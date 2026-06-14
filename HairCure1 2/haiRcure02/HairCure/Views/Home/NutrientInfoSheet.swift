import SwiftUI

struct NutrientInfoSheet: View {
    private struct NutrientInfo: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let role: String
        let researchURL: String
        let sourceName: String
    }

    private let nutrients: [NutrientInfo] = [
        NutrientInfo(
            name: "Biotin",
            color: Color(red: 0.22, green: 0.72, blue: 0.45),
            role: "Essential B-vitamin that supports keratin production — the structural protein making up hair. Deficiency is linked to hair thinning and brittle strands.",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5582478/",
            sourceName: "NIH PMC · Biotin & Hair Loss"
        ),
        NutrientInfo(
            name: "Zinc",
            color: Color(red: 0.20, green: 0.55, blue: 0.90),
            role: "Regulates hair follicle cycling and sebum production. Low zinc is one of the most common nutritional causes of hair loss in both men and women.",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3870206/",
            sourceName: "NIH PMC · Zinc & Hair Loss"
        ),
        NutrientInfo(
            name: "Iron",
            color: Color(red: 0.90, green: 0.38, blue: 0.25),
            role: "Carries oxygen to the hair follicle via red blood cells. Iron-deficiency anaemia is a leading cause of telogen effluvium (diffuse hair shedding).",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3678013/",
            sourceName: "NIH PMC · Iron & Telogen Effluvium"
        ),
        NutrientInfo(
            name: "Omega-3",
            color: Color(red: 0.12, green: 0.70, blue: 0.82),
            role: "Anti-inflammatory fatty acids that nourish hair follicles, improve scalp circulation, and reduce scalp dryness and flaking.",
            researchURL: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6164340/",
            sourceName: "NIH PMC · Omega-3 & Hair Density"
        ),
        NutrientInfo(
            name: "Vitamin A",
            color: Color(red: 0.95, green: 0.65, blue: 0.10),
            role: "Needed for sebum synthesis which moisturises the scalp. However, excess vitamin A (>10,000 IU/day) can paradoxically trigger hair loss.",
            researchURL: "https://www.ncbi.nlm.nih.gov/books/NBK532986/",
            sourceName: "NIH StatPearls · Vitamin A & Skin"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hair Nutrient Research")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.15, green: 0.10, blue: 0.08))
                    Text("5 key nutrients · tap links to read studies")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 20)

                VStack(spacing: 0) {
                    ForEach(Array(nutrients.enumerated()), id: \.element.id) { idx, nutrient in
                        VStack(alignment: .leading, spacing: 10) {

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(nutrient.color)
                                    .frame(width: 8, height: 8)
                                Text(nutrient.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(red: 0.15, green: 0.10, blue: 0.08))
                            }

                            Text(nutrient.role)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)

                            if let url = URL(string: nutrient.researchURL) {
                                Link(destination: url) {
                                    Text(nutrient.sourceName + "  ↗")
                                        .font(.system(size: 12, weight: .semibold))
                                        .underline()
                                        .foregroundStyle(nutrient.color)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(nutrient.color.opacity(0.10))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)

                        if idx < nutrients.count - 1 {
                            Divider().padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .background(Color(red: 0.98, green: 0.96, blue: 0.92).ignoresSafeArea())
    }
}
