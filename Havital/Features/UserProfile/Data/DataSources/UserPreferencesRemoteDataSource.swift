import Foundation

// MARK: - UserPreferencesRemoteDataSource Protocol
protocol UserPreferencesRemoteDataSourceProtocol {
    func getPreferences() async throws -> UserPreferences
    func updatePreferences(language: String?, timezone: String?, unitSystem: String?) async throws
    func updateTimezone(_ timezone: String) async throws
    func updateLanguage(_ language: String) async throws
}

// MARK: - UserPreferencesRemoteDataSource
/// Handles all API calls related to user preferences
/// Data Layer - Pure HTTP communication, no caching logic
/// Uses APICallHelper for unified error handling
final class UserPreferencesRemoteDataSource: UserPreferencesRemoteDataSourceProtocol {

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    // MARK: - Initialization

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "UserPreferencesRemoteDS"
        )
    }

    // MARK: - API Methods

    /// Fetch user preferences from API
    /// - Returns: UserPreferences model
    func getPreferences() async throws -> UserPreferences {
        Logger.debug("[UserPreferencesRemoteDS] Fetching preferences")
        return try await apiHelper.get(UserPreferences.self, path: "/user/preferences")
    }

    /// Update user preferences (language, timezone, and/or unit system)
    /// - Parameters:
    ///   - language: Language code (optional)
    ///   - timezone: IANA timezone (optional)
    ///   - unitSystem: Unit system rawValue e.g. "metric" / "imperial" (optional)
    func updatePreferences(language: String?, timezone: String?, unitSystem: String? = nil) async throws {
        Logger.debug("[UserPreferencesRemoteDS] Updating preferences")

        var requestBody: [String: String] = [:]

        if let language = language {
            requestBody["language"] = language
        }
        if let timezone = timezone {
            requestBody["timezone"] = timezone
        }
        if let unitSystem = unitSystem {
            requestBody["unit_system"] = unitSystem
        }

        guard !requestBody.isEmpty else {
            throw UserProfileError.invalidUpdateData(field: "at least one field required")
        }

        let body = try JSONEncoder().encode(requestBody)
        try await apiHelper.callNoResponse(path: "/user/preferences", method: .PUT, body: body)
        Logger.info("[UserPreferencesRemoteDS] Preferences updated: \(requestBody)")
    }

    /// Update only timezone
    /// - Parameter timezone: IANA timezone identifier
    func updateTimezone(_ timezone: String) async throws {
        try await updatePreferences(language: nil, timezone: timezone, unitSystem: nil)
    }

    /// Update only language
    /// - Parameter language: Language code
    func updateLanguage(_ language: String) async throws {
        try await updatePreferences(language: language, timezone: nil, unitSystem: nil)
    }
}
