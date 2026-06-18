import SwiftUI

enum AppRoute: Hashable {
    case auth
    case assessment
    case hairAnalysis
    case planResults
    case mainApp
}

struct ContentView: View {
    @Environment(AuthViewModel.self) var authVM
    @Environment(AppDataStore.self) var store
    @State private var route: AppRoute = .auth
    @State private var selectedTab = 0
    /// Becomes true once the post-login route (mainApp / assessment) has been resolved.
    /// Keeps the splash screen visible until we know where to send a returning user.
    @State private var isRouteResolved: Bool = false
    @State private var isInitialLoad: Bool = true
    @State private var analysisViewModel = HairAnalysisViewModel()
    @State private var assessmentInitialIndex = 0

    var body: some View {
        Group {
            if (authVM.isLoading && isInitialLoad) || (authVM.isLoggedIn && !isRouteResolved) {
                // Splash / loading screen — also shown while we resolve the route
                // for a returning logged-in user, to prevent AuthLandingView from flashing.
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                }
            } else if !authVM.isLoggedIn && !authVM.isGuestMode {
                AuthLandingView {
                    if authVM.isGuestMode {
                        // Guest user is already created in AuthLandingView — just navigate
                        withAnimation(.easeInOut(duration: 0.3)) {
                            route = .assessment
                        }
                    } else {
                        // After login — reset stale state then create user in store with real ID
                        store.resetForLogout()
                        store.createUser(
                            name: authVM.userName ?? "User",
                            email: authVM.userEmail ?? "",
                            authProvider: .google,
                            supabaseId: authVM.currentUserId
                        )
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // Returning user with a completed scan → skip assessment
                            if store.latestScanReport != nil {
                                route = .mainApp
                            } else {
                                route = .assessment
                            }
                        }
                    }
                } guestUpgrade: { newUserId, name, email in
                    // Guest→Authenticated upgrade from within the app
                    handleGuestUpgrade(newUserId: newUserId, name: name, email: email)
                }
            } else {
                // Already logged in — go straight to app
                switch route {
                case .auth:
                    AuthLandingView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            route = .assessment
                        }
                    }
                case .assessment:
                    AssessmentView(onComplete: {
                        assessmentInitialIndex = 0
                        withAnimation(.easeInOut(duration: 0.3)) {
                            route = .hairAnalysis
                        }
                    }, onBack: {
                        assessmentInitialIndex = 0
                        withAnimation(.easeInOut(duration: 0.3)) {
                            route = .auth
                        }
                    }, initialIndex: assessmentInitialIndex)
                    .transition(.opacity)
                case .hairAnalysis:
                    HairAnalysisView(onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            route = .planResults
                        }
                    }, onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            assessmentInitialIndex = 7
                            route = .assessment
                        }
                    }, onSkipToApp: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 0
                            route = .mainApp
                        }
                    }, viewModel: analysisViewModel)
                    .transition(.opacity)
                case .planResults:
                    PlanResultsView(onStart: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 0   // Always land on Home tab
                            route = .mainApp
                        }
                    }, onRetake: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            route = .hairAnalysis
                        }
                    })
                    .transition(.opacity)
                case .mainApp:
                    TabView(selection: $selectedTab) {
                        HomeView(selectedTab: $selectedTab)
                            .tabItem { Label("Home", systemImage: "house.fill") }
                            .tag(0)
                        WellnessView()
                            .tabItem { Label("Wellness", systemImage: "heart.fill") }
                            .tag(1)
                        HairInsightsView()
                            .tabItem { Label("Hair Insights", systemImage: "lightbulb.fill") }
                            .tag(2)
                        ProfileView()
                            .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                            .tag(3)
                    }
                    .accentColor(Color.hcBrown)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            if authVM.isLoggedIn {
                Task {
                    print("Checking assessment for userId: \(store.currentUserId)")
                    let hasAssessment = await BackendService.shared.fetchAssessment(
                        userId: store.currentUserId
                    )
                    print("Has assessment: \(hasAssessment)")
                    await MainActor.run {
                        route = hasAssessment ? .mainApp : .assessment
                    }
                }
            }
        }
        .onChange(of: authVM.isLoading) { _, isLoading in
            guard !isLoading else { return }
            isInitialLoad = false
            if authVM.isLoggedIn {
                // Reset any stale data from a previous session BEFORE setting up the new user
                store.resetForLogout()
                store.createUser(
                    name: authVM.userName ?? "User",
                    email: authVM.userEmail ?? "",
                    authProvider: .google,
                    supabaseId: authVM.currentUserId
                )

                // Keep loading screen visible until we know where to send the user.
                // NOTE: loadScanReports() runs AFTER createUser() has finished setting
                // currentUserId — sequential, not parallel, to avoid the race condition.
                Task {
                    guard let userIdString = authVM.currentUserId,
                          let userId = UUID(uuidString: userIdString) else {
                        await MainActor.run {
                            route = .mainApp
                            isRouteResolved = true
                        }
                        return
                    }

                    print("store.currentUserId: \(store.currentUserId)")
                    print("authVM.currentUserId: \(userIdString)")

                    // Step 1: Load scan records FIRST (sequential — needs currentUserId set above)
                    await store.loadScanReports()
                    // Run scalpScans + profile/nutrition restore in parallel (both need currentUserId)
                    async let scalpTask: () = store.loadScalpScans()
                    async let userDataTask: () = store.loadUserData()
                    await (scalpTask, userDataTask)

                    // Step 2: Load favourites and check assessment in parallel (no userId dependency on store)
                    async let favTask: () = store.hairInsightsStore.loadFavourites(userId: userId)
                    async let assessmentTask = BackendService.shared.fetchAssessment(userId: userId)
                    let (_, hasAssessment) = await (favTask, assessmentTask)
                    print("Has assessment: \(hasAssessment)")

                    let hairType = store.latestScanReport?.hairType
                    await store.hairInsightsStore.loadContent(hairType: hairType)

                    await MainActor.run {
                        // Navigate directly to the right place — no flash
                        route = hasAssessment ? .mainApp : .assessment
                        isRouteResolved = true
                    }
                }
            } else if authVM.isGuestMode {
                // Guest session restored — skip backend loads, go to route
                isRouteResolved = true
                if route == .auth { route = .assessment }
            } else {
                // Not logged in — show AuthLandingView immediately
                isRouteResolved = true
            }
        }
    }
    
    // MARK: - Guest → Authenticated Upgrade
    
    /// Handles the transition from guest to authenticated user.
    /// Migrates in-memory data, clears guest flags, and navigates appropriately.
    private func handleGuestUpgrade(newUserId: UUID, name: String, email: String) {
        // Migrate all guest data to the new authenticated account
        store.migrateGuestData(toUserId: newUserId, name: name, email: email)
        
        // Clear guest flags
        authVM.upgradeGuestToUser()
        authVM.currentUserId = newUserId.uuidString
        authVM.userName = name
        authVM.userEmail = email
        authVM.isLoggedIn = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if store.latestScanReport != nil {
                route = .mainApp
            } else if store.assessments.contains(where: { $0.userId == newUserId && $0.completedAt != nil }) {
                route = .hairAnalysis
            } else {
                route = .assessment
            }
        }
    }
}

#Preview {
    ContentView()
}
