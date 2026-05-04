import Foundation

// MARK: - Auth

enum AuthProvider: String, Codable {
    case apple
    case google
    case guest
}

// MARK: - User

struct User: Identifiable {
    let id: UUID
    var name: String
    var email: String
    var phoneNumber: String?
    let authProvider: AuthProvider
    let createdAt: Date
}

// MARK: - UserProfile

struct UserProfile: Identifiable {
    let id: UUID
    var userId: UUID
    var username: String
    var displayName: String
    var dateOfBirth: Date
    var gender: String
    var heightCm: Float
    var weightKg: Float
    var hairType: String
    var scalpType: String
    var isVegetarian: Bool
    var profileImageURL: String?
    var isProfileComplete: Bool
    var joinedAt: Date
}

// MARK: - UserPlan

struct UserPlan: Identifiable {
    let id: UUID
    var userId: UUID
    var scanReportId: UUID
    var planId: String
    var stage: Int
    var lifestyleProfile: LifestyleProfile
    var scalpModifier: ScalpCondition
    var meditationMinutesPerDay: Int
    var yogaMinutesPerDay: Int
    var soundMinutesPerDay: Int
    var sessionFrequencyPerWeek: Int
    var isActive: Bool
    var assignedAt: Date
    var expiresAt: Date
}

// MARK: - UserNutritionProfile

struct UserNutritionProfile: Identifiable {
    let id: UUID
    var userId: UUID
    var activityLevel: ActivityLevel
    var bmr: Float
    var tdee: Float
    var breakfastCalTarget: Float
    var lunchCalTarget: Float
    var snackCalTarget: Float
    var dinnerCalTarget: Float
    var proteinTargetGm: Float
    var carbTargetGm: Float
    var fatTargetGm: Float
    var waterTargetML: Float
    var createdAt: Date
    var updatedAt: Date
}

// MARK: - WaterIntakeLog

struct WaterIntakeLog: Identifiable {
    let id: UUID
    var userId: UUID
    var date: Date
    var cupSize: String
    var cupSizeAmountInML: Float
    var loggedAt: Date
}

// MARK: - SleepRecord

struct SleepRecord: Identifiable {
    let id: UUID
    var userId: UUID
    var date: Date
    var bedTime: Date
    var wakeTime: Date
    var alarmEnabled: Bool
    var alarmTime: Date?
    var hoursSlept: Float
}

// MARK: - AppPreferences

struct AppPreferences: Identifiable {
    let id: UUID
    var userId: UUID
    var preferMetricUnits: Bool
    var vegFilterDefault: Bool
    var defaultMealType: MealType
    var dailyCalorieGoal: Float
    var dailyMindfulMinutesGoal: Int
    var dailyWaterGoalML: Float
}

// MARK: - NotificationSettings

struct NotificationSettings: Identifiable {
    let id: UUID
    var userId: UUID
    var pushEnabled: Bool
    var mealReminderEnabled: Bool
    var mealReminderTimes: [String]
    var mindfulReminderEnabled: Bool
    var mindfulReminderTime: String
    var waterReminderEnabled: Bool
    var waterReminderIntervalHours: Int
    var bedtimeReminderEnabled: Bool
    var bedtimeReminderMinutesBefore: Int
    var dailyTipEnabled: Bool
    var dailyTipTime: String
    var weeklyScanReminderEnabled: Bool
    var weeklyScanReminderDay: String
    var weeklyScanReminderTime: String
}
