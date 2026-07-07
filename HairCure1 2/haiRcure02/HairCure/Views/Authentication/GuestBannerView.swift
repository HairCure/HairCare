import SwiftUI

// MARK: - Guest Banner View

/// A compact, non-blocking banner shown at the top of Home and Profile tabs
/// to remind guest users to sign up and save their progress.
struct GuestBannerView: View {
    let daysRemaining: Int
    let onSignUp: () -> Void
    
    @State private var isDismissed = false
    
    var body: some View {
        if !isDismissed {
            Button(action: onSignUp) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.hcBrown.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.hcBrown)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're browsing as a guest")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text(daysRemaining > 0
                             ? "Sign up to save your progress · \(daysRemaining)d left"
                             : "Sign up to keep your data")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer(minLength: 4)
                    
                    Text("Sign Up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.hcBrown)
                        .clipShape(Capsule())
                    
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) {
                            isDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.hcBrown.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Guest Profile Upgrade Card

/// A larger card shown in the Profile tab encouraging guests to create an account.
struct GuestProfileUpgradeCard: View {
    let onSignUp: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.hcBrown.opacity(0.15), Color.hcBrown.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.hcBrown)
            }
            
            VStack(spacing: 6) {
                Text("Complete Your Profile")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Create a free account to save your hair analysis, track progress, and get personalised plans.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            
            Button(action: onSignUp) {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Create Account")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.hcBrown)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.hcBrown.opacity(0.1), lineWidth: 1)
        )
    }
}
