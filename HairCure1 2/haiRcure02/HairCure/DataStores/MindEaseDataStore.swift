import Foundation
import Observation

@Observable
final class MindEaseDataStore {
    
    var mindEaseCategories:       [MindEaseCategory]        = []
    var mindEaseCategoryContents: [MindEaseCategoryContent] = []
    var mindfulSessions:          [MindfulSession]          = []
    var todaysPlans:              [TodaysPlan]              = []
    var sessionStartTimes:        [UUID: Date]              = [:]
    var isLoadingContent:         Bool                      = false
    /// Non-nil when the backend load fails — display this in the UI.
    var loadError:                String?                   = nil
    
    var currentUserId: UUID
    weak var parentStore: AppDataStore?
    
    init(currentUserId: UUID) {
        self.currentUserId = currentUserId
    }
    
    // MARK: - Backend Load
    // All category and content data lives exclusively in Supabase.
    // There is no local fallback — if the fetch fails, loadError is set
    // and the UI should show a retry prompt.
    
    func loadFromBackend() async {
        await MainActor.run {
            isLoadingContent = true
            loadError        = nil
        }
        do {
            let (cats, contents) = try await MindEaseBackendService.shared
                .fetchCategoriesAndContents()
            await MainActor.run {
                mindEaseCategories       = cats
                mindEaseCategoryContents = contents
                isLoadingContent         = false
                
                if todaysPlans.filter({
                    $0.userId == currentUserId &&
                    Calendar.current.isDateInToday($0.planDate)
                }).isEmpty,
                   let store = parentStore,
                   !store.userPlans.isEmpty {
                    seedTodaysPlan(userId: currentUserId, userPlans: store.userPlans)
                }
            }
        } catch {
            print("MindEase backend load failed: \(error)")
            await MainActor.run {
                isLoadingContent = false
                loadError        = "Could not load content. Please check your connection and try again."
            }
        }
    }
    
    func addAll(userId: UUID, userPlans: [UserPlan]) {
        seedTodaysPlan(userId: userId, userPlans: userPlans)
    }
    
    private func seedTodaysPlan(userId: UUID, userPlans: [UserPlan]) {
        guard let plan = userPlans.first(where: { $0.userId == userId }) else { return }
        let today  = Date()
        var result: [TodaysPlan] = []
        
        let dailyPlan: [(categoryTitle: String, totalMinutes: Int)] = [
            ("Meditation",      plan.meditationMinutesPerDay),
            ("Yoga",            plan.yogaMinutesPerDay),
            ("Relaxing Sounds", plan.soundMinutesPerDay),
        ]
        
        for (categoryTitle, totalMinutes) in dailyPlan {
            guard totalMinutes > 0,
                  let cat = mindEaseCategories.first(where: { $0.title == categoryTitle })
            else { continue }
            
            let pool = mindEaseCategoryContents
                .filter { $0.categoryId == cat.id }
                .shuffled()
            
            guard let recommendedContent = pool.first else { continue }
            
            result.append(TodaysPlan(
                id: UUID(), userId: userId, planDate: today,
                contentId: recommendedContent.id, categoryId: cat.id,
                planId: plan.planId,
                minutesTarget: totalMinutes, minutesCompleted: 0,
                isCompleted: false
            ))
        }
        
        todaysPlans = result
    }
    
    func saveSession(_ session: MindfulSession) async {
        mindfulSessions.append(session)
        await MindEaseBackendService.shared.saveSession(session)
    }
    
    func loadSessions() async {
        let remote = await MindEaseBackendService.shared.fetchSessions(userId: currentUserId)
        await MainActor.run {
            let remoteIds = Set(remote.map { $0.id })
            let localOnly = mindfulSessions.filter { !remoteIds.contains($0.id) }
            mindfulSessions = (remote + localOnly)
                .sorted { $0.sessionDate > $1.sessionDate }
        }
    }
    
    // MARK: - Computed Daily Target
    
    var dailyMindfulTarget: Int {
        guard let store = parentStore,
              let plan  = store.userPlans.first(where: { $0.userId == currentUserId })
        else { return 30 }
        return plan.meditationMinutesPerDay + plan.yogaMinutesPerDay + plan.soundMinutesPerDay
    }
    
    func durationMinutes(for content: MindEaseCategoryContent) -> Int {
        content.durationSeconds / 60
    }
    
    func sessions(for date: Date) -> [MindfulSession] {
        mindfulSessions.filter {
            $0.userId == currentUserId &&
            Calendar.current.isDate($0.sessionDate, inSameDayAs: date)
        }
    }
    
    func mindfulMinutes(for date: Date) -> Int {
        sessions(for: date).reduce(0) { $0 + $1.minutesCompleted }
    }
    
    func todaysMindfulMinutes() -> Int {
        mindfulMinutes(for: .now)
    }
    
    func weeklyMindfulMinutes() -> [Int] {
        let cal = Calendar.current
        return (0..<7).map { daysAgo -> Int in
            guard let day = cal.date(byAdding: .day, value: -daysAgo, to: .now) else { return 0 }
            return mindfulMinutes(for: day)
        }.reversed()
    }
    
    func getContentItems(for categoryId: UUID) -> [MindEaseCategoryContent] {
        mindEaseCategoryContents.filter { $0.categoryId == categoryId }
    }
    
    func categoryMinutes(named categoryTitle: String, for date: Date, userId: UUID) -> Int {
        sessions(for: date)
            .filter { session in
                guard session.userId == userId,
                      let content = mindEaseCategoryContents.first(where: { $0.id == session.contentId }),
                      let cat     = mindEaseCategories.first(where: { $0.id == content.categoryId })
                else { return false }
                return cat.title == categoryTitle
            }
            .reduce(0) { $0 + $1.minutesCompleted }
    }
    
    // MARK: - Session Lookup Helpers
    
    func content(for session: MindfulSession) -> MindEaseCategoryContent? {
        mindEaseCategoryContents.first { $0.id == session.contentId }
    }
    
    func sessionIcon(for session: MindfulSession) -> String {
        guard let content  = content(for: session),
              let category = mindEaseCategories.first(where: { $0.id == content.categoryId })
        else { return "brain.head.profile" }
        return category.cardIconName
    }
    
    func contentTitle(for session: MindfulSession) -> String {
        content(for: session)?.title ?? "Session"
    }
    
    func categoryName(for session: MindfulSession) -> String {
        guard let content  = content(for: session),
              let category = mindEaseCategories.first(where: { $0.id == content.categoryId })
        else { return "MindEase" }
        return category.title
    }
    
    // MARK: - Today's Plan Helpers
    
    func todayPlan(for content: MindEaseCategoryContent) -> TodaysPlan? {
        todaysPlans.first {
            $0.userId == currentUserId &&
            $0.contentId == content.id &&
            Calendar.current.isDateInToday($0.planDate)
        }
    }
    
    func todayActivePlans() -> [TodaysPlan] {
        todaysPlans.filter {
            $0.userId == currentUserId &&
            Calendar.current.isDateInToday($0.planDate)
        }
    }
    
    private func updatePlan(contentId: UUID, minutesCompleted: Int) {
        guard let content = mindEaseCategoryContents.first(where: { $0.id == contentId }) else { return }
        guard let idx = todaysPlans.firstIndex(where: {
            $0.userId == currentUserId &&
            $0.categoryId == content.categoryId &&
            Calendar.current.isDateInToday($0.planDate)
        }) else { return }
        
        todaysPlans[idx].minutesCompleted += minutesCompleted
        let completed = todaysPlans[idx].minutesCompleted >= todaysPlans[idx].minutesTarget
        todaysPlans[idx].isCompleted = completed
        
        // If target is not yet met, cycle recommended session to a different track
        if !completed {
            let pool = mindEaseCategoryContents.filter { $0.categoryId == content.categoryId }
            if let nextContent = pool.filter({ $0.id != contentId }).shuffled().first {
                todaysPlans[idx].contentId = nextContent.id
            }
        }
    }
    
    func startSession(contentId: UUID) {
        sessionStartTimes[contentId] = .now
    }
    
    func completeSession(contentId: UUID, minutesCompleted: Int) -> ActionResult {
        guard minutesCompleted > 0 else {
            return .blocked(reason: "Session too short to log (< 1 minute).")
        }
        let now       = Date.now
        let startTime = sessionStartTimes[contentId] ??
        Calendar.current.date(byAdding: .minute, value: -minutesCompleted, to: now)!
        sessionStartTimes.removeValue(forKey: contentId)
        
        let session = MindfulSession(
            id: UUID(), userId: currentUserId,
            contentId: contentId, sessionDate: now,
            minutesCompleted: minutesCompleted,
            startTime: startTime, endTime: now
        )
        mindfulSessions.append(session)
        updatePlan(contentId: contentId, minutesCompleted: minutesCompleted)
        
        Task { await MindEaseBackendService.shared.saveSession(session) }
        
        let target = todaysPlans.first(where: {
            $0.userId == currentUserId && $0.contentId == contentId
        })?.minutesTarget ?? minutesCompleted
        
        return minutesCompleted >= target
        ? .success(message: "Session complete! \(minutesCompleted) min logged.")
        : .warning(message: "Session logged — \(minutesCompleted)/\(target) min completed.")
    }
    
    func logMindfulSession(contentId: UUID, minutesCompleted: Int) {
        guard minutesCompleted > 0 else { return }
        let now = Date.now
        let session = MindfulSession(
            id: UUID(), userId: currentUserId, contentId: contentId,
            sessionDate: now, minutesCompleted: minutesCompleted,
            startTime: Calendar.current.date(byAdding: .minute, value: -minutesCompleted, to: now)!,
            endTime: now
        )
        mindfulSessions.append(session)
        updatePlan(contentId: contentId, minutesCompleted: minutesCompleted)
        Task { await MindEaseBackendService.shared.saveSession(session) }
    }
    
    // MARK: - Mood Tracking & Recommendations
    
    func logUserMood(_ mood: String) async {
        await MindEaseBackendService.shared.logUserMood(userId: currentUserId, mood: mood)
    }
    
    func fetchMoodRecommendations(for mood: String) async -> [MindEaseCategoryContent] {
        return await MindEaseBackendService.shared.fetchMoodRecommendations(mood: mood)
    }
}
