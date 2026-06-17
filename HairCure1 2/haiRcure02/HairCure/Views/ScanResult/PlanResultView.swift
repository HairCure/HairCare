
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

                    planBadgeCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    recommendedPlanSection
                        .padding(.horizontal, 20)
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
            NavigationStack {
                RegisterView(onProceed: {
                    showAuthSheet = false
                    onStart()
                })
            }
        }
        .sheet(isPresented: $showNorwoodSheet) {
            NorwoodInfoSheet()
        }
    }

    
    // MARK: 1 — Nav Bar
    

    private var navBar: some View {
        HStack {
            HCBackButton {
                if authVM.isGuestMode {
                    authVM.isGuestMode = false
                } else {
                    onStart()
                }
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
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = scan != nil ? formatter.string(from: scan!.scanDate) : "Now"

        let paths = [
            scan?.frontImageURL,
            scan?.leftImageURL,
            scan?.rightImageURL,
            scan?.backImageURL
        ].compactMap { $0 }.filter { !$0.isEmpty && !$0.starts(with: "ai_") && !$0.starts(with: "self_") }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(spacing: 6) {
                        if i < paths.count, let uiImage = UIImage(contentsOfFile: paths[i]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 95, height: 95)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.hcBrown, lineWidth: 2)
                                )
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
                        }
                        Text(timeString)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }


    private var swipeableCards: some View {
        VStack(spacing: 12) {
            TabView(selection: $cardPage) {
                hairAnalysisCard.tag(0)
                lifestyleScoresCard.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 190)

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
        let density  = report?.hairDensityPercent ?? 52
        let stage    = report?.hairFallStage.intValue ?? plan?.stage ?? 2
        let hairType = report?.hairType?.capitalized ?? "N/A"
        let isNotAssessed = report?.hairDensityLevel == .notAssessed

        return VStack(alignment: .leading, spacing: 0) {
            Text("Your Hair Analysis Results")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 10)

            Divider().padding(.bottom, 14)

            resultRow(label: "Hair Density",
                      value: isNotAssessed ? "Not Assessed" : "\(Int(density))%",
                      color: isNotAssessed ? .secondary : densityColor(density))

            resultRow(label: "Growth Stage",
                      value: "Stage \(stage)",
                      color: stageColor(stage),
                      onInfo: { showNorwoodSheet = true })

            resultRow(label: "Hair Type",
                      value: hairType,
                      color: Color(red: 0.2, green: 0.55, blue: 0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(18)
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
        VStack(alignment: .leading, spacing: 0) {

            // Title row
            Text("Your Lifestyle Scores")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 10)

            Divider().padding(.bottom, 12)

            // Ring + dimension bars
            HStack(alignment: .center, spacing: 20) {
                compositeRing
                    .frame(width: 100, height: 100)
                VStack(spacing: 10) {
                    dimBar("Sleep",     report?.sleepScore    ?? 2.0, Color(red: 0.3,  green: 0.55, blue: 0.9))
                    dimBar("Stress",    report?.stressScore   ?? 4.0, Color(red: 0.4,  green: 0.72, blue: 0.35))
                    dimBar("Diet",      report?.dietScore     ?? 3.5, Color(red: 0.9,  green: 0.58, blue: 0.18))
                    dimBar("Hair care", report?.hairCareScore ?? 4.0, Color.hcBrown)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(18)
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

    
    // MARK: 4 — Plan Badge Card
  

    private var planBadgeCard: some View {
        let stage   = plan?.stage ?? report?.hairFallStage.intValue ?? 2
        let profile = plan?.lifestyleProfile ?? .poor

        let (profileLabel, profileColor): (String, Color) = {
            switch profile {
            case .poor:     return ("Poor lifestyle",     .red)
            case .moderate: return ("Moderate lifestyle", .orange)
            case .good:     return ("Good lifestyle",     .green)
            }
        }()

        return VStack(spacing: 14) {
            Text((plan?.planId ?? "2A").planDisplayName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)

            Text("Your personalised hair recovery plan")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(stageColor(stage)).frame(width: 8, height: 8)
                    Text("Stage \(stage)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(stageColor(stage))
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(stageColor(stage).opacity(0.12))
                .cornerRadius(20)

                Text(profileLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(profileColor)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(profileColor.opacity(0.12))
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white)
        .cornerRadius(20)
    }

    // MARK: 5 — Recommended Plan Section
    
    private var recommendedPlanSection: some View {
        let scalp = plan?.scalpModifier ?? report?.scalpCondition ?? .dry
        let np    = nutrition

        var items: [(icon: String, iconBg: Color, iconFg: Color, title: String, subtitle: String)] = []

        items.append((
            icon:     "leaf.fill",
            iconBg:   Color(red: 1.0,  green: 0.65, blue: 0.2),
            iconFg:   .white,
            title:    "Protein Rich-Diet",
            subtitle: "For keratin production and hair follicle strength"
        ))
        items.append((
            icon:     "moon.zzz.fill",
            iconBg:   Color(red: 0.38, green: 0.3, blue: 0.75),
            iconFg:   .white,
            title:    "Sleep",
            subtitle: "Aim for 7–8 hours to reduce cortisol and support hair repair"
        ))
        let waterL = np.map { String(format: "%.1f", $0.waterTargetML / 1000) } ?? "2.5"
        items.append((
            icon:     "drop.fill",
            iconBg:   Color(red: 0.15, green: 0.55, blue: 0.9),
            iconFg:   .white,
            title:    "Hydration",
            subtitle: "Drink at least \(waterL)L of water to keep your scalp and body hydrated"
        ))
        items.append((
            icon:     "heart.fill",
            iconBg:   Color(red: 0.2,  green: 0.72, blue: 0.4),
            iconFg:   .white,
            title:    "Stress Management",
            subtitle: "High stress pushes hair follicles into a resting phase — daily MindEase sessions help"
        ))
        let (scalpTitle, scalpSub) = scalpPlanItem(scalp)
        items.append((
            icon:     scalpIcon(scalp),
            iconBg:   Color.hcWarmBrown,
            iconFg:   .white,
            title:    scalpTitle,
            subtitle: scalpSub
        ))

        return VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Plan")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 4)

            ForEach(0..<items.count, id: \.self) { i in
                let item = items[i]
                recommendCard(
                    icon:     item.icon,
                    iconBg:   item.iconBg,
                    iconFg:   item.iconFg,
                    title:    item.title,
                    subtitle: item.subtitle
                )
            }
        }
    }

    private func recommendCard(
        icon: String, iconBg: Color, iconFg: Color,
        title: String, subtitle: String
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(iconBg).frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconFg)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
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
                    dividerLine
                    targetCell(
                        value: "\(mindEaseMinutes)",
                        unit: "min", label: "MindEase"
                    )
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
                    if authVM.isGuestMode {
                        showAuthSheet = true
                    } else {
                        onStart()
                    }
                } label: {
                    Text(authVM.isGuestMode ? "Create Account to Continue" : "Get Started")
                        .hcPrimaryButton()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
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

    private var mindEaseMinutes: Int {
        guard let p = plan else { return 80 }
        return p.meditationMinutesPerDay + p.yogaMinutesPerDay + p.soundMinutesPerDay
    }

    private var compositeRing: some View {
        let score = report?.lifestyleScore ?? 3.25
        let frac  = CGFloat(score / 10.0)
        let c: Color = score < 5 ? .orange : score < 8 ? .orange : .green
        return ZStack {
            Circle()
                .stroke(c.opacity(0.18), lineWidth: 11)
            Circle()
                .trim(from: 0, to: animateBars ? frac : 0)
                .stroke(c, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0).delay(0.2), value: animateBars)
            VStack(spacing: 1) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.primary)
                Text("/ 10").font(.system(size: 11)).foregroundStyle(.secondary)
                Text("composite").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }

    private func dimBar(_ title: String, _ value: Float, _ c: Color) -> some View {
        let frac = CGFloat(value / 10.0)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .leading)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.opacity(0.15)).frame(height: 6)
                    Capsule().fill(c)
                        .frame(width: animateBars ? g.size.width * frac : 0, height: 6)
                        .animation(.easeOut(duration: 0.85).delay(0.3), value: animateBars)
                }
            }
            .frame(height: 6)
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
