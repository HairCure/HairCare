import Foundation

enum MediaType: String, Codable {
    case video, audio
}

enum CategoryType {
    case yoga, meditation, sounds
}

struct MindEaseCategory: Identifiable, Hashable {
    let id: UUID
    var title: String
    var categoryDescription: String
    var cardImageUrl: String
    var cardIconName: String
}

struct MindEaseCategoryContent: Identifiable, Hashable {
    let id: UUID
    var categoryId: UUID
    var title: String
    var caption: String
    
    var mediaURL: String
    var mediaType: MediaType
    var durationSeconds: Int
    var difficultyLevel: String
    
    var imageurl: String
   
    var thumbnailUrl: String?
}

struct MindfulSession: Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var contentId: UUID
    var sessionDate: Date
    var minutesCompleted: Int
    var startTime: Date
    var endTime: Date
}

struct TodaysPlan: Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var planDate: Date
    var contentId: UUID
    var categoryId: UUID
    var planId: String
    var minutesTarget: Int
    var minutesCompleted: Int
    var isCompleted: Bool
}
