
import SwiftUI

struct WellnessView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @State private var selectedSegment: WellnessSegment = .dietMate
    @State private var showAuthSheet = false

    enum WellnessSegment: String, CaseIterable {
        case dietMate = "DietMate"
        case mindEase = "MindEase"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                
                pickerBar

                ZStack {
                    if selectedSegment == .dietMate {
                        DietMateView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal:   .move(edge: .trailing).combined(with: .opacity)
                            ))
                            .guestGate(
                                isGuest: authVM.isGuestMode,
                                icon: "fork.knife",
                                title: "Personalised Diet Tracking",
                                message: "Create a free account to log meals, track hair-boosting nutrients, and get personalised calorie targets.",
                                onSignUp: { showAuthSheet = true }
                            )
                    } else {
                        MindEaseView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                            .guestGate(
                                isGuest: authVM.isGuestMode,
                                icon: "figure.mind.and.body",
                                title: "Guided Mindfulness Sessions",
                                message: "Create a free account to access meditation, yoga, and sound therapy sessions designed to reduce stress-related hair loss.",
                                onSignUp: { showAuthSheet = true }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.38, dampingFraction: 0.85), value: selectedSegment)
            }
            .background(Color.hcCream.ignoresSafeArea())
            .navigationTitle("Wellness")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthLandingView(hideGuestButton: true, onProceed: {
                    showAuthSheet = false
                })
            }
        }
    }

    // MARK: - Picker Bar

    private var pickerBar: some View {
        Picker("Wellness", selection: $selectedSegment) {
            ForEach(WellnessSegment.allCases, id: \.self) { seg in
                Text(seg.rawValue).tag(seg)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.hcCream)
    }
}

// MARK: - MindEase Placeholder

private struct MindEasePlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 0.9))
                .symbolEffect(.pulse)          
            Text("MindEase")
                .font(.system(size: 24, weight: .semibold))
            Text("Coming soon")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview {
    WellnessView()
        .environment(AppDataStore())
}
