
//  Weekly scan submission pipeline:
//  1. Carry lifestyle scores forward from prior ScanReport (no re-assessment)
//  2. Evaluate whether active plan should change via RecommendationEngine
//  3. If plan changes → deactivate old plan, append updated plan
//  4. Build and append new ScanReport, return it
//

import Foundation

extension AppDataStore {
    
    // MARK: - Submit Weekly Scan
    
    
    @discardableResult
    func submitWeeklyScan(
        hairFallStage:     HairFallStage,
        scalpCondition:    ScalpCondition,
        hairDensityLevel:  HairDensityLevel,
        hairDensityPercent: Float
    ) -> ScanReport {
        
        let prior = latestScanReport
        
        // Carry lifestyle scores forward
        let lifeScore     = prior?.lifestyleScore  ?? 5.0
        let dietScore     = prior?.dietScore       ?? 5.0
        let stressScore   = prior?.stressScore     ?? 5.0
        let sleepScore    = prior?.sleepScore      ?? 5.0
        let hairCareScore = prior?.hairCareScore   ?? 5.0
        
        //Pre generate report ID so plan can reference it
        let reportId = UUID()
        
        // Plan re-evaluation
        var finalPlanId = activePlan?.planId ?? "2A"
        
        if let currentPlan = activePlan {
            let carriedScores = RecommendationEngine.LifestyleScores(
                diet:      dietScore,
                stress:    stressScore,
                sleep:     sleepScore,
                hairCare:  hairCareScore,
                hydration: dietScore,       // approximate from diet
                composite: lifeScore
            )
            
            let evalResult = RecommendationEngine.evaluatePlanUpdate(
                currentPlan: currentPlan,
                newStage:    hairFallStage,
                newScores:   carriedScores
            )
            
            if evalResult.shouldUpdate {
                finalPlanId = evalResult.newPlanId
                
                // Deactivate existing plans
                for idx in userPlans.indices where userPlans[idx].isActive {
                    userPlans[idx].isActive = false
                }
                
                
                let newSchedule = RecommendationEngine.resolveSessionSchedule(planId: finalPlanId)
                
                let updatedPlan = UserPlan(
                    id:                        UUID(),
                    userId:                    currentPlan.userId,
                    scanReportId:              reportId,
                    planId:                    finalPlanId,
                    stage:                     hairFallStage.intValue,
                    lifestyleProfile:          currentPlan.lifestyleProfile,
                    scalpModifier:             scalpCondition,
                    meditationMinutesPerDay:   newSchedule.meditationMinutes,
                    yogaMinutesPerDay:         newSchedule.yogaMinutes,
                    soundMinutesPerDay:        newSchedule.soundMinutes,
                    sessionFrequencyPerWeek:   newSchedule.frequencyPerWeek,
                    isActive:                  true,
                    assignedAt:                Date(),
                    expiresAt:                 Calendar.current.date(
                        byAdding: .day, value: 7, to: Date()
                    )!
                )
                userPlans.append(updatedPlan)
                
                // Update today's mindful goal in preferences
                if let prefIdx = appPreferences.firstIndex(where: {
                    $0.userId == currentPlan.userId
                }) {
                    appPreferences[prefIdx].dailyMindfulMinutesGoal =
                    newSchedule.meditationMinutes +
                    newSchedule.yogaMinutes +
                    newSchedule.soundMinutes
                }
            }
        }
        
        // ── Build and store the ScanReport 
        let report = ScanReport(
            id:                 reportId,
            createdAt:          Date(),
            scalpScanId:        UUID(),
            hairDensityPercent: hairDensityPercent,
            hairDensityLevel:   hairDensityLevel,
            hairFallStage:      hairFallStage,
            scalpCondition:     scalpCondition,
            analysisSource:     .aiModel,
            planId:             finalPlanId,
            lifestyleScore:     lifeScore,
            dietScore:          dietScore,
            stressScore:        stressScore,
            sleepScore:         sleepScore,
            hairCareScore:      hairCareScore,
            recommendedPlan:    RecommendationEngine.planSummaryText(for: finalPlanId)
        )
        
        scanReports.append(report)
        saveScanReportToBackend(report)
        return report
    }
}

