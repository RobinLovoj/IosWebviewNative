//
//  LoginResponse.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation

// MARK: - Login Response Models
struct LoginResponse: Codable {
    let success: Bool
    let message: String
    let token: String
    let user: User
}

struct User: Codable {
    let currentLocation: CurrentLocation?
    let id: String
    let storeId: String
    let storeNumber: String
    let email: String
    let mobileNumber: String
    let name: String
    let storeType: String
    let role: String
    let Associate: [String]
    let Associated: [String]
    let personalProfileStatus: Bool
    let businessProfileStatus: Bool
    let profilePhotoStatus: Bool
    let profileSignatureStatus: Bool
    let profileFactoryStatus: Bool
    let createdAt: String
    let updatedAt: String
    let v: Int
    let deviceToken: String?
    let activestatus: Bool
    let superAdminPermission: Bool
    let websitePermission: Bool
    let makingProductList: [String]
    let fabricStatus: Bool
    let measurmentStatus: Bool
    let productStatus: Bool
    let specialist: [String]
    let location: String
    let created_by: String
    let working_locations: [String]
    
    enum CodingKeys: String, CodingKey {
        case currentLocation
        case id = "_id"
        case storeId
        case storeNumber
        case email
        case mobileNumber
        case name
        case storeType
        case role
        case Associate
        case Associated
        case personalProfileStatus
        case businessProfileStatus
        case profilePhotoStatus
        case profileSignatureStatus
        case profileFactoryStatus
        case createdAt
        case updatedAt
        case v = "__v"
        case deviceToken
        case activestatus
        case superAdminPermission
        case websitePermission
        case makingProductList
        case fabricStatus
        case measurmentStatus
        case productStatus
        case specialist
        case location
        case created_by
        case working_locations
    }
}

struct CurrentLocation: Codable {
    let ip: String
    let country: String
    let countryCode: String
    let region: String
    let regionName: String
    let city: String
    let zip: String
    let lat: Double
    let lon: Double
    let timezone: String
    let isp: String
    let org: String
    let `as`: String
    let query: String
    
    enum CodingKeys: String, CodingKey {
        case ip
        case country
        case countryCode
        case region
        case regionName
        case city
        case zip
        case lat
        case lon
        case timezone
        case isp
        case org
        case `as` = "as"
        case query
    }
}

// MARK: - Login Request Model
struct LoginRequest: Codable {
    let email: String
    let password: String
    let storeType: String
    let role: String
}

