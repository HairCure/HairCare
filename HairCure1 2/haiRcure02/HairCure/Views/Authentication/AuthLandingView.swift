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
            
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // Space for the manual back button
                        Spacer().frame(height: 72)
                        

                        
                        // ── Header ──────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back!")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Sign in to continue your hair journey")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        
                        // Flexible space to distribute layout naturally
                        Spacer()
                            .frame(minHeight: 32)
                        
                        // ── Form Card ───────────────────────────
                        VStack(spacing: 0) {
                            // Email row
                            HStack(spacing: 14) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.hcBrown.opacity(0.8))
                                    .frame(width: 24)
                                    .padding(.leading, 18)
                                TextField("Email", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 18)
                                Spacer()
                            }
                            .padding(.trailing, 16)
                            
                            Divider().padding(.leading, 56)
                            
                            // Password row with eye toggle
                            HStack(spacing: 14) {
                                Image(systemName: "lock")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.hcBrown.opacity(0.8))
                                    .frame(width: 24)
                                    .padding(.leading, 18)
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .font(.system(size: 16))
                                .padding(.vertical, 18)
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye" : "eye.slash")
//                                        .foregroundStyle(.secondary)
                                        .foregroundStyle(Color.hcBrown.opacity(0.8))
                                        .font(.system(size: 15))
                                }
                                .padding(.trailing, 18)
                            }
                        }
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 24)
                        
                        // ── Forgot + inline error ───────────────
                        HStack {
                            if let err = authVM.errorMessage {
                                Label(err, systemImage: "exclamationmark.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            Spacer()
                            Button("Forgot Password?") {}
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.hcBrown.opacity(0.8))
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        
                        // Flexible space before CTA
                        Spacer()
                            .frame(minHeight: 32)
                        
                        // ── CTA ─────────────────────────────────
                        VStack(spacing: 20) {
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
                                .padding(.vertical, 4)
                            
                            socialRow(
                                onAppleTap: { onProceed() },
                                onGoogleTap: {
                                    Task {
                                        await authVM.signInWithGoogle()
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
                                }
                            )
                            
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                NavigationLink(destination: RegisterView(onProceed: onProceed)) {
                                    Text("Register")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.hcWarmBrown)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        
                        // Flexible space before bottom decorative text
                        Spacer()
                            .frame(minHeight: 40)
                        
                       
                    }
                    .frame(minHeight: geometry.size.height)
                }
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
            
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // Space for the manual back button
                        Spacer().frame(height: 72)
                        

                        
                        // ── Header ──────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create Account")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Start your personalised hair journey")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        
                        Spacer()
                            .frame(minHeight: 24)
                        
                        // ── Form Card ───────────────────────────
                        VStack(spacing: 0) {
                            inputRow(icon: "person", placeholder: "Full name", text: $name, keyboard: .default, isSecure: false)
                            Divider().padding(.leading, 56)
                            inputRow(icon: "envelope", placeholder: "Email", text: $email, keyboard: .emailAddress, isSecure: false, autoCapitalize: false)
                            Divider().padding(.leading, 56)
                            PasswordRowView(icon: "lock", placeholder: "Password", text: $password)
                            Divider().padding(.leading, 56)
                            PasswordRowView(icon: "lock", placeholder: "Confirm password", text: $confirmPassword)
                        }
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 24)
                        
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
                        .padding(.top, 12)
                        
                        Spacer()
                            .frame(minHeight: 24)
                            

                        
                        Spacer()
                            .frame(minHeight: 24)
                        
                        // ── CTA ─────────────────────────────────
                        VStack(spacing: 20) {
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
                                .padding(.vertical, 4)
                            
                            socialRow(
                                onAppleTap: { onProceed() },
                                onGoogleTap: {
                                    Task {
                                        await authVM.signInWithGoogle()
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
                                }
                            )
                            
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                NavigationLink(destination: LoginView(onProceed: onProceed)) {
                                    Text("Log In")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.hcWarmBrown)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                            .frame(minHeight: 40)
                            
                        
                    }
                    .frame(minHeight: geometry.size.height)
                }
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
                .foregroundStyle(Color.hcBrown.opacity(0.8))
                .frame(width: 24)
                .padding(.leading, 18)
            
            if isSecure {
                SecureField(placeholder, text: text)
                    .font(.system(size: 16))
                    .padding(.vertical, 18)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .autocapitalization(autoCapitalize ? .words : .none)
                    .font(.system(size: 16))
                    .padding(.vertical, 18)
            }
        }
        .padding(.trailing, 18)
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
                .foregroundStyle(Color.hcBrown.opacity(0.8))
                .frame(width: 24)
                .padding(.leading, 18)
            
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
            .padding(.vertical, 18)
            
            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye" : "eye.slash")
                    .foregroundStyle(Color.hcBrown.opacity(0.8))
                    .font(.system(size: 15))
            }
            .padding(.trailing, 18)
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

private func socialRow(onAppleTap: @escaping () -> Void, onGoogleTap: @escaping () -> Void) -> some View {
    VStack(spacing: 12) {
        // Apple — HIG: solid black background, white logo, "Continue with Apple"
        Button(action: onAppleTap) {
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
        
        // Google — standard "Continue with Google" with official G icon
        Button(action: onGoogleTap) {
            HStack(spacing: 8) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                
                Text("Continue with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hcBrown, lineWidth: 1.0))
        }
    }
    
}
