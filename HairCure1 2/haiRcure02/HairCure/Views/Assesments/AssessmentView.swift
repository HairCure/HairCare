import SwiftUI

struct AssessmentView: View {
    @Environment(AppDataStore.self) private var store
    let onComplete: () -> Void
    var onBack: (() -> Void)? = nil
    
    @State private var viewModel = AssessmentViewModel()
    
    var initialIndex: Int = 0
    
    var body: some View {
        ZStack {
            Color.hcCream.ignoresSafeArea()
            
            if viewModel.hasStarted {
                assessmentContent
            } else {
                onboardingContent
            }
        }
        .onAppear {
            if initialIndex > 0 {
                viewModel.hasStarted = true
                viewModel.currentIndex = initialIndex
                viewModel.loadExistingAnswers(store: store)
            } else {
                viewModel.startAssessment(store: store)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.hasStarted)
        .animation(.easeInOut(duration: 0.22), value: viewModel.currentIndex)
    }
    
    private var assessmentContent: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            TabView(selection: $viewModel.currentIndex) {
                ForEach(Array(viewModel.questions(store: store).enumerated()), id: \.offset) { index, q in
                    QuestionBodyView(q: q, viewModel: viewModel, store: store)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            continueButton
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 16)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture().onChanged { _ in }
        )
    }
    
    private var onboardingContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundStyle(Color.hcBrown)
            
            VStack(spacing: 12) {
                Text("Let's get to know you")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                
                Text("Help us personalize your experience")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                viewModel.hasStarted = true
            } label: {
                Text("Start")
                    .hcPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }
    
    private var headerBar: some View {
        let totalCount = viewModel.totalCount(store: store)
        
        return ZStack {
            HStack {
                HCBackButton {
                    if viewModel.currentIndex > 0 {
                        viewModel.currentIndex -= 1
                    } else {
                        onBack?()
                    }
                }
                .opacity(viewModel.currentIndex > 0 || onBack != nil ? 1 : 0.3)
                .disabled(viewModel.currentIndex == 0 && onBack == nil)
                
                Spacer()
            }
            
            VStack(spacing: 6) {
                Text("\(viewModel.currentIndex + 1)/\(totalCount)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.hcProgressBg)
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.hcBrown)
                            .frame(width: geo.size.width * CGFloat(viewModel.currentIndex + 1) / CGFloat(totalCount), height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.currentIndex)
                    }
                }
                .frame(width: 140, height: 6)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var continueButton: some View {
        let totalCount = viewModel.totalCount(store: store)
        let canContinue = viewModel.canContinue(store: store)
        
        return Button {
            viewModel.handleContinue(store: store, onComplete: onComplete)
        } label: {
            Text(viewModel.currentIndex == totalCount - 1 ? "Finish" : "Continue")
                .hcPrimaryButton()
                .opacity(canContinue ? 1.0 : 0.5)
        }
        .disabled(!canContinue)
    }
}

// MARK: - Subviews for Questions

struct QuestionBodyView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text(q.questionText)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 24)
                    
                    Spacer()
                    
                    switch q.questionType {
                    case .singleChoice:
                        SingleChoiceOptionsView(q: q, viewModel: viewModel, store: store)
                    case .multiChoice:
                        MultiChoiceOptionsView(q: q, viewModel: viewModel, store: store)
                    case .picker:
                        PickerQuestionView(q: q, viewModel: viewModel, store: store)
                    case .imageChoice:
                        ImageChoiceGridView(q: q, viewModel: viewModel, store: store)
                    case .freeText:
                        FreeTextQuestionView(q: q, viewModel: viewModel)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
                .frame(minHeight: geometry.size.height)
            }
        }
    }
}

struct SingleChoiceOptionsView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        let opts = store.options(for: q.id)
        let selected = viewModel.singleSelections[q.id]
        
        return VStack(spacing: 16) {
            ForEach(opts) { opt in
                let isSelected = selected == opt.id
                Button {
                    viewModel.saveSingleChoice(store: store, questionId: q.id, optionId: opt.id)
                } label: {
                    HStack {
                        Text(opt.optionText)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.leading, 20)
                        
                        Spacer()
                        
                        
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(isSelected ? Color.hcBrown : Color.hcOptionBg)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.hcBrown : Color.black.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MultiChoiceOptionsView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        let opts = store.options(for: q.id)
        let selected = viewModel.multiSelections[q.id] ?? []
        
        return VStack(spacing: 16) {
            ForEach(opts) { opt in
                let isSelected = selected.contains(opt.id)
                Button {
                    var current = viewModel.multiSelections[q.id] ?? []
                    if current.contains(opt.id) {
                        current.remove(opt.id)
                    } else {
                        current.insert(opt.id)
                    }
                    viewModel.saveMultiChoice(store: store, questionId: q.id, optionIds: Array(current))
                } label: {
                    HStack {
                        Text(opt.optionText)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.leading, 20)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.trailing, 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(isSelected ? Color.hcBrown : Color.hcOptionBg)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.hcBrown : Color.black.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PickerQuestionView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        if q.pickerUnit == "cm" {
            HeightPickerQuestionView(q: q, viewModel: viewModel, store: store)
        } else {
            StandardPickerQuestionView(q: q, viewModel: viewModel, store: store)
        }
    }
}

struct StandardPickerQuestionView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        let minVal  = Int(q.pickerMin  ?? 0)
        let maxVal  = Int(q.pickerMax  ?? 100)
        let unit    = q.pickerUnit ?? ""
        let current = Binding<Float>(
            get: { viewModel.pickerValues[q.id] ?? q.pickerMin ?? 0 },
            set: { viewModel.savePickerValue(store: store, questionId: q.id, value: $0) }
        )
        
        let intCurrent = Binding<Int>(
            get: { Int(current.wrappedValue) },
            set: { current.wrappedValue = Float($0) }
        )
        
        let displayText = Binding<String>(
            get: { "\(Int(current.wrappedValue)) \(unit)" },
            set: { _ in }
        )
        
        VStack(spacing: 20) {
            TextField("", text: displayText)
                .font(.system(size: 18, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .disabled(true)
            
            Picker("", selection: intCurrent) {
                ForEach(minVal...maxVal, id: \.self) { val in
                    Text("\(val) \(unit)").tag(val)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)
            .clipped()
        }
        .padding(.horizontal, 4)
    }
}

struct HeightPickerQuestionView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        @Bindable var vm = viewModel
        
        let cmBinding = Binding<Float>(
            get: { vm.pickerValues[q.id] ?? 175.0 },
            set: { vm.savePickerValue(store: store, questionId: q.id, value: $0) }
        )
        
        let cmIntBinding = Binding<Int>(
            get: { Int(cmBinding.wrappedValue) },
            set: { cmBinding.wrappedValue = Float($0) }
        )
        
        let ftBinding = Binding<Int>(
            get: {
                let totalInches = cmBinding.wrappedValue * 0.393701
                return Int(totalInches / 12)
            },
            set: { newFt in
                let currentTotalInches = cmBinding.wrappedValue * 0.393701
                let currentIn = currentTotalInches.truncatingRemainder(dividingBy: 12.0)
                let newTotalInches = Float(newFt * 12) + Float(currentIn)
                cmBinding.wrappedValue = newTotalInches * 2.54
            }
        )
        
        let inBinding = Binding<Int>(
            get: {
                let totalInches = cmBinding.wrappedValue * 0.393701
                let inches = totalInches.truncatingRemainder(dividingBy: 12.0)
                return Int(round(inches))
            },
            set: { newIn in
                let currentTotalInches = cmBinding.wrappedValue * 0.393701
                let currentFt = Int(currentTotalInches / 12)
                let newTotalInches = Float(currentFt * 12) + Float(newIn)
                cmBinding.wrappedValue = newTotalInches * 2.54
            }
        )
        
        let displayText = Binding<String>(
            get: {
                if vm.isHeightMetric {
                    return "\(Int(cmBinding.wrappedValue)) cm"
                } else {
                    return "\(ftBinding.wrappedValue)' \(inBinding.wrappedValue)\""
                }
            },
            set: { _ in }
        )
        
        VStack(spacing: 20) {
            Picker("Unit", selection: $vm.isHeightMetric) {
                Text("cm").tag(true)
                Text("ft/in").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            
            TextField("", text: displayText)
                .font(.system(size: 18, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .disabled(true)
            
            if vm.isHeightMetric {
                Picker("", selection: cmIntBinding) {
                    ForEach(140...220, id: \.self) { val in
                        Text("\(val) cm").tag(val)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 180)
                .clipped()
            } else {
                HStack(spacing: 0) {
                    Picker("Feet", selection: ftBinding) {
                        ForEach(4...7, id: \.self) { val in
                            Text("\(val) ft").tag(val)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    
                    Picker("Inches", selection: inBinding) {
                        ForEach(0...11, id: \.self) { val in
                            Text("\(val) in").tag(val)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 180)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct ImageChoiceGridView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    var store: AppDataStore
    
    var body: some View {
        let opts = store.options(for: q.id)
        let selected = viewModel.imageSelections[q.id]
        let columns = [GridItem(.flexible(), spacing: 16),
                       GridItem(.flexible(), spacing: 16)]
        
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(opts) { opt in
                let isSelected = selected == opt.id
                Button {
                    viewModel.saveImageChoice(store: store, questionId: q.id, optionId: opt.id)
                } label: {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        isSelected ? Color.hcBrown : Color(.systemGray5),
                                        lineWidth: isSelected ? 2.5 : 1
                                    )
                            )
                        
                        VStack(spacing: 0) {
                            StageImageView(imageURL: opt.imageURL, index: opt.optionOrderIndex)
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

struct StageImageView: View {
    let imageURL: String?
    let index: Int
    
    var body: some View {
        if let url = imageURL, !url.isEmpty, UIImage(named: url) != nil {
            Image(url).resizable().scaledToFit().padding(12)
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

struct FreeTextQuestionView: View {
    let q: Question
    var viewModel: AssessmentViewModel
    
    var body: some View {
        let binding = Binding<String>(
            get: { viewModel.textValues[q.id] ?? "" },
            set: { viewModel.saveFreeText(questionId: q.id, text: $0) }
        )
        TextField("Your answer", text: binding).hcInputField()
    }
}
