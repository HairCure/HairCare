import SwiftUI

struct OTPResetPasswordView: View {
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.dismiss) private var dismiss
    
    let email: String
    
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }
    
    var canSubmit: Bool {
        otpCode.count >= 6 && passwordsMatch && !authVM.isLoading
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hcCream.ignoresSafeArea()
            
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        Spacer().frame(height: 72)
                        
                        // ── Header ──────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reset Password")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("Enter the reset code sent to your email, along with your new password.")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        
                        Spacer().frame(minHeight: 32)
                        
                        // ── Form Card ───────────────────────────
                        VStack(spacing: 0) {
                            // OTP Code Row
                            HStack(spacing: 14) {
                                Image(systemName: "number.square")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.hcBrown.opacity(0.8))
                                    .frame(width: 24)
                                    .padding(.leading, 18)
                                TextField("Reset Code", text: $otpCode)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 18)
                                Spacer()
                            }
                            .padding(.trailing, 16)
                            
                            Divider().padding(.leading, 56)
                            
                            PasswordRowView(icon: "lock", placeholder: "New Password", text: $newPassword)
                            
                            Divider().padding(.leading, 56)
                            
                            PasswordRowView(icon: "lock", placeholder: "Confirm Password", text: $confirmPassword)
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
                            } else if let success = authVM.successMessage {
                                Label(success, systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Color.clear.frame(height: 20)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        
                        Spacer().frame(minHeight: 32)
                        
                        // ── CTA ─────────────────────────────────
                        VStack(spacing: 20) {
                            Button {
                                Task {
                                    let success = await authVM.verifyOTPAndResetPassword(
                                        email: email,
                                        token: otpCode,
                                        newPassword: newPassword
                                    )
                                    if success {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Group {
                                    if authVM.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Save New Password")
                                    }
                                }
                                .hcPrimaryButton()
                            }
                            .disabled(!canSubmit)
                        }
                        .padding(.horizontal, 24)
                        
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
