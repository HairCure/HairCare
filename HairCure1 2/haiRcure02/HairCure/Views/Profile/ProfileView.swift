
import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @State private var showAuthSheet = false
    
    private var user: User? {
        store.users.first(where: { $0.id == store.currentUserId })
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Guest upgrade card
                if authVM.isGuestMode {
                    Section {
                        GuestProfileUpgradeCard {
                            showAuthSheet = true
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                
                Section {
                    ProfileRow(icon: "person.fill", color: Color.hcBrown, title: "My Profile") {
                        MyProfileView()
                    }
                    if !authVM.isGuestMode {
                        ProfileRow(icon: "bell.badge.fill", color: Color.hcBrownLight, title: "Notifications") {
                            NotificationSettingsView()
                        }
                    }
                    ProfileRow(icon: "gearshape.fill", color: Color.hcWarmBrown, title: "Settings") {
                        SettingsView()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.hcCream)
            .navigationTitle("Profile")
            .sheet(isPresented: $showAuthSheet) {
                NavigationStack {
                    AuthLandingView(hideGuestButton: true, onProceed: {
                        showAuthSheet = false
                    })
                }
            }
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @State private var showLogoutAlert = false
    @State private var showAuthSheet = false
    
    var body: some View {
        List {
            Section {

                ProfileRow(icon: "questionmark.circle.fill", color: Color.hcBrown, title: "Help & Support") {
                    ProgressPlaceholderView(title: "Help & Support")
                }
                ProfileRow(icon: "doc.text.fill", color: Color.hcBrownLight, title: "Terms & Policies") {
                    ProgressPlaceholderView(title: "Terms & Policies")
                }
                ProfileRow(icon: "info.circle.fill", color: Color.hcWarmBrown, title: "About Us") {
                    ProgressPlaceholderView(title: "About Us")
                }
            }
            
            Section {
                if authVM.isGuestMode {
                    // Guests see "Sign Up or Log In" instead of "Sign Out"
                    Button {
                        showAuthSheet = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Up or Log In", systemImage: "person.badge.plus")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.hcBrown)
                            Spacer()
                        }
                    }
                } else {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            
            // Hide Delete Account for guests
            if !authVM.isGuestMode {
                Section {
                    NavigationLink(destination: DeleteAccountView()) {
                        HStack(spacing: 14) {
                            iconBadge(systemName: "trash.fill", color: Color.hcBrown)
                            Text("Delete Account")
                                .foregroundStyle(Color.hcBrown)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.hcCream)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out") {
                Task {
                    store.resetForLogout()
                    await authVM.signOut()
                }
            }
            .foregroundColor(.red)
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthLandingView(hideGuestButton: true, onProceed: {
                    showAuthSheet = false
                })
            }
        }
    }
    
    private func iconBadge(systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
            
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - ProfileRow

private struct ProfileRow<Destination: View>: View {
    let icon: String
    let color: Color
    let title: String
    @ViewBuilder let destination: () -> Destination
    
    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text(title)
            }
        }
    }
}

// MARK: - Delete Account View

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDataStore.self) private var store
    @Environment(AuthViewModel.self) private var authVM
    @State private var showConfirmation = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("This action is permanent", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.hcBrown)
                    
                    Text("Deleting your account will permanently remove your profile, progress, hair reports, and all associated data. This cannot be undone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            
            Section {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete My Account")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            } footer: {
                Text("If you'd like to take a break instead, you can simply sign out from the Profile screen.")
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.hcCream)
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                Task {
                    store.resetForLogout()
                    await authVM.deleteAccount()
                    dismiss()
                }
            }
        } message: {
            Text("All your data will be permanently deleted. This action cannot be undone.")
        }
    }
}

// MARK: - Coming Soon Placeholder

struct ProgressPlaceholderView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 52))
                .foregroundStyle(Color.hcBrown.opacity(0.5))
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text("Coming soon")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hcCream.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    ProfileView().environment(AppDataStore())
}
