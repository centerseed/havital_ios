import Foundation

// MARK: - Backend Auth Data Source
/// Handles backend API calls for authentication
/// Responsible for user sync, onboarding status, and FCM token management
final class BackendAuthDataSource {

    // MARK: - API Endpoints

    private enum Endpoint {
        static let authSync = "/auth/sync"
        static let demoLogin = "/login/demo"
        static let onboardingStatus = "/auth/users/%@/onboarding"
        static let completeOnboarding = "/auth/users/%@/complete-onboarding"
        static let resetOnboarding = "/auth/users/%@/reset-onboarding"
    }

    // MARK: - Dependencies

    private let httpClient: HTTPClient
    private let parser: APIParser

    // MARK: - Initialization

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - User Sync Operations

    /// Sync Firebase user with backend
    /// Creates or updates user in backend database
    /// - Parameter request: User sync request with Firebase UID and tokens
    /// - Returns: User sync response with onboarding status
    /// - Throws: AuthenticationError.backendSyncFailed if sync fails
    func syncUserWithBackend(request: UserSyncRequest) async throws -> UserSyncResponse {
        do {
            // Encode request to JSON
            let bodyData = try JSONEncoder().encode(request)

            // Make HTTP request
            let rawData = try await httpClient.request(
                path: Endpoint.authSync,
                method: .POST,
                body: bodyData
            )

            // Parse response
            let response = try ResponseProcessor.extractData(
                UserSyncResponse.self,
                from: rawData,
                using: parser
            )

            Logger.debug("Backend user sync succeeded: \(request.firebaseUid)")
            return response
        } catch {
            Logger.error("Backend user sync failed: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }

    // MARK: - Onboarding Operations

    /// Get onboarding status for user
    /// - Parameter uid: User unique identifier
    /// - Returns: Onboarding status DTO
    /// - Throws: AuthenticationError.backendSyncFailed if fetch fails
    func getOnboardingStatus(uid: String) async throws -> OnboardingStatusDTO {
        let path = String(format: Endpoint.onboardingStatus, uid)

        do {
            // Make HTTP request
            let rawData = try await httpClient.request(
                path: path,
                method: .GET
            )

            // Parse response
            let response = try ResponseProcessor.extractData(
                OnboardingStatusDTO.self,
                from: rawData,
                using: parser
            )

            Logger.debug("Fetched onboarding status: \(uid)")
            return response
        } catch {
            Logger.error("Failed to fetch onboarding status: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }

    /// Mark onboarding as completed
    /// - Parameters:
    ///   - uid: User unique identifier
    ///   - data: Optional completion data
    /// - Throws: AuthenticationError.backendSyncFailed if completion fails
    func completeOnboarding(uid: String, data: [String: Any]? = nil) async throws {
        let path = String(format: Endpoint.completeOnboarding, uid)

        do {
            // Encode optional data
            let bodyData: Data? = if let data = data {
                try JSONSerialization.data(withJSONObject: data)
            } else {
                nil
            }

            // Make HTTP request (ignore response)
            _ = try await httpClient.request(
                path: path,
                method: .POST,
                body: bodyData
            )

            Logger.debug("Onboarding marked as completed: \(uid)")
        } catch {
            Logger.error("Failed to complete onboarding: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }

    /// Reset onboarding status (admin/debug)
    /// - Parameter uid: User unique identifier
    /// - Throws: AuthenticationError.backendSyncFailed if reset fails
    func resetOnboarding(uid: String) async throws {
        let path = String(format: Endpoint.resetOnboarding, uid)

        do {
            // Make HTTP request (ignore response)
            _ = try await httpClient.request(
                path: path,
                method: .POST
            )

            Logger.debug("Onboarding reset: \(uid)")
        } catch {
            Logger.error("Failed to reset onboarding: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed(error.localizedDescription)
        }
    }

    // MARK: - Demo Login

    /// Demo login for development and testing
    /// - Returns: Demo user information
    /// - Throws: AuthenticationError.backendSyncFailed if login fails
    func demoLogin() async throws -> DemoUserDTO {
        do {
            // Make HTTP request
            let rawData = try await httpClient.request(
                path: Endpoint.demoLogin,
                method: .POST
            )

            // Parse response using DemoLoginResponse from EmailAuthModels
            let response = try parser.parse(DemoLoginResponse.self, from: rawData)

            guard response.success else {
                throw AuthenticationError.firebaseAuthFailed("Demo login API returned success=false")
            }

            Logger.debug("Demo login succeeded: \(response.data.user.uid)")

            return DemoUserDTO(
                uid: response.data.user.uid,
                email: response.data.user.email,
                displayName: response.data.user.displayName,
                idToken: response.data.idToken
            )
        } catch let error as AuthenticationError {
            throw error
        } catch {
            Logger.error("Demo login failed: \(error.localizedDescription)")
            throw AuthenticationError.backendSyncFailed("Demo login failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Demo User DTO

/// Data Transfer Object for Demo Login Response
struct DemoUserDTO {
    let uid: String
    let email: String
    let displayName: String
    let idToken: String
}
