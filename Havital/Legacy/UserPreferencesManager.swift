//
//  UserPreferencesManager.swift
//  Havital
//
//  用戶偏好管理器
//  實現雙軌緩存策略，統一管理用戶偏好設置（語言、時區）
//
//  ⚠️ DEPRECATED - 此檔案已被 Clean Architecture 重構取代
//  請使用: Features/UserProfile/Presentation/ViewModels/UserProfileFeatureViewModel.swift
//  遷移指南: Docs/refactor/REFACTOR-002-Feature-Plans.md (Feature 2: UserProfile)
//  預計刪除日期: Views 遷移完成後

import Foundation
import Combine

/// 用戶偏好管理器
/// 遵循 DataManageable 協議，整合統一緩存系統
/// - Warning: 此類別已被廢棄，請改用 `UserProfileFeatureViewModel`
@available(*, deprecated, message: "Use UserProfileFeatureViewModel from Features/UserProfile instead")
class UserPreferencesManager: ObservableObject, DataManageable {

    // MARK: - Type Definitions
    typealias DataType = UserPreferences
    typealias ServiceType = UserPreferencesService

    // MARK: - Singleton
    static let shared = UserPreferencesManager()

    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?

    // MARK: - User Preferences Data
    @Published var preferences: UserPreferences? {
        didSet {
            // 當偏好設置改變時，保存到緩存
            if let prefs = preferences {
                cacheManager.savePreferences(prefs)
            }
        }
    }

    // MARK: - Private Helpers

    /// 獲取或創建 UserPreferences 實例的輔助方法
    private func getOrCreatePreferences() -> UserPreferences {
        return preferences ?? UserPreferences(
            language: "en",
            timezone: TimeZone.current.identifier
        )
    }

    // MARK: - Computed Properties (與舊版 UserPreferenceManager 兼容)

    /// 數據來源偏好
    var dataSourcePreference: DataSourceType {
        get {
            preferences?.dataSourcePreference ?? .unbound
        }
        set {
            var updated = getOrCreatePreferences()
            updated.dataSourcePreference = newValue
            preferences = updated

            // 發送通知（與舊版兼容）
            NotificationCenter.default.post(
                name: NSNotification.Name("DataSourceDidChange"),
                object: newValue.rawValue
            )
            NotificationCenter.default.post(
                name: .dataSourceChanged,
                object: newValue
            )
            print("數據來源已切換為: \(newValue.displayName)")
        }
    }

    var email: String {
        get { preferences?.email ?? "" }
        set {
            var updated = getOrCreatePreferences()
            updated.email = newValue
            preferences = updated
        }
    }

    var name: String? {
        get { preferences?.name }
        set {
            var updated = getOrCreatePreferences()
            updated.name = newValue
            preferences = updated
        }
    }

    var age: Int? {
        get { preferences?.age }
        set {
            var updated = getOrCreatePreferences()
            updated.age = newValue
            preferences = updated
        }
    }

    var maxHeartRate: Int? {
        get { preferences?.maxHeartRate }
        set {
            var updated = getOrCreatePreferences()
            updated.maxHeartRate = newValue
            preferences = updated
        }
    }

    var restingHeartRate: Int? {
        get { preferences?.restingHeartRate }
        set {
            var updated = getOrCreatePreferences()
            updated.restingHeartRate = newValue
            preferences = updated
        }
    }

    var doNotShowHeartRatePrompt: Bool {
        get { preferences?.doNotShowHeartRatePrompt ?? false }
        set {
            var updated = getOrCreatePreferences()
            updated.doNotShowHeartRatePrompt = newValue
            preferences = updated
        }
    }

    var heartRatePromptNextRemindDate: Date? {
        get { preferences?.heartRatePromptNextRemindDate }
        set {
            var updated = getOrCreatePreferences()
            updated.heartRatePromptNextRemindDate = newValue
            preferences = updated
        }
    }

    var heartRateZones: Data? {
        get { preferences?.heartRateZones }
        set {
            var updated = getOrCreatePreferences()
            updated.heartRateZones = newValue
            preferences = updated
        }
    }

    var currentPace: String? {
        get { preferences?.currentPace }
        set {
            var updated = getOrCreatePreferences()
            updated.currentPace = newValue
            preferences = updated
        }
    }

    var currentDistance: String? {
        get { preferences?.currentDistance }
        set {
            var updated = getOrCreatePreferences()
            updated.currentDistance = newValue
            preferences = updated
        }
    }

    var preferWeekDays: [String]? {
        get { preferences?.preferWeekDays }
        set {
            var updated = getOrCreatePreferences()
            updated.preferWeekDays = newValue
            preferences = updated
        }
    }

    var preferWeekDaysLongRun: [String]? {
        get { preferences?.preferWeekDaysLongRun }
        set {
            var updated = getOrCreatePreferences()
            updated.preferWeekDaysLongRun = newValue
            preferences = updated
        }
    }

    var weekOfTraining: Int? {
        get { preferences?.weekOfTraining }
        set {
            var updated = getOrCreatePreferences()
            updated.weekOfTraining = newValue
            preferences = updated
        }
    }

    var photoURL: String? {
        get { preferences?.photoURL }
        set {
            var updated = getOrCreatePreferences()
            updated.photoURL = newValue
            preferences = updated
        }
    }

    var languagePreference: SupportedLanguage {
        get {
            if let language = preferences?.language,
               let supportedLang = SupportedLanguage(rawValue: language) {
                return supportedLang
            }
            return SupportedLanguage.current
        }
        set {
            Task { @MainActor in
                try? await updatePreferences(language: newValue.rawValue, timezone: nil)
                // Sync with LanguageManager
                LanguageManager.shared.applyFromBackend(newValue)
            }
        }
    }

    var timezonePreference: String? {
        get { preferences?.timezone }
        set {
            if let timezone = newValue {
                Task { @MainActor in
                    try? await updatePreferences(language: nil, timezone: timezone)
                }
            }
        }
    }

    // MARK: - Dependencies
    let service: UserPreferencesService
    private let cacheManager: UserPreferencesCacheManager

    // MARK: - TaskManageable Properties
    let taskRegistry = TaskRegistry()

    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "UserPreferencesManager" }

    // MARK: - Initialization
    private init() {
        self.service = UserPreferencesService.shared
        self.cacheManager = UserPreferencesCacheManager()

        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)

        // 遷移舊版 UserDefaults 數據（首次啟動時執行一次）
        migrateFromUserDefaults()

        // 載入緩存的偏好設置
        loadCachedPreferences()
    }

    // MARK: - Migration Logic

    /// 遷移舊版 UserPreferenceManager 的 UserDefaults 數據到新的緩存系統
    private func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        let migrationKey = "user_preferences_migrated_to_new_manager"

        // 檢查是否已經遷移過
        if defaults.bool(forKey: migrationKey) {
            print("📊 [UserPreferencesManager] 數據已遷移，跳過遷移流程")
            return
        }

        print("📊 [UserPreferencesManager] 開始遷移舊版 UserDefaults 數據")

        // 從 UserDefaults 讀取舊版數據
        let dataSourceRaw = defaults.string(forKey: "data_source_preference") ?? "unbound"
        let dataSource = DataSourceType(rawValue: dataSourceRaw) ?? .unbound

        let email = defaults.string(forKey: "user_email") ?? ""
        let name = defaults.string(forKey: "user_name")
        let age = defaults.object(forKey: "age") as? Int
        let maxHR = defaults.object(forKey: "max_heart_rate") as? Int
        let restingHR = defaults.object(forKey: "resting_heart_rate") as? Int
        let doNotShow = defaults.bool(forKey: "do_not_show_heart_rate_prompt")
        let heartRateZones = defaults.data(forKey: "heart_rate_zones")
        let currentPace = defaults.string(forKey: "current_pace")
        let currentDistance = defaults.string(forKey: "current_distance")
        let preferWeekDays = defaults.array(forKey: "prefer_week_days") as? [String]
        let preferWeekDaysLongRun = defaults.array(forKey: "prefer_week_days_longrun") as? [String]
        let weekOfTraining = defaults.object(forKey: "week_of_training") as? Int
        let photoURL = defaults.string(forKey: "user_photo_url")

        // 處理下次提醒日期
        var nextRemindDate: Date? = nil
        if let timestamp = defaults.object(forKey: "heart_rate_prompt_next_remind_date") as? TimeInterval {
            nextRemindDate = Date(timeIntervalSince1970: timestamp)
        }

        // 語言和時區
        let languageRaw = defaults.string(forKey: "language_preference")
        let language = languageRaw ?? SupportedLanguage.current.rawValue
        let timezone = defaults.string(forKey: "timezone_preference") ?? TimeZone.current.identifier

        // 創建遷移後的 UserPreferences 對象
        let migratedPrefs = UserPreferences(
            language: language,
            timezone: timezone,
            supportedLanguages: [],
            languageNames: [:],
            dataSourcePreference: dataSource,
            email: email.isEmpty ? nil : email,
            name: name,
            age: age,
            maxHeartRate: maxHR == 0 ? nil : maxHR,  // 舊版 0 代表未設定
            restingHeartRate: restingHR == 0 ? nil : restingHR,
            doNotShowHeartRatePrompt: doNotShow,
            heartRatePromptNextRemindDate: nextRemindDate,
            heartRateZones: heartRateZones,
            currentPace: currentPace,
            currentDistance: currentDistance,
            preferWeekDays: preferWeekDays,
            preferWeekDaysLongRun: preferWeekDaysLongRun,
            weekOfTraining: weekOfTraining,
            photoURL: photoURL
        )

        // 保存到新的緩存系統
        self.preferences = migratedPrefs
        cacheManager.savePreferences(migratedPrefs)

        // 標記遷移完成
        defaults.set(true, forKey: migrationKey)

        Logger.firebase(
            "✅ UserPreferences 遷移完成",
            level: .info,
            labels: ["module": "UserPreferencesManager", "action": "migration"],
            jsonPayload: [
                "dataSource": dataSource.rawValue,
                "hasEmail": !email.isEmpty,
                "hasMaxHR": maxHR != nil && maxHR != 0,
                "language": language,
                "timezone": timezone
            ]
        )

        print("📊 [UserPreferencesManager] ✅ 遷移完成，數據已保存到新緩存系統")
    }

    // MARK: - DataManageable Implementation

    func initialize() async {
        Logger.firebase(
            "UserPreferencesManager 初始化",
            level: .info,
            labels: ["module": "UserPreferencesManager", "action": "initialize"]
        )

        await loadData()
    }

    func loadData() async {
        await executeDataLoadingTask(id: "load_user_preferences") {
            try await self.performLoadPreferences()
        }
    }

    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_user_preferences") {
            try await self.performRefreshPreferences()
        } != nil
    }

    func clearAllData() async {
        // 清除內存中的偏好設置
        await MainActor.run {
            preferences = nil
            lastSyncTime = nil
            syncError = nil
        }

        // 清除緩存
        cacheManager.clearCache()

        // 清除其他相關緩存（與舊版兼容）
        TrainingPlanStorage.shared.clearAll()
        WorkoutUploadTracker.shared.clearUploadedWorkouts()

        // 清除用戶偏好相關的 UserDefaults
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "training_plan", "training_plan_overview", "weekly_plan",
            "user_email", "user_name", "age", "max_heart_rate",
            "current_pace", "current_distance", "prefer_week_days",
            "prefer_week_days_longrun", "week_of_training", "user_photo_url",
            "language_preference", "unit_preference", "resting_heart_rate",
            "do_not_show_heart_rate_prompt", "heart_rate_prompt_next_remind_date",
            "heart_rate_zones", "data_source_preference", "timezone_preference",
            "current_vdot", "target_vdot"
        ]

        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        Logger.firebase(
            "用戶偏好數據已清除",
            level: .info,
            labels: ["module": "UserPreferencesManager", "action": "clear_all_data"]
        )
    }

    // MARK: - Cacheable Implementation

    func clearCache() {
        cacheManager.clearCache()
    }

    func getCacheSize() -> Int {
        return cacheManager.getCacheSize()
    }

    func isExpired() -> Bool {
        return cacheManager.isExpired()
    }

    // MARK: - Core Preferences Logic

    /// 執行載入用戶偏好（雙軌緩存策略）
    private func performLoadPreferences() async throws {
        print("📊 [UserPreferencesManager] 開始載入用戶偏好")

        // ✅ 軌道 A: 優先從緩存載入
        if let cachedPrefs = cacheManager.loadPreferences(),
           !cacheManager.shouldRefresh() {
            print("📊 [UserPreferencesManager] ✅ 使用緩存數據")
            await MainActor.run {
                self.preferences = cachedPrefs
            }

            // ✅ 軌道 B: 背景更新
            Task.detached { [weak self] in
                await self?.refreshInBackground()
            }
            return
        }

        print("📊 [UserPreferencesManager] 緩存無效，從 API 獲取")

        // 從 API 獲取
        let prefs = try await service.getPreferences()

        await MainActor.run {
            self.preferences = prefs
        }

        cacheManager.savePreferences(prefs)

        Logger.firebase(
            "用戶偏好載入成功",
            level: .info,
            labels: ["module": "UserPreferencesManager", "action": "load_preferences"],
            jsonPayload: [
                "language": prefs.language,
                "timezone": prefs.timezone
            ]
        )
    }

    /// 執行刷新用戶偏好（強制從 API）
    private func performRefreshPreferences() async throws {
        print("📊 [UserPreferencesManager] 強制刷新用戶偏好")

        let prefs = try await service.getPreferences()

        await MainActor.run {
            self.preferences = prefs
        }

        cacheManager.forceRefreshPreferences(prefs)

        Logger.firebase(
            "用戶偏好刷新成功",
            level: .info,
            labels: ["module": "UserPreferencesManager", "action": "refresh_preferences"]
        )
    }

    /// 背景更新（不阻塞 UI）
    private func refreshInBackground() async {
        do {
            print("📊 [UserPreferencesManager] 背景更新用戶偏好...")
            let latestPrefs = try await service.getPreferences()

            await MainActor.run {
                self.preferences = latestPrefs
            }

            cacheManager.savePreferences(latestPrefs)
            print("📊 [UserPreferencesManager] ✅ 背景更新成功")
        } catch {
            print("📊 [UserPreferencesManager] ⚠️ 背景更新失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - State Management

    private func loadCachedPreferences() {
        if let cachedPrefs = cacheManager.loadPreferences() {
            preferences = cachedPrefs
            print("📊 [UserPreferencesManager] 從緩存載入了偏好設置")
        }
    }

    // MARK: - Public Interface

    /// 獲取用戶偏好（優先從緩存）
    func getPreferences() async -> UserPreferences? {
        print("📊 [UserPreferencesManager] getPreferences 被調用")

        // 如果有緩存且有效，直接返回
        if let prefs = preferences {
            print("📊 [UserPreferencesManager] ✅ 返回內存緩存")
            return prefs
        }

        // 沒有緩存，觸發載入
        print("📊 [UserPreferencesManager] 內存緩存未命中，觸發載入")
        await loadData()
        return preferences
    }

    /// 更新用戶偏好（語言或時區）
    func updatePreferences(language: String? = nil, timezone: String? = nil) async throws {
        print("📊 [UserPreferencesManager] 更新用戶偏好")

        try await service.updatePreferences(language: language, timezone: timezone)

        // 更新後重新載入
        await refreshData()

        Logger.firebase(
            "用戶偏好更新成功",
            level: .info,
            labels: ["module": "UserPreferencesManager", "action": "update_preferences"],
            jsonPayload: [
                "language": language ?? "nil",
                "timezone": timezone ?? "nil"
            ]
        )
    }

    /// 強制刷新用戶偏好（清除緩存）
    func forceRefreshPreferences() async {
        print("📊 [UserPreferencesManager] 強制刷新")
        cacheManager.clearCache()
        await refreshData()
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Helper Methods (與舊版 UserPreferenceManager 兼容)

    /// 檢查是否有必要的心率數據
    func hasHeartRateData() -> Bool {
        guard let maxHR = maxHeartRate,
              let restingHR = restingHeartRate else {
            return false
        }
        return maxHR > restingHR && maxHR > 0 && restingHR > 0
    }

    /// 同步心率數據
    func syncHeartRateData(from user: User?) {
        guard let user = user else { return }

        // 只有當用戶數據中的值大於0時才更新
        if user.maxHr ?? 0 > 0 {
            self.maxHeartRate = user.maxHr
        }

        if user.relaxingHr ?? 0 > 0 {
            self.restingHeartRate = user.relaxingHr
        }

        // 檢查是否可以計算心率區間
        if hasHeartRateData() {
            HeartRateZonesManager.shared.calculateAndSaveHeartRateZones(
                maxHR: maxHeartRate!,
                restingHR: restingHeartRate!
            )
        }
    }

    /// 更新心率數據並計算區間
    func updateHeartRateData(maxHR: Int, restingHR: Int) {
        // 驗證輸入值
        guard maxHR > 0 && restingHR > 0 && maxHR > restingHR else {
            print("無效的心率數據：maxHR = \(maxHR), restingHR = \(restingHR)")
            return
        }

        // 更新數據
        self.maxHeartRate = maxHR
        self.restingHeartRate = restingHR

        // 計算並保存心率區間
        HeartRateZonesManager.shared.calculateAndSaveHeartRateZones(
            maxHR: maxHR,
            restingHR: restingHR
        )

        print("心率數據已更新並計算區間：maxHR = \(maxHR), restingHR = \(restingHR)")
    }

    /// 嘗試從API更新心率數據
    func fetchHeartRateDataFromAPI() async {
        do {
            let user = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
                var cancellable: AnyCancellable?
                cancellable = UserService.shared.getUserProfile().sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { user in
                        continuation.resume(returning: user)
                        cancellable?.cancel()
                    }
                )
            }

            syncHeartRateData(from: user)
        } catch {
            print("從API獲取心率數據失敗：\(error)")
        }
    }

    /// 獲取心率區間
    func getHeartRateZones() -> [HeartRateZonesManager.HeartRateZone]? {
        // 如果沒有保存的區間數據，返回nil
        guard let _ = heartRateZones else { return nil }

        return HeartRateZonesManager.shared.getHeartRateZones()
    }

    /// 獲取存儲的VDOT數據
    func getVDOTData() -> VDOTData? {
        if let currentVDOT = UserDefaults.standard.object(forKey: "current_vdot") as? Double,
           let targetVDOT = UserDefaults.standard.object(forKey: "target_vdot") as? Double {
            return VDOTData(currentVDOT: currentVDOT, targetVDOT: targetVDOT)
        }
        return nil
    }

    /// 保存VDOT數據
    func saveVDOTData(currentVDOT: Double, targetVDOT: Double) {
        UserDefaults.standard.set(currentVDOT, forKey: "current_vdot")
        UserDefaults.standard.set(targetVDOT, forKey: "target_vdot")
    }

    /// 檢查是否需要初始化時區設定
    func needsTimezoneInitialization() -> Bool {
        return timezonePreference == nil
    }

    /// 使用裝置時區初始化時區偏好
    func initializeTimezoneFromDevice() {
        let deviceTimezone = TimeZone.current.identifier
        self.timezonePreference = deviceTimezone
        Logger.firebase("時區已從裝置初始化: \(deviceTimezone)", level: .info)
    }

    /// 獲取裝置當前時區（IANA 格式）
    static func getDeviceTimezone() -> String {
        return TimeZone.current.identifier
    }

    /// 獲取時區的本地化顯示名稱
    static func getTimezoneDisplayName(for identifier: String) -> String {
        guard let timezone = TimeZone(identifier: identifier) else {
            return identifier
        }
        return timezone.localizedName(for: .standard, locale: Locale.current) ?? identifier
    }
}

// MARK: - Helper Data Models

extension UserPreferencesManager {
    /// VDOT数据模型
    struct VDOTData {
        let currentVDOT: Double?
        let targetVDOT: Double?
    }
}

// MARK: - Cache Manager

private class UserPreferencesCacheManager: BaseCacheManagerTemplate<UserPreferencesCacheData> {

    init() {
        super.init(identifier: "user_preferences", defaultTTL: 3600) // 1 小時
    }

    // MARK: - Specialized Cache Methods

    func savePreferences(_ preferences: UserPreferences) {
        let cacheData = UserPreferencesCacheData(preferences: preferences)
        saveToCache(cacheData)
    }

    func loadPreferences() -> UserPreferences? {
        return loadFromCache()?.preferences
    }

    func forceRefreshPreferences(_ preferences: UserPreferences) {
        let cacheData = UserPreferencesCacheData(preferences: preferences)
        forceRefresh(with: cacheData)
    }
}

// MARK: - Cache Data Structure

private struct UserPreferencesCacheData: Codable {
    let preferences: UserPreferences
}

// MARK: - Compatibility
/// 為舊代碼提供兼容性支持
typealias UserPreferenceManager = UserPreferencesManager
