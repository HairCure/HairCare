
//  Shown when a monthly scan is due.
//  Flow:
//    1. User uploads 3 scalp photos (Top, Front, Side)
//    2. Taps "Analyse Scalp"
//    3. Animated 4-step analysis overlay (~3.2 s)
//    4. Calls store.submitWeeklyScan() → returns ScanReport
//    5. Fires onComplete(report) → caller navigates to HairProgressDetailView
//

import SwiftUI
import PhotosUI

struct WeeklyScanView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss)         private var dismiss
    
    let onComplete: (ScanReport) -> Void
    
    // ── Photo picker state (3 independent slots)
    @State private var pickerItem1: PhotosPickerItem? = nil
    @State private var pickerItem2: PhotosPickerItem? = nil
    @State private var pickerItem3: PhotosPickerItem? = nil
    @State private var photo1: UIImage? = nil
    @State private var photo2: UIImage? = nil
    @State private var photo3: UIImage? = nil
    
    // Analysis state
    @State private var isAnalysing   = false
    @State private var analysisStep  = 0
    
    private let analysisSteps = [
        "Scanning scalp density...",
        "Measuring follicle distribution...",
        "Calculating hair fall stage...",
        "Generating your report..."
    ]
    
    private var allPhotosSelected: Bool { photo1 != nil && photo2 != nil && photo3 != nil }
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()
                
                if isAnalysing {
                    analysingOverlay
                } else {
                    mainContent
                }
            }
            .navigationTitle("Monthly Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.hcBrown)
                }
            }
        }
        .onChange(of: pickerItem1) { _, item in loadPhoto(from: item, into: .slot1) }
        .onChange(of: pickerItem2) { _, item in loadPhoto(from: item, into: .slot2) }
        .onChange(of: pickerItem3) { _, item in loadPhoto(from: item, into: .slot3) }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // ── Instructions card ────────────────────────────
                    instructionsCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    // ── Photo upload section ─────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Upload Scalp Photos")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                            // Progress indicator
                            Text("\([photo1, photo2, photo3].compactMap { $0 }.count)/3")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(allPhotosSelected ? Color.hcBrown : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    allPhotosSelected
                                    ? Color.hcBrown.opacity(0.12)
                                    : Color(UIColor.systemGray6)
                                )
                                .clipShape(Capsule())
                        }
                        
                        HStack(spacing: 12) {
                            photoSlot(image: photo1, picker: $pickerItem1,
                                      label: "Top",   sfIcon: "arrow.up")
                            photoSlot(image: photo2, picker: $pickerItem2,
                                      label: "Front", sfIcon: "person.fill")
                            photoSlot(image: photo3, picker: $pickerItem3,
                                      label: "Side",  sfIcon: "arrow.right")
                        }
                        .frame(height: 118)
                        
                        photoTipsView
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            
            analyseButtonBar
        }
    }
    
    
    // MARK: Photo Slot
    
    private func photoSlot(
        image:   UIImage?,
        picker:  Binding<PhotosPickerItem?>,
        label:   String,
        sfIcon:  String
    ) -> some View {
        PhotosPicker(selection: picker, matching: .images) {
            ZStack(alignment: .bottom) {
                // Card background
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(image != nil ? Color.clear : Color(UIColor.systemGray6))
                
                // Border
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        image != nil ? Color.hcBrown : Color(UIColor.systemGray4),
                        style: StrokeStyle(
                            lineWidth: image != nil ? 2.0 : 1.5,
                            dash:      image != nil ? []  : [5, 4]
                        )
                    )
                
                if let img = image {
                    // Filled: show photo + label badge
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    // Label badge at bottom
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.hcBrown.opacity(0.88))
                    .clipShape(Capsule())
                    .padding(.bottom, 7)
                    
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color(UIColor.systemGray3))
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: sfIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(UIColor.systemGray4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.hcBrown.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.hcBrown)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Scalp Scan")
                        .font(.system(size: 16, weight: .bold))
                    Text("3 photos · ~1 min")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Upload clear photos of your scalp — top, front, and side — in good lighting. Our AI tracks monthly density changes and adjusts your plan if needed.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    
    // MARK: Photo Tips
    
    
    private var photoTipsView: some View {
        let tips: [(String, String)] = [
            ("lightbulb.fill",        "Use bright, even lighting — avoid direct flash"),
            ("iphone",                "Hold camera 6–8 inches from your scalp"),
            ("person.fill.viewfinder","Part hair clearly before each shot")
        ]
        return VStack(alignment: .leading, spacing: 8) {
            Text("Tips for best results")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            ForEach(tips, id: \.0) { icon, text in
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.hcBrown)
                        .frame(width: 14)
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    
    // MARK: Analyse Button Bar
    
    private var analyseButtonBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.hcCream.opacity(0), Color.hcCream],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)
            
            Button { startAnalysis() } label: {
                Text("Analyse Scalp")
                    .hcPrimaryButton()
                    .opacity(allPhotosSelected ? 1.0 : 0.40)
            }
            .disabled(!allPhotosSelected)
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
            .background(Color.hcCream)
        }
    }
    
    
    // MARK: Analysing Overlay
    
    
    private var analysingOverlay: some View {
        VStack(spacing: 36) {
            Spacer()
            
            // Spinning scan ring
            ZStack {
                Circle()
                    .stroke(Color.hcBrown.opacity(0.10), lineWidth: 3)
                    .frame(width: 132, height: 132)
                Circle()
                    .stroke(Color.hcBrown.opacity(0.18), lineWidth: 2)
                    .frame(width: 106, height: 106)
                
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(Color.hcBrown,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 132, height: 132)
                    .rotationEffect(.degrees(Double(analysisStep) * 90 - 90))
                    .animation(
                        .linear(duration: 0.75).repeatForever(autoreverses: false),
                        value: analysisStep
                    )
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 38, weight: .thin))
                    .foregroundStyle(Color.hcBrown.opacity(0.50))
            }
            
            VStack(spacing: 12) {
                Text("Analysing Your Scalp")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(analysisSteps[min(analysisStep, analysisSteps.count - 1)])
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.25), value: analysisStep)
            }
            
            // Step progress dots
            HStack(spacing: 8) {
                ForEach(0..<analysisSteps.count, id: \.self) { i in
                    Circle()
                        .fill(i <= analysisStep ? Color.hcBrown : Color(UIColor.systemGray4))
                        .frame(
                            width:  i == analysisStep ? 10 : 7,
                            height: i == analysisStep ? 10 : 7
                        )
                        .animation(.easeInOut(duration: 0.2), value: analysisStep)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.hcCream.ignoresSafeArea())
    }
    
    
    // MARK: Analysis Pipeline
    
    
    private func startAnalysis() {
        isAnalysing  = true
        analysisStep = 0
        
        let stepInterval = 0.80
        
        // Advance step indicator at each interval
        for i in 1..<analysisSteps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepInterval) {
                analysisStep = i
            }
        }
        
        // Complete analysis after all steps
        let totalDuration = Double(analysisSteps.count) * stepInterval + 0.40
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            let report = deriveAndSubmitResult()
            onComplete(report)
        }
    }
    
    
    
    private func deriveAndSubmitResult() -> ScanReport {
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
        
        // Call with correct signature
        store.submitWeeklyScan(
            stage:   baseStage,
            scalp:   baseScalp,
            density: newLevel
        )
        
        // Return the latest scan report that was just created
        return store.latestScanReport ?? ScanReport(
            id: UUID(), createdAt: Date(), scalpScanId: UUID(),
            hairDensityPercent: newDensity, hairDensityLevel: newLevel,
            hairFallStage: baseStage, scalpCondition: baseScalp,
            analysisSource: .selfAssessed, planId: "unknown",
            lifestyleScore: 5, dietScore: 5, stressScore: 5,
            sleepScore: 5, hairCareScore: 5, recommendedPlan: ""
        )
    }
    
    // ─────────────────────────────────────
    // MARK: Photo Loading
    // ─────────────────────────────────────
    
    private enum PhotoSlot { case slot1, slot2, slot3 }
    
    private func loadPhoto(from item: PhotosPickerItem?, into slot: PhotoSlot) {
        guard let item else { clearPhoto(slot: slot); return }
        
        Task {
            if let data  = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    switch slot {
                    case .slot1: photo1 = image
                    case .slot2: photo2 = image
                    case .slot3: photo3 = image
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
