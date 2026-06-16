import SwiftUI
import PhotosUI

struct HairAnalysisView: View {
    let onComplete: () -> Void
    var onBack: (() -> Void)? = nil

    @Environment(AppDataStore.self) private var store
    @Bindable var viewModel: HairAnalysisViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.hcCream.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    HCBackButton {
                        onBack?()
                    }
                    .opacity(onBack != nil ? 1 : 0)
                    .disabled(onBack == nil)
                    Spacer()
                }
                .padding(.horizontal, 16)
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
                                ForEach(0..<viewModel.slots.count, id: \.self) { i in
                                    PhotoGridCellView(index: i, viewModel: viewModel)
                                }
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                Divider()
                                    .padding(.horizontal, 20)
                                Text("\(viewModel.capturedCount) of 4 photos captured")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 16)

                                if let error = viewModel.analysisError {
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

            VStack(spacing: 12) {
                Spacer()
                Button {
                    Task { await viewModel.analyzeButtonTapped(store: store, onComplete: onComplete) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15))
                        Text("Analyze My Scalp")
                    }
                    .hcPrimaryButton()
                    .opacity(viewModel.allCaptured ? 1.0 : 0.5)
                }
                .disabled(!viewModel.allCaptured)
                .padding(.horizontal, 20)
                
                Button {
                    viewModel.submitManualStage(store: store, onComplete: onComplete)
                } label: {
                    Text("Skip & Generate Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.hcBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            if viewModel.isAnalyzing {
                HairAnalyzingOverlayView()
            }
        }
        .confirmationDialog("Add Photo", isPresented: $viewModel.showingActionSheet, titleVisibility: .visible) {
            Button("Take Photo") { viewModel.showingCamera = true }
            Button("Choose from Library") { viewModel.showingPicker = true }
            
            if let activeId = viewModel.activeSlotId, viewModel.slots.first(where: { $0.id == activeId })?.image != nil {
                Button("Remove Photo", role: .destructive) {
                    viewModel.removePhoto(activeId: activeId)
                }
            }
            Button("Cancel", role: .cancel) { viewModel.activeSlotId = nil }
        }
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                if let activeId = viewModel.activeSlotId {
                    viewModel.setPhoto(activeId: activeId, image: image)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $viewModel.showingPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                if let activeId = viewModel.activeSlotId {
                    viewModel.setPhoto(activeId: activeId, image: image)
                }
            }
            .ignoresSafeArea()
        }
        .alert("Doctor Consultation Recommended", isPresented: $viewModel.showDoctorAlert) {
            Button("Understood") { onComplete() }
        } message: {
            Text(viewModel.doctorMessage)
        }
    }
}

// MARK: - Subviews

struct PhotoGridCellView: View {
    let index: Int
    var viewModel: HairAnalysisViewModel
    
    var body: some View {
        let slot = viewModel.slots[index]
        return VStack(spacing: 12) {
            Button {
                viewModel.activeSlotId = slot.id
                viewModel.showingActionSheet = true
            } label: {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        ZStack {
                            if let img = slot.image {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                
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
}

struct HairAnalyzingOverlayView: View {
    var body: some View {
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
}

struct ManualStageImageGridView: View {
    var viewModel: HairAnalysisViewModel
    var store: AppDataStore
    
    var body: some View {
        let qs = store.fallbackQuestions()
        if let q = qs.first(where: { $0.questionOrderIndex == 11 }) {
            let opts = store.options(for: q.id)
            let selected = viewModel.manualStageOptionId
            let columns = [GridItem(.flexible(), spacing: 16),
                           GridItem(.flexible(), spacing: 16)]
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(opts) { opt in
                    let isSel = selected == opt.id
                    Button {
                        viewModel.manualStageOptionId = opt.id
                        store.saveAnswer(questionId: q.id, selectedOptionId: opt.id)
                    } label: {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            isSel ? Color.hcBrown : Color(.systemGray5),
                                            lineWidth: isSel ? 2.5 : 1
                                        )
                                )
                            
                            VStack(spacing: 0) {
                                ManualStageImageView(imageURL: opt.imageURL, index: opt.optionOrderIndex)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 130)
                                    .clipped()
                            }
                            
                            Text("\(opt.optionOrderIndex)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                                .padding(8)
                        }
                        .frame(height: 150)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ManualStageImageView: View {
    let imageURL: String?
    let index: Int
    
    var body: some View {
        if let url = imageURL, UIImage(named: url) != nil {
            Image(url)
                .resizable()
                .scaledToFit()
                .padding(12)
        } else {
            ZStack {
                Color(.systemGray6)
                VStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(.systemGray3))
                    Text("Stage \(index)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.systemGray2))
                }
            }
        }
    }
}
