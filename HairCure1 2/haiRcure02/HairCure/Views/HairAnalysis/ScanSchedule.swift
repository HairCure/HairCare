
//  No prior scan          → firstScan    → full monthly assessment
//  0–6 days since last    → notDue       → countdown chip only
//  7–27 days since last   → weeklyDue    → WeeklyScanView (3 photos)
//  ≥28 days since last    → monthlyDue   → full re-assessment (AssessmentView)
import Foundation

extension RecommendationEngine {

    // MARK: - Scan Schedule Enum

    enum ScanSchedule: Equatable {
        /// No scans exist at all — launch full first-time assessment.
        case firstScan
        /// ≥28 days since last scan — full monthly re-assessment.
        case monthlyDue(dueDate: Date)
        /// <28 days since last scan — show countdown, no scan allowed.
        case notDue(nextDate: Date, daysLeft: Int)
    }

    // MARK: - Schedule Resolver

    /// Returns the current scan schedule based on the store's scan history.
    static func scanSchedule(store: AppDataStore) -> ScanSchedule {
        guard let latest = store.latestScanReport else {
            return .firstScan
        }

        let cal         = Calendar.current
        let now         = Date()
        let daysSince   = cal.dateComponents([.day], from: latest.createdAt, to: now).day ?? 0
        let nextMonthly = cal.date(byAdding: .day, value: 28, to: latest.createdAt) ?? now

        if daysSince < 28 {
            return .notDue(nextDate: nextMonthly, daysLeft: max(1, 28 - daysSince))
        } else {
            return .monthlyDue(dueDate: nextMonthly)
        }
    }

    // MARK: - Chip Display Info
    static func scheduleChipInfo(for schedule: ScanSchedule) -> (label: String, isActive: Bool) {
        let df = DateFormatter()
        df.dateFormat = "dd MMM"

        switch schedule {

        case .firstScan:
            return ("Take Your First Scan", true)

        case .monthlyDue(let due):
            let dueStr = Calendar.current.isDateInToday(due)
                ? "Today"
                : df.string(from: due)
            return ("Monthly Scan · Due \(dueStr)", true)

        case .notDue(_, let days):
            return ("Next scan in \(days) day\(days == 1 ? "" : "s")", false)
        }
    }

    // MARK: - Next Scan Type Label 

    static func nextScanTypeLabel(for schedule: ScanSchedule) -> String {
        switch schedule {
        case .firstScan:          return "First Time Scan"
        case .monthlyDue:         return "Monthly Scan"
        case .notDue(_, let days): return "In \(days) day\(days == 1 ? "" : "s")"
        }
    }
}
