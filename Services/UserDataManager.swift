//
//  UserDataManager.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation

class UserDataManager {
    static let shared = UserDataManager()
    
    // File names
    private let loginResponseFileName = "login_response.json"
    private let userDataFileName = "user_data.json"
    private let tokenFileName = "auth_token.txt"
    
    // Directory path
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // File paths
    private var loginResponseFilePath: URL {
        documentsDirectory.appendingPathComponent(loginResponseFileName)
    }
    
    private var userDataFilePath: URL {
        documentsDirectory.appendingPathComponent(userDataFileName)
    }
    
    private var tokenFilePath: URL {
        documentsDirectory.appendingPathComponent(tokenFileName)
    }
    
    private init() {}
    
    // MARK: - Token Management
    func saveToken(_ token: String) {
        do {
            try token.write(to: tokenFilePath, atomically: true, encoding: .utf8)
            print("✅ Token saved to: \(tokenFilePath.path)")
        } catch {
            print("❌ Error saving token: \(error.localizedDescription)")
        }
    }
    
    func getToken() -> String? {
        do {
            let token = try String(contentsOf: tokenFilePath, encoding: .utf8)
            return token.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("❌ Error reading token: \(error.localizedDescription)")
            return nil
        }
    }
    
    func removeToken() {
        try? FileManager.default.removeItem(at: tokenFilePath)
    }
    
    // MARK: - Login Response Management
    func saveLoginResponse(_ response: LoginResponse) {
        // Save token
        saveToken(response.token)
        
        // Save entire response as JSON file
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(response)
            try jsonData.write(to: loginResponseFilePath, options: .atomic)
            print("✅ Login response saved to: \(loginResponseFilePath.path)")
        } catch {
            print("❌ Error saving login response: \(error.localizedDescription)")
        }
        
        // Also save user data separately for easy access
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(response.user)
            try jsonData.write(to: userDataFilePath, options: .atomic)
            print("✅ User data saved to: \(userDataFilePath.path)")
        } catch {
            print("❌ Error saving user data: \(error.localizedDescription)")
        }
    }
    
    func getLoginResponse() -> LoginResponse? {
        do {
            let data = try Data(contentsOf: loginResponseFilePath)
            let decoder = JSONDecoder()
            let response = try decoder.decode(LoginResponse.self, from: data)
            print("✅ Login response loaded from: \(loginResponseFilePath.path)")
            return response
        } catch {
            print("❌ Error reading login response: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getUser() -> User? {
        do {
            let data = try Data(contentsOf: userDataFilePath)
            let decoder = JSONDecoder()
            let user = try decoder.decode(User.self, from: data)
            print("✅ User data loaded from: \(userDataFilePath.path)")
            return user
        } catch {
            print("❌ Error reading user data: \(error.localizedDescription)")
            return nil
        }
    }
    
    func clearAllData() {
        try? FileManager.default.removeItem(at: loginResponseFilePath)
        try? FileManager.default.removeItem(at: userDataFilePath)
        try? FileManager.default.removeItem(at: tokenFilePath)
        print("✅ All data cleared")
    }
    
    func isLoggedIn() -> Bool {
        return getToken() != nil
    }
    
    // MARK: - Helper Methods
    func getDocumentsDirectoryPath() -> String {
        return documentsDirectory.path
    }
    
    func getAllSavedFiles() -> [String] {
        var files: [String] = []
        
        if FileManager.default.fileExists(atPath: loginResponseFilePath.path) {
            files.append("login_response.json")
        }
        
        if FileManager.default.fileExists(atPath: userDataFilePath.path) {
            files.append("user_data.json")
        }
        
        if FileManager.default.fileExists(atPath: tokenFilePath.path) {
            files.append("auth_token.txt")
        }
        
        return files
    }
    
    // MARK: - API Done Flag (like Android SharedPreferences)
    func setApiDone(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "api_done")
        print("✅ API done flag set to: \(value)")
    }
    
    func getApiDone() -> Bool {
        return UserDefaults.standard.bool(forKey: "api_done")
    }
}

