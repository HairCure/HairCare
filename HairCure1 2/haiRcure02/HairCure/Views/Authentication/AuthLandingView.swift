import SwiftUI

// MARK: 1 — Auth Landing

struct AuthLandingView: View {
    var hideGuestButton: Bool = false
    let onProceed: () -> Void
    /// Optional closure for guest→authenticated upgrade (receives newUserId, name, email)
    var guestUpgrade: ((UUID, String, String) -> Void)? = nil
    
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
                    
                    VStack(spacing: 16) {
                        socialRow(
                            onAppleTap: {
                                Task {
                                    await authVM.signInWithApple()
                                    if authVM.isLoggedIn {
                                        store.createUser(
                                            name: authVM.userName ?? "User",
                                            email: authVM.userEmail ?? "",
                                            authProvider: .apple,
                                            supabaseId: authVM.currentUserId
                                        )
                                        onProceed()
                                    }
                                }
                            },
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
                            .padding(.top, 8)
                        }
                        
                        if let err = authVM.errorMessage {
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
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
