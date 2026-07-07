import Foundation

struct CareTip: Identifiable {
    let id: UUID
    var title: String
    var tipDescription: String
    var mediaURL: String?
    var steps: [String]
    var frequency: String?
    var precautions: String?
    var researchURL: String?
    /// Empty = universal (shown to all hair types)
    var hairTypes: [String]
    var isActive: Bool
}

struct HomeRemedy: Identifiable {
    let id: UUID
    var title: String
    var remedyDescription: String
    var mediaURL: String?
    var videoDurationSeconds: Int?
    var videoURL: String?
    var ingredients: [String]
    var steps: [String]
    var benefits: String
    var frequency: String?
    var precautions: String?
    var researchURL: String?
    /// Empty = universal (shown to all hair types)
    var hairTypes: [String]
    var isActive: Bool
}

struct HairCareRoutine: Identifiable {
    let id: UUID
    var cardHeading: String
    var applyingFrequency: String
    var summary: String
    var benefits: String?
    var steps: [String]
    var precautions: String?
    var researchURL: String?
    var hairTypes: [String]
    var isActive: Bool
}

struct UserFavorite: Identifiable {
    let id: UUID
    var contentId: UUID                 // FK for care tip, home remedy, or routine
    var savedAt: Date
}
