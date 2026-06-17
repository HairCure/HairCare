import Foundation
import Observation

@Observable
class AppDataStore {
    
    // MARK: - Core User
    var users: [User] = []
    var userProfiles: [UserProfile] = []
    var currentUserId: UUID = UUID()
    
    // MARK: - Assessment
    var assessments: [Assessment] = []
    var questions: [Question] = []
    var questionOptions: [QuestionOption] = []
    var questionScoreMaps: [QuestionScoreMap] = []
    var userAnswers: [UserAnswer] = []
    
    // MARK: - Scalp Scan
    var scalpScans: [ScalpScan] = []
    var scanReports: [ScanReport] = []
    
    // MARK: - Engine Output
    var userPlans: [UserPlan] = []
    var userNutritionProfiles: [UserNutritionProfile] = []
    
    // MARK: - Trackers
    var sleepRecords: [SleepRecord] = []
    var waterIntakeLogs: [WaterIntakeLog] = []
    
    // MARK: - Hair Insights
    private(set) var hairInsightsStore: HairInsightsDataStore = HairInsightsDataStore()
    
    // MARK: - DietMate
    private(set) var dietMateStore: DietmateDataStore = DietmateDataStore(currentUserId: UUID())
    
    // MARK: - MindEase
    private(set) var mindEaseStore: MindEaseDataStore = MindEaseDataStore(currentUserId: UUID())
    
    // MARK: - Settings
    var appPreferences: [AppPreferences] = []
    var notificationSettings: [NotificationSettings] = []
    
    // MARK: - Init
    
    init() {
        // Only seed the question bank and content library — no user data
        seedQuestions()
        hairInsightsStore = HairInsightsDataStore()
    }
    
    
    // MARK: 1 — Create User (called from auth flow)
    
    
    
    
    func createUser(
        name: String,
        email: String,
        phone: String? = nil,
        authProvider: AuthProvider = .guest,
        supabaseId: String? = nil
    ) {
        // Use Supabase UUID if provided, otherwise generate local one
        let userId = supabaseId.flatMap { UUID(uuidString: $0) } ?? UUID()
        currentUserId = userId
        
        users.append(User(
            id: userId,
            name: name,
            email: email,
            phoneNumber: phone,
            authProvider: authProvider,
            createdAt: Date()
        ))
        
        userProfiles.append(UserProfile(
            id: UUID(),
            userId: userId,
            username: name.lowercased().replacingOccurrences(of: " ", with: ""),
            displayName: name,
            dateOfBirth: Date(),
            gender: "",
            heightCm: 0,
            weightKg: 0,
            hairType: "",
            scalpType: "",
            isVegetarian: false,
            profileImageURL: nil,
            isProfileComplete: false,
            joinedAt: Date()
        ))
        
        dietMateStore = DietmateDataStore(currentUserId: userId)
        dietMateStore.parentStore = self
        Task { await dietMateStore.loadFoodsFromBackend() }
        dietMateStore.seedDefaultMealEntries(userId: userId)
        
        mindEaseStore = MindEaseDataStore(currentUserId: userId)
        mindEaseStore.parentStore = self
        
        seedSettings(userId: userId)
        
        //Save profile to Supabase
        // Only save if this is a real auth user (not guest)
        if authProvider != .guest, !email.isEmpty {
            Task {
                await BackendService.shared.saveProfile(
                    userId: userId,
                    name: name,
                    email: email
                )
            }
        }
    }
    
    
    func seedSubStoresAfterEngineRun(userId: UUID) {
        let np = userNutritionProfiles.first(where: { $0.userId == userId })
        dietMateStore.seedTodaysMealEntries(userId: userId, nutritionProfile: np)
        mindEaseStore.addAll(userId: userId, userPlans: userPlans)
    }
    
    
    // MARK: seedQuestions — REPLACE this entire function
    //       in AppDataStore.swift
    //
    //  7 assessment questions :
    //   Q1  Hair fall duration   — context only (.none)
    //   Q2  Sleep hours          — sleepScore    (PSQI + Trüeb 2015)
    //   Q3  Stress level         — stressScore   (PSS-4, Peters 2006)
    //   Q4  Diet quality         — dietScore     (Almohanna 2019, Rushton 2002)
    //   Q5  Water intake         — hydration     (EFSA 2010)
    //   Q6  Hair washing         — hairCareScore (Ranganathan 2010)
    //   Q7  Activity level       — TDEE only, no score
    //  Age / height / weight now read from UserProfile (set in ProfileSetupView)
    //
    //  3 fallback questions unchanged (orderIndex 8, 9, 10)
    
    private func seedQuestions() {
        
        // Q1 Sleep hours (SCORED)
        // Research: PSQI scale (Buysse 1989) + Trüeb 2015 cortisol-hair link
        //   <6 hrs  → PSQI severe → cortisol spike → telogen effluvium  → 1.5
        //   6–7 hrs → PSQI moderate impairment                           → 4.5
        //   7–8 hrs → WHO/NHS optimal range                              → 10.0
        //   >8 hrs  → elevated cortisol link (Motivala 2008)             → 6.5
        let q1 = Question(id: UUID(), questionType: .singleChoice,
                          questionText: "How many hours of sleep do you get each night?",
                          questionOrderIndex: 1, scoreDimension: .sleep)
        questions.append(q1)
        let q1opts: [(String, Float)] = [
            ("Less than 6 hours", 1.5),
            ("6 to 7 hours",         4.5),
            ("7 to 8 hours",         10.0),
            ("More than 8 hours", 6.5)
        ]
        q1opts.enumerated().forEach { i, pair in
            let opt = QuestionOption(id: UUID(), questionId: q1.id,
                                     optionOrderIndex: i+1, optionText: pair.0, imageURL: nil, optionType: .text)
            questionOptions.append(opt)
            questionScoreMaps.append(QuestionScoreMap(id: UUID(), questionId: q1.id,
                                                      optionId: opt.id, scoreDimension: .sleep, scoreValue: pair.1))
        }
        
        // Q2 Diet quality
        // Research: Almohanna et al. 2019 (Dermatol Ther) + Rushton 2002 (Clin Exp Dermatol)
        //   Very healthy  → all key nutrients likely met                  → 10.0
        //   Fairly balanced → partial zinc/iron gaps probable             → 6.5
        //   Often junk    → iron/zinc/biotin deficiency high probability  → 2.5
        //   Very poor     → severe multi-nutrient deficiency — TE trigger → 1.0
        let q2 = Question(id: UUID(), questionType: .singleChoice,
                          questionText: "How would you describe your typical daily diet?",
                          questionOrderIndex: 2, scoreDimension: .diet)
        questions.append(q2)
        let q2opts: [(String, Float)] = [
            ("Balanced meals", 10.0),
            ("Fairly balanced",               6.5),
            ("Often junk food",        2.5),
            ("Skipping meals",    1.0)
        ]
        q2opts.enumerated().forEach { i, pair in
            let opt = QuestionOption(id: UUID(), questionId: q2.id,
                                     optionOrderIndex: i+1, optionText: pair.0, imageURL: nil, optionType: .text)
            questionOptions.append(opt)
            questionScoreMaps.append(QuestionScoreMap(id: UUID(), questionId: q2.id,
                                                      optionId: opt.id, scoreDimension: .diet, scoreValue: pair.1))
        }
        
        // ── Q3 — Hair washing frequency (SCORED) ──
        // Research: Ranganathan & Mukhopadhyay 2010 (Indian J Dermatol)
        //           + Trüeb scalp hygiene guidelines
        //   Daily          → strips sebum, disrupts microbiome             → 3.5
        //   Every 2–3 days → optimal sebum balance — trichology consensus  → 10.0
        //   Every 4–5 days → suboptimal but acceptable                     → 6.5
        //   Once a week    → product buildup + follicle blockage risk       → 2.5
        let q3 = Question(id: UUID(), questionType: .singleChoice,
                          questionText: "How often do you wash your hair?",
                          questionOrderIndex: 3, scoreDimension: .hairCare)
        questions.append(q3)
        let q3opts: [(String, Float)] = [
            ("Daily",                 3.5),
            ("Every 2 to 3 days",       10.0),
            ("Every 4 to 5 days",        6.5),
            ("Once a week or less",   2.5)
        ]
        q3opts.enumerated().forEach { i, pair in
            let opt = QuestionOption(id: UUID(), questionId: q3.id,
                                     optionOrderIndex: i+1, optionText: pair.0, imageURL: nil, optionType: .text)
            questionOptions.append(opt)
            questionScoreMaps.append(QuestionScoreMap(id: UUID(), questionId: q3.id,
                                                      optionId: opt.id, scoreDimension: .hairCare, scoreValue: pair.1))
        }
        
        // Q4  Age (picker)
        questions.append(Question(id: UUID(), questionType: .picker,
                                  questionText: "What is your age?",
                                  questionOrderIndex: 4, scoreDimension: .none,
                                  pickerMin: 18, pickerMax: 40 , pickerStep: 1, pickerUnit: "yrs",
                                  keyboardType: .number))
        
        //  Q5  Height (picker)
        questions.append(Question(id: UUID(), questionType: .picker,
                                  questionText: "What is your height?",
                                  questionOrderIndex: 5, scoreDimension: .none,
                                  pickerMin: 140, pickerMax: 220, pickerStep: 1, pickerUnit: "cm",
                                  keyboardType: .number))
        
        // Q6 Weight (picker)
        questions.append(Question(id: UUID(), questionType: .picker,
                                  questionText: "What is your weight?",
                                  questionOrderIndex: 6, scoreDimension: .none,
                                  pickerMin: 40, pickerMax: 150, pickerStep: 0.5, pickerUnit: "kg",
                                  keyboardType: .decimal))
        
        // Q7 Activity level (TDEE only, not lifestyle-scored)
        let q7 = Question(id: UUID(), questionType: .singleChoice,
                           questionText: "How active are you on most days?",
                           questionOrderIndex: 7, scoreDimension: .none)
        questions.append(q7)
        ["Sedentary ",
         "Light ",
         "Moderate ",
         "Very active "].enumerated().forEach { i, text in
            questionOptions.append(QuestionOption(id: UUID(), questionId: q7.id,
                                                  optionOrderIndex: i+1, optionText: text, imageURL: nil, optionType: .text))
        }
        
        //  Q8  Fallback: self-select stage
        let q8 = Question(id: UUID(), questionType: .imageChoice,
                           questionText: "Select your current hair fall stage",
                           questionOrderIndex: 8, scoreDimension: .none)
        questions.append(q8)
        [("Stage 1 — Slight thinning, hairline normal", "stage1_illustration"),
         ("Stage 2 — Noticeable thinning on top",       "stage2_illustration"),
         ("Stage 3 — Clear bald patch forming",         "stage3_illustration"),
         ("Stage 4 — Large bald area",                  "stage4_illustration")
        ].enumerated().forEach { i, pair in
            questionOptions.append(QuestionOption(id: UUID(), questionId: q8.id,
                                                  optionOrderIndex: i+1, optionText: pair.0,
                                                  imageURL: pair.1, optionType: .image))
        }
        
        // Q9  Fallback: scalp condition
        let q9 = Question(id: UUID(), questionType: .singleChoice,
                           questionText: "How does your scalp feel most of the time?",
                           questionOrderIndex: 9, scoreDimension: .none)
        questions.append(q9)
        ["Dandruff",
         "Dry scalp",
         "Oily scalp",
         "Inflammation",
         "No issues"].enumerated().forEach { i, text in
            questionOptions.append(QuestionOption(id: UUID(), questionId: q9.id,
                                                  optionOrderIndex: i+1, optionText: text, imageURL: nil, optionType: .text))
        }
        
        //  Q10  Fallback: hair density
        let q10 = Question(id: UUID(), questionType: .singleChoice,
                           questionText: "How would you describe your hair thickness?",
                           questionOrderIndex: 10, scoreDimension: .none)
        questions.append(q10)
        ["Thick and full",
         "Medium ",
         "Thin ",
         "Very thin"].enumerated().forEach { i, text in
            questionOptions.append(QuestionOption(id: UUID(), questionId: q10.id,
                                                  optionOrderIndex: i+1, optionText: text, imageURL: nil, optionType: .text))
        }
    }
    
    // MARK: 3 — Engine Output
    //   (no longer pre-seeded — computed dynamically by
    //    RecommendationEngine.run() after assessment + hair analysis)
    
    
    
    // MARK: 9 — Settings
    
    
    private func seedSettings(userId: UUID) {
        // Derive initial goals from UserProfile using the same formulas as RecommendationEngine
        let profile  = userProfiles.first(where: { $0.userId == userId })
        let heightCm = profile?.heightCm ?? 0
        let weightKg = profile?.weightKg ?? 0
        let age      = profile.map {
            Calendar.current.dateComponents([.year], from: $0.dateOfBirth, to: Date()).year ?? 0
        } ?? 0
        
        // Mifflin–St Jeor (male): BMR = (10 × kg) + (6.25 × cm) − (5 × age) + 5
        // Default activity = sedentary (×1.2) — engine will recalculate with actual level later
        let bmr  = (10 * weightKg) + (6.25 * heightCm) - (5 * Float(age)) + 5
        let tdee = userNutritionProfiles.first(where: { $0.userId == userId })?.tdee
        ?? (bmr * 1.2).rounded()
        
        // Water: 35 mL × body weight (EFSA 2010)
        let waterGoal = userNutritionProfiles.first(where: { $0.userId == userId })?.waterTargetML
        ?? (weightKg * 35).rounded()
        
        // Mindful minutes: 0 until the engine assigns a plan with session schedule
        let mindfulGoal = userPlans.first(where: { $0.userId == userId }).map {
            $0.meditationMinutesPerDay + $0.yogaMinutesPerDay + $0.soundMinutesPerDay
        } ?? 0
        
        appPreferences.append(AppPreferences(id: UUID(), userId: userId,
                                             preferMetricUnits: true, vegFilterDefault: false,
                                             defaultMealType: .breakfast,
                                             dailyCalorieGoal: tdee,
                                             dailyMindfulMinutesGoal: mindfulGoal,
                                             dailyWaterGoalML: waterGoal))
        
        notificationSettings.append(NotificationSettings(id: UUID(), userId: userId,
                                                         pushEnabled: true,
                                                         mealReminderEnabled: true,
                                                         mealReminderTimes: ["08:00", "13:00", "20:00"],
                                                         mindfulReminderEnabled: true, mindfulReminderTime: "07:00",
                                                         waterReminderEnabled: true, waterReminderIntervalHours: 2,
                                                         bedtimeReminderEnabled: true, bedtimeReminderMinutesBefore: 30,
                                                         dailyTipEnabled: true, dailyTipTime: "09:00",
                                                         weeklyScanReminderEnabled: true,
                                                         weeklyScanReminderDay: "monday", weeklyScanReminderTime: "10:00"))
    }
    
    
    // MARK: - Convenience Helpers (used by Views)
    
    var currentUser: User? {
        users.first(where: { $0.id == currentUserId })
    }
    
    var currentProfile: UserProfile? {
        userProfiles.first(where: { $0.userId == currentUserId })
    }
    
    var activePlan: UserPlan? {
        userPlans.first(where: { $0.userId == currentUserId && $0.isActive })
    }
    
    var activeNutritionProfile: UserNutritionProfile? {
        userNutritionProfiles.first(where: { $0.userId == currentUserId })
    }
    
    var latestScanReport: ScanReport? {
        if let plan = activePlan,
           let linked = scanReports.first(where: { $0.id == plan.scanReportId }) {
            return linked
        }
        return scanReports
            .filter { r in scalpScans.contains(where: { $0.id == r.scalpScanId && $0.userId == currentUserId }) }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first
    }
    
    func options(for questionId: UUID) -> [QuestionOption] {
        questionOptions
            .filter { $0.questionId == questionId }
            .sorted(by: { $0.optionOrderIndex < $1.optionOrderIndex })
    }
    
    func scoreMap(for optionId: UUID) -> QuestionScoreMap? {
        questionScoreMaps.first(where: { $0.optionId == optionId })
    }
    
    func assessmentQuestions() -> [Question] {
        questions
            .filter { $0.questionOrderIndex <= 8 }
            .sorted(by: { $0.questionOrderIndex < $1.questionOrderIndex })
    }
    
    func fallbackQuestions() -> [Question] {
        questions
            .filter { $0.questionOrderIndex > 8 }
            .sorted(by: { $0.questionOrderIndex < $1.questionOrderIndex })
    }
    
    // MARK: - DietMate Convenience Helpers (forwarded from dietMateStore)
    
    func todaysTotalCalories() -> Float {
        dietMateStore.todaysTotalCalories()
    }
    
    func todaysMealEntries() -> [MealEntry] {
        dietMateStore.todaysMealEntries()
    }
    
    func todaysHairNutrientsCovered() -> [String] {
        dietMateStore.todaysHairNutrientsCovered()
    }
    
    func logWaterIntake(cupSize: String, amountML: Float) {
        let log = WaterIntakeLog(
            id: UUID(),
            userId: currentUserId,
            date: Calendar.current.startOfDay(for: Date()),
            cupSize: cupSize,
            cupSizeAmountInML: amountML,
            loggedAt: Date()
        )
        waterIntakeLogs.append(log)
    }
    
    
    var dailyMindfulTarget: Int {
        // Read from preferences (set by engine via applyToStore), fall back to active plan, then 0
        if let pref = appPreferences.first(where: { $0.userId == currentUserId }),
           pref.dailyMindfulMinutesGoal > 0 {
            return pref.dailyMindfulMinutesGoal
        }
        if let plan = activePlan {
            return plan.meditationMinutesPerDay + plan.yogaMinutesPerDay + plan.soundMinutesPerDay
        }
        return 0
    }
    
    func todaysMindfulMinutes() -> Int {
        mindEaseStore.todaysMindfulMinutes()
    }
    
    // MARK: - Water Intake Helpers
    
    func waterIntakeLogs(for date: Date) -> [WaterIntakeLog] {
        let dayStart = Calendar.current.startOfDay(for: date)
        return waterIntakeLogs
            .filter {
                $0.userId == currentUserId &&
                Calendar.current.startOfDay(for: $0.date) == dayStart
            }
            .sorted { $0.loggedAt < $1.loggedAt }
    }
    
    func totalWaterML(for date: Date) -> Float {
        waterIntakeLogs(for: date).reduce(0) { $0 + $1.cupSizeAmountInML }
    }
    
    var dailyWaterGoalML: Float {
        
        if let pref = appPreferences.first(where: { $0.userId == currentUserId }),
           pref.dailyWaterGoalML > 0 {
            return pref.dailyWaterGoalML
        }
        
        let weight = currentProfile?.weightKg ?? 0
        return (weight * 35).rounded()
    }
    
    // MARK: - Sleep Record Helpers
    
    func sleepRecord(for date: Date) -> SleepRecord? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return sleepRecords.first {
            $0.userId == currentUserId &&
            Calendar.current.startOfDay(for: $0.date) == dayStart
        }
    }
    
    var sleepHistoryDates: [Date] {
        let cal = Calendar.current
        let unique = Set(
            sleepRecords
                .filter { $0.userId == currentUserId }
                .map { cal.startOfDay(for: $0.date) }
        )
        return unique.sorted(by: >)
    }
    
    var waterHistoryDates: [Date] {
        let cal = Calendar.current
        let unique = Set(
            waterIntakeLogs
                .filter { $0.userId == currentUserId }
                .map { cal.startOfDay(for: $0.date) }
        )
        return unique.sorted(by: >)
    }
    
    func applyAIResult(
        densityPercent: Float,
        densityLevel: HairDensityLevel,
        hairFallStage: HairFallStage,
        scalpCondition: ScalpCondition,
        hairType: String? = nil
    ) {
        guard let scan = scalpScans.last(where: { $0.userId == currentUserId }),
              let assessment = assessments.last(where: { $0.userId == currentUserId }),
              let profile = currentProfile
        else { return }
        
        scanReports.removeAll(where: { $0.scalpScanId == scan.id })
        
        let result = runEngineAndApply(
            scanId: scan.id,
            stage: hairFallStage,
            scalp: scalpCondition,
            density: densityLevel,
            densityPercent: densityPercent,
            hairType: hairType,
            source: AnalysisSource.aiModel,
            profile: profile,
            assessment: assessment
        )
        
        print("AI result applied: \(result)")
    }
    
    
    // MARK: - Backend Sync
    
    
    
    func loadScanReports() async {
        guard currentUserId != UUID() else { return }
        let reports = await BackendService.shared.fetchScanReports(userId: currentUserId)
        await MainActor.run {
            // Merge: keep any locally-created reports not yet persisted, add remote ones
            let remoteIds = Set(reports.map { $0.id })
            let localOnly = self.scanReports.filter { !remoteIds.contains($0.id) }
            self.scanReports = (reports + localOnly)
                .sorted { $0.createdAt > $1.createdAt }
        }
        print("Loaded \(reports.count) scan reports from backend")
    }

    /// Fetches the current user's scalp scans from Supabase and merges them
    /// into the in-memory `scalpScans` array. Must be called after `loadScanReports()`
    /// on login so the userId filter in HairProgressView has data to work with.
    func loadScalpScans() async {
        guard currentUserId != UUID() else { return }
        let scans = await BackendService.shared.fetchScalpScans(userId: currentUserId)
        await MainActor.run {
            let remoteIds = Set(scans.map { $0.id })
            let localOnly = self.scalpScans.filter { !remoteIds.contains($0.id) }
            self.scalpScans = scans + localOnly
        }
        print("Loaded \(scans.count) scalp scans from backend")
    }

    /// Restores the user's physical profile (height, weight, DOB), nutrition profile
    /// (calorie & water goals), user plan (MindEase targets), and app preferences
    /// from Supabase after login.
    func loadUserData() async {
        guard currentUserId != UUID() else { return }
        let userId = currentUserId

        // Fetch profile, nutrition, and active plan in parallel
        async let profileTask   = BackendService.shared.fetchProfileData(userId: userId)
        async let nutritionTask = BackendService.shared.fetchNutritionProfile(userId: userId)
        async let planTask      = BackendService.shared.fetchUserPlan(userId: userId)
        let (profileData, nutrition, plan) = await (profileTask, nutritionTask, planTask)

        await MainActor.run {
            // ── Restore physical profile ──
            if let data = profileData,
               let idx = self.userProfiles.firstIndex(where: { $0.userId == userId }) {
                if data.heightCm > 0 { self.userProfiles[idx].heightCm = data.heightCm }
                if data.weightKg > 0 { self.userProfiles[idx].weightKg = data.weightKg }
                if let dob = data.dob { self.userProfiles[idx].dateOfBirth = dob }
            }

            // ── Restore nutrition profile (calorie goal + water target) ──
            if let nutrition = nutrition {
                self.userNutritionProfiles.removeAll(where: { $0.userId == userId })
                self.userNutritionProfiles.append(nutrition)

                // Sync into AppPreferences so HomeView goals are correct
                if let prefIdx = self.appPreferences.firstIndex(where: { $0.userId == userId }) {
                    if nutrition.tdee         > 0 { self.appPreferences[prefIdx].dailyCalorieGoal = nutrition.tdee }
                    if nutrition.waterTargetML > 0 { self.appPreferences[prefIdx].dailyWaterGoalML = nutrition.waterTargetML }
                }
            }

            // ── Restore active user plan + seed MindEase targets ──
            if let plan = plan {
                self.userPlans.removeAll(where: { $0.userId == userId })
                self.userPlans.append(plan)

                // Sync mindful minutes target into AppPreferences
                let mindfulMins = plan.meditationMinutesPerDay
                                + plan.yogaMinutesPerDay
                                + plan.soundMinutesPerDay
                if let prefIdx = self.appPreferences.firstIndex(where: { $0.userId == userId }),
                   mindfulMins > 0 {
                    self.appPreferences[prefIdx].dailyMindfulMinutesGoal = mindfulMins
                }

                // Tell MindEaseDataStore about the plan so today's sessions are seeded
                mindEaseStore.addAll(userId: userId, userPlans: self.userPlans)
            }
        }
        print("User data restored from backend")
    }

    
    
    func saveScanReportToBackend(_ report: ScanReport) {
        Task {
            await BackendService.shared.saveScanReport(report: report, userId: currentUserId)
        }
    }

    // MARK: - Reset on Logout
    /// Clears all user-specific in-memory data so a fresh login
    /// never sees stale data from a previous session.
    func resetForLogout() {
        currentUserId        = UUID()   // reset to a throwaway ID
        users                = []
        userProfiles         = []
        assessments          = []
        userAnswers          = []
        scalpScans           = []
        scanReports          = []
        userPlans            = []
        userNutritionProfiles = []
        sleepRecords         = []
        waterIntakeLogs      = []
        appPreferences       = []
        notificationSettings = []
        hairInsightsStore    = HairInsightsDataStore()
        dietMateStore        = DietmateDataStore(currentUserId: UUID())
        mindEaseStore        = MindEaseDataStore(currentUserId: UUID())
    }
}
