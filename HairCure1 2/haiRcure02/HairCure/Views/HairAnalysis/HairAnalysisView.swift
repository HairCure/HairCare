import SwiftUI
import PhotosUI

private struct PhotoSlot: Identifiable {
    let id: String
    let label: String
    let icon: String
    let instruction: String
    var image: UIImage? = nil
}

struct HairAnalysisView: View {
    let onComplete: () -> Void

    @Environment(AppDataStore.self) private var store

    @State private var slots: [PhotoSlot] = [
        PhotoSlot(id: "front", label: "Front",
                  icon: "arrow.up",
                  instruction: "Hold camera directly above your forehead"),
        PhotoSlot(id: "left",  label: "Left Side",
                  icon: "arrow.left",
                  instruction: "Tilt your head slightly to show left temple"),
        PhotoSlot(id: "right", label: "Right Side",
                  icon: "arrow.right",
                  instruction: "Tilt your head slightly to show right temple"),
        PhotoSlot(id: "back",  label: "Back",
                  icon: "arrow.down",
                  instruction: "Show the back of your head and crown area")
    ]

    @State private var activeSlotId: String?
    @State private var showingActionSheet = false
    @State private var showingPicker  = false
    @State private var showingCamera  = false
    
    @State private var isAnalyzing    = false
    @State private var showFallback   = false
    @State private var analysisError: String? = nil

    private let service = HairAnalysisService()

    private var capturedCount: Int { slots.filter { $0.image != nil }.count }
    private var allCaptured: Bool { capturedCount == 4 }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.hcCream.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Capture 4 scalp views")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Take clear, well-lit photos for accurate AI analysis")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(0..<slots.count, id: \.self) { i in
                                photoGridCell(index: i)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            Divider()
                                .padding(.horizontal, 20)
                            Text("\(capturedCount) of 4 photos captured")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.top, 16)

                            if let error = analysisError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()
                Button {
                    Task { await analyzeButtonTapped() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15))
                        Text(allCaptured ? "Analyze My Scalp" : "Skip to Manual Assessment")
                    }
                    .hcPrimaryButton()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }

            if isAnalyzing { analyzingOverlay }
        }
        .confirmationDialog("Add Photo", isPresented: $showingActionSheet, titleVisibility: .visible) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingPicker = true }
            
            if let activeId = activeSlotId, slots.first(where: { $0.id == activeId })?.image != nil {
                Button("Remove Photo", role: .destructive) {
                    if let idx = slots.firstIndex(where: { $0.id == activeId }) {
                        slots[idx].image = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { activeSlotId = nil }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                if let activeId = activeSlotId, let idx = slots.firstIndex(where: { $0.id == activeId }) {
                    slots[idx].image = image
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                if let activeId = activeSlotId, let idx = slots.firstIndex(where: { $0.id == activeId }) {
                    slots[idx].image = image
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showFallback) {
            FallbackAssessmentView(onComplete: onComplete)
        }
    }

    private var navBar: some View {
        HStack {
            HCBackButton { goToFallback() }
            Spacer()
            Button("Skip") { goToFallback() }
                .font(.system(size: 16))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
    }

    private func photoGridCell(index i: Int) -> some View {
        let slot = slots[i]
        return VStack(spacing: 12) {
            Button {
                activeSlotId = slot.id
                showingActionSheet = true
            } label: {
                // Perfect 1:1 square for consistency and to prevent grid bleed
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        ZStack {
                            if let img = slot.image {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                
                                // Clean subtle retake overlay
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 32, height: 32)
                                            .background(.black.opacity(0.4))
                                            .clipShape(Circle())
                                            .padding(8)
                                    }
                                    Spacer()
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                    .foregroundStyle(Color(.systemGray4))

                                VStack(spacing: 12) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 38, weight: .light))
                                        .foregroundStyle(Color.hcBrown.opacity(0.8))

                                    VStack(spacing: 6) {
                                        Text("Tap to capture")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.hcBrown)
                                        
                                        Text(slot.instruction)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 16)
                                            .lineLimit(3)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    // Soft shadow makes the empty cards feel highly native
                    .shadow(color: .black.opacity(slot.image == nil ? 0.04 : 0), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Text(slot.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView().scaleEffect(1.4).tint(.white)
                Text("Analyzing your scalp…")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
            }
            .padding(36)
            .background(Color(red: 0.15, green: 0.1, blue: 0.1).opacity(0.92))
            .cornerRadius(20)
        }
    }

    private func analyzeButtonTapped() async {
        guard allCaptured,
              let frontImg = slots.first(where: { $0.id == "front" })?.image,
              let leftImg  = slots.first(where: { $0.id == "left"  })?.image,
              let rightImg = slots.first(where: { $0.id == "right" })?.image,
              let backImg  = slots.first(where: { $0.id == "back"  })?.image
        else {
            goToFallback()
            return
        }

        isAnalyzing   = true
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
                await MainActor.run {
                    isAnalyzing   = false
                    analysisError = "One or more photos were unclear. Please retake them."
                }
                return
            }

            // Save images locally so PlanResultView can display them
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

            let _ = store.submitScanImages(
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

            await MainActor.run {
                isAnalyzing = false
                onComplete()
            }

        } catch {
            await MainActor.run {
                isAnalyzing   = false
                analysisError = "Analysis failed. Please try again or skip to manual assessment."
            }
        }
    }

    private func goToFallback() {
        showFallback = true
    }

    private func saveImageLocally(_ image: UIImage, prefix: String) -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return "" }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("\(prefix)_\(UUID().uuidString).jpg")
        try? data.write(to: url)
        return url.path
    }
}



#Preview {
    HairAnalysisView { print("Completed") }
        .environment(AppDataStore())
}
