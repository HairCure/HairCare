import SwiftUI

struct HomeProtocolCarouselView: View {
    let plan: UserPlan?
    let nutrition: UserNutritionProfile?
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Daily Action Plan")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Spacer()
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if let plan = plan, let aiPlan = plan.aiWeeklyPlan, let np = nutrition {
                    // Find today's plan, assuming Day 1 for home screen or a dynamic day
                    if let todayPlan = aiPlan.dailyPlans.first {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                protocolCard(
                                    title: "Nutrition Plan",
                                    icon: "fork.knife",
                                    iconBg: Color(red: 0.9, green: 0.58, blue: 0.18),
                                    description: todayPlan.eat,
                                    targets: [
                                        ("\(Int(np.tdee))", "kcal", "Calories"),
                                        ("\(Int(np.proteinTargetGm))", "g", "Protein"),
                                        ("\(Int(np.carbTargetGm))", "g", "Carbs")
                                    ]
                                )
                                
                                protocolCard(
                                    title: "MindEase Wellness",
                                    icon: "moon.zzz.fill",
                                    iconBg: Color(red: 0.38, green: 0.3, blue: 0.75),
                                    description: todayPlan.mindEase,
                                    targets: [
                                        ("7.5", "hrs", "Sleep"),
                                        ("15", "min", "MindEase")
                                    ]
                                )
                                
                                protocolCard(
                                    title: "Hair Insight & Routine",
                                    icon: "sparkles",
                                    iconBg: Color.hcWarmBrown,
                                    description: todayPlan.hairCare,
                                    targets: [
                                        (String(format: "%.1f", np.waterTargetML / 1000), "L", "Water")
                                    ]
                                )
                            }
                            .padding(.horizontal, 2)
                            .padding(.bottom, 20)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.hcBrown)
                        Text("Creating your protocol...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func protocolCard(
        title: String,
        icon: String,
        iconBg: Color,
        description: String,
        targets: [(String, String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(iconBg).frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            
            Divider()
            
            HStack(spacing: 16) {
                ForEach(targets.indices, id: \.self) { index in
                    let target = targets[index]
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(target.0)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(target.1)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.hcBrown)
                        }
                        Text(target.2)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if index < targets.count - 1 {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 1, height: 28)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 280, height: 220)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
