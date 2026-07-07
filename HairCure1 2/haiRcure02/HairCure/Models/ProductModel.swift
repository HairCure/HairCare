import Foundation

enum CompatibilityRating: String, Codable, CaseIterable {
    case safe
    case caution
    case hazard

    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .hazard: return "Hazard"
        }
    }
}

enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case shampoo
    case conditioner
    case treatment
    case styling

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .shampoo: return "Shampoo"
        case .conditioner: return "Conditioner"
        case .treatment: return "Treatment"
        case .styling: return "Styling"
        }
    }
}

struct Product: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var brand: String
    var ingredients: [String]
    var compatibility: CompatibilityRating
    var category: ProductCategory
    var scannedAt: Date
    var notes: String?
}

struct ResearchLink: Codable, Hashable, Identifiable {
    var id: String { source }
    let source: String
    let url: String
}

struct FlaggedIngredient: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let cid: Int?
    let rating: CompatibilityRating
    let signalWord: String?
    let ghsCodes: [String]
    let hazardStatements: [String]
    let explanation: String
    let researchLinks: [ResearchLink]
}

