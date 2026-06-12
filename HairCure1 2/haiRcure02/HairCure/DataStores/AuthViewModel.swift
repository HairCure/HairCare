//
//  AuthViewModel.swift
//  haiRcure02
//
//  Created by Chetan Kandpal on 23/04/26.
//


import Foundation
import Observation
import Supabase

@Observable
class AuthViewModel {
    var isLoggedIn: Bool = false
    var isGuestMode: Bool = false
    var currentUserId: String? = nil
    var userEmail: String? = nil
    var userName: String? = nil
    var isLoading: Bool = true
    var errorMessage: String? = nil
    
    private let auth = SupabaseManager.shared.auth
    
    init() {
        Task { await checkSession() }
    }
    
    // MARK: - Check Existing Session
    
    
    func checkSession() async {
        do {
            let session = try await auth.session
            await MainActor.run {
                self.currentUserId = session.user.id.uuidString
                self.userEmail = session.user.email
                self.userName = session.user.userMetadata["full_name"]?.stringValue
                self.isLoggedIn = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoggedIn = false
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Up with Email
    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(name)]
            )
            await MainActor.run {
                self.currentUserId = response.user.id.uuidString
                self.userEmail = response.user.email
                self.userName = name
                self.isLoggedIn = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign In with Email
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await auth.signIn(
                email: email,
                password: password
            )
            await MainActor.run {
                self.currentUserId = session.user.id.uuidString
                self.userEmail = session.user.email
                self.userName = session.user.userMetadata["full_name"]?.stringValue
                self.isLoggedIn = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            try await auth.signOut()
            await MainActor.run {
                self.isLoggedIn = false
                self.currentUserId = nil
                self.userEmail = nil
                self.userName = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount() async {
        guard let userIdStr = currentUserId, let userId = UUID(uuidString: userIdStr) else { return }
        isLoading = true
        errorMessage = nil
        do {
            // Delete user data from database
            await BackendService.shared.deleteUserData(userId: userId)
            
            // Sign out from Auth
            try await auth.signOut()
            
            await MainActor.run {
                self.isLoggedIn = false
                self.currentUserId = nil
                self.userEmail = nil
                self.userName = nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Guest Mode
    @MainActor
    func continueAsGuest() {
        self.isGuestMode = true
        self.currentUserId = UUID().uuidString
        self.isLoggedIn = false
        self.isLoading = false
    }
}
