import SwiftUI
import AVKit
import AVFoundation   // ← required for AVAudioSession

// MARK: - Theme

extension Color {
    static let mindEasePurple = Color(red: 0.40, green: 0.30, blue: 0.85)
}

extension Date {
    func mindEaseFormatted(_ format: String) -> String {
        Date.meFormatter(format).string(from: self)
    }
    private static var meCache: [String: DateFormatter] = [:]
    private static func meFormatter(_ format: String) -> DateFormatter {
        if let f = meCache[format] { return f }
        let f = DateFormatter(); f.dateFormat = format
        meCache[format] = f; return f
    }
}

extension Date: Identifiable {
    public var id: Date { self }
}

// MARK: - View Modifiers

extension View {
    func mindEaseCard(cornerRadius: CGFloat = 18, shadowRadius: CGFloat = 10, shadowY: CGFloat = 4) -> some View {
        self.background(.background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: shadowRadius, x: 0, y: shadowY)
    }
    func mindEaseSectionHeader() -> some View {
        self.font(.system(size: 22, weight: .bold)).padding(.horizontal, 20)
    }
    func mindEaseStatValue(size: CGFloat = 28) -> some View {
        self.font(.system(size: size, weight: .bold)).foregroundStyle(Color.mindEasePurple)
    }
    func mindEasePageBackground() -> some View {
        self.background(Color.hcCream.ignoresSafeArea())
    }
}

// MARK: ── MindEaseView

struct MindEaseView: View {
    @Environment(AppDataStore.self)      private var store
    @Environment(MindEaseDataStore.self) private var mindEaseStore

    @State private var sheetDate:         Date? = nil
    @State private var selectedDate:      Date  = Calendar.current.startOfDay(for: .now)
    @State private var showCalendarSheet        = false

    private var weekDates: [Date] {
        let cal    = Calendar.current
        let today  = cal.startOfDay(for: .now)
        let offset = -(cal.component(.weekday, from: today) - 1)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: offset + $0, to: today) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                // Date header
                HStack(spacing: 8) {
                    Text("Today, \(Date().mindEaseFormatted("d MMM yyyy"))")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button { showCalendarSheet = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.mindEasePurple)
                            .padding(8)
                            .background(Color.mindEasePurple.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 0) {
                    ForEach(weekDates, id: \.self) { date in
                        WeekDayCell(
                            date: date,
                            dailyTarget: mindEaseStore.dailyMindfulTarget,
                            minutes: mindEaseStore.mindfulMinutes(for: date),
                            isSelected: Calendar.current.startOfDay(for: date) == selectedDate,
                            onTap: {
                                let day = Calendar.current.startOfDay(for: date)
                                selectedDate = day
                                sheetDate    = day
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Loading / error states
                if mindEaseStore.isLoadingContent {
                    HStack { Spacer(); ProgressView().padding(.vertical, 24); Spacer() }
                } else if let errorMsg = mindEaseStore.loadError {
                    // Backend failed — show error + retry, never fall back to local data
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundStyle(.secondary)
                        Text(errorMsg)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            Task { await mindEaseStore.loadFromBackend() }
                        } label: {
                            Text("Try Again")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28).padding(.vertical, 10)
                                .background(Color.mindEasePurple).clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {

                    // Categories
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Categories").mindEaseSectionHeader()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(mindEaseStore.mindEaseCategories) { cat in
                                    NavigationLink(value: cat) { CategoryCard(category: cat) }
                                        .buttonStyle(.plain)
                                        .scrollTransition(.animated.threshold(.visible(0.05))) { c, p in
                                            c.opacity(p.isIdentity ? 1 : 0).scaleEffect(p.isIdentity ? 1 : 0.88)
                                        }
                                }
                            }
                            .padding(.horizontal, 20).padding(.bottom, 4)
                        }
                    }

                    // Today's plan
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Today's Plan").mindEaseSectionHeader()
                        let plans = mindEaseStore.todayActivePlans()
                        if plans.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 36, weight: .ultraLight))
                                    .foregroundStyle(Color.mindEasePurple.opacity(0.5))
                                Text(store.userPlans.isEmpty
                                     ? "Complete your assessment to get a personalised plan"
                                     : "Your plan is being prepared…")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .mindEaseCard(cornerRadius: 16)
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(plans.enumerated()), id: \.element.id) { idx, plan in
                                    if let content = mindEaseStore.mindEaseCategoryContents
                                        .first(where: { $0.id == plan.contentId }) {
                                        NavigationLink(value: content) {
                                            PlanRow(plan: plan, content: content, store: mindEaseStore)
                                        }
                                        .buttonStyle(.plain)
                                        .scrollTransition(.animated.threshold(.visible(0.1))) { c, p in
                                            c.opacity(p.isIdentity ? 1 : 0).offset(y: p.isIdentity ? 0 : 22)
                                        }
                                        if idx < plans.count - 1 { Divider().padding(.leading, 96) }
                                    }
                                }
                            }
                            .mindEaseCard(cornerRadius: 16)
                            .padding(.horizontal, 20)
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .mindEasePageBackground()
        .navigationDestination(for: MindEaseCategory.self)        { MindEaseCategoryListView(category: $0) }
        .navigationDestination(for: MindEaseCategoryContent.self) { MindEasePlayerView(content: $0) }
        .sheet(item: $sheetDate) { DayDetailSheet(date: $0) }
        .sheet(isPresented: $showCalendarSheet) { CalendarPickerSheet() }
        .task {
            if mindEaseStore.mindEaseCategories.isEmpty {
                await mindEaseStore.loadFromBackend()
            } else if mindEaseStore.todayActivePlans().isEmpty,
                      !store.userPlans.isEmpty {
                // Categories already cached but plan was seeded before content loaded — re-seed.
                mindEaseStore.addAll(userId: store.currentUserId, userPlans: store.userPlans)
            }
        }
    }
}

// MARK: - Week Day Cell

private struct WeekDayCell: View {
    let date: Date; let dailyTarget: Int; let minutes: Int
    let isSelected: Bool; let onTap: () -> Void

    private var cal:      Calendar { .current }
    private var dayStart: Date     { cal.startOfDay(for: date) }
    private var isToday:  Bool     { cal.isDateInToday(date) }
    private var isFuture: Bool     { dayStart > cal.startOfDay(for: .now) }
    private var letter:   String   { ["S","M","T","W","T","F","S"][cal.component(.weekday, from: date) - 1] }
    private var progress: Double   { min(Double(minutes) / Double(max(1, dailyTarget)), 1.0) }

    private var ringColor: Color {
        guard !isFuture, minutes > 0 else { return Color(UIColor.systemGray3) }
        return minutes > dailyTarget ? .orange : Color.mindEasePurple
    }

    var body: some View {
        Button {
            guard !isFuture else { return }
            onTap()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isToday {
                        Circle().fill(Color.mindEasePurple).frame(width: 28, height: 28)
                    }
                    Text(letter)
                        .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                        .foregroundStyle(isToday ? .white : (isFuture ? Color.secondary : Color.primary))
                }
                .frame(width: 28, height: 28)

                ZStack {
                    Circle().stroke(Color(UIColor.systemGray4), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: progress)
                    if isSelected && !isToday {
                        Circle().fill(Color.mindEasePurple).frame(width: 6, height: 6)
                    }
                }
                .frame(width: 34, height: 34)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: MindEaseCategory
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MindEaseThumbnail(
                imageurl: category.cardImageUrl,
                size: 220, height: 145,
                cornerRadius: 0,
                placeholder: category.cardIconName,
                placeholderSize: 44
            )
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .frame(width: 220, height: 145)
            VStack(alignment: .leading, spacing: 5) {
                Text(category.title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Text(category.categoryDescription)
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.80))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .frame(width: 220, height: 145)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Plan Row

private struct PlanRow: View {
    let plan: TodaysPlan; let content: MindEaseCategoryContent; let store: MindEaseDataStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            MindEaseThumbnail(
                imageurl: content.thumbnailUrl ?? content.imageurl,
                size: 68, cornerRadius: 10,
                placeholder: content.mediaType == .audio ? "waveform" : "play.fill"
            )
            VStack(alignment: .leading, spacing: 6) {
                Text(content.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(content.difficultyLevel.capitalized)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if plan.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28)).foregroundStyle(Color.mindEasePurple)
            } else {
                Text("Start")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Color.mindEasePurple).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Calendar Picker Sheet

private struct CalendarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pickedDate    = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
    @State private var showDayDetail = false

    var body: some View {
        NavigationStack {
            DatePicker(
                "Select a past date",
                selection: Binding(
                    get: { pickedDate },
                    set: { pickedDate = Calendar.current.startOfDay(for: $0) }
                ),
                in: ...Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.mindEasePurple)
            .padding(.horizontal, 16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                            .padding(8).background(Color(.systemGray5)).clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("View Day") { showDayDetail = true }
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.mindEasePurple)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showDayDetail) { DayDetailSheet(date: pickedDate) }
    }
}

// MARK: ── MindEaseProgressView

struct MindEaseProgressView: View {
    @Environment(AppDataStore.self)      private var store
    @Environment(MindEaseDataStore.self) private var mindEaseStore

    private var recentDates: [Date] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (1...7).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    @State private var sheetDate: Date? = nil
    @State private var showDatePicker   = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                let done   = mindEaseStore.mindfulMinutes(for: .now)
                let target = max(1, mindEaseStore.dailyMindfulTarget)
                HStack(spacing: 16) {
                    MindEaseProgressRing(progress: min(Double(done) / Double(target), 1.0), lineWidth: 8, diameter: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today").font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(done)").mindEaseStatValue()
                            Text("/ \(target) min").font(.system(size: 14)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(16).mindEaseCard()
                .padding(.horizontal, 20).padding(.top, 4)

                HStack {
                    Text("Recent Days").mindEaseSectionHeader()
                    Spacer()
                    Button { showDatePicker = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.mindEasePurple)
                            .padding(.trailing, 20)
                    }
                    .sheet(isPresented: $showDatePicker) { CalendarPickerSheet() }
                }

                VStack(spacing: 0) {
                    ForEach(Array(recentDates.enumerated()), id: \.element) { idx, date in
                        DayProgressRow(
                            date: date,
                            minutes: mindEaseStore.mindfulMinutes(for: date),
                            target: mindEaseStore.dailyMindfulTarget,
                            onTap: { sheetDate = date }
                        )
                        if idx < recentDates.count - 1 { Divider().padding(.leading, 20) }
                    }
                }
                .mindEaseCard().padding(.horizontal, 20)

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("MindEase Progress")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheetDate) { DayDetailSheet(date: $0) }
    }
}

private struct DayProgressRow: View {
    let date: Date; let minutes: Int; let target: Int; let onTap: () -> Void
    private var progress: Double { min(Double(minutes) / Double(max(1, target)), 1.0) }
    private var label: String {
        Calendar.current.isDateInYesterday(date) ? "Yesterday" : date.mindEaseFormatted("EEE, d MMM")
    }
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                MindEaseProgressRing(progress: progress, lineWidth: 4, diameter: 36).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 15, weight: .semibold))
                    Text(minutes > 0 ? "\(minutes) min · \(Int(progress * 100))% of goal" : "Rest day")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: ── DayDetailSheet

struct DayDetailSheet: View, Identifiable {
    var id: Date { date }
    @Environment(AppDataStore.self)      private var store
    @Environment(MindEaseDataStore.self) private var mindEaseStore
    @Environment(\.dismiss)             private var dismiss
    let date: Date

    private var sessions: [MindfulSession] {
        let dayStart = Calendar.current.startOfDay(for: date)
        return mindEaseStore.mindfulSessions
            .filter {
                $0.userId == store.currentUserId &&
                Calendar.current.startOfDay(for: $0.sessionDate) == dayStart
            }
            .sorted { $0.startTime < $1.startTime }
    }
    private var totalMinutes:  Int    { sessions.reduce(0) { $0 + $1.minutesCompleted } }
    private var targetMinutes: Int    { mindEaseStore.dailyMindfulTarget }
    private var fraction:      Double {
        guard targetMinutes > 0 else { return 0 }
        return min(Double(totalMinutes) / Double(targetMinutes), 1.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    HStack(spacing: 16) {
                        MindEaseProgressRing(progress: fraction, lineWidth: 8, diameter: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(totalMinutes)").mindEaseStatValue()
                                Text("/ \(targetMinutes) min").font(.system(size: 14)).foregroundStyle(.secondary)
                            }
                            Text(totalMinutes == 0 ? "No sessions logged"
                                 : fraction >= 1   ? "Goal reached 🎉"
                                                   : "\(targetMinutes - totalMinutes) min short")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(fraction >= 1 ? Color.mindEasePurple : .secondary)
                        }
                        Spacer()
                    }
                    .padding(16).mindEaseCard().padding(.horizontal, 20)

                    Text(sessions.isEmpty ? "Sessions" : "Sessions (\(sessions.count))").mindEaseSectionHeader()

                    if sessions.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 44)).foregroundStyle(.secondary.opacity(0.35))
                            Text("No sessions logged for this day").font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 48)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(sessions.enumerated()), id: \.element.id) { idx, session in
                                SessionRow(session: session)
                                if idx < sessions.count - 1 { Divider().padding(.leading, 72) }
                            }
                        }
                        .mindEaseCard(cornerRadius: 16, shadowRadius: 8, shadowY: 3)
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .mindEasePageBackground()
            .navigationTitle(date.mindEaseFormatted("EEE, d MMM"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct SessionRow: View {
    @Environment(MindEaseDataStore.self) private var mindEaseStore
    let session: MindfulSession
    var body: some View {
        HStack(spacing: 14) {
            MindEaseSessionIconView(iconName: mindEaseStore.sessionIcon(for: session), size: 52, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(mindEaseStore.contentTitle(for: session))
                    .font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text("\(session.startTime.mindEaseFormatted("h:mm a")) – \(session.endTime.mindEaseFormatted("h:mm a"))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(session.minutesCompleted)").mindEaseStatValue(size: 18)
                Text("min").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: ── MindEaseCategoryListView

struct MindEaseCategoryListView: View {
    let category: MindEaseCategory
    @Environment(MindEaseDataStore.self) private var mindEaseStore

    var body: some View {
        let contents = mindEaseStore.mindEaseCategoryContents.filter { $0.categoryId == category.id }
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(contents.enumerated()), id: \.element.id) { idx, content in
                        NavigationLink(value: content) { ContentRow(content: content, store: mindEaseStore) }
                            .buttonStyle(.plain)
                            .scrollTransition(.animated.threshold(.visible(0.05))) { c, p in
                                c.opacity(p.isIdentity ? 1 : 0).offset(x: p.isIdentity ? 0 : 24)
                            }
                        if idx < contents.count - 1 { Divider().padding(.leading, 100) }
                    }
                }
                .mindEaseCard()
                .padding(.horizontal, 16).padding(.top, 12)
                Spacer(minLength: 32)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .mindEasePageBackground()
        .navigationTitle(category.title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct ContentRow: View {
    let content: MindEaseCategoryContent; let store: MindEaseDataStore
    private var isAudio: Bool { content.mediaType == .audio }
    var body: some View {
        HStack(spacing: 14) {
            MindEaseThumbnail(
                imageurl: content.thumbnailUrl ?? content.imageurl,
                size: 78, height: 68, cornerRadius: 10,
                placeholder: isAudio ? "waveform" : "play.fill"
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(content.caption).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(isAudio ? 2 : 1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
    }
}

// MARK: ── MindEasePlayerView
// Plays video/audio from a Cloudinary URL using AVKit.
// FIX: AVAudioSession is configured for .playback so audio works on silent mode
//      and doesn't get blocked by the iOS media session.

struct MindEasePlayerView: View {
    let content: MindEaseCategoryContent
    @Environment(MindEaseDataStore.self) private var mindEaseStore

    @State private var player:        AVPlayer? = nil
    @State private var isPlaying                = false
    @State private var currentSeconds: Double   = 0.0   // actual playback position in seconds
    @State private var realDuration:   Double   = 0.0   // actual media duration (auto-detected from file)
    @State private var timeObserver:   Any?     = nil
    @State private var loadError:      Bool     = false

    private var elapsed:   Int { Int(currentSeconds) }
    private var remaining: Int { max(0, Int(realDuration) - elapsed) }
    private var progress:  Double {
        guard realDuration > 0 else { return 0 }
        return min(currentSeconds / realDuration, 1.0)
    }
    private func timeLabel(_ s: Int) -> String { String(format: "%02d : %02d", s / 60, s % 60) }

    private func saveProgress() {
        let mins = elapsed / 60
        guard mins > 0 else { return }
        mindEaseStore.logMindfulSession(contentId: content.id, minutesCompleted: mins)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                // ── Media area ───────────────────────────────
                if content.mediaType == .video, let player {
                    VideoPlayer(player: player)
                        .frame(width: geo.size.width, height: geo.size.height * 0.48)
                        .clipped()
                } else {
                    // Audio — show thumbnail + animated waveform overlay
                    ZStack {
                        MindEaseThumbnail(
                            imageurl: content.thumbnailUrl ?? content.imageurl,
                            size: geo.size.width,
                            height: geo.size.height * 0.48,
                            cornerRadius: 0,
                            placeholder: "waveform",
                            placeholderSize: 64
                        )
                        .clipped()

                        // Dark scrim so waveform reads clearly
                        Color.black.opacity(0.35)
                            .frame(width: geo.size.width, height: geo.size.height * 0.48)

                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 56, weight: .ultraLight))
                                .foregroundStyle(.white.opacity(0.90))
                                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 48, weight: .ultraLight))
                                .foregroundStyle(.white.opacity(0.70))
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height * 0.48)
                }

                // ── Error banner ─────────────────────────────
                if loadError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Could not load media — check your Cloudinary URL.")
                            .font(.system(size: 13))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.12))
                }

                // ── Controls ─────────────────────────────────
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(content.title).font(.system(size: 22, weight: .bold)).lineLimit(1)
                            if content.mediaType == .audio {
                                Label("Audio", systemImage: "waveform")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.mindEasePurple)
                            }
                        }
                        Spacer()
                    }

                    Slider(value: Binding(
                        get: { progress },
                        set: { newValue in
                            guard realDuration > 0 else { return }
                            currentSeconds = newValue * realDuration
                        }
                    ), in: 0...1) { editing in
                        if !editing, let player, realDuration > 0 {
                            player.seek(to: CMTime(seconds: currentSeconds, preferredTimescale: 600))
                        }
                    }
                    .tint(Color.mindEasePurple)
                    .padding(.top, 16)

                    HStack {
                        Text(timeLabel(elapsed))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(timeLabel(remaining))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 0) {
                        Button { seekRelative(seconds: -10) } label: {
                            Image(systemName: "gobackward.10").font(.system(size: 24))
                        }.frame(maxWidth: .infinity)

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { togglePlayback() }
                        } label: {
                            ZStack {
                                Circle().fill(Color.mindEasePurple).frame(width: 64, height: 64)
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24)).foregroundStyle(.white)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }.frame(maxWidth: .infinity)

                        Button { seekRelative(seconds: 10) } label: {
                            Image(systemName: "goforward.10").font(.system(size: 24))
                        }.frame(maxWidth: .infinity)
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationTitle(content.title).navigationBarTitleDisplayMode(.inline)
        .onAppear  { setupPlayer() }
        .onDisappear { teardownPlayer(); saveProgress() }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        guard let url = URL(string: content.mediaURL) else {
            print("[Player] Invalid URL: \(content.mediaURL)")
            loadError = true
            return
        }

        // ── Configure AVAudioSession for playback ───────────────────────────
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Player] AVAudioSession setup failed: \(error)")
        }
        // ───────────────────────────────────────────────────────────────────

        let avPlayer = AVPlayer(url: url)
        player = avPlayer

        // Async-load the real duration from the asset metadata BEFORE playback
        Task {
            let asset = AVURLAsset(url: url)
            if let dur = try? await asset.load(.duration),
               dur.isNumeric, dur.seconds > 0 {
                await MainActor.run { realDuration = dur.seconds }
            }
        }

        // Periodic time observer — updates every 0.25s for smooth playback
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak avPlayer] time in
            guard let item = avPlayer?.currentItem else { return }
            let duration = item.duration
            guard duration.isNumeric, duration.seconds > 0 else { return }

            // Update real duration from the actual media file
            realDuration   = duration.seconds
            currentSeconds = time.seconds
            isPlaying      = avPlayer?.rate != 0
        }

        // End-of-playback observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            isPlaying      = false
            currentSeconds = realDuration
            saveProgress()
        }

        // Error observer — fires if the URL is unreachable / wrong format
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { notification in
            if let err = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("[Player] Playback failed: \(err)")
            }
            loadError = true
        }
    }

    private func teardownPlayer() {
        player?.pause()
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        timeObserver = nil
        NotificationCenter.default.removeObserver(self)
        player = nil
        // Deactivate audio session so other apps can resume
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func seekRelative(seconds: Double) {
        guard let player else { return }
        let current = player.currentTime().seconds
        let newTime = min(max(0, current + seconds), realDuration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
}

// MARK: ── Shared Primitives

struct MindEaseProgressRing: View {
    let progress: Double; let lineWidth: CGFloat; let diameter: CGFloat
    var color: Color = .mindEasePurple; var trackOpacity: Double = 0.15
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(trackOpacity), lineWidth: lineWidth)
            Circle().trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct MindEaseSessionIconView: View {
    let iconName: String; let size: CGFloat; let cornerRadius: CGFloat
    var color: Color = .mindEasePurple
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color.opacity(0.10)).frame(width: size, height: size)
            .overlay(Image(systemName: iconName).font(.system(size: size * 0.45)).foregroundStyle(color))
    }
}

/// Unified image view — auto-detects remote URLs (starts with "http/https").
/// Falls back to a local named asset, then to an SF Symbol placeholder.
/// Pass any URL string or local asset name to `imageurl`.
struct MindEaseThumbnail: View {
    /// Either a full https:// URL (Cloudinary) or a local asset name.
    let imageurl: String
    var size: CGFloat            = 68
    var height: CGFloat?         = nil
    var cornerRadius: CGFloat    = 10
    var placeholder: String      = "photo"
    var placeholderSize: CGFloat = 20

    /// Resolved remote URL string — non-nil only when imageurl looks like a URL.
    private var remoteURL: URL? {
        guard imageurl.hasPrefix("http://") || imageurl.hasPrefix("https://") else { return nil }
        return URL(string: imageurl)
    }

    var body: some View {
        Group {
            if let url = remoteURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        // Remote load failed — try local asset next
                        localOrPlaceholder
                    default:
                        // Loading spinner
                        Color(UIColor.systemGray5)
                            .overlay(ProgressView().scaleEffect(0.7))
                    }
                }
            } else {
                localOrPlaceholder
            }
        }
        .frame(width: size, height: height ?? size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var localOrPlaceholder: some View {
        if !imageurl.isEmpty, let img = UIImage(named: imageurl) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            // No local asset — show SF Symbol placeholder
            Color(UIColor.systemGray5)
                .overlay(
                    Image(systemName: placeholder)
                        .font(.system(size: placeholderSize, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                )
        }
    }
}

// MARK: ── Previews

#Preview("Home") {
    NavigationStack {
        MindEaseView()
            .environment(AppDataStore())
            .environment(MindEaseDataStore(currentUserId: UUID()))
    }
}

#Preview("Progress") {
    NavigationStack {
        MindEaseProgressView()
            .environment(AppDataStore())
            .environment(MindEaseDataStore(currentUserId: UUID()))
    }
}

#Preview("Day Detail Sheet") {
    DayDetailSheet(date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
        .environment(AppDataStore())
        .environment(MindEaseDataStore(currentUserId: UUID()))
}

// Note: The Category List preview is intentionally omitted here because
// MindEaseDataStore no longer has a local fallback — all data loads from
// Supabase. Run the app on a simulator/device to preview this screen.
