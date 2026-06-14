import SwiftUI
import Charts

struct SleepDetailsSheet: View {
    let healthKit: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = SleepDetailsViewModel()
    
    private var totalHours: Double { viewModel.totalHours(healthKit: healthKit) }
    private var hours: Int { Int(totalHours) }
    private var mins: Int { Int((totalHours - Double(hours)) * 60) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                SleepStatusBannerView(hours: hours)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                
                List {
                    Section {
                        SleepTimeRowView(
                            icon: "bed.double.fill",
                            iconColor: Color(red: 0.42, green: 0.30, blue: 0.80),
                            label: "Bedtime",
                            time: healthKit.lastSleepStart,
                            viewModel: viewModel
                        )
                        SleepTimeRowView(
                            icon: "alarm.fill",
                            iconColor: Color(red: 0.52, green: 0.38, blue: 0.88),
                            label: "Wake Up",
                            time: healthKit.lastSleepEnd,
                            viewModel: viewModel
                        )
                        HStack {
                            Label {
                                Text("Duration")
                                    .font(.system(size: 16, weight: .medium))
                            } icon: {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color(red: 0.52, green: 0.38, blue: 0.88))
                            }
                            Spacer()
                            Text(viewModel.durationText(healthKit: healthKit))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("Last Night's Session")
                    }
                    
                    Section {
                        SleepHistoryChartView(healthKit: healthKit)
                            .frame(height: 180)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } header: {
                        Text("Sleep History")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sleep Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct SleepStatusBannerView: View {
    let hours: Int
    
    var body: some View {
        let text = hours >= 7 ? "Optimal sleep. Excellent for cell regeneration & follicle health." : "Insufficient sleep. Aim for 7-8 hours to support hair growth."
        let icon = hours >= 7 ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        let color = hours >= 7 ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color.orange
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct SleepTimeRowView: View {
    let icon: String
    let iconColor: Color
    let label: String
    let time: Date?
    var viewModel: SleepDetailsViewModel
    
    var body: some View {
        let displayText = viewModel.formattedTime(time)
        return HStack {
            Label {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            Spacer()
            Text(displayText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

struct SleepHistoryChartView: View {
    let healthKit: HealthKitManager
    
    var body: some View {
        return Chart {
            ForEach(Array(healthKit.weeklySleepData.enumerated()), id: \.offset) { _, entry in
                BarMark(
                    x: .value("Day", entry.day),
                    y: .value("Hours", entry.hours)
                )
                .foregroundStyle(
                    entry.hours >= 7
                        ? Color(red: 0.52, green: 0.38, blue: 0.88)
                        : entry.hours >= 5
                            ? Color(red: 0.95, green: 0.65, blue: 0.15)
                            : Color(red: 0.90, green: 0.30, blue: 0.28)
                )
                .cornerRadius(4)
            }
            RuleMark(y: .value("Goal", 7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.35))
                .annotation(position: .top, alignment: .trailing) {
                    Text("7h goal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.35))
                }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))h")
                            .font(.system(size: 10))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium))
            }
        }
    }
}
