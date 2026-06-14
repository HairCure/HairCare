import SwiftUI
import Observation

@Observable
@MainActor
class SleepDetailsViewModel {
    init() {}
    
    func totalHours(healthKit: HealthKitManager) -> Double {
        healthKit.lastNightSleepHours
    }
    
    func durationText(healthKit: HealthKitManager) -> String {
        let total = healthKit.lastNightSleepHours
        let hours = Int(total)
        let mins = Int((total - Double(hours)) * 60)
        
        if total < 0.1 {
            return "No data"
        }
        return mins == 0 ? "\(hours)h sleep" : "\(hours)h \(mins)m sleep"
    }
    
    func formattedTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
