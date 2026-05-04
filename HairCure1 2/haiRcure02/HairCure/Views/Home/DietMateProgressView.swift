import SwiftUI

// MARK: - DietMateProgressView  (nutrient-focused redesign)

struct DietMateProgressView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(DietmateDataStore.self) private var dietMateStore

    private let green = Color.green

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
                    .padding(.horizontal, 20).padding(.top, 4)
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
        .navigationTitle("Diet Mate Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Today summary card  (nutrient ring)

    private var todaySummaryCard: some View {
        let progress    = dietMateStore.hairNutrientProgress(for: Date())
        let covered     = dietMateStore.hairNutrientsCovered(for: Date())
        let totalCal    = dietMateStore.totalCalories(for: Date())
        let entries     = dietMateStore.mealEntries(for: Date())
        let totalP      = entries.reduce(0) { $0 + $1.proteinConsumed }
        let totalC      = entries.reduce(0) { $0 + $1.carbsConsumed  }
        let totalF      = entries.reduce(0) { $0 + $1.fatConsumed    }

        return HStack(spacing: 20) {
            ZStack {
                Circle().stroke(green.opacity(0.15), lineWidth: 10).frame(width: 80, height: 80)
                Circle().trim(from: 0, to: progress)
                    .stroke(green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 80, height: 80).rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                VStack(spacing: 0) {
                    Text("\(covered.count)/5")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(green)
                    Text("nutrients").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Today's Nutrients")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                NutrientPillRow(coveredNames: covered, size: 9)
                if totalCal > 0 {
                    Text("~\(Int(totalCal)) kcal   |   P \(Int(totalP))g · C \(Int(totalC))g · F \(Int(totalF))g")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - 4-day ring selector  (nutrient progress)

    private var ringSelectorSection: some View {
        let cal = Calendar.current
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tap a day to view details")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Button { showDatePicker = true } label: {
                    Image(systemName: "calendar").font(.system(size: 18, weight: .semibold)).foregroundStyle(green)
                }
                .sheet(isPresented: $showDatePicker) {
                    DatePickerSheet(selectedDate: $selectedDate, accentColor: green, isPresented: $showDatePicker)
                }
            }

            HStack(spacing: 0) {
                ForEach(ringDates, id: \.self) { date in
                    let isSelected = cal.startOfDay(for: selectedDate) == cal.startOfDay(for: date)
                    let prog       = dietMateStore.hairNutrientProgress(for: date)
                    let covered    = dietMateStore.hairNutrientsCovered(for: date).count
                    let ringColor: Color = prog >= 0.8 ? green : (prog > 0 ? .orange : Color.gray.opacity(0.3))

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = cal.startOfDay(for: date)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().stroke(isSelected ? ringColor.opacity(0.25) : Color.gray.opacity(0.15),
                                                lineWidth: isSelected ? 7 : 5).frame(width: 58, height: 58)
                                if prog > 0 {
                                    Circle().trim(from: 0, to: prog)
                                        .stroke(ringColor, style: StrokeStyle(lineWidth: isSelected ? 7 : 5, lineCap: .round))
                                        .frame(width: 58, height: 58).rotationEffect(.degrees(-90))
                                        .animation(.easeInOut(duration: 0.4), value: prog)
                                }
                                VStack(spacing: 0) {
                                    Text(covered > 0 ? "\(covered)/5" : "–")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(isSelected ? ringColor : .secondary)
                                    Text("nutrients").font(.system(size: 7)).foregroundStyle(.secondary)
                                }
                            }
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                            Text(shortDayLabel(date))
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? ringColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12).padding(.horizontal, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Selected day detail

    private var selectedDayDetail: some View {
        let entries  = dietMateStore.mealEntries(for: selectedDate)
                           .sorted { $0.mealType.displayOrder < $1.mealType.displayOrder }
        let covered  = dietMateStore.hairNutrientsCovered(for: selectedDate)
        let progress = dietMateStore.hairNutrientProgress(for: selectedDate)
        let ringColor: Color = progress >= 0.8 ? green : (progress > 0 ? .orange : .gray)
        let cal = Calendar.current

        let titleLabel: String = {
            if cal.isDateInToday(selectedDate)     { return "Today" }
            if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
            let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
            return f.string(from: selectedDate)
        }()

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleLabel).font(.system(size: 18, weight: .bold))
                    if covered.isEmpty {
                        Text("No meals logged").font(.system(size: 13)).foregroundStyle(.secondary)
                    } else {
                        Text("\(covered.count)/5 hair nutrients covered")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(ringColor.opacity(0.15), lineWidth: 4).frame(width: 40, height: 40)
                    if progress > 0 {
                        Circle().trim(from: 0, to: progress)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 40, height: 40).rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                    Image(systemName: "leaf.fill").font(.system(size: 11)).foregroundStyle(ringColor)
                }
            }
            .padding(.horizontal, 18).padding(.top, 16)
            .padding(.bottom, covered.isEmpty ? 16 : 10)

            if !covered.isEmpty {
                NutrientPillRow(coveredNames: covered, size: 10).padding(.horizontal, 18).padding(.bottom, 12)
            }

            if !entries.isEmpty {
                Divider().padding(.horizontal, 18)
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        let entryNutrients = dietMateStore.hairNutrientsCoveredInEntry(entry.id)
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(entry.mealType.accentColor.opacity(0.12)).frame(width: 40, height: 40)
                                .overlay(Circle().fill(entry.mealType.accentColor).frame(width: 10, height: 10))
                                .padding(.leading, 18)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.mealType.displayName)
                                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                                if entryNutrients.isEmpty {
                                    Text("No nutrients tracked").font(.system(size: 11)).foregroundStyle(.secondary)
                                } else {
                                    HStack(spacing: 3) {
                                        ForEach(0..<kNutrientPills.count, id: \.self) { i in
                                            let pill = kNutrientPills[i]
                                            if entryNutrients.contains(pill.name) {
                                                Circle().fill(pill.color).frame(width: 6, height: 6)
                                            }
                                        }
                                        Text(entryNutrients.joined(separator: " · "))
                                            .font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            if entry.caloriesConsumed > 0 {
                                Text("~\(Int(entry.caloriesConsumed)) kcal")
                                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(.trailing, 18)
                            } else {
                                Text("—").font(.system(size: 14))
                                    .foregroundStyle(Color(UIColor.tertiaryLabel)).padding(.trailing, 18)
                            }
                        }
                        .padding(.vertical, 12)
                        if entry.id != entries.last?.id { Divider().padding(.leading, 74) }
                    }
                }
                .padding(.bottom, 8)

                // Macro summary
                let totalP = entries.reduce(0) { $0 + $1.proteinConsumed }
                let totalC = entries.reduce(0) { $0 + $1.carbsConsumed }
                let totalF = entries.reduce(0) { $0 + $1.fatConsumed }
                if totalP + totalC + totalF > 0 {
                    Divider().padding(.horizontal, 18)
                    HStack(spacing: 12) {
                        MacroChip(label: "P", value: "\(Int(totalP))g", color: .orange)
                        MacroChip(label: "C", value: "\(Int(totalC))g", color: .blue)
                        MacroChip(label: "F", value: "\(Int(totalF))g", color: .purple)
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                }
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

// MARK: - MacroChip

private struct MacroChip: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(color.opacity(0.12)).clipShape(Capsule())
    }
}
