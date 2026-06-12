import SwiftUI

// MARK: 1 — Auth Landing

struct AuthLandingView: View {
    var hideGuestButton: Bool = false
    let onProceed: () -> Void
    
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hcCream.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    logoView
                        .padding(.bottom, 16)
                    
                    Text("HairCare")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    VStack(spacing: 14) {
                        NavigationLink(destination: LoginView(onProceed: onProceed)) {
                            Text("Login")
                                .hcPrimaryButton()
                        }
                        
                        NavigationLink(destination: RegisterView(onProceed: onProceed)) {
                            Text("Register")
                                .hcSecondaryButton()
                        }
                        if !hideGuestButton {
                            Button("Continue as a guest") {
                                authVM.continueAsGuest()
                                store.createUser(
                                    name: "Guest",
                                    email: "",
                                    authProvider: .guest,
                                    supabaseId: authVM.currentUserId
                                )
                                onProceed()
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.hcWarmBrown)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var logoView: some View {
        Group {
            if UIImage(named: "haircure") != nil {
                Image("haircure")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
            }
        }
    }
}

// MARK: 2 — Login

struct LoginView: View {
    let onProceed: () -> Void
    
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var email        = ""
    @State private var password     = ""
    @State private var showPassword = false
    
    var canSubmit: Bool { !email.isEmpty && !password.isEmpty && !authVM.isLoading }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hcCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Space for the manual back button
                Spacer().frame(height: 72)
                
                // ── Header ──────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back!")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Sign in to continue your hair journey")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                
                // ── Form Card ───────────────────────────
                VStack(spacing: 0) {
                    // Email row
                    HStack(spacing: 14) {
                        Image(systemName: "envelope")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.hcBrown)
                            .frame(width: 24)
                            .padding(.leading, 16)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .font(.system(size: 16))
                            .padding(.vertical, 16)
                        Spacer()
                    }
                    .padding(.trailing, 16)
                    
                    Divider().padding(.leading, 52)
                    
                    // Password row with eye toggle
                    HStack(spacing: 14) {
                        Image(systemName: "lock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.hcBrown)
                            .frame(width: 24)
                            .padding(.leading, 16)
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .font(.system(size: 16))
                        .padding(.vertical, 16)
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye" : "eye.slash")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15))
                        }
                        .padding(.trailing, 16)
                    }
                }
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                
                // ── Forgot + inline error ───────────────
                HStack {
                    if let err = authVM.errorMessage {
                        Label(err, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Button("Forgot Password?") {}
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 10)
                
                Spacer().frame(height: 24)
                
                // ── CTA ─────────────────────────────────
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await authVM.signIn(email: email, password: password)
                            if authVM.isLoggedIn {
                                store.createUser(
                                    name: authVM.userName ?? "User",
                                    email: authVM.userEmail ?? "",
                                    authProvider: .google,
                                    supabaseId: authVM.currentUserId
                                )
                                onProceed()
                            }
                        }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Log In")
                            }
                        }
                        .hcPrimaryButton()
                    }
                    .disabled(!canSubmit)
                    
                    dividerRow(label: "Or continue with")
                    
                    socialRow { onProceed() }
                    
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        NavigationLink(destination: RegisterView(onProceed: onProceed)) {
                            Text("Register")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.hcWarmBrown)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            
            // ── Single back button — pinned to safe area top-left ──
            HCBackButton { dismiss() }
                .padding(.leading, 16)
                .padding(.top, 8)
                .safeAreaPadding(.top, 0)
        }
        .navigationBarHidden(true)
    }
}


// MARK: 3 — Register

struct RegisterView: View {
    let onProceed: () -> Void
    
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var name            = ""
    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    
    var passwordsMatch: Bool { password == confirmPassword }
    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && passwordsMatch && !authVM.isLoading
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hcCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Space for the manual back button
                Spacer().frame(height: 72)
                
                // ── Header ──────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Account")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Start your personalised hair journey")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                
                // ── Form Card ───────────────────────────
                VStack(spacing: 0) {
                    inputRow(icon: "person", placeholder: "Full name", text: $name, keyboard: .default, isSecure: false)
                    Divider().padding(.leading, 52)
                    inputRow(icon: "envelope", placeholder: "Email", text: $email, keyboard: .emailAddress, isSecure: false, autoCapitalize: false)
                    Divider().padding(.leading, 52)
                    PasswordRowView(icon: "lock", placeholder: "Password", text: $password)
                    Divider().padding(.leading, 52)
                    PasswordRowView(icon: "lock", placeholder: "Confirm password", text: $confirmPassword)
                }
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                
                // ── Inline validation ───────────────────
                Group {
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Label("Passwords don't match", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    } else if let err = authVM.errorMessage {
                        Label(err, systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                
                Spacer(minLength: 0)
                
                // ── CTA ─────────────────────────────────
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await authVM.signUp(
                                email: email,
                                password: password,
                                name: name.isEmpty
                                ? email.components(separatedBy: "@").first ?? "User"
                                : name
                            )
                            if authVM.isLoggedIn {
                                store.createUser(
                                    name: authVM.userName ?? "User",
                                    email: authVM.userEmail ?? "",
                                    authProvider: .google,
                                    supabaseId: authVM.currentUserId
                                )
                                onProceed()
                            }
                        }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Account")
                            }
                        }
                        .hcPrimaryButton()
                    }
                    .disabled(!canSubmit)
                    
                    dividerRow(label: "Or continue with")
                    
                    socialRow { onProceed() }
                    
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        NavigationLink(destination: LoginView(onProceed: onProceed)) {
                            Text("Log In")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.hcWarmBrown)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            
            // ── Single back button — pinned to safe area top-left ──
            HCBackButton { dismiss() }
                .padding(.leading, 16)
                .padding(.top, 8)
                .safeAreaPadding(.top, 0)
        }
        .navigationBarHidden(true)
    }
    
    // ── Grouped input row (icon + field) ────────────────────────────────────
    @ViewBuilder
    private func inputRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        isSecure: Bool,
        autoCapitalize: Bool = true
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.hcBrown)
                .frame(width: 24)
                .padding(.leading, 16)
            
            if isSecure {
                SecureField(placeholder, text: text)
                    .font(.system(size: 16))
                    .padding(.vertical, 16)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .autocapitalization(autoCapitalize ? .words : .none)
                    .font(.system(size: 16))
                    .padding(.vertical, 16)
            }
        }
        .padding(.trailing, 16)
    }
}

// MARK: - PasswordRowView

struct PasswordRowView: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var showPassword = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.hcBrown)
                .frame(width: 24)
                .padding(.leading, 16)
            
            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    SecureField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .font(.system(size: 16))
            .padding(.vertical, 16)
            
            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye" : "eye.slash")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
            }
            .padding(.trailing, 16)
        }
    }
}

// MARK: Shared Auth Sub-views

private func dividerRow(label: String) -> some View {
    HStack {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
        Text(label)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize()
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
    }
}

private func socialRow(onTap: @escaping () -> Void) -> some View {
    VStack(spacing: 12) {
        // Apple — HIG: solid black background, white logo, "Continue with Apple"
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                Text("Continue with Apple")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(12)
        }
        
        // Google — standard "Continue with Google" with G icon in white circle
        Button(action: onTap) {
            HStack(spacing: 8) {
                GoogleLogoView()
                    .frame(width: 22, height: 22)
                
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.15), lineWidth: 1.5))
        }
    }
}

// MARK: - Google "G" Logo (Official brand colours drawn with SwiftUI)

private struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let r = min(w, h) / 2
            let thickness = r * 0.42
            let inner = r - thickness
            
            // Background arc — blue (bottom-left → top-right, clockwise)
            drawArc(in: &context, center: CGPoint(x: cx, y: cy),
                    radius: r, innerRadius: inner,
                    startAngle: .degrees(-45), endAngle: .degrees(45),
                    color: Color(red: 0.26, green: 0.52, blue: 0.96))  // #4285F4
            
            // Green (bottom-right)
            drawArc(in: &context, center: CGPoint(x: cx, y: cy),
                    radius: r, innerRadius: inner,
                    startAngle: .degrees(45), endAngle: .degrees(135),
                    color: Color(red: 0.20, green: 0.66, blue: 0.33))  // #34A853
            
            // Yellow (bottom-left)
            drawArc(in: &context, center: CGPoint(x: cx, y: cy),
                    radius: r, innerRadius: inner,
                    startAngle: .degrees(135), endAngle: .degrees(210),
                    color: Color(red: 0.98, green: 0.74, blue: 0.02))  // #FBBC05
            
            // Red (top-left portion)
            drawArc(in: &context, center: CGPoint(x: cx, y: cy),
                    radius: r, innerRadius: inner,
                    startAngle: .degrees(210), endAngle: .degrees(315),
                    color: Color(red: 0.92, green: 0.26, blue: 0.21))  // #EA4335
            
            // Horizontal bar extending right from center (blue)
            let barH = thickness
            let barRect = CGRect(x: cx, y: cy - barH / 2, width: r + thickness * 0.1, height: barH)
            context.fill(Path(barRect), with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
        }
    }
    
    private func drawArc(in context: inout GraphicsContext,
                         center: CGPoint, radius: CGFloat, innerRadius: CGFloat,
                         startAngle: Angle, endAngle: Angle, color: Color) {
        var path = Path()
        path.addArc(center: center, radius: radius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }
}
