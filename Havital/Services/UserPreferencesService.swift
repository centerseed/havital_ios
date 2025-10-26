//
//  UserPreferencesService.swift
//  Havital
//
//  用戶偏好設定服務（語言和時區）
//  遵循新架構：HTTPClient + APIParser 模式
//
//  ⚠️ MERGE CONFLICT NOTICE ⚠️
//  此檔案在 dev_strava 分支已存在舊版本（使用 URLSession 直接調用）
//  合併時請保留此新架構版本（與 TrainingPlanService/UserService 一致）
//  主要差異：
//  - 新版：使用 HTTPClient + APIParser（統一架構）
//  - 舊版：使用 URLSession.shared（直接調用）
//

import Foundation

/// 用戶偏好設定 API 服務
final class UserPreferencesService {
    static let shared = UserPreferencesService()

    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser

    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Unified API Call Method

    /// 統一的 API 調用方法
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }

    // MARK: - API Methods

    /// 獲取用戶偏好設定
    /// - Returns: 用戶偏好設定（語言、時區等）
    func getPreferences() async throws -> UserPreferences {
        return try await makeAPICall(UserPreferences.self, path: "/user/preferences")
    }

    /// 更新用戶偏好設定
    /// - Parameters:
    ///   - language: 語言代碼（可選，例如 "zh-TW"）
    ///   - timezone: 時區（可選，IANA 格式，例如 "Asia/Taipei"）
    /// - Throws: APIError 如果請求失敗
    func updatePreferences(language: String? = nil, timezone: String? = nil) async throws {
        var requestBody: [String: String] = [:]

        if let language = language {
            requestBody["language"] = language
        }
        if let timezone = timezone {
            requestBody["timezone"] = timezone
        }

        guard !requestBody.isEmpty else {
            throw APIError.system(SystemError.unknownError("至少需要提供語言或時區其中之一"))
        }

        let body = try JSONEncoder().encode(requestBody)
        _ = try await httpClient.request(path: "/user/preferences", method: .PUT, body: body)

        Logger.info("用戶偏好設定已更新: \(requestBody)")
    }

    /// 更新時區設定
    /// - Parameter timezone: IANA 時區格式（例如 "Asia/Taipei"）
    func updateTimezone(_ timezone: String) async throws {
        try await updatePreferences(timezone: timezone)
    }

    /// 更新語言設定
    /// - Parameter language: 語言代碼（例如 "zh-TW", "ja-JP", "en-US"）
    func updateLanguage(_ language: String) async throws {
        try await updatePreferences(language: language)
    }
}

// MARK: - Data Models

/// 用戶偏好設定模型
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

/// 時區選項（用於 UI 顯示）
struct TimezoneOption: Identifiable, Equatable {
    let id: String  // IANA 時區 ID (例如 "Asia/Taipei")
    let displayName: String  // 顯示名稱 (例如 "台北 (GMT+8)")
    let offset: String  // 時區偏移 (例如 "GMT+8")

    /// 常用時區列表
    static let commonTimezones: [TimezoneOption] = [
        TimezoneOption(id: "Asia/Taipei", displayName: NSLocalizedString("timezone.taipei", comment: "台北"), offset: "GMT+8"),
        TimezoneOption(id: "Asia/Tokyo", displayName: NSLocalizedString("timezone.tokyo", comment: "東京"), offset: "GMT+9"),
        TimezoneOption(id: "Asia/Hong_Kong", displayName: NSLocalizedString("timezone.hong_kong", comment: "香港"), offset: "GMT+8"),
        TimezoneOption(id: "Asia/Singapore", displayName: NSLocalizedString("timezone.singapore", comment: "新加坡"), offset: "GMT+8"),
        TimezoneOption(id: "Asia/Seoul", displayName: NSLocalizedString("timezone.seoul", comment: "首爾"), offset: "GMT+9"),
        TimezoneOption(id: "America/New_York", displayName: NSLocalizedString("timezone.new_york", comment: "紐約"), offset: "GMT-5/-4"),
        TimezoneOption(id: "America/Los_Angeles", displayName: NSLocalizedString("timezone.los_angeles", comment: "洛杉磯"), offset: "GMT-8/-7"),
        TimezoneOption(id: "Europe/London", displayName: NSLocalizedString("timezone.london", comment: "倫敦"), offset: "GMT+0/+1"),
        TimezoneOption(id: "Australia/Sydney", displayName: NSLocalizedString("timezone.sydney", comment: "雪梨"), offset: "GMT+10/+11")
    ]

    /// 獲取裝置當前時區
    static var deviceTimezone: TimezoneOption {
        let tzIdentifier = TimeZone.current.identifier

        // 如果在常用時區列表中，返回完整資訊
        if let common = commonTimezones.first(where: { $0.id == tzIdentifier }) {
            return common
        }

        // 否則創建自訂時區選項
        let tz = TimeZone.current
        let displayName = tz.localizedName(for: .standard, locale: Locale.current) ?? tzIdentifier
        let offsetSeconds = tz.secondsFromGMT()
        let offsetHours = offsetSeconds / 3600
        let offsetString = String(format: "GMT%+d", offsetHours)

        return TimezoneOption(id: tzIdentifier, displayName: displayName, offset: offsetString)
    }
}
