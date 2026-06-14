import Foundation
import Observation

@Observable
@MainActor
class FallbackAssessmentViewModel {
    var pendingScalp: ScalpCondition = .normal
    var pendingDensity: HairDensityLevel = .medium
    var showAuthSheet = false
    var currentIndex = 0
    var stageOptionId: UUID? = nil
    var scalpOptionId: UUID? = nil
    var densityOptionId: UUID? = nil
    var showDoctorAlert = false
    var doctorMessage = ""
    
    init() {}
    
    func questions(store: AppDataStore) -> [Question] {
        store.fallbackQuestions()
    }
    
    func totalCount(store: AppDataStore) -> Int {
        questions(store: store).count
    }
    
    func currentQuestion(store: AppDataStore) -> Question? {
        let qs = questions(store: store)
        guard currentIndex < qs.count else { return nil }
        return qs[currentIndex]
    }
    
    func canContinue() -> Bool {
        switch currentIndex {
        case 0: return stageOptionId != nil
        case 1: return scalpOptionId != nil
        case 2: return densityOptionId != nil
        default: return true
        }
    }
    
    func handleContinue(authVM: AuthViewModel, store: AppDataStore, onComplete: @escaping () -> Void) {
        let total = totalCount(store: store)
        if currentIndex < total - 1 {
            currentIndex += 1
            return
        }
        
        if authVM.isGuestMode {
            showAuthSheet = true
        } else {
            submitToEngine(store: store, onComplete: onComplete)
        }
    }
    
    func submitToEngine(store: AppDataStore, onComplete: @escaping () -> Void) {
        let stage = resolveStage(store: store)
        let scalp = resolveScalp(store: store)
        let density = resolveDensity(store: store)
        
        let result = store.submitSelfAssessedStage(
            stage: stage, scalp: scalp, density: density
        )
        
        switch result {
        case .referDoctor(let msg):
            doctorMessage = msg
            showDoctorAlert = true
            
            pendingScalp = scalp
            pendingDensity = density
        default:
            onComplete()
        }
    }
    
    func resolveStage(store: AppDataStore) -> HairFallStage {
        let qs = questions(store: store)
        guard let optId = stageOptionId,
              let q = qs.first(where: { $0.questionOrderIndex == 11 }),
              let opt = store.options(for: q.id).first(where: { $0.id == optId })
        else { return .stage2 }
        
        switch opt.optionOrderIndex {
        case 1: return .stage1
        case 2: return .stage2
        case 3: return .stage3
        case 4: return .stage4
        default: return .stage2
        }
    }
    
    func resolveScalp(store: AppDataStore) -> ScalpCondition {
        let qs = questions(store: store)
        guard let optId = scalpOptionId,
              let q = qs.first(where: { $0.questionOrderIndex == 12 }),
              let opt = store.options(for: q.id).first(where: { $0.id == optId })
        else { return .normal }
        
        let text = opt.optionText.lowercased()
        if text.contains("flak") || text.contains("dandruff") { return .dandruff }
        if text.contains("tight") || text.contains("dry")     { return .dry }
        if text.contains("greasy") || text.contains("oily")   { return .oily }
        if text.contains("red") || text.contains("inflam")    { return .inflamed }
        return .normal
    }
    
    func resolveDensity(store: AppDataStore) -> HairDensityLevel {
        let qs = questions(store: store)
        guard let optId = densityOptionId,
              let q = qs.first(where: { $0.questionOrderIndex == 13 }),
              let opt = store.options(for: q.id).first(where: { $0.id == optId })
        else { return .medium }
        
        let text = opt.optionText.lowercased()
        if text.contains("thick")      { return .high }
        if text.contains("medium")     { return .medium }
        if text.contains("very thin")  { return .veryLow }
        if text.contains("thin")       { return .low }
        return .medium
    }
}
