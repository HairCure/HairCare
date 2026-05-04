
import SwiftUI

// MARK: - Data Model

private struct Reference: Identifiable {
    let id = UUID()
    let citation: String
    let urlString: String
}

private struct ReferenceGroup: Identifiable {
    let id = UUID()
    let topic: String
    let icon: String
    let references: [Reference]
}

// MARK: - View

struct AllReferencesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("The science behind your personalised hair plan.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    
                    ForEach(allGroups) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: group.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.hcBrown)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text(group.topic)
                                    .font(.system(size: 18, weight: .bold))
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(group.references) { ref in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(ref.citation)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.primary.opacity(0.85))
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        if let url = URL(string: ref.urlString) {
                                            Link(destination: url) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "link")
                                                        .font(.system(size: 11))
                                                    Text("View Paper")
                                                        .font(.system(size: 13, weight: .medium))
                                                }
                                                .foregroundStyle(Color.hcBrown)
                                            }
                                        }
                                    }
                                    
                                    if ref.id != group.references.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.hcCream.ignoresSafeArea())
            .navigationTitle("Research Basis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - All Reference Groups
    
    private var allGroups: [ReferenceGroup] {
        [
            ReferenceGroup(
                topic: "Sleep",
                icon: "moon.zzz.fill",
                references: [
                    Reference(
                        citation: "Boghosian T, Mendez H, Sayegh M, et al. The intersection of sleep and hair loss: a systematic review. Dermatol Ther (Heidelb). 2026; PMID: 41535530.",
                        urlString: "https://pubmed.ncbi.nlm.nih.gov/41535530/"
                    ),
                ]
            ),
            ReferenceGroup(
                topic: "Stress",
                icon: "brain.head.profile",
                references: [
                    Reference(
                        citation: "National Institutes of Health (NIH). (2021, April 13). How stress causes hair loss",
                        urlString: "https://www.nih.gov/news-events/nih-research-matters/how-stress-causes-hair-loss"
                    ),
                ]
            ),
            ReferenceGroup(
                topic: "Diet",
                icon: "leaf.fill",
                references: [
                    Reference(
                        citation: "Guo EL, Katta R. Diet and hair loss: effects of nutrient deficiency and supplement use. Dermatol Pract Concept. 2017;7(1):1–10. PMCID: PMC5315033; PMID: 28243487",
                        urlString: "https://pmc.ncbi.nlm.nih.gov/articles/PMC5315033/"
                    ),
                ]
            ),
        ]
        
        
    }
}
