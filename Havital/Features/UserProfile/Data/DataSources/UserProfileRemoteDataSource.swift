import Foundation

// MARK: - UserProfileRemoteDataSource Protocol
protocol UserProfileRemoteDataSourceProtocol {
    func getUserProfile() async throws -> User
    func updateUserProfile(_ updates: [String: Any]) async throws
    func updateDataSource(_ dataSource: String) async throws
    func updatePersonalBest(_ performanceData: [String: Any]) async throws
    func deleteUser(userId: String) async throws
    func getTargets() async throws -> [Target]
    func createTarget(_ target: Target) async throws
    func recordRatingPrompt(promptCount: Int, lastPromptDate: String) async throws
}

// MARK: - UserProfileRemoteDataSource
/// Handles all API calls related to user profile
/// Data Layer - Pure HTTP communication, no caching logic
final class UserProfileRemoteDataSource: UserProfileRemoteDataSourceProtocol {

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

    // MARK: - API Methods

    /// Fetch user profile from API
    /// - Returns: User model
    func getUserProfile() async throws -> User {
        Logger.debug("[UserProfileRemoteDS] Fetching user profile")

        do {
            let rawData = try await httpClient.request(path: "/user", method: .GET)
            return try ResponseProcessor.extractData(User.self, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        }
    }

    /// Update user profile data
    /// - Parameter updates: Dictionary of fields to update
    func updateUserProfile(_ updates: [String: Any]) async throws {
        Logger.debug("[UserProfileRemoteDS] Updating user profile")

        let body = try JSONSerialization.data(withJSONObject: updates)

        do {
            _ = try await httpClient.request(path: "/user", method: .PUT, body: body)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        }
    }

    /// Update data source setting
    /// - Parameter dataSource: Data source identifier (apple_health, garmin, strava, unbound)
    func updateDataSource(_ dataSource: String) async throws {
        Logger.debug("[UserProfileRemoteDS] Updating data source: \(dataSource)")

        let updates: [String: Any] = ["data_source": dataSource]
        try await updateUserProfile(updates)
    }

    /// Update personal best data
    /// - Parameter performanceData: Performance data dictionary
    func updatePersonalBest(_ performanceData: [String: Any]) async throws {
        Logger.debug("[UserProfileRemoteDS] Updating personal best")

        let body = try JSONSerialization.data(withJSONObject: performanceData)

        do {
            _ = try await httpClient.request(path: "/user/pb/race_run", method: .POST, body: body)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        }
    }

    /// Delete user account
    /// - Parameter userId: User ID to delete
    func deleteUser(userId: String) async throws {
        Logger.debug("[UserProfileRemoteDS] Deleting user: \(userId)")

        do {
            _ = try await httpClient.request(path: "/user/\(userId)", method: .DELETE)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        }
    }

    /// Fetch user targets
    /// - Returns: Array of Target models
    func getTargets() async throws -> [Target] {
        Logger.debug("[UserProfileRemoteDS] Fetching targets")

        do {
            let rawData = try await httpClient.request(path: "/user/targets", method: .GET)
            return try ResponseProcessor.extractData([Target].self, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            // Return empty array if API returns 404 or empty
            Logger.debug("[UserProfileRemoteDS] No targets found, returning empty array")
            return []
        }
    }

    /// Create a new target
    /// - Parameter target: Target to create
    func createTarget(_ target: Target) async throws {
        Logger.debug("[UserProfileRemoteDS] Creating target: \(target.name)")

        let body = try JSONEncoder().encode(target)

        do {
            _ = try await httpClient.request(path: "/user/targets", method: .POST, body: body)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        }
    }

    /// Record app rating prompt
    /// - Parameters:
    ///   - promptCount: Number of times prompt was shown
    ///   - lastPromptDate: Last prompt date (ISO8601 string)
    func recordRatingPrompt(promptCount: Int, lastPromptDate: String) async throws {
        Logger.debug("[UserProfileRemoteDS] Recording rating prompt")

        let ratingData: [String: Any] = [
            "rating_prompt_count": promptCount,
            "last_rating_prompt_date": lastPromptDate
        ]
        try await updateUserProfile(ratingData)
    }
}
