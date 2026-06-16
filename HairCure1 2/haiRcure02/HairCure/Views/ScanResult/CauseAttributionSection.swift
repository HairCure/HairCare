import SwiftUI

// MARK: - Data Model

struct CauseCard: Identifiable {
    let id          = UUID()
    let icon        : String
    let iconColor   : Color
    let severityLabel: String   // "Primary Cause" | "Contributing Factor" | "Low Risk"
    let severityColor: Color
    let headline    : String
    let yourDataLine: String    // references user's actual scores / answers
    let mechanismLine: String   // clinical mechanism
    let confidenceFraction: Float   // 0.0 – 1.0  (drives the animated bar)
    let isPrimary   : Bool
}

// MARK: - Cause Attribution Engine

enum CauseAttributionEngine {

    // ── Entry point ─────────────────────────────────────────────────────────
    static func buildCauses(
        report  : ScanReport?,
        answers : [UserAnswer],
        questions: [Question],
        options : [QuestionOption]
    ) -> [CauseCard] {

        guard let report = report else { return [] }

        var cards: [CauseCard] = []

        // ── 1. GENETIC / ANDROGENETIC ALOPECIA ──────────────────────────────
        // Inferred from hair fall stage + density. No direct question needed;
        // pattern-based loss is the hallmark of androgenetic alopecia (AGA).
        let stage   = report.hairFallStage.intValue
        let density = report.hairDensityPercent
        let lifestyleComposite = report.lifestyleScore

        // Confidence: higher stage + lower density → stronger genetic signal.
        // If lifestyle is good (≥ 6.5) but loss is still significant, AGA is
        // almost certainly the dominant driver.
        let geneticConf: Float
        let geneticIsPrimary: Bool
        let geneticSeverity: (String, Color)

        switch stage {
        case 1:
            geneticConf      = 0.28
            geneticIsPrimary = false
            geneticSeverity  = ("Contributing Factor", .orange)
        case 2:
            let boost = lifestyleComposite >= 6.5 ? Float(0.15) : Float(0)
            geneticConf      = 0.44 + boost
            geneticIsPrimary = lifestyleComposite >= 6.5
            geneticSeverity  = geneticIsPrimary
                ? ("Primary Cause", .red)
                : ("Contributing Factor", .orange)
        case 3:
            let boost = lifestyleComposite >= 5.5 ? Float(0.12) : Float(0)
            geneticConf      = 0.68 + boost
            geneticIsPrimary = true
            geneticSeverity  = ("Primary Cause", .red)
        default: // stage 4
            geneticConf      = 0.90
            geneticIsPrimary = true
            geneticSeverity  = ("Primary Cause", .red)
        }

        let densityNote = density < 50
            ? "Your hair density is \(Int(density))% — well below the healthy baseline of 80%+."
            : "Your hair density is \(Int(density))%, showing measurable thinning."

        let stageNote = "Your scan places you at Stage \(stage) on the Norwood scale."

        cards.append(CauseCard(
            icon            : "dna",
            iconColor       : Color(red: 0.55, green: 0.2, blue: 0.75),
            severityLabel   : geneticSeverity.0,
            severityColor   : geneticSeverity.1,
            headline        : "Androgenetic Alopecia (Genetic)",
            yourDataLine    : "\(stageNote) \(densityNote) When lifestyle factors are relatively controlled, pattern-based loss like this strongly indicates genetic DHT sensitivity.",
            mechanismLine   : "DHT (dihydrotestosterone) binds to genetically sensitive follicle receptors, progressively miniaturising them. Each cycle produces thinner, shorter hair until the follicle goes dormant.",
            confidenceFraction: geneticConf,
            isPrimary       : geneticIsPrimary
        ))

        // ── 2. NUTRITIONAL DEFICIENCY (Q4 diet, orderIndex 4) ───────────────
        let dietScore = report.dietScore
        if dietScore < 8.5 {
            let answerStr   = answerText(forOrderIndex: 2, answers: answers,
                                         questions: questions, options: options)
                              ?? "a suboptimal diet"
            let lif         = lifestyle(for: dietScore)
            let conf        = lifestyleConf(score: dietScore)
            cards.append(CauseCard(
                icon          : "fork.knife",
                iconColor     : Color(red: 0.9, green: 0.55, blue: 0.15),
                severityLabel : lif.label,
                severityColor : lif.color,
                headline      : "Nutritional Deficiency",
                yourDataLine  : "Your diet score is \(fmt(dietScore))/10 — you reported \"\(answerStr)\", which signals likely gaps in iron, zinc, and biotin.",
                mechanismLine : "Iron deficiency depletes the ferritin stores that follicles depend on. Zinc and biotin shortfalls slow keratin synthesis, causing diffuse shedding across the entire scalp.",
                confidenceFraction: conf,
                isPrimary     : lif.isPrimary
            ))
        }

        // ── 3. CHRONIC STRESS / TELOGEN EFFLUVIUM (SCORED) ────────
        if questions.contains(where: { $0.scoreDimension == .stress }) {
            let stressScore = report.stressScore
            if stressScore < 8.5 {
                let answerStr   = answerText(forOrderIndex: 3, answers: answers,
                                             questions: questions, options: options)
                                  ?? "elevated stress"
                let lif         = lifestyle(for: stressScore)
                let conf        = lifestyleConf(score: stressScore)
                cards.append(CauseCard(
                    icon          : "brain.head.profile",
                    iconColor     : Color(red: 0.55, green: 0.35, blue: 0.85),
                    severityLabel : lif.label,
                    severityColor : lif.color,
                    headline      : "Chronic Stress (Telogen Effluvium)",
                    yourDataLine  : "Your stress score is \(fmt(stressScore))/10 — you indicated \"\(answerStr)\", a documented cortisol trigger.",
                    mechanismLine : "Elevated cortisol forces follicles into a resting (telogen) phase prematurely. This causes 100–300 extra hairs to shed daily, typically 2–4 months after the stress peak.",
                    confidenceFraction: conf,
                    isPrimary     : lif.isPrimary
                ))
            }
        }

        // ── 4. SLEEP DEPRIVATION (Q1, orderIndex 1) ──────────────────────────
        let sleepScore = report.sleepScore
        if sleepScore < 8.5 {
            let answerStr   = answerText(forOrderIndex: 1, answers: answers,
                                         questions: questions, options: options)
                                  ?? "insufficient sleep"
            let lif         = lifestyle(for: sleepScore)
            let conf        = lifestyleConf(score: sleepScore)
            cards.append(CauseCard(
                icon          : "moon.zzz.fill",
                iconColor     : Color(red: 0.3, green: 0.45, blue: 0.85),
                severityLabel : lif.label,
                severityColor : lif.color,
                headline      : "Sleep Deprivation",
                yourDataLine  : "Your sleep score is \(fmt(sleepScore))/10 — you reported \"\(answerStr)\", falling below the 7–8 hour repair window.",
                mechanismLine : "Growth hormone — critical for the anagen (growth) phase — peaks during deep sleep. Chronic deprivation suppresses it, shortening the growth cycle and increasing shed rate.",
                confidenceFraction: conf,
                isPrimary     : lif.isPrimary
            ))
        }

        // ── 5. SCALP ENVIRONMENT (from scan) ─────────────────────────────────
        let scalp = report.scalpCondition
        if scalp != .normal {
            let (scalpDesc, scalpMechanism) = scalpDetails(for: scalp)
            cards.append(CauseCard(
                icon          : "waveform.path.ecg",
                iconColor     : Color(red: 0.75, green: 0.35, blue: 0.2),
                severityLabel : "Contributing Factor",
                severityColor : .orange,
                headline      : "Scalp Environment",
                yourDataLine  : "Your scan detected \(scalpDesc), creating a hostile follicle environment.",
                mechanismLine : scalpMechanism,
                confidenceFraction: 0.52,
                isPrimary     : false
            ))
        }

        // ── 6. HAIR CARE ROUTINE (Q3, orderIndex 3) ──────────────────────────
        let hairCareScore = report.hairCareScore
        if hairCareScore < 6.5 {
            let answerStr = answerText(forOrderIndex: 3, answers: answers,
                                       questions: questions, options: options)
                            ?? "a suboptimal washing routine"
            let conf      = min(lifestyleConf(score: hairCareScore), 0.58)
            cards.append(CauseCard(
                icon          : "shower.fill",
                iconColor     : Color(red: 0.2, green: 0.65, blue: 0.55),
                severityLabel : "Contributing Factor",
                severityColor : .orange,
                headline      : "Hair Care Routine",
                yourDataLine  : "Your hair care score is \(fmt(hairCareScore))/10 — you reported \"\(answerStr)\", which can disrupt the scalp microbiome balance.",
                mechanismLine : "Washing too frequently strips protective sebum; washing too rarely allows buildup that blocks follicles. Both increase mechanical breakage and shedding over time.",
                confidenceFraction: conf,
                isPrimary     : false
            ))
        }

        // ── Sort: Primary first → then by confidence ──────────────────────────
        let sorted = cards.sorted {
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
            return $0.confidenceFraction > $1.confidenceFraction
        }

        // ── Fallback for a fully healthy user (rare edge case) ────────────────
        if sorted.count == 1 && !sorted[0].isPrimary {
            return [CauseCard(
                icon            : "checkmark.shield.fill",
                iconColor       : .green,
                severityLabel   : "Low Risk",
                severityColor   : .green,
                headline        : "Strong Lifestyle Profile",
                yourDataLine    : "Your lifestyle scores are all strong — diet, sleep, stress, and hair care are well managed.",
                mechanismLine   : "Your hair loss appears primarily structural or genetic (androgenetic). The plan below focuses on preservation and density support.",
                confidenceFraction: 0.18,
                isPrimary       : false
            )]
        }

        return Array(sorted.prefix(5))
    }

    // MARK: - Private Helpers

    /// Looks up the selected answer text for a question identified by its order index.
    private static func answerText(
        forOrderIndex index: Int,
        answers  : [UserAnswer],
        questions: [Question],
        options  : [QuestionOption]
    ) -> String? {
        guard
            let question = questions.first(where: { $0.questionOrderIndex == index }),
            let answer   = answers.first(where: { $0.questionId == question.id }),
            let optionId = answer.selectedOptionId,
            let option   = options.first(where: { $0.id == optionId })
        else { return nil }
        return option.optionText.trimmingCharacters(in: .whitespaces)
    }

    /// Maps a lifestyle score (0–10) to a severity label + colour + isPrimary flag.
    private static func lifestyle(for score: Float) -> (label: String, color: Color, isPrimary: Bool) {
        let primary = score < 4.0
        return primary
            ? ("Primary Cause",       .red,    true)
            : ("Contributing Factor", .orange, false)
    }

    /// Maps a lifestyle score to a confidence fraction for the bar.
    /// Score 0 → ~0.95, Score 5 → ~0.55, Score 8.5 → ~0.20
    private static func lifestyleConf(score: Float) -> Float {
        max(0.18, 1.0 - (min(score, 10) / 10.0) * 0.82)
    }

    private static func fmt(_ v: Float) -> String { String(format: "%.1f", v) }

    private static func scalpDetails(for scalp: ScalpCondition) -> (String, String) {
        switch scalp {
        case .dandruff:
            return (
                "dandruff (Malassezia overgrowth)",
                "Fungal overgrowth triggers scalp inflammation, blocking follicle openings and disrupting the normal hair cycle."
            )
        case .dry:
            return (
                "a dry scalp",
                "A dry, compromised scalp barrier reduces nutrient delivery to follicles and increases mechanical fragility at the root."
            )
        case .oily:
            return (
                "an oily scalp",
                "Excess sebum binds DHT-related proteins near the follicle, accelerating miniaturisation — especially in androgenetic cases."
            )
        case .inflamed:
            return (
                "scalp inflammation",
                "Active inflammation releases cytokines that damage follicle stem cells and shorten the anagen (growth) phase."
            )
        case .normal, .notAssessed:
            return ("", "")
        }
    }
}

// MARK: - Cause Attribution Section View

struct CauseAttributionSection: View {
    let causes: [CauseCard]
    @State private var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            ForEach(Array(causes.enumerated()), id: \.element.id) { index, cause in
                causeCard(cause, index: index)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.15)) {
                animate = true
            }
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────

    private var sectionHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.82, green: 0.18, blue: 0.18).opacity(0.11))
                    .frame(width: 40, height: 40)
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.82, green: 0.18, blue: 0.18))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Why Your Hair Is Falling")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Based on your scan & lifestyle data")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // ── Single Cause Card ────────────────────────────────────────────────────

    private func causeCard(_ cause: CauseCard, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top severity stripe
            Rectangle()
                .fill(cause.severityColor)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 14) {

                // Icon + headline + pill
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(cause.iconColor.opacity(0.13))
                            .frame(width: 46, height: 46)
                        Image(systemName: cause.icon)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(cause.iconColor)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(cause.severityLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(cause.severityColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(cause.severityColor.opacity(0.11))
                            .cornerRadius(6)

                        Text(cause.headline)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                }

                Divider()

                // "Your data shows…"
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(cause.iconColor)
                        Text("Your data shows")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(cause.iconColor)
                    }
                    Text(cause.yourDataLine)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // "Why this causes shedding"
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(.systemGray3))
                        Text("Why this causes shedding")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(cause.mechanismLine)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Impact bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Estimated impact on your hair loss")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(cause.confidenceFraction * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(cause.iconColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(cause.iconColor.opacity(0.12))
                                .frame(height: 7)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [cause.iconColor, cause.iconColor.opacity(0.55)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: animate
                                        ? geo.size.width * CGFloat(cause.confidenceFraction)
                                        : 0,
                                    height: 7
                                )
                                .animation(
                                    .easeOut(duration: 0.9)
                                        .delay(Double(index) * 0.13 + 0.25),
                                    value: animate
                                )
                        }
                    }
                    .frame(height: 7)
                }
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.045), radius: 6, x: 0, y: 2)
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 14)
        .animation(
            .easeOut(duration: 0.42).delay(Double(index) * 0.10),
            value: animate
        )
    }
}
