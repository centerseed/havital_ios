//
//  UserPreferencesService.swift
//  Havital
//
//  用戶偏好設定服務（語言和時區）
//  遵循新架構：HTTPClient + APIParser 模式
//

import Foundation

// MARK: - 數據來源類型定義
/// 定義 App 的數據來源類型
enum DataSourceType: String, CaseIterable, Identifiable {
    case unbound = "unbound"
    case appleHealth = "apple_health"
    case garmin = "garmin"
    case strava = "strava"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .unbound:
            return L10n.DataSource.notConnected.localized
        case .appleHealth:
            return L10n.DataSource.appleHealth.localized
        case .garmin:
            return "Garmin"
        case .strava:
            return "Strava"
        }
    }
}

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
    // API 返回的字段
    var language: String
    var timezone: String
    var supportedLanguages: [String]
    var languageNames: [String: String]

    // 本地管理的字段（不從 API 獲取，僅本地存儲）
    var dataSourcePreference: DataSourceType?
    var email: String?
    var name: String?
    var age: Int?
    var maxHeartRate: Int?
    var restingHeartRate: Int?
    var doNotShowHeartRatePrompt: Bool?
    var heartRatePromptNextRemindDate: Date?
    var heartRateZones: Data?
    var currentPace: String?
    var currentDistance: String?
    var preferWeekDays: [String]?
    var preferWeekDaysLongRun: [String]?
    var weekOfTraining: Int?
    var photoURL: String?

    enum CodingKeys: String, CodingKey {
        case language
        case timezone
        case supportedLanguages = "supported_languages"
        case languageNames = "language_names"
        // 本地字段不參與 API 編解碼
    }

    // MARK: - Custom Decoding (from API)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decode(String.self, forKey: .language)
        timezone = try container.decode(String.self, forKey: .timezone)
        supportedLanguages = try container.decode([String].self, forKey: .supportedLanguages)
        languageNames = try container.decode([String: String].self, forKey: .languageNames)

        // 本地字段初始化為 nil，由 UserPreferencesManager 從緩存載入
        dataSourcePreference = nil
        email = nil
        name = nil
        age = nil
        maxHeartRate = nil
        restingHeartRate = nil
        doNotShowHeartRatePrompt = nil
        heartRatePromptNextRemindDate = nil
        heartRateZones = nil
        currentPace = nil
        currentDistance = nil
        preferWeekDays = nil
        preferWeekDaysLongRun = nil
        weekOfTraining = nil
        photoURL = nil
    }

    // MARK: - Custom Encoding (for API - only encode API fields)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(supportedLanguages, forKey: .supportedLanguages)
        try container.encode(languageNames, forKey: .languageNames)
        // 本地字段不編碼到 API
    }

    // MARK: - Manual Initializer (for local creation)
    init(
        language: String,
        timezone: String,
        supportedLanguages: [String] = [],
        languageNames: [String: String] = [:],
        dataSourcePreference: DataSourceType? = nil,
        email: String? = nil,
        name: String? = nil,
        age: Int? = nil,
        maxHeartRate: Int? = nil,
        restingHeartRate: Int? = nil,
        doNotShowHeartRatePrompt: Bool? = nil,
        heartRatePromptNextRemindDate: Date? = nil,
        heartRateZones: Data? = nil,
        currentPace: String? = nil,
        currentDistance: String? = nil,
        preferWeekDays: [String]? = nil,
        preferWeekDaysLongRun: [String]? = nil,
        weekOfTraining: Int? = nil,
        photoURL: String? = nil
    ) {
        self.language = language
        self.timezone = timezone
        self.supportedLanguages = supportedLanguages
        self.languageNames = languageNames
        self.dataSourcePreference = dataSourcePreference
        self.email = email
        self.name = name
        self.age = age
        self.maxHeartRate = maxHeartRate
        self.restingHeartRate = restingHeartRate
        self.doNotShowHeartRatePrompt = doNotShowHeartRatePrompt
        self.heartRatePromptNextRemindDate = heartRatePromptNextRemindDate
        self.heartRateZones = heartRateZones
        self.currentPace = currentPace
        self.currentDistance = currentDistance
        self.preferWeekDays = preferWeekDays
        self.preferWeekDaysLongRun = preferWeekDaysLongRun
        self.weekOfTraining = weekOfTraining
        self.photoURL = photoURL
    }
}

/// 時區選項（用於 UI 顯示）
struct TimezoneOption: Identifiable, Equatable {
    let id: String  // IANA 時區 ID (例如 "Asia/Taipei")
    let displayName: String  // 顯示名稱 (例如 "台北")
    let offset: String  // 時區偏移 (例如 "GMT+8")

    // MARK: - Static Utility Methods

    /// 獲取裝置當前時區 ID（IANA 格式）
    static func getDeviceTimezoneId() -> String {
        return TimeZone.current.identifier
    }

    /// 獲取時區的本地化顯示名稱
    /// - Parameter identifier: IANA 時區 ID
    /// - Returns: 本地化顯示名稱
    static func getDisplayName(for identifier: String) -> String {
        guard let timezone = TimeZone(identifier: identifier) else {
            return identifier
        }
        return timezone.localizedName(for: .standard, locale: Locale.current) ?? identifier
    }

    /// 計算時區的 GMT 偏移字串
    /// - Parameter identifier: IANA 時區 ID
    /// - Returns: 例如 "GMT+8" 或 "GMT-5"
    static func getCurrentOffset(for identifier: String) -> String {
        guard let tz = TimeZone(identifier: identifier) else {
            return "GMT"
        }
        let offsetSeconds = tz.secondsFromGMT()
        let offsetHours = offsetSeconds / 3600
        let offsetMinutes = abs(offsetSeconds % 3600) / 60

        if offsetMinutes == 0 {
            return String(format: "GMT%+d", offsetHours)
        } else {
            return String(format: "GMT%+d:%02d", offsetHours, offsetMinutes)
        }
    }

    // MARK: - Common Timezones

    /// 常用時區 ID 列表
    private static let commonTimezoneIds: [String] = [
        "Asia/Taipei",
        "Asia/Tokyo",
        "Asia/Hong_Kong",
        "Asia/Singapore",
        "Asia/Seoul",
        "America/New_York",
        "America/Los_Angeles",
        "Europe/London",
        "Australia/Sydney"
    ]

    /// 常用時區列表（動態計算偏移量）
    static var commonTimezones: [TimezoneOption] {
        return commonTimezoneIds.map { id in
            makeTimezoneOption(from: id)
        }
    }

    /// 從 IANA 時區 ID 創建 TimezoneOption
    /// - Parameter identifier: IANA 時區 ID
    /// - Returns: TimezoneOption 實例
    static func makeTimezoneOption(from identifier: String) -> TimezoneOption {
        let localizedNames: [String: String] = [
            "Asia/Taipei": NSLocalizedString("timezone.taipei", comment: "台北"),
            "Asia/Tokyo": NSLocalizedString("timezone.tokyo", comment: "東京"),
            "Asia/Hong_Kong": NSLocalizedString("timezone.hong_kong", comment: "香港"),
            "Asia/Singapore": NSLocalizedString("timezone.singapore", comment: "新加坡"),
            "Asia/Seoul": NSLocalizedString("timezone.seoul", comment: "首爾"),
            "America/New_York": NSLocalizedString("timezone.new_york", comment: "紐約"),
            "America/Los_Angeles": NSLocalizedString("timezone.los_angeles", comment: "洛杉磯"),
            "Europe/London": NSLocalizedString("timezone.london", comment: "倫敦"),
            "Australia/Sydney": NSLocalizedString("timezone.sydney", comment: "雪梨")
        ]

        let displayName = localizedNames[identifier] ?? getDisplayName(for: identifier)
        let offset = getCurrentOffset(for: identifier)

        return TimezoneOption(id: identifier, displayName: displayName, offset: offset)
    }

    /// 獲取裝置當前時區
    static var deviceTimezone: TimezoneOption {
        let tzIdentifier = TimeZone.current.identifier

        // 如果在常用時區列表中，返回完整資訊
        if commonTimezoneIds.contains(tzIdentifier) {
            return makeTimezoneOption(from: tzIdentifier)
        }

        // 否則創建自訂時區選項
        return TimezoneOption(
            id: tzIdentifier,
            displayName: getDisplayName(for: tzIdentifier),
            offset: getCurrentOffset(for: tzIdentifier)
        )
    }
}
