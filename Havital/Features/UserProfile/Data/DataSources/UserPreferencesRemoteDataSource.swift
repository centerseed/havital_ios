import Foundation

// MARK: - UserPreferencesRemoteDataSource
/// Handles all API calls related to user preferences
/// Data Layer - Pure HTTP communication, no caching logic
final class UserPreferencesRemoteDataSource {

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

    /// Fetch user preferences from API
    /// - Returns: UserPreferences model
    func getPreferences() async throws -> UserPreferences {
        Logger.debug("[UserPreferencesRemoteDS] Fetching preferences")

        do {
            let rawData = try await httpClient.request(path: "/user/preferences", method: .GET)
            return try ResponseProcessor.extractData(UserPreferences.self, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        }
    }

    /// Update user preferences (language and/or timezone)
    /// - Parameters:
    ///   - language: Language code (optional)
    ///   - timezone: IANA timezone (optional)
    func updatePreferences(language: String?, timezone: String?) async throws {
        Logger.debug("[UserPreferencesRemoteDS] Updating preferences")

        var requestBody: [String: String] = [:]

        if let language = language {
            requestBody["language"] = language
        }
        if let timezone = timezone {
            requestBody["timezone"] = timezone
        }

        guard !requestBody.isEmpty else {
            throw UserProfileError.invalidUpdateData(field: "language or timezone required")
        }

        let body = try JSONEncoder().encode(requestBody)

        do {
            _ = try await httpClient.request(path: "/user/preferences", method: .PUT, body: body)
            Logger.info("[UserPreferencesRemoteDS] Preferences updated: \(requestBody)")
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        }
    }

    /// Update only timezone
    /// - Parameter timezone: IANA timezone identifier
    func updateTimezone(_ timezone: String) async throws {
        try await updatePreferences(language: nil, timezone: timezone)
    }

    /// Update only language
    /// - Parameter language: Language code
    func updateLanguage(_ language: String) async throws {
        try await updatePreferences(language: language, timezone: nil)
    }
}
