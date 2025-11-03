//
//  UserPreferencesManager.swift
//  Havital
//
//  用戶偏好管理器
//  實現雙軌緩存策略，統一管理用戶偏好設置（語言、時區）
//

import Foundation
import Combine

/// 用戶偏好管理器
/// 遵循 DataManageable 協議，整合統一緩存系統
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
    @Published var preferences: UserPreferences?

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

        // 載入緩存的偏好設置
        loadCachedPreferences()
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
        await MainActor.run {
            preferences = nil
            lastSyncTime = nil
            syncError = nil
        }

        cacheManager.clearCache()

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
