import SwiftUI

struct ProductDetailView: View {
    let product: Product
    var onAdd: () -> Void
    var onDiscard: () -> Void
    
    @Environment(AppDataStore.self) private var store
    @State private var notes: String = ""
    @State private var flaggedIngredients: [FlaggedIngredient] = []
    @State private var isLoading = false
    
    var activeScalp: ScalpCondition {
        store.latestScanReport?.scalpCondition ?? .normal
    }
    
    var overallRecommendation: (title: String, description: String, color: Color, backgroundColor: Color, icon: String) {
        switch product.compatibility {
        case .safe:
            return (
                "Good for your Hair",
                "Recommended. This product contains safe, nourishing ingredients and no flagged irritants or drying agents.",
                Color(red: 0.12, green: 0.48, blue: 0.22),
                Color(red: 0.90, green: 0.97, blue: 0.92),
                "hand.thumbsup.fill"
            )
        case .caution:
            return (
                "Use with Caution",
                "Partially Recommended. Contains ingredients that may cause mild dryness or sebum build-up depending on usage frequency.",
                Color(red: 0.70, green: 0.40, blue: 0.05),
                Color(red: 1.00, green: 0.96, blue: 0.90),
                "exclamationmark.circle.fill"
            )
        case .hazard:
            return (
                "Not Good for your Hair",
                "Not Recommended. Contains harsh chemicals or heavy silicones that can irritate your scalp or cause product build-up.",
                Color(red: 0.77, green: 0.12, blue: 0.16),
                Color(red: 0.99, green: 0.92, blue: 0.93),
                "hand.thumbsdown.fill"
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.brand.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1)
                        
                        Text(product.name)
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        
                        Text(product.category.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.hcBrown)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.hcBrown.opacity(0.08))
                            .cornerRadius(8)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(overallRecommendation.color.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: overallRecommendation.icon)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(overallRecommendation.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OVERALL RECOMMENDATION")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(overallRecommendation.color.opacity(0.8))
                                    .tracking(1)
                                
                                Text(overallRecommendation.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(overallRecommendation.color)
                            }
                            
                            Spacer()
                        }
                        
                        Text(overallRecommendation.description)
                            .font(.system(size: 13))
                            .foregroundColor(overallRecommendation.color.opacity(0.9))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Divider()
                            .background(overallRecommendation.color.opacity(0.15))
                        
                        Text("Evaluated for your \(activeScalp.rawValue.capitalized) Scalp Profile")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(overallRecommendation.color.opacity(0.75))
                    }
                    .padding(20)
                    .background(overallRecommendation.backgroundColor)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(overallRecommendation.color.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INGREDIENT ANALYSIS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.horizontal, 20)
                        
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView("Checking safety data...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 24)
                        } else if flaggedIngredients.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                                Text("No harsh chemicals or irritants flagged for your scalp condition.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            // Flagged carousel / scrollable cards
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(flaggedIngredients) { flag in
                                        FlaggedIngredientCard(flag: flag)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALL INGREDIENTS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1)
                        
                        Text(product.ingredients.isEmpty ? "None detected" : product.ingredients.joined(separator: ", "))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MY NOTES (OPTIONAL)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1)
                        
                        TextField("Add comments about scent, texture, or results...", text: $notes)
                            .hcInputField()
                    }
                    .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        Button {
                            onDiscard()
                        } label: {
                            Text("Discard")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.hcBrown)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.hcBrown, lineWidth: 1.0)
                                )
                        }
                        
                        Button {
                            var savedProduct = product
                            if !notes.isEmpty {
                                savedProduct.notes = notes
                            }
                            onAdd()
                        } label: {
                            Text("Add to Shelf")
                                .hcPrimaryButton()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .padding(.top, 24)
            }
        }
        .background(Color.hcCream.ignoresSafeArea())
        .task {
            isLoading = true
            var resolved: [FlaggedIngredient] = []
            for ingredient in product.ingredients {
                let flag = await PubChemService.shared.analyzeIngredient(ingredient, against: activeScalp)
                if flag.rating != .safe {
                    resolved.append(flag)
                }
            }
            self.flaggedIngredients = resolved
            isLoading = false
        }
    }
}

// MARK: - Flagged Ingredient Card View
struct FlaggedIngredientCard: View {
    let flag: FlaggedIngredient
    
    var cardColor: Color {
        switch flag.rating {
        case .safe: return Color.green
        case .caution: return Color.orange
        case .hazard: return Color.red
        }
    }
    
    var elementLabel: String {
        switch flag.rating {
        case .safe: return "SAFE ELEMENT"
        case .caution: return "CAUTION ELEMENT"
        case .hazard: return "HAZARD ELEMENT"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(cardColor)
                    .frame(width: 8, height: 8)
                
                Text(elementLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(cardColor)
                
                if let signal = flag.signalWord {
                    Text(signal.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(cardColor)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            Text(flag.name.capitalized)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
            
            if !flag.ghsCodes.isEmpty {
                Text("GHS: \(flag.ghsCodes.prefix(4).joined(separator: ", "))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            Text(flag.explanation)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("RESEARCH SOURCES")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                ForEach(flag.researchLinks.prefix(2)) { link in
                    Link(destination: URL(string: link.url)!) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                                .font(.system(size: 9))
                            Text(link.source)
                                .font(.system(size: 10, weight: .semibold))
                                .underline()
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.hcBrown)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 250, height: 235)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardColor.opacity(0.15), lineWidth: 1)
        )
    }
}
