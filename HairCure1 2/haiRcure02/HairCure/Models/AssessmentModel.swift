import Foundation

enum KeyboardType: String, Codable {
    case text
    case decimal
    case number
}

enum OptionType: String, Codable {
    case text
    case image
}


enum ScanType: String, Codable {
    case initial
    case monthly
    case weekly  // legacy — kept so old DB records decode gracefully; treated as monthly in UI
}

enum ScalpCondition: String, Codable {
    case dry
    case dandruff
    case oily
    case inflamed
    case normal
    case notAssessed
}

enum HairDensityLevel: String, Codable {
    case high
    case medium
    case low
    case veryLow
    case notAssessed
}

enum AnalysisSource: String, Codable {
    case aiModel
    case selfAssessed
}

// MARK: - Lifestyle Profile

enum LifestyleProfile: String, Codable {
    case poor
    case moderate
    case good

    static func from(score: Float) -> LifestyleProfile {
        switch score {
        case 0..<5:   return .poor
        case 5..<8:   return .moderate
        default:      return .good
        }
    }
}

// MARK: - Activity Level

enum ActivityLevel: String, Codable {
    case sedentary
    case light
    case moderate
    case veryActive

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light:     return 1.375
        case .moderate:  return 1.55
        case .veryActive: return 1.725
        }
    }
}
enum ScoreDimension: String, Codable {
    case diet
    case stress
    case sleep
    case hairCare
    case hydration
    case none
}


enum HairFallStage: String, Codable {
    case stage1
    case stage2
    case stage3
    case stage4

    var intValue: Int {
        switch self {
        case .stage1: return 1
        case .stage2: return 2
        case .stage3: return 3
        case .stage4: return 4
        }
    }

    var displayName: String {
        switch self {
        case .stage1: return "Stage 1"
        case .stage2: return "Stage 2"
        case .stage3: return "Stage 3"
        case .stage4: return "Stage 4"
        }
    }
}
enum QuestionType: String, Codable {
    case singleChoice
    case multiChoice
    case imageChoice
    case freeText
    case picker
}



// MARK: - Assessment

struct Assessment: Identifiable {
    let id: UUID
    var userId: UUID
    var completionPercent: Float
    var completedAt: Date?
}

// MARK: - Question / Option / ScoreMap




struct Question: Identifiable {
    let id: UUID
    let questionType: QuestionType
    var questionText: String
    var questionOrderIndex: Int
    var scoreDimension: ScoreDimension
    var pickerMin: Float?
    var pickerMax: Float?
    var pickerStep: Float?
    var pickerUnit: String?
    var keyboardType: KeyboardType?
}

struct QuestionOption: Identifiable {
    let id: UUID
    var questionId: UUID
    var optionOrderIndex: Int
    var optionText: String
    var imageURL: String?
    var optionType: OptionType
}


struct QuestionScoreMap: Identifiable {
    let id: UUID
    var questionId: UUID
    var optionId: UUID
    var scoreDimension: ScoreDimension
    var scoreValue: Float
}

// MARK: - UserAnswer

struct UserAnswer: Identifiable {
    let id: UUID
    let answeredAt: Date
    var questionId: UUID
    var assessmentId: UUID
    var selectedOptionId: UUID?
    var selectedOptionIds: [UUID]
    var answerText: String?
    var pickerValue: Float?
    var scoreValue: Float?
    var scoreDimension: ScoreDimension?
}

// MARK: - Scalp Scan / Report

struct ScalpScan: Identifiable {
    let id: UUID
    var userId: UUID
    let scanDate: Date
    var frontImageURL: String
    var leftImageURL: String
    var rightImageURL: String
    var backImageURL: String
    var topImageURL: String
    let scanType: ScanType
}



struct ScanReport: Identifiable {
    let id: UUID
    let createdAt: Date
    var scalpScanId: UUID
    var hairDensityPercent: Float
    var hairDensityLevel: HairDensityLevel
    var hairFallStage: HairFallStage
    var scalpCondition: ScalpCondition
    var hairType: String?
    var analysisSource: AnalysisSource
    var planId: String
    var lifestyleScore: Float
    var dietScore: Float
    var stressScore: Float
    var sleepScore: Float
    var hairCareScore: Float
    var recommendedPlan: String
}

