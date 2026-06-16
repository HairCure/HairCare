import SwiftUI

struct StageSelectionView: View {
    let onComplete: () -> Void
    var onBack: (() -> Void)? = nil

    @Environment(AppDataStore.self) private var store
    @Bindable var viewModel: HairAnalysisViewModel

    var body: some View {
        ZStack {
            Color.hcCream.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    HCBackButton {
                        onBack?()
                    }
                    .opacity(onBack != nil ? 1 : 0)
                    .disabled(onBack == nil)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Select your stage")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Choose the image that best matches your hair loss")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        ManualStageImageGridView(viewModel: viewModel, store: store)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()
                Button {
                    onComplete()
                } label: {
                    Text("Continue")
                        .hcPrimaryButton()
                        .opacity(viewModel.manualStageOptionId != nil ? 1.0 : 0.5)
                }
                .disabled(viewModel.manualStageOptionId == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
    }
}
