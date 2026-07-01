import Foundation

// MARK: - Compatibility Rating
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

// MARK: - Product Category
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

// MARK: - Product
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

// MARK: - Ingredient Rule
struct IngredientRule: Codable, Hashable {
    let name: String
    let synonyms: [String]
    let hazardProfile: [ScalpCondition: CompatibilityRating]
    let explanation: String
}

// MARK: - Flagged Ingredient
struct FlaggedIngredient: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let rule: IngredientRule
    let rating: CompatibilityRating
    let explanation: String
}
