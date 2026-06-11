import Foundation
import UIKit
import HealthKit
import Observation

@Observable
@MainActor
class HealthKitManager {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    // Retained so HealthKit doesn't drop the observers
    private var waterObserverQuery: HKObserverQuery?
    private var sleepObserverQuery: HKObserverQuery?

    // Published state — drives SwiftUI views
    var isAuthorized = false
    var todaysWaterML: Double = 0
    var lastNightSleepHours: Double = 0
    var lastSleepStart: Date? = nil
    var lastSleepEnd: Date? = nil
    var weeklySleepData: [(day: String, hours: Double)] = []
    var weeklyWaterData: [(day: String, totalML: Double)] = []
    /// Individual water entries logged today (fetched from HealthKit)
    var todaysWaterSamples: [WaterEntry] = []

    struct WaterEntry: Identifiable {
        let id: UUID
        let amountML: Double
        let loggedAt: Date
        let hkSample: HKQuantitySample
    }
    var canWriteWater: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
       
        return store.authorizationStatus(for: waterType) != .sharingDenied
    }

    private let waterType = HKQuantityType(.dietaryWater)
    private let sleepType = HKCategoryType(.sleepAnalysis)

    private init() {
       
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchWaterData()
            }
        }
    }

    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return
        }

        let readTypes: Set<HKObjectType> = [waterType, sleepType]
        let writeTypes: Set<HKSampleType> = [waterType]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            print("HealthKit authorization requested")

            // Fetch data immediately
            await fetchAll()

            // Start live observers (retained on self)
            startObservingWater()
            startObservingSleep()
            enableBackgroundDelivery()
        } catch {
            print("HealthKit authorization error: \(error)")
        }
    }

    // MARK: - Fetch Everything
    func fetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchTodaysWater() }
            group.addTask { await self.fetchTodaysWaterSamples() }
            group.addTask { await self.fetchWeeklyWater() }
            group.addTask { await self.fetchLastNightSleep() }
            group.addTask { await self.fetchWeeklySleep() }
        }
    }

    /// Convenience: re-fetch just the water data (used by observer + foreground refresh)
    func fetchWaterData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchTodaysWater() }
            group.addTask { await self.fetchTodaysWaterSamples() }
            group.addTask { await self.fetchWeeklyWater() }
        }
    }

    // MARK: - Refresh
    func refresh() async {
        await fetchAll()
    }

    // MARK: - Fetch Today's Water
    func fetchTodaysWater() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        let totalML = await fetchCumulativeSum(type: waterType, predicate: predicate, unit: .literUnit(with: .milli))
        self.todaysWaterML = totalML
        print("Today's water: \(Int(totalML)) ml")
    }

    // MARK: - Fetch Weekly Water
    func fetchWeeklyWater() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"

        var result: [(day: String, totalML: Double)] = []

        for daysAgo in (0..<7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let start = cal.startOfDay(for: date)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            let predicate = HKQuery.predicateForSamples(
                withStart: start, end: end, options: .strictStartDate
            )

            let totalML = await fetchCumulativeSum(type: waterType, predicate: predicate, unit: .literUnit(with: .milli))
            result.append((day: fmt.string(from: date), totalML: totalML))
        }

        self.weeklyWaterData = result
    }

    // MARK: - Fetch Today's Water Samples (individual entries)
    func fetchTodaysWaterSamples() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: now, options: .strictStartDate
        )

        let raw = await fetchSamples(type: waterType, predicate: predicate)
        let entries: [WaterEntry] = raw.compactMap { sample in
            guard let qty = sample as? HKQuantitySample else { return nil }
            let ml = qty.quantity.doubleValue(for: .literUnit(with: .milli))
            return WaterEntry(id: qty.uuid, amountML: ml, loggedAt: qty.startDate, hkSample: qty)
        }
        self.todaysWaterSamples = entries.sorted { $0.loggedAt > $1.loggedAt }
        print("Fetched \(entries.count) water entries for today")
    }

    // MARK: - Log Water to HealthKit
    /// Logs water and throws a typed error if the save fails.
    /// isLoggingWater guard removed — HealthKit assigns each save a unique UUID,
    /// so concurrent saves are safe and the old guard was causing silent failures.
    func logWater(amountML: Double) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HydrationError.healthKitUnavailable
        }
        guard canWriteWater else {
            throw HydrationError.writePermissionDenied
        }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountML)
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: Date(),
            end: Date()
        )

        do {
            try await store.save(sample)
            print("Logged \(Int(amountML)) ml to HealthKit")
            // Refresh immediately so UI reflects the save before the observer fires
            await fetchWaterData()
        } catch {
            print("Water log error: \(error)")
            throw HydrationError.saveFailed(error)
        }
    }

    enum HydrationError: LocalizedError {
        case healthKitUnavailable
        case writePermissionDenied
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .healthKitUnavailable:
                return "Apple Health is not available on this device."
            case .writePermissionDenied:
                return "HairCure doesn't have permission to write water data to Apple Health. Go to Settings → Health → HairCure → Data → turn on Dietary Water Write access."
            case .saveFailed(let err):
                return "Failed to save water entry: \(err.localizedDescription)"
            }
        }
    }

    // MARK: - Delete Water Entry
    func deleteWater(sample: HKSample) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await store.delete(sample)
            print("Water entry deleted")
            await fetchWaterData()
        } catch {
            print("Delete error: \(error)")
        }
    }

    // MARK: - Fetch Last Night's Sleep
    func fetchLastNightSleep() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let startOfYesterday = Calendar.current.startOfDay(for: yesterday)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday,
            end: now,
            options: .strictStartDate
        )

        let samples = await fetchSamples(type: sleepType, predicate: predicate)

        let sleepSamples = samples
            .compactMap { $0 as? HKCategorySample }
            .filter {
                $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }

        let totalHours = sleepSamples
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }

        let earliestStart = sleepSamples.map(\.startDate).min()
        let latestEnd = sleepSamples.map(\.endDate).max()

        self.lastNightSleepHours = totalHours
        self.lastSleepStart = earliestStart
        self.lastSleepEnd = latestEnd
        print("Last night sleep: \(String(format: "%.1f", totalHours)) hours")
    }

    // MARK: - Fetch Weekly Sleep
    func fetchWeeklySleep() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"

        var result: [(day: String, hours: Double)] = []

        for daysAgo in (0..<7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let start = cal.startOfDay(for: date)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            let predicate = HKQuery.predicateForSamples(
                withStart: start, end: end, options: .strictStartDate
            )

            let samples = await fetchSamples(type: sleepType, predicate: predicate)

            let hours = samples
                .compactMap { $0 as? HKCategorySample }
                .filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }

            result.append((day: fmt.string(from: date), hours: hours))
        }

        self.weeklySleepData = result
    }

    // MARK: - Generic Helpers

    /// Fetches cumulative sum for a quantity type using async/await safe pattern
    private nonisolated func fetchCumulativeSum(
        type: HKQuantityType,
        predicate: NSPredicate,
        unit: HKUnit
    ) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    print("Stats query error: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                let total = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: total)
            }
            self.store.execute(query)
        }
    }

    /// Fetches samples for a given type using async/await safe pattern
    private nonisolated func fetchSamples(
        type: HKSampleType,
        predicate: NSPredicate
    ) async -> [HKSample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(
                    key: HKSampleSortIdentifierStartDate,
                    ascending: false
                )]
            ) { _, samples, error in
                if let error = error {
                    print("Sample query error: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: samples ?? [])
            }
            self.store.execute(query)
        }
    }

    // MARK: - Start Observing Water Changes
    private nonisolated func startObservingWater() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let query = HKObserverQuery(sampleType: waterType, predicate: nil) {
            [weak self] _, completionHandler, error in
            // Call completionHandler promptly so HealthKit keeps delivering
            defer { completionHandler() }

            guard let self = self, error == nil else {
                if let error = error { print("Water observer error: \(error)") }
                return
            }

            Task { @MainActor [weak self] in
                // Short delay: external HealthKit writes (e.g. from Health app) may not be
                // immediately visible in the store when the observer fires. Waiting 0.8 s
                // gives HealthKit time to commit the write before we query.
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 s
                await self?.fetchWaterData()
                print("Water data refreshed via observer (first pass)")

                // Second fetch 3 s later as a safety net for slow commits
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 s
                await self?.fetchWaterData()
                print("Water data refreshed via observer (safety pass)")
            }
        }

        store.execute(query)

        // Retain the query so ARC doesn't drop it
        Task { @MainActor [weak self] in
            self?.waterObserverQuery = query
        }
    }


    // MARK: - Start Observing Sleep Changes
    private nonisolated func startObservingSleep() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) {
            [weak self] _, completionHandler, error in
            defer { completionHandler() }

            guard let self = self, error == nil else { return }

            Task { @MainActor [weak self] in
                await self?.fetchLastNightSleep()
                await self?.fetchWeeklySleep()
                print("Sleep data refreshed via observer")
            }
        }

        store.execute(query)

        Task { @MainActor [weak self] in
            self?.sleepObserverQuery = query
        }
    }

    // MARK: - Enable Background Delivery
    private nonisolated func enableBackgroundDelivery() {
        store.enableBackgroundDelivery(for: waterType, frequency: .immediate) { success, error in
            if success {
                print("Background delivery enabled for water")
            } else {
                print("Background delivery error (water): \(error?.localizedDescription ?? "unknown")")
            }
        }
        store.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
            if success {
                print("Background delivery enabled for sleep")
            } else {
                print("Background delivery error (sleep): \(error?.localizedDescription ?? "unknown")")
            }
        }
    }
}
