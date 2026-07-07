
import SwiftUI

// MARK: - MyProfileView

struct MyProfileView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    
    // Editable fields
    @State private var fullName:    String = ""
    @State private var email:       String = ""
    @State private var dateOfBirth: Date?  = nil
    @State private var pickerDate: Date    = Date()
    @State private var showDOBPicker       = false
    @State private var heightCm:    String = ""
    @State private var weightKg:    String = ""
    @State private var calorieGoal: String = ""
    @State private var waterGoalML: String = ""
    
    private var user:      User?                 { store.users.first(where: { $0.id == store.currentUserId }) }
    private var profile:   UserProfile?          { store.userProfiles.first(where: { $0.userId == store.currentUserId }) }
    private var nutrition: UserNutritionProfile? { store.userNutritionProfiles.first(where: { $0.userId == store.currentUserId }) }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // ── List sections ──
                VStack(spacing: 28) {
                    personalDetailsSection
                    healthGoalsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                
                // Save button (edit mode, non-guest only)
                if isEditing && !authVM.isGuestMode {
                    Button {
                        saveProfile()
                        withAnimation { isEditing = false }
                    } label: {
                        Text("Update Profile")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.hcBrown)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.hcCream.ignoresSafeArea())
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !authVM.isGuestMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing { saveProfile() }
                        withAnimation { isEditing.toggle() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.hcBrown)
                }
            }
        }
        .sheet(isPresented: $showDOBPicker) { dobPickerSheet }
        .onAppear(perform: loadFields)
    }
    
    
    
    // MARK: - Personal Details Section
    
    private var personalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(icon: "person.circle.fill", title: "Personal Details")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
            
            Divider().padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                editableRow(label: "Full Name", text: $fullName, placeholder: "Full name")
                divider
                editableRow(label: "Email", text: $email, placeholder: "email@example.com", keyboard: .emailAddress)
                divider
                dobRow
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Health & Goals Section
    
    private var healthGoalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(icon: "heart.text.clipboard.fill", title: "Health & Goals")
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
            
            Divider().padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                editableRow(label: "Height", text: $heightCm, placeholder: "cm", keyboard: .numberPad, unit: "cm")
                divider
                editableRow(label: "Weight", text: $weightKg, placeholder: "kg", keyboard: .decimalPad, unit: "kg")
                divider
                editableRow(label: "Calorie Goal", text: $calorieGoal, placeholder: "kcal", keyboard: .numberPad, unit: "kcal")
                divider
                editableRow(label: "Hydration", text: $waterGoalML, placeholder: "mL", keyboard: .numberPad, unit: "mL")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Row Components
    
    @ViewBuilder
    private func editableRow(
        label: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default,
        unit: String? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
            Spacer()
            if isEditing {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                if let unit {
                    Text(unit)
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(text.wrappedValue.isEmpty ? "—" : text.wrappedValue + (unit.map { " \($0)" } ?? ""))
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
    
    
    
    private var dobRow: some View {
        Button {
            if isEditing {
                pickerDate = dateOfBirth ?? Date()
                showDOBPicker = true
            }
        } label: {
            HStack {
                Text("Date of Birth")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                Spacer()
                Text(dobDisplayText)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                if isEditing {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .disabled(!isEditing)
    }
    
    private var divider: some View {
        Divider().padding(.leading, 16)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.hcBrown.opacity(0.7))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.hcBrown.opacity(0.7))
        }
    }
    
    
    private var dobDisplayText: String {
        guard let dob = dateOfBirth else {
            return isEditing ? "Add Birthday" : "—"
        }
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: dob)
    }
    
    // MARK: - DOB Picker
    
    private var dobPickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Date of Birth",
                selection: $pickerDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.hcBrown)
            .padding(.horizontal)
            .navigationTitle("Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dateOfBirth = pickerDate
                        showDOBPicker = false
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.hcBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Load / Save
    
    private func loadFields() {
        fullName    = user?.name  ?? ""
        email       = user?.email ?? ""
        if let dob = profile?.dateOfBirth { dateOfBirth = dob }
        
        // Show actual values from the data store — no hardcoded fallbacks
        if let tdee = nutrition?.tdee, tdee > 0 {
            calorieGoal = "\(Int(tdee))"
        }
        if let water = nutrition?.waterTargetML, water > 0 {
            waterGoalML = "\(Int(water))"
        }
        if let h = profile?.heightCm, h > 0 {
            heightCm = "\(Int(h))"
        }
        if let w = profile?.weightKg, w > 0 {
            weightKg = "\(Int(w))"
        }
    }
    
    private func saveProfile() {
        if let idx = store.users.firstIndex(where: { $0.id == store.currentUserId }) {
            store.users[idx].name  = fullName
            store.users[idx].email = email
        }
        if let idx = store.userProfiles.firstIndex(where: { $0.userId == store.currentUserId }) {
            store.userProfiles[idx].displayName = fullName
            store.userProfiles[idx].dateOfBirth = dateOfBirth
            store.userProfiles[idx].heightCm    = Float(heightCm) ?? store.userProfiles[idx].heightCm
            store.userProfiles[idx].weightKg    = Float(weightKg) ?? store.userProfiles[idx].weightKg
        }
        if let idx = store.userNutritionProfiles.firstIndex(where: { $0.userId == store.currentUserId }) {
            store.userNutritionProfiles[idx].tdee          = Float(calorieGoal) ?? store.userNutritionProfiles[idx].tdee
            store.userNutritionProfiles[idx].waterTargetML = Float(waterGoalML) ?? store.userNutritionProfiles[idx].waterTargetML
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { MyProfileView() }
        .environment(AppDataStore())
}
