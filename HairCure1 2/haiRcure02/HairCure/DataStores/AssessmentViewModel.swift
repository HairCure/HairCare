import Foundation
import Observation

@Observable
@MainActor
class AssessmentViewModel {
    var currentIndex = 0
    var singleSelections: [UUID: UUID] = [:]
    var multiSelections: [UUID: Set<UUID>] = [:]
    var pickerValues: [UUID: Float] = [:]
    var imageSelections: [UUID: UUID] = [:]
    var textValues: [UUID: String] = [:]
    var isHeightMetric: Bool = true
    var hasStarted: Bool = false
    
    init() {}
    
    func questions(store: AppDataStore) -> [Question] {
        store.assessmentQuestions()
    }
    
    func totalCount(store: AppDataStore) -> Int {
        questions(store: store).count
    }
    
    func currentQuestion(store: AppDataStore) -> Question? {
        let q = questions(store: store)
        guard currentIndex < q.count else { return nil }
        return q[currentIndex]
    }
    
    func startAssessment(store: AppDataStore) {
        store.startAssessment()
        seedPickerDefaults(store: store)
    }
    
    func seedPickerDefaults(store: AppDataStore) {
        let qs = questions(store: store)
        for q in qs where q.questionType == .picker {
            if pickerValues[q.id] == nil {
                let defaultVal: Float
                if q.pickerUnit == "yrs" {
                    defaultVal = 20
                } else if q.pickerUnit == "cm" {
                    defaultVal = 175
                } else if q.pickerUnit == "kg" {
                    defaultVal = 70
                } else {
                    defaultVal = ((q.pickerMin ?? 0) + (q.pickerMax ?? 100)) / 2
                }
                pickerValues[q.id] = defaultVal
                store.savePickerAnswer(questionId: q.id, pickerValue: defaultVal)
            }
        }
    }
    
    func saveSingleChoice(store: AppDataStore, questionId: UUID, optionId: UUID) {
        singleSelections[questionId] = optionId
        store.saveAnswer(questionId: questionId, selectedOptionId: optionId)
    }
    
    func saveMultiChoice(store: AppDataStore, questionId: UUID, optionIds: [UUID]) {
        multiSelections[questionId] = Set(optionIds)
        store.saveMultiAnswer(questionId: questionId, selectedOptionIds: optionIds)
    }
    
    func savePickerValue(store: AppDataStore, questionId: UUID, value: Float) {
        pickerValues[questionId] = value
        store.savePickerAnswer(questionId: questionId, pickerValue: value)
    }
    
    func saveImageChoice(store: AppDataStore, questionId: UUID, optionId: UUID) {
        imageSelections[questionId] = optionId
        store.saveAnswer(questionId: questionId, selectedOptionId: optionId)
    }
    
    func saveFreeText(questionId: UUID, text: String) {
        textValues[questionId] = text
    }
    
    func canContinue(store: AppDataStore) -> Bool {
        guard let q = currentQuestion(store: store) else { return false }
        switch q.questionType {
        case .singleChoice: return singleSelections[q.id] != nil
        case .multiChoice:  return !(multiSelections[q.id]?.isEmpty ?? true)
        case .picker:       return true
        case .imageChoice:  return imageSelections[q.id] != nil
        case .freeText:
            return !(textValues[q.id]?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        }
    }
    
    func advance(store: AppDataStore) {
        let total = totalCount(store: store)
        if currentIndex < total - 1 {
            currentIndex += 1
        }
    }
    
    func handleContinue(store: AppDataStore, onComplete: @escaping () -> Void) {
        guard canContinue(store: store) else { return }
        if currentIndex == totalCount(store: store) - 1 {
            store.completeAssessment()
            onComplete()
        } else {
            advance(store: store)
        }
    }
}
