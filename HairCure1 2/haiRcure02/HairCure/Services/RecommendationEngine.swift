import Foundation
import HealthKit

struct EngineInput {
    let userId: UUID
    let assessmentId: UUID
    let answers: [UserAnswer]
    let hairFallStage: HairFallStage
    let scalpCondition: ScalpCondition
    let hairDensityLevel: HairDensityLevel
    let hairDensityPercent: Float
    let hairType: String?
    let analysisSource: AnalysisSource
    let scalpScanId: UUID
    let age: Int
    let heightCm: Float
    let weightKg: Float
    let activityLevel: ActivityLevel
}

struct EngineOutput {
    let scanReport: ScanReport
    let userPlan: UserPlan
    let nutritionProfile: UserNutritionProfile
    let planDescription: PlanDescription
}

struct PlanDescription {
    let planId: String
    let planTitle: String
    let planSummary: String
    let dietFocus: String
    let mindEaseFocus: String
    let hairCareFocus: String
    let insightsFocus: String
    let scalpModifierNote: String
    let isReferDoctor: Bool
    let doctorReferralMessage: String?
}

struct RecommendationEngine {
    
    // MARK: - Main Entry Point
    
    static func run(input: EngineInput, store: AppDataStore) -> EngineOutput {
        let scores      = calculateLifestyleScores(answers: input.answers, store: store)
        let profile     = LifestyleProfile.from(score: scores.composite)
        let planId      = resolvePlanId(stage: input.hairFallStage, profile: profile)
        let schedule    = resolveSessionSchedule(planId: planId)
        let nutrition   = calculateNutrition(userId: input.userId, age: input.age,
                                             heightCm: input.heightCm, weightKg: input.weightKg,
                                             activityLevel: input.activityLevel)
        let scanReport  = buildScanReport(input: input, scores: scores, planId: planId)
        let userPlan    = buildUserPlan(userId: input.userId, scanReportId: scanReport.id,
                                        planId: planId, stage: input.hairFallStage.intValue,
                                        profile: profile, scalpModifier: input.scalpCondition,
                                        schedule: schedule)
        let description = buildPlanDescription(planId: planId,
                                               scalpCondition: input.scalpCondition, scores: scores)
        
        return EngineOutput(scanReport: scanReport, userPlan: userPlan,
                            nutritionProfile: nutrition, planDescription: description)
    }
    
    // MARK: - Apply Output to Store
    
    static func applyToStore(_ output: EngineOutput, store: AppDataStore) {
        
        for idx in store.userPlans.indices where store.userPlans[idx].isActive {
            store.userPlans[idx].isActive = false
        }
        
        // Helps remove stale nutrition profile
        store.userNutritionProfiles.removeAll(where: {
            $0.userId == output.userPlan.userId
        })
        
        store.scanReports.append(output.scanReport)
        store.userPlans.append(output.userPlan)
        store.userNutritionProfiles.append(output.nutritionProfile)
        
        // Rebuild today's meal entries with new calorie budgets
        store.dietMateStore.mealEntries.removeAll(where: {
            $0.userId == output.userPlan.userId &&
            Calendar.current.isDateInToday($0.date)
        })
        createDailyMealEntries(userId: output.userPlan.userId,
                               nutrition: output.nutritionProfile, store: store)
        
        if let idx = store.appPreferences.firstIndex(where: {
            $0.userId == output.userPlan.userId
        }) {
            store.appPreferences[idx].dailyCalorieGoal = output.nutritionProfile.tdee
            store.appPreferences[idx].dailyMindfulMinutesGoal =
            output.userPlan.meditationMinutesPerDay +
            output.userPlan.yogaMinutesPerDay +
            output.userPlan.soundMinutesPerDay
            store.appPreferences[idx].dailyWaterGoalML = output.nutritionProfile.waterTargetML
        }
        
        createTodaysPlan(userId: output.userPlan.userId,
                         userPlan: output.userPlan, store: store)
    }
    
    struct LifestyleScores {
        let diet: Float
        let stress: Float
        let sleep: Float
        let hairCare: Float
        let hydration: Float
        let composite: Float
    }
    
    static func calculateLifestyleScores(
        answers: [UserAnswer],
        store: AppDataStore
    ) -> LifestyleScores {
        
        var dimensionValues: [ScoreDimension: [Float]] = [
            .diet: [], .stress: [], .sleep: [], .hairCare: [], .hydration: []
        ]
        
        for answer in answers {
            guard let optionId = answer.selectedOptionId else { continue }
            guard let map = store.scoreMap(for: optionId) else { continue }
            guard map.scoreDimension != .none else { continue }
            dimensionValues[map.scoreDimension, default: []].append(map.scoreValue)
        }
        
        func avg(_ key: ScoreDimension) -> Float {
            let vals = dimensionValues[key] ?? []
            return vals.isEmpty ? 5.0 : vals.reduce(0, +) / Float(vals.count)
        }
        
        let rawDiet      = avg(.diet)
        let rawHydration = avg(.hydration)
        let rawStress    = avg(.stress)
        let rawSleep     = avg(.sleep)
        let rawHairCare  = avg(.hairCare)
        
        // Blends hydration into diet (EFSA water research embedded in diet dimension)
        let adjustedDiet = ((rawDiet + rawHydration) / 2).clamped(to: 0...10)
        
        let composite = (
            (rawStress    * 0.30) +
            (adjustedDiet * 0.30) +
            (rawSleep     * 0.25) +
            (rawHairCare  * 0.15)
        ).rounded(toPlaces: 2)
        
        return LifestyleScores(
            diet:      adjustedDiet,
            stress:    rawStress,
            sleep:     rawSleep,
            hairCare:  rawHairCare,
            hydration: rawHydration,
            composite: composite
        )
    }
    
    // MARK: STEP 2+3 — Plan Matrix
    //
    //                 Poor (0–4.99)   Moderate (5–7.99)   Good (8–10)
    //  Stage 1    →     1A                 1B                 1C
    //  Stage 2    →     2A                 2B                 2C
    //  Stage 3    →     3A                 3B                 3C
    //  Stage 4+   →     refer_doctor   (all profiles)
    
    static func resolvePlanId(stage: HairFallStage, profile: LifestyleProfile) -> String {
        
        let stageNum: Int
        switch stage {
        case .stage1: stageNum = 1
        case .stage2: stageNum = 2
        case .stage3, .stage4: stageNum = 3
        default:      stageNum = 3
        }
        
        return "Stage \(stageNum)"
    }
    
    // MARK: STEP 4 — MindEase Session Schedule
    
    struct SessionSchedule {
        let meditationMinutes: Int
        let yogaMinutes: Int
        let soundMinutes: Int
        let frequencyPerWeek: Int
    }
    
    static func resolveSessionSchedule(planId: String) -> SessionSchedule {
        if planId == "refer_doctor" {
            return SessionSchedule(meditationMinutes: 0, yogaMinutes: 0, soundMinutes: 0, frequencyPerWeek: 0)
        }
        
        let stageNum: Int
        if planId.contains("1") {
            stageNum = 1
        } else if planId.contains("3") {
            stageNum = 3
        } else {
            stageNum = 2
        }
        
        let meditation = stageNum * 5 + 5
        let yoga = stageNum * 10 + 10
        let sound = 10
        let freq = 4
        
        return SessionSchedule(
            meditationMinutes: meditation,
            yogaMinutes: yoga,
            soundMinutes: sound,
            frequencyPerWeek: freq
        )
    }
    
    // MARK: STEP 5 — BMR / TDEE / Nutrition Pipeline
    //
    //  Mifflin–St Jeor (Male only — app is male-only):
    //  BMR = (10 × weight_kg) + (6.25 × height_cm) − (5 × age) + 5
    //
    //  TDEE = BMR × activity_multiplier
    //
    //  Macro targets (of TDEE):
    //    Protein   20% ÷ 4  (g)
    //    Carbs     50% ÷ 4  (g)
    //    Fat       30% ÷ 9  (g)
    //
    //  Meal slot budgets (of TDEE):
    //    Breakfast  25%
    //    Lunch      35%
    //    Snack      15%
    //    Dinner     25%
    //
    //  Water target = 35 ml × weight_kg
    
    static func calculateNutrition(
        userId: UUID,
        age: Int,
        heightCm: Float,
        weightKg: Float,
        activityLevel: ActivityLevel
    ) -> UserNutritionProfile {
        
        let bmr  = (10 * weightKg) + (6.25 * heightCm) - (5 * Float(age)) + 5
        let tdee = (bmr * Float(activityLevel.multiplier)).rounded()
        
        return UserNutritionProfile(
            id: UUID(), userId: userId,
            activityLevel: activityLevel,
            bmr: bmr.rounded(),
            tdee: tdee,
            breakfastCalTarget: (tdee * 0.25).rounded(),
            lunchCalTarget:     (tdee * 0.35).rounded(),
            snackCalTarget:     (tdee * 0.15).rounded(),
            dinnerCalTarget:    (tdee * 0.25).rounded(),
            proteinTargetGm:    ((tdee * 0.20) / 4).rounded(),
            carbTargetGm:       ((tdee * 0.50) / 4).rounded(),
            fatTargetGm:        ((tdee * 0.30) / 9).rounded(),
            waterTargetML:      (weightKg * 35).rounded(),
            createdAt: Date(), updatedAt: Date()
        )
    }
    
    private static func buildScanReport(
        input: EngineInput,
        scores: LifestyleScores,
        planId: String
    ) -> ScanReport {
        ScanReport(
            id: UUID(), createdAt: Date(),
            scalpScanId: input.scalpScanId,
            hairDensityPercent: input.hairDensityPercent,
            hairDensityLevel: input.hairDensityLevel,
            hairFallStage: input.hairFallStage,
            scalpCondition: input.scalpCondition,
            hairType: input.hairType,
            analysisSource: input.analysisSource,
            planId: planId,
            lifestyleScore: scores.composite,
            dietScore: scores.diet,
            stressScore: scores.stress,
            sleepScore: scores.sleep,
            hairCareScore: scores.hairCare,
            recommendedPlan: planSummaryText(for: planId)
        )
    }
    
    private static func buildUserPlan(
        userId: UUID, scanReportId: UUID,
        planId: String, stage: Int,
        profile: LifestyleProfile, scalpModifier: ScalpCondition,
        schedule: SessionSchedule
    ) -> UserPlan {
        UserPlan(
            id: UUID(), userId: userId, scanReportId: scanReportId,
            planId: planId, stage: stage,
            lifestyleProfile: profile, scalpModifier: scalpModifier,
            meditationMinutesPerDay: schedule.meditationMinutes,
            yogaMinutesPerDay: schedule.yogaMinutes,
            soundMinutesPerDay: schedule.soundMinutes,
            sessionFrequencyPerWeek: schedule.frequencyPerWeek,
            isActive: true,
            assignedAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        )
    }
    
    private static func createDailyMealEntries(
        userId: UUID,
        nutrition: UserNutritionProfile,
        store: AppDataStore
    ) {
        let slots: [(MealType, Float)] = [
            (.breakfast, nutrition.breakfastCalTarget),
            (.lunch,     nutrition.lunchCalTarget),
            (.snack,     nutrition.snackCalTarget),
            (.dinner,    nutrition.dinnerCalTarget)
        ]
        for (type, _) in slots {
            store.dietMateStore.mealEntries.append(MealEntry(
                id: UUID(), userId: userId, mealType: type,
                date: Date(), isLogged: false, loggedAt: nil,
                caloriesConsumed: 0,
                proteinConsumed: 0, carbsConsumed: 0, fatConsumed: 0
            ))
        }
    }
    
    // MARK: Today's MindEase Plan
    //
    //  Daily category rotation (by day of year):
    //    day % 3 == 0  →  Relaxing Sounds
    //    day % 3 == 1  →  Yoga
    //    day % 3 == 2  →  Meditation
    //
    //  Plan 1C (yoga = 0): rotates between Sounds and Meditation only.
    //  refer_doctor: no plan created.
    //
    //
    //  (dayOfYear % contents.count) so users on daily plans never see
    //  the same session two days in a row.
    
    private static func createTodaysPlan(
        userId: UUID,
        userPlan: UserPlan,
        store: AppDataStore
    ) {
        store.mindEaseStore.todaysPlans.removeAll(where: {
            $0.userId == userId && Calendar.current.isDateInToday($0.planDate)
        })
        guard userPlan.planId != "refer_doctor" else { return }
        
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let categoryTitle = resolveRotationCategory(dayOfYear: dayOfYear, plan: userPlan)
        
        guard let category = store.mindEaseStore.mindEaseCategories.first(where: { $0.title == categoryTitle }) else { return }
        
        // FIX: Rotate through all available content items by day of year
        // instead of always picking the first item. This ensures users on
        // daily plans (1A, 2A, 3A, 3B) see variety across sessions.
        let contents = store.mindEaseStore.mindEaseCategoryContents
            .filter { $0.categoryId == category.id }
        
        guard !contents.isEmpty else { return }
        let content = contents[dayOfYear % contents.count]
        
        let target: Int
        switch categoryTitle {
        case "Meditation":      target = userPlan.meditationMinutesPerDay
        case "Yoga":            target = userPlan.yogaMinutesPerDay
        case "Relaxing Sounds": target = userPlan.soundMinutesPerDay
        default:                target = 10
        }
        
        store.mindEaseStore.todaysPlans.append(TodaysPlan(
            id: UUID(), userId: userId, planDate: Date(),
            contentId: content.id, categoryId: category.id,
            planId: userPlan.planId,
            minutesTarget: target,
            minutesCompleted: 0, isCompleted: false
        ))
    }
    
    private static func resolveRotationCategory(dayOfYear: Int, plan: UserPlan) -> String {
        if plan.yogaMinutesPerDay == 0 {
            return dayOfYear % 2 == 0 ? "Relaxing Sounds" : "Meditation"
        }
        switch dayOfYear % 3 {
        case 0:  return "Relaxing Sounds"
        case 1:  return "Yoga"
        default: return "Meditation"
        }
    }
    
    // MARK: Food Ranking
    //
    //  Foods are ranked by hair-nutrient priority for each plan.
    //  Scalp modifier boosts specific nutrients:
    //    Dry scalp      → Vitamin A + Omega-3 ranked higher
    //    Dandruff       → Zinc ranked highest (anti-fungal)
    //    Inflamed       → Omega-3 ranked highest (anti-inflammatory)
    //    Oily scalp     → Zinc ranked higher (sebum regulation)
    //    Poor lifestyle → All hair-nutrient foods ranked higher (plan "A")
    
    static func rankedFoods(
        from foods: [Food],
        for mealType: MealType,
        plan: UserPlan,
        vegetarianOnly: Bool = false
    ) -> [Food] {
        foods
            .filter { $0.suitableMealTypes.contains(mealType) && (!vegetarianOnly || $0.isVegetarian) }
            .sorted { priorityScore(food: $0, plan: plan) > priorityScore(food: $1, plan: plan) }
    }
    
    private static func priorityScore(food: Food, plan: UserPlan) -> Int {
        var score = 0
        
        // Base hair-nutrient scores (all plans)
        if food.isBiotinRich { score += 3 }
        if food.isZincRich   { score += 3 }
        if food.isIronRich   { score += 2 }
        if food.isOmega3Rich { score += 2 }
        
        // Poor lifestyle (Plan A) — boost all hair nutrients
        if plan.lifestyleProfile == .poor {
            score += food.isBiotinRich || food.isZincRich || food.isIronRich ? 2 : 0
        }
        
        switch plan.scalpModifier {
        case .dry:       score += food.isVitaminARich ? 3 : 0
            score += food.isOmega3Rich   ? 2 : 0
        case .dandruff:  score += food.isZincRich     ? 4 : 0
            score += food.isVitaminARich ? 2 : 0
        case .inflamed:  score += food.isOmega3Rich   ? 4 : 0
            score += food.isVitaminARich ? 1 : 0
        case .oily:      score += food.isZincRich     ? 3 : 0
        case .normal, .notAssessed:    break
        }
        
        return score
    }
    
    // MARK: Weekly Plan Re-evaluation
    //
    //  Called when a weekly re-scan is submitted.
    //  If planId changes → apply the new plan.
    //  Scores that improve → plan shifts toward "C" (less intensive).
    //  Stage that worsens → plan shifts toward "A" (more intensive).
    
    struct PlanUpdateResult {
        let shouldUpdate: Bool
        let newPlanId: String
        let reason: String
        let highlights: [String]    // bullet points shown to user on results screen
    }
    
    static func evaluatePlanUpdate(
        currentPlan: UserPlan,
        newStage: HairFallStage,
        newScores: LifestyleScores
    ) -> PlanUpdateResult {
        
        let newProfile = LifestyleProfile.from(score: newScores.composite)
        let newPlanId  = resolvePlanId(stage: newStage, profile: newProfile)
        
        guard newPlanId != currentPlan.planId else {
            return PlanUpdateResult(
                shouldUpdate: false, newPlanId: newPlanId,
                reason: "No change — keep current plan.",
                highlights: ["Keep up your current routine — it's working!"]
            )
        }
        
        var highlights: [String] = []
        
        if newScores.sleep > 6  { highlights.append("Sleep improved") }
        if newScores.diet  > 6  { highlights.append("Diet quality is now stronger") }
        if newScores.stress > 6 { highlights.append("Stress is well managed ") }
        
        // which caused moderate users to never see the improvement highlight
        // (their threshold was 8, but the Good band only starts at 8.0).
        let significantImprovementThreshold: Float
        switch currentPlan.lifestyleProfile {
        case .poor:     significantImprovementThreshold = 5.0   // poor → any meaningful gain
        case .moderate: significantImprovementThreshold = 7.0   // moderate → approaching good
        case .good:     significantImprovementThreshold = 9.0   // good → exceptional
        }
        if newScores.composite > significantImprovementThreshold {
            highlights.append("Lifestyle score improved significantly")
        }
        
        let oldStage = currentPlan.stage
        if newStage.intValue < oldStage {
            highlights.append("Hair density scan shows recovery progress ")
        } else if newStage.intValue > oldStage {
            highlights.append("Hair loss stage progressed — plan intensity increased.")
        }
        
        let reason: String
        switch (newProfile, currentPlan.lifestyleProfile) {
        case (.good, _):
            reason = "Excellent progress! Moving to a maintenance plan."
        case (.moderate, .poor):
            reason = "Lifestyle improved to Moderate — plan intensity reduced."
        case (.poor, .moderate), (.poor, .good):
            reason = "Lifestyle score dropped — plan adjusted to support recovery."
        default:
            reason = newStage.intValue > oldStage
            ? "Hair loss stage progressed — switching to a more intensive plan."
            : "Plan updated based on your latest scan results."
        }
        
        return PlanUpdateResult(
            shouldUpdate: true, newPlanId: newPlanId,
            reason: reason, highlights: highlights
        )
    }
    
    // MARK: Home Screen Progress Summary
    
    struct DailyProgressSummary {
        let caloriesToday: Float
        let calorieTarget: Float
        let caloriePercent: Float       // 0.0 – 1.0 clamped
        let mindfulMinutesToday: Int
        let mindfulMinutesTarget: Int
        let mindfulPercent: Float
        let waterTodayML: Float
        let waterTargetML: Float
        let waterPercent: Float
        let sleepLastNight: Float
        let sleepTarget: Float
        let planId: String
        let daysOnPlan: Int
    }
    
    @MainActor static func buildDailyProgressSummary(store: AppDataStore) -> DailyProgressSummary {
        let cal        = store.todaysTotalCalories()
        let calTarget  = store.activeNutritionProfile?.tdee ?? 2000
        let mindful    = Float(store.todaysMindfulMinutes())
        let mindTarget = Float(store.dailyMindfulTarget)
        let water      = Float(HealthKitManager.shared.todaysWaterML)
        let wTarget    = store.activeNutritionProfile?.waterTargetML ?? 2500
        let sleep      = Float(HealthKitManager.shared.lastNightSleepHours)
        let plan       = store.activePlan
        let days       = plan.map {
            Calendar.current.dateComponents([.day], from: $0.assignedAt, to: Date()).day ?? 0
        } ?? 0
        
        return DailyProgressSummary(
            caloriesToday: cal,       calorieTarget: calTarget,
            caloriePercent: (cal / calTarget).clamped(to: 0...1),
            mindfulMinutesToday: Int(mindful), mindfulMinutesTarget: Int(mindTarget),
            mindfulPercent: (mindful / max(mindTarget, 1)).clamped(to: 0...1),
            waterTodayML: water,      waterTargetML: wTarget,
            waterPercent: (water / wTarget).clamped(to: 0...1),
            sleepLastNight: sleep,    sleepTarget: 7.5,
            planId: plan?.planId.planDisplayName ?? "–", daysOnPlan: days
        )
    }
    
    // MARK: Hair Care Routine Builder
    
    struct HairCareRoutine {
        let iconName: String
        let cardHeading: String
        let applyingFrequency: String
        let summary: String
    }
    
    static func buildHairCareRoutine(for plan: UserPlan) -> [HairCareRoutine] {
        var routines: [HairCareRoutine] = []
        let condition = plan.scalpModifier
        
        let washFreq: String
        let washDetails: String
        let careFreq: String
        let careDetails: String
        let washIcon: String = "shower"
        let careIcon: String = "drop.fill"
        
        switch condition {
        case .dry:
            washFreq = "Every 3 days"
            washDetails = "Use a sulfate-free shampoo to gently cleanse without stripping the little natural oil your dry scalp produces."
            careFreq = "2× per week"
            careDetails = "Warm coconut or almond oil pre-wash to replenish scalp moisture and strengthen hair follicles starved by low sebum production."
        case .dandruff:
            washFreq = "Every 2 days"
            washDetails = "Use a zinc pyrithione or ketoconazole shampoo to target Malassezia fungus, the primary cause of dandruff in men."
            careFreq = "1× per week"
            careDetails = "Apply warm neem or tea tree oil to the scalp before wash day to soothe irritation and reduce flaking between washes."
        case .oily:
            washFreq = "Every 2 days"
            washDetails = "Use a clarifying shampoo to remove excess sebum driven by androgens, which cause faster oil buildup in men."
            careFreq = "Skip heavy oiling"
            careDetails = "Avoid heavy scalp oils. Use a light leave-in serum with salicylic acid on wash days to regulate sebum without clogging follicles."
        case .inflamed:
            washFreq = "Every 3–4 days"
            washDetails = "Use fragrance-free, sulphate-free shampoo to avoid aggravating scalp inflammation linked to stress and DHT sensitivity."
            careFreq = "2× per week"
            careDetails = "Apply diluted lavender or chamomile oil to reduce redness and calm irritated follicles before wash day."
        default:
            washFreq = "Every 2–3 days"
            washDetails = "Use a mild, pH-balanced shampoo to maintain your scalp's healthy oil levels and keep follicles clean."
            careFreq = "1–2× per week"
            careDetails = "Coconut or bhringraj oil pre-wash to maintain follicle strength and support healthy hair growth cycles."
        }
        
        routines.append(HairCareRoutine(iconName: washIcon, cardHeading: "Scalp Wash Routine", applyingFrequency: washFreq, summary: washDetails))
        routines.append(HairCareRoutine(iconName: careIcon, cardHeading: "Follicle Care Treatment", applyingFrequency: careFreq, summary: careDetails))
        
        return routines
    }
    
    static func planSummaryText(for planId: String) -> String {
        guard planId != "refer_doctor" else {
            return "Please consult a dermatologist for professional medical assessment."
        }
        
        let stageNum: String
        if planId.contains("1") { stageNum = "1" }
        else if planId.contains("3") { stageNum = "3" }
        else { stageNum = "2" }
        
        return "Stage \(stageNum) hair thinning support with targeted lifestyle corrections, regular mindfulness, and scalp care."
    }
    
    static func buildPlanDescription(
        planId: String,
        scalpCondition: ScalpCondition,
        scores: LifestyleScores
    ) -> PlanDescription {
        
        if planId == "refer_doctor" {
            return PlanDescription(
                planId: "refer_doctor",
                planTitle: "Doctor Consultation Recommended",
                planSummary: "Your hair loss is at an advanced stage that needs professional evaluation.",
                dietFocus: "", mindEaseFocus: "",
                hairCareFocus: "", insightsFocus: "",
                scalpModifierNote: "",
                isReferDoctor: true,
                doctorReferralMessage: buildDoctorReferralMessage()
            )
        }
        
        let weakest  = identifyWeakestDimension(scores: scores)
        let base     = planContentMap(planId: planId, weakest: weakest, scores: scores)
        let modifier = scalpModifierNote(for: scalpCondition)
        
        return PlanDescription(
            planId: planId,
            planTitle: base.title,
            planSummary: base.summary,
            dietFocus: base.dietFocus,
            mindEaseFocus: base.mindEaseFocus,
            hairCareFocus: base.hairCareFocus,
            insightsFocus: base.insightsFocus,
            scalpModifierNote: modifier,
            isReferDoctor: false,
            doctorReferralMessage: nil
        )
    }
    
    private struct PlanContent {
        let title: String
        let summary: String
        let dietFocus: String
        let mindEaseFocus: String
        let hairCareFocus: String
        let insightsFocus: String
    }
    
    private static func planContentMap(
        planId: String,
        weakest: ScoreDimension,
        scores: LifestyleScores
    ) -> PlanContent {
        
        let stageNum: String
        if planId.contains("1") { stageNum = "1" }
        else if planId.contains("3") { stageNum = "3" }
        else { stageNum = "2" }
        
        let title = "Stage \(stageNum) Recovery Plan"
        let summary = "This plan targets Stage \(stageNum) hair loss. Guided daily targets will help you rebuild follicle resilience."
        
        let stressNote = weakest == .stress
        ? " Stress is your biggest driver — Bhramari pranayama is your priority session."
        : " Consistency in daily sessions reduces the cortisol driving your hair fall."
        let sleepNote  = weakest == .sleep
        ? " Poor sleep is your biggest risk — use relaxation sounds before bedtime."
        : ""
        let dietNote   = weakest == .diet
        ? " Diet is your most critical gap — even one nutrient-rich meal makes a difference today."
        : ""
        
        let dietFocus = "Focus on biotin (eggs, almonds) and zinc-rich foods (pumpkin seeds, lentils) at every meal.\(dietNote)"
        let mindEaseFocus = "Daily sessions tailored to your schedule. Cortisol reduction is key.\(sleepNote)\(stressNote)"
        let hairCareFocus = "Wash and oil according to your scalp condition. Avoid harsh chemicals."
        let insightsFocus = "Check Hair Insights for details on follicle recovery and monthly progress tracking."
        
        return PlanContent(
            title: title,
            summary: summary,
            dietFocus: dietFocus,
            mindEaseFocus: mindEaseFocus,
            hairCareFocus: hairCareFocus,
            insightsFocus: insightsFocus
        )
    }
    
    private static func identifyWeakestDimension(scores: LifestyleScores) -> ScoreDimension {
        let dims: [(ScoreDimension, Float)] = [
            (.diet, scores.diet), (.stress, scores.stress),
            (.sleep, scores.sleep), (.hairCare, scores.hairCare)
        ]
        return dims.min(by: { $0.1 < $1.1 })?.0 ?? .diet
    }
    
    private static func scalpModifierNote(for condition: ScalpCondition) -> String {
        switch condition {
        case .dry:      return "Dry scalp detected — oiling schedule and Vitamin A foods added to your plan."
        case .dandruff: return "Dandruff detected — zinc-rich foods and anti-fungal wash routine added."
        case .oily:     return "Oily scalp detected — sebum-balancing tips and adjusted wash frequency added."
        case .inflamed: return "Scalp inflammation detected — Omega-3 foods and cooling oil routine prioritised."
        case .normal:   return "Scalp condition is normal — standard plan applied."
        case .notAssessed: return "General scalp health tips applied."
        }
    }
    
    private static func buildDoctorReferralMessage() -> String {
        """
        Your hair loss is at Stage 4 — beyond the lifestyle-correction range of this app.
        
        What to do next:
        • Book an appointment with a dermatologist or trichologist.
        • Request blood tests for: Iron (ferritin), Zinc, Vitamin D, Thyroid (TSH), and DHT levels.
        • Mention how long you have been experiencing hair loss and any family history.
        
        You can continue using this app for wellness, diet, and stress management — \
        these remain important while you receive professional treatment.
        """
    }

    // MARK: - Clean Shelf Ingredient Evaluator

    static func evaluateProduct(
        ingredients: [String],
        analyzedIngredients: [FlaggedIngredient],
        against scalp: ScalpCondition
    ) -> (rating: CompatibilityRating, flaggedIngredients: [FlaggedIngredient]) {
        let flagged = analyzedIngredients.filter { $0.rating != .safe }

        var finalRating = CompatibilityRating.safe
        if flagged.contains(where: { $0.rating == .hazard }) {
            finalRating = .hazard
        } else if flagged.contains(where: { $0.rating == .caution }) {
            finalRating = .caution
        }

        return (finalRating, flagged)
    }
}

// MARK: - Comparable Float Extension

private extension Float {
    func rounded(toPlaces places: Int) -> Float {
        let m = pow(10, Float(places))
        return (self * m).rounded() / m
    }
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

// MARK: - Plan Display Name Extension

extension String {
    /// Converts an internal plan code into a user-friendly display name.
    var planDisplayName: String {
        if self == "refer_doctor" { return "Specialist Care" }
        return self
    }
}
