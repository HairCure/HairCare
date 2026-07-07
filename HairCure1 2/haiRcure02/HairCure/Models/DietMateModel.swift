import Foundation

enum MealType: String, Codable, CaseIterable {
    case breakfast, lunch, snack, dinner
}

struct MealEntry: Identifiable {
    let id: UUID
    var userId: UUID
    var mealType: MealType
    var date: Date
    var isLogged: Bool
    var loggedAt: Date?
    var caloriesConsumed: Float
    var proteinConsumed: Float
    var carbsConsumed: Float
    var fatConsumed: Float
}

extension MealEntry {
    var hasCalories: Bool { caloriesConsumed > 0 }
}

struct MealFood: Identifiable {
    let id: UUID
    var mealEntryId: UUID
    var foodId: Int
    var quantity: Float      
}

struct Food: Identifiable {
    let id: Int
    var name: String
    var description: String?
    var imageURL: String?
    var category: MealType
    var isVegetarian: Bool
    var hairBenefit: String?
    var dataSource: String?

    var caloriesKcal: Float

    var totalProteinsInGm: Float
    var totalCarbsInGm: Float
    var totalFatInGm: Float

    // Full nutrient panel from meal_nutrients
    var ironMg: Float
    var vitaminDIU: Float
    var vitaminCMg: Float
    var zincMg: Float
    var omega3G: Float
    var vitaminB12Mcg: Float
    var biotinMcg: Float
    var vitaminEMg: Float
    var seleniumMcg: Float
    var niacinMg: Float
}

extension Food {
    // Hair-nutrient flags — derived from evidence-based thresholds
    var isBiotinRich:   Bool { biotinMcg >= 5.0  }
    var isZincRich:     Bool { zincMg    >= 1.5  }
    var isIronRich:     Bool { ironMg    >= 3.0  }
    var isOmega3Rich:   Bool { omega3G   >= 0.5  }
    var isVitaminARich: Bool { vitaminCMg >= 15.0 } 

    var hairNutrients: [String] {
        var list: [String] = []
        if isBiotinRich   { list.append("Biotin") }
        if isZincRich     { list.append("Zinc") }
        if isIronRich     { list.append("Iron") }
        if isOmega3Rich   { list.append("Omega-3") }
        if isVitaminARich { list.append("Vitamin A") }
        return list
    }

    var averageCalories: Float { caloriesKcal }

    var macroMaxValue: Float {
        max(totalProteinsInGm, totalFatInGm, totalCarbsInGm, 1)
    }

    func macroDisplayInfo(value: Float) -> (label: String, fraction: Double) {
        let label    = "\(Int((value * 0.85).rounded())) – \(Int((value * 1.15).rounded())) g"
        let fraction = Double(value / macroMaxValue)
        return (label, fraction)
    }

    var suitableMealTypes: [MealType] { [category] }
}
