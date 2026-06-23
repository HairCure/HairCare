import SwiftUI


extension View {
    func hcInputField() -> some View { modifier(HCInputField()) }
}

// MARK: - Colours

extension Color {
    /// Dark brown — primary button fill, selected option, progress bar fill
    static let hcBrown       = Color(red: 0.32, green: 0.15, blue: 0.15)   // Lighter than #3D1A1A, but not too light
    /// Slightly lighter brown — used on pressed states / borders
    static let hcBrownLight  = Color(red: 0.361, green: 0.176, blue: 0.176)   // #5C2D2D
    /// Teal — link colour, "Continue as guest"
    //static let hcTeal        = Color(red: 0.000, green: 0.749, blue: 0.647)   // #00BFA5
    static let hcWarmBrown = Color(red: 0.35, green: 0.22, blue: 0.23)
    /// Cream — page background for assessment + onboarding
    static let hcCream       = Color(red: 0.980, green: 0.965, blue: 0.941)   // #FAF5EF
    /// Input field background
    static let hcInputBg     = Color(red: 0.929, green: 0.945, blue: 0.961)   // #EDF1F5
    /// Unselected option background
    static let hcOptionBg    = Color.white
    /// Progress bar unfilled segment
    static let hcProgressBg  = Color(red: 0.878, green: 0.867, blue: 0.855)   // #E0DDA9 (muted)
}

// MARK: - Shared Button Styles

struct HCPrimaryButton: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? Color.hcBrown : Color.hcBrown.opacity(0.5))
            .cornerRadius(14)
    }
}

struct HCSecondaryButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.hcBrown)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.hcBrown, lineWidth: 1.0)
            )
    }
}

extension View {
    func hcPrimaryButton() -> some View { modifier(HCPrimaryButton()) }
    func hcSecondaryButton() -> some View { modifier(HCSecondaryButton()) }
}

// MARK: - Input Field Style

struct HCInputField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .frame(height: 60)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}

// MARK: - Back Button

struct HCBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }
}
