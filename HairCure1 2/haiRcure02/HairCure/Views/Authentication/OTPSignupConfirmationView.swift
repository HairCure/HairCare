import SwiftUI

struct OTPSignupConfirmationView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.dismiss) private var dismiss
    
    let email: String
    let onProceed: () -> Void
    
    @State private var otpCode = ""
    
    var canSubmit: Bool {
        otpCode.count >= 6 && !authVM.isLoading
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
                            Text("Confirm Email")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("We sent a confirmation code to \(email). Enter it below to unlock your account.")
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
                                TextField("Confirmation Code", text: $otpCode)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 16))
                                    .padding(.vertical, 18)
                                Spacer()
                            }
                            .padding(.trailing, 16)
                        }
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 24)
                        
                        // ── Inline validation ───────────────────
                        Group {
                            if let err = authVM.errorMessage {
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
                                    let success = await authVM.verifySignupOTP(
                                        email: email,
                                        token: otpCode
                                    )
                                    if success {
                                        store.createUser(
                                            name: authVM.userName ?? "User",
                                            email: authVM.userEmail ?? "",
                                            authProvider: .email,
                                            supabaseId: authVM.currentUserId
                                        )
                                        dismiss()
                                        onProceed()
                                    }
                                }
                            } label: {
                                Group {
                                    if authVM.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Confirm Account")
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
