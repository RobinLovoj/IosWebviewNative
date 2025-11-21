//
//  LocalWebServer.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//
//  Pure Swift Local HTTP server using Network.framework (no external packages).
//

import Foundation
import Network

final class LocalWebServer {
    private let baseDir: URL
    let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.offlineweb.localserver", qos: .userInitiated)
    private var isServerRunning = false
    private let fileManager = FileManager.default
    
    init(baseDir: URL, port: UInt16 = 9000) {
        self.baseDir = baseDir
        self.port = port
    }
    
    @discardableResult
    func start() -> Bool {
        guard !isServerRunning else {
            print("✅ Local HTTP server already running")
            return true
        }
        
        guard fileManager.fileExists(atPath: baseDir.path) else {
            print("❌ Directory does not exist: \(baseDir.path)")
            return false
        }
        
        do {
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                print("❌ Invalid port \(port)")
                return false
            }
            
            let listener = try NWListener(using: .tcp, on: nwPort)
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isServerRunning = true
                    print("🚀 Local HTTP server running on http://localhost:\(nwPort.rawValue)")
                    print("📁 Serving files from: \(self?.baseDir.path ?? "unknown")")
                case .failed(let error):
                    print("❌ Local HTTP server failed: \(error.localizedDescription)")
                    self?.stop()
                case .cancelled:
                    self?.isServerRunning = false
                default:
                    break
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            
            listener.start(queue: queue)
            self.listener = listener
            return true
        } catch {
            print("❌ Failed to start local HTTP server: \(error.localizedDescription)")
            return false
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isServerRunning = false
        print("✅ Local HTTP server stopped")
    }
    
    var isRunning: Bool {
        return isServerRunning
    }
    
    private func handle(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("⚠️ Connection failed: \(error.localizedDescription)")
            }
        }
        
        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }
    
    private func receive(on connection: NWConnection, accumulated data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] buffer, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("⚠️ Receive error: \(error.localizedDescription)")
                connection.cancel()
                return
            }
            
            var currentData = data
            if let buffer = buffer {
                currentData.append(buffer)
            }
            
            if self.isRequestComplete(currentData) {
                self.process(requestData: currentData, connection: connection)
            } else if isComplete {
                self.send400(on: connection)
            } else {
                self.receive(on: connection, accumulated: currentData)
            }
        }
    }
    
    private func isRequestComplete(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let terminator = Data("\r\n\r\n".utf8)
        return data.range(of: terminator) != nil
    }
    
    private func process(requestData: Data, connection: NWConnection) {
        guard let request = String(data: requestData, encoding: .utf8) else {
            send400(on: connection)
            return
        }
        
        guard let path = extractPath(from: request) else {
            send400(on: connection)
            return
        }
        
        serve(path: path, over: connection)
    }
    
    private func extractPath(from request: String) -> String? {
        guard let firstLine = request.components(separatedBy: "\r\n").first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }
    
    private func serve(path rawPath: String, over connection: NWConnection) {
        let safePath = sanitize(path: rawPath)
        var fileURL = baseDir.appendingPathComponent(safePath)
        print("📥 Requested path: \(rawPath) -> sanitized: \(safePath)")
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            fileURL = fileURL.appendingPathComponent("index.html")
            print("📁 Path is directory, serving index: \(fileURL.lastPathComponent)")
        }
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("❌ File not found for request: \(fileURL.path)")
            send404(on: connection)
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            sendResponse(
                connection: connection,
                status: "200 OK",
                headers: [
                    "Content-Type": mimeType(for: fileURL.pathExtension),
                    "Content-Length": "\(data.count)",
                    "Connection": "close",
                    "Cache-Control": "no-store",
                    "Access-Control-Allow-Origin": "*"
                ],
                body: data
            )
        } catch {
            print("❌ Failed to read \(fileURL.path): \(error.localizedDescription)")
            send500(on: connection)
        }
    }
    
    private func sanitize(path: String) -> String {
        var cleaned = path
        
        if let hashRange = cleaned.range(of: "#") {
            cleaned.removeSubrange(hashRange.lowerBound..<cleaned.endIndex)
        }
        
        if let queryRange = cleaned.range(of: "?") {
            cleaned = String(cleaned[..<queryRange.lowerBound])
        }
        
        if cleaned.isEmpty || cleaned == "/" {
            return "index.html"
        }
        
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = trimmed.split(separator: "/").filter { $0 != ".." && $0 != "." }
        let safePath = parts.joined(separator: "/")
        return safePath.isEmpty ? "index.html" : safePath
    }
    
    private func sendResponse(connection: NWConnection, status: String, headers: [String: String], body: Data) {
        var headerString = "HTTP/1.1 \(status)\r\n"
        headers.forEach { headerString += "\($0.key): \($0.value)\r\n" }
        headerString += "\r\n"
        
        var responseData = Data(headerString.utf8)
        responseData.append(body)
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func send400(on connection: NWConnection) {
        let body = Data("<h1>400 - Bad Request</h1>".utf8)
        sendResponse(
            connection: connection,
            status: "400 Bad Request",
            headers: [
                "Content-Type": "text/html",
                "Content-Length": "\(body.count)",
                "Connection": "close"
            ],
            body: body
        )
    }
    
    private func send404(on connection: NWConnection) {
        let body = Data("<h1>404 - File Not Found</h1>".utf8)
        sendResponse(
            connection: connection,
            status: "404 Not Found",
            headers: [
                "Content-Type": "text/html",
                "Content-Length": "\(body.count)",
                "Connection": "close"
            ],
            body: body
        )
    }
    
    private func send500(on connection: NWConnection) {
        let body = Data("<h1>500 - Internal Server Error</h1>".utf8)
        sendResponse(
            connection: connection,
            status: "500 Internal Server Error",
            headers: [
                "Content-Type": "text/html",
                "Content-Length": "\(body.count)",
                "Connection": "close"
            ],
            body: body
        )
    }
    
    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "js": return "application/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "glb": return "model/gltf-binary"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
    
    // MARK: - URL Helpers
    
    func getFileURL(for path: String = "index.html") -> URL {
        return URL(string: "http://localhost:\(port)/\(path)")!
    }
    
    func getCacheDataURL(token: String) -> URL {
        let json = ["token": token]
        if let jsonData = try? JSONSerialization.data(withJSONObject: json),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "http://localhost:\(port)/index.html#/cache-data?device=ios&encoded=\(encoded)")!
        }
        return URL(string: "http://localhost:\(port)/index.html")!
    }
    
    func getProductURL(productName: String, fileName: String, token: String) -> URL {
        let json = ["token": token, "productName": productName, "fileName": fileName]
        if let jsonData = try? JSONSerialization.data(withJSONObject: json),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "http://localhost:\(port)/index.html#/product?device=ios&encoded=\(encoded)")!
        }
        let encodedName = productName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productName
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
        return URL(string: "http://localhost:\(port)/index.html#/product/\(encodedFileName)?name=\(encodedName)")!
    }
    
    func getFabricFormURL(productName: String) -> URL {
        let encodedName = productName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productName
        let payload = ["productName": productName]
        let encodedPayload: String
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            encodedPayload = encoded
        } else {
            encodedPayload = ""
        }
        let encodedQuery = encodedPayload.isEmpty ? "" : "&encoded=\(encodedPayload)"
        return URL(string: "http://localhost:\(port)/index.html#/fabric-form?fabric=\(encodedName)\(encodedQuery)")!
    }
    
    func getTokenDataJSON(token: String) -> String? {
        let json = ["token": token]
        if let jsonData = try? JSONSerialization.data(withJSONObject: json),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return nil
    }
}
