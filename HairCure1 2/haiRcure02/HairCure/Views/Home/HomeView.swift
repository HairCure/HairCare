import SwiftUI
import HealthKit
import Charts
private let heroCardHeight: CGFloat = 218

struct HomeView: View {
    @Binding var selectedTab: Int

    @Environment(AppDataStore.self) private var store
    @Environment(HealthKitManager.self) private var healthKit
    @State private var showCoach          = false
    @State private var heroPage           = 0
    @State private var pushHairProgress   = false

    @State private var pushMealId: UUID?  = nil
    @State private var showHydrationSheet = false
    @State private var showSleepSheet     = false
    @State private var isMealLogExpanded  = true
    @State private var expandedMeals: Set<MealType> = []
    @State private var showNutrientInfo       = false



    private var report:    ScanReport?           { store.latestScanReport }
    private var plan:      UserPlan?             { store.activePlan }
    private var nutrition: UserNutritionProfile? { store.activeNutritionProfile }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        heroCardsSection
                        featureCardsSection
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $pushMealId) { mealId in
                AddMealView(mealEntryId: mealId)
            }
            .navigationDestination(isPresented: $pushHairProgress) {
                HairProgressView()
                    .environment(store)
            }
            .onAppear {
                Task {
                    await healthKit.refresh()
                }
            }
        }

        .sheet(isPresented: $showCoach) {
            CoachView(viewModel: CoachViewModel())
        }
        .sheet(isPresented: $showHydrationSheet) {
            WaterDetailsSheet(healthKit: healthKit, targetML: store.activeNutritionProfile?.waterTargetML ?? 2500)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSleepSheet) {
            SleepDetailsSheet(healthKit: healthKit)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNutrientInfo) {
            NutrientInfoSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }

    }

    // MARK: - Hero Swipe Cards

    private var heroCardsSection: some View {
        VStack(spacing: 10) {
            TabView(selection: $heroPage) {
                hairHealthCard
                    .padding(.horizontal, 4)
                    .tag(0)

                aiCoachCard
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
                        .fill(heroPage == i ? Color.hcBrown : Color(.systemGray4))
                        .frame(width: heroPage == i ? 10 : 7,
                               height: heroPage == i ? 10 : 7)
                        .animation(.easeInOut(duration: 0.2), value: heroPage)
                }
            }
        }
    }

    // MARK: - Card A — Hair Health

    private var hairHealthCard: some View {
        let hasReport = report != nil
        let density   = report?.hairDensityPercent ?? 0
        let stage     = report?.hairFallStage.intValue ?? plan?.stage
        let progress  = hasReport ? min(CGFloat(density) / 100.0, 1.0) : CGFloat(0)

        let (severityLabel, severityColor): (String, Color) = {
            guard let stage else { return ("", .clear) }
            switch stage {
            case 1: return ("Healthy",  Color(red: 0.22, green: 0.78, blue: 0.45))
            case 2: return ("Moderate", Color(red: 1.00, green: 0.60, blue: 0.15))
            case 3: return ("Severe",   Color(red: 0.95, green: 0.32, blue: 0.22))
            default: return ("Critical", Color(red: 0.85, green: 0.15, blue: 0.15))
            }
        }()

        let ringColor: Color = {
            guard let stage else { return Color.white.opacity(0.25) }
            switch stage {
            case 1: return Color(red: 0.22, green: 0.88, blue: 0.52)
            case 2: return Color(red: 1.00, green: 0.62, blue: 0.18)
            case 3: return Color(red: 0.95, green: 0.38, blue: 0.22)
            default: return Color(red: 0.85, green: 0.20, blue: 0.20)
            }
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
                    colors: [Color(red: 0.953, green: 0.933, blue: 0.851).opacity(0.12), .clear],
                    center: .init(x: 0.78, y: 0.22),
                    startRadius: 10,
                    endRadius: 140
                )

                RadialGradient(
                    colors: [Color(red: 0.424, green: 0.298, blue: 0.302).opacity(0.28), .clear],
                    center: .init(x: 0.15, y: 0.80),
                    startRadius: 5,
                    endRadius: 110
                )

                HStack(alignment: .center, spacing: 20) {

                    if hasReport {
                        // Density ring — real data
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 11)
                                .frame(width: 96, height: 96)

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    AngularGradient(
                                        colors: [ringColor.opacity(0.6), ringColor, ringColor.opacity(0.85)],
                                        center: .center,
                                        startAngle: .degrees(-90),
                                        endAngle:   .degrees(270)
                                    ),
                                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 96, height: 96)
                                .animation(.easeOut(duration: 0.9), value: progress)

                            VStack(spacing: 1) {
                                Text("\(Int(density))%")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("DENSITY")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .kerning(1.2)
                            }
                        }
                    } else {
                        // No scan — camera icon placeholder
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 11)
                                .frame(width: 96, height: 96)
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 34, weight: .light))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    // Right text column
                    VStack(alignment: .leading, spacing: 10) {

                        if hasReport, let stage {
                            HStack(spacing: 7) {
                                Text("Stage \(stage)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.18), in: Capsule())
                                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))

                                Text(severityLabel)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(severityColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(severityColor.opacity(0.18), in: Capsule())
                                    .overlay(Capsule().stroke(severityColor.opacity(0.35), lineWidth: 0.5))
                            }
                        }

                        Text(hasReport ? "Hair Health Score" : "Scan Your Scalp")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(hasReport ? "Last scan available" : "No scan yet — tap to start")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.50))
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

            // "View Hair Progress"
            Button { pushHairProgress = true } label: {
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

   

    private var aiCoachCard: some View {
        VStack(spacing: 0) {

            // Gradient hero section
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

                    // Right icon with glow rings
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

                    // Text column
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

            // ── "Start Session"
            Button { showCoach = true } label: {
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
    // MARK: - Feature Cards

    private var featureCardsSection: some View {
        VStack(spacing: 20) {
            todaySection
            logMealsSection
            waterCardCompact
            sleepCardCompact
            dailyTipCard
        }
    }

    // MARK: - Today (fitness rings)

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 2)

            HStack(alignment: .top, spacing: 12) {

                hairNutrientsCard
                    .buttonStyle(.plain)

                    fitnessCard(
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

    private func fitnessCard(
        title: String, icon: String, iconColor: Color,
        gradientColors: [Color], current: Double, target: Double,
        ringColor: Color, unitSuffix: String, darkText: Bool = false
    ) -> some View {
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

    // MARK: - Hair Nutrients Card

    private var hairNutrientsCard: some View {
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
            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.22))
                Text("Hair Nutrients")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.15))
                Spacer()
                Button { showNutrientInfo = true } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.22).opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // Single segmented ring
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

                // Centre label
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

            // Legend — 2 columns so height matches MindEase card
            HStack(alignment: .top, spacing: 6) {
                // Left column: Biotin, Iron, Vitamin A
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
                // Right column: Zinc, Omega-3
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

    // MARK: - Log Meals
    private var logMealsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Tappable header with chevron
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isMealLogExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Today's Log")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isMealLogExpanded ? 90 : 0))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)

            if isMealLogExpanded {
                Divider().padding(.horizontal, 16)
                mealListContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // Separate @ViewBuilder so `let` bindings are in proper Swift scope
    @ViewBuilder
    private var mealListContent: some View {
        let entries = store.todaysMealEntries()
            .sorted { $0.mealType.displayOrder < $1.mealType.displayOrder }
        let firstUnlogged = entries.first(where: { $0.caloriesConsumed == 0 })?.mealType

        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                let isLogged      = entry.caloriesConsumed > 0
                let isAutoExpanded = entry.mealType == firstUnlogged
                let shouldExpand  = isLogged
                                  || isAutoExpanded
                                  || expandedMeals.contains(entry.mealType)

                if shouldExpand {
                    expandedMealRow(entry: entry)
                } else {
                    compactMealRow(entry: entry)
                }

                if idx < entries.count - 1 {
                    Divider().padding(.leading, shouldExpand ? 68 : 52)
                }
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func expandedMealRow(entry: MealEntry) -> some View {
        let isLogged  = entry.caloriesConsumed > 0
        let timeHint  = mealTimeHint(entry.mealType)
        let loggedStr = loggedTimeString(entry)

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.mealType.accentColor)
                    .frame(width: 44, height: 44)
                Image(systemName: mealIcon(entry.mealType))
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
                Button { pushMealId = entry.id } label: {
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
        .onTapGesture { pushMealId = entry.id }
    }

    @ViewBuilder
    private func compactMealRow(entry: MealEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.mealType.accentColor)
                .frame(width: 10, height: 10)
            Text(entry.mealType.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button { pushMealId = entry.id } label: {
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
                _ = expandedMeals.insert(entry.mealType)
            }
        }
    }

    // MARK: - Meal helpers

    private func mealIcon(_ type: MealType) -> String {
        switch type {
        case .breakfast: return "cup.and.saucer.fill"
        case .lunch:     return "fork.knife"
        case .snack:     return "takeoutbag.and.cup.and.straw.fill"
        case .dinner:    return "moon.fill"
        }
    }

    private func mealTimeHint(_ type: MealType) -> String {
        switch type {
        case .breakfast: return "Recommended time : 7:00 – 9:00 AM"
        case .lunch:     return "Recommended time : 12:00 – 2:00 PM"
        case .snack:     return "Recommended time : 4:00 – 5:00 PM"
        case .dinner:    return "Recommended time : 7:00 – 9:00 PM"
        }
    }

    private func loggedTimeString(_ entry: MealEntry) -> String {
        guard let loggedAt = entry.loggedAt else {
            return "Logged · \(Int(entry.caloriesConsumed)) kcal"
        }
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return "Logged at \(f.string(from: loggedAt)) · \(Int(entry.caloriesConsumed)) kcal"
    }

    // MARK: - Water Card (read-only, data from Apple Health)

    private var waterCardCompact: some View {
        let today    = healthKit.todaysWaterML
        let target   = store.activeNutritionProfile?.waterTargetML ?? 2500
        let progress = min(Double(today) / Double(max(target, 1)), 1.0)
        let todayL   = String(format: "%.1f", today  / 1000)
        let targetL  = String(format: "%.1f", target / 1000)
        let metGoal  = today >= Double(target)
        let stage    = report?.hairFallStage.intValue ?? plan?.stage ?? 2

        return VStack(alignment: .leading, spacing: 10) {
            Button { showHydrationSheet = true } label: {
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

            // Stage-based hydration message
            HStack(spacing: 8) {
                Image(systemName: metGoal ? "checkmark.circle.fill" : "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(metGoal
                        ? Color(red: 0.20, green: 0.78, blue: 0.35)
                        : Color(red: 0.15, green: 0.55, blue: 0.90))
                Text(hydrationMessage(metGoal: metGoal, stage: stage))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.top, 2)

            // Source label
            HStack(spacing: 4) {
                // Removed Apple Health text
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
    }

    private func hydrationMessage(metGoal: Bool, stage: Int) -> String {
        if metGoal {
            return "Great job! You've hit your daily hydration goal."
        }
        switch stage {
        case 1:
            return "Stay hydrated to maintain your healthy hair."
        case 2:
            return "Drinking enough water helps reduce hair thinning."
        case 3:
            return "Hydration is crucial — it supports scalp recovery."
        default:
            return "Your hair needs extra care. Keep sipping water throughout the day."
        }
    }

    // MARK: - Sleep Card (read-only, data from Apple Health)

    private var sleepCardCompact: some View {
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

            // Header row
            Button { showSleepSheet = true } label: {
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

            // Arc + time labels row
            HStack(spacing: 24) {

                // Sleep arc
                ZStack {
                    Circle()
                        .trim(from: 0.62, to: 1.0)
                        .stroke(
                            Color(.systemGray5),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(162))
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0.62, to: 0.62 + 0.38 * progress)
                        .stroke(
                            LinearGradient(
                                colors: [arcColor.opacity(0.65), arcColor],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(162))
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

                // Bedtime / Wake time column
                VStack(alignment: .leading, spacing: 12) {
                    sleepTimeRow(
                        icon: "bed.double.fill",
                        label: "Bedtime",
                        time: healthKit.lastSleepStart,
                        color: Color(red: 0.42, green: 0.30, blue: 0.80)
                    )
                    Divider()
                    sleepTimeRow(
                        icon: "alarm.fill",
                        label: "Wake Up",
                        time: healthKit.lastSleepEnd,
                        color: Color(red: 0.52, green: 0.38, blue: 0.88)
                    )
                }

                Spacer(minLength: 0)
            }

            // Source label
            HStack(spacing: 4) {
                // Removed Apple Health text
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func sleepTimeRow(
        icon: String, label: String, time: Date?, color: Color
    ) -> some View {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
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

    // MARK: - Daily Tip

    private var dailyTipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Tips")
                .font(.system(size: 20, weight: .bold))
            HStack(spacing: 16) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 0.30))
                Text("20 minutes walk improves blood flow to scalp.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                Spacer()
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.95, blue: 0.93))
            .cornerRadius(18)
        }
    }
}

// MARK: - Water Details Sheet

struct WaterDetailsSheet: View {
    let healthKit: HealthKitManager
    let targetML: Float
    @Environment(\.dismiss) private var dismiss

    // Add-water state
    @State private var selectedCup: CupSize = .medium
    @State private var banner: String? = nil
    @State private var logError: HealthKitManager.HydrationError?
    @State private var showErrorAlert = false

    private var todayML: Double { healthKit.todaysWaterML }
    private var todayL:  String { String(format: "%.1f", todayML / 1000) }
    private var targetL: String { String(format: "%.1f", Double(targetML) / 1000) }
    private var progress: Double { min(todayML / Double(max(targetML, 1)), 1.0) }
    private var metGoal:  Bool { todayML >= Double(targetML) }
    private var remaining: Double { max(0, Double(targetML) - todayML) }

    enum CupSize: String, CaseIterable {
        case small  = "Small"
        case medium = "Medium"
        case large  = "Large"
        var ml: Double { switch self { case .small: return 150; case .medium: return 250; case .large: return 400 } }
        var icon: String { switch self { case .small: return "waterbottle"; case .medium: return "waterbottle.fill"; case .large: return "waterbottle.fill" } }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Progress ring + stats
                    progressSection
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // Permission banner
                    if !healthKit.canWriteWater {
                        permissionBanner
                            .padding(.horizontal, 20)
                    }

                    // Success/info banner
                    if let msg = banner {
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Cup picker
                    cupPickerSection
                        .padding(.horizontal, 20)

                    // Add button
                    Button { logWater() } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add \(Int(selectedCup.ml)) ml")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                         Color(red: 0.0, green: 0.75, blue: 0.95)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    // Today's log from HealthKit
                    if !healthKit.todaysWaterSamples.isEmpty {
                        todayLogSection
                            .padding(.horizontal, 20)
                    }

                    // Weekly chart
                    weeklySection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: banner)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Water Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Could Not Log Water", isPresented: $showErrorAlert) {
                if case .writePermissionDenied = logError {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(logError?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Log Water
    private func logWater() {
        Task {
            do {
                try await healthKit.logWater(amountML: selectedCup.ml)
                let rem = max(0, Double(targetML) - healthKit.todaysWaterML)
                let msg = healthKit.todaysWaterML >= Double(targetML)
                    ? "💧 Daily goal reached! Great job."
                    : "💧 +\(Int(selectedCup.ml)) ml added. \(Int(rem)) ml remaining."
                await MainActor.run {
                    withAnimation { banner = msg }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { banner = nil }
                    }
                }
            } catch let err as HealthKitManager.HydrationError {
                await MainActor.run { logError = err; showErrorAlert = true }
            } catch {
                await MainActor.run { logError = .saveFailed(error); showErrorAlert = true }
            }
        }
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(red: 0.15, green: 0.55, blue: 0.95).opacity(0.12), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                                Color(red: 0.0, green: 0.75, blue: 0.95)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.75), value: progress)
                VStack(spacing: 1) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("of goal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                statRow(label: "Today", value: "\(todayL) L", color: Color(red: 0.15, green: 0.55, blue: 0.95))
                statRow(label: "Target", value: "\(targetL) L", color: .secondary)
                statRow(label: "Remaining", value: String(format: "%.1f L", remaining / 1000), color: .orange)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Cup Picker
    private var cupPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select amount")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(CupSize.allCases, id: \.self) { cup in
                    let isSel = selectedCup == cup
                    Button { selectedCup = cup } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cup.icon)
                                .font(.system(size: isSel ? 26 : 20))
                                .foregroundStyle(isSel ? .white : Color(red: 0.15, green: 0.55, blue: 0.95))
                            Text(cup.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSel ? .white : .primary)
                            Text("\(Int(cup.ml)) ml")
                                .font(.system(size: 11))
                                .foregroundStyle(isSel ? .white.opacity(0.80) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSel
                            ? LinearGradient(colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                                      Color(red: 0.0, green: 0.75, blue: 0.95)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.white, Color.white],
                                             startPoint: .top, endPoint: .bottom))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSel ? Color.clear : Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(color: isSel ? Color(red: 0.15, green: 0.55, blue: 0.95).opacity(0.30) : .clear,
                                radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: selectedCup)
                }
            }
        }
    }

    // MARK: - Permission Banner
    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Health Write Access Required")
                    .font(.system(size: 13, weight: .semibold))
                Text("Logs won't sync to Apple Health.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Grant") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Today's Log Section
    private var todayLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Log")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.7))
                Text("Apple Health")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(healthKit.todaysWaterSamples.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.15, green: 0.55, blue: 0.9).opacity(0.10))
                                .frame(width: 34, height: 34)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(timeStr(entry.loggedAt))
                                .font(.system(size: 14, weight: .medium))
                            Text(entry.hkSample.sourceRevision.source.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+\(fmtML(entry.amountML))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.15, green: 0.55, blue: 0.9).opacity(0.09), in: Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await healthKit.deleteWater(sample: entry.hkSample) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    if idx < healthKit.todaysWaterSamples.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Weekly Chart Section
    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Week")
                .font(.system(size: 15, weight: .bold))
            weeklyWaterChart
                .frame(height: 140)
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: Weekly bar chart (Swift Charts)
    private var weeklyWaterChart: some View {
        let data = healthKit.weeklyWaterData
        let targetLitres = Double(targetML) / 1000

        return Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                BarMark(
                    x: .value("Day", entry.day),
                    y: .value("Litres", entry.totalML / 1000)
                )
                .foregroundStyle(
                    entry.totalML >= Double(targetML)
                        ? Color(red: 0.15, green: 0.55, blue: 0.95)
                        : Color(red: 0.15, green: 0.55, blue: 0.95).opacity(0.45)
                )
                .cornerRadius(4)
            }
            RuleMark(y: .value("Target", targetLitres))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .foregroundStyle(.orange)
                .annotation(position: .top, alignment: .trailing) {
                    Text("\(String(format: "%.1f", targetLitres))L goal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.orange)
                }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.1f", v)).font(.system(size: 10))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.system(size: 10, weight: .medium))
            }
        }
    }

    // MARK: - Helpers
    private func fmtML(_ ml: Double) -> String {
        ml >= 1000 ? String(format: "%.1fL", ml / 1000) : "\(Int(ml)) ml"
    }
    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }
}

// MARK: - Sleep Details Sheet


struct SleepDetailsSheet: View {
    let healthKit: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    private var totalHours: Double { healthKit.lastNightSleepHours }
    private var hours: Int { Int(totalHours) }
    private var mins: Int { Int((totalHours - Double(hours)) * 60) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                statusBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                List {
                    Section {
                        timeRow(
                            icon: "bed.double.fill",
                            iconColor: Color(red: 0.42, green: 0.30, blue: 0.80),
                            label: "Bedtime",
                            time: healthKit.lastSleepStart
                        )
                        timeRow(
                            icon: "alarm.fill",
                            iconColor: Color(red: 0.52, green: 0.38, blue: 0.88),
                            label: "Wake Up",
                            time: healthKit.lastSleepEnd
                        )
                        HStack {
                            Label {
                                Text("Duration")
                                    .font(.system(size: 16, weight: .medium))
                            } icon: {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color(red: 0.52, green: 0.38, blue: 0.88))
                            }
                            Spacer()
                            Text(totalHours > 0.1
                                 ? (mins == 0 ? "\(hours) hr" : "\(hours) hr \(mins) min")
                                 : "No data")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("Last Night")
                    }

                    Section {
                        weeklySleepChart
                            .frame(height: 140)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } header: {
                        Text("This Week")
                    } footer: {
                        Text("Aim for 7–9 hours for optimal hair health.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Status banner

    private var statusBanner: some View {
        let hasData = totalHours > 0.1
        let txt = hasData
            ? (mins == 0 ? "\(hours) hr" : "\(hours) hr \(mins) min")
            : "No sleep data"
        let good = hours >= 7

        let bannerColor: Color = !hasData
            ? Color(.systemGray3)
            : good
                ? Color(red: 0.20, green: 0.78, blue: 0.35)
                : Color(red: 0.95, green: 0.55, blue: 0.10)

        return HStack(spacing: 10) {
            Image(systemName: hasData
                  ? (good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                  : "moon.zzz")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(bannerColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(hasData ? "\(txt) of sleep recorded" : "No sleep data available")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(hasData
                     ? (good ? "Great! You're hitting your goal." : "Try to get at least 7 hours.")
                     : "Wear your Apple Watch or log sleep in Health app.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            bannerColor.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(bannerColor.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: Weekly bar chart (Swift Charts)

    private var weeklySleepChart: some View {
        let data = healthKit.weeklySleepData

        return Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                BarMark(
                    x: .value("Day", entry.day),
                    y: .value("Hours", entry.hours)
                )
                .foregroundStyle(
                    entry.hours >= 7
                        ? Color(red: 0.52, green: 0.38, blue: 0.88)
                        : entry.hours >= 5
                            ? Color(red: 0.95, green: 0.65, blue: 0.15)
                            : Color(red: 0.90, green: 0.30, blue: 0.28)
                )
                .cornerRadius(4)
            }
            RuleMark(y: .value("Goal", 7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.35))
                .annotation(position: .top, alignment: .trailing) {
                    Text("7h goal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.35))
                }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))h")
                            .font(.system(size: 10))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium))
            }
        }
    }

    // MARK: Time row

    private func timeRow(
        icon: String,
        iconColor: Color,
        label: String,
        time: Date?
    ) -> some View {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let displayText = time.map { f.string(from: $0) } ?? "--:--"

        return HStack {
            Label {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            Spacer()
            Text(displayText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Reusable Ring

struct CenterRingView: View {
    let progress: CGFloat
    let icon: String
    let iconColor: Color
    let trackColor: Color
    let text: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(trackColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(text)
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .frame(width: 80, height: 80)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - NutrientInfoSheet

struct NutrientInfoSheet: View {

    private struct NutrientInfo: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let role: String
        let researchURL: String
        let sourceName: String
    }

    private let nutrients: [NutrientInfo] = [
        NutrientInfo(
            name: "Biotin",
            color: Color(red: 0.22, green: 0.72, blue: 0.45),
            role: "Essential B-vitamin that supports keratin production — the structural protein making up hair. Deficiency is linked to hair thinning and brittle strands.",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5582478/",
            sourceName: "NIH PMC · Biotin & Hair Loss"
        ),
        NutrientInfo(
            name: "Zinc",
            color: Color(red: 0.20, green: 0.55, blue: 0.90),
            role: "Regulates hair follicle cycling and sebum production. Low zinc is one of the most common nutritional causes of hair loss in both men and women.",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3870206/",
            sourceName: "NIH PMC · Zinc & Hair Loss"
        ),
        NutrientInfo(
            name: "Iron",
            color: Color(red: 0.90, green: 0.38, blue: 0.25),
            role: "Carries oxygen to the hair follicle via red blood cells. Iron-deficiency anaemia is a leading cause of telogen effluvium (diffuse hair shedding).",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3678013/",
            sourceName: "NIH PMC · Iron & Telogen Effluvium"
        ),
        NutrientInfo(
            name: "Omega-3",
            color: Color(red: 0.12, green: 0.70, blue: 0.82),
            role: "Anti-inflammatory fatty acids that nourish hair follicles, improve scalp circulation, and reduce scalp dryness and flaking.",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6164340/",
            sourceName: "NIH PMC · Omega-3 & Hair Density"
        ),
        NutrientInfo(
            name: "Vitamin A",
            color: Color(red: 0.95, green: 0.65, blue: 0.10),
            role: "Needed for sebum synthesis which moisturises the scalp. However, excess vitamin A (>10,000 IU/day) can paradoxically trigger hair loss.",
            researchURL: "https://www.ncbi.nlm.nih.gov/books/NBK532986/",
            sourceName: "NIH StatPearls · Vitamin A & Skin"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Sheet header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hair Nutrient Research")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.15, green: 0.10, blue: 0.08))
                    Text("5 key nutrients · tap links to read studies")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 20)

                // Nutrient rows
                VStack(spacing: 0) {
                    ForEach(Array(nutrients.enumerated()), id: \.element.id) { idx, nutrient in
                        VStack(alignment: .leading, spacing: 10) {

                            // Name row — coloured dot + bold text
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(nutrient.color)
                                    .frame(width: 8, height: 8)
                                Text(nutrient.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(red: 0.15, green: 0.10, blue: 0.08))
                            }

                            // Role description
                            Text(nutrient.role)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)

                            // Research link — plain text pill
                            if let url = URL(string: nutrient.researchURL) {
                                Link(destination: url) {
                                    Text(nutrient.sourceName + "  ↗")
                                        .font(.system(size: 12, weight: .semibold))
                                        .underline()
                                        .foregroundStyle(nutrient.color)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(nutrient.color.opacity(0.10))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)

                        if idx < nutrients.count - 1 {
                            Divider().padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .background(Color(red: 0.98, green: 0.96, blue: 0.92).ignoresSafeArea())
    }
}
