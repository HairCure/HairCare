import Foundation
import Observation
import Supabase
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import CryptoKit
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
    
    // Helper to generate a random nonce for secure authentication
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
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
                self.isGuestMode = false
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
                self.isGuestMode = false
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
                self.isGuestMode = false
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
                self.isGuestMode = false
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
                self.isGuestMode = false
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
    
    // MARK: - Google Sign In
    @MainActor
    func signInWithGoogle() async {
        #if canImport(GoogleSignIn)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            self.errorMessage = "Could not find root view controller for Google Sign-In"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            GIDSignIn.sharedInstance.signOut()
            
            // 1. Generate the raw nonce for Supabase
            let rawNonce = randomNonceString()
            
            // 2. Hash the nonce for Google
            let hashedData = SHA256.hash(data: Data(rawNonce.utf8))
            let hashedNonce = hashedData.compactMap { String(format: "%02x", $0) }.joined()
            
            // 3. Pass hashed nonce to Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: [],
                nonce: hashedNonce
            )
            
            guard let idToken = result.user.idToken?.tokenString else {
                self.errorMessage = "Missing ID Token from Google"
                self.isLoading = false
                return
            }
            
            // 4. Pass raw nonce to Supabase
            let session = try await auth.signInWithIdToken(credentials: .init(
                provider: .google,
                idToken: idToken,
                nonce: rawNonce
            ))
            
            self.currentUserId = session.user.id.uuidString
            self.userEmail = session.user.email
            self.userName = session.user.userMetadata["full_name"]?.stringValue ?? result.user.profile?.name
            self.isLoggedIn = true
            self.isGuestMode = false
            self.isLoading = false
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
        #else
        self.errorMessage = "GoogleSignIn SDK not installed yet."
        #endif
    }
}
