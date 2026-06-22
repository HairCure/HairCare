
import SwiftUI

extension MealType {
    var accentColor: Color {
        switch self {
        case .breakfast: return Color(red: 1.00, green: 0.60, blue: 0.20)
        case .lunch:     return Color(red: 0.20, green: 0.75, blue: 0.35)
        case .snack:     return Color(red: 0.60, green: 0.35, blue: 0.90)
        case .dinner:    return Color(red: 0.20, green: 0.50, blue: 0.95)
        }
    }
}

// MARK: - Nutrient pill labels

let kNutrientPills: [(name: String, color: Color)] = [
    ("Biotin",    Color(red: 0.25, green: 0.70, blue: 0.40)),
    ("Zinc",      Color(red: 0.15, green: 0.55, blue: 0.95)),
    ("Iron",      Color(red: 0.85, green: 0.30, blue: 0.25)),
    ("Omega-3",   Color(red: 0.10, green: 0.65, blue: 0.80)),
    ("Vitamin A", Color(red: 0.95, green: 0.65, blue: 0.10)),
]

// kcal targets per meal type (for the progress bar)
private let kMealKcalTarget: [MealType: Float] = [
    .breakfast: 450,
    .lunch:     630,
    .snack:     360,
    .dinner:    360,
]

// MARK: - CalorieProgressBar (kept for thin secondary bars if ever needed)

private struct CalorieProgressBar: View {
    let consumed: Float; let target: Float; let color: Color; let height: CGFloat
    var body: some View {
        GeometryReader { geo in
            let fraction = min(CGFloat(consumed / max(target, 1)), 1.0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2).fill(Color.gray.opacity(0.15)).frame(height: height)
                RoundedRectangle(cornerRadius: height / 2).fill(color)
                    .frame(width: geo.size.width * fraction, height: height)
                    .animation(.easeOut(duration: 0.4), value: fraction)
            }
        }.frame(height: height)
    }
}

// MARK: - Nutrient Pill Row

struct NutrientPillRow: View {
    let coveredNames: [String]
    let size: CGFloat        // font size scaling

    var body: some View {
        HStack(spacing: 4) {
            ForEach(kNutrientPills, id: \.name) { pill in
                let covered = coveredNames.contains(pill.name)
                Text(pill.name)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(covered ? .white : pill.color)
                    .padding(.horizontal, size * 0.8).padding(.vertical, size * 0.4)
                    .background(covered ? pill.color : pill.color.opacity(0.12))
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.25), value: covered)
            }
        }
    }
}

// MARK: - MacroRow

private struct MacroRow: View {
    let color: Color; let label: String; let fraction: Double; let showBar: Bool
    init(color: Color, label: String, fraction: Double = 0, showBar: Bool = true) {
        self.color = color; self.label = label
        self.fraction = fraction; self.showBar = showBar
    }
    var body: some View {
        if showBar {
            HStack(spacing: 0) {
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.18)).frame(height: 34)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.75))
                            .frame(width: geo.size.width * min(fraction, 1.0), height: 34)
                            .animation(.easeOut(duration: 0.5), value: fraction)
                    }.frame(height: 34)
                    Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.black.opacity(0.75))
                        .padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.frame(height: 34).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(label).font(.system(size: 15))
            }
        }
    }
}

// MARK: - FoodImageView

private struct FoodImageView: View {
    let food: Food; let tint: Color; let height: CGFloat; let width: CGFloat?; let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if let urlStr = food.imageURL, !urlStr.isEmpty {
                if urlStr.hasPrefix("http://") || urlStr.hasPrefix("https://") {
                    // ── Remote URL from backend ──
                    AsyncImage(url: URL(string: urlStr)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholder
                        case .empty:
                            placeholder.overlay(ProgressView().tint(tint))
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    // ── Local asset name ──
                    Image(urlStr).resizable().aspectRatio(contentMode: .fill)
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        ZStack {
            tint.opacity(0.12)
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: height * 0.4))
                .foregroundStyle(tint.opacity(0.5))
        }
    }
}


// MARK: - DietMateView

struct DietMateView: View {
    @Environment(AppDataStore.self)      private var store
    @Environment(DietmateDataStore.self) private var dietMateStore
    @Environment(AuthViewModel.self)     private var authVM

    let onGuestTap: () -> Void

    @State private var selectedDate  = Calendar.current.startOfDay(for: Date())
    @State private var showCalendar  = false
    @State private var pushMealId:   UUID? = nil
    @State private var selectedFood: Food? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                DateHeader(selectedDate: selectedDate) { showCalendar = true }
                WeekRingStrip(selectedDate: $selectedDate, store: dietMateStore)
                SectionHeading(selectedDate: selectedDate) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedDate = Calendar.current.startOfDay(for: Date())
                    }
                }
                // Loading / error states
                if dietMateStore.isLoadingFoods {
                    HStack {
                        ProgressView().tint(.green)
                        Text("Loading meals…").font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                } else if let err = dietMateStore.foodLoadError {
                    Text(err).font(.system(size: 14)).foregroundStyle(.red).padding(.horizontal, 20)
                }
                MealListSection(
                    selectedDate: selectedDate, store: dietMateStore,
                    isGuest: authVM.isGuestMode,
                    onAdd: { pushMealId = $0 },
                    onFoodTap: { selectedFood = $0 },
                    onGuestTap: onGuestTap
                )
                Spacer(minLength: 24)
            }
            .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sheet(isPresented: $showCalendar) { CalendarSheet(selectedDate: $selectedDate, show: $showCalendar) }
        .navigationDestination(item: $pushMealId) { AddMealView(mealEntryId: $0) }
        .sheet(item: $selectedFood)               { FoodDetailView(food: $0) }
    }
}

// MARK: - DateHeader

private struct DateHeader: View {
    let selectedDate: Date; let onCalendarTap: () -> Void
    var body: some View {
        HStack {
            Text(selectedDate.dietMateDateTitle)
                .font(.system(size: 20, weight: .bold))
                .animation(.easeInOut(duration: 0.2), value: selectedDate)
            Spacer()
            Button(action: onCalendarTap) {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .medium)).foregroundStyle(.green)
                    .padding(8).background(Color.green.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - CalendarSheet

private struct CalendarSheet: View {
    @Binding var selectedDate: Date; @Binding var show: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { show = false } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).padding(10) }
                Spacer()
                Text("Pick a Date").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Today") { withAnimation { selectedDate = Calendar.current.startOfDay(for: Date()) }; show = false }.padding(10)
            }
            .padding(.horizontal, 4).padding(.top, 8)
            Divider()
            DatePicker("", selection: Binding(get: { selectedDate }, set: { v in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedDate = Calendar.current.startOfDay(for: v) }
                show = false
            }), in: ...Date(), displayedComponents: .date)
            .datePickerStyle(.graphical).labelsHidden().padding(.horizontal, 16)
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

// MARK: - WeekRingStrip

private struct WeekRingStrip: View {
    @Binding var selectedDate: Date; let store: DietmateDataStore
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(store.currentWeekDates().enumerated()), id: \.offset) { _, date in
                WeekDayCell(date: date, selectedDate: $selectedDate, store: store)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - WeekDayCell  (rings show MEAL completion: each meal with food = 25%)

private struct WeekDayCell: View {
    let date: Date; @Binding var selectedDate: Date; let store: DietmateDataStore
    private let letters = ["S","M","T","W","T","F","S"]

    var body: some View {
        let cal        = Calendar.current
        let today      = cal.startOfDay(for: Date())
        let dayStart   = cal.startOfDay(for: date)
        let isToday    = dayStart == today
        let isSelected = dayStart == cal.startOfDay(for: selectedDate)
        let isFuture   = dayStart > today
        let idx        = cal.component(.weekday, from: date) - 1

        // Count how many meal slots have at least one food added
        let done       = isFuture ? 0 : store.mealsWithFoodCount(for: date)
        let progress   = isFuture ? 0.0 : min(Double(done) / 4.0, 1.0)
        let ringColor: Color = done > 0 ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color.gray.opacity(0.3)

        VStack(spacing: 6) {
            ZStack {
                if isToday { Circle().fill(Color.green).frame(width: 28, height: 28) }
                Text(letters[idx])
                    .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? .white : (isSelected ? .primary : .secondary))
            }
            .frame(width: 28, height: 28)

            ZStack {
                Circle().stroke(Color.gray.opacity(0.18), lineWidth: 4)
                if progress > 0 {
                    Circle().trim(from: 0, to: CGFloat(progress))
                        .stroke(ringColor,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
                if isSelected && !isToday {
                    Circle().fill(Color.hcBrown).frame(width: 6, height: 6)
                }
            }
            .frame(width: 32, height: 32)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFuture else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDate = dayStart }
        }
    }
}

// MARK: - SectionHeading

private struct SectionHeading: View {
    let selectedDate: Date; let onBackToToday: () -> Void
    var body: some View {
        HStack {
            Text(selectedDate.isToday ? "Daily Meals" : "\(selectedDate.formatted(.dateTime.day().month())) (Meals)")
                .font(.system(size: 22, weight: .bold))
                .animation(.easeInOut(duration: 0.2), value: selectedDate)
            Spacer()
            if !selectedDate.isToday {
                Button(action: onBackToToday) {
                    Label("Today", systemImage: "arrow.uturn.left")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.hcBrown).clipShape(Capsule())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - MealListSection

private struct MealListSection: View {
    let selectedDate: Date; let store: DietmateDataStore
    let isGuest: Bool
    let onAdd: (UUID) -> Void; let onFoodTap: (Food) -> Void
    let onGuestTap: () -> Void

    var body: some View {
        let entries = store.mealEntries(for: selectedDate)
        let isPast  = !selectedDate.isToday

        VStack(spacing: 14) {
            if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle").font(.system(size: 44)).foregroundStyle(.secondary.opacity(0.5))
                    Text("No meal data for this day").font(.system(size: 16)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ForEach(entries) { entry in
                    MealCard(
                        entry: entry, isPast: isPast, isGuest: isGuest,
                        onAdd: { onAdd(entry.id) },
                        onFoodTap: onFoodTap,
                        onGuestTap: onGuestTap
                    )
                    .scrollTransition(.animated.threshold(.visible(0.1))) { content, phase in
                        content.opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                            .offset(y: phase.isIdentity ? 0 : 24)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .id(selectedDate)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - MealCard

private struct MealCard: View {
    @Environment(DietmateDataStore.self) private var store
    let entry: MealEntry; let isPast: Bool; let isGuest: Bool
    let onAdd: () -> Void; let onFoodTap: (Food) -> Void
    let onGuestTap: () -> Void

    var body: some View {
        let loggedFoods = store.linkedFoods(for: entry.id)
        let consumed    = entry.caloriesConsumed
        let target      = kMealKcalTarget[entry.mealType] ?? 400
        let fraction    = min(CGFloat(consumed / max(target, 1)), 1.0)
        let accentColor = entry.mealType.accentColor
        let hasFoods    = !loggedFoods.isEmpty

        VStack(alignment: .leading, spacing: 10) {
            // ── Header row ──
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.mealType.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(hasFoods ? accentColor : .primary)
                    Text(entry.mealType.recommendedPortionText)
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                if hasFoods {
                    Button(action: isGuest ? onGuestTap : onAdd) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18))
                            .foregroundStyle(accentColor)
                    }
                } else if isPast {
                    Image(systemName: "minus.circle").foregroundStyle(.secondary.opacity(0.4))
                }
            }

            if hasFoods {
                // ── Big calorie number ──
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 32, weight: .bold))
                    Text(" /\(Int(target)) kcal")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                }

                // ── Thick progress bar ──
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor.opacity(0.18))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: geo.size.width * fraction, height: 8)
                            .animation(.easeOut(duration: 0.4), value: fraction)
                    }
                }
                .frame(height: 8)

                // ── Food rows ──
                MealFoodList(foods: loggedFoods, accentColor: accentColor, onTap: onFoodTap)

            } else if !isPast {
                // ── Add button ──
                Button(action: isGuest ? onGuestTap : onAdd) {
                    Text("Add \(entry.mealType.displayName)")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.hcBrown).cornerRadius(12)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .overlay {
            if hasFoods {
                RoundedRectangle(cornerRadius: 16).stroke(accentColor, lineWidth: 1.5)
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - MealFoodList

private struct MealFoodList: View {
    let foods: [(mealFood: MealFood, food: Food)]; let accentColor: Color; let onTap: (Food) -> Void
    var body: some View {
        VStack(spacing: 0) {
            ForEach(foods, id: \.mealFood.id) { pair in
                Button { onTap(pair.food) } label: {
                    HStack(spacing: 8) {
                        Circle().fill(accentColor).frame(width: 8, height: 8)
                        Text(pair.food.name)
                            .font(.system(size: 14)).foregroundStyle(.primary).lineLimit(1)
                        if pair.mealFood.quantity > 1 {
                            Text("×\(Int(pair.mealFood.quantity))")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let kcal = Int(pair.food.averageCalories * pair.mealFood.quantity)
                        if kcal > 0 {
                            Text("\(kcal) kcal")
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                if pair.mealFood.id != foods.last?.mealFood.id {
                    Divider().padding(.leading, 18)
                }
            }
        }
    }
}

// MARK: - AddMealView

struct AddMealView: View {
    @Environment(AppDataStore.self)      private var store
    @Environment(DietmateDataStore.self) private var dietMateStore
    @Environment(\.dismiss)             private var dismiss

    let mealEntryId: UUID

    @State private var searchText    = ""
    @State private var selectedFood: Food? = nil
    @State private var showCustomFoodSheet = false
    @State private var vegFilter: DietmateDataStore.VegFilter = .all
    @State private var selectedNutrients: Set<String> = []

    var body: some View {
        let entry     = dietMateStore.mealEntry(id: mealEntryId)
        let mealColor = entry?.mealType.accentColor ?? .hcBrown

        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(.primary)
                        .frame(width: 36, height: 36).background(Color.white.opacity(0.8)).clipShape(Circle())
                }
                Spacer()
                Text(entry?.mealType.displayName ?? "Meal").font(.system(size: 20, weight: .semibold))
                Spacer()
                UnifiedFilterMenu(vegFilter: $vegFilter, selectedNutrients: $selectedNutrients)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.hcCream)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    SearchBar(text: $searchText, themeColor: mealColor)

                    // Hair Nutrient Coverage Panel
                    if let e = entry {
                        HairNutrientCoveragePanel(mealEntryId: e.id, store: dietMateStore)
                    }

                    // Calorie info — secondary
                    if let e = entry, e.caloriesConsumed > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange).font(.system(size: 13))
                            Text("~\(Int(e.caloriesConsumed)) kcal in this meal")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }

                    let addedFoods = dietMateStore.linkedFoods(for: mealEntryId)
                    if !addedFoods.isEmpty {
                        AddedFoodsSection(addedFoods: addedFoods, mealColor: mealColor,
                                          mealEntryId: mealEntryId, store: dietMateStore)
                    }

                    SuggestedSection(
                        foods:       dietMateStore.suggestedFoods(for: entry?.mealType ?? .breakfast, searchText: searchText, vegFilter: vegFilter, nutrientFilter: selectedNutrients),
                        mealColor:   mealColor,
                        showHeading: searchText.isEmpty,
                        onAdd:       { dietMateStore.addOrIncrementFood($0, to: mealEntryId) },
                        onTap:       { selectedFood = $0 },
                        onCustomAdd: !searchText.isEmpty ? { showCustomFoodSheet = true } : nil
                    )

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20).padding(.top, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.hcCream.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $selectedFood) { FoodDetailView(food: $0) }
        .sheet(isPresented: $showCustomFoodSheet) {
            if let entry = entry {
                CustomFoodSheet(
                    initialSearchText: searchText,
                    mealType: entry.mealType,
                    onSave: { newFood in
                        dietMateStore.foods.append(newFood)
                        dietMateStore.addOrIncrementFood(newFood, to: mealEntryId)
                        searchText = ""
                    }
                )
            }
        }
    }
}

// MARK: - Hair Nutrient Coverage Panel

private struct HairNutrientCoveragePanel: View {
    let mealEntryId: UUID; let store: DietmateDataStore
    var body: some View {
        let covered = store.hairNutrientsCoveredInEntry(mealEntryId)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "leaf.fill").foregroundStyle(.green).font(.system(size: 14))
                Text("Hair Nutrients Covered").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(covered.count)/5")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(covered.count >= 4 ? .green : (covered.count >= 2 ? .orange : .secondary))
            }
            NutrientPillRow(coveredNames: covered, size: 11)
        }
        .padding(14)
        .background(Color.green.opacity(0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.2), lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: covered.count)
    }
}

// MARK: - UnifiedFilterMenu

private struct UnifiedFilterMenu: View {
    @Binding var vegFilter: DietmateDataStore.VegFilter
    @Binding var selectedNutrients: Set<String>
    let nutrients = ["Biotin", "Zinc", "Iron", "Omega-3", "Vitamin A"]

    var body: some View {
        Menu {
            Section("Dietary Preference") {
                Picker("Diet", selection: $vegFilter) {
                    Text("All").tag(DietmateDataStore.VegFilter.all)
                    Text("Veg").tag(DietmateDataStore.VegFilter.vegOnly)
                    Text("Non-Veg").tag(DietmateDataStore.VegFilter.nonVegOnly)
                }
            }
            
            Section("Hair Nutrients") {
                ForEach(nutrients, id: \.self) { nutrient in
                    Button {
                        if selectedNutrients.contains(nutrient) {
                            selectedNutrients.remove(nutrient)
                        } else {
                            selectedNutrients.insert(nutrient)
                        }
                    } label: {
                        if selectedNutrients.contains(nutrient) {
                            Label(nutrient, systemImage: "checkmark")
                        } else {
                            Text(nutrient)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.hcBrown)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                        .opacity((!selectedNutrients.isEmpty || vegFilter != .all) ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: !selectedNutrients.isEmpty || vegFilter != .all)
                }
        }
    }
}

// MARK: - SearchBar

private struct SearchBar: View {
    @Binding var text: String
    var themeColor: Color = .hcBrown
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(themeColor)
            TextField("Search for a meal", text: $text).font(.system(size: 16))
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(themeColor.opacity(0.6)) }
            } else {
                Image(systemName: "mic.fill").foregroundStyle(themeColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(themeColor.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - AddedFoodsSection

private struct AddedFoodsSection: View {
    let addedFoods: [(mealFood: MealFood, food: Food)]
    let mealColor: Color; let mealEntryId: UUID; let store: DietmateDataStore

    var body: some View {
        VStack(spacing: 10) {
            ForEach(addedFoods, id: \.mealFood.id) { pair in
                HStack(spacing: 12) {
                    FoodImageView(food: pair.food, tint: mealColor, height: 60, width: 60, cornerRadius: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pair.food.name).font(.system(size: 15, weight: .medium)).lineLimit(2)
                        // nutrient dots
                        HStack(spacing: 4) {
                            ForEach(kNutrientPills, id: \.name) { pill in
                                let has = pair.food.hairNutrients.contains(pill.name)
                                Circle()
                                    .fill(has ? pill.color : pill.color.opacity(0.18))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        if pair.food.averageCalories > 0 {
                            Text("~\(Int(pair.food.averageCalories * pair.mealFood.quantity)) kcal")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            store.decrementOrRemoveFood(mealFoodId: pair.mealFood.id, mealEntryId: mealEntryId)
                        } label: { Image(systemName: "minus.circle").font(.system(size: 22)).foregroundStyle(.secondary) }
                        Text("\(Int(pair.mealFood.quantity))").font(.system(size: 16, weight: .semibold)).frame(minWidth: 20)
                        Button {
                            store.incrementFood(mealFoodId: pair.mealFood.id, mealEntryId: mealEntryId)
                        } label: { Image(systemName: "plus.circle").font(.system(size: 22)).foregroundStyle(mealColor) }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(mealColor.opacity(0.06)))
            }
        }
    }
}

// MARK: - SuggestedSection

private struct SuggestedSection: View {
    let foods: [Food]; let mealColor: Color
    let showHeading: Bool
    let onAdd: (Food) -> Void; let onTap: (Food) -> Void
    var onCustomAdd: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showHeading {
                Text("Suggested Meals").font(.system(size: 20, weight: .bold))
            }
            if foods.isEmpty {
                VStack(spacing: 12) {
                    Text("No meals found").foregroundStyle(.secondary).font(.system(size: 15))
                    if let onCustomAdd = onCustomAdd {
                        Button(action: onCustomAdd) {
                            Text("Create Custom Meal")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(mealColor)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(mealColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(foods) { food in
                        FoodGridCard(food: food, mealColor: mealColor, onAdd: { onAdd(food) }, onTap: { onTap(food) })
                            .scrollTransition(.animated.threshold(.visible(0.05))) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0).scaleEffect(phase.isIdentity ? 1 : 0.88)
                            }
                    }
                }
                if let onCustomAdd = onCustomAdd {
                    Button(action: onCustomAdd) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Can't find it? Add Custom Meal")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(mealColor)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(mealColor.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }
}

// MARK: - FoodGridCard

private struct FoodGridCard: View {
    let food: Food; let mealColor: Color; let onAdd: () -> Void; let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FoodImageView(food: food, tint: mealColor, height: 110, width: nil, cornerRadius: 12)
                .overlay(alignment: .topTrailing) {
                    Button(action: onAdd) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(Color.green).clipShape(Circle())
                    }
                    .padding(6)
                }
                .overlay(alignment: .bottomLeading) {
                    if food.averageCalories > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange).font(.system(size: 9))
                            Text("\(Int(food.averageCalories))")
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.black.opacity(0.55)).cornerRadius(8)
                        .padding(6).allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            // food name
            Button(action: onTap) {
                Text(food.name).font(.system(size: 13, weight: .medium))
                    .lineLimit(1).foregroundStyle(.primary).padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - FoodDetailView

private struct FoodDetailView: View {
    let food: Food
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if let urlStr = food.imageURL, !urlStr.isEmpty {
                        if urlStr.hasPrefix("http://") || urlStr.hasPrefix("https://") {
                            AsyncImage(url: URL(string: urlStr)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().aspectRatio(contentMode: .fill)
                                        .frame(height: 280).frame(maxWidth: .infinity).clipped()
                                default:
                                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 280)
                                        .overlay { Image(systemName: "fork.knife").font(.system(size: 100, weight: .light)).foregroundStyle(.white.opacity(0.5)) }
                                }
                            }
                        } else {
                            Image(urlStr).resizable().aspectRatio(contentMode: .fill)
                                .frame(height: 280).frame(maxWidth: .infinity).clipped()
                        }
                    } else {
                        Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 280)
                            .overlay { Image(systemName: "fork.knife").font(.system(size: 100, weight: .light)).foregroundStyle(.white.opacity(0.5)) }
                    }
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 38, height: 38).background(Color.black.opacity(0.35)).clipShape(Circle())
                    }
                    .padding(.leading, 20).padding(.top, 56)
                }

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.system(size: 26, weight: .bold))
                        Text("Nutrition information").font(.system(size: 17, weight: .semibold)).foregroundStyle(.secondary)
                        if let desc = food.description { Text(desc).font(.system(size: 14)).foregroundStyle(.secondary) }
                        if let benefit = food.hairBenefit {
                            HStack(spacing: 6) {
                                Image(systemName: "leaf.fill").foregroundStyle(.green).font(.system(size: 12))
                                Text(benefit).font(.system(size: 13)).foregroundStyle(.green.opacity(0.85))
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    NutritionCard(food: food)
                    if !food.hairNutrients.isEmpty {
                        HairNutrientsDetailCard(food: food)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20).padding(.top, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - NutritionCard

private struct NutritionCard: View {
    let food: Food
    private static let protein = Color(red: 0.20, green: 0.78, blue: 0.35)
    private static let fat     = Color(red: 0.98, green: 0.76, blue: 0.18)
    private static let carbs   = Color(red: 0.18, green: 0.80, blue: 0.88)

    var body: some View {
        let pr = food.macroDisplayInfo(value: food.totalProteinsInGm)
        let fr = food.macroDisplayInfo(value: food.totalFatInGm)
        let cr = food.macroDisplayInfo(value: food.totalCarbsInGm)

        VStack(alignment: .leading, spacing: 16) {
            if food.averageCalories > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Calories :").font(.system(size: 18, weight: .bold))
                    Text("~\(Int(food.averageCalories))").font(.system(size: 18, weight: .bold))
                    Text("kcal").font(.system(size: 14)).foregroundStyle(.secondary)
                }
            }
            if food.totalProteinsInGm > 0 {
                VStack(spacing: 10) {
                    MacroRow(color: Self.protein, label: pr.label, fraction: pr.fraction)
                    MacroRow(color: Self.fat,     label: fr.label, fraction: fr.fraction)
                    MacroRow(color: Self.carbs,   label: cr.label, fraction: cr.fraction)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    MacroRow(color: Self.protein, label: "Proteins",      showBar: false)
                    MacroRow(color: Self.fat,     label: "Fats",          showBar: false)
                    MacroRow(color: Self.carbs,   label: "Carbohydrates", showBar: false)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground)).cornerRadius(16)
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }
}

// MARK: - HairNutrientsDetailCard  (covered nutrients only, with tick)

private struct HairNutrientsDetailCard: View {
    let food: Food

    private struct NutrientRow: Identifiable {
        let id = UUID()
        let name: String; let color: Color
    }

    private var rows: [NutrientRow] {
        var result: [NutrientRow] = []
        if food.isBiotinRich   { result.append(NutrientRow(name: "Biotin",    color: Color(red:0.25,green:0.70,blue:0.40))) }
        if food.isZincRich     { result.append(NutrientRow(name: "Zinc",      color: Color(red:0.15,green:0.55,blue:0.95))) }
        if food.isIronRich     { result.append(NutrientRow(name: "Iron",      color: Color(red:0.85,green:0.30,blue:0.25))) }
        if food.isOmega3Rich   { result.append(NutrientRow(name: "Omega-3",   color: Color(red:0.10,green:0.65,blue:0.80))) }
        if food.isVitaminARich { result.append(NutrientRow(name: "Vitamin A", color: Color(red:0.95,green:0.65,blue:0.10))) }
        if food.vitaminDIU  >= 40  { result.append(NutrientRow(name: "Vitamin D", color: .orange)) }
        if food.vitaminB12Mcg >= 0.5 { result.append(NutrientRow(name: "B12",     color: .purple)) }
        if food.vitaminEMg  >= 2.0 { result.append(NutrientRow(name: "Vitamin E", color: .yellow)) }
        if food.seleniumMcg >= 15  { result.append(NutrientRow(name: "Selenium",  color: .gray))   }
        if food.niacinMg    >= 2.0 { result.append(NutrientRow(name: "Niacin",    color: .teal))   }
        return result
    }

    var body: some View {
        if rows.isEmpty { EmptyView() } else {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "leaf.circle.fill").foregroundStyle(.green).font(.system(size: 18))
                    Text("Hair Nutrient Profile").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(rows.count) present").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                Divider().padding(.horizontal, 16)

                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    HStack {
                        Text(row.name)
                            .font(.system(size: 15))
                            .foregroundStyle(row.color)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18)).foregroundStyle(row.color)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if i < rows.count - 1 { Divider().padding(.horizontal, 16) }
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - CustomFoodSheet

private struct CustomFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let initialSearchText: String
    let mealType: MealType
    let onSave: (Food) -> Void
    
    @State private var name: String = ""
    @State private var calories: String = ""
    @State private var isVeg: Bool = true
    
    // Optional Macros
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Meal Info")) {
                    TextField("Meal Name", text: $name)
                    Toggle("Is Vegetarian", isOn: $isVeg)
                }
                
                Section(header: Text("Nutrition (Optional)"), footer: Text("Approximate values per serving")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("kcal", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("g", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("g", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("g", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Custom Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newFood = Food(
                            id: Int.random(in: 100000...999999),
                            name: name.isEmpty ? "Custom Meal" : name,
                            description: "Custom meal added by you",
                            imageURL: nil,
                            category: mealType,
                            isVegetarian: isVeg,
                            hairBenefit: nil,
                            dataSource: "User Custom",
                            caloriesKcal: Float(calories) ?? 0,
                            totalProteinsInGm: Float(protein) ?? 0,
                            totalCarbsInGm: Float(carbs) ?? 0,
                            totalFatInGm: Float(fat) ?? 0,
                            ironMg: 0,
                            vitaminDIU: 0,
                            vitaminCMg: 0,
                            zincMg: 0,
                            omega3G: 0,
                            vitaminB12Mcg: 0,
                            biotinMcg: 0,
                            vitaminEMg: 0,
                            seleniumMcg: 0,
                            niacinMg: 0
                        )
                        onSave(newFood)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = initialSearchText
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let appStore      = AppDataStore()
    let dietMateStore = DietmateDataStore(currentUserId: appStore.currentUserId)
    return NavigationStack {
        DietMateView(onGuestTap: {})
            .environment(appStore)
            .environment(dietMateStore)
    }
}
