import SwiftUI

struct WeeklyPlanWidgetView: View {
    let plan: UserPlan?
    var isCompact: Bool = false
    @State private var selectedDay: Int = 1
    
    var body: some View {
        if let plan = plan, let aiPlan = plan.aiWeeklyPlan {
            VStack(alignment: .leading, spacing: 18) {
                if isCompact {
                    HStack {
                        Text("Today's AI Plan")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Personalised 7-Day Schedule")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text("AI generated day-by-day roadmap for your scalp and lifestyle needs.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(aiPlan.dailyPlans) { daily in
                                let isSelected = selectedDay == daily.dayNumber
                                
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedDay = daily.dayNumber
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("Day")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                        Text("\(daily.dayNumber)")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                    }
                                    .frame(width: 54, height: 64)
                                    .background(isSelected ? Color.hcBrown : Color.white)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isSelected ? Color.hcBrown : Color.black.opacity(0.06), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? Color.hcBrown.opacity(0.3) : Color.black.opacity(0.04), radius: isSelected ? 6 : 4, x: 0, y: isSelected ? 4 : 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
                
                // Card details for active day
                if let activeDayPlan = aiPlan.dailyPlans.first(where: { $0.dayNumber == selectedDay }) {
                    VStack(spacing: 12) {
                        dailyPlanCard(
                            icon: "fork.knife",
                            iconBg: Color(red: 0.9, green: 0.58, blue: 0.18),
                            title: "What to Eat",
                            description: activeDayPlan.eat,
                            actions: activeDayPlan.eatActions
                        )
                        
                        dailyPlanCard(
                            icon: "moon.zzz.fill",
                            iconBg: Color(red: 0.38, green: 0.3, blue: 0.75),
                            title: "MindEase Wellness",
                            description: activeDayPlan.mindEase,
                            actions: activeDayPlan.mindEaseActions
                        )
                        
                        // Hair insights / routine card
                        dailyPlanCard(
                            icon: "sparkles",
                            iconBg: Color.hcWarmBrown,
                            title: "Hair Insight & Routine",
                            description: activeDayPlan.hairCare,
                            actions: activeDayPlan.hairCareActions
                        )
                    }
                    .padding(.horizontal, 20)
                    .id(selectedDay)
                }
            }
            .padding(.vertical, 10)
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.hcBrown)
                    Text("Creating your custom 7-day plan using AI...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func dailyPlanCard(
        icon: String,
        iconBg: Color,
        title: String,
        description: String,
        actions: [AIActionItem]? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(iconBg).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let actions = actions, !actions.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(actions, id: \.self) { action in
                            VStack(alignment: .leading, spacing: 6) {
                                if let time = action.time {
                                    Text(time.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(iconBg)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(iconBg.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let subtitle = action.subtitle {
                                        Text(subtitle)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6).opacity(0.7))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
