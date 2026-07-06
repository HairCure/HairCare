
import SwiftUI

struct PlanResultsView: View {
    let onStart: () -> Void
    var onRetake: (() -> Void)? = nil

    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM

    @State private var cardPage       = 0      // 0 = hair analysis, 1 = lifestyle
    @State private var animateBars    = false
    @State private var showReferences = false
    @State private var showAuthSheet  = false
    @State private var showNorwoodSheet = false
    @State private var showDailyPlanSheet = false

    private var report:    ScanReport?           { store.latestScanReport }
    private var plan:      UserPlan?             { store.activePlan }
    private var nutrition: UserNutritionProfile? { store.activeNutritionProfile }

    // Density → fixed thresholds
    private func densityLabel(_ pct: Float) -> String {
        switch pct {
        case 80...100: return "High (\(Int(pct))%)"
        case 60..<80:  return "Medium (\(Int(pct))%)"
        case 40..<60:  return "Low (\(Int(pct))%)"
        default:       return "Very Low (\(Int(pct))%)"
        }
    }
    private func densityColor(_ pct: Float) -> Color {
        switch pct {
        case 80...100: return .green
        case 60..<80:  return .orange
        case 40..<60:  return Color(red: 0.85, green: 0.45, blue: 0.1)
        default:       return .red
        }
    }

     var body: some View {
        ZStack(alignment: .bottom) {
            Color.hcCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    navBar
                        .padding(.bottom, 20)

                    scanPhotoRow
                        .padding(.bottom, 20)

                    swipeableCards
                        .padding(.bottom, 20)

                    aiWeeklyPlanSection
                        .padding(.bottom, 20)

                    dailyTargetsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 110)
                }
                .padding(.top, 12)
            }

            ctaButton
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.85).delay(0.3)) {
                animateBars = true
            }
        }
        .sheet(isPresented: $showReferences) {
            AllReferencesView()
        }
        .fullScreenCover(isPresented: $showAuthSheet) {
            AuthLandingView(hideGuestButton: true, onProceed: {
                showAuthSheet = false
                onStart()
            })
        }
        .sheet(isPresented: $showNorwoodSheet) {
            NorwoodInfoSheet()
        }
        .sheet(isPresented: $showDailyPlanSheet) {
            DailyActionPlanSheet(plan: plan, nutrition: nutrition)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }

    
    // MARK: 1 — Nav Bar
    

    private var navBar: some View {
        HStack {
            HCBackButton {
                onStart()
            }
            Spacer()
            Text("Scan Report")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                showReferences = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.hcBrown)
            }
            .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
    }

    
    // MARK: 2 — Scan Photo Row

    private var scanPhotoRow: some View {
        let scan = store.scalpScans.first { $0.id == report?.scalpScanId }
        
        let photoInfo: [(label: String, path: String)] = [
            ("Front", scan?.frontImageURL),
            ("Left", scan?.leftImageURL),
            ("Right", scan?.rightImageURL),
            ("Back", scan?.backImageURL),
            ("Top", scan?.topImageURL)
        ].compactMap {
            guard let url = $0.1, let resolved = url.resolvedLocalImagePath, !resolved.isEmpty else {
                return nil
            }
            return ($0.0, resolved)
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<max(4, photoInfo.count), id: \.self) { i in
                    VStack(spacing: 6) {
                        if i < photoInfo.count, let uiImage = UIImage(contentsOfFile: photoInfo[i].path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 95, height: 95)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.hcBrown, lineWidth: 2)
                                )
                            Text(photoInfo[i].label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemGray5))
                                .frame(width: 95, height: 95)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                                        )
                                        .foregroundStyle(Color(.systemGray4))
                                )
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color(.systemGray3))
                                )
                            Text(" ") // invisible spacer
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }


    private var swipeableCards: some View {
        VStack(spacing: 12) {
            TabView(selection: $cardPage) {
                hairAnalysisCard
                    .padding(.horizontal, 4)
                    .tag(0)
                lifestyleScoresCard
                    .padding(.horizontal, 4)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220)

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(cardPage == i ? Color.hcBrown : Color(.systemGray4))
                        .frame(width: cardPage == i ? 10 : 8,
                               height: cardPage == i ? 10 : 8)
                        .animation(.easeInOut(duration: 0.2), value: cardPage)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var hairAnalysisCard: some View {
        let density      = report?.hairDensityPercent ?? 52
        let stage        = report?.hairFallStage.intValue ?? plan?.stage ?? 2
        let hairType     = report?.hairType?.capitalized ?? "N/A"
        let isNotAssessed = report?.hairDensityLevel == .notAssessed
        let dColor        = isNotAssessed ? Color.white.opacity(0.5) : densityColor(density)
        let sColor        = stageColor(stage)

        return ZStack(alignment: .topLeading) {
            // Base gradient
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.424, green: 0.298, blue: 0.302), location: 0.0),
                    .init(color: Color(red: 0.298, green: 0.192, blue: 0.196), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Cream glow top-right
            RadialGradient(
                colors: [Color(red: 0.953, green: 0.933, blue: 0.851).opacity(0.13), .clear],
                center: .init(x: 0.80, y: 0.15),
                startRadius: 8,
                endRadius: 150
            )
            // Dark-rose glow bottom-left
            RadialGradient(
                colors: [Color(red: 0.424, green: 0.298, blue: 0.302).opacity(0.30), .clear],
                center: .init(x: 0.10, y: 0.85),
                startRadius: 5,
                endRadius: 110
            )

            VStack(alignment: .leading, spacing: 14) {
                // Header chip
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.953, green: 0.933, blue: 0.851))
                    Text("AI ANALYSIS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.953, green: 0.933, blue: 0.851))
                        .kerning(1.3)
                }

                Text("Your Hair Analysis Results")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                // Metric rows
                VStack(spacing: 12) {
                    // Hair Density
                    HStack {
                        Text("Hair Density")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.60))
                        Spacer()
                        Text(isNotAssessed ? "Not Assessed" : "\(Int(density))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(dColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(dColor.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(dColor.opacity(0.45), lineWidth: 1))
                    }

                    // Growth Stage
                    HStack {
                        HStack(spacing: 4) {
                            Text("Growth Stage")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.60))
                            Button { showNorwoodSheet = true } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.40))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text("Stage \(stage)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(sColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(sColor.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(sColor.opacity(0.45), lineWidth: 1))
                    }

                    // Hair Type
                    HStack {
                        Text("Hair Type")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.60))
                        Spacer()
                        let typeColor = Color(red: 0.45, green: 0.70, blue: 1.0)
                        Text(hairType)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(typeColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(typeColor.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(typeColor.opacity(0.45), lineWidth: 1))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
    }

    private func resultRow(label: String, value: String, color: Color, onInfo: (() -> Void)? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            if let action = onInfo {
                Button(action: action) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.hcBrown.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.bottom, 14)
    }

    // Card B — Lifestyle Scores
    private var lifestyleScoresCard: some View {
        ZStack(alignment: .topLeading) {
            // Base gradient
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.424, green: 0.298, blue: 0.302), location: 0.0),
                    .init(color: Color(red: 0.298, green: 0.192, blue: 0.196), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Cream glow top-right
            RadialGradient(
                colors: [Color(red: 0.953, green: 0.933, blue: 0.851).opacity(0.13), .clear],
                center: .init(x: 0.80, y: 0.15),
                startRadius: 8,
                endRadius: 150
            )
            // Dark-rose glow bottom-left
            RadialGradient(
                colors: [Color(red: 0.424, green: 0.298, blue: 0.302).opacity(0.30), .clear],
                center: .init(x: 0.10, y: 0.85),
                startRadius: 5,
                endRadius: 110
            )

            VStack(alignment: .leading, spacing: 8) {
                // Header chip
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.953, green: 0.933, blue: 0.851))
                    Text("LIFESTYLE SCORE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.953, green: 0.933, blue: 0.851))
                        .kerning(1.3)
                }

                Text("Your Lifestyle Scores")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                // Ring + dimension bars
                HStack(alignment: .center, spacing: 16) {
                    compositeRing
                        .frame(width: 85, height: 85)
                    VStack(spacing: 8) {
                        dimBar("Sleep",     report?.sleepScore    ?? 2.0, Color(red: 0.3,  green: 0.55, blue: 0.9))
                        dimBar("Stress",    report?.stressScore   ?? 4.0, Color(red: 0.4,  green: 0.72, blue: 0.35))
                        dimBar("Diet",      report?.dietScore     ?? 3.5, Color(red: 0.9,  green: 0.58, blue: 0.18))
                        dimBar("Hair care", report?.hairCareScore ?? 4.0, Color(red: 0.953, green: 0.933, blue: 0.851))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
    }

    private func scoreRow(_ label: String, _ value: Float, _ dotColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Circle().fill(dotColor).frame(width: 9, height: 9)
            Text("\(Int(value))/10")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.bottom, 10)
    }
    
    // MARK: 6 — Daily Targets Strip
    
    @ViewBuilder
    private var dailyTargetsSection: some View {
        if let np = nutrition {
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily Targets")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                HStack(spacing: 0) {
                    targetCell(value: "\(Int(np.tdee))",
                               unit: "kcal", label: "Calories")
                    dividerLine
                    targetCell(value: "\(Int(np.proteinTargetGm))",
                               unit: "g", label: "Protein")
                    dividerLine
                    targetCell(value: "\(Int(np.carbTargetGm))",
                               unit: "g", label: "Carbs")
                    dividerLine
                    targetCell(value: String(format: "%.1f", np.waterTargetML / 1000),
                               unit: "L", label: "Water")
                    dividerLine
                    targetCell(value: "7.5",
                               unit: "hrs", label: "Sleep")
                }
                .padding(.vertical, 18)
                .background(Color.white)
                .cornerRadius(16)
            }
        }
    }

    private func targetCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.hcBrown)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 1, height: 44)
    }

        // MARK: 7 — CTA
    

    private var ctaButton: some View {
        let isNotAssessed = report?.hairDensityLevel == .notAssessed
        
        return VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.hcCream.opacity(0), Color.hcCream],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                if isNotAssessed, let onRetake = onRetake {
                    Button {
                        onRetake()
                    } label: {
                        Text("Upload Photo for Better Analysis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.hcBrown)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    onStart()
                } label: {
                    Text("Get Started")
                        .hcPrimaryButton()
                }
                .padding(.horizontal, 20)
                
                // Gentle nudge for guests — not a hard block
                if authVM.isGuestMode {
                    Button {
                        showAuthSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 13, weight: .medium))
                            Text("Sign up to save your results")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Color.hcWarmBrown)
                    }
                    .padding(.top, 4)
                }
                
                Color.clear.frame(height: 36)
            }
            .background(Color.hcCream)
        }
    }

    // MARK: Helpers



    private func stageColor(_ s: Int) -> Color {
        switch s {
        case 1:  return .green
        case 2:  return .orange
        case 3:  return Color(red: 0.85, green: 0.35, blue: 0.1)
        default: return .red
        }
    }

    private func scalpLabel(_ c: ScalpCondition) -> String {
        switch c {
        case .dry:      return "Mild Dryness"
        case .dandruff: return "Dandruff"
        case .oily:     return "Oily Scalp"
        case .inflamed: return "Inflamed"
        case .normal:   return "Normal"
        case .notAssessed: return "Not Assessed"
        }
    }

    private func scalpIcon(_ c: ScalpCondition) -> String {
        switch c {
        case .dry:      return "drop.fill"
        case .dandruff: return "snowflake"
        case .oily:     return "waveform.path"
        case .inflamed: return "flame.fill"
        case .normal:   return "checkmark.seal.fill"
        case .notAssessed: return "sparkles"
        }
    }

    private func scalpPlanItem(_ c: ScalpCondition) -> (String, String) {
        switch c {
        case .dry:
            return ("Scalp Oiling Routine",
                    "Warm coconut or almond oil twice a week — reduces dryness and supports follicle strength")
        case .dandruff:
            return ("Anti-Dandruff Routine",
                    "Zinc-rich foods and anti-fungal shampoo — wash every 2–3 days with ketoconazole formula")
        case .oily:
            return ("Sebum Control",
                    "Wash every 2 days — zinc foods regulate sebum. Avoid heavy oils directly on scalp")
        case .inflamed:
            return ("Soothing Scalp Care",
                    "Omega-3 foods and aloe vera gel twice a week — reduces redness and inflammation")
        case .normal:
            return ("Maintain Scalp Health",
                    "Oil once a week, wash every 2–3 days — keep up the healthy routine")
        case .notAssessed:
            return ("General Scalp Health",
                    "Maintain a clean, nourished scalp with regular washing and light oiling to support hair growth.")
        }
    }

    @ViewBuilder
    private var aiWeeklyPlanSection: some View {
        WeeklyPlanWidgetView(plan: plan)
    }

    private var compositeRing: some View {
        let score = report?.lifestyleScore ?? 3.25
        let frac  = CGFloat(score / 10.0)
        let c: Color = score < 5 ? Color(red: 1.0, green: 0.6, blue: 0.2) : score < 8 ? Color(red: 0.4, green: 0.85, blue: 0.45) : Color(red: 0.3, green: 0.90, blue: 0.5)
        return ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 11)
            // Filled arc with glow
            Circle()
                .trim(from: 0, to: animateBars ? frac : 0)
                .stroke(c, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: c.opacity(0.55), radius: 8, x: 0, y: 0)
                .animation(.easeOut(duration: 1.0).delay(0.2), value: animateBars)
            VStack(spacing: 1) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("/ 10")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                Text("composite")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func dimBar(_ title: String, _ value: Float, _ c: Color) -> some View {
        let frac = CGFloat(value / 10.0)
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(c)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(c.opacity(0.20))
                    .clipShape(Capsule())
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 5)
                    Capsule()
                        .fill(c)
                        .frame(width: animateBars ? g.size.width * frac : 0, height: 5)
                        .animation(.easeOut(duration: 0.85).delay(0.3), value: animateBars)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - NorwoodInfoSheet

private struct NorwoodInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let norwoodURL = URL(string: "https://en.wikipedia.org/wiki/Hamilton%E2%80%93Norwood_scale")!

    private let stages: [(stage: String, title: String, description: String, color: Color)] = [
        ("Stage 1", "No Hair Loss",
         "Hairline shows no significant recession. Full coverage with no visible thinning.",
         .green),
        ("Stage 2", "Slight Recession",
         "Minor recession at the temples. Early signs of a mature hairline forming.",
         .green),
        ("Stage 3", "Noticeable Recession",
         "Deeper temple recession creating an M-shape. Hair may thin at the crown (Stage 3 Vertex).",
         .orange),
        ("Stage 4", "Moderate Loss",
         "Significant frontal loss with a sparse or absent crown patch. A band of hair still connects the sides.",
         Color(red: 0.85, green: 0.45, blue: 0.1)),
        ("Stage 5", "Extensive Loss",
         "The bridge of hair between front and crown narrows. Both areas continue to merge with thin coverage.",
         Color(red: 0.85, green: 0.35, blue: 0.1)),
        ("Stage 6", "Severe Loss",
         "Front and crown loss areas merge completely. Only a horseshoe fringe remains on the sides and back.",
         .red),
        ("Stage 7", "Advanced Loss",
         "Only a thin band of hair remains around the sides and back. Most severe form of male pattern baldness.",
         .red),
    ]

    var body: some View {
        VStack(spacing: 0) {

            // ── Handle + header ──
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                HStack {
                    Color.clear.frame(width: 24, height: 24)
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Norwood Scale")
                            .font(.system(size: 18, weight: .bold))
                        Text("Hair Loss Stages Explained")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.hcBrown)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider()
            }
            .background(Color(.systemBackground))

            // ── Stage list ──
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(stages, id: \.stage) { item in
                        HStack(alignment: .top, spacing: 14) {
                            // Stage badge
                            Text(item.stage)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(item.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(item.color.opacity(0.12))
                                .clipShape(Capsule())
                                .frame(width: 76, alignment: .center)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(item.description)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(item.color.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // ── Open in Safari button ──
                    Button {
                        openURL(norwoodURL)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                                .font(.system(size: 15, weight: .semibold))
                            Text("View Full Reference on Wikipedia")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.hcBrown)
                        .cornerRadius(14)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - DailyActionPlanSheet

struct DailyActionPlanSheet: View {
    let plan:      UserPlan?
    let nutrition: UserNutritionProfile?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                ZStack {
                    Color(.systemBackground)
                    VStack(spacing: 0) {
                        Spacer().frame(height: 24)

                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.hcBrown.opacity(0.10))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.hcBrown)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Action Plan")
                                    .font(.system(size: 18, weight: .bold))
                                Text("AI-powered daily roadmap for your hair")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.hcBrown)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                        Divider()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                // ── Scrollable content ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Daily Targets strip
                        if let np = nutrition {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Daily Targets", systemImage: "target")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.6)

                                HStack(spacing: 0) {
                                    sheetTargetCell(value: "\(Int(np.tdee))",   unit: "kcal", label: "Calories")
                                    sheetDivider
                                    sheetTargetCell(value: "\(Int(np.proteinTargetGm))", unit: "g", label: "Protein")
                                    sheetDivider
                                    sheetTargetCell(value: "\(Int(np.carbTargetGm))",    unit: "g", label: "Carbs")
                                    sheetDivider
                                    sheetTargetCell(value: String(format: "%.1f", np.waterTargetML / 1000), unit: "L", label: "Water")
                                    sheetDivider
                                    sheetTargetCell(value: "7.5",                        unit: "hrs", label: "Sleep")
                                }
                                .padding(.vertical, 18)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
                            }
                            .padding(.horizontal, 20)
                        }

                        // 7-Day Plan
                        WeeklyPlanWidgetView(plan: plan)

                        Color.clear.frame(height: 30)
                    }
                    .padding(.top, 20)
                }
            }
        }
    }

    private func sheetTargetCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.hcBrown)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sheetDivider: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 1, height: 44)
    }
}
