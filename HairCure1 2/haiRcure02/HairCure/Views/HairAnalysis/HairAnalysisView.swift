import SwiftUI
import PhotosUI

struct HairAnalysisView: View {
    let onComplete: () -> Void
    var onBack: (() -> Void)? = nil
    var onSkipToApp: (() -> Void)? = nil
    
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @Bindable var viewModel: HairAnalysisViewModel
    
    @State private var showScanGateSheet = false
    @State private var showAuthSheet = false
    
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
                            Text("Capture 4 scalp photos")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Take clear, well lit photos for accurate AI analysis")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(0..<viewModel.slots.count, id: \.self) { i in
                                PhotoGridCellView(
                                    index: i,
                                    viewModel: viewModel,
                                    isGuest: authVM.isGuestMode,
                                    onGuestTap: {
                                        showScanGateSheet = true
                                    }
                                )
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
                
                if authVM.isGuestMode {
                    Button {
                        onSkipToApp?()
                    } label: {
                        Text("Explore the App")
                            .hcPrimaryButton()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                } else {
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
                    .padding(.bottom, 24)
                }
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
        .fullScreenCover(isPresented: $showScanGateSheet) {
            GuestGateSheetView(
                icon: "camera.viewfinder",
                title: "AI Scalp Analysis",
                message: "Create a free account to unlock our AI scanning tool. You'll get a personalised hair plan, track regrowth, and receive an AI diagnosis.",
                onSignUp: {
                    showScanGateSheet = false
                    // small delay to let sheet dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showAuthSheet = true
                    }
                },
                onDismiss: { showScanGateSheet = false }
            )
        }
        .fullScreenCover(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthLandingView(hideGuestButton: true, onProceed: {
                    showAuthSheet = false
                })
            }
            .environment(store)
            .environment(authVM)
        }
    }
}

// MARK: - Subviews

struct PhotoGridCellView: View {
    let index: Int
    var viewModel: HairAnalysisViewModel
    var isGuest: Bool
    var onGuestTap: () -> Void
    
    var body: some View {
        let slot = viewModel.slots[index]
        return VStack(spacing: 12) {
            Button {
                if isGuest {
                    onGuestTap()
                } else {
                    viewModel.activeSlotId = slot.id
                    viewModel.showingActionSheet = true
                }
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
                                        .foregroundStyle(isGuest ? Color(.systemGray3) : Color.hcBrown.opacity(0.8))
                                    
                                    VStack(spacing: 6) {
                                        Text(isGuest ? "Sign up to unlock" : "Tap to capture")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(isGuest ? Color(.systemGray) : Color.hcBrown)
                                        
                                        if !isGuest {
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
                                
                                if isGuest {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .frame(width: 28, height: 28)
                                                .background(Color.hcBrown.opacity(0.8))
                                                .clipShape(Circle())
                                                .padding(8)
                                        }
                                        Spacer()
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
