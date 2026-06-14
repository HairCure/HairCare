import SwiftUI
import Observation

@Observable
@MainActor
class PlanResultViewModel {
    var cardPage = 0
    var animateBars = false
    var showReferences = false
    var showAuthSheet = false
    var showNorwoodSheet = false
    
    init() {}
    
    func densityLabel(_ pct: Float) -> String {
        switch pct {
        case 80...100: return "High (\(Int(pct))%)"
        case 60..<80:  return "Medium (\(Int(pct))%)"
        case 40..<60:  return "Low (\(Int(pct))%)"
        default:       return "Very Low (\(Int(pct))%)"
        }
    }
    
    func densityColor(_ pct: Float) -> Color {
        switch pct {
        case 80...100: return .green
        case 60..<80:  return .orange
        case 40..<60:  return Color(red: 0.85, green: 0.45, blue: 0.1)
        default:       return .red
        }
    }
    
    func stageColor(_ s: Int) -> Color {
        switch s {
        case 1:  return .green
        case 2:  return .orange
        case 3:  return Color(red: 0.85, green: 0.35, blue: 0.1)
        default: return .red
        }
    }
    
    func scalpLabel(_ c: ScalpCondition) -> String {
        switch c {
        case .dry:      return "Mild Dryness"
        case .dandruff: return "Dandruff"
        case .oily:     return "Oily Scalp"
        case .inflamed: return "Inflamed"
        case .normal:   return "Normal"
        }
    }

    func scalpIcon(_ c: ScalpCondition) -> String {
        switch c {
        case .dry:      return "drop.fill"
        case .dandruff: return "snowflake"
        case .oily:     return "waveform.path"
        case .inflamed: return "flame.fill"
        case .normal:   return "checkmark.seal.fill"
        }
    }

    func scalpPlanItem(_ c: ScalpCondition) -> (String, String) {
        switch c {
        case .dry:
            return ("Scalp Oiling Routine",
                    "Warm coconut or almond oil twice a week — reduces dryness and supports follicle strength")
        case .dandruff:
            return ("Anti-Dandruff Routine",
                    "Zinc-rich foods and anti-fungal shampoo — wash every 2–3 days with ketoconazole formula")
        case .oily:
            return ("Sebum Control",
                    "Wash every 2 days — zinc foods regulate sebum. Avoid heavy oils directly on scalp")
        case .inflamed:
            return ("Soothing Scalp Care",
                    "Omega-3 foods and aloe vera gel twice a week — reduces redness and inflammation")
        case .normal:
            return ("Maintain Scalp Health",
                    "Oil once a week, wash every 2–3 days — keep up the healthy routine")
        }
    }
    
    func mindEaseMinutes(plan: UserPlan?) -> Int {
        guard let p = plan else { return 80 }
        return p.meditationMinutesPerDay + p.yogaMinutesPerDay + p.soundMinutesPerDay
    }
}
