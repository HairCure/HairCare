//
//  NotificationManager.swift
//  HairCure
//
//  Schedules and manages iOS local notifications for water, meals, bedtime,
//  and weekly scan reminders using UNUserNotificationCenter.
//

import Foundation
import UserNotifications

@Observable
final class NotificationManager {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // Identifier prefixes for each category
    private enum Prefix {
        static let water   = "hc.water."
        static let meal    = "hc.meal."
        static let bedtime = "hc.bedtime."
        static let scan    = "hc.scan."
    }

    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print(granted ? "Notifications authorized" : "Notifications denied")
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    var isAuthorized: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Reschedule All

    /// Cancels all existing HairCure notifications and reschedules based on current settings.
    func reschedule(settings: NotificationSettings) {
        // Cancel everything first
        center.removeAllPendingNotificationRequests()

        // Schedule each enabled category
        if settings.waterReminderEnabled {
            scheduleWaterReminders(intervalHours: settings.waterReminderIntervalHours)
        }
        if settings.mealReminderEnabled {
            scheduleMealReminders(times: settings.mealReminderTimes)
        }
        if settings.bedtimeReminderEnabled {
            scheduleBedtimeReminder(minutesBefore: settings.bedtimeReminderMinutesBefore)
        }
        if settings.weeklyScanReminderEnabled {
            scheduleWeeklyScanReminder(day: settings.weeklyScanReminderDay,
                                       time: settings.weeklyScanReminderTime)
        }
    }

    // MARK: - Water Reminders

    /// Schedules repeating water reminders every `intervalHours` between 8 AM and 10 PM.
    private func scheduleWaterReminders(intervalHours: Int) {
        let interval = max(intervalHours, 1)
        let startHour = 8
        let endHour   = 22

        let messages = [
            "Time to hydrate! Drink a glass of water.",
            "Stay hydrated! Your hair needs water too.",
            "Water break! Keep sipping to reach your goal.",
            "Hydration check! Have you had water recently?"
        ]

        var index = 0
        var hour = startHour
        while hour <= endHour {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Water Reminder"
            content.body = messages[index % messages.count]
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(Prefix.water)\(hour)",
                content: content,
                trigger: trigger
            )
            center.add(request)

            hour += interval
            index += 1
        }
    }

    // MARK: - Meal Reminders

    /// Schedules meal reminders at specific times like ["08:00", "13:00", "20:00"].
    private func scheduleMealReminders(times: [String]) {
        let mealNames = ["Breakfast", "Lunch", "Dinner"]
        let mealIcons = ["sun.max.fill", "fork.knife", "moon.fill"]

        for (i, timeString) in times.enumerated() {
            let parts = timeString.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { continue }

            var dateComponents = DateComponents()
            dateComponents.hour = parts[0]
            dateComponents.minute = parts[1]

            let name = i < mealNames.count ? mealNames[i] : "Meal"
            let icon = i < mealIcons.count ? mealIcons[i] : "fork.knife"

            let content = UNMutableNotificationContent()
            content.title = "\(name) Time \(icon)"
            content.body = "Time to log your \(name.lowercased()). Stay on track with your nutrition goals!"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(Prefix.meal)\(i)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Bedtime Reminder

    /// Schedules a bedtime reminder X minutes before 10:30 PM (default bedtime).
    private func scheduleBedtimeReminder(minutesBefore: Int) {
        // Default bedtime: 22:30 (10:30 PM)
        let bedtimeHour = 22
        let bedtimeMinute = 30

        let totalMinutes = (bedtimeHour * 60 + bedtimeMinute) - minutesBefore
        let reminderHour = totalMinutes / 60
        let reminderMinute = totalMinutes % 60

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let content = UNMutableNotificationContent()
        content.title = "Bedtime Soon"
        content.body = "Wind down — your bedtime is in \(minutesBefore) minutes. Good sleep helps hair health!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(Prefix.bedtime)daily",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Weekly Scan Reminder

    /// Schedules a weekly scan reminder on a given day at a given time.
    private func scheduleWeeklyScanReminder(day: String, time: String) {
        let weekdayMap: [String: Int] = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        guard let weekday = weekdayMap[day.lowercased()] else { return }

        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = parts[0]
        dateComponents.minute = parts[1]

        let content = UNMutableNotificationContent()
        content.title = "Weekly Scalp Scan"
        content.body = "Time for your weekly scan! Track your hair progress and stay consistent."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(Prefix.scan)weekly",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Cancel All

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
