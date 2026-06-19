
import SwiftUI

struct WellnessView: View {
    @Environment(AppDataStore.self)  private var store
    @Environment(AuthViewModel.self) private var authVM

    @State private var selectedSegment: WellnessSegment = .dietMate

    // Guest gate — pushed as a navigation destination so tab bar + back button stay visible
    @State private var pushGuestGate  = false
    @State private var showAuthSheet  = false
    @State private var guestGateConfig: GuestGateConfig = GuestGateConfig(
        icon: "fork.knife",
        title: "Personalised Diet Tracking",
        message: "Create a free account to log meals, track hair-boosting nutrients, and get personalised calorie targets."
    )

    enum WellnessSegment: String, CaseIterable {
        case dietMate = "DietMate"
        case mindEase = "MindEase"
    }

    // Closures passed into child views
    private var dietMateGuestTap: () -> Void {
        {
            guestGateConfig = GuestGateConfig(
                icon: "fork.knife",
                title: "Personalised Diet Tracking",
                message: "Create a free account to log meals, track hair-boosting nutrients, and get personalised calorie targets."
            )
            pushGuestGate = true
        }
    }

    private var mindEaseGuestTap: () -> Void {
        {
            guestGateConfig = GuestGateConfig(
                icon: "figure.mind.and.body",
                title: "Guided Mindfulness Sessions",
                message: "Create a free account to access meditation, yoga, and sound therapy sessions designed to reduce stress-related hair loss."
            )
            pushGuestGate = true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pickerBar

                ZStack {
                    if selectedSegment == .dietMate {
                        DietMateView(onGuestTap: dietMateGuestTap)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal:   .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        MindEaseView(onGuestTap: mindEaseGuestTap)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.38, dampingFraction: 0.85), value: selectedSegment)
            }
            .background(Color.hcCream.ignoresSafeArea())
            .navigationTitle("Wellness")
            .navigationBarTitleDisplayMode(.large)
            // ── Guest gate pushed as nav destination (tab bar + back button stay visible) ──
            .navigationDestination(isPresented: $pushGuestGate) {
                GuestGatePage(
                    config: guestGateConfig,
                    onSignUp: {
                        pushGuestGate = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showAuthSheet = true
                        }
                    },
                    onDismiss: { pushGuestGate = false }
                )
            }
        }
        // Auth landing shown as a sheet after the user taps "Create Free Account"
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


#Preview {
    WellnessView()
        .environment(AppDataStore())
}
