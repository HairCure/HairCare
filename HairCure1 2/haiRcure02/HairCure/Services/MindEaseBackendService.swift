// MindEaseBackendService.swift
import Foundation
import Supabase

final class MindEaseBackendService {

    static let shared = MindEaseBackendService()
    private let db    = SupabaseManager.shared.client
    private init() {}

    // MARK: - ISO 8601 helpers

    private let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoBasic = ISO8601DateFormatter()

    private func parseDate(_ string: String) -> Date? {
        isoFull.date(from: string) ?? isoBasic.date(from: string)
    }

    // MARK: - Fetch Categories + Contents

    func fetchCategoriesAndContents() async throws -> ([MindEaseCategory], [MindEaseCategoryContent]) {

        // ── STEP 1: Raw fetch — categories ──────────────────
        print("[MindEase] Fetching mindease_categories...")
        let catResponse = try await db
            .from("mindease_categories")
            .select()
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()

        let catRawString = String(data: catResponse.data, encoding: .utf8) ?? "nil"
        print("[MindEase] categories raw JSON:\n\(catRawString)")

        guard let catRows = try JSONSerialization.jsonObject(with: catResponse.data) as? [[String: Any]] else {
            print("[MindEase] categories: could not cast JSON to [[String:Any]]")
            return ([], [])
        }
        print("[MindEase] categories row count: \(catRows.count)")

        let categories: [MindEaseCategory] = catRows.compactMap { row in
            print("   CAT ROW keys: \(row.keys.sorted())")
            print("   CAT ROW values: \(row)")

            guard let idStr = row["id"] as? String else {
                print("missing 'id'"); return nil
            }
            guard let id = UUID(uuidString: idStr) else {
                print("invalid UUID: \(idStr)"); return nil
            }
            guard let title = row["title"] as? String else {
                print("missing 'title'"); return nil
            }
            guard let desc = row["description"] as? String else {
                print("missing 'description'"); return nil
            }
            guard let icon = row["card_icon_name"] as? String else {
                print("missing 'card_icon_name'"); return nil
            }

            let cardImageUrl = row["card_image_url"] as? String ?? ""
            print("CAT '\(title)' cardImageUrl='\(cardImageUrl)'")

            return MindEaseCategory(
                id:                  id,
                title:               title,
                categoryDescription: desc,
                cardImageUrl:        cardImageUrl,
                cardIconName:        icon
            )
        }
        print("[MindEase] Parsed \(categories.count) categories")

        // ── STEP 2: Raw fetch — contents ────────────────────
        print("[MindEase] Fetching mindease_contents...")
        let contentResponse = try await db
            .from("mindease_contents")
            .select()
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()

        let contentRawString = String(data: contentResponse.data, encoding: .utf8) ?? "nil"
        print("[MindEase] contents raw JSON:\n\(contentRawString)")

        guard let contentRows = try JSONSerialization.jsonObject(with: contentResponse.data) as? [[String: Any]] else {
            print("[MindEase] contents: could not cast JSON to [[String:Any]]")
            return (categories, [])
        }
        print("[MindEase] contents row count: \(contentRows.count)")

        let contents: [MindEaseCategoryContent] = contentRows.compactMap { row in
            print("   CONTENT ROW keys: \(row.keys.sorted())")

            guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr) else {
                print("missing/invalid 'id'"); return nil
            }
            guard let catIdStr = row["category_id"] as? String, let catId = UUID(uuidString: catIdStr) else {
                print("missing/invalid 'category_id'"); return nil
            }
            guard let title = row["title"] as? String else {
                print("missing 'title'"); return nil
            }
            guard let mediaURL = row["media_url"] as? String else {
                print("missing 'media_url' in '\(title)'"); return nil
            }
            guard let typeRaw = row["media_type"] as? String else {
                print("missing 'media_type' in '\(title)'"); return nil
            }
            guard let mediaType = MediaType(rawValue: typeRaw) else {
                print("unknown media_type '\(typeRaw)' in '\(title)'"); return nil
            }

            let thumbnailUrl = row["thumbnail_url"] as? String
            print("CONTENT '\(title)' mediaType=\(typeRaw) thumbnailUrl='\(thumbnailUrl ?? "nil")'")

            if let t = thumbnailUrl, URL(string: t) == nil {
                print("thumbnail_url is NOT a valid URL: '\(t)'")
            }

            return MindEaseCategoryContent(
                id:              id,
                categoryId:      catId,
                title:           title,
                caption:         row["caption"] as? String ?? "",
                mediaURL:        mediaURL,
                mediaType:       mediaType,
                durationSeconds: row["duration_seconds"] as? Int ?? 0,
                difficultyLevel: row["difficulty_level"] as? String ?? "beginner",
                imageurl:        thumbnailUrl ?? "",
                thumbnailUrl:    thumbnailUrl
            )
        }
        print("[MindEase] Parsed \(contents.count) contents")
        return (categories, contents)
    }

    // MARK: - Fetch Sessions

    func fetchSessions(userId: UUID) async -> [MindfulSession] {
        do {
            let response = try await db
                .from("mindful_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("session_date", ascending: false)
                .execute()

            let rows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []

            return rows.compactMap { row -> MindfulSession? in
                guard
                    let idStr        = row["id"] as? String,         let id        = UUID(uuidString: idStr),
                    let contentIdStr = row["content_id"] as? String, let contentId = UUID(uuidString: contentIdStr),
                    let dateStr      = row["session_date"] as? String,
                    let sessionDate  = parseDate(dateStr) ?? DateFormatter.yyyyMMdd.date(from: dateStr),
                    let startStr     = row["start_time"] as? String,
                    let startTime    = parseDate(startStr),
                    let endStr       = row["end_time"] as? String,
                    let endTime      = parseDate(endStr),
                    let minutes      = row["minutes_completed"] as? Int
                else { return nil }

                return MindfulSession(
                    id: id, userId: userId, contentId: contentId,
                    sessionDate: sessionDate, minutesCompleted: minutes,
                    startTime: startTime, endTime: endTime
                )
            }
        } catch {
            print("Fetch MindEase sessions error: \(error)")
            return []
        }
    }

    // MARK: - Save Session

    func saveSession(_ session: MindfulSession) async {
        // ── Guard: verify content exists in Supabase before writing the FK ──
        let contentIdStr = session.contentId.uuidString
        print("[MindEase] saveSession — checking content_id exists: \(contentIdStr)")
        do {
            let check = try await db
                .from("mindease_contents")
                .select("id")
                .eq("id", value: contentIdStr)
                .execute()
            let rows = (try? JSONSerialization.jsonObject(with: check.data) as? [[String: Any]]) ?? []
            guard !rows.isEmpty else {
                print("Save MindEase session aborted — content_id \(contentIdStr) not found in mindease_contents. "
                    + "The session was recorded locally but cannot be persisted until the content is seeded in Supabase.")
                return
            }
        } catch {
            print("[MindEase] content_id existence check failed (\(error)) — attempting save anyway")
        }

        do {
            let data: [String: AnyJSON] = [
                "id":                  .string(session.id.uuidString),
                "user_id":             .string(session.userId.uuidString),
                "content_id":          .string(contentIdStr),
                "session_date":        .string(DateFormatter.yyyyMMdd.string(from: session.sessionDate)),
                "minutes_completed":   .double(Double(session.minutesCompleted)),
                "start_time":          .string(isoFull.string(from: session.startTime)),
                "end_time":            .string(isoFull.string(from: session.endTime))
            ]
            try await db.from("mindful_sessions").upsert(data).execute()
            print("MindEase session saved: \(session.id)")
        } catch {
            print("Save MindEase session error: \(error)")
        }
    }

    // MARK: - Save Plan

    func savePlan(_ plan: TodaysPlan) async {
        do {
            let data: [String: AnyJSON] = [
                "id":                .string(plan.id.uuidString),
                "user_id":           .string(plan.userId.uuidString),
                "plan_date":         .string(DateFormatter.yyyyMMdd.string(from: plan.planDate)),
                "content_id":        .string(plan.contentId.uuidString),
                "category_id":       .string(plan.categoryId.uuidString),
                "plan_id":           .string(plan.planId),
                "minutes_target":    .double(Double(plan.minutesTarget)),
                "minutes_completed": .double(Double(plan.minutesCompleted)),
                "is_completed":      .bool(plan.isCompleted)
            ]
            try await db.from("todays_plans").upsert(data).execute()
        } catch {
            print("Save MindEase plan error: \(error)")
        }
    }

    // MARK: - Mood Tracking & Recommendations
    
    func logUserMood(userId: UUID, mood: String) async {
        do {
            let data: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "mood":    .string(mood)
            ]
            try await db.from("user_mood_logs").insert(data).execute()
        } catch {
            print("MindEase log user mood error: \(error)")
        }
    }
    
    func fetchMoodRecommendations(mood: String) async -> [MindEaseCategoryContent] {
        do {
            let response = try await db
                .rpc("get_mood_recommendations", params: ["p_mood": mood])
                .execute()
            
            guard let contentRows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
                return []
            }
            
            let contents: [MindEaseCategoryContent] = contentRows.compactMap { row in
                guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                      let catIdStr = row["category_id"] as? String, let catId = UUID(uuidString: catIdStr),
                      let title = row["title"] as? String,
                      let mediaURL = row["media_url"] as? String,
                      let typeRaw = row["media_type"] as? String,
                      let mediaType = MediaType(rawValue: typeRaw)
                else { return nil }

                let thumbnailUrl = row["thumbnail_url"] as? String

                return MindEaseCategoryContent(
                    id:              id,
                    categoryId:      catId,
                    title:           title,
                    caption:         row["caption"] as? String ?? "",
                    mediaURL:        mediaURL,
                    mediaType:       mediaType,
                    durationSeconds: row["duration_seconds"] as? Int ?? 0,
                    difficultyLevel: row["difficulty_level"] as? String ?? "beginner",
                    imageurl:        thumbnailUrl ?? "",
                    thumbnailUrl:    thumbnailUrl
                )
            }
            return contents
        } catch {
            print("MindEase fetch mood recommendations error: \(error)")
            return []
        }
    }
}

// MARK: - DateFormatter helper

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
