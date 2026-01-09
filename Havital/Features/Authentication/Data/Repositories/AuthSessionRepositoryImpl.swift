import Foundation

// MARK: - Auth Session Repository Implementation
/// Implements authentication session and token management
/// Responsible for managing user session state and token lifecycle
/// Implements secure caching strategy: business data cached (5 min), tokens NOT cached
final class AuthSessionRepositoryImpl: AuthSessionRepository {

    // MARK: - Constants

    /// UserDefaults key for legacy onboarding completion status
    private static let legacyOnboardingKey = "hasCompletedOnboarding"

    /// UserDefaults key to track if legacy migration sync has been done
    private static let legacyMigrationSyncedKey = "hasCompletedOnboarding_migrationSynced"

    // MARK: - Dependencies

    private let firebaseAuth: FirebaseAuthDataSource
    private let backendAuth: BackendAuthDataSource
    private let authCache: AuthCache

    // MARK: - Initialization

    init(
        firebaseAuth: FirebaseAuthDataSource,
        backendAuth: BackendAuthDataSource,
        authCache: AuthCache
    ) {
        self.firebaseAuth = firebaseAuth
        self.backendAuth = backendAuth
        self.authCache = authCache
    }

    // MARK: - Session State Operations

    /// Get currently cached user (synchronous)
    /// Returns cached AuthUser without making network calls
    /// Cache expires after 5 minutes (business data only, no tokens)
    func getCurrentUser() -> AuthUser? {
        // Return cached user if valid
        let cachedUser = authCache.getCurrentUser()

        if let user = cachedUser {
            Logger.debug("[AuthSession] Returning cached user: \(user.uid)")
        } else {
            Logger.debug("[AuthSession] No valid cached user found")
        }

        return cachedUser
    }

    /// Fetch current user from Firebase and Backend (asynchronous)
    /// Always fetches fresh data from API, updates cache
    /// Also performs one-time legacy migration sync if needed
    func fetchCurrentUser() async throws -> AuthUser {
        do {
            // Step 1: Get current Firebase user
            guard let firebaseUser = firebaseAuth.getCurrentUser() else {
                Logger.debug("[AuthSession] No Firebase user session found")
                throw AuthenticationError.userNotFound
            }

            Logger.debug("[AuthSession] Fetching fresh user data for: \(firebaseUser.uid)")

            // Step 2: Get Firebase ID Token
            let idToken = try await firebaseAuth.getIdToken()

            // Step 3: Sync with backend to get latest data
            let syncRequest = UserSyncRequest(
                firebaseUid: firebaseUser.uid,
                idToken: idToken,
                fcmToken: nil,
                deviceInfo: nil
            )
            let syncResponse = try await backendAuth.syncUserWithBackend(request: syncRequest)

            // Step 4: Check for legacy migration and sync if needed (one-time)
            await syncLegacyOnboardingStatusIfNeeded(
                uid: firebaseUser.uid,
                backendCompleted: syncResponse.onboardingStatus.isCompleted
            )

            // Step 5: Map to AuthUser Entity (includes legacy fallback logic)
            let authUser = FirebaseUserMapper.toDomain(
                firebaseUser: firebaseUser,
                syncResponse: syncResponse
            )

            // Step 6: Update cache
            authCache.saveUser(authUser)

            Logger.debug("[AuthSession] User data fetched and cached: \(authUser.uid)")
            return authUser

        } catch let error as AuthenticationError {
            Logger.error("[AuthSession] Failed to fetch user: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[AuthSession] Unexpected error fetching user: \(error.localizedDescription)")
            throw AuthenticationError.userNotFound
        }
    }

    // MARK: - Legacy Migration

    /// Sync legacy onboarding status to backend if there's a mismatch
    /// This is a one-time operation to migrate from old AuthenticationService
    /// - Parameters:
    ///   - uid: User's Firebase UID
    ///   - backendCompleted: Backend's current onboarding completion status
    private func syncLegacyOnboardingStatusIfNeeded(uid: String, backendCompleted: Bool) async {
        // Skip if backend already says completed
        guard !backendCompleted else { return }

        // Skip if we've already done the migration sync for this user
        let migrationSynced = UserDefaults.standard.bool(forKey: Self.legacyMigrationSyncedKey)
        guard !migrationSynced else { return }

        // Check if legacy UserDefaults says completed
        let legacyCompleted = UserDefaults.standard.bool(forKey: Self.legacyOnboardingKey)
        guard legacyCompleted else { return }

        // Mismatch detected: legacy says completed, backend says not
        Logger.debug("[AuthSession] 🔄 Legacy migration: syncing onboarding status to backend")
        Logger.debug("[AuthSession]   Backend: false, Legacy: true → Updating backend")

        do {
            // Sync to backend (fire and forget, don't block login)
            try await backendAuth.completeOnboarding(uid: uid, data: [
                "migrated_from": "legacy_userdefaults",
                "migration_timestamp": ISO8601DateFormatter().string(from: Date())
            ])

            // Mark migration as done (won't try again)
            UserDefaults.standard.set(true, forKey: Self.legacyMigrationSyncedKey)

            Logger.debug("[AuthSession] ✅ Legacy onboarding status synced to backend successfully")

        } catch {
            // Don't fail login if sync fails - just log and continue
            // The legacy fallback in FirebaseUserMapper will still work
            Logger.error("[AuthSession] ⚠️ Failed to sync legacy status to backend: \(error.localizedDescription)")
            Logger.debug("[AuthSession]   Will retry on next login")
        }
    }

    /// Check if user is currently authenticated
    /// Validates Firebase Auth State
    func isAuthenticated() -> Bool {
        let authenticated = firebaseAuth.isAuthenticated()
        Logger.debug("[AuthSession] Authentication status: \(authenticated)")
        return authenticated
    }

    // MARK: - Token Management

    /// Get Firebase ID Token (real-time, not cached)
    /// Token is fetched from Firebase SDK every time for security
    /// Firebase SDK handles automatic refresh internally
    func getIdToken() async throws -> String {
        // Prioritize Demo Token if set
        if let demoToken = demoToken {
             return demoToken
        }

        do {
            let token = try await firebaseAuth.getIdToken()
            Logger.debug("[AuthSession] ID Token retrieved successfully")
            return token
        } catch {
            Logger.error("[AuthSession] Failed to get ID Token: \(error.localizedDescription)")
            throw AuthenticationError.tokenExpired
        }
    }

    /// Force refresh Firebase ID Token
    /// Explicitly requests new token from Firebase
    func refreshIdToken() async throws -> String {
        do {
            let token = try await firebaseAuth.refreshIdToken()
            Logger.debug("[AuthSession] ID Token refreshed successfully")
            return token
        } catch {
            Logger.error("[AuthSession] Failed to refresh ID Token: \(error.localizedDescription)")
            throw AuthenticationError.tokenExpired
        }
    }

    // MARK: - Cache Management

    /// Clear all cached authentication data
    /// Used during sign-out or when cache becomes invalid
    func clearCache() {
        authCache.clearCache()
        Logger.debug("[AuthSession] Cache cleared")
    }

    // MARK: - Demo Support

    private var demoToken: String?

    func setDemoToken(_ token: String?) {
        self.demoToken = token
        Logger.debug("[AuthSession] Demo token set: \(token != nil)")
    }
}
