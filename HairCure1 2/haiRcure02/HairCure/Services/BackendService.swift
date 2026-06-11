import Foundation
import Supabase

class BackendService {
    
    static let shared = BackendService()
    private let db = SupabaseManager.shared.client
    private init() {}
    
    // MARK: - Save Profile
    func saveProfile(userId: UUID, name: String, email: String) async {
        do {
            try await db.from("profiles").upsert([
                "id": AnyJSON.string(userId.uuidString),
                "name": AnyJSON.string(name),
                "email": AnyJSON.string(email),
                "display_name": AnyJSON.string(name),
                "joined_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
            ]).execute()
            print("Profile saved")
        } catch {
            print("Profile save error: \(error)")
        }
    }
    
    // MARK: - Update Profile Physical Data
    func updateProfilePhysical(
        userId: UUID,
        heightCm: Float,
        weightKg: Float,
        age: Int
    ) async {
        let dob = Calendar.current.date(
            byAdding: .year, value: -age, to: Date()
        ) ?? Date()
        do {
            try await db.from("profiles").update([
                "height_cm": AnyJSON.double(Double(heightCm)),
                "weight_kg": AnyJSON.double(Double(weightKg)),
                "date_of_birth": AnyJSON.string(ISO8601DateFormatter().string(from: dob)),
                "is_profile_complete": AnyJSON.bool(true)
            ])
            .eq("id", value: userId.uuidString)
            .execute()
            print("Physical profile updated")
        } catch {
            print("Physical profile update error: \(error)")
        }
    }
    
    // MARK: - Save Assessment
    func saveAssessment(
        assessmentId: UUID,
        userId: UUID,
        completionPercent: Float,
        completedAt: Date?
    ) async {
        do {
            var data: [String: AnyJSON] = [
                "id": .string(assessmentId.uuidString),
                "user_id": .string(userId.uuidString),
                "completion_percent": .double(Double(completionPercent))
            ]
            if let date = completedAt {
                data["completed_at"] = .string(ISO8601DateFormatter().string(from: date))
            }
            try await db.from("assessments").upsert(data).execute()
            print("Assessment saved")
        } catch {
            print("Assessment save error: \(error)")
        }
    }
    
    // MARK: - Save User Answers
    func saveUserAnswers(answers: [UserAnswer], userId: UUID) async {
        do {
            let rows: [[String: AnyJSON]] = answers.map { answer in
                var row: [String: AnyJSON] = [
                    "id": .string(answer.id.uuidString),
                    "user_id": .string(userId.uuidString),
                    "assessment_id": .string(answer.assessmentId.uuidString),
                    "question_id": .string(answer.questionId.uuidString),
                    "answered_at": .string(ISO8601DateFormatter().string(from: answer.answeredAt))
                ]
                if let optId = answer.selectedOptionId {
                    row["selected_option_id"] = .string(optId.uuidString)
                }
                if let val = answer.pickerValue {
                    row["picker_value"] = .double(Double(val))
                }
                if let score = answer.scoreValue {
                    row["score_value"] = .double(Double(score))
                }
                if let dim = answer.scoreDimension {
                    row["score_dimension"] = .string(dim.rawValue)
                }
                return row
            }
            try await db.from("user_answers").upsert(rows).execute()
            print("\(answers.count) answers saved")
        } catch {
            print("Answers save error: \(error)")
        }
    }
    
    // MARK: - Save User Plan
    func saveUserPlan(plan: UserPlan, userId: UUID) async {
        do {
            let data: [String: AnyJSON] = [
                "id": .string(plan.id.uuidString),
                "user_id": .string(userId.uuidString),
                "plan_id": .string(plan.planId),
                "stage": .double(Double(plan.stage)),
                "lifestyle_profile": .string(plan.lifestyleProfile.rawValue),
                "scalp_modifier": .string(plan.scalpModifier.rawValue),
                "meditation_minutes_per_day": .double(Double(plan.meditationMinutesPerDay)),
                "yoga_minutes_per_day": .double(Double(plan.yogaMinutesPerDay)),
                "sound_minutes_per_day": .double(Double(plan.soundMinutesPerDay)),
                "session_frequency_per_week": .double(Double(plan.sessionFrequencyPerWeek)),
                "is_active": .bool(plan.isActive),
                "assigned_at": .string(ISO8601DateFormatter().string(from: plan.assignedAt)),
                "expires_at": .string(ISO8601DateFormatter().string(from: plan.expiresAt))
            ]
            try await db.from("user_plans").upsert(data).execute()
            print("User plan saved: \(plan.planId)")
        } catch {
            print("Plan save error: \(error)")
        }
    }
    
    // MARK: - Save Nutrition Profile
    func saveNutritionProfile(profile: UserNutritionProfile, userId: UUID) async {
        do {
            let data: [String: AnyJSON] = [
                "id": .string(profile.id.uuidString),
                "user_id": .string(userId.uuidString),
                "activity_level": .string(profile.activityLevel.rawValue),
                "bmr": .double(Double(profile.bmr)),
                "tdee": .double(Double(profile.tdee)),
                "breakfast_cal_target": .double(Double(profile.breakfastCalTarget)),
                "lunch_cal_target": .double(Double(profile.lunchCalTarget)),
                "snack_cal_target": .double(Double(profile.snackCalTarget)),
                "dinner_cal_target": .double(Double(profile.dinnerCalTarget)),
                "protein_target_gm": .double(Double(profile.proteinTargetGm)),
                "carb_target_gm": .double(Double(profile.carbTargetGm)),
                "fat_target_gm": .double(Double(profile.fatTargetGm)),
                "water_target_ml": .double(Double(profile.waterTargetML))
            ]
            try await db.from("nutrition_profiles").upsert(data).execute()
            print("Nutrition profile saved")
        } catch {
            print("Nutrition save error: \(error)")
        }
    }
    
    
    
    // MARK: - Save Scalp Scan
    func saveScalpScan(scan: ScalpScan, userId: UUID) async {
        do {
            // Canonicalise: .weekly is a legacy case — always write "monthly" to DB
            let scanTypeValue: String
            switch scan.scanType {
            case .initial:          scanTypeValue = "initial"
            case .monthly, .weekly: scanTypeValue = "monthly"
            }
            let data: [String: AnyJSON] = [
                "id": .string(scan.id.uuidString),
                "user_id": .string(userId.uuidString),
                "scan_date": .string(ISO8601DateFormatter().string(from: scan.scanDate)),
                "front_image_url": .string(scan.frontImageURL),
                "left_image_url": .string(scan.leftImageURL),
                "right_image_url": .string(scan.rightImageURL),
                "back_image_url": .string(scan.backImageURL),
                "top_image_url": .string(scan.topImageURL),
                "scan_type": .string(scanTypeValue)
            ]
            try await db.from("scalp_scans").upsert(data).execute()
            print("Scalp scan saved")
        } catch {
            print("Scalp scan save error: \(error)")
        }
    }

    // MARK: - Fetch Scalp Scans
    /// Fetches all scalp scans belonging to `userId` from Supabase.
    /// This is needed on login so the in-memory `scalpScans` array is populated,
    /// enabling the user-ID filter in HairProgressView to work correctly.
    func fetchScalpScans(userId: UUID) async -> [ScalpScan] {
        do {
            let response = try await db
                .from("scalp_scans")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("scan_date", ascending: false)
                .execute()

            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]] ?? []

            let isoFull = ISO8601DateFormatter()
            isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoBasic = ISO8601DateFormatter()

            return decoded.compactMap { row -> ScalpScan? in
                guard
                    let idStr   = row["id"]      as? String, let id   = UUID(uuidString: idStr),
                    let dateStr = row["scan_date"] as? String,
                    let date    = isoFull.date(from: dateStr) ?? isoBasic.date(from: dateStr),
                    let typeRaw = row["scan_type"] as? String,
                    let type    = ScanType(rawValue: typeRaw)
                else { return nil }

                return ScalpScan(
                    id:             id,
                    userId:         userId,
                    scanDate:       date,
                    frontImageURL:  row["front_image_url"] as? String ?? "",
                    leftImageURL:   row["left_image_url"]  as? String ?? "",
                    rightImageURL:  row["right_image_url"] as? String ?? "",
                    backImageURL:   row["back_image_url"]  as? String ?? "",
                    topImageURL:    row["top_image_url"]   as? String ?? "",
                    scanType:       type
                )
            }
        } catch {
            print("Fetch scalp scans error: \(error)")
            return []
        }
    }

    
    // MARK: - Save Scan Report
    func saveScanReport(report: ScanReport, userId: UUID) async {
        do {
            var data: [String: AnyJSON] = [
                "id": .string(report.id.uuidString),
                "user_id": .string(userId.uuidString),
                "scalp_scan_id": .string(report.scalpScanId.uuidString),
                "hair_density_percent": .double(Double(report.hairDensityPercent)),
                "hair_density_level": .string(report.hairDensityLevel.rawValue),
                "hair_fall_stage": .string(report.hairFallStage.rawValue),
                "scalp_condition": .string(report.scalpCondition.rawValue),
                "analysis_source": .string(report.analysisSource.rawValue),
                "plan_id": .string(report.planId),
                "lifestyle_score": .double(Double(report.lifestyleScore)),
                "diet_score": .double(Double(report.dietScore)),
                "stress_score": .double(Double(report.stressScore)),
                "sleep_score": .double(Double(report.sleepScore)),
                "hair_care_score": .double(Double(report.hairCareScore)),
                "recommended_plan": .string(report.recommendedPlan)
            ]
            if let hairType = report.hairType {
                data["hair_type"] = .string(hairType)
            }
            try await db.from("scan_reports").upsert(data).execute()
            print("Scan report saved")
        } catch {
            print("Scan report save error: \(error)")
        }
    }
    func fetchAssessment(userId: UUID) async -> Bool {
        print("Fetching assessment for UUID: \(userId.uuidString)")
        do {
            let response = try await db
                .from("assessments")
                .select()
                .eq("user_id", value: userId.uuidString)
                .not("completed_at", operator: .is, value: AnyJSON.null)
                .execute()
            let decoded = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]]
            print("Assessment rows found: \(decoded?.count ?? 0)")
            print("Raw response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            return !(decoded?.isEmpty ?? true)
        } catch {
            print("Fetch assessment error: \(error)")
            return false
        }
    }

    // MARK: - Fetch Profile Physical Data
    /// Returns height, weight, DOB from the `profiles` table.
    func fetchProfileData(userId: UUID) async -> (heightCm: Float, weightKg: Float, dob: Date?)? {
        do {
            let response = try await db
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
            let decoded = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]]
            guard let row = decoded?.first else { return nil }

            let isoFull = ISO8601DateFormatter()
            isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoBasic = ISO8601DateFormatter()

            let height = (row["height_cm"] as? Double).map { Float($0) } ?? 0
            let weight = (row["weight_kg"] as? Double).map { Float($0) } ?? 0
            let dob: Date? = (row["date_of_birth"] as? String).flatMap {
                isoFull.date(from: $0) ?? isoBasic.date(from: $0)
            }
            print("Profile fetched — height: \(height) weight: \(weight)")
            return (heightCm: height, weightKg: weight, dob: dob)
        } catch {
            print("Fetch profile error: \(error)")
            return nil
        }
    }

    // MARK: - Fetch Nutrition Profile
    func fetchNutritionProfile(userId: UUID) async -> UserNutritionProfile? {
        do {
            let response = try await db
                .from("nutrition_profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            let decoded = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]]
            guard let row = decoded?.first,
                  let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                  let actRaw = row["activity_level"] as? String,
                  let activity = ActivityLevel(rawValue: actRaw)
            else { return nil }

            let isoFull = ISO8601DateFormatter()
            isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoBasic = ISO8601DateFormatter()
            func date(_ key: String) -> Date {
                (row[key] as? String).flatMap { isoFull.date(from: $0) ?? isoBasic.date(from: $0) } ?? Date()
            }
            func f(_ key: String) -> Float { Float(row[key] as? Double ?? 0) }

            print("Nutrition profile fetched — tdee: \(f("tdee")) water: \(f("water_target_ml"))")
            return UserNutritionProfile(
                id:                 id,
                userId:             userId,
                activityLevel:      activity,
                bmr:                f("bmr"),
                tdee:               f("tdee"),
                breakfastCalTarget: f("breakfast_cal_target"),
                lunchCalTarget:     f("lunch_cal_target"),
                snackCalTarget:     f("snack_cal_target"),
                dinnerCalTarget:    f("dinner_cal_target"),
                proteinTargetGm:    f("protein_target_gm"),
                carbTargetGm:       f("carb_target_gm"),
                fatTargetGm:        f("fat_target_gm"),
                waterTargetML:      f("water_target_ml"),
                createdAt:          date("created_at"),
                updatedAt:          date("updated_at")
            )
        } catch {
            print("Fetch nutrition profile error: \(error)")
            return nil
        }
    }

    // MARK: - Fetch User Plan (typed)
    func fetchUserPlan(userId: UUID) async -> UserPlan? {
        do {
            let response = try await db
                .from("user_plans")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("assigned_at", ascending: false)
                .limit(1)
                .execute()

            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]]
            guard let row = decoded?.first,
                  let idStr  = row["id"]  as? String, let id  = UUID(uuidString: idStr),
                  let planId = row["plan_id"] as? String,
                  let lpRaw  = row["lifestyle_profile"] as? String,
                  let lp     = LifestyleProfile(rawValue: lpRaw),
                  let smRaw  = row["scalp_modifier"] as? String,
                  let sm     = ScalpCondition(rawValue: smRaw)
            else { return nil }

            let isoFull = ISO8601DateFormatter()
            isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoBasic = ISO8601DateFormatter()
            func date(_ key: String) -> Date {
                (row[key] as? String).flatMap { isoFull.date(from: $0) ?? isoBasic.date(from: $0) } ?? Date()
            }
            func i(_ key: String) -> Int { Int(row[key] as? Double ?? 0) }

            print("User plan fetched: \(planId)")
            return UserPlan(
                id:                      id,
                userId:                  userId,
                scanReportId:            UUID(),   // not stored — placeholder
                planId:                  planId,
                stage:                   i("stage"),
                lifestyleProfile:        lp,
                scalpModifier:           sm,
                meditationMinutesPerDay: i("meditation_minutes_per_day"),
                yogaMinutesPerDay:       i("yoga_minutes_per_day"),
                soundMinutesPerDay:      i("sound_minutes_per_day"),
                sessionFrequencyPerWeek: i("session_frequency_per_week"),
                isActive:                row["is_active"] as? Bool ?? true,
                assignedAt:              date("assigned_at"),
                expiresAt:               date("expires_at")
            )
        } catch {
            print("Fetch plan error: \(error)")
            return nil
        }
    }

    
    // MARK: - Save Favourite
    func saveFavourite(
        userId: UUID,
        contentId: UUID,
        contentType: String
    ) async {
        do {
            let data: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "content_id": .string(contentId.uuidString),
                "content_type": .string(contentType),
                "saved_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            try await db.from("user_favourites").upsert(data).execute()
            print("Favourite saved: \(contentType)")
        } catch {
            print("Favourite save error: \(error)")
        }
    }
    
    // MARK: - Delete Favourite
    func deleteFavourite(userId: UUID, contentId: UUID) async {
        do {
            try await db.from("user_favourites")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("content_id", value: contentId.uuidString)
                .execute()
            print("Favourite removed")
        } catch {
            print("Favourite delete error: \(error)")
        }
    }
    
    // MARK: - Fetch Favourites
    func fetchFavourites(userId: UUID) async -> [(contentId: UUID, contentType: String, savedAt: Date)] {
        do {
            let response = try await db
                .from("user_favourites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("saved_at", ascending: false)
                .execute()
            
            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]] ?? []
            
            return decoded.compactMap { row in
                guard let contentIdStr = row["content_id"] as? String,
                      let contentId = UUID(uuidString: contentIdStr),
                      let contentType = row["content_type"] as? String
                else { return nil }
                let savedAt = (row["saved_at"] as? String)
                    .flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
                return (contentId: contentId, contentType: contentType, savedAt: savedAt)
            }
        } catch {
            print("Fetch favourites error: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Care Tips
    func fetchCareTips() async -> [CareTip] {
        do {
            let response = try await db
                .from("care_tip")
                .select()
                .eq("is_active", value: true)
                .execute()
            
            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]] ?? []
            
            return decoded.compactMap { row in
                guard let idStr = row["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let title = row["title"] as? String,
                      let desc = row["tip_description"] as? String
                else { return nil }
                
                return CareTip(
                    id: id,
                    title: title,
                    tipDescription: desc,
                    mediaURL: row["media_url"] as? String,
                    steps: row["steps"] as? [String] ?? [],
                    frequency: row["frequency"] as? String,
                    precautions: row["precautions"] as? String,
                    researchURL: row["research_url"] as? String,
                    hairTypes: row["hair_types"] as? [String] ?? [],
                    isActive: row["is_active"] as? Bool ?? true
                )
            }
        } catch {
            print("Fetch care tips error: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Home Remedies
    func fetchHomeRemedies() async -> [HomeRemedy] {
        do {
            let response = try await db
                .from("home_remedy")
                .select()
                .eq("is_active", value: true)
                .execute()
            
            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]] ?? []
            
            return decoded.compactMap { row in
                guard let idStr = row["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let title = row["title"] as? String,
                      let desc = row["remedy_description"] as? String,
                      let benefits = row["benefits"] as? String
                else { return nil }
                
                return HomeRemedy(
                    id: id,
                    title: title,
                    remedyDescription: desc,
                    mediaURL: row["media_url"] as? String,
                    videoDurationSeconds: row["video_duration_seconds"] as? Int,
                    videoURL: row["video_url"] as? String,
                    ingredients: row["ingredients"] as? [String] ?? [],
                    steps: row["steps"] as? [String] ?? [],
                    benefits: benefits,
                    frequency: row["frequency"] as? String,
                    precautions: row["precautions"] as? String,
                    researchURL: row["research_url"] as? String,
                    hairTypes: row["hair_types"] as? [String] ?? [],
                    isActive: row["is_active"] as? Bool ?? true
                )
            }
        } catch {
            print("Fetch home remedies error: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Hair Care Routines
    func fetchHairCareRoutines() async -> [HairCareRoutine] {
        do {
            let response = try await db
                .from("hair_care_routine")
                .select()
                .eq("is_active", value: true)
                .execute()
            
            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]] ?? []
            
            return decoded.compactMap { row in
                guard let idStr = row["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let heading = row["card_heading"] as? String,
                      let freq = row["applying_frequency"] as? String,
                      let summary = row["summary"] as? String
                else { return nil }
                
                return HairCareRoutine(
                    id: id,
                    cardHeading: heading,
                    applyingFrequency: freq,
                    summary: summary,
                    benefits: row["benefits"] as? String,
                    steps: row["steps"] as? [String] ?? [],
                    precautions: row["precautions"] as? String,
                    researchURL: row["research_url"] as? String,
                    hairTypes: row["hair_types"] as? [String] ?? [],
                    isActive: row["is_active"] as? Bool ?? true
                )
            }
        } catch {
            print("Fetch hair care routines error: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Scan Reports
    func fetchScanReports(userId: UUID) async -> [ScanReport] {
        do {
            let response = try await db
                .from("scan_reports")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]] ?? []
            
            let isoFull = ISO8601DateFormatter()
            isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoBasic = ISO8601DateFormatter()
            
            return decoded.compactMap { row -> ScanReport? in
                guard
                    let idStr   = row["id"]   as? String, let id   = UUID(uuidString: idStr),
                    let scanStr = row["scalp_scan_id"] as? String, let scanId = UUID(uuidString: scanStr),
                    let createdStr = row["created_at"] as? String,
                    let createdAt  = isoFull.date(from: createdStr) ?? isoBasic.date(from: createdStr),
                    let densityPct = row["hair_density_percent"] as? Double,
                    let densityLvlRaw = row["hair_density_level"] as? String,
                    let densityLvl    = HairDensityLevel(rawValue: densityLvlRaw),
                    let stageRaw   = row["hair_fall_stage"] as? String,
                    let stage      = HairFallStage(rawValue: stageRaw),
                    let scalpRaw   = row["scalp_condition"] as? String,
                    let scalp      = ScalpCondition(rawValue: scalpRaw),
                    let planId     = row["plan_id"] as? String,
                    let recPlan    = row["recommended_plan"] as? String
                else { return nil }

                // analysis_source is optional — default to .selfAssessed if missing/null
                let source: AnalysisSource
                if let sourceRaw = row["analysis_source"] as? String,
                   let decoded   = AnalysisSource(rawValue: sourceRaw) {
                    source = decoded
                } else {
                    source = .selfAssessed
                }
                
                return ScanReport(
                    id:                 id,
                    createdAt:          createdAt,
                    scalpScanId:        scanId,
                    hairDensityPercent: Float(densityPct),
                    hairDensityLevel:   densityLvl,
                    hairFallStage:      stage,
                    scalpCondition:     scalp,
                    hairType:           row["hair_type"] as? String,
                    analysisSource:     source,
                    planId:             planId,
                    lifestyleScore:     Float(row["lifestyle_score"] as? Double ?? 5.0),
                    dietScore:          Float(row["diet_score"]      as? Double ?? 5.0),
                    stressScore:        Float(row["stress_score"]    as? Double ?? 5.0),
                    sleepScore:         Float(row["sleep_score"]     as? Double ?? 5.0),
                    hairCareScore:      Float(row["hair_care_score"] as? Double ?? 5.0),
                    recommendedPlan:    recPlan
                )
            }
        } catch {
            print("Fetch scan reports error: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Meals from Backend (meals + meal_nutrients joined)
    
    func fetchMeals(vegetarianOnly: Bool = false) async -> [Food] {
        do {
            var query = db
                .from("meals")
                .select("*, meal_nutrients(*)")
            
            if vegetarianOnly {
                query = query.eq("is_veg", value: true)
            }
            
            let response = try await query.execute()
            
            let decoded = try JSONSerialization.jsonObject(
                with: response.data
            ) as? [[String: Any]] ?? []
            
            return decoded.compactMap { row -> Food? in
                guard
                    let id       = row["id"] as? Int,
                    let name     = row["name"] as? String,
                    let catRaw   = row["category"] as? String,
                    let category = mealTypeFrom(catRaw)
                else { return nil }
                
                // meal_nutrients is a nested array (1-to-1 join returns array)
                let nutrients = (row["meal_nutrients"] as? [[String: Any]])?.first
                
                let protein  = (nutrients?["protein_g"]       as? Double).map { Float($0) } ?? 0
                let iron     = (nutrients?["iron_mg"]          as? Double).map { Float($0) } ?? 0
                let vitD     = (nutrients?["vitamin_d_iu"]     as? Double).map { Float($0) } ?? 0
                let vitC     = (nutrients?["vitamin_c_mg"]     as? Double).map { Float($0) } ?? 0
                let zinc     = (nutrients?["zinc_mg"]          as? Double).map { Float($0) } ?? 0
                let omega3   = (nutrients?["omega3_g"]         as? Double).map { Float($0) } ?? 0
                let b12      = (nutrients?["vitamin_b12_mcg"]  as? Double).map { Float($0) } ?? 0
                let biotin   = (nutrients?["biotin_mcg"]       as? Double).map { Float($0) } ?? 0
                let vitE     = (nutrients?["vitamin_e_mg"]     as? Double).map { Float($0) } ?? 0
                let selenium = (nutrients?["selenium_mcg"]     as? Double).map { Float($0) } ?? 0
                let niacin   = (nutrients?["niacin_mg"]        as? Double).map { Float($0) } ?? 0
                let carbs    = (nutrients?["carbs_g"]          as? Double).map { Float($0) } ?? 0
                let fat      = (nutrients?["fat_g"]            as? Double).map { Float($0) } ?? 0
                
                return Food(
                    id:               id,
                    name:             name,
                    description:      row["description"]   as? String,
                    imageURL:         row["image_url"]     as? String,
                    category:         category,
                    isVegetarian:     row["is_veg"]        as? Bool ?? true,
                    hairBenefit:      row["hair_benefit"]  as? String,
                    dataSource:       row["data_source"]   as? String,
                    caloriesKcal:     Float((row["calories_kcal"] as? Double) ?? 0),
                    totalProteinsInGm: protein,
                    totalCarbsInGm:   carbs,
                    totalFatInGm:     fat,
                    ironMg:           iron,
                    vitaminDIU:       vitD,
                    vitaminCMg:       vitC,
                    zincMg:           zinc,
                    omega3G:          omega3,
                    vitaminB12Mcg:    b12,
                    biotinMcg:        biotin,
                    vitaminEMg:       vitE,
                    seleniumMcg:      selenium,
                    niacinMg:         niacin
                )
            }
        } catch {
            print("Fetch meals error: \(error)")
            return []
        }
    }
    
    private func mealTypeFrom(_ raw: String) -> MealType? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "breakfast": return .breakfast
        case "lunch":     return .lunch
        case "snack", "snacks": return .snack
        case "dinner":    return .dinner
        default:          return nil
        }
    }
}
