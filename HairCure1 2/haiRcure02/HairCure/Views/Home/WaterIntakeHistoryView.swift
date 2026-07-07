
import SwiftUI

struct WaterIntakeHistoryView: View {
    @Environment(AppDataStore.self) private var store
    
    private let blue = Color(red: 0.18, green: 0.52, blue: 0.92)
    
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
        .navigationTitle("Water Intake History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Apple Health badge removed
    
    // MARK: - Today summary card
    
    private var todaySummaryCard: some View {
        let totalML  = store.totalWaterML(for: Date())
        let goal     = store.dailyWaterGoalML
        let progress = goal > 0 ? min(Double(totalML / goal), 1.0) : 0
        let cups     = store.waterIntakeLogs(for: Date())
        
        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(blue.opacity(0.15), lineWidth: 10)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(blue)
                    Text("goal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's Intake")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Int(totalML))")
                        .font(.system(size: 28, weight: .bold))
                    Text("/ \(Int(goal)) ml")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    WaterChip(icon: "drop.fill",  label: "\(cups.count) cups",   color: blue)
                    let large = cups.filter { $0.cupSize == "large" }.count
                    if large > 0 {
                        WaterChip(icon: "arrow.up", label: "\(large) large", color: blue.opacity(0.75))
                    }
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
        let cal   = Calendar.current
        let goal  = Double(store.dailyWaterGoalML)
        
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
                        Text("Pick Date")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(blue.opacity(0.10))
                    .clipShape(Capsule())
                }
                .sheet(isPresented: $showDatePicker) {
                    DatePickerSheet(selectedDate: $selectedDate,
                                    accentColor: blue,
                                    isPresented: $showDatePicker)
                }
            }
            
            HStack(spacing: 0) {
                ForEach(ringDates, id: \.self) { date in
                    let isSelected = cal.startOfDay(for: selectedDate) == cal.startOfDay(for: date)
                    let totalML    = Double(store.totalWaterML(for: date))
                    let prog       = goal > 0 ? min(totalML / goal, 1.0) : 0
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
                                        isSelected ? blue.opacity(0.25) : Color.gray.opacity(0.15),
                                        lineWidth: isSelected ? 7 : 5
                                    )
                                    .frame(width: 58, height: 58)
                                if prog > 0 {
                                    Circle()
                                        .trim(from: 0, to: prog)
                                        .stroke(blue,
                                                style: StrokeStyle(lineWidth: isSelected ? 7 : 5,
                                                                   lineCap: .round))
                                        .frame(width: 58, height: 58)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut(duration: 0.4), value: prog)
                                }
                                if totalML > 0 {
                                    VStack(spacing: 0) {
                                        Text("\(Int(totalML))")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(isSelected ? blue : .primary)
                                        Text("ml")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Image(systemName: "drop")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                            
                            Text(dayLabel)
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? blue : .secondary)
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
        let logs     = store.waterIntakeLogs(for: selectedDate)
        let totalML  = store.totalWaterML(for: selectedDate)
        let goal     = store.dailyWaterGoalML
        let progress = goal > 0 ? min(Double(totalML / goal), 1.0) : 0.0
        let cal      = Calendar.current
        
        let titleLabel: String = {
            if cal.isDateInToday(selectedDate)     { return "Today" }
            if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
            let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
            return f.string(from: selectedDate)
        }()
        
        return VStack(alignment: .leading, spacing: 0) {
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleLabel)
                        .font(.system(size: 18, weight: .bold))
                    if totalML > 0 {
                        Text("\(Int(totalML)) ml · \(logs.count) cups · \(Int(progress * 100))% of goal")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No intake logged")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(blue.opacity(0.15), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    if progress > 0 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(blue)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, logs.isEmpty ? 16 : 10)
            
            if !logs.isEmpty {
                Divider().padding(.horizontal, 18)
                
                VStack(spacing: 0) {
                    ForEach(logs) { log in
                        WaterCupRow(log: log, blue: blue)
                        if log.id != logs.last?.id {
                            Divider()
                                .padding(.leading, 74)
                        }
                    }
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
}

// MARK: - Cup log row

private struct WaterCupRow: View {
    let log: WaterIntakeLog
    let blue: Color
    
    private var timeLabel: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: log.loggedAt)
    }
    private var cupIcon: String {
        switch log.cupSize {
        case "small": return "drop"
        case "large": return "drop.fill"
        default:      return "drop.halffull"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(blue.opacity(0.10))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: cupIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(blue)
                )
                .padding(.leading, 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(log.cupSize.capitalized) cup")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(timeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(log.cupSizeAmountInML)) ml")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(blue)
                .padding(.trailing, 18)
        }
        .padding(.vertical, 12)
    }
}

private struct WaterChip: View {
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
    NavigationStack { WaterIntakeHistoryView() }
        .environment(AppDataStore())
}
