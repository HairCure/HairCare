import SwiftUI

// MARK: - Guest Gate Overlay

/// A reusable modifier that blocks a view with a sign-up overlay when the user is a guest.
/// Usage:
/// ```swift
/// SomeView()
///     .guestGate(
///         isGuest: authVM.isGuestMode,
///         icon: "chart.bar.fill",
///         title: "Track Your Progress",
///         message: "Create a free account to track your hair journey.",
///         onSignUp: { showAuthSheet = true }
///     )
/// ```
struct GuestGateModifier: ViewModifier {
    let isGuest: Bool
    let icon: String
    let title: String
    let message: String
    let onSignUp: () -> Void
    
    @State private var showSheet = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isGuest ? 8 : 0)
                .allowsHitTesting(!isGuest)
            
            if isGuest {
                // Dim background to make the lock pop and indicate it's disabled
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.hcBrown)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                    
                    Text("Locked for Guests")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.hcBrown)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Capsule())
                }
                
                // Invisible button to catch all taps and show sheet
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showSheet = true
                    }
            }
        }
        .fullScreenCover(isPresented: $showSheet) {
            GuestGateSheetView(
                icon: icon,
                title: title,
                message: message,
                onSignUp: {
                    showSheet = false
                    // Wait for sheet to dismiss before triggering the auth navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSignUp()
                    }
                },
                onDismiss: {
                    showSheet = false
                }
            )
        }
    }
}

extension View {
    /// Applies a guest gate overlay that blocks the view and prompts sign-up.
    func guestGate(
        isGuest: Bool,
        icon: String = "lock.shield.fill",
        title: String,
        message: String,
        onSignUp: @escaping () -> Void
    ) -> some View {
        modifier(GuestGateModifier(
            isGuest: isGuest,
            icon: icon,
            title: title,
            message: message,
            onSignUp: onSignUp
        ))
    }
}

// MARK: - Guest Gate Sheet Overlay

/// A standalone overlay view for presenting as a sheet or full-screen modal.
/// Used when the gate needs to appear over a specific interaction (e.g., tapping a button)
/// rather than over an entire view.
struct GuestGateSheetView: View {
    let icon: String
    let title: String
    let message: String
    let onSignUp: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.hcCream)
                        .frame(width: 80, height: 80)
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Color.hcBrown)
                }
                
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text(message)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                VStack(spacing: 12) {
                    Button(action: onSignUp) {
                        Text("Create Free Account")
                            .hcPrimaryButton()
                    }
                    
                    Button(action: onDismiss) {
                        Text("Maybe Later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.hcWarmBrown)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.vertical, 28)
            .background(Color.white)
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hcCream.opacity(0.95).ignoresSafeArea())
    }
}

struct GuestGateConfig {
    let icon: String
    let title: String
    let message: String
}

// MARK: - GuestGatePage
// Full navigation-destination page that keeps the tab bar + back button visible.

struct GuestGatePage: View {
    let config:    GuestGateConfig
    let onSignUp:  () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.hcCream.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.hcBrown.opacity(0.10))
                            .frame(width: 80, height: 80)
                        Image(systemName: config.icon)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Color.hcBrown)
                    }

                    VStack(spacing: 10) {
                        Text(config.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(config.message)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 14) {
                        Button(action: onSignUp) {
                            Text("Create Free Account")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.hcBrown)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button {
                            onDismiss()
                            dismiss()
                        } label: {
                            Text("Maybe Later")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.hcWarmBrown)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.07), radius: 20, x: 0, y: 8)
                )
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
