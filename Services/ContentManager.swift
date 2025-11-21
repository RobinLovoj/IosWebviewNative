//
//  ContentManager.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation
import UniformTypeIdentifiers

// URLSessionDelegate for progress tracking
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Int) -> Void)?
    var onComplete: ((URL) -> Void)?
    var onError: ((Error) -> Void)?
    var totalBytesExpected: Int64 = 0
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        totalBytesExpected = totalBytesExpectedToWrite
        let percent = Int((totalBytesWritten * 100) / totalBytesExpectedToWrite)
        
        // Log download progress every 10% or on first update
        if percent % 10 == 0 || totalBytesWritten == bytesWritten {
            let downloadedMB = Double(totalBytesWritten) / 1024 / 1024
            let totalMB = Double(totalBytesExpectedToWrite) / 1024 / 1024
            print("📥 ZIP Downloading: \(percent)% (\(String(format: "%.2f", downloadedMB)) MB / \(String(format: "%.2f", totalMB)) MB)")
        }
        
        DispatchQueue.main.async {
            self.onProgress?(percent)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async {
            self.onComplete?(location)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onError?(error)
            }
        }
    }
}

class ContentManager {
    private let baseDir: URL
    private let zipUrl = "https://d12hs8wunnl6k1.cloudfront.net/3dorder/dist.zip"
    
    init(baseDir: URL) {
        self.baseDir = baseDir
        // Create base directory if it doesn't exist
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }
    
    func downloadZip(
        onProgress: @escaping (Int) -> Void,
        onComplete: @escaping (URL) -> Void,
        onError: @escaping (String) -> Void
    ) {
        let distIndexFile = baseDir.appendingPathComponent("dist/index.html")
        
        // Check if content already exists
        if FileManager.default.fileExists(atPath: distIndexFile.path) {
            print("✅ Content already exists, skipping download")
            // Call onComplete with a dummy file to signal that content exists
            // ViewModel will check and skip extraction if content exists
            DispatchQueue.main.async {
                onComplete(self.baseDir.appendingPathComponent("existing_content.zip"))
            }
            return
        }
        
        // Download on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Clean existing directory
                if FileManager.default.fileExists(atPath: self.baseDir.path) {
                    try? FileManager.default.removeItem(at: self.baseDir)
                }
                try FileManager.default.createDirectory(at: self.baseDir, withIntermediateDirectories: true)
                
                let zipFile = self.baseDir.appendingPathComponent("temp.zip")
                
                // Download ZIP file with progress
                print("📥 Starting ZIP download from: \(self.zipUrl)")
                try self.downloadZipFileWithProgress(
                    urlString: self.zipUrl,
                    outputFile: zipFile,
                    onProgress: { percent in
                        DispatchQueue.main.async {
                            onProgress(percent)
                        }
                    }
                )
                
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: zipFile.path)
                let zipSize = (fileAttributes[.size] as? Int64) ?? 0
                let zipSizeMB = Double(zipSize) / 1024.0 / 1024.0
                print("✅ ZIP Download Complete!")
                print("📦 ZIP File Size: \(zipSize) bytes (\(String(format: "%.2f", zipSizeMB)) MB)")
                print("📁 ZIP File Path: \(zipFile.path)")
                
                DispatchQueue.main.async {
                    onComplete(zipFile)
                }
                
            } catch {
                print("❌ Download error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onError(error.localizedDescription)
                }
            }
        }
    }
    
    func extractZip(
        zipFile: URL,
        onProgress: @escaping (String, Int, Int) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        let distIndexFile = baseDir.appendingPathComponent("dist/index.html")
        
        // Extract on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Extract ZIP file with progress tracking
                try ZipExtractor.extract(
                    zipFile: zipFile,
                    to: self.baseDir,
                    onProgress: { fileName, current, total in
                        DispatchQueue.main.async {
                            onProgress(fileName, current, total)
                        }
                    }
                )
                
                // Delete temp zip file
                try? FileManager.default.removeItem(at: zipFile)
                
                // Verify dist folder structure exists
                let distDir = self.baseDir.appendingPathComponent("dist")
                if FileManager.default.fileExists(atPath: distDir.path) {
                    print("✅ Dist folder created at: \(distDir.path)")
                    
                    // List some files in dist to verify structure
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: distDir.path) {
                        print("📁 Dist folder contains \(files.count) items")
                        if files.count > 0 {
                            print("📁 Sample files in dist: \(files.prefix(5).joined(separator: ", "))")
                        }
                    }
                } else {
                    print("⚠️ WARNING: Dist folder not found at: \(distDir.path)")
                }
                
                // Verify index.html exists
                if !FileManager.default.fileExists(atPath: distIndexFile.path) {
                    print("❌ Index.html not found at: \(distIndexFile.path)")
                    print("📁 Base directory contents:")
                    if let baseContents = try? FileManager.default.contentsOfDirectory(atPath: self.baseDir.path) {
                        for item in baseContents {
                            print("   - \(item)")
                        }
                    }
                    throw NSError(domain: "ContentManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "index.html not found after extraction!"])
                }
                
                print("✅ Index.html found at: \(distIndexFile.path)")
                
                // Patch asset paths
                self.patchAssetPaths(file: distIndexFile)
                
                print("✅ Content extraction complete")
                
                DispatchQueue.main.async {
                    onComplete()
                }
                
            } catch {
                print("❌ Extraction error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onError(error.localizedDescription)
                }
            }
        }
    }
    
    // Legacy method for backward compatibility
    func extractAndLoadContent(
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void,
        onProgress: @escaping (Int) -> Void
    ) {
        downloadZip(
            onProgress: onProgress,
            onComplete: { [weak self] zipFile in
                self?.extractZip(
                    zipFile: zipFile,
                    onProgress: { fileName, current, total in
                        // Legacy method doesn't need file-level progress
                        // Just update overall progress
                        let progress = total > 0 ? Int((current * 100) / total) : 0
                        onProgress(progress)
                    },
                    onComplete: onSuccess,
                    onError: onError
                )
            },
            onError: onError
        )
    }
    
    private func downloadZipFileWithProgress(
        urlString: String,
        outputFile: URL,
        onProgress: @escaping (Int) -> Void
    ) throws {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ContentManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        print("📥 Starting download from: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let semaphore = DispatchSemaphore(value: 0)
        var downloadError: Error?
        var downloadedFileURL: URL?
        
        // Create delegate for progress tracking
        let delegate = DownloadDelegate()
        delegate.onProgress = { percent in
            onProgress(percent)
        }
        delegate.onComplete = { tempURL in
            downloadedFileURL = tempURL
            semaphore.signal()
        }
        delegate.onError = { error in
            print("❌ Download error: \(error.localizedDescription)")
            downloadError = error
            semaphore.signal()
        }
        
        // Create URLSession with delegate
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        
        // Start download
        print("🚀 Starting ZIP download task...")
        print("📥 Downloading ZIP from: \(urlString)")
        let task = session.downloadTask(with: request)
        task.resume()
        print("✅ ZIP download task started, waiting for progress...")
        
        // Wait for completion
        semaphore.wait()
        
        // Clean up session
        session.invalidateAndCancel()
        
        if let error = downloadError {
            throw error
        }
        
        guard let tempURL = downloadedFileURL else {
            throw NSError(domain: "ContentManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file downloaded"])
        }
        
        // Move file to output location
        do {
            try? FileManager.default.removeItem(at: outputFile)
            try FileManager.default.moveItem(at: tempURL, to: outputFile)
            print("✅ File moved to: \(outputFile.path)")
            onProgress(100)
        } catch {
            print("❌ Error moving file: \(error.localizedDescription)")
            throw error
        }
    }
    
    
    private func patchAssetPaths(file: URL) {
        do {
            var html = try String(contentsOf: file, encoding: .utf8)
            html = html.replacingOccurrences(of: "src=\"/vite.svg", with: "src=\"vite.svg")
            try html.write(to: file, atomically: true, encoding: .utf8)
            print("✅ Asset paths patched")
        } catch {
            print("❌ Error patching asset paths: \(error.localizedDescription)")
        }
    }
}

