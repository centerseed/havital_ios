import Foundation
import UIKit

// MARK: - Auth Repository Implementation
/// Implements core authentication operations
/// Orchestrates DataSources and Mappers to provide authentication functionality
/// Does NOT publish events (passive principle - ViewModel publishes events)
final class AuthRepositoryImpl: AuthRepository {

    // MARK: - Dependencies

    private let firebaseAuth: FirebaseAuthDataSource
    private let googleSignIn: GoogleSignInDataSource
    private let appleSignIn: AppleSignInDataSource
    private let backendAuth: BackendAuthDataSource
    private let authCache: AuthCache
    private let authSessionRepository: AuthSessionRepository

    // MARK: - Initialization

    init(
        firebaseAuth: FirebaseAuthDataSource,
        googleSignIn: GoogleSignInDataSource,
        appleSignIn: AppleSignInDataSource,
        backendAuth: BackendAuthDataSource,
        authCache: AuthCache,
        authSessionRepository: AuthSessionRepository
    ) {
        self.firebaseAuth = firebaseAuth
        self.googleSignIn = googleSignIn
        self.appleSignIn = appleSignIn
        self.backendAuth = backendAuth
        self.authCache = authCache
        self.authSessionRepository = authSessionRepository
    }

    // MARK: - Sign-In Operations

    /// Sign in with Google account
    /// 7-Step Authentication Flow:
    /// 1. Google SDK sign-in → Get tokens
    /// 2. Convert SDK credential → Domain credential
    /// 3. Firebase OAuth authentication
    /// 4. Get Firebase ID Token
    /// 5. Backend user sync
    /// 6. Map DTO → AuthUser Entity
    /// 7. Cache AuthUser
    func signInWithGoogle() async throws -> AuthUser {
        do {
            // Step 1: Google SDK sign-in
            Logger.debug("[AuthRepository] Step 1: Starting Google Sign-In")
            let googleUser = try await googleSignIn.performSignIn()

            // Step 2: Convert SDK credential to Domain abstraction
            Logger.debug("[AuthRepository] Step 2: Mapping Google credential")
            let googleCredential = try AuthCredentialMapper.toDomain(googleUser)

            // Step 3: Firebase OAuth authentication
            Logger.debug("[AuthRepository] Step 3: Authenticating with Firebase")
            let firebaseUser = try await firebaseAuth.signInWithGoogle(
                idToken: googleCredential.idToken,
                accessToken: googleCredential.accessToken
            )

            // Step 4: Get Firebase ID Token
            Logger.debug("[AuthRepository] Step 4: Fetching Firebase ID Token")
            let idToken = try await firebaseAuth.getIdToken()

            // Step 5: Backend user sync
            Logger.debug("[AuthRepository] Step 5: Syncing with backend")
            let syncRequest = UserSyncRequest(
                firebaseUid: firebaseUser.uid,
                idToken: idToken,
                fcmToken: nil, // TODO: Add FCM token if available
                deviceInfo: DeviceInfo(
                    model: UIDevice.current.model,
                    osVersion: UIDevice.current.systemVersion,
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    locale: Locale.current.identifier
                )
            )
            let syncResponse = try await backendAuth.syncUserWithBackend(request: syncRequest)

            // Step 5.5: [Version Gate] Intercept forceUpdate before mapping
            if let vc = syncResponse.versionCheck, vc.forceUpdate {
                Logger.warn("[AuthRepository] 🚫 Force update required. minVersion=\(vc.minAppVersion ?? "?") updateUrl=\(vc.updateUrl ?? "?")")
                throw AuthenticationError.forceUpdateRequired(updateUrl: vc.updateUrl)
            }

            // Step 6: Map DTO → AuthUser Entity
            Logger.debug("[AuthRepository] Step 6: Mapping to AuthUser Entity")
            let authUser = FirebaseUserMapper.toDomain(
                firebaseUser: firebaseUser,
                syncResponse: syncResponse
            )

            // Step 7: Cache AuthUser
            Logger.debug("[AuthRepository] Step 7: Caching AuthUser")
            authCache.saveUser(authUser)

            Logger.debug("[AuthRepository] Google Sign-In completed successfully: \(authUser.uid)")
            return authUser

        } catch let error as AuthenticationError {
            Logger.error("[AuthRepository] Google Sign-In failed: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[AuthRepository] Google Sign-In unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.googleSignInFailed(error.localizedDescription)
        }
    }

    /// Sign in with Apple ID (full async flow)
    /// Handles ASAuthorizationController internally via AppleSignInDataSource
    /// Similar 7-Step flow as Google Sign-In
    func signInWithApple() async throws -> AuthUser {
        do {
            // Step 1: Generate nonce for security
            Logger.debug("[AuthRepository] Step 1: Generating nonce for Apple Sign-In")
            let rawNonce = FirebaseAuthDataSource.generateNonce()
            let hashedNonce = FirebaseAuthDataSource.sha256(rawNonce)

            // Step 2: Apple Sign-In via DataSource (presents UI)
            Logger.debug("[AuthRepository] Step 2: Presenting Apple Sign-In UI")
            let appleCredential = try await appleSignIn.performSignIn(nonce: hashedNonce)

            // Extract identity token
            guard let identityToken = appleCredential.identityToken else {
                throw AuthenticationError.appleSignInFailed("Missing identity token")
            }

            // Step 3: Firebase OAuth authentication
            Logger.debug("[AuthRepository] Step 3: Authenticating with Firebase")
            let firebaseUser = try await firebaseAuth.signInWithApple(
                identityToken: identityToken,
                rawNonce: rawNonce
            )

            // Step 4: Get Firebase ID Token
            Logger.debug("[AuthRepository] Step 4: Fetching Firebase ID Token")
            let idToken = try await firebaseAuth.getIdToken()

            // Step 5: Backend user sync
            Logger.debug("[AuthRepository] Step 5: Syncing with backend")
            let syncRequest = UserSyncRequest(
                firebaseUid: firebaseUser.uid,
                idToken: idToken,
                fcmToken: nil,
                deviceInfo: DeviceInfo(
                    model: UIDevice.current.model,
                    osVersion: UIDevice.current.systemVersion,
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    locale: Locale.current.identifier
                )
            )
            let syncResponse = try await backendAuth.syncUserWithBackend(request: syncRequest)

            // Step 5.5: [Version Gate] Intercept forceUpdate before mapping
            if let vc = syncResponse.versionCheck, vc.forceUpdate {
                Logger.warn("[AuthRepository] 🚫 Force update required. minVersion=\(vc.minAppVersion ?? "?") updateUrl=\(vc.updateUrl ?? "?")")
                throw AuthenticationError.forceUpdateRequired(updateUrl: vc.updateUrl)
            }

            // Step 6: Map DTO → AuthUser Entity
            Logger.debug("[AuthRepository] Step 6: Mapping to AuthUser Entity")
            let authUser = FirebaseUserMapper.toDomain(
                firebaseUser: firebaseUser,
                syncResponse: syncResponse
            )

            // Step 7: Cache AuthUser
            Logger.debug("[AuthRepository] Step 7: Caching AuthUser")
            authCache.saveUser(authUser)

            Logger.debug("[AuthRepository] Apple Sign-In completed successfully: \(authUser.uid)")
            return authUser

        } catch let error as AuthenticationError {
            Logger.error("[AuthRepository] Apple Sign-In failed: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[AuthRepository] Apple Sign-In unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.appleSignInFailed(error.localizedDescription)
        }
    }

    /// Sign in with Apple ID (with pre-obtained credential)
    /// Similar 7-Step flow as Google Sign-In
    func signInWithApple(credential: AppleAuthCredential) async throws -> AuthUser {
        do {
            // Step 1: Generate nonce for security (rawNonce needed for Firebase verification)
            Logger.debug("[AuthRepository] Step 1: Generating nonce for Apple Sign-In")
            let rawNonce = FirebaseAuthDataSource.generateNonce()

            // Step 2: Apple Sign-In (credential already provided)
            Logger.debug("[AuthRepository] Step 2: Using provided Apple credential")

            // Step 3: Firebase OAuth authentication
            Logger.debug("[AuthRepository] Step 3: Authenticating with Firebase")
            let firebaseUser = try await firebaseAuth.signInWithApple(
                identityToken: credential.identityToken,
                rawNonce: rawNonce
            )

            // Step 4: Get Firebase ID Token
            Logger.debug("[AuthRepository] Step 4: Fetching Firebase ID Token")
            let idToken = try await firebaseAuth.getIdToken()

            // Step 5: Backend user sync
            Logger.debug("[AuthRepository] Step 5: Syncing with backend")
            let syncRequest = UserSyncRequest(
                firebaseUid: firebaseUser.uid,
                idToken: idToken,
                fcmToken: nil,
                deviceInfo: DeviceInfo(
                    model: UIDevice.current.model,
                    osVersion: UIDevice.current.systemVersion,
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    locale: Locale.current.identifier
                )
            )
            let syncResponse = try await backendAuth.syncUserWithBackend(request: syncRequest)

            // Step 5.5: [Version Gate] Intercept forceUpdate before mapping
            if let vc = syncResponse.versionCheck, vc.forceUpdate {
                Logger.warn("[AuthRepository] 🚫 Force update required. minVersion=\(vc.minAppVersion ?? "?") updateUrl=\(vc.updateUrl ?? "?")")
                throw AuthenticationError.forceUpdateRequired(updateUrl: vc.updateUrl)
            }

            // Step 6: Map DTO → AuthUser Entity
            Logger.debug("[AuthRepository] Step 6: Mapping to AuthUser Entity")
            let authUser = FirebaseUserMapper.toDomain(
                firebaseUser: firebaseUser,
                syncResponse: syncResponse
            )

            // Step 7: Cache AuthUser
            Logger.debug("[AuthRepository] Step 7: Caching AuthUser")
            authCache.saveUser(authUser)

            Logger.debug("[AuthRepository] Apple Sign-In completed successfully: \(authUser.uid)")
            return authUser

        } catch let error as AuthenticationError {
            Logger.error("[AuthRepository] Apple Sign-In failed: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[AuthRepository] Apple Sign-In unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.appleSignInFailed(error.localizedDescription)
        }
    }

    /// Sign in with email and password
    /// Currently not implemented - placeholder for future
    func signInWithEmail(email: String, password: String) async throws -> AuthUser {
        throw AuthenticationError.invalidCredentials
    }

    /// Demo login for development/testing
    /// Calls backend /login/demo API and returns authenticated user
    func demoLogin(reviewerPasscode: String) async throws -> AuthUser {
        do {
            Logger.debug("[AuthRepository] Starting demo login")

            // Step 1: Call demo login API
            let demoResponse = try await backendAuth.demoLogin(reviewerPasscode: reviewerPasscode)

            Logger.debug("[AuthRepository] Demo login API succeeded, UID: \(demoResponse.uid)")

            // Step 2: Store demo token in AuthSessionRepository
            // This is crucial for subsequent API calls to use the demo token
            authSessionRepository.setDemoToken(demoResponse.idToken)
            Logger.debug("[AuthRepository] 🎯 Demo token stored. SessionRepo ID: \(ObjectIdentifier(authSessionRepository as AnyObject))")

            // Step 3: Create AuthUser from demo response
            let forceOnboardingInUITest = CommandLine.arguments.contains("-resetOnboarding")
            let authUser = AuthUser(
                uid: demoResponse.uid,
                email: demoResponse.email,
                displayName: demoResponse.displayName,
                photoURL: nil,
                isAuthenticated: true,
                hasCompletedOnboarding: !forceOnboardingInUITest,
                onboardingMode: forceOnboardingInUITest ? .initial : .none
            )

            // Step 4: Cache the user
            authCache.saveUser(authUser)
            Logger.debug("[AuthRepository] 🎯 User cached with UID: \(authUser.uid)")

            Logger.debug("[AuthRepository] Demo login completed successfully")
            return authUser

        } catch let error as AuthenticationError {
            Logger.error("[AuthRepository] Demo login failed: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[AuthRepository] Demo login unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.firebaseAuthFailed("Demo login failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign-Out Operations

    /// Sign out current user
    /// Clears Firebase session and local cache
    func signOut() async throws {
        do {
            Logger.debug("[AuthRepository] Signing out user")

            // Sign out from Firebase
            try await firebaseAuth.signOut()

            // Demo reviewer login uses a backend token without Firebase session.
            authSessionRepository.setDemoToken(nil)

            // Clear local cache
            authCache.clearCache()

            Logger.debug("[AuthRepository] Sign-out completed successfully")

        } catch let error as AuthenticationError {
            Logger.error("[AuthRepository] Sign-out failed: \(error.localizedDescription)")
            throw error
        } catch {
            Logger.error("[AuthRepository] Sign-out unexpected error: \(error.localizedDescription)")
            throw AuthenticationError.firebaseAuthFailed(error.localizedDescription)
        }
    }
}

// MARK: - Dependency Injection Registration
extension DependencyContainer {
    /// Register Authentication Module Dependencies
    /// Registers DataSources, Cache, and Repositories
    func registerAuthenticationModule() {
        // Step 1: Register Cache
        let authCache = UserDefaultsAuthCache()
        register(authCache as AuthCache, forProtocol: AuthCache.self)

        // Step 2: Register DataSources
        let firebaseAuthDS = FirebaseAuthDataSource()
        register(firebaseAuthDS, for: FirebaseAuthDataSource.self)

        let googleSignInDS = GoogleSignInDataSource()
        register(googleSignInDS, for: GoogleSignInDataSource.self)

        let appleSignInDS = AppleSignInDataSource()
        register(appleSignInDS, for: AppleSignInDataSource.self)

        let backendAuthDS = BackendAuthDataSource(
            httpClient: resolve(),
            parser: resolve()
        )
        register(backendAuthDS, for: BackendAuthDataSource.self)

        // Step 3: Register Repositories
        // First register AuthSessionRepository since AuthRepository depends on it
        let authSessionRepo = AuthSessionRepositoryImpl(
            firebaseAuth: resolve(),
            backendAuth: resolve(),
            authCache: resolve()
        )
        register(authSessionRepo as AuthSessionRepository, forProtocol: AuthSessionRepository.self)

        // Then register AuthRepository with AuthSessionRepository dependency
        let authRepo = AuthRepositoryImpl(
            firebaseAuth: resolve(),
            googleSignIn: resolve(),
            appleSignIn: resolve(),
            backendAuth: resolve(),
            authCache: resolve(),
            authSessionRepository: authSessionRepo
        )
        register(authRepo as AuthRepository, forProtocol: AuthRepository.self)

        let onboardingRepo = OnboardingRepositoryImpl(
            firebaseAuth: resolve(),
            backendAuth: resolve(),
            authCache: resolve()
        )
        register(onboardingRepo as OnboardingRepository, forProtocol: OnboardingRepository.self)

        Logger.debug("[DI] Authentication module registered")
    }
}
