import Foundation
import Observation
import Supabase
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import CryptoKit
import AuthenticationServices

@Observable
class AuthViewModel: NSObject {
    var isLoggedIn: Bool = false
    var isGuestMode: Bool = false
    var currentUserId: String? = nil
    var userEmail: String? = nil
    var userName: String? = nil
    var isLoading: Bool = true
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var isResetEmailSent: Bool = false
    var isSignupEmailSent: Bool = false
    
    /// Date when the guest session was created (persisted in UserDefaults)
    var guestSessionStartDate: Date? = nil
    
    /// Maximum guest session duration — 7 days
    private static let guestSessionDurationDays = 7
    
    private enum GuestKeys {
        static let isGuestMode = "hc_guest_isGuestMode"
        static let guestUserId = "hc_guest_userId"
        static let guestSessionStart = "hc_guest_sessionStart"
    }
    
    private let auth = SupabaseManager.shared.auth
    
    /// Whether the current guest session has expired (>7 days)
    var isGuestSessionExpired: Bool {
        guard let start = guestSessionStartDate else { return false }
        let expiry = Calendar.current.date(byAdding: .day, value: Self.guestSessionDurationDays, to: start) ?? start
        return Date() > expiry
    }
    
    /// Days remaining in the guest session
    var guestDaysRemaining: Int {
        guard let start = guestSessionStartDate else { return Self.guestSessionDurationDays }
        let expiry = Calendar.current.date(byAdding: .day, value: Self.guestSessionDurationDays, to: start) ?? start
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return max(0, remaining)
    }
    
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
    
    // MARK: - Current Apple Nonce
    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?
    
    override init() {
        super.init()
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
                // Clear any leftover guest session
                clearGuestStorage()
            }
        } catch {
            await MainActor.run {
                // No auth session — check for a stored guest session
                if restoreGuestSession() {
                    self.isLoading = false
                } else {
                    self.isLoggedIn = false
                    self.isLoading = false
                }
            }
        }
    }
    
    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        isSignupEmailSent = false
        do {
            let response = try await auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(name)]
            )
            
            await MainActor.run {
                if let session = response.session {
                    // Confirm email is OFF - logged in immediately
                    self.currentUserId = session.user.id.uuidString
                    self.userEmail = session.user.email
                    self.userName = name
                    self.isLoggedIn = true
                    self.isGuestMode = false
                } else {
                    // Confirm email is ON - session is nil, user needs to verify OTP
                    self.isSignupEmailSent = true
                    self.successMessage = "Please check your email for the confirmation code."
                }
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
    
    func deleteAccount() async {
        guard let userIdStr = currentUserId, let userId = UUID(uuidString: userIdStr) else { return }
        isLoading = true
        errorMessage = nil
        do {
            // Delete user data from database
            await BackendService.shared.deleteUserData(userId: userId)
            
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
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        isResetEmailSent = false
        do {
            try await auth.resetPasswordForEmail(email)
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "A reset code has been sent to your email."
                self.isResetEmailSent = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Verify OTP & Update Password
    func verifyOTPAndResetPassword(email: String, token: String, newPassword: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Verify the 6-digit code
            _ = try await auth.verifyOTP(email: email, token: token, type: .recovery)
            
            // 2. The user is now temporarily logged in. We update the password.
            try await auth.update(user: UserAttributes(password: newPassword))
            
            // 3. Sign them out so they have to manually log in with the new password
            try? await auth.signOut()
            
            await MainActor.run {
                self.isLoading = false
                self.isResetEmailSent = false
                self.successMessage = "Password updated successfully! Please log in."
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Invalid code or failed to update password. Please try again."
                self.isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Verify Signup OTP
    func verifySignupOTP(email: String, token: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await auth.verifyOTP(email: email, token: token, type: .signup)
            
            await MainActor.run {
                self.currentUserId = session.user.id.uuidString
                self.userEmail = session.user.email
                self.userName = session.user.userMetadata["full_name"]?.stringValue
                self.isLoggedIn = true
                self.isGuestMode = false
                self.isLoading = false
                self.isSignupEmailSent = false
                self.successMessage = "Email verified successfully!"
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Invalid verification code. Please try again."
                self.isLoading = false
            }
            return false
        }
    }
    
    @MainActor
    func continueAsGuest() {
        let guestId = UUID().uuidString
        self.isGuestMode = true
        self.currentUserId = guestId
        self.isLoggedIn = false
        self.isLoading = false
        self.guestSessionStartDate = Date()
        
        // Persist guest session to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: GuestKeys.isGuestMode)
        defaults.set(guestId, forKey: GuestKeys.guestUserId)
        defaults.set(Date(), forKey: GuestKeys.guestSessionStart)
    }
    
    // MARK: - Guest → Authenticated Upgrade
    
    /// Called after a guest successfully signs up or logs in.
    /// Clears guest persistence so the next launch uses the real auth session.
    @MainActor
    func upgradeGuestToUser() {
        self.isGuestMode = false
        self.guestSessionStartDate = nil
        clearGuestStorage()
    }
    
    // MARK: - Guest Session Helpers
    
    /// Restores a guest session from UserDefaults. Returns true if restored.
    @MainActor
    private func restoreGuestSession() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: GuestKeys.isGuestMode),
              let storedId = defaults.string(forKey: GuestKeys.guestUserId),
              let startDate = defaults.object(forKey: GuestKeys.guestSessionStart) as? Date
        else { return false }
        
        let expiry = Calendar.current.date(byAdding: .day, value: Self.guestSessionDurationDays, to: startDate) ?? startDate
        if Date() > expiry {
            clearGuestStorage()
            return false
        }
        
        self.isGuestMode = true
        self.currentUserId = storedId
        self.isLoggedIn = false
        self.guestSessionStartDate = startDate
        return true
    }
    
    /// Removes all guest session data from UserDefaults
    private func clearGuestStorage() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: GuestKeys.isGuestMode)
        defaults.removeObject(forKey: GuestKeys.guestUserId)
        defaults.removeObject(forKey: GuestKeys.guestSessionStart)
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
    
    // MARK: - Apple Sign In
    @MainActor
    func signInWithApple() async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.appleSignInContinuation = continuation
                
                let nonce = randomNonceString()
                self.currentNonce = nonce
                let hashedNonce = sha256(nonce)
                
                let appleIDProvider = ASAuthorizationAppleIDProvider()
                let request = appleIDProvider.createRequest()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
                
                let authorizationController = ASAuthorizationController(authorizationRequests: [request])
                authorizationController.delegate = self
                authorizationController.presentationContextProvider = self
                authorizationController.performRequests()
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AuthViewModel: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            Task { @MainActor in
                let error = NSError(domain: "AuthViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
                self.appleSignInContinuation?.resume(throwing: error)
                self.appleSignInContinuation = nil
            }
            return
        }
        
        let name = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        Task {
            do {
                let session = try await auth.signInWithIdToken(credentials: .init(
                    provider: .apple,
                    idToken: idTokenString,
                    nonce: nonce
                ))
                
                await MainActor.run {
                    self.currentUserId = session.user.id.uuidString
                    self.userEmail = session.user.email
                    self.userName = name.isEmpty ? (session.user.userMetadata["full_name"]?.stringValue ?? "User") : name
                    self.isLoggedIn = true
                    self.isGuestMode = false
                    self.isLoading = false
                    self.appleSignInContinuation?.resume(returning: ())
                    self.appleSignInContinuation = nil
                }
            } catch {
                await MainActor.run {
                    self.appleSignInContinuation?.resume(throwing: error)
                    self.appleSignInContinuation = nil
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                self.isLoading = false
                self.appleSignInContinuation?.resume(returning: ())
                self.appleSignInContinuation = nil
                return
            }
            self.appleSignInContinuation?.resume(throwing: error)
            self.appleSignInContinuation = nil
        }
    }
}
