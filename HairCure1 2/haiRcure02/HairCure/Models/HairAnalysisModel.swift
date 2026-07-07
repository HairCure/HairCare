import Foundation

struct AreaDetail: Codable {
    let density_percentage: Int
    let notes: String
}

struct ImagesValid: Codable {
    let front: Bool
    let crown: Bool
    let left: Bool
    let right: Bool
}

struct AreaBreakdown: Codable {
    let front: AreaDetail
    let crown: AreaDetail
    let left: AreaDetail
    let right: AreaDetail
}

struct HairAnalysisResult: Codable {
    let overall_density_percentage: Int
    let overall_density_label: String
    let norwood_stage: String
    let norwood_description: String
    let area_breakdown: AreaBreakdown
    let most_affected_area: String
    let affected_areas: [String]
    let summary: String
    let hair_type: String?
    let images_valid: ImagesValid
    let confidence: String?
    let tip: String?         
}
