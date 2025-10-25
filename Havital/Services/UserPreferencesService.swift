import Foundation

/// Service for managing user preferences (language, timezone)
class UserPreferencesService {
    static let shared = UserPreferencesService()

    private init() {}

    // MARK: - Data Models

    struct UserPreferences: Codable {
        let language: String
        let timezone: String
        let supportedLanguages: [String]
        let languageNames: [String: String]

        enum CodingKeys: String, CodingKey {
            case language
            case timezone
            case supportedLanguages = "supported_languages"
            case languageNames = "language_names"
        }
    }

    struct PreferencesResponse: Codable {
        let success: Bool
        let data: UserPreferences
    }

    struct UpdatePreferencesRequest: Codable {
        let timezone: String?
        let language: String?

        init(timezone: String? = nil, language: String? = nil) {
            self.timezone = timezone
            self.language = language
        }
    }

    struct UpdatePreferencesResponse: Codable {
        let success: Bool
        let message: String
        let data: PreferencesData

        struct PreferencesData: Codable {
            let timezone: String?
            let language: String?
        }
    }

    // MARK: - API Methods

    /// 獲取用戶偏好設定
    func getPreferences() async throws -> UserPreferences {
        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/user/preferences")!)
        request.httpMethod = "GET"

        // Add authentication token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            Logger.firebase("Failed to get auth token: \(error.localizedDescription)", level: .warn)
            throw error
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.firebase("獲取偏好設定失敗: HTTP \(statusCode)", level: .error)
            throw NSError(domain: "UserPreferencesService", code: statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch user preferences"
            ])
        }

        let apiResponse = try JSONDecoder().decode(PreferencesResponse.self, from: data)
        Logger.firebase("成功獲取用戶偏好設定", level: .info, labels: [
            "language": apiResponse.data.language,
            "timezone": apiResponse.data.timezone
        ])

        return apiResponse.data
    }

    /// 更新用戶偏好設定
    func updatePreferences(timezone: String? = nil, language: String? = nil) async throws -> UpdatePreferencesResponse {
        guard timezone != nil || language != nil else {
            throw NSError(domain: "UserPreferencesService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "At least one of timezone or language must be provided"
            ])
        }

        var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/user/preferences")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authentication token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            Logger.firebase("Failed to get auth token: \(error.localizedDescription)", level: .warn)
            throw error
        }

        // Prepare request body
        let requestBody = UpdatePreferencesRequest(timezone: timezone, language: language)
        request.httpBody = try JSONEncoder().encode(requestBody)

        Logger.firebase("更新用戶偏好設定", level: .info, labels: [
            "timezone": timezone ?? "nil",
            "language": language ?? "nil"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.firebase("更新偏好設定失敗: HTTP \(statusCode)", level: .error)
            throw NSError(domain: "UserPreferencesService", code: statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to update user preferences"
            ])
        }

        let apiResponse = try JSONDecoder().decode(UpdatePreferencesResponse.self, from: data)
        Logger.firebase("成功更新用戶偏好設定: \(apiResponse.message)", level: .info)

        return apiResponse
    }

    /// 僅更新時區
    func updateTimezone(_ timezone: String) async throws {
        _ = try await updatePreferences(timezone: timezone, language: nil)
    }

    /// 僅更新語言
    func updateLanguage(_ language: String) async throws {
        _ = try await updatePreferences(timezone: nil, language: language)
    }
}
