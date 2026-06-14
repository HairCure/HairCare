import SwiftUI
import Observation

@Observable
@MainActor
class WaterDetailsViewModel {
    enum CupSize: String, CaseIterable {
        case small  = "Small"
        case medium = "Medium"
        case large  = "Large"
        
        var ml: Double {
            switch self {
            case .small:  return 150
            case .medium: return 250
            case .large:  return 400
            }
        }
        
        var icon: String {
            switch self {
            case .small:  return "waterbottle"
            case .medium: return "waterbottle.fill"
            case .large:  return "waterbottle.fill"
            }
        }
    }
    
    var selectedCup: CupSize = .medium
    var banner: String? = nil
    var logError: HealthKitManager.HydrationError? = nil
    var showErrorAlert = false
    
    init() {}
    
    func logWater(healthKit: HealthKitManager, targetML: Float) {
        Task {
            do {
                try await healthKit.logWater(amountML: selectedCup.ml)
                let rem = max(0, Double(targetML) - healthKit.todaysWaterML)
                let msg = healthKit.todaysWaterML >= Double(targetML)
                    ? "💧 Daily goal reached! Great job."
                    : "💧 +\(Int(selectedCup.ml)) ml added. \(Int(rem)) ml remaining."
                await MainActor.run {
                    withAnimation { self.banner = msg }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { self.banner = nil }
                    }
                }
            } catch let err as HealthKitManager.HydrationError {
                await MainActor.run {
                    self.logError = err
                    self.showErrorAlert = true
                }
            } catch {
                await MainActor.run {
                    self.logError = .saveFailed(error)
                    self.showErrorAlert = true
                }
            }
        }
    }
}
