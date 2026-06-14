import SwiftUI
import Observation
import PhotosUI

struct HairPhotoSlot: Identifiable {
    let id: String
    let label: String
    let icon: String
    let instruction: String
    var image: UIImage? = nil
}

@Observable
@MainActor
class HairAnalysisViewModel {
    var slots: [HairPhotoSlot] = [
        HairPhotoSlot(id: "front", label: "Front",
                      icon: "arrow.up",
                      instruction: "Hold camera directly above your forehead"),
        HairPhotoSlot(id: "left",  label: "Left Side",
                      icon: "arrow.left",
                      instruction: "Tilt your head slightly to show left temple"),
        HairPhotoSlot(id: "right", label: "Right Side",
                      icon: "arrow.right",
                      instruction: "Tilt your head slightly to show right temple"),
        HairPhotoSlot(id: "back",  label: "Back",
                      icon: "arrow.down",
                      instruction: "Show the back of your head and crown area")
    ]
    
    var activeSlotId: String? = nil
    var showingActionSheet = false
    var showingPicker = false
    var showingCamera = false
    
    var isAnalyzing = false
    var showFallback = false
    var analysisError: String? = nil
    
    private let service = HairAnalysisService()
    
    init() {}
    
    var capturedCount: Int {
        slots.filter { $0.image != nil }.count
    }
    
    var allCaptured: Bool {
        capturedCount == 4
    }
    
    func removePhoto(activeId: String) {
        if let idx = slots.firstIndex(where: { $0.id == activeId }) {
            slots[idx].image = nil
        }
    }
    
    func setPhoto(activeId: String, image: UIImage) {
        if let idx = slots.firstIndex(where: { $0.id == activeId }) {
            slots[idx].image = image
        }
    }
    
    func goToFallback() {
        showFallback = true
    }
    
    func analyzeButtonTapped(store: AppDataStore, onComplete: @escaping () -> Void) async {
        guard allCaptured,
              let frontImg = slots.first(where: { $0.id == "front" })?.image,
              let leftImg  = slots.first(where: { $0.id == "left"  })?.image,
              let rightImg = slots.first(where: { $0.id == "right" })?.image,
              let backImg  = slots.first(where: { $0.id == "back"  })?.image
        else {
            goToFallback()
            return
        }
        
        isAnalyzing = true
        analysisError = nil
        
        do {
            let result = try await service.analyse(
                front: frontImg,
                crown: backImg,
                left:  leftImg,
                right: rightImg
            )
            
            guard result.images_valid.front &&
                  result.images_valid.crown &&
                  result.images_valid.left  &&
                  result.images_valid.right
            else {
                isAnalyzing = false
                analysisError = "One or more photos were unclear. Please retake them."
                return
            }
            
            let frontPath = saveImageLocally(frontImg, prefix: "front")
            let leftPath  = saveImageLocally(leftImg, prefix: "left")
            let rightPath = saveImageLocally(rightImg, prefix: "right")
            let backPath  = saveImageLocally(backImg, prefix: "back")
            
            let densityLevel: HairDensityLevel
            switch result.overall_density_percentage {
            case 76...100: densityLevel = .high
            case 51...75:  densityLevel = .medium
            case 26...50:  densityLevel = .low
            default:       densityLevel = .veryLow
            }
            
            let hairFallStage: HairFallStage
            let norwood = result.norwood_stage.lowercased()
            if norwood.contains("7") || norwood.contains("6") {
                hairFallStage = .stage4
            } else if norwood.contains("5") || norwood.contains("4") {
                hairFallStage = .stage3
            } else if norwood.contains("3") || norwood.contains("2") {
                hairFallStage = .stage2
            } else {
                hairFallStage = .stage1
            }
            
            let scalpCondition: ScalpCondition = .normal
            
            _ = store.submitScanImages(
                frontURL: frontPath,
                leftURL:  leftPath,
                rightURL: rightPath,
                backURL:  backPath,
                topURL:   ""
            )
            
            store.applyAIResult(
                densityPercent: Float(result.overall_density_percentage),
                densityLevel:   densityLevel,
                hairFallStage:  hairFallStage,
                scalpCondition: scalpCondition,
                hairType:       result.hair_type
            )
            
            isAnalyzing = false
            onComplete()
            
        } catch {
            isAnalyzing = false
            analysisError = "Analysis failed. Please try again or skip to manual assessment."
        }
    }
    
    private func saveImageLocally(_ image: UIImage, prefix: String) -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return "" }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("\(prefix)_\(UUID().uuidString).jpg")
        try? data.write(to: url)
        return url.path
    }
}
