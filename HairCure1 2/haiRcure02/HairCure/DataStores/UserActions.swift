
import Foundation
import Observation

// MARK: - Action Result

enum ActionResult {
    case success(message: String)
    case blocked(reason: String)
    case warning(message: String)
    case planUpdated(newPlanId: String, reason: String, highlights: [String])
    case referDoctor(message: String)
    case noChange
}

// MARK: - AppDataStore User Actions Extension

extension AppDataStore {
    
    
    @discardableResult
    func saveAnswer(questionId: UUID, selectedOptionId: UUID) -> ActionResult {
        
        let currentAssessmentId = assessments.last(where: { $0.userId == currentUserId })?.id
        userAnswers.removeAll(where: {
            $0.questionId == questionId &&
            $0.assessmentId == (currentAssessmentId ?? UUID())
        })
        
        guard let assessment = assessments.last(where: { $0.userId == currentUserId }) else {
            return .blocked(reason: "No active assessment found.")
        }
        
        let scoreMap   = questionScoreMaps.first(where: { $0.optionId == selectedOptionId })
        let scoreValue = scoreMap?.scoreValue
        let scoreDim   = scoreMap?.scoreDimension
        
        let answer = UserAnswer(
            id: UUID(),
            answeredAt: Date(),
            questionId: questionId,
            assessmentId: assessment.id,
            selectedOptionId: selectedOptionId,
            selectedOptionIds: [],
            answerText: nil,
            pickerValue: nil,
            scoreValue: scoreValue,
            scoreDimension: scoreDim
        )
        userAnswers.append(answer)
        updateAssessmentProgress()
        return .success(message: "Answer saved.")
    }
    
    @discardableResult
    func saveMultiAnswer(questionId: UUID, selectedOptionIds: [UUID]) -> ActionResult {
        
        guard let assessment = assessments.last(where: { $0.userId == currentUserId }) else {
            return .blocked(reason: "No active assessment found.")
        }
        
        userAnswers.removeAll(where: {
            $0.questionId == questionId && $0.assessmentId == assessment.id
        })
        
        let answer = UserAnswer(
            id: UUID(),
            answeredAt: Date(),
            questionId: questionId,
            assessmentId: assessment.id,
            selectedOptionId: nil,
            selectedOptionIds: selectedOptionIds,
            answerText: nil,
            pickerValue: nil,
            scoreValue: nil,
            scoreDimension: Optional.none
        )
        userAnswers.append(answer)
        updateAssessmentProgress()
        return .success(message: "Answer saved.")
    }
    
    @discardableResult
    func savePickerAnswer(questionId: UUID, pickerValue: Float) -> ActionResult {
        
        guard let assessment = assessments.last(where: { $0.userId == currentUserId }) else {
            return .blocked(reason: "No active assessment found.")
        }
        
        userAnswers.removeAll(where: {
            $0.questionId == questionId && $0.assessmentId == assessment.id
        })
        
        let answer = UserAnswer(
            id: UUID(),
            answeredAt: Date(),
            questionId: questionId,
            assessmentId: assessment.id,
            selectedOptionId: nil,
            selectedOptionIds: [],
            answerText: nil,
            pickerValue: pickerValue,
            scoreValue: nil,
            scoreDimension: Optional.none
        )
        userAnswers.append(answer)
        updateAssessmentProgress()
        return .success(message: "Value saved.")
    }
    
    
    
    @discardableResult
    func completeAssessment() -> ActionResult {
        guard let idx = assessments.lastIndex(where: { $0.userId == currentUserId }) else {
            return .blocked(reason: "No active assessment found.")
        }
        assessments[idx].completionPercent = 100
        assessments[idx].completedAt = Date()
        
        // Sync age / height / weight from picker answers → UserProfile
        let assessment = assessments[idx]
        if let profileIdx = userProfiles.firstIndex(where: { $0.userId == currentUserId }) {
            let age    = pickerValue(for: "age",    assessment: assessment, default: 0)
            let height = pickerValue(for: "height", assessment: assessment, default: 0)
            let weight = pickerValue(for: "weight", assessment: assessment, default: 0)
            
            if age > 0 {
                let dob = Calendar.current.date(byAdding: .year, value: -Int(age), to: Date()) ?? Date()
                userProfiles[profileIdx].dateOfBirth = dob
            }
            if height > 0 { userProfiles[profileIdx].heightCm = height }
            if weight > 0 { userProfiles[profileIdx].weightKg = weight }
        }
        
        // ── Save to Supabase ──
        let answersToSave = userAnswers.filter { $0.assessmentId == assessment.id }
        let age    = Int(pickerValue(for: "age",    assessment: assessment, default: 22))
        let height = pickerValue(for: "height", assessment: assessment, default: 170)
        let weight = pickerValue(for: "weight", assessment: assessment, default: 70)
        
        Task {
            await BackendService.shared.saveAssessment(
                assessmentId: assessment.id,
                userId: currentUserId,
                completionPercent: 100,
                completedAt: Date()
            )
            await BackendService.shared.saveUserAnswers(
                answers: answersToSave,
                userId: currentUserId
            )
            await BackendService.shared.updateProfilePhysical(
                userId: currentUserId,
                heightCm: height,
                weightKg: weight,
                age: age
            )
        }
        
        return .success(message: "Assessment complete.")
    }
    
    func startAssessment() {
        assessments.removeAll(where: { $0.userId == currentUserId && $0.completedAt == nil })
        
        let assessment = Assessment(
            id: UUID(),
            userId: currentUserId,
            completionPercent: 0,
            completedAt: nil
        )
        assessments.append(assessment)
        
        userAnswers.removeAll(where: { answer in
            assessments.contains(where: { $0.id == answer.assessmentId && $0.userId == currentUserId })
        })
    }
    
    private func updateAssessmentProgress() {
        guard let idx = assessments.lastIndex(where: { $0.userId == currentUserId }) else { return }
        let assessmentId = assessments[idx].id
        let answered = userAnswers.filter { $0.assessmentId == assessmentId }.count
        let total    = questions.filter { $0.questionOrderIndex <= 8 }.count
        let percent  = total > 0 ? Float(answered) / Float(total) * 100 : 0
        assessments[idx].completionPercent = min(percent, 99)
    }
    
    @discardableResult
    func submitScanImages(
        frontURL: String, leftURL: String,
        rightURL: String, backURL: String, topURL: String,
        scanType: ScanType = .initial
    ) -> ActionResult {
        
        guard assessments.last(where: { $0.userId == currentUserId })?.completedAt != nil
        else {
            return .blocked(reason: "Please complete the assessment before scanning.")
        }
        
        let scanId = UUID()
        let scan = ScalpScan(
            id: scanId, userId: currentUserId, scanDate: Date(),
            frontImageURL: frontURL, leftImageURL: leftURL,
            rightImageURL: rightURL, backImageURL: backURL,
            topImageURL: topURL, scanType: scanType
        )
        scalpScans.append(scan)
        // Save scan to Supabase immediately
        let userId = currentUserId
        Task {
            await BackendService.shared.saveScalpScan(
                scan: scan,
                userId: userId
            )
        }
        return .success(message: "Scan created.")
    }
    
    @discardableResult
    func submitSelfAssessedStage(
        stage: HairFallStage,
        scalp: ScalpCondition,
        density: HairDensityLevel,
        scanType: ScanType = .initial
    ) -> ActionResult {
        
        guard let profile    = currentProfile,
              let assessment = assessments.last(where: { $0.userId == currentUserId }),
              assessment.completedAt != nil
        else {
            return .blocked(reason: "Please complete the assessment first.")
        }
        
        if stage == .stage4 {
            return .referDoctor(message: RecommendationEngine.buildPlanDescription(
                planId: "refer_doctor",
                scalpCondition: scalp,
                scores: RecommendationEngine.LifestyleScores(
                    diet: 5, stress: 5, sleep: 5, hairCare: 5, hydration: 5, composite: 5)
            ).doctorReferralMessage ?? "")
        }
        
        let scanId = UUID()
        scalpScans.append(ScalpScan(
            id: scanId, userId: currentUserId, scanDate: Date(),
            frontImageURL: "self_assessed_front", leftImageURL: "self_assessed_left",
            rightImageURL: "self_assessed_right", backImageURL: "self_assessed_back",
            topImageURL: "self_assessed_top", scanType: scanType
        ))
        
        
        let densityPercent: Float
        switch density {
        case .high:    densityPercent = 85
        case .medium:  densityPercent = 65
        case .low:     densityPercent = 45
        case .veryLow: densityPercent = 25
        case .notAssessed: densityPercent = -1
        }
        
        return runEngineAndApply(
            scanId: scanId,
            stage: stage, scalp: scalp,
            density: density, densityPercent: densityPercent,
            source: .selfAssessed,
            profile: profile, assessment: assessment
        )
    }
    
    // MARK: 5 — Water Intake
    
    @discardableResult
    func logWaterIntake(cupSize: String, amountML: Float) -> ActionResult {
        
        guard amountML > 0 else {
            return .blocked(reason: "Invalid water amount.")
        }
        
        waterIntakeLogs.append(WaterIntakeLog(
            id: UUID(), userId: currentUserId,
            date: Date(), cupSize: cupSize,
            cupSizeAmountInML: amountML, loggedAt: Date()
        ))
        
        let totalToday = todaysTotalWaterML()
        let target     = activeNutritionProfile?.waterTargetML ?? 2500
        let remaining  = max(0, target - totalToday)
        
        if totalToday >= target {
            return .success(message: "Daily water goal reached! Great job.")
        }
        return .success(message: "+\(Int(amountML)) ml logged. \(Int(remaining)) ml remaining today.")
    }
    
    @discardableResult
    func removeWaterEntry(id: UUID) -> ActionResult {
        guard waterIntakeLogs.contains(where: { $0.id == id && $0.userId == currentUserId }) else {
            return .blocked(reason: "Water entry not found.")
        }
        waterIntakeLogs.removeAll(where: { $0.id == id })
        return .success(message: "Water entry removed.")
    }
    
    func todaysTotalWaterML() -> Float {
        let today = Calendar.current.startOfDay(for: Date())
        return waterIntakeLogs
            .filter {
                $0.userId == currentUserId &&
                Calendar.current.startOfDay(for: $0.loggedAt) == today
            }
            .reduce(0) { $0 + $1.cupSizeAmountInML }
    }
    
    func todaysWaterLogs() -> [WaterIntakeLog] {
        let today = Calendar.current.startOfDay(for: Date())
        return waterIntakeLogs
            .filter {
                $0.userId == currentUserId &&
                Calendar.current.startOfDay(for: $0.loggedAt) == today
            }
            .sorted(by: { $0.loggedAt > $1.loggedAt })
    }
    
    func weeklyWaterTotals() -> [(day: String, totalML: Float)] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return (0..<7).map { daysAgo in
            let date  = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
            let start = cal.startOfDay(for: date)
            let total = waterIntakeLogs
                .filter { $0.userId == currentUserId && cal.startOfDay(for: $0.loggedAt) == start }
                .reduce(0) { $0 + $1.cupSizeAmountInML }
            return (day: fmt.string(from: date), totalML: total)
        }.reversed()
    }
    
    // ─────────────────────────────────────────────
    // MARK: 6 — Sleep Tracking
    // ─────────────────────────────────────────────
    
    @discardableResult
    func saveSleepRecord(
        bedTime: Date,
        wakeTime: Date,
        alarmEnabled: Bool,
        alarmTime: Date? = nil
    ) -> ActionResult {
        
        var diff = wakeTime.timeIntervalSince(bedTime)
        if diff < 0 { diff += 86400 }
        let hours = Float(diff / 3600)
        
        let record = SleepRecord(
            id: UUID(), userId: currentUserId, date: Date(),
            bedTime: bedTime, wakeTime: wakeTime,
            alarmEnabled: alarmEnabled,
            alarmTime: alarmEnabled ? (alarmTime ?? wakeTime) : nil,
            hoursSlept: (hours * 10).rounded() / 10
        )
        
        let today = Calendar.current.startOfDay(for: Date())
        sleepRecords.removeAll(where: {
            $0.userId == currentUserId &&
            Calendar.current.startOfDay(for: $0.date) == today
        })
        sleepRecords.append(record)
        
        let quality: String
        switch hours {
        case 7...: quality = "Great sleep target!"
        case 6..<7: quality = "Slightly under target — aim for 7+ hours."
        default:    quality = "Poor sleep detected — this affects hair health."
        }
        
        return .success(message: "\(String(format: "%.1f", hours)) hours logged. \(quality)")
    }
    
    @discardableResult
    func toggleAlarm(enabled: Bool, alarmTime: Date? = nil) -> ActionResult {
        let today = Calendar.current.startOfDay(for: Date())
        
        guard let idx = sleepRecords.lastIndex(where: {
            $0.userId == currentUserId &&
            Calendar.current.startOfDay(for: $0.date) == today
        }) else {
            return .blocked(reason: "Set your sleep schedule first.")
        }
        
        sleepRecords[idx].alarmEnabled = enabled
        if let time = alarmTime {
            sleepRecords[idx].alarmTime = time
        }
        
        return .success(message: enabled ? "Alarm set." : "Alarm turned off.")
    }
    
    var lastNightSleep: SleepRecord? {
        sleepRecords
            .filter { $0.userId == currentUserId }
            .sorted(by: { $0.date > $1.date })
            .first
    }
    
    func weeklySleepData() -> [(day: String, hours: Float)] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return (0..<7).map { daysAgo in
            let date  = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
            let start = cal.startOfDay(for: date)
            let hrs   = sleepRecords.first(where: {
                $0.userId == currentUserId &&
                cal.startOfDay(for: $0.date) == start
            })?.hoursSlept ?? 0
            return (day: fmt.string(from: date), hours: hrs)
        }.reversed()
    }
    
    // ─────────────────────────────────────────────
    // MARK: 7 — Monthly Re-scan
    // ─────────────────────────────────────────────
    
    @discardableResult
    func submitWeeklyScan(
        stage: HairFallStage,
        scalp: ScalpCondition,
        density: HairDensityLevel,
        isAIModel: Bool = false
    ) -> ActionResult {
        
        guard let profile    = currentProfile,
              let assessment = assessments.last(where: { $0.userId == currentUserId })
        else { return .blocked(reason: "No assessment found.") }
        
        let newScores = RecommendationEngine.calculateLifestyleScores(
            answers: userAnswers.filter { $0.assessmentId == assessment.id },
            store: self
        )
        
        if let currentPlan = activePlan {
            let update = RecommendationEngine.evaluatePlanUpdate(
                currentPlan: currentPlan,
                newStage: stage,
                newScores: newScores
            )
            
            if update.shouldUpdate {
                let result = submitSelfAssessedStage(
                    stage: stage, scalp: scalp,
                    density: density, scanType: .monthly
                )
                if case .success = result {
                    return .planUpdated(
                        newPlanId: update.newPlanId,
                        reason: update.reason,
                        highlights: update.highlights
                    )
                }
                return result }
            else {
                let scanId = UUID()
                let scan = ScalpScan(
                    id: scanId, userId: currentUserId, scanDate: Date(),
                    frontImageURL: "weekly_front", leftImageURL: "weekly_left",
                    rightImageURL: "weekly_right", backImageURL: "weekly_back",
                    topImageURL: "monthly_top", scanType: .monthly
                )
                scalpScans.append(scan)
                
                let densityPct: Float
                switch density {
                case .high:    densityPct = 85
                case .medium:  densityPct = 65
                case .low:     densityPct = 45
                case .veryLow: densityPct = 25
                case .notAssessed: densityPct = -1
                }
                
                let report = ScanReport(
                    id: UUID(), createdAt: Date(), scalpScanId: scanId,
                    hairDensityPercent: densityPct, hairDensityLevel: density,
                    hairFallStage: stage, scalpCondition: scalp,
                    analysisSource: isAIModel ? .aiModel : .selfAssessed,
                    planId: currentPlan.planId,
                    lifestyleScore: newScores.composite,
                    dietScore: newScores.diet, stressScore: newScores.stress,
                    sleepScore: newScores.sleep, hairCareScore: newScores.hairCare,
                    recommendedPlan: RecommendationEngine.planSummaryText(for: currentPlan.planId)
                )
                scanReports.append(report)
                
                // ── Save to Supabase ──
                let userId = currentUserId
                Task {
                    await BackendService.shared.saveScalpScan(scan: scan, userId: userId)
                    await BackendService.shared.saveScanReport(report: report, userId: userId)
                }
                
                return .success(message: "Monthly scan saved. Your plan \(currentPlan.planId) remains unchanged. \(update.reason)")
            }
        }
        
        return submitSelfAssessedStage(stage: stage, scalp: scalp, density: density, scanType: .monthly)
    }
    
    // MARK: 8 — Profile & Settings Updates
    
    @discardableResult
    func updatePhysicalProfile(
        heightCm: Float? = nil,
        weightKg: Float? = nil,
        activityLevel: ActivityLevel? = nil
    ) -> ActionResult {
        
        guard let idx = userProfiles.firstIndex(where: { $0.userId == currentUserId }) else {
            return .blocked(reason: "Profile not found.")
        }
        
        if let h = heightCm { userProfiles[idx].heightCm = h }
        if let w = weightKg { userProfiles[idx].weightKg = w }
        
        let profile  = userProfiles[idx]
        let dob      = profile.dateOfBirth
        let age      = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        let activity = activityLevel ?? activeNutritionProfile?.activityLevel ?? .sedentary
        
        let newNutrition = RecommendationEngine.calculateNutrition(
            userId: currentUserId,
            age: age, heightCm: profile.heightCm,
            weightKg: profile.weightKg, activityLevel: activity
        )
        
        userNutritionProfiles.removeAll(where: { $0.userId == currentUserId })
        userNutritionProfiles.append(newNutrition)
        
        
        if let prefIdx = appPreferences.firstIndex(where: { $0.userId == currentUserId }) {
            appPreferences[prefIdx].dailyCalorieGoal = newNutrition.tdee
            appPreferences[prefIdx].dailyWaterGoalML = newNutrition.waterTargetML
        }
        
        return .success(message: "Profile updated. Daily target: \(Int(newNutrition.tdee)) kcal.")
    }
    
    @discardableResult
    func updateNotificationSettings(
        mealReminderEnabled: Bool? = nil,
        mindfulReminderEnabled: Bool? = nil,
        waterReminderEnabled: Bool? = nil,
        bedtimeReminderEnabled: Bool? = nil,
        weeklyScanReminderEnabled: Bool? = nil
    ) -> ActionResult {
        
        guard let idx = notificationSettings.firstIndex(where: { $0.userId == currentUserId }) else {
            return .blocked(reason: "Settings not found.")
        }
        
        if let v = mealReminderEnabled         { notificationSettings[idx].mealReminderEnabled    = v }
        if let v = mindfulReminderEnabled       { notificationSettings[idx].mindfulReminderEnabled = v }
        if let v = waterReminderEnabled         { notificationSettings[idx].waterReminderEnabled   = v }
        if let v = bedtimeReminderEnabled       { notificationSettings[idx].bedtimeReminderEnabled = v }
        if let v = weeklyScanReminderEnabled    { notificationSettings[idx].weeklyScanReminderEnabled = v }
        
        return .success(message: "Notification settings updated.")
    }
    
    // MARK: 9 — Home Screen Computed Data
    
    @MainActor var dailyProgress: RecommendationEngine.DailyProgressSummary {
        RecommendationEngine.buildDailyProgressSummary(store: self)
    }
    
    var currentHairCareRoutine: [HairCareRoutine] {
        return hairInsightsStore.hairCareRoutines
    }
    
    
    // ─────────────────────────────────────────────
    // MARK: Private Helpers
    // ─────────────────────────────────────────────
    
    private func pickerValue(
        for key: String,
        assessment: Assessment,
        default fallback: Float
    ) -> Float {
        let orderIndex: Int
        switch key {
        case "age":    orderIndex = 4
        case "height": orderIndex = 5
        case "weight": orderIndex = 6
        default:       return fallback
        }
        guard let question = questions.first(where: { $0.questionOrderIndex == orderIndex }),
              let answer   = userAnswers.first(where: {
                  $0.questionId == question.id && $0.assessmentId == assessment.id
              })
        else { return fallback }
        return answer.pickerValue ?? fallback
    }
    
    
    private func ageFromProfile(_ profile: UserProfile) -> Int {
        Calendar.current.dateComponents([.year], from: profile.dateOfBirth, to: Date()).year ?? 0
    }
    
    func runEngineAndApply(
        scanId: UUID,
        stage: HairFallStage,
        scalp: ScalpCondition,
        density: HairDensityLevel,
        densityPercent: Float,
        hairType: String? = nil,
        source: AnalysisSource,
        profile: UserProfile,
        assessment: Assessment
    ) -> ActionResult {
        
        let age      = Int(pickerValue(for: "age",    assessment: assessment, default: 22))
        let heightCm = pickerValue(for: "height", assessment: assessment, default: 170)
        let weightKg = pickerValue(for: "weight", assessment: assessment, default: 70)
        
        // Activity level — from Q10 answer if present, else default to sedentary
        let activity = resolvedActivityLevel(from: assessment) ?? activeNutritionProfile?.activityLevel ?? .sedentary
        
        if let idx = userProfiles.firstIndex(where: { $0.userId == profile.userId }) {
            let dob = Calendar.current.date(byAdding: .year, value: -age, to: Date()) ?? Date()
            userProfiles[idx].dateOfBirth = dob
            userProfiles[idx].heightCm   = heightCm
            userProfiles[idx].weightKg   = weightKg
        }
        
        let input = EngineInput(
            userId:            currentUserId,
            assessmentId:      assessment.id,
            answers:           userAnswers.filter { $0.assessmentId == assessment.id },
            hairFallStage:     stage,
            scalpCondition:    scalp,
            hairDensityLevel:  density,
            hairDensityPercent: densityPercent,
            hairType:          hairType,
            analysisSource:    source,
            scalpScanId:       scanId,
            age:               age,
            heightCm:          heightCm,
            weightKg:          weightKg,
            activityLevel:     activity
        )
        
        let output = RecommendationEngine.run(input: input, store: self)
        RecommendationEngine.applyToStore(output, store: self)
        
        if output.userPlan.planId == "refer_doctor" {
            return .referDoctor(message: output.planDescription.doctorReferralMessage ?? "")
        }
        let scanToSave = scalpScans.last(where: { $0.id == scanId })
        let reportToSave = scanReports.last(where: { $0.scalpScanId == scanId })
        let userId = currentUserId
        
        Task {
            // Save scalp scan
            if let scan = scanToSave {
                await BackendService.shared.saveScalpScan(
                    scan: scan,
                    userId: userId
                )
            }
            
            // Save scan report
            if let report = reportToSave {
                await BackendService.shared.saveScanReport(
                    report: report,
                    userId: userId
                )
            }
            
            // Save plan
            await BackendService.shared.saveUserPlan(
                plan: output.userPlan,
                userId: userId
            )
            
            // Save nutrition
            if let nutrition = userNutritionProfiles.first(where: { $0.userId == userId }) {
                await BackendService.shared.saveNutritionProfile(
                    profile: nutrition,
                    userId: userId
                )
            }
        }
        
        return .success(message: "Plan \(output.userPlan.planId) assigned.")
    }
    
    
    private func resolvedActivityLevel(from assessment: Assessment) -> ActivityLevel? {
        guard let q7 = questions.first(where: { $0.questionOrderIndex == 7 }),
              let answer = userAnswers.first(where: {
                  $0.questionId == q7.id && $0.assessmentId == assessment.id
              }),
              let optionId = answer.selectedOptionId,
              let option = questionOptions.first(where: { $0.id == optionId })
        else { return nil }
        
        let text = option.optionText.lowercased()
        if text.contains("very active") { return .veryActive }
        if text.contains("moderate")    { return .moderate }
        if text.contains("light")       { return .light }
        return .sedentary
    }
}
