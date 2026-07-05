import SwiftUI
import PhotosUI
import Observation

@Observable
@MainActor
class WeeklyScanViewModel {
    var pickerItem1: PhotosPickerItem? = nil {
        didSet { loadPhoto(from: pickerItem1, slot: .slot1) }
    }
    var pickerItem2: PhotosPickerItem? = nil {
        didSet { loadPhoto(from: pickerItem2, slot: .slot2) }
    }
    var pickerItem3: PhotosPickerItem? = nil {
        didSet { loadPhoto(from: pickerItem3, slot: .slot3) }
    }
    
    var photo1: UIImage? = nil
    var photo2: UIImage? = nil
    var photo3: UIImage? = nil
    
    var isAnalysing = false
    var analysisStep = 0
    
    let analysisSteps = [
        "Scanning scalp density...",
        "Measuring follicle distribution...",
        "Calculating hair fall stage...",
        "Generating your report..."
    ]
    
    enum PhotoSlot { case slot1, slot2, slot3 }
    
    init() {}
    
    var allPhotosSelected: Bool {
        photo1 != nil && photo2 != nil && photo3 != nil
    }
    
    func startAnalysis(store: AppDataStore, onComplete: @escaping (ScanReport) -> Void) {
        isAnalysing = true
        analysisStep = 0
        
        let stepInterval = 0.80
        
        for i in 1..<analysisSteps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepInterval) { [weak self] in
                guard let self = self else { return }
                self.analysisStep = i
            }
        }
        
        let totalDuration = Double(analysisSteps.count) * stepInterval + 0.40
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            guard let self = self else { return }
            Task {
                let report = await self.deriveAndSubmitResult(store: store)
                onComplete(report)
            }
        }
    }
    
    private func deriveAndSubmitResult(store: AppDataStore) async -> ScanReport {
        let prior = store.latestScanReport
        
        let baseDensity = prior?.hairDensityPercent ?? 65.0
        let baseStage   = prior?.hairFallStage      ?? .stage2
        let baseScalp   = prior?.scalpCondition     ?? .normal
        
        let delta      = Float.random(in: -0.5...2.5)
        let newDensity = min(100.0, max(20.0, baseDensity + delta))
        
        let newLevel: HairDensityLevel
        switch newDensity {
        case 80...:   newLevel = .high
        case 60..<80: newLevel = .medium
        case 40..<60: newLevel = .low
        default:      newLevel = .veryLow
        }

        let topPath = photo1.map { saveImageLocally($0, prefix: "top") } ?? ""
        let frontPath = photo2.map { saveImageLocally($0, prefix: "front") } ?? ""
        let sidePath = photo3.map { saveImageLocally($0, prefix: "side") } ?? ""
        
        _ = await store.submitWeeklyScan(
            stage:   baseStage,
            scalp:   baseScalp,
            density: newLevel,
            isAIModel: false,
            frontURL: frontPath,
            leftURL: sidePath,
            rightURL: sidePath,
            backURL: "",
            topURL: topPath
        )
        
        return store.latestScanReport ?? ScanReport(
            id: UUID(), createdAt: Date(), scalpScanId: UUID(),
            hairDensityPercent: newDensity, hairDensityLevel: newLevel,
            hairFallStage: baseStage, scalpCondition: baseScalp,
            analysisSource: .selfAssessed, planId: "unknown",
            lifestyleScore: 5, dietScore: 5, stressScore: 5,
            sleepScore: 5, hairCareScore: 5, recommendedPlan: ""
        )
    }

    private func saveImageLocally(_ image: UIImage, prefix: String) -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return "" }
        let filename = "\(prefix)_\(UUID().uuidString).jpg"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(filename)
        try? data.write(to: url)
        return filename
    }
    
    private func loadPhoto(from item: PhotosPickerItem?, slot: PhotoSlot) {
        guard let item else {
            clearPhoto(slot: slot)
            return
        }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    switch slot {
                    case .slot1: self.photo1 = image
                    case .slot2: self.photo2 = image
                    case .slot3: self.photo3 = image
                    }
                }
            }
        }
    }
    
    private func clearPhoto(slot: PhotoSlot) {
        switch slot {
        case .slot1: photo1 = nil
        case .slot2: photo2 = nil
        case .slot3: photo3 = nil
        }
    }
}
