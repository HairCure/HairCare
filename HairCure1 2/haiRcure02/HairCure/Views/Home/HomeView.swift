import SwiftUI
import HealthKit
import Charts

private let heroCardHeight: CGFloat = 218

struct HomeView: View {
    @Binding var selectedTab: Int

    @Environment(AppDataStore.self) private var store
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(AuthViewModel.self) private var authVM
    
    @State private var viewModel = HomeViewModel()
    @State private var showAuthSheet = false
    @State private var showGuestGateSheet = false
    @State private var guestGateConfig: (icon: String, title: String, message: String) = ("lock.shield.fill", "", "")

    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Guest banner
                        if authVM.isGuestMode {
                            GuestBannerView(
                                daysRemaining: authVM.guestDaysRemaining,
                                onSignUp: { showAuthSheet = true }
                            )
                        }
                        
                        HomeHeroCardsSectionView(viewModel: viewModel, store: store)
                        HomeFeatureCardsSectionView(viewModel: viewModel, store: store, healthKit: healthKit)
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $viewModel.pushMealId) { mealId in
                if authVM.isGuestMode {
                    GuestGateSheetView(
                        icon: "fork.knife",
                        title: "Log Your Meals",
                        message: "Create a free account to track meals, monitor nutrients, and get personalised diet recommendations for healthier hair.",
                        onSignUp: { showAuthSheet = true },
                        onDismiss: { viewModel.pushMealId = nil }
                    )
                } else {
                    AddMealView(mealEntryId: mealId)
                }
            }
            .navigationDestination(isPresented: $viewModel.pushHairProgress) {
                if authVM.isGuestMode {
                    GuestGateSheetView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Track Hair Progress",
                        message: "Create a free account to track your hair health over time, compare scans, and see your improvement journey.",
                        onSignUp: { showAuthSheet = true },
                        onDismiss: { viewModel.pushHairProgress = false }
                    )
                } else {
                    HairProgressView()
                        .environment(store)
                }
            }
            .onAppear {
                Task {
                    await healthKit.refresh()
                }
            }
        }
        .sheet(isPresented: $viewModel.showCoach) {
            CoachView(viewModel: CoachViewModel())
        }
        .sheet(isPresented: $viewModel.showHydrationSheet) {
            if authVM.isGuestMode {
                GuestGateSheetView(
                    icon: "drop.fill",
                    title: "Track Your Water Intake",
                    message: "Create a free account to log water, track your hydration goals, and get personalised water targets.",
                    onSignUp: {
                        viewModel.showHydrationSheet = false
                        showAuthSheet = true
                    },
                    onDismiss: { viewModel.showHydrationSheet = false }
                )
            } else {
                WaterDetailsSheet(healthKit: healthKit, targetML: store.activeNutritionProfile?.waterTargetML ?? 2500)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(28)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $viewModel.showSleepSheet) {
            if authVM.isGuestMode {
                GuestGateSheetView(
                    icon: "moon.zzz.fill",
                    title: "Track Your Sleep",
                    message: "Create a free account to log sleep patterns, set bedtime reminders, and see how sleep affects your hair health.",
                    onSignUp: {
                        viewModel.showSleepSheet = false
                        showAuthSheet = true
                    },
                    onDismiss: { viewModel.showSleepSheet = false }
                )
            } else {
                SleepDetailsSheet(healthKit: healthKit)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(28)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $viewModel.showNutrientInfo) {
            NutrientInfoSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthLandingView(hideGuestButton: true, onProceed: {
                    showAuthSheet = false
                })
            }
        }
    }
}

// MARK: - Subviews for HomeView

struct HomeHeroCardsSectionView: View {
    var viewModel: HomeViewModel
    var store: AppDataStore
    
    var body: some View {
        @Bindable var vm = viewModel
        
        return VStack(spacing: 10) {
            TabView(selection: $vm.heroPage) {
                HomeHairHealthCardView(viewModel: viewModel, store: store)
                    .padding(.horizontal, 4)
                    .tag(0)

                HomeAICoachCardView(viewModel: viewModel)
                    .padding(.horizontal, 4)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: heroCardHeight)
            .background(Color.clear)

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(viewModel.heroPage == i ? Color.hcBrown : Color(.systemGray4))
                        .frame(width: viewModel.heroPage == i ? 10 : 7,
                               height: viewModel.heroPage == i ? 10 : 7)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.heroPage)
                }
            }
        }
    }
}

struct HomeHairHealthCardView: View {
    var viewModel: HomeViewModel
    var store: AppDataStore
    
    var body: some View {
        let report = store.latestScanReport
        let plan = store.activePlan
        let hasReport = report != nil
        let density   = report?.hairDensityPercent ?? 0
        let stage     = report?.hairFallStage.intValue ?? plan?.stage ?? 2
        
        let (severityLabel, severityColor): (String, Color) = {
            switch stage {
            case 1: return ("Healthy",  Color(red: 0.22, green: 0.78, blue: 0.45))
            case 2: return ("Moderate", Color(red: 1.00, green: 0.60, blue: 0.15))
            case 3: return ("Severe",   Color(red: 0.95, green: 0.32, blue: 0.22))
            default: return ("Critical", Color(red: 0.85, green: 0.15, blue: 0.15))
            }
        }()
        
        let dateString: String = {
            guard let date = report?.createdAt else { return "N/A" }
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }()
        
        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.424, green: 0.298, blue: 0.302), location: 0.0),
                        .init(color: Color(red: 0.298, green: 0.192, blue: 0.196), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color(red: 0.953, green: 0.933, blue: 0.851).opacity(0.14), .clear],
                    center: .init(x: 0.75, y: 0.25),
                    startRadius: 10,
                    endRadius: 160
                )

                RadialGradient(
                    colors: [Color(red: 0.424, green: 0.298, blue: 0.302).opacity(0.30), .clear],
                    center: .init(x: 0.15, y: 0.80),
                    startRadius: 5,
                    endRadius: 120
                )

                VStack(spacing: 12) {
                    // Top Row: Title & Severity Badge
                    HStack(alignment: .center) {
                        Text("Hair Health Score")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(severityLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(severityColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .stroke(severityColor, lineWidth: 1)
                            )
                    }
                    
                    // Columns Row: Density, Stage, Last Scanned
                    HStack(alignment: .center, spacing: 0) {
                        // Density Column
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text(hasReport ? "\(Int(density))" : "--")
                                    .font(.system(size: 46, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .frame(height: 46)
                            
                            Text("Density")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Divider 1
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 40)
                            .padding(.horizontal, 8)
                        
                        // Stage Column
                        VStack(alignment: .center, spacing: 4) {
                            Text("Stage")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text("\(stage)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 64, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Divider 2
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 40)
                            .padding(.horizontal, 8)
                        
                        // Last Scanned Column
                        VStack(alignment: .center, spacing: 4) {
                            Text("Last Scanned")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(dateString)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 82, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .frame(height: heroCardHeight - 50)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 18
            ))

            Button {
                viewModel.pushHairProgress = true
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.28, green: 0.14, blue: 0.08))
                        .frame(width: 26)
                    
                    Text("View Hair Progress")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.08, blue: 0.05))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 18)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.hcCream)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 18,
                bottomTrailingRadius: 18, topTrailingRadius: 0
            ))
        }
        .frame(height: heroCardHeight)
        .background(Color.hcCream)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct HomeAICoachCardView: View {
    var viewModel: HomeViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.424, green: 0.298, blue: 0.302), location: 0.0),
                        .init(color: Color(red: 0.298, green: 0.192, blue: 0.196), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color(red: 0.953, green: 0.933, blue: 0.851).opacity(0.14), .clear],
                    center: .init(x: 0.75, y: 0.25),
                    startRadius: 10,
                    endRadius: 160
                )

                RadialGradient(
                    colors: [Color(red: 0.424, green: 0.298, blue: 0.302).opacity(0.30), .clear],
                    center: .init(x: 0.15, y: 0.80),
                    startRadius: 5,
                    endRadius: 120
                )

                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color(red: 0.953, green: 0.933, blue: 0.851).opacity(0.12), lineWidth: 1)
                            .frame(width: 96, height: 96)
                        Circle()
                            .stroke(Color(red: 0.953, green: 0.933, blue: 0.851).opacity(0.20), lineWidth: 1)
                            .frame(width: 72, height: 72)
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.549, green: 0.373, blue: 0.376),
                                            Color(red: 0.380, green: 0.247, blue: 0.251),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 58, height: 58)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(Color(red: 0.953, green: 0.933, blue: 0.851))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(red: 0.953, green: 0.933, blue: 0.851))
                                .frame(width: 6, height: 6)
                            Text("AI POWERED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 0.953, green: 0.933, blue: 0.851))
                                .kerning(1.3)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hair Coach")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Personalised answers,\nanytime you need.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.50))
                                .lineSpacing(3)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
            }
            .frame(height: heroCardHeight - 50)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 18
            ))

            Button { viewModel.showCoach = true } label: {
                HStack(spacing: 13) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.28, green: 0.14, blue: 0.08))
                        .frame(width: 26)

                    Text("Start Session")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.08, blue: 0.05))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 18)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.hcCream)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 18,
                bottomTrailingRadius: 18, topTrailingRadius: 0
            ))
        }
        .frame(height: heroCardHeight)
        .background(Color.hcCream)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct HomeFeatureCardsSectionView: View {
    var viewModel: HomeViewModel
    var store: AppDataStore
    let healthKit: HealthKitManager
    
    var body: some View {
        VStack(spacing: 20) {
            HomeTodaySectionView(viewModel: viewModel, store: store)
            HomeMealLogSectionView(viewModel: viewModel, store: store)
            HomeWaterCardCompactView(viewModel: viewModel, store: store, healthKit: healthKit)
            HomeSleepCardCompactView(viewModel: viewModel, healthKit: healthKit)
            HomeDailyTipCardView()
        }
    }
}

struct HomeTodaySectionView: View {
    var viewModel: HomeViewModel
    var store: AppDataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 2)

            HStack(alignment: .top, spacing: 12) {
                HomeHairNutrientsCardView(viewModel: viewModel, store: store)
                    .buttonStyle(.plain)

                HomeFitnessCardView(
                    title: "MindEase", icon: "figure.mind.and.body",
                    iconColor: Color(red: 0.58, green: 0.48, blue: 0.92),
                    gradientColors: [Color(red: 0.90, green: 0.87, blue: 1.0),
                                     Color(red: 0.82, green: 0.78, blue: 0.98)],
                    current: Double(store.todaysMindfulMinutes()),
                    target:  Double(max(store.dailyMindfulTarget, 20)),
                    ringColor: Color(red: 0.50, green: 0.38, blue: 0.85),
                    unitSuffix: "min",
                    darkText: true
                )
                .buttonStyle(.plain)
            }
        }
    }
}

struct HomeFitnessCardView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let gradientColors: [Color]
    let current: Double
    let target: Double
    let ringColor: Color
    let unitSuffix: String
    var darkText: Bool = false
    
    var body: some View {
        let progress = min(current / max(target, 1), 1.0)
        let pct      = Int(progress * 100)
        let textPrimary   = darkText ? Color(red: 0.15, green: 0.12, blue: 0.10) : Color.white
        let textSecondary = darkText ? Color(red: 0.35, green: 0.30, blue: 0.25) : Color.white.opacity(0.55)
        let titleOpacity  = darkText ? Color(red: 0.30, green: 0.25, blue: 0.20) : Color.white.opacity(0.75)
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(titleOpacity)
                Spacer()
            }
            .padding(.bottom, 14)

            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.7), value: progress)
                VStack(spacing: 1) {
                    Text("\(pct)%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(textPrimary)
                    Text("of goal")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(textSecondary)
                }
            }
            .frame(width: 72, height: 72)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(current < 1000
                     ? "\(Int(current)) \(unitSuffix)"
                     : String(format: "%.0f \(unitSuffix)", current))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(textPrimary)
                Text("Goal \(Int(target)) \(unitSuffix)")
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: gradientColors,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(18)
    }
}

struct HomeHairNutrientsCardView: View {
    var viewModel: HomeViewModel
    var store: AppDataStore
    
    var body: some View {
        let covered = Set(store.todaysHairNutrientsCovered())
        let nutrients: [(name: String, icon: String, color: Color)] = [
            ("Biotin",    "leaf.fill",    Color(red: 0.22, green: 0.72, blue: 0.45)),
            ("Zinc",      "shield.fill",  Color(red: 0.20, green: 0.55, blue: 0.90)),
            ("Iron",      "bolt.fill",    Color(red: 0.90, green: 0.38, blue: 0.25)),
            ("Omega-3",   "drop.fill",    Color(red: 0.12, green: 0.70, blue: 0.82)),
            ("Vitamin A", "sun.max.fill", Color(red: 0.95, green: 0.65, blue: 0.10)),
        ]
        let coveredCount = nutrients.filter { covered.contains($0.name) }.count
        let segSize: Double   = 1.0 / 5.0   // 0.20 each
        let gap:     Double   = 0.018        // gap between arcs

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.22))
                Text("Hair Nutrients")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.15))
                Spacer()
                Button { viewModel.showNutrientInfo = true } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.22).opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            ZStack {
                ForEach(Array(nutrients.enumerated()), id: \.offset) { idx, nutrient in
                    let from = Double(idx) * segSize + gap / 2
                    let to   = Double(idx + 1) * segSize - gap / 2
                    let isCovered = covered.contains(nutrient.name)
                    Circle()
                        .trim(from: from, to: to)
                        .stroke(
                            isCovered ? nutrient.color : nutrient.color.opacity(0.38),
                            style: StrokeStyle(lineWidth: 11, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: isCovered)
                }

                VStack(spacing: 1) {
                    Text("\(coveredCount)/5")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.15, green: 0.12, blue: 0.10))
                    Text("covered")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.28, blue: 0.22).opacity(0.70))
                        .kerning(0.8)
                }
            }
            .frame(width: 76, height: 76)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach([0, 2, 4], id: \.self) { idx in
                        let nutrient  = nutrients[idx]
                        let isCovered = covered.contains(nutrient.name)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isCovered ? nutrient.color : nutrient.color.opacity(0.45))
                                .frame(width: 5, height: 5)
                            Text(nutrient.name == "Vitamin A" ? "Vit A" : nutrient.name)
                                .font(.system(size: 9, weight: isCovered ? .semibold : .regular))
                                .foregroundStyle(
                                    isCovered
                                        ? Color(red: 0.15, green: 0.12, blue: 0.10)
                                        : Color(red: 0.50, green: 0.42, blue: 0.34)
                                )
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach([1, 3], id: \.self) { idx in
                        let nutrient  = nutrients[idx]
                        let isCovered = covered.contains(nutrient.name)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isCovered ? nutrient.color : nutrient.color.opacity(0.45))
                                .frame(width: 5, height: 5)
                            Text(nutrient.name)
                                .font(.system(size: 9, weight: isCovered ? .semibold : .regular))
                                .foregroundStyle(
                                    isCovered
                                        ? Color(red: 0.15, green: 0.12, blue: 0.10)
                                        : Color(red: 0.50, green: 0.42, blue: 0.34)
                                )
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.85, blue: 0.68),
                         Color(red: 0.88, green: 0.76, blue: 0.54)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
    }
}

struct HomeMealLogSectionView: View {
    @Bindable var viewModel: HomeViewModel
    var store: AppDataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.isMealLogExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Today's Log")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(viewModel.isMealLogExpanded ? 90 : 0))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)

            if viewModel.isMealLogExpanded {
                Divider().padding(.horizontal, 16)
                
                let entries = store.todaysMealEntries()
                    .sorted { $0.mealType.displayOrder < $1.mealType.displayOrder }
                let firstUnlogged = entries.first(where: { $0.caloriesConsumed == 0 })?.mealType
                
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        let isLogged      = entry.caloriesConsumed > 0
                        let isAutoExpanded = entry.mealType == firstUnlogged
                        let shouldExpand  = isLogged
                                          || isAutoExpanded
                                          || viewModel.expandedMeals.contains(entry.mealType)

                        if shouldExpand {
                            HomeMealRowExpandedView(entry: entry, viewModel: viewModel)
                        } else {
                            HomeMealRowCompactView(entry: entry, viewModel: viewModel)
                        }

                        if idx < entries.count - 1 {
                            Divider().padding(.leading, shouldExpand ? 68 : 52)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct HomeMealRowExpandedView: View {
    let entry: MealEntry
    var viewModel: HomeViewModel
    
    var body: some View {
        let isLogged  = entry.caloriesConsumed > 0
        let timeHint  = viewModel.mealTimeHint(entry.mealType)
        let loggedStr = viewModel.loggedTimeString(entry)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.mealType.accentColor)
                    .frame(width: 44, height: 44)
                Image(systemName: viewModel.mealIcon(entry.mealType))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.mealType.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(isLogged ? loggedStr : timeHint)
                    .font(.system(size: 13))
                    .foregroundStyle(isLogged ? Color(red: 0.20, green: 0.78, blue: 0.35) : .secondary)
            }

            Spacer()

            if isLogged {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.35))
            } else {
                Button { viewModel.pushMealId = entry.id } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.hcBrown)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.pushMealId = entry.id }
    }
}

struct HomeMealRowCompactView: View {
    let entry: MealEntry
    @Bindable var viewModel: HomeViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.mealType.accentColor)
                .frame(width: 10, height: 10)
            Text(entry.mealType.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button { viewModel.pushMealId = entry.id } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.hcBrown)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                _ = viewModel.expandedMeals.insert(entry.mealType)
            }
        }
    }
}

struct HomeWaterCardCompactView: View {
    var viewModel: HomeViewModel
    var store: AppDataStore
    let healthKit: HealthKitManager
    
    var body: some View {
        let today    = healthKit.todaysWaterML
        let target   = store.activeNutritionProfile?.waterTargetML ?? 2500
        let progress = min(Double(today) / Double(max(target, 1)), 1.0)
        let todayL   = String(format: "%.1f", today  / 1000)
        let targetL  = String(format: "%.1f", target / 1000)
        let metGoal  = today >= Double(target)
        let stage    = store.latestScanReport?.hairFallStage.intValue ?? store.activePlan?.stage ?? 2

        return VStack(alignment: .leading, spacing: 10) {
            Button { viewModel.showHydrationSheet = true } label: {
                HStack {
                    Text("Water Intake")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(todayL)/\(targetL)L")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                     Color(red: 0.0,  green: 0.75, blue: 0.95)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 8)
                        .animation(.easeOut(duration: 0.4), value: today)
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                Image(systemName: metGoal ? "checkmark.circle.fill" : "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(metGoal
                        ? Color(red: 0.20, green: 0.78, blue: 0.35)
                        : Color(red: 0.15, green: 0.55, blue: 0.90))
                Text(viewModel.hydrationMessage(metGoal: metGoal, stage: stage))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.top, 2)

            HStack(spacing: 4) {
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct HomeSleepCardCompactView: View {
    var viewModel: HomeViewModel
    let healthKit: HealthKitManager
    
    var body: some View {
        let totalHours   = healthKit.lastNightSleepHours
        let hours        = Int(totalHours)
        let mins         = Int((totalHours - Double(hours)) * 60)

        let durationText = totalHours < 0.1
            ? "No data"
            : mins == 0 ? "\(hours)h sleep" : "\(hours)h \(mins)m sleep"

        let progress = min(totalHours / 8.0, 1.0)

        let arcColor: Color = hours >= 7
            ? Color(red: 0.52, green: 0.38, blue: 0.88)
            : hours >= 5
                ? Color(red: 0.95, green: 0.65, blue: 0.15)
                : Color(red: 0.90, green: 0.30, blue: 0.28)

        return VStack(alignment: .leading, spacing: 14) {
            Button { viewModel.showSleepSheet = true } label: {
                HStack(alignment: .center) {
                    Text("Sleep")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(durationText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(arcColor)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(
                            Color(.systemGray5),
                            style: StrokeStyle(lineWidth: 10)
                        )
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [arcColor.opacity(0.65), arcColor],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 84, height: 84)
                        .animation(.easeOut(duration: 0.6), value: progress)

                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [arcColor.opacity(0.75), arcColor],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HomeSleepTimeRowView(
                        icon: "bed.double.fill",
                        label: "Bedtime",
                        time: healthKit.lastSleepStart,
                        color: Color(red: 0.42, green: 0.30, blue: 0.80)
                    )
                    Divider()
                    HomeSleepTimeRowView(
                        icon: "alarm.fill",
                        label: "Wake Up",
                        time: healthKit.lastSleepEnd,
                        color: Color(red: 0.52, green: 0.38, blue: 0.88)
                    )
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct HomeSleepTimeRowView: View {
    let icon: String
    let label: String
    let time: Date?
    let color: Color
    
    var body: some View {
        let f = DateFormatter()
        let _ = { f.dateFormat = "h:mm a" }()
        let displayText = time.map { f.string(from: $0) } ?? "--:--"
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(displayText)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct HomeDailyTipCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily Tip")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 16) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 0.30))
                Text("20 minutes walk improves blood flow to scalp.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
