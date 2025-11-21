//
//  ProductService.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation

class ProductService {
    static let shared = ProductService()
    
    private let baseURL = "https://app.lovoj.com:444/api/v1"
    
    private init() {}
    
    func fetchMakingProductList(token: String) async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/products/making-list") else {
            throw ProductError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProductError.invalidResponse
            }
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 API Response: \(responseString)")
                
                // Check if response is "Route not found" (endpoint doesn't exist)
                if responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "Route not found" {
                    print("⚠️ API endpoint not found, will use fallback products")
                    throw ProductError.serverError("Route not found")
                }
            }
            
            if httpResponse.statusCode == 200 {
                // Try different response formats
                do {
                    // Format 1: Direct array of strings
                    if let products = try? JSONDecoder().decode([String].self, from: data) {
                        print("✅ Products decoded as direct array: \(products.count) products")
                        return products
                    }
                    
                    // Format 2: Object with "products" key
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let products = json["products"] as? [String] {
                            print("✅ Products decoded from 'products' key: \(products.count) products")
                            return products
                        }
                        if let products = json["data"] as? [String] {
                            print("✅ Products decoded from 'data' key: \(products.count) products")
                            return products
                        }
                        if let products = json["makingProductList"] as? [String] {
                            print("✅ Products decoded from 'makingProductList' key: \(products.count) products")
                            return products
                        }
                    }
                    
                    // Format 3: Object with nested array
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataObj = json["data"] as? [String: Any],
                       let products = dataObj["products"] as? [String] {
                        print("✅ Products decoded from nested structure: \(products.count) products")
                        return products
                    }
                    
                    // Format 4: Array of objects with "name" key
                    if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        let products = jsonArray.compactMap { $0["name"] as? String }
                        if !products.isEmpty {
                            print("✅ Products decoded from array of objects: \(products.count) products")
                            return products
                        }
                    }
                    
                    // If all formats fail, print error
                    print("❌ Failed to decode response. Response data: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
                    throw ProductError.decodingError
                    
                } catch let error as ProductError {
                    throw error
                } catch {
                    print("❌ Decoding error: \(error.localizedDescription)")
                    throw ProductError.decodingError
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                
                // Handle 404 or "Route not found" gracefully
                if httpResponse.statusCode == 404 || errorMessage.contains("Route not found") {
                    print("⚠️ API endpoint not found (404), will use fallback products")
                    throw ProductError.serverError("Route not found")
                } else {
                    print("❌ Server error: \(httpResponse.statusCode) - \(errorMessage)")
                    throw ProductError.serverError("Failed with status code: \(httpResponse.statusCode) - \(errorMessage)")
                }
            }
        } catch let error as ProductError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw ProductError.networkError(error.localizedDescription)
        }
    }
}

enum ProductError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkError(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        }
    }
}

