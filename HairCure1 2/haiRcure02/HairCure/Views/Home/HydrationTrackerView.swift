import SwiftUI
import HealthKit

struct HydrationTrackerView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCupSize: CupOption = .medium
    @State private var banner: String? = nil
    @State private var logError: HealthKitManager.HydrationError?
    @State private var showErrorAlert = false
    
    private var todayML: Float { Float(healthKit.todaysWaterML) }
    private var targetML: Float { Float(store.activeNutritionProfile?.waterTargetML ?? 2450) }
    private var progress: Float { min(todayML / max(targetML, 1), 1.0) }
    private var todayEntries: [HealthKitManager.WaterEntry] { healthKit.todaysWaterSamples }
    
    enum CupOption: String, CaseIterable {
        case small  = "Small"
        case medium = "Medium"
        case large  = "Large"
        
        var ml: Float {
            switch self {
            case .small:  return 150
            case .medium: return 250
            case .large:  return 400
            }
        }
        
        var icon: String {
            switch self {
            case .small:  return "waterbottle"
            case .medium: return "waterbottle"
            case .large:  return "mug.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Permission warning banner
                        if !healthKit.canWriteWater {
                            writePermissionBanner
                        }
                        
                        progressRing
                            .padding(.top, 8)
                        
                        HStack(spacing: 0) {
                            statCell(value: formattedML(todayML), label: "Today")
                            stripDivider
                            statCell(value: formattedML(targetML), label: "Target")
                            stripDivider
                            statCell(value: formattedML(max(0, targetML - todayML)), label: "Remaining")
                        }
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select cup size")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 12) {
                                ForEach(CupOption.allCases, id: \.self) { cup in
                                    cupButton(cup)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Button {
                            logWater()
                        } label: {
                            Text("+ Add \(Int(selectedCupSize.ml)) ml")
                                .hcPrimaryButton()
                        }
                        .padding(.horizontal, 20)
                        
                        if let msg = banner {
                            Text(msg)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        if !todayEntries.isEmpty {
                            todayLogList
                        }
                    }
                    .padding(.bottom, 40)
                    .animation(.easeInOut(duration: 0.25), value: banner)
                    .animation(.easeInOut(duration: 0.25), value: todayML)
                }
            }
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.hcBrown)
                        .fontWeight(.semibold)
                }
            }
            .alert("Could Not Log Water", isPresented: $showErrorAlert) {
                if case .writePermissionDenied = logError {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(logError?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }
    
    // MARK: - Log Action
    private func logWater() {
        let amount = selectedCupSize.ml
        Task {
            do {
                try await healthKit.logWater(amountML: Double(amount))
                let totalToday = todayML + amount
                let remaining  = max(0, targetML - totalToday)
                let msg = totalToday >= targetML
                ? "Daily water goal reached! Great job."
                : "\(Int(amount)) ml logged. \(Int(remaining)) ml remaining today."
                await MainActor.run {
                    withAnimation { banner = msg }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { banner = nil }
                    }
                }
            } catch let err as HealthKitManager.HydrationError {
                await MainActor.run {
                    logError = err
                    showErrorAlert = true
                }
            } catch {
                await MainActor.run {
                    logError = .saveFailed(error)
                    showErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Write Permission Banner
    private var writePermissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 18))
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Health Write Access Required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Logs from this app won't appear in Apple Health.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Grant") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.orange)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private var progressRing: some View {
        ZStack {
            Circle().stroke(Color(red: 0.15, green: 0.55, blue: 0.9).opacity(0.12), lineWidth: 14).frame(width: 140, height: 140)
            Circle().trim(from: 0, to: CGFloat(progress)).stroke(Color(red: 0.15, green: 0.55, blue: 0.9), style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 140, height: 140)
            VStack(spacing: 2) {
                Text(formattedML(todayML)).font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("of \(formattedML(targetML))").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
            }
        }
    }
    
    private func cupButton(_ cup: CupOption) -> some View {
        let isSel = selectedCupSize == cup
        return Button { selectedCupSize = cup } label: {
            VStack(spacing: 8) {
                Image(systemName: cup.icon)
                    .font(.system(size: isSel ? 28 : 22))
                    .foregroundStyle(isSel ? .white : Color(red: 0.15, green: 0.55, blue: 0.9))
                Text(cup.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSel ? .white : .primary)
                Text("\(Int(cup.ml)) ml")
                    .font(.system(size: 11))
                    .foregroundStyle(isSel ? .white.opacity(0.80) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSel ? Color(red: 0.15, green: 0.55, blue: 0.9) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSel ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
            .shadow(
                color: isSel ? Color(red: 0.15, green: 0.55, blue: 0.9).opacity(0.30) : .clear,
                radius: 6, x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: selectedCupSize)
    }
    
    // MARK: - Today's Log List (from HealthKit)
    private var todayLogList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's log")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.7))
                Text("Apple Health")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                ForEach(Array(todayEntries.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.15, green: 0.55, blue: 0.9).opacity(0.10))
                                .frame(width: 36, height: 36)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(timeString(entry.loggedAt))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(entry.hkSample.sourceRevision.source.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("+\(formattedMLDouble(entry.amountML))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Color(red: 0.15, green: 0.55, blue: 0.9).opacity(0.09),
                                in: Capsule()
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await healthKit.deleteWater(sample: entry.hkSample) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    
                    if idx < todayEntries.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Helpers
    private var stripDivider: some View {
        Rectangle()
            .fill(Color(UIColor.separator).opacity(0.5))
            .frame(width: 1, height: 36)
    }
    
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formattedML(_ ml: Float) -> String {
        ml >= 1000 ? String(format: "%.1fL", ml / 1000) : "\(Int(ml)) ml"
    }
    
    private func formattedMLDouble(_ ml: Double) -> String {
        ml >= 1000 ? String(format: "%.1fL", ml / 1000) : "\(Int(ml)) ml"
    }
    
    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
