//
//  AuthService.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation

class AuthService {
    static let shared = AuthService()
    
    private let baseURL = "https://app.lovoj.com:444/api/v1"
    
    private init() {}
    
    func login(email: String, password: String, storeType: String, role: String) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw AuthError.invalidURL
        }
        
        let requestBody = LoginRequest(
            email: email,
            password: password,
            storeType: storeType,
            role: role
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Authorization header if token exists
        if let token = UserDataManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AuthError.encodingError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    // Save the response
                    UserDataManager.shared.saveLoginResponse(loginResponse)
                    return loginResponse
                } catch {
                    print("Decoding error: \(error)")
                    throw AuthError.decodingError
                }
            } else {
                // Try to decode error message
                if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorData["message"] {
                    throw AuthError.serverError(message)
                } else {
                    throw AuthError.serverError("Login failed with status code: \(httpResponse.statusCode)")
                }
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }
}

enum AuthError: LocalizedError {
    case invalidURL
    case encodingError
    case decodingError
    case invalidResponse
    case networkError(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        }
    }
}




