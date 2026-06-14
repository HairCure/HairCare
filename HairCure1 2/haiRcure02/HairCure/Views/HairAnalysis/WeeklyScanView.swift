import SwiftUI
import PhotosUI

struct WeeklyScanView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss)         private var dismiss
    
    let onComplete: (ScanReport) -> Void
    
    @State private var viewModel = WeeklyScanViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()
                
                if viewModel.isAnalysing {
                    AnalysingOverlayView(viewModel: viewModel)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Monthly Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.hcBrown)
                }
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    WeeklyInstructionsCardView()
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Upload Scalp Photos")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                            
                            let count = [viewModel.photo1, viewModel.photo2, viewModel.photo3].compactMap { $0 }.count
                            Text("\(count)/3")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(viewModel.allPhotosSelected ? Color.hcBrown : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    viewModel.allPhotosSelected
                                    ? Color.hcBrown.opacity(0.12)
                                    : Color(UIColor.systemGray6)
                                )
                                .clipShape(Capsule())
                        }
                        
                        HStack(spacing: 12) {
                            @Bindable var vm = viewModel
                            PhotoSlotView(image: viewModel.photo1, picker: $vm.pickerItem1, label: "Top", sfIcon: "arrow.up")
                            PhotoSlotView(image: viewModel.photo2, picker: $vm.pickerItem2, label: "Front", sfIcon: "person.fill")
                            PhotoSlotView(image: viewModel.photo3, picker: $vm.pickerItem3, label: "Side", sfIcon: "arrow.right")
                        }
                        .frame(height: 118)
                        
                        WeeklyPhotoTipsView()
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            
            analyseButtonBar
        }
    }
    
    private var analyseButtonBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.hcCream.opacity(0), Color.hcCream],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)
            
            Button {
                viewModel.startAnalysis(store: store, onComplete: onComplete)
            } label: {
                Text("Analyse Scalp")
                    .hcPrimaryButton()
                    .opacity(viewModel.allPhotosSelected ? 1.0 : 0.40)
            }
            .disabled(!viewModel.allPhotosSelected)
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
            .background(Color.hcCream)
        }
    }
}

// MARK: - Subviews

struct PhotoSlotView: View {
    let image: UIImage?
    var picker: Binding<PhotosPickerItem?>
    let label: String
    let sfIcon: String
    
    var body: some View {
        PhotosPicker(selection: picker, matching: .images) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(image != nil ? Color.clear : Color(UIColor.systemGray6))
                
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        image != nil ? Color.hcBrown : Color(UIColor.systemGray4),
                        style: StrokeStyle(
                            lineWidth: image != nil ? 2.0 : 1.5,
                            dash:      image != nil ? []  : [5, 4]
                        )
                    )
                
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.hcBrown.opacity(0.88))
                    .clipShape(Capsule())
                    .padding(.bottom, 7)
                    
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color(UIColor.systemGray3))
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: sfIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(UIColor.systemGray4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct WeeklyInstructionsCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.hcBrown.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.hcBrown)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Scalp Scan")
                        .font(.system(size: 16, weight: .bold))
                    Text("3 photos · ~1 min")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Upload clear photos of your scalp — top, front, and side — in good lighting. Our AI tracks monthly density changes and adjusts your plan if needed.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct WeeklyPhotoTipsView: View {
    var body: some View {
        let tips: [(String, String)] = [
            ("lightbulb.fill",        "Use bright, even lighting — avoid direct flash"),
            ("iphone",                "Hold camera 6–8 inches from your scalp"),
            ("person.fill.viewfinder","Part hair clearly before each shot")
        ]
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips for best results")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            ForEach(tips, id: \.0) { icon, text in
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.hcBrown)
                        .frame(width: 14)
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct AnalysingOverlayView: View {
    var viewModel: WeeklyScanViewModel
    
    var body: some View {
        let step = viewModel.analysisStep
        let steps = viewModel.analysisSteps
        
        VStack(spacing: 36) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.hcBrown.opacity(0.10), lineWidth: 3)
                    .frame(width: 132, height: 132)
                Circle()
                    .stroke(Color.hcBrown.opacity(0.18), lineWidth: 2)
                    .frame(width: 106, height: 106)
                
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(Color.hcBrown,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 132, height: 132)
                    .rotationEffect(.degrees(Double(step) * 90 - 90))
                    .animation(
                        .linear(duration: 0.75).repeatForever(autoreverses: false),
                        value: step
                    )
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 38, weight: .thin))
                    .foregroundStyle(Color.hcBrown.opacity(0.50))
            }
            
            VStack(spacing: 12) {
                Text("Analysing Your Scalp")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text(steps[min(step, steps.count - 1)])
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.hcBrown : Color(UIColor.systemGray4))
                        .frame(
                            width:  i == step ? 10 : 7,
                            height: i == step ? 10 : 7
                        )
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.hcCream.ignoresSafeArea())
    }
}
