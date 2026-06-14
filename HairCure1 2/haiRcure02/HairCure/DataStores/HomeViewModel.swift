import SwiftUI
import Observation

@Observable
@MainActor
class HomeViewModel {
    var showCoach = false
    var heroPage = 0
    var pushHairProgress = false
    var pushMealId: UUID? = nil
    var showHydrationSheet = false
    var showSleepSheet = false
    var isMealLogExpanded = true
    var expandedMeals: Set<MealType> = []
    var showNutrientInfo = false
    
    init() {}
    
    func mealIcon(_ type: MealType) -> String {
        switch type {
        case .breakfast: return "cup.and.saucer.fill"
        case .lunch:     return "fork.knife"
        case .snack:     return "takeoutbag.and.cup.and.straw.fill"
        case .dinner:    return "moon.fill"
        }
    }
    
    func mealTimeHint(_ type: MealType) -> String {
        switch type {
        case .breakfast: return "Recommended time : 7:00 – 9:00 AM"
        case .lunch:     return "Recommended time : 12:00 – 2:00 PM"
        case .snack:     return "Recommended time : 4:00 – 5:00 PM"
        case .dinner:    return "Recommended time : 7:00 – 9:00 PM"
        }
    }
    
    func loggedTimeString(_ entry: MealEntry) -> String {
        guard let loggedAt = entry.loggedAt else {
            return "Logged · \(Int(entry.caloriesConsumed)) kcal"
        }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "Logged at \(f.string(from: loggedAt)) · \(Int(entry.caloriesConsumed)) kcal"
    }
    
    func hydrationMessage(metGoal: Bool, stage: Int) -> String {
        if metGoal {
            return "Great job! You've hit your daily hydration goal."
        }
        switch stage {
        case 1:
            return "Stay hydrated to maintain your healthy hair."
        case 2:
            return "Drinking enough water helps reduce hair thinning."
        case 3:
            return "Hydration is crucial — it supports scalp recovery."
        default:
            return "Your hair needs extra care. Keep sipping water throughout the day."
        }
    }
}
