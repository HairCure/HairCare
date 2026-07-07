import SwiftUI

struct WaterDetailsSheet: View {
    let healthKit: HealthKitManager
    let targetML: Float
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = WaterDetailsViewModel()
    
    private var todayML: Double { healthKit.todaysWaterML }
    private var todayL:  String { String(format: "%.1f", todayML / 1000) }
    private var targetL: String { String(format: "%.1f", Double(targetML) / 1000) }
    private var progress: Double { min(todayML / Double(max(targetML, 1)), 1.0) }
    private var metGoal:  Bool { todayML >= Double(targetML) }
    private var remaining: Double { max(0, Double(targetML) - todayML) }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    WaterProgressCardView(progress: progress, todayL: todayL, targetL: targetL, remaining: remaining)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    
                    if !healthKit.canWriteWater {
                        WaterPermissionBannerView()
                            .padding(.horizontal, 20)
                    }
                    
                    if let msg = viewModel.banner {
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    WaterCupPickerSectionView(selectedCup: $viewModel.selectedCup)
                        .padding(.horizontal, 20)
                    
                    Button {
                        viewModel.logWater(healthKit: healthKit, targetML: targetML)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add \(Int(viewModel.selectedCup.ml)) ml")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                         Color(red: 0.0, green: 0.75, blue: 0.95)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    
                    if !healthKit.todaysWaterSamples.isEmpty {
                        WaterTodayLogSectionView(healthKit: healthKit)
                            .padding(.horizontal, 20)
                    }
                    
                    WaterWeeklySectionView(healthKit: healthKit)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.banner)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Water Intake")
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
            .alert("Could Not Log Water", isPresented: $viewModel.showErrorAlert) {
                if case .writePermissionDenied = viewModel.logError {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.logError?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }
}

struct WaterProgressCardView: View {
    let progress: Double
    let todayL: String
    let targetL: String
    let remaining: Double
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(red: 0.15, green: 0.55, blue: 0.95).opacity(0.12), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                                Color(red: 0.0, green: 0.75, blue: 0.95)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.75), value: progress)
                VStack(spacing: 1) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("of goal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 8) {
                WaterStatRowView(label: "Today", value: "\(todayL) L", color: Color(red: 0.15, green: 0.55, blue: 0.95))
                WaterStatRowView(label: "Target", value: "\(targetL) L", color: .secondary)
                WaterStatRowView(label: "Remaining", value: String(format: "%.1f L", remaining / 1000), color: .orange)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct WaterStatRowView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
}

struct WaterPermissionBannerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Health Write Access Off")
                    .font(.system(size: 14, weight: .semibold))
                Text("Water logged here will not sync to Apple Health.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }
}

struct WaterCupPickerSectionView: View {
    @Binding var selectedCup: WaterDetailsViewModel.CupSize
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(WaterDetailsViewModel.CupSize.allCases, id: \.self) { cup in
                let isSelected = selectedCup == cup
                Button {
                    selectedCup = cup
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: cup.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(isSelected ? .white : Color(red: 0.15, green: 0.55, blue: 0.90))
                        
                        Text(cup.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isSelected ? .white : .primary)
                        
                        Text("\(Int(cup.ml)) ml")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isSelected
                        ? LinearGradient(
                            colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                     Color(red: 0.0, green: 0.75, blue: 0.95)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [Color.white],
                            startPoint: .top, endPoint: .bottom
                          )
                    )
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: 6, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WaterTodayLogSectionView: View {
    let healthKit: HealthKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Log")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(healthKit.todaysWaterSamples.enumerated()), id: \.element.id) { idx, sample in
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.90))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(sample.amountML)) ml")
                                .font(.system(size: 15, weight: .bold))
                            
                            let f = DateFormatter()
                            let _ = { f.timeStyle = .short }()
                            Text(f.string(from: sample.loggedAt))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        Button {
                            Task { await healthKit.deleteWater(sample: sample.hkSample) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(.red.opacity(0.7))
                                .padding(8)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    
                    if idx < healthKit.todaysWaterSamples.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

import Charts

struct WaterWeeklySectionView: View {
    let healthKit: HealthKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Hydration")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                Chart {
                    ForEach(Array(healthKit.weeklyWaterData.enumerated()), id: \.offset) { _, entry in
                        BarMark(
                            x: .value("Day", entry.day),
                            y: .value("Volume", entry.totalML / 1000)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.55, blue: 0.95),
                                         Color(red: 0.0, green: 0.75, blue: 0.95)],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1fL", v))
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
                .frame(height: 140)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}
