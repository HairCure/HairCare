
import SwiftUI

struct AssessmentView: View {
    @Environment(AppDataStore.self) private var store
    let onComplete: () -> Void
    var onBack: (() -> Void)? = nil
    
    // Navigation state
    @State private var currentIndex = 0
    
    // (reset/restore per question)
    @State private var singleSelections: [UUID: UUID]       = [:]
    @State private var multiSelections:  [UUID: Set<UUID>]  = [:]
    @State private var pickerValues:     [UUID: Float]       = [:]
    @State private var imageSelections:  [UUID: UUID]        = [:]
    @State private var textValues:       [UUID: String]      = [:]
    
    @State private var isHeightMetric:   Bool                = true
    @State private var hasStarted:       Bool                = false
    
    
    // ── Derived ──
    private var questions:        [Question] { store.assessmentQuestions() }
    private var totalCount:       Int        { questions.count }
    private var currentQuestion:  Question?  {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    // MARK: Body
    
    var body: some View {
        ZStack {
            Color.hcCream.ignoresSafeArea()
            
            if hasStarted {
                assessmentContent
            } else {
                onboardingContent
            }
        }
        .onAppear {
            store.startAssessment()
            seedPickerDefaults()
        }
        .animation(.easeInOut(duration: 0.22), value: hasStarted)
        .animation(.easeInOut(duration: 0.22), value: currentIndex)
    }
    
    private var assessmentContent: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            TabView(selection: $currentIndex) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, q in
                    questionBody(q)
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
            
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.hcBrown)
            
            VStack(spacing: 12) {
                Text("Let's get to know you")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                
                Text("Help us personalize your experience ♡")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                hasStarted = true
            } label: {
                Text("Start")
                    .hcPrimaryButton()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }
    
    // MARK: Header
    
    private var headerBar: some View {
        ZStack {
            HStack {
                HCBackButton {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    } else {
                        onBack?()
                    }
                }
                .opacity(currentIndex > 0 || onBack != nil ? 1 : 0.3)
                .disabled(currentIndex == 0 && onBack == nil)
                
                Spacer()
                
                if currentQuestion?.scoreDimension != Optional.none {
                    Button("Skip") { advance() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.hcBrown)
                }
            }
            
            VStack(spacing: 6) {
                Text("\(currentIndex + 1)/\(totalCount)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.hcBrown.opacity(0.15))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.hcBrown)
                            .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(totalCount), height: 6)
                            .animation(.easeInOut, value: currentIndex)
                    }
                }
                .frame(width: 140, height: 6)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: Question body — routes by type
    
    @ViewBuilder
    private func questionBody(_ q: Question) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                Text(q.questionText)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                
                switch q.questionType {
                case .singleChoice:
                    singleChoiceOptions(for: q)
                case .multiChoice:
                    multiChoiceOptions(for: q)
                case .picker:
                    pickerQuestion(for: q)
                case .imageChoice:
                    imageChoiceGrid(for: q)
                case .freeText:
                    freeTextQuestion(for: q)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: Single Choice
    
    private func singleChoiceOptions(for q: Question) -> some View {
        let opts     = store.options(for: q.id)
        let selected = singleSelections[q.id]
        
        return VStack(spacing: 12) {
            ForEach(opts) { opt in
                let isSelected = selected == opt.id
                Button {
                    singleSelections[q.id] = opt.id
                    store.saveAnswer(questionId: q.id, selectedOptionId: opt.id)
                } label: {
                    HStack(spacing: 16) {
                        Text(opt.optionText)
                            .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(.black)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.hcBrown)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(isSelected ? Color.hcBrown.opacity(0.05) : Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.hcBrown : Color.black.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: Multi Choice
    
    private func multiChoiceOptions(for q: Question) -> some View {
        let opts     = store.options(for: q.id)
        let selected = multiSelections[q.id] ?? []
        
        return VStack(spacing: 12) {
            ForEach(opts) { opt in
                let isSelected = selected.contains(opt.id)
                Button {
                    var current = multiSelections[q.id] ?? []
                    if current.contains(opt.id) {
                        current.remove(opt.id)
                    } else {
                        current.insert(opt.id)
                    }
                    multiSelections[q.id] = current
                    store.saveMultiAnswer(questionId: q.id, selectedOptionIds: Array(current))
                } label: {
                    HStack(spacing: 16) {
                        Text(opt.optionText)
                            .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(.black)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.hcBrown)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(isSelected ? Color.hcBrown.opacity(0.05) : Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.hcBrown : Color.black.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: Picker (age / height / weight)
    
    @ViewBuilder
    private func pickerQuestion(for q: Question) -> some View {
        if q.pickerUnit == "cm" {
            heightPickerQuestion(for: q)
        } else {
            standardPickerQuestion(for: q)
        }
    }
    
    private func standardPickerQuestion(for q: Question) -> some View {
        let minVal  = Int(q.pickerMin  ?? 0)
        let maxVal  = Int(q.pickerMax  ?? 100)
        let unit    = q.pickerUnit ?? ""
        let current = Binding<Float>(
            get: { pickerValues[q.id] ?? q.pickerMin ?? 0 },
            set: { newVal in
                pickerValues[q.id] = newVal
                store.savePickerAnswer(questionId: q.id, pickerValue: newVal)
            }
        )
        
        let intCurrent = Binding<Int>(
            get: { Int(current.wrappedValue) },
            set: { current.wrappedValue = Float($0) }
        )
        
        let displayText = Binding<String>(
            get: { "\(Int(current.wrappedValue)) \(unit)" },
            set: { _ in }
        )
        
        return VStack(spacing: 20) {
            TextField("", text: displayText)
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.hcInputBg)
                .cornerRadius(12)
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
    
    private func heightPickerQuestion(for q: Question) -> some View {
        let cmBinding = Binding<Float>(
            get: { pickerValues[q.id] ?? 175.0 },
            set: { newVal in
                pickerValues[q.id] = newVal
                store.savePickerAnswer(questionId: q.id, pickerValue: newVal)
            }
        )
        
        let cmIntBinding = Binding<Int>(
            get: { Int(cmBinding.wrappedValue) },
            set: { cmBinding.wrappedValue = Float($0) }
        )
        
        // Math: 1 cm = 0.393701 inches. Total inches = cm * 0.393701
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
                if isHeightMetric {
                    return "\(Int(cmBinding.wrappedValue)) cm"
                } else {
                    return "\(ftBinding.wrappedValue)' \(inBinding.wrappedValue)\""
                }
            },
            set: { _ in }
        )
        
        return VStack(spacing: 20) {
            Picker("Unit", selection: $isHeightMetric) {
                Text("cm").tag(true)
                Text("ft/in").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            
            TextField("", text: displayText)
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.hcInputBg)
                .cornerRadius(12)
                .disabled(true)
            
            if isHeightMetric {
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
    
    // MARK: Image Choice (stage cards)
    
    private func imageChoiceGrid(for q: Question) -> some View {
        let opts     = store.options(for: q.id)
        let selected = imageSelections[q.id]
        let columns  = [GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(opts) { opt in
                let isSelected = selected == opt.id
                Button {
                    imageSelections[q.id] = opt.id
                    store.saveAnswer(questionId: q.id, selectedOptionId: opt.id)
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
                            stageImage(imageURL: opt.imageURL, index: opt.optionOrderIndex)
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
    
    @ViewBuilder
    private func stageImage(imageURL: String?, index: Int) -> some View {
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
    
    
    private func freeTextQuestion(for q: Question) -> some View {
        let binding = Binding<String>(
            get: { textValues[q.id] ?? "" },
            set: { textValues[q.id] = $0 }
        )
        return TextField("Your answer", text: binding).hcInputField()
    }
    
    // MARK: Continue Button
    
    private var continueButton: some View {
        Button {
            guard canContinue else { return }
            if currentIndex == totalCount - 1 {
                store.completeAssessment()
                onComplete()
            } else {
                advance()
            }
        } label: {
            Text(currentIndex == totalCount - 1 ? "Finish" : "Continue")
                .hcPrimaryButton()
                .opacity(canContinue ? 1.0 : 0.5)
        }
        .disabled(!canContinue)
    }
    
    // MARK: Can Continue Logic
    
    private var canContinue: Bool {
        guard let q = currentQuestion else { return false }
        switch q.questionType {
        case .singleChoice: return singleSelections[q.id] != nil
        case .multiChoice:  return !(multiSelections[q.id]?.isEmpty ?? true)
        case .picker:       return true
        case .imageChoice:  return imageSelections[q.id] != nil
        case .freeText:
            return !(textValues[q.id]?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        }
    }
    
    // MARK: Helpers
    
    private func advance() {
        if currentIndex < totalCount - 1 { currentIndex += 1 }
    }
    
    private func seedPickerDefaults() {
        for q in questions where q.questionType == .picker {
            if pickerValues[q.id] == nil {
                let defaultVal: Float
                
                if q.pickerUnit == "yrs" {
                    defaultVal = 20
                } else if q.pickerUnit == "cm" {
                    defaultVal = 175
                } else if q.pickerUnit == "kg" {
                    defaultVal = 70
                } else {
                    defaultVal = ((q.pickerMin ?? 0) + (q.pickerMax ?? 100)) / 2
                }
                
                pickerValues[q.id] = defaultVal
                store.savePickerAnswer(questionId: q.id, pickerValue: defaultVal)
            }
        }
    }
}
