//
//  TimezoneSyncCoordinator.swift
//  Havital
//
//  T-0430：啟動時的時區同步決策。
//
//  根因：`GET /user/preferences` 在後端沒有紀錄時區時會回預設值（目前是
//  Asia/Taipei），這個值不能拿來判斷「後端是否已經設定過時區」。真正的訊號是
//  `timezone_is_set`（T-0428 Contract 11，缺席視為 false）。
//
//  寫回後端的唯一路徑就是這裡的 `run()`；PUT 失敗直接放棄、不落地任何「已同步」
//  標記，下次啟動 `timezone_is_set` 仍是 false，會自然重試（不吞錯誤、不用額外的
//  本地旗標）。
//
//  決策邏輯抽成可注入 `TimezoneSyncGateway`，讓 Contract 3 的三個案例可以用純
//  mock 測，不必真的碰網路或 `UserPreferencesManager.shared` 單例。
//  （查過 `LanguageManager.changeLanguageWithBackendSync()` 的 decide-then-PUT 模式，
//  但它直接綁死 `DefaultHTTPClient.shared`，沒有可注入的測試縫，不適合直接沿用。）

import Foundation

/// 抽象掉 `UserPreferencesManager.shared` 的網路/本地讀寫，方便單元測試注入 mock。
protocol TimezoneSyncGateway {
    /// 向後端拉取最新偏好；回傳 nil 代表拉取失敗（本次啟動放棄，下次再試）。
    func fetchBackendTimezoneStatus() async -> (timezoneIsSet: Bool, timezone: String)?
    /// 本地目前記錄的時區（純讀取，不觸發網路）。
    var localTimezone: String? { get }
    /// 顯式 PUT 裝置時區到後端；失敗要 throw，呼叫方負責 log 且不吞。
    func putTimezone(_ timezone: String) async throws
    /// 純本地寫入（不觸發網路），用來把本地緩存同步成後端已存在的值。
    func syncLocalTimezone(_ timezone: String)
}

/// 用現行 `UserPreferencesManager.shared` 實作 `TimezoneSyncGateway`。
struct UserPreferencesManagerTimezoneSyncGateway: TimezoneSyncGateway {
    func fetchBackendTimezoneStatus() async -> (timezoneIsSet: Bool, timezone: String)? {
        let refreshed = await UserPreferencesManager.shared.refreshData()
        guard refreshed, let prefs = UserPreferencesManager.shared.preferences else {
            return nil
        }
        return (prefs.timezoneIsSet, prefs.timezone)
    }

    var localTimezone: String? {
        UserPreferencesManager.shared.timezonePreference
    }

    func putTimezone(_ timezone: String) async throws {
        try await UserPreferencesManager.shared.updatePreferences(timezone: timezone)
    }

    func syncLocalTimezone(_ timezone: String) {
        UserPreferencesManager.shared.timezonePreference = timezone
    }
}

/// 這次啟動實際做了什麼，方便測試斷言。
enum TimezoneSyncOutcome: Equatable {
    case fetchFailed
    case putSucceeded(String)
    case putFailed
    case alreadySet
    case localSynced(String)
}

/// 啟動時的時區同步流程（T-0430 Contract 1）。
struct TimezoneSyncCoordinator {
    let gateway: TimezoneSyncGateway
    let deviceTimezoneProvider: () -> String
    let log: (String) -> Void

    init(
        gateway: TimezoneSyncGateway = UserPreferencesManagerTimezoneSyncGateway(),
        deviceTimezoneProvider: @escaping () -> String = { TimeZone.current.identifier },
        log: @escaping (String) -> Void = { print($0) }
    ) {
        self.gateway = gateway
        self.deviceTimezoneProvider = deviceTimezoneProvider
        self.log = log
    }

    @discardableResult
    func run() async -> TimezoneSyncOutcome {
        guard let status = await gateway.fetchBackendTimezoneStatus() else {
            log("⏰ [TimezoneSync] fetch backend preferences failed, skipping this launch, will retry next launch")
            return .fetchFailed
        }

        guard !status.timezoneIsSet else {
            log("⏰ [TimezoneSync] backend timezone already set, no initialization needed")
            if let local = gateway.localTimezone, local != status.timezone {
                log("⏰ [TimezoneSync] local timezone differs from backend, syncing local to backend value")
                gateway.syncLocalTimezone(status.timezone)
                return .localSynced(status.timezone)
            }
            return .alreadySet
        }

        let deviceTimezone = deviceTimezoneProvider()
        log("⏰ [TimezoneSync] backend timezone not set yet, writing device timezone: \(deviceTimezone)")

        do {
            try await gateway.putTimezone(deviceTimezone)
            log("⏰ [TimezoneSync] timezone synced to backend: \(deviceTimezone)")
            return .putSucceeded(deviceTimezone)
        } catch {
            log("⏰ [TimezoneSync] PUT to backend failed, will retry next launch: \(error.localizedDescription)")
            return .putFailed
        }
    }
}
