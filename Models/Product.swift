//
//  Product.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation

enum ProductCategory: String, CaseIterable {
    case men
    case women
}

struct Product: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let imageName: String
    let category: ProductCategory
    let fileName: String
    var percent: Int = 0
    var isChecked: Bool = false
    
    init(name: String, imageName: String = "suit", category: ProductCategory = .men, fileName: String? = nil) {
        self.name = name
        self.imageName = imageName
        self.category = category
        self.fileName = fileName ?? getProductFileName(name)
    }
}

struct DefaultProductLists {
    static let men: [String] = [
        "Shirt",
        "Bandhgala Suit",
        "Suits",
        "Half Jacket",
        "Trench Coat",
        "Abayas",
        "Field Jacket",
        "Sherwani",
        "Waist Coat",
        "Wool Coat",
        "Trousers",
        "Casual Trousers",
        "Joggers"
    ]
    
    static let women: [String] = [
        "Kurti",
        "Women Trench Coat",
        "Women Suit",
        "One Piece Dress",
        "Women Abayas",
        "Skirt",
        "Sarees",
        "Women Anarkali Suit",
        "Palazzo",
        "Gown",
        "Kaftan",
        "Draped Top",
        "Draped Dress",
        "Lehenga"
    ]
    
    static var allEntries: [(name: String, category: ProductCategory)] {
        men.map { ($0, .men) } + women.map { ($0, .women) }
    }
    
    static var allProducts: [String] {
        men + women
    }
}

private let productFileNameLookup: [String: String] = [
    "shirt": "men/shirt",
    "bandhgala suit": "men/bandhgala_suit",
    "suits": "men/suits",
    "half jacket": "men/half_jacket",
    "trench coat": "men/trench_coat",
    "abayas": "men/abayas",
    "field jacket": "men/field_jacket",
    "sherwani": "men/sherwani",
    "waist coat": "men/waist_coat",
    "wool coat": "men/wool_coat",
    "trousers": "men/trousers",
    "casual trousers": "men/casual_trousers",
    "joggers": "men/joggers",
    "kurti": "women/kurti",
    "women trench coat": "women/women_trench_coat",
    "women suit": "women/women_suit",
    "one piece dress": "women/one_piece_dress",
    "women abayas": "women/women_abayas",
    "skirt": "women/skirt",
    "sarees": "women/sarees",
    "women anarkali suit": "women/women_anarkali_suit",
    "palazzo": "women/palazzo",
    "gown": "women/gown",
    "kaftan": "women/kaftan",
    "draped top": "women/draped_top",
    "draped dress": "women/draped_dress",
    "lehenga": "women/lehenga"
]

private let productImageLookup: [String: String] = [
    // Men
    "shirt": "men_shirt",
    "bandhgala suit": "bandhgala_suit",
    "suits": "suit",
    "half jacket": "half_jacket",
    "trench coat": "overcoat",
    "abayas": "men_abayas",
    "field jacket": "overcoat",
    "sherwani": "sherwani",
    "waist coat": "vest",
    "wool coat": "overcoat",
    "trousers": "cropped_pants",
    "casual trousers": "cropped_pants",
    "joggers": "cropped_pants",
    
    // Women
    "kurti": "kurta",
    "women trench coat": "overcoat",
    "women suit": "suit",
    "one piece dress": "one_piece",
    "women abayas": "women_abayas",
    "skirt": "women_skirt",
    "sarees": "bride_dress",
    "women anarkali suit": "ball_gown",
    "palazzo": "cropped_pants",
    "gown": "ball_gown",
    "kaftan": "peplum_dress",
    "draped top": "losse_fit",
    "draped dress": "drapped_dress",
    "lehenga": "bride_dress"
]

func getProductFileName(_ productName: String) -> String {
    let key = productName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let mapped = productFileNameLookup[key] {
        return mapped
    }
    return key
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "\n", with: "_")
}

func getProductCategory(_ productName: String) -> ProductCategory {
    let key = productName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if DefaultProductLists.men.map({ $0.lowercased() }).contains(key) {
        return .men
    }
    return .women
}

func getProductImageName(_ productName: String) -> String {
    let key = productName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let mapped = productImageLookup[key] {
        return mapped
    }
    
    // Default fallback
    return "suit"
}

