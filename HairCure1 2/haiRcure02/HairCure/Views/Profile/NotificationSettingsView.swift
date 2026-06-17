
import SwiftUI

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {
    @Environment(AppDataStore.self) private var store
    
    private var settings: NotificationSettings? {
        store.notificationSettings.first(where: { $0.userId == store.currentUserId })
    }
    private var settingsIndex: Int? {
        store.notificationSettings.firstIndex(where: { $0.userId == store.currentUserId })
    }
    
    var body: some View {
        List {
            
            // ── Water Reminders ──
            Section {
                if let idx = settingsIndex {
                    Toggle(isOn: Bindable(store).notificationSettings[idx].waterReminderEnabled) {
                       
                            Text("Water Reminders")
                    }
                    .tint(Color.hcBrown)
                    .onChange(of: store.notificationSettings[idx].waterReminderEnabled) {
                        reschedule()
                    }
                    
                    if store.notificationSettings[idx].waterReminderEnabled {
                        Picker("Remind every", selection: Bindable(store).notificationSettings[idx].waterReminderIntervalHours) {
                            Text("1 hour").tag(1)
                            Text("2 hours").tag(2)
                            Text("3 hours").tag(3)
                            Text("4 hours").tag(4)
                        }
                        .onChange(of: store.notificationSettings[idx].waterReminderIntervalHours) {
                            reschedule()
                        }
                    }
                }
            } header: {
                Text("Hydration")
            }
            
            // ── Meal Reminders ──
            Section {
                if let idx = settingsIndex {
                    Toggle(isOn: Bindable(store).notificationSettings[idx].mealReminderEnabled) {
                        
                            Text("Meal Reminders")
                    }
                    .tint(Color.hcBrown)
                    .onChange(of: store.notificationSettings[idx].mealReminderEnabled) {
                        reschedule()
                    }
                    
                    if store.notificationSettings[idx].mealReminderEnabled {
                        mealTimeRow(label: "Breakfast", icon: "cup.and.saucer.fill",
                                    index: 0, settingsIdx: idx)
                        mealTimeRow(label: "Lunch", icon: "fork.knife",
                                    index: 1, settingsIdx: idx)
                        mealTimeRow(label: "Dinner", icon: "moon.fill",
                                    index: 2, settingsIdx: idx)
                    }
                }
            } header: {
                Text("Meals")
            }
            // ── Bedtime Reminder ──
            Section {
                if let idx = settingsIndex {
                    Toggle(isOn: Bindable(store).notificationSettings[idx].bedtimeReminderEnabled) {
                        
                            Text("Bedtime Reminder")
                    }
                    .tint(Color.hcBrown)
                    .onChange(of: store.notificationSettings[idx].bedtimeReminderEnabled) {
                        reschedule()
                    }
                    
                    if store.notificationSettings[idx].bedtimeReminderEnabled {
                        Picker("Remind me", selection: Bindable(store).notificationSettings[idx].bedtimeReminderMinutesBefore) {
                            Text("15 min before").tag(15)
                            Text("30 min before").tag(30)
                            Text("45 min before").tag(45)
                            Text("1 hour before").tag(60)
                        }
                        .onChange(of: store.notificationSettings[idx].bedtimeReminderMinutesBefore) {
                            reschedule()
                        }
                    }
                }
            } header: {
                Text("Sleep")
            }
            
            // ── Weekly Scan Reminder ──
            Section {
                if let idx = settingsIndex {
                    Toggle(isOn: Bindable(store).notificationSettings[idx].weeklyScanReminderEnabled) {
                            Text("Weekly Scan Reminder")
                    }
                    .tint(Color.hcBrown)
                    .onChange(of: store.notificationSettings[idx].weeklyScanReminderEnabled) {
                        reschedule()
                    }
                    
                    if store.notificationSettings[idx].weeklyScanReminderEnabled {
                        Picker("Day", selection: Bindable(store).notificationSettings[idx].weeklyScanReminderDay) {
                            Text("Monday").tag("monday")
                            Text("Tuesday").tag("tuesday")
                            Text("Wednesday").tag("wednesday")
                            Text("Thursday").tag("thursday")
                            Text("Friday").tag("friday")
                            Text("Saturday").tag("saturday")
                            Text("Sunday").tag("sunday")
                        }
                        .onChange(of: store.notificationSettings[idx].weeklyScanReminderDay) {
                            reschedule()
                        }
                        
                        Picker("Time", selection: Bindable(store).notificationSettings[idx].weeklyScanReminderTime) {
                            Text("8:00 AM").tag("08:00")
                            Text("9:00 AM").tag("09:00")
                            Text("10:00 AM").tag("10:00")
                            Text("11:00 AM").tag("11:00")
                            Text("12:00 PM").tag("12:00")
                            Text("6:00 PM").tag("18:00")
                            Text("8:00 PM").tag("20:00")
                        }
                        .onChange(of: store.notificationSettings[idx].weeklyScanReminderTime) {
                            reschedule()
                        }
                    }
                }
            } header: {
                Text("Scalp Scan")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.hcCream)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Meal Time Row
    
    @ViewBuilder
    private func mealTimeRow(label: String, icon: String, index: Int, settingsIdx: Int) -> some View {
        let times = store.notificationSettings[settingsIdx].mealReminderTimes
        if index < times.count {
            let currentTime = times[index]
            
            let binding = Binding<String>(
                get: { currentTime },
                set: { newValue in
                    store.notificationSettings[settingsIdx].mealReminderTimes[index] = newValue
                    reschedule()
                }
            )
            
            Picker(label, selection: binding) {
                Text("7:00 AM").tag("07:00")
                Text("8:00 AM").tag("08:00")
                Text("9:00 AM").tag("09:00")
                Text("12:00 PM").tag("12:00")
                Text("1:00 PM").tag("13:00")
                Text("2:00 PM").tag("14:00")
                Text("7:00 PM").tag("19:00")
                Text("8:00 PM").tag("20:00")
                Text("9:00 PM").tag("21:00")
            }
        }
    }
    
    // MARK: - Reschedule
    
    private func reschedule() {
        guard let s = settings else { return }
        NotificationManager.shared.reschedule(settings: s)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { NotificationSettingsView() }
        .environment(AppDataStore())
}
