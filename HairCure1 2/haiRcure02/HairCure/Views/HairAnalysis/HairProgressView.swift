import SwiftUI

// MARK: 1 — Hair Progress View

struct HairProgressView: View {
    @Environment(AppDataStore.self) private var store

    // Scan flow state
    @State private var showMonthlyAssessment = false
    @State private var showNotDueAlert       = false
    @State private var notDueDaysLeft        = 0

    // Post scan navigation (stored as UUID to avoid Hashable requirement on ScanReport)
    @State private var pushToReportId: UUID? = nil

    /// 3 most recent real scans for this user
    private var recentScans: [ScanReport] {
        Array(
            store.scanReports
                .filter { r in
                    store.scalpScans.contains { $0.id == r.scalpScanId && $0.userId == store.currentUserId }
                }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(3)
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    Text("Hair Journey")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if recentScans.isEmpty {
                        emptyJourneyState
                    } else {
                        ForEach(recentScans) { report in
                            NavigationLink(destination: HairProgressDetailView(report: report)) {
                                HairProgressCard(report: report)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 120)
                }
                .padding(.top, 4)
            }
            .background(Color.hcCream.ignoresSafeArea())

            // ── FAB + schedule chip
            VStack(alignment: .trailing, spacing: 10) {
                scheduleChip
                floatingCameraButton
            }
            .padding(.trailing, 20)
            .padding(.bottom, 28)
        }
        .navigationTitle("Hair Progress")
        .navigationBarTitleDisplayMode(.inline)

        // Post-scan push to detail
        .navigationDestination(isPresented: Binding(
            get: { pushToReportId != nil },
            set: { if !$0 { pushToReportId = nil } }
        )) {
            if let id = pushToReportId,
               let report = store.scanReports.first(where: { $0.id == id }) {
                HairProgressDetailView(report: report)
            }
        }

        // Monthly (full) re-assessment
        .fullScreenCover(isPresented: $showMonthlyAssessment) {
            MonthlyAssessmentWrapper(
                onComplete: { newReport in
                    showMonthlyAssessment = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        pushToReportId = newReport.id
                    }
                },
                onCancel: { showMonthlyAssessment = false }
            )
            .environment(store)
        }

        // ── Not-due alert
        .alert("Scan Not Due Yet", isPresented: $showNotDueAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "Your next scan is due in \(notDueDaysLeft) day\(notDueDaysLeft == 1 ? "" : "s"). "
              + "Keep following your plan until then!"
            )
        }
    }

    // MARK: - Schedule Chip

    private var scheduleChip: some View {
        let schedule = RecommendationEngine.scanSchedule(store: store)
        let (label, isActive) = RecommendationEngine.scheduleChipInfo(for: schedule)

        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isActive ? .white : Color.primary.opacity(0.60))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isActive
                    ? Color.hcBrown.opacity(0.92)
                    : Color(UIColor.systemGray5)
            )
            .clipShape(Capsule())
    }

    // MARK: - Floating Camera FAB

    private var floatingCameraButton: some View {
        Button { handleCameraTap() } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.hcBrownLight, Color.hcBrown],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)
                    .shadow(color: Color.hcBrown.opacity(0.40), radius: 14, x: 0, y: 6)
                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera Tap Handler

    private func handleCameraTap() {
        let schedule = RecommendationEngine.scanSchedule(store: store)
        switch schedule {
        case .firstScan, .monthlyDue:
            showMonthlyAssessment = true
        case .notDue(_, let daysLeft):
            notDueDaysLeft  = daysLeft
            showNotDueAlert = true
        }
    }

    // MARK: - Empty State

    private var emptyJourneyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Color.hcBrown.opacity(0.30))
            Text("No scans yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Tap the camera button below\nto take your first scan.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: 2 — All Scans View

struct HairProgressAllScansView: View {
    @Environment(AppDataStore.self) private var store

    @State private var selectedMonth:        Date = Date()
    @State private var showMonthPicker       = false

    // ── Scan flow state ──
    @State private var showMonthlyAssessment = false
    @State private var showNotDueAlert       = false
    @State private var notDueDaysLeft        = 0

    /// All real scans for the selected month, newest first, for the current user only
    private var scansForMonth: [ScanReport] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let firstOfNext  = cal.date(byAdding: .month, value: 1, to: firstOfMonth)
        else { return [] }

        return store.scanReports
            .filter { r in
                r.createdAt >= firstOfMonth && r.createdAt < firstOfNext &&
                store.scalpScans.contains { $0.id == r.scalpScanId && $0.userId == store.currentUserId }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    // Month row
                    HStack {
                        Text("Monthly reports")
                            .font(.system(size: 22, weight: .bold))
                        Spacer()
                        Button { showMonthPicker.toggle() } label: {
                            HStack(spacing: 6) {
                                Text(monthLabel(selectedMonth))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.hcBrown)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Entry cards
                    if scansForMonth.isEmpty {
                        emptyState
                    } else {
                        ForEach(scansForMonth) { report in
                            NavigationLink(destination: HairProgressDetailView(report: report)) {
                                HairProgressCard(report: report)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 120)
                }
                .padding(.top, 8)
            }
            .background(Color.hcCream.ignoresSafeArea())

            VStack(alignment: .trailing, spacing: 10) {
                scheduleChip
                floatingCameraButton
            }
            .padding(.trailing, 20)
            .padding(.bottom, 28)
        }
        .navigationTitle("My Hair Progress")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(selectedMonth: $selectedMonth)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showMonthlyAssessment) {
            MonthlyAssessmentWrapper(
                onComplete: { _ in showMonthlyAssessment = false },
                onCancel:   { showMonthlyAssessment = false }
            )
            .environment(store)
        }
        .alert("Scan Not Due Yet", isPresented: $showNotDueAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "Your next scan is due in \(notDueDaysLeft) day\(notDueDaysLeft == 1 ? "" : "s")."
            )
        }
    }

    // MARK: - Schedule Chip

    private var scheduleChip: some View {
        let schedule = RecommendationEngine.scanSchedule(store: store)
        let (label, isActive) = RecommendationEngine.scheduleChipInfo(for: schedule)
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isActive ? .white : Color.primary.opacity(0.60))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.hcBrown.opacity(0.92) : Color(UIColor.systemGray5))
            .clipShape(Capsule())
    }

    private var floatingCameraButton: some View {
        Button { handleCameraTap() } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.hcBrownLight, Color.hcBrown],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)
                    .shadow(color: Color.hcBrown.opacity(0.40), radius: 14, x: 0, y: 6)
                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleCameraTap() {
        let schedule = RecommendationEngine.scanSchedule(store: store)
        switch schedule {
        case .firstScan, .monthlyDue: showMonthlyAssessment = true
        case .notDue(_, let days):    notDueDaysLeft = days; showNotDueAlert = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 52))
                .foregroundStyle(Color.hcBrown.opacity(0.35))
            Text("No scans for this month")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func monthLabel(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "dd MMM, yyyy"
        let lastDay = Calendar.current.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
        ) ?? date
        return df.string(from: lastDay)
    }
}

// MARK: 3 — Monthly Assessment Wrapper

struct MonthlyAssessmentWrapper: View {
    @Environment(AppDataStore.self) private var store

    let onComplete: (ScanReport) -> Void
    let onCancel:   () -> Void

    enum AssessmentStep {
        case questions
        case photoPrompt
    }

    @State private var currentStep: AssessmentStep = .questions
    @State private var analysisViewModel = HairAnalysisViewModel()
    @State private var assessmentInitialIndex = 0

    var body: some View {
        NavigationStack {
            switch currentStep {
            case .questions:
                AssessmentView(onComplete: {
                    assessmentInitialIndex = 0
                    withAnimation { currentStep = .photoPrompt }
                }, onBack: {
                    assessmentInitialIndex = 0
                    onCancel()
                }, initialIndex: assessmentInitialIndex)
                .environment(store)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel", action: onCancel)
                            .foregroundStyle(Color.hcBrown)
                    }
                }
                
            case .photoPrompt:
                HairAnalysisView(onComplete: {
                    if let newReport = store.latestScanReport {
                        onComplete(newReport)
                    } else {
                        onCancel()
                    }
                }, onBack: {
                    withAnimation {
                        assessmentInitialIndex = 7
                        currentStep = .questions
                    }
                }, viewModel: analysisViewModel)
                .environment(store)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel", action: onCancel)
                            .foregroundStyle(Color.hcBrown)
                    }
                }
            }
        }
    }
}

// MARK: 4 — Shared Card (uses real ScanReport directly)

struct HairProgressCard: View {
    let report: ScanReport

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd MMM, yyyy"
        return df
    }()

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Density : \(Int(report.hairDensityPercent))%")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Done on \(Self.dateFormatter.string(from: report.createdAt))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("View Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.hcBrown)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: 5 — Month Picker Sheet

private struct MonthPickerSheet: View {
    @Binding var selectedMonth: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("Select month",
                       selection: $selectedMonth,
                       displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .tint(Color.hcBrown)
                .padding(.horizontal)
                .navigationTitle("Choose Month")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Color.hcBrown)
                    }
                }
        }
    }
}

// MARK: 6 — Detail View

struct HairProgressDetailView: View {
    let report: ScanReport
    @Environment(AppDataStore.self) private var store
    @State private var animateBars = false

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd MMM, yyyy"
        return df
    }()

    // Named density thresholds
    private let densityHighThreshold: Float = 80
    private let densityMediumThreshold: Float = 65

    var body: some View {
        ScrollView(showsIndicators: false) {
            realScanContent(report: report)
        }
        .background(Color.hcCream.ignoresSafeArea())
        .navigationTitle("Scan Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.85).delay(0.3)) { animateBars = true }
        }
    }

    // MARK: Real scan content

    @ViewBuilder
    private func realScanContent(report: ScanReport) -> some View {
        VStack(alignment: .leading, spacing: 20) {

            // Density gauge
            densityGauge(percent: Int(report.hairDensityPercent),
                         doneOn: Self.dateFormatter.string(from: report.createdAt))
                .padding(.horizontal, 20)

            // Analysis rows
            VStack(spacing: 10) {
                analysisRow(title: "Hair Density Level",
                            value: densityLevelLabel(report.hairDensityPercent),
                            color: densityColor(report.hairDensityPercent))
                analysisRow(title: "Growth Stage",
                            value: "Stage \(report.hairFallStage.intValue)",
                            color: stageColor(report.hairFallStage.intValue))
                analysisRow(title: "Hair Type",
                            value: report.hairType?.capitalized ?? "N/A",
                            color: Color.blue.opacity(0.85))
                analysisRow(title: "Scan Type",
                            value: scanTypeLabel(report),
                            color: .primary)
            }
            .padding(.horizontal, 20)

            // Lifestyle scores
            lifestyleScoresCard(report: report)
                .padding(.horizontal, 20)

            // Plan info
            planInfoCard(report: report)
                .padding(.horizontal, 20)

            Spacer(minLength: 40)
        }
        .padding(.top, 16)
    }

    // MARK: Sub-views

    private func densityGauge(percent: Int, doneOn: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.hcBrown.opacity(0.15), lineWidth: 14)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: animateBars ? CGFloat(percent) / 100 : 0)
                    .stroke(Color.hcBrown,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: animateBars)
                VStack(spacing: 2) {
                    Text("\(percent)%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.hcBrown)
                    Text("Hair Density")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)
            Text("Done on \(doneOn)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func analysisRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func lifestyleScoresCard(report: ScanReport) -> some View {
        // Named color constants — no raw RGB literals
        let sleepColor    = Color(hue: 0.60, saturation: 0.65, brightness: 0.88)
        let stressColor   = Color(hue: 0.33, saturation: 0.52, brightness: 0.70)
        let dietColor     = Color(hue: 0.10, saturation: 0.72, brightness: 0.92)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Lifestyle Scores")
                .font(.system(size: 17, weight: .bold))
            Divider()
            HStack(alignment: .center, spacing: 16) {
                compositeRing(score: report.lifestyleScore)
                    .frame(width: 90, height: 90)
                VStack(spacing: 10) {
                    dimBar("Sleep",     report.sleepScore,    sleepColor)
                    dimBar("Stress",    report.stressScore,   stressColor)
                    dimBar("Diet",      report.dietScore,     dietColor)
                    dimBar("Hair Care", report.hairCareScore, Color.hcBrown)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func compositeRing(score: Float) -> some View {
        let frac = CGFloat(score / 10.0)
        let c: Color = score < 5 ? .red : score < 8 ? .orange : .green
        return ZStack {
            Circle().stroke(c.opacity(0.18), lineWidth: 10)
            Circle()
                .trim(from: 0, to: animateBars ? frac : 0)
                .stroke(c, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0).delay(0.2), value: animateBars)
            VStack(spacing: 1) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 18, weight: .bold))
                Text("/ 10")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dimBar(_ title: String, _ value: Float, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.system(size: 12, weight: .semibold))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.opacity(0.15)).frame(height: 5)
                    Capsule().fill(c)
                        .frame(width: animateBars ? g.size.width * CGFloat(value / 10.0) : 0, height: 5)
                        .animation(.easeOut(duration: 0.85).delay(0.3), value: animateBars)
                }
            }
            .frame(height: 5)
        }
    }

    private func planInfoCard(report: ScanReport) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.hcBrown)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.hcBrown.opacity(0.30), radius: 8, y: 3)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(report.planId.planDisplayName)
                    .font(.system(size: 16, weight: .bold))
                Text(report.recommendedPlan)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    /// Returns "First Time Scan" or "Monthly Scan" based on the linked ScalpScan type.
    private func scanTypeLabel(_ report: ScanReport) -> String {
        let scan = store.scalpScans.first { $0.id == report.scalpScanId }
        switch scan?.scanType {
        case .initial:              return "First Time Scan"
        case .monthly, .weekly, .none: return "Monthly Scan"
        }
    }

    private func densityLevelLabel(_ pct: Float) -> String {
        if pct >= densityHighThreshold   { return "High — Thick & full" }
        if pct >= densityMediumThreshold { return "Medium" }
        return "Low — Thin"
    }

    private func densityColor(_ pct: Float) -> Color {
        if pct >= densityHighThreshold   { return .green }
        if pct >= densityMediumThreshold { return .orange }
        return .red
    }

    private func stageColor(_ s: Int) -> Color {
        switch s {
        case 1:  return .green
        case 2:  return .orange
        case 3:  return Color(hue: 0.07, saturation: 0.80, brightness: 0.85) // amber-orange
        default: return .red
        }
    }
}


#Preview {
    NavigationStack {
        HairProgressView()
    }
    .environment(AppDataStore())
}
