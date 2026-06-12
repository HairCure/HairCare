import Foundation
import Observation


extension MealType {

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .snack:     return "Snacks"
        case .dinner:    return "Dinner"
        }
    }

    var recommendedPortionText: String {
        switch self {
        case .breakfast: return "Recommended portion : 25% of daily consumption"
        case .lunch:     return "Recommended portion : 35% of daily consumption"
        case .snack:     return "Recommended portion : 20% of daily consumption"
        case .dinner:    return "Recommended portion : 20% of daily consumption"
        }
    }

    var displayOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch:     return 1
        case .snack:     return 2
        case .dinner:    return 3
        }
    }
}

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }

    var dietMateDateTitle: String {
        let cal = Calendar.current
        let str = formatted(.dateTime.day().month().year())
        if cal.isDateInToday(self)     { return "Today, \(str)" }
        if cal.isDateInYesterday(self) { return "Yesterday, \(str)" }
        return formatted(.dateTime.weekday(.wide).day().month().year())
    }
}

// MARK: - The 5 tracked hair nutrients

struct HairNutrient {
    let name: String
    let icon: String   // SF symbol
}

extension Food {
    static let hairNutrientList: [HairNutrient] = [
        HairNutrient(name: "Biotin",    icon: "leaf.fill"),
        HairNutrient(name: "Zinc",      icon: "shield.fill"),
        HairNutrient(name: "Iron",      icon: "bolt.fill"),
        HairNutrient(name: "Omega-3",   icon: "drop.fill"),
        HairNutrient(name: "Vitamin A", icon: "sun.max.fill"),
    ]
}

// MARK: - DietmateDataStore

@Observable
class DietmateDataStore {

    // MARK: - Properties

    var foods:       [Food]      = []
    var mealEntries: [MealEntry] = []
    var mealFoods:   [MealFood]  = []

    var isLoadingFoods: Bool   = false
    var foodLoadError:  String? = nil

    var currentUserId: UUID
    weak var parentStore: AppDataStore?

    // MARK: - Init

    init(currentUserId: UUID) {
        self.currentUserId = currentUserId
    }

    func addAll(userId: UUID, nutritionProfile: UserNutritionProfile?) {
        seedTodaysMealEntries(userId: userId, nutritionProfile: nutritionProfile)
    }

    // MARK: - Backend food load (replaces hardcoded foodItems())

    func loadFoodsFromBackend() async {
        await MainActor.run { isLoadingFoods = true; foodLoadError = nil }
        let fetched = await BackendService.shared.fetchMeals()
        await MainActor.run {
            if fetched.isEmpty {
                foodLoadError = "Could not load meals. Check your connection."
            } else {
                foods = fetched
            }
            isLoadingFoods = false
        }
        print("Loaded \(fetched.count) meals from backend")
    }

    // MARK: - Meal Entry seeding

    func seedTodaysMealEntries(userId: UUID, nutritionProfile: UserNutritionProfile?) {
        guard todaysMealEntries().isEmpty else { return }
        for mealType in [MealType.breakfast, .lunch, .snack, .dinner] {
            mealEntries.append(MealEntry(
                id: UUID(), userId: userId, mealType: mealType,
                date: Date(), isLogged: false, loggedAt: nil,
                caloriesConsumed: 0,
                proteinConsumed: 0, carbsConsumed: 0, fatConsumed: 0
            ))
        }
    }

    func seedDefaultMealEntries(userId: UUID) {
        guard todaysMealEntries().isEmpty else { return }
        for mealType in [MealType.breakfast, .lunch, .snack, .dinner] {
            mealEntries.append(MealEntry(
                id: UUID(), userId: userId, mealType: mealType,
                date: Date(), isLogged: false, loggedAt: nil,
                caloriesConsumed: 0,
                proteinConsumed: 0, carbsConsumed: 0, fatConsumed: 0
            ))
        }
    }

    // MARK: - Query Helpers

    func todaysMealEntries() -> [MealEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return mealEntries.filter {
            $0.userId == currentUserId &&
            Calendar.current.startOfDay(for: $0.date) == today
        }.sorted { $0.mealType.displayOrder < $1.mealType.displayOrder }
    }

    func mealEntries(for date: Date) -> [MealEntry] {
        let dayStart = Calendar.current.startOfDay(for: date)
        return mealEntries.filter {
            $0.userId == currentUserId &&
            Calendar.current.startOfDay(for: $0.date) == dayStart
        }.sorted { $0.mealType.displayOrder < $1.mealType.displayOrder }
    }

    func mealEntry(id: UUID) -> MealEntry? {
        mealEntries.first { $0.id == id }
    }

    func totalCalories(for date: Date) -> Float {
        mealEntries(for: date).reduce(0) { $0 + $1.caloriesConsumed }
    }

    /// All unique hair nutrients covered across today's added foods
    func todaysHairNutrientsCovered() -> [String] {
        hairNutrientsCovered(for: Date())
    }

    /// Unique hair nutrients covered across all foods on a given date
    func hairNutrientsCovered(for date: Date) -> [String] {
        let entries = mealEntries(for: date)
        var covered = Set<String>()
        for entry in entries {
            for pair in linkedFoods(for: entry.id) {
                pair.food.hairNutrients.forEach { covered.insert($0) }
            }
        }
        // Return in canonical order
        return Food.hairNutrientList.map(\.name).filter { covered.contains($0) }
    }

    /// Fraction 0…1 of the 5 hair nutrients covered on a given date
    func hairNutrientProgress(for date: Date) -> Double {
        let count = hairNutrientsCovered(for: date).count
        return min(Double(count) / 5.0, 1.0)
    }

    /// Number of meal slots (0–4) that have at least one food added on a given date
    func mealsWithFoodCount(for date: Date) -> Int {
        mealEntries(for: date).filter { entry in
            mealFoods.contains { $0.mealEntryId == entry.id }
        }.count
    }

    /// Hair nutrients covered within a single meal entry
    func hairNutrientsCoveredInEntry(_ entryId: UUID) -> [String] {
        var covered = Set<String>()
        for pair in linkedFoods(for: entryId) {
            pair.food.hairNutrients.forEach { covered.insert($0) }
        }
        return Food.hairNutrientList.map(\.name).filter { covered.contains($0) }
    }

    func currentWeekDates() -> [Date] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = -(cal.component(.weekday, from: today) - 1)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: start + $0, to: today) }
    }

    func foods(for mealType: MealType, vegetarianOnly: Bool = false) -> [Food] {
        foods
            .filter { $0.category == mealType && (!vegetarianOnly || $0.isVegetarian) }
            .sorted {
                let a = ($0.isBiotinRich ? 1:0) + ($0.isZincRich ? 1:0) + ($0.isIronRich ? 1:0)
                let b = ($1.isBiotinRich ? 1:0) + ($1.isZincRich ? 1:0) + ($1.isIronRich ? 1:0)
                return a > b
            }
    }

    func linkedFoods(for mealEntryId: UUID) -> [(mealFood: MealFood, food: Food)] {
        mealFoods
            .filter { $0.mealEntryId == mealEntryId }
            .compactMap { mf in
                guard let food = foods.first(where: { $0.id == mf.foodId }) else { return nil }
                return (mealFood: mf, food: food)
            }
    }

    enum VegFilter: Equatable { case all, vegOnly, nonVegOnly }

    func suggestedFoods(for mealType: MealType, searchText: String, vegFilter: VegFilter = .all) -> [Food] {
        var all = foods(for: mealType)
        switch vegFilter {
        case .vegOnly:    all = all.filter {  $0.isVegetarian }
        case .nonVegOnly: all = all.filter { !$0.isVegetarian }
        case .all:        break
        }
        return searchText.isEmpty
            ? all
            : all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func foodsInMealEntry(mealType: MealType) -> [(mealFood: MealFood, food: Food)] {
        guard let entry = mealEntries.first(where: {
            $0.userId == currentUserId &&
            $0.mealType == mealType &&
            Calendar.current.isDateInToday($0.date)
        }) else { return [] }
        return linkedFoods(for: entry.id)
    }

    func todaysTotalMacros() -> (protein: Double, carbs: Double, fat: Double) {
        let entries = todaysMealEntries()
        return (
            protein: Double(entries.reduce(0) { $0 + $1.proteinConsumed }),
            carbs:   Double(entries.reduce(0) { $0 + $1.carbsConsumed  }),
            fat:     Double(entries.reduce(0) { $0 + $1.fatConsumed    })
        )
    }

    func todaysTotalCalories() -> Float {
        todaysMealEntries().reduce(0) { $0 + $1.caloriesConsumed }
    }

    func todaysLoggedMealCount() -> Int {
        todaysMealEntries().filter { $0.isLogged }.count
    }

    func rankedFoods(for mealType: MealType, plan: UserPlan?, vegetarianOnly: Bool = false) -> [Food] {
        guard let plan = plan else {
            return foods(for: mealType, vegetarianOnly: vegetarianOnly)
        }
        return RecommendationEngine.rankedFoods(
            from: foods, for: mealType, plan: plan,
            vegetarianOnly: vegetarianOnly
        )
    }

    // MARK: - Meal Slot Summary

    struct MealSlotSummary {
        let mealType: MealType
        let caloriesConsumed: Float
        let isLogged: Bool
        let canLog: Bool
        let hairNutrients: [String]
        let nutrientProgress: Double
        let foods: [(mealFood: MealFood, food: Food)]
    }

    func mealSlotSummary(for mealType: MealType) -> MealSlotSummary {
        guard let entry = mealEntries.first(where: {
            $0.userId == currentUserId &&
            $0.mealType == mealType &&
            Calendar.current.isDateInToday($0.date)
        }) else {
            return MealSlotSummary(
                mealType: mealType, caloriesConsumed: 0,
                isLogged: false, canLog: false,
                hairNutrients: [], nutrientProgress: 0, foods: []
            )
        }
        let linked    = linkedFoods(for: entry.id)
        let nutrients = hairNutrientsCoveredInEntry(entry.id)
        return MealSlotSummary(
            mealType: mealType,
            caloriesConsumed: entry.caloriesConsumed,
            isLogged: entry.isLogged,
            canLog: !linked.isEmpty && !entry.isLogged,
            hairNutrients: nutrients,
            nutrientProgress: min(Double(nutrients.count) / 5.0, 1.0),
            foods: linked
        )
    }

    // MARK: - Meal Entry calculation

    func updateMealEntryTotals(mealEntryId: UUID) {
        guard let index = mealEntries.firstIndex(where: { $0.id == mealEntryId }) else { return }
        let linked = mealFoods.filter { $0.mealEntryId == mealEntryId }

        var calories: Float = 0
        var protein:  Float = 0
        var carbs:    Float = 0
        var fat:      Float = 0

        for mf in linked {
            if let food = foods.first(where: { $0.id == mf.foodId }) {
                calories += food.averageCalories    * mf.quantity
                protein  += food.totalProteinsInGm  * mf.quantity
                carbs    += food.totalCarbsInGm     * mf.quantity
                fat      += food.totalFatInGm       * mf.quantity
            }
        }

        mealEntries[index].caloriesConsumed = calories
        mealEntries[index].proteinConsumed  = protein
        mealEntries[index].carbsConsumed    = carbs
        mealEntries[index].fatConsumed      = fat
    }

    // MARK: - Food CRUD

    func addFood(_ food: Food, to mealEntryId: UUID, quantity: Float = 1.0) {
        mealFoods.append(MealFood(id: UUID(), mealEntryId: mealEntryId,
                                  foodId: food.id, quantity: quantity))
        updateMealEntryTotals(mealEntryId: mealEntryId)
    }

    func removeFood(mealFoodId: UUID, from mealEntryId: UUID) {
        mealFoods.removeAll { $0.id == mealFoodId }
        updateMealEntryTotals(mealEntryId: mealEntryId)
    }

    func incrementFood(mealFoodId: UUID, mealEntryId: UUID) {
        guard let idx = mealFoods.firstIndex(where: { $0.id == mealFoodId }) else { return }
        mealFoods[idx].quantity += 1
        updateMealEntryTotals(mealEntryId: mealEntryId)
    }

    func decrementOrRemoveFood(mealFoodId: UUID, mealEntryId: UUID) {
        guard let idx = mealFoods.firstIndex(where: { $0.id == mealFoodId }) else { return }
        if mealFoods[idx].quantity > 1 {
            mealFoods[idx].quantity -= 1
            updateMealEntryTotals(mealEntryId: mealEntryId)
        } else {
            removeFood(mealFoodId: mealFoodId, from: mealEntryId)
        }
    }

    func addOrIncrementFood(_ food: Food, to mealEntryId: UUID) {
        if let existing = mealFoods.first(where: {
            $0.mealEntryId == mealEntryId && $0.foodId == food.id
        }) {
            incrementFood(mealFoodId: existing.id, mealEntryId: mealEntryId)
        } else {
            addFood(food, to: mealEntryId)
        }
    }

    // MARK: - Meal Logging Actions

    func addFoodToMeal(food: Food, mealType: MealType, quantity: Float = 1.0) -> ActionResult {
        guard let entry = mealEntries.first(where: {
            $0.userId == currentUserId &&
            $0.mealType == mealType &&
            Calendar.current.isDateInToday($0.date)
        }) else {
            return .blocked(reason: "No meal slot found for \(mealType.displayName) today.")
        }
        if entry.isLogged {
            return .blocked(reason: "\(mealType.displayName) is already logged. Tap edit to make changes.")
        }
        mealFoods.append(MealFood(id: UUID(), mealEntryId: entry.id,
                                  foodId: food.id, quantity: quantity))
        updateMealEntryTotals(mealEntryId: entry.id)
        let nutrients = hairNutrientsCoveredInEntry(entry.id)
        let msg = nutrients.isEmpty
            ? "\(food.name) added."
            : "\(food.name) added · covers \(nutrients.joined(separator: ", "))"
        return .success(message: msg)
    }

    func removeFoodFromMeal(mealFoodId: UUID, mealType: MealType) -> ActionResult {
        guard let entry = mealEntries.first(where: {
            $0.userId == currentUserId &&
            $0.mealType == mealType &&
            Calendar.current.isDateInToday($0.date)
        }) else { return .noChange }
        if entry.isLogged {
            return .blocked(reason: "Unlog \(mealType.displayName) first to edit foods.")
        }
        guard mealFoods.contains(where: { $0.id == mealFoodId }) else {
            return .blocked(reason: "Food not found.")
        }
        mealFoods.removeAll { $0.id == mealFoodId }
        updateMealEntryTotals(mealEntryId: entry.id)
        return .success(message: "Food removed from \(mealType.displayName).")
    }

    func logMealEntry(mealType: MealType) -> ActionResult {
        guard let index = mealEntries.firstIndex(where: {
            $0.userId == currentUserId &&
            $0.mealType == mealType &&
            Calendar.current.isDateInToday($0.date)
        }) else {
            return .blocked(reason: "No \(mealType.displayName) entry found for today.")
        }
        let entry = mealEntries[index]
        if entry.isLogged {
            return .warning(message: "\(mealType.displayName) is already logged.")
        }
        let linked = linkedFoods(for: entry.id)
        guard !linked.isEmpty else {
            return .blocked(reason: "Add at least one food before logging.")
        }
        mealEntries[index].isLogged = true
        mealEntries[index].loggedAt = Date()
        let nutrients = hairNutrientsCoveredInEntry(entry.id)
        let covered   = nutrients.isEmpty ? "No hair nutrients covered yet." : "Covers: \(nutrients.joined(separator: " · "))"
        return .success(message: "\(mealType.displayName) logged! \(covered)")
    }

    func unlogMealEntry(mealType: MealType) -> ActionResult {
        guard let idx = mealEntries.firstIndex(where: {
            $0.userId == currentUserId &&
            $0.mealType == mealType &&
            Calendar.current.isDateInToday($0.date)
        }) else { return .noChange }
        mealEntries[idx].isLogged = false
        mealEntries[idx].loggedAt = nil
        return .success(message: "\(mealType.displayName) unlocked for editing.")
    }
}
