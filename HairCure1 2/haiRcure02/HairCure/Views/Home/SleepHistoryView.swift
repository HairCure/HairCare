
import SwiftUI

struct SleepHistoryView: View {
    @Environment(AppDataStore.self) private var store
    
    private let teal          = Color(red: 0.28, green: 0.20, blue: 0.65)
    private let sleepGoal     = 8.0
    private var ringDates: [Date] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<4).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }
    
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showDatePicker      = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                todaySummaryCard
                    .padding(.horizontal, 20)
                    .scrollTransition(.animated.threshold(.visible(0.2))) { c, p in
                        c.opacity(p.isIdentity ? 1 : 0).scaleEffect(p.isIdentity ? 1 : 0.96)
                    }
                
                ringSelectorSection
                    .padding(.horizontal, 20)
                    .scrollTransition(.animated.threshold(.visible(0.2))) { c, p in
                        c.opacity(p.isIdentity ? 1 : 0.2).scaleEffect(p.isIdentity ? 1 : 0.95)
                    }
                
                selectedDayDetail
                    .padding(.horizontal, 20)
                    .scrollTransition(.animated.threshold(.visible(0.1))) { c, p in
                        c.opacity(p.isIdentity ? 1 : 0).offset(y: p.isIdentity ? 0 : 18)
                    }
                
                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.hcCream.ignoresSafeArea())
        .navigationTitle("Daily Sleep History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Apple Health badge removed
    
    // MARK: - Today summary card
    
    private var todaySummaryCard: some View {
        let record   = store.sleepRecord(for: Date())
        let hours    = Double(record?.hoursSlept ?? 0)
        let progress = min(hours / sleepGoal, 1.0)
        
        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(teal.opacity(0.15), lineWidth: 10)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(teal, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", hours))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(teal)
                    Text("hrs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Last Night's Sleep")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1fh", hours))
                        .font(.system(size: 28, weight: .bold))
                    Text("/ \(Int(sleepGoal))h goal")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                if let rec = record, rec.hoursSlept > 0 {
                    HStack(spacing: 6) {
                        SleepChip(icon: "moon.fill",  label: formatTime(rec.bedTime),  color: teal)
                        SleepChip(icon: "alarm.fill", label: formatTime(rec.wakeTime), color: teal.opacity(0.8))
                    }
                } else {
                    Text("No sleep data yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - 4-day tappable ring selector
    
    private var ringSelectorSection: some View {
        let cal = Calendar.current
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tap a day to view details")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(teal)
                    
                }
                .sheet(isPresented: $showDatePicker) {
                    DatePickerSheet(selectedDate: $selectedDate,
                                    accentColor: teal,
                                    isPresented: $showDatePicker)
                }
            }
            
            HStack(spacing: 0) {
                ForEach(ringDates, id: \.self) { date in
                    let isSelected = cal.startOfDay(for: selectedDate) == cal.startOfDay(for: date)
                    let rec        = store.sleepRecord(for: date)
                    let hours      = Double(rec?.hoursSlept ?? 0)
                    let prog       = min(hours / sleepGoal, 1.0)
                    let dayLabel   = shortDayLabel(date)
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = cal.startOfDay(for: date)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        isSelected ? teal.opacity(0.25) : Color.gray.opacity(0.15),
                                        lineWidth: isSelected ? 7 : 5
                                    )
                                    .frame(width: 58, height: 58)
                                if prog > 0 {
                                    Circle()
                                        .trim(from: 0, to: prog)
                                        .stroke(teal,
                                                style: StrokeStyle(lineWidth: isSelected ? 7 : 5,
                                                                   lineCap: .round))
                                        .frame(width: 58, height: 58)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut(duration: 0.4), value: prog)
                                }
                                if hours > 0 {
                                    VStack(spacing: 0) {
                                        Text(String(format: "%.1f", hours))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(isSelected ? teal : .primary)
                                        Text("h")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Image(systemName: "moon")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                            
                            Text(dayLabel)
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? teal : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }
    
    // MARK: - Selected day detail panel
    
    private var selectedDayDetail: some View {
        let record   = store.sleepRecord(for: selectedDate)
        let hours    = Double(record?.hoursSlept ?? 0)
        let progress = min(hours / sleepGoal, 1.0)
        let quality  = sleepQuality(hours: hours)
        let cal      = Calendar.current
        
        let titleLabel: String = {
            if cal.isDateInToday(selectedDate)     { return "Today" }
            if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
            let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
            return f.string(from: selectedDate)
        }()
        
        return VStack(alignment: .leading, spacing: 0) {
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleLabel)
                        .font(.system(size: 18, weight: .bold))
                    if hours > 0 {
                        HStack(spacing: 6) {
                            Text(String(format: "%.1fh slept", hours))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text(quality.text)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(quality.color)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(quality.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    } else {
                        Text("No sleep data")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(teal.opacity(0.15), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    if progress > 0 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(teal)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, record == nil || hours == 0 ? 16 : 10)
            
            if let rec = record, hours > 0 {
                Divider().padding(.horizontal, 18)
                
                VStack(spacing: 0) {
                    SleepDetailRow(icon: "moon.fill",  label: "Bed Time",  value: formatTime(rec.bedTime),          color: teal)
                    Divider().padding(.leading, 74)
                    SleepDetailRow(icon: "alarm.fill", label: "Wake Time", value: formatTime(rec.wakeTime),         color: teal)
                    Divider().padding(.leading, 74)
                    SleepDetailRow(icon: "clock.fill", label: "Duration",  value: durationLabel(rec.hoursSlept),    color: teal)
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedDate)
    }
    
    private func shortDayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
    
    private func durationLabel(_ hrs: Float) -> String {
        let m = Int((hrs * 60).rounded())
        return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
    }
    
    private func sleepQuality(hours: Double) -> (text: String, color: Color) {
        switch hours {
        case 0:     return ("No data",   .secondary)
        case ..<5:  return ("Poor",      Color(red: 0.90, green: 0.25, blue: 0.25))
        case ..<6:  return ("Short",     Color(red: 0.95, green: 0.55, blue: 0.15))
        case ..<7:  return ("Fair",      Color(red: 0.90, green: 0.78, blue: 0.10))
        case ..<8:  return ("Good",      Color(red: 0.25, green: 0.72, blue: 0.40))
        default:    return ("Excellent", teal)
        }
    }
}

// MARK: - Sleep detail row

private struct SleepDetailRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.10))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
                )
                .padding(.leading, 18)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .padding(.trailing, 18)
        }
        .padding(.vertical, 12)
    }
}

private struct SleepChip: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(color.opacity(0.12)).clipShape(Capsule())
    }
}

#Preview {
    NavigationStack { SleepHistoryView() }
        .environment(AppDataStore())
}
