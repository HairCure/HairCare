import SwiftUI
import Charts

// MARK: 1 — Hair Progress View

struct HairProgressView: View {
    @Environment(AppDataStore.self) private var store

    // Scan flow state
    @State private var showMonthlyAssessment = false
    @State private var showNotDueAlert       = false
    @State private var notDueDaysLeft        = 0
    @State private var showComparisonView    = false

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

                    HStack {
                        Text("Hair Journey")
                            .font(.system(size: 22, weight: .bold))
                        Spacer()
                        if store.scanReports.filter({ r in
                            store.scalpScans.contains { $0.id == r.scalpScanId && $0.userId == store.currentUserId }
                        }).count >= 2 {
                            Button {
                                showComparisonView = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.left.and.right.righttriangle.left.and.righttriangle.right")
                                        .font(.system(size: 11))
                                    Text("Compare")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.hcBrown)
                                .clipShape(Capsule())
                            }
                        }
                    }
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
        .sheet(isPresented: $showComparisonView) {
            HairProgressComparisonView()
                .environment(store)
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
    @State private var showComparisonView    = false

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
                        if store.scanReports.filter({ r in
                            store.scalpScans.contains { $0.id == r.scalpScanId && $0.userId == store.currentUserId }
                        }).count >= 2 {
                            Button {
                                showComparisonView = true
                            } label: {
                                Image(systemName: "arrow.left.and.right.righttriangle.left.and.righttriangle.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.hcBrown)
                                    .clipShape(Circle())
                            }
                        }
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
        .sheet(isPresented: $showComparisonView) {
            HairProgressComparisonView()
                .environment(store)
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
        .background(Color.white)
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

            // Scalp Photos
            scalpPhotosSection(report: report)

            // Analysis Card
            VStack(spacing: 0) {
                analysisRow(title: "Hair Density Level",
                            value: densityLevelLabel(report.hairDensityPercent),
                            color: densityColor(report.hairDensityPercent))
                Divider()
                    .padding(.horizontal, 16)
                analysisRow(title: "Growth Stage",
                            value: "Stage \(report.hairFallStage.intValue)",
                            color: stageColor(report.hairFallStage.intValue))
                Divider()
                    .padding(.horizontal, 16)
                analysisRow(title: "Hair Type",
                            value: report.hairType?.capitalized ?? "N/A",
                            color: Color.blue.opacity(0.85))
                Divider()
                    .padding(.horizontal, 16)
                analysisRow(title: "Scan Type",
                            value: scanTypeLabel(report),
                            color: .primary)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private func scalpPhotosSection(report: ScanReport) -> some View {
        let scan = store.scalpScans.first { $0.id == report.scalpScanId }
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
        
        return Group {
            if !photoInfo.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scalp Photos")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photoInfo, id: \.path) { photo in
                                VStack(spacing: 6) {
                                    if let uiImage = UIImage(contentsOfFile: photo.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 95, height: 95)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Color.hcBrown, lineWidth: 2)
                                            )
                                        Text(photo.label)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
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
        .background(Color.white)
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
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
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
        .background(Color.white)
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
        .background(Color.white)
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

// MARK: 7 — Comparison View (Swift Charts Enhanced)

struct HairProgressComparisonView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReportIdA: UUID?
    @State private var selectedReportIdB: UUID?
    @State private var animateCharts = false

    // ── Data models for charts ──────────────────────────────────

    struct DensityPoint: Identifiable {
        let id: UUID
        let date: Date
        let density: Double
        let tag: String?        // "A", "B", or nil
    }

    struct LifestyleBar: Identifiable {
        let id = UUID()
        let dimension: String
        let scan: String        // "Scan A" or "Scan B"
        let value: Double
    }

    // ── Sorted reports for this user ────────────────────────────

    private var allUserReports: [ScanReport] {
        store.scanReports
            .filter { r in
                store.scalpScans.contains { $0.id == r.scalpScanId && $0.userId == store.currentUserId }
            }
            .sorted { $0.createdAt < $1.createdAt }   // oldest → newest for charts
    }

    private var reportA: ScanReport? { store.scanReports.first { $0.id == selectedReportIdA } }
    private var reportB: ScanReport? { store.scanReports.first { $0.id == selectedReportIdB } }

    // ── Chart data builders ─────────────────────────────────────

    private var densityPoints: [DensityPoint] {
        allUserReports.map { r in
            let tag: String?
            if r.id == selectedReportIdA { tag = "A" }
            else if r.id == selectedReportIdB { tag = "B" }
            else { tag = nil }
            return DensityPoint(id: r.id, date: r.createdAt,
                                density: Double(r.hairDensityPercent), tag: tag)
        }
    }

    private var lifestyleBars: [LifestyleBar] {
        guard let a = reportA, let b = reportB else { return [] }
        let dims = [("Sleep", a.sleepScore, b.sleepScore),
                    ("Stress", a.stressScore, b.stressScore),
                    ("Diet", a.dietScore, b.dietScore),
                    ("Hair Care", a.hairCareScore, b.hairCareScore)]
        return dims.flatMap { (name, va, vb) in [
            LifestyleBar(dimension: name, scan: "Scan A", value: Double(va)),
            LifestyleBar(dimension: name, scan: "Scan B", value: Double(vb))
        ]}
    }

    // ── Date formatter ──────────────────────────────────────────

    private static let shortDate: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "dd MMM, yyyy"; return df
    }()

    private static let axisDate: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "MMM yy"; return df
    }()

    // ── Body ────────────────────────────────────────────────────

    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ─── Scan Selectors ───────────────────
                        scanSelectors
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // ─── Density Trend Chart ──────────────
                        densityTrendCard
                            .padding(.horizontal, 20)

                        if reportA != nil && reportB != nil {

                            // ─── Delta Badge ──────────────────
                            deltaBadgeCard
                                .padding(.horizontal, 20)

                            // ─── Lifestyle Bar Chart ──────────
                            lifestyleChartCard
                                .padding(.horizontal, 20)

                            // ─── Side-by-side Photos ──────────
                            photoComparisonSection
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Compare Scans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(Color.hcBrown)
                }
            }
            .onAppear {
                let reports = allUserReports.reversed()   // newest first for default pick
                if let first = reports.first { selectedReportIdA = first.id }
                if reports.count > 1 { selectedReportIdB = reports[reports.index(reports.startIndex, offsetBy: 1)].id }
                withAnimation(.easeOut(duration: 0.9).delay(0.25)) { animateCharts = true }
            }
        }
    }

    // MARK: – Scan Selectors

    private var scanSelectors: some View {
        HStack(spacing: 12) {
            selectorMenu(label: "Scan A", selectedId: $selectedReportIdA,
                         accentColor: Color.hcBrown)
            selectorMenu(label: "Scan B", selectedId: $selectedReportIdB,
                         accentColor: Color(hue: 0.07, saturation: 0.55, brightness: 0.75))
        }
    }

    @ViewBuilder
    private func selectorMenu(label: String, selectedId: Binding<UUID?>, accentColor: Color) -> some View {
        let selected = store.scanReports.first { $0.id == selectedId.wrappedValue }
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(accentColor).frame(width: 8, height: 8)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(accentColor)
            }
            Menu {
                ForEach(allUserReports.reversed()) { r in
                    Button(Self.shortDate.string(from: r.createdAt)) { selectedId.wrappedValue = r.id }
                }
            } label: {
                HStack {
                    Text(selected.map { Self.shortDate.string(from: $0.createdAt) } ?? "Select Scan")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 11))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accentColor.opacity(0.35), lineWidth: 1.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Density Trend Chart

    private var densityTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Density Trend")
                    .font(.system(size: 17, weight: .bold))
                Text("Hair density % across all your scans")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if densityPoints.count < 2 {
                Text("Need at least 2 scans to show a trend.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart {
                    // Gradient area under the line
                    ForEach(densityPoints) { pt in
                        AreaMark(
                            x: .value("Date", pt.date),
                            y: .value("Density", animateCharts ? pt.density : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.hcBrown.opacity(0.22), Color.hcBrown.opacity(0.00)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Main line
                    ForEach(densityPoints) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Density", animateCharts ? pt.density : 0)
                        )
                        .foregroundStyle(Color.hcBrown)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }

                    // Plain data points
                    ForEach(densityPoints.filter { $0.tag == nil }) { pt in
                        PointMark(
                            x: .value("Date", pt.date),
                            y: .value("Density", animateCharts ? pt.density : 0)
                        )
                        .foregroundStyle(Color.hcBrown)
                        .symbolSize(40)
                    }

                    // Scan A highlight
                    ForEach(densityPoints.filter { $0.tag == "A" }) { pt in
                        PointMark(
                            x: .value("Date", pt.date),
                            y: .value("Density", animateCharts ? pt.density : 0)
                        )
                        .foregroundStyle(Color.hcBrown)
                        .symbolSize(110)
                        .annotation(position: .top, spacing: 5) {
                            Text("A")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.hcBrown)
                                .clipShape(Capsule())
                        }
                    }

                    // Scan B highlight
                    ForEach(densityPoints.filter { $0.tag == "B" }) { pt in
                        PointMark(
                            x: .value("Date", pt.date),
                            y: .value("Density", animateCharts ? pt.density : 0)
                        )
                        .foregroundStyle(Color(hue: 0.07, saturation: 0.55, brightness: 0.75))
                        .symbolSize(110)
                        .annotation(position: .top, spacing: 5) {
                            Text("B")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hue: 0.07, saturation: 0.55, brightness: 0.75))
                                .clipShape(Capsule())
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .stride(by: 20)) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let val = v.as(Double.self) {
                                Text("\(Int(val))%").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisValueLabel {
                            if let d = v.as(Date.self) {
                                Text(Self.axisDate.string(from: d))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
                .animation(.easeOut(duration: 0.9), value: animateCharts)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: – Delta Badge

    @ViewBuilder
    private var deltaBadgeCard: some View {
        if let a = reportA, let b = reportB {
            let delta = Double(b.hairDensityPercent) - Double(a.hairDensityPercent)
            let improved = delta >= 0
            let deltaText = String(format: "%+.1f%%", delta)
            let arrow = improved ? "arrow.up.right" : "arrow.down.right"
            let arrowColor: Color = improved ? .green : .red

            HStack(spacing: 0) {
                // Scan A
                VStack(spacing: 4) {
                    Text("\(Int(a.hairDensityPercent))%")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.hcBrown)
                    Text("Scan A")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(Self.shortDate.string(from: a.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                // Delta
                VStack(spacing: 6) {
                    Image(systemName: arrow)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(arrowColor)
                    Text(deltaText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(arrowColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(arrowColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                // Scan B
                VStack(spacing: 4) {
                    Text("\(Int(b.hairDensityPercent))%")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(hue: 0.07, saturation: 0.55, brightness: 0.75))
                    Text("Scan B")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(Self.shortDate.string(from: b.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: – Lifestyle Bar Chart

    private var lifestyleChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Lifestyle Comparison")
                    .font(.system(size: 17, weight: .bold))
                Text("How your habits compared between scans")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Color.hcBrown, label: "Scan A")
                legendDot(color: Color(hue: 0.07, saturation: 0.55, brightness: 0.75), label: "Scan B")
            }

            if lifestyleBars.isEmpty {
                Text("Select both scans to see lifestyle comparison.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart(lifestyleBars) { bar in
                    BarMark(
                        x: .value("Dimension", bar.dimension),
                        y: .value("Score", animateCharts ? bar.value : 0),
                        width: .ratio(0.38)
                    )
                    .foregroundStyle(
                        bar.scan == "Scan A"
                            ? Color.hcBrown
                            : Color(hue: 0.07, saturation: 0.55, brightness: 0.75)
                    )
                    .position(by: .value("Scan", bar.scan))
                    .cornerRadius(5)
                    .annotation(position: .top, spacing: 3) {
                        Text(String(format: "%.1f", animateCharts ? bar.value : 0))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(values: [0, 5, 10]) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let val = v.as(Double.self) {
                                Text(String(format: "%.0f", val))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { v in
                        AxisValueLabel {
                            if let str = v.as(String.self) {
                                Text(str)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .animation(.easeOut(duration: 0.9), value: animateCharts)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    // MARK: – Photo Comparison

    @ViewBuilder
    private var photoComparisonSection: some View {
        if let repA = reportA, let repB = reportB {
            VStack(alignment: .leading, spacing: 16) {
                Text("Scalp Photos")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.horizontal, 20)

                let scanA = store.scalpScans.first { $0.id == repA.scalpScanId }
                let scanB = store.scalpScans.first { $0.id == repB.scalpScanId }

                let pairs: [(label: String, pathA: String?, pathB: String?)] = [
                    ("Front",       scanA?.frontImageURL.resolvedLocalImagePath, scanB?.frontImageURL.resolvedLocalImagePath),
                    ("Left Side",   scanA?.leftImageURL.resolvedLocalImagePath,  scanB?.leftImageURL.resolvedLocalImagePath),
                    ("Right Side",  scanA?.rightImageURL.resolvedLocalImagePath, scanB?.rightImageURL.resolvedLocalImagePath),
                    ("Back / Crown",scanA?.backImageURL.resolvedLocalImagePath,  scanB?.backImageURL.resolvedLocalImagePath),
                    ("Top",         scanA?.topImageURL.resolvedLocalImagePath,   scanB?.topImageURL.resolvedLocalImagePath)
                ].filter { ($0.pathA != nil && !$0.pathA!.isEmpty) || ($0.pathB != nil && !$0.pathB!.isEmpty) }

                if pairs.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary.opacity(0.35))
                        Text("No scalp photos available to compare.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    ForEach(pairs, id: \.label) { pair in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pair.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                photoCell(path: pair.pathA, scanLabel: "Scan A",
                                          accentColor: Color.hcBrown)
                                photoCell(path: pair.pathB, scanLabel: "Scan B",
                                          accentColor: Color(hue: 0.07, saturation: 0.55, brightness: 0.75))
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func photoCell(path: String?, scanLabel: String, accentColor: Color) -> some View {
        VStack(spacing: 5) {
            if let p = path, let img = UIImage(contentsOfFile: p) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 145)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(accentColor, lineWidth: 1.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(height: 145)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary.opacity(0.4))
                            Text("N/A")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    )
            }
            HStack(spacing: 4) {
                Circle().fill(accentColor).frame(width: 7, height: 7)
                Text(scanLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

