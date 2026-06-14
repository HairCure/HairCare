import SwiftUI

struct FallbackAssessmentView: View {
    let onComplete: () -> Void
    
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    
    @State private var viewModel = FallbackAssessmentViewModel()
    
    var body: some View {
        let questions = viewModel.questions(store: store)
        let total = viewModel.totalCount(store: store)
        let canContinue = viewModel.canContinue()
        
        return ZStack(alignment: .bottom) {
            Color.hcCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    HCBackButton {
                        if viewModel.currentIndex > 0 { viewModel.currentIndex -= 1 }
                    }
                    .opacity(viewModel.currentIndex > 0 ? 1 : 0.3)
                    .disabled(viewModel.currentIndex == 0)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                TabView(selection: $viewModel.currentIndex) {
                    ForEach(Array(questions.enumerated()), id: \.offset) { index, q in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 28) {
                                Text(q.questionText)
                                    .font(.system(size: 26, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 8)
                                
                                switch q.questionType {
                                case .imageChoice:
                                    FallbackStageImageGridView(q: q, viewModel: viewModel, store: store)
                                case .singleChoice:
                                    FallbackSingleChoiceOptionsView(q: q, viewModel: viewModel, store: store)
                                default:
                                    EmptyView()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 140)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture().onChanged { _ in }
            )
            
            VStack(spacing: 12) {
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<total, id: \.self) { i in
                        Circle()
                            .fill(i == viewModel.currentIndex ? Color.hcBrown : Color.hcBrown.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Button {
                    viewModel.handleContinue(authVM: authVM, store: store, onComplete: onComplete)
                } label: {
                    Text(viewModel.currentIndex == total - 1 ? "Get My Plan" : "Continue")
                        .hcPrimaryButton()
                        .opacity(canContinue ? 1.0 : 0.5)
                }
                .disabled(!canContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Color.hcBrown)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor(Color.hcBrown.opacity(0.2))
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.currentIndex)
        .alert("Doctor Consultation Recommended", isPresented: $viewModel.showDoctorAlert) {
            Button("Understood") { onComplete() }
        } message: {
            Text(viewModel.doctorMessage)
        }
        .sheet(isPresented: $viewModel.showAuthSheet) {
            AuthLandingView(hideGuestButton: true) {
                viewModel.showAuthSheet = false
                viewModel.submitToEngine(store: store, onComplete: onComplete)
            }
        }
    }
}

// MARK: - Subviews

struct FallbackStageImageGridView: View {
    let q: Question
    var viewModel: FallbackAssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        let opts = store.options(for: q.id)
        let selected = viewModel.stageOptionId
        let columns = [GridItem(.flexible(), spacing: 16),
                       GridItem(.flexible(), spacing: 16)]
        
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(opts) { opt in
                let isSel = selected == opt.id
                Button {
                    viewModel.stageOptionId = opt.id
                    store.saveAnswer(questionId: q.id, selectedOptionId: opt.id)
                } label: {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        isSel ? Color.hcBrown : Color(.systemGray5),
                                        lineWidth: isSel ? 2.5 : 1
                                    )
                            )
                        
                        VStack(spacing: 0) {
                            FallbackStageImageView(imageURL: opt.imageURL, index: opt.optionOrderIndex)
                                .frame(maxWidth: .infinity)
                                .frame(height: 130)
                                .clipped()
                        }
                        
                        Text("\(opt.optionOrderIndex)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(8)
                    }
                    .frame(height: 150)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FallbackStageImageView: View {
    let imageURL: String?
    let index: Int
    
    var body: some View {
        if let url = imageURL, UIImage(named: url) != nil {
            Image(url)
                .resizable()
                .scaledToFit()
                .padding(12)
        } else {
            ZStack {
                Color(.systemGray6)
                VStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(.systemGray3))
                    Text("Stage \(index)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.systemGray2))
                }
            }
        }
    }
}

struct FallbackSingleChoiceOptionsView: View {
    let q: Question
    var viewModel: FallbackAssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        let opts = store.options(for: q.id)
        let selected: UUID? = q.questionOrderIndex == 12 ? viewModel.scalpOptionId : viewModel.densityOptionId
        
        VStack(spacing: 12) {
            ForEach(opts) { opt in
                let isSel = selected == opt.id
                Button {
                    if q.questionOrderIndex == 12 {
                        viewModel.scalpOptionId = opt.id
                    } else {
                        viewModel.densityOptionId = opt.id
                    }
                    store.saveAnswer(questionId: q.id, selectedOptionId: opt.id)
                } label: {
                    HStack {
                        Text(opt.optionText)
                            .font(.system(size: 17, weight: isSel ? .semibold : .regular))
                            .foregroundStyle(isSel ? .white : .primary)
                            .padding(.leading, 20)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .background(isSel ? Color.hcBrown : Color.hcOptionBg)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSel ? Color.clear : Color(.systemGray4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
