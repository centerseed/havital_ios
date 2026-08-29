import Foundation

// MARK: - DataSourceSwitchCoordinator
/// 切換主要資料來源（Apple Health / Garmin / Strava / 解除綁定）的**唯一**執行路徑。
///
/// 這段流程原本整段寫在 `UserProfileView.switchDataSource(to:)` 裡（1.4 設定頁）。
/// 2.0 的「數據來源」子頁（設計 frame-24／25）需要同一個行為 —— 查過既有實作：
/// `UserProfileFeatureViewModel.updateAndSyncDataSource` 只寫偏好與後端，
/// `AppViewModel.switchDataSource` 只清 workout 快取（Garmin mismatch 警示專用），
/// 兩者都不含解綁與 OAuth。所以把 View 裡那段抽出來給兩個版面共用，**不複製第二份**。
/// 抽出時行為逐段照搬，沒有改寫順序或加解除條件。
///
/// 為什麼是 Domain/Managers：它協調的是既有的 `GarminManager`／`StravaManager`／
/// `HealthKitManager`／偏好寫入，不自己碰 HTTP，也不持有 UI 狀態。
///
/// 偏好寫入走 [DataSourcePreferenceWriting] 抽象——Domain 不 import presentation 型別，
/// `UserProfileFeatureViewModel` 在 presentation 側 conform（2026-08-29 外審 C03：
/// 依賴方向必須是 Presentation → Domain，不得反向持有 ViewModel）。
// MARK: - DataSourcePreferenceWriting
/// 資料來源偏好的寫入口（目前的值＋寫後端並同步）。Domain 只依賴這個抽象；
/// presentation 的 `UserProfileFeatureViewModel` conform 它。
@MainActor
protocol DataSourcePreferenceWriting: AnyObject {
    var currentDataSource: DataSourceType { get set }
    func updateAndSyncDataSource(_ dataSource: DataSourceType) async throws
}

@MainActor
struct DataSourceSwitchCoordinator {

    private let profileViewModel: any DataSourcePreferenceWriting
    private let garminManager: GarminManager
    private let stravaManager: StravaManager
    private let healthKitManager: HealthKitManager

    init(
        profileViewModel: any DataSourcePreferenceWriting,
        garminManager: GarminManager = .shared,
        stravaManager: StravaManager = .shared,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.profileViewModel = profileViewModel
        self.garminManager = garminManager
        self.stravaManager = stravaManager
        self.healthKitManager = healthKitManager
    }

    /// OAuth 流程最長等待時間（秒）——沿用 1.4 的 30 秒。
    private static let oauthTimeout: TimeInterval = 30

    func switchDataSource(to newDataSource: DataSourceType) async {
        switch newDataSource {
        case .unbound:
            profileViewModel.currentDataSource = .unbound
            do {
                try await profileViewModel.updateAndSyncDataSource(newDataSource)
                Logger.debug("[DataSourceSwitch] 數據源設定已同步到後端: \(newDataSource.displayName)")
            } catch {
                Logger.error("[DataSourceSwitch] 同步數據源設定到後端失敗: \(error.localizedDescription)")
            }

        case .appleHealth:
            await disconnectGarminIfNeeded()
            await disconnectStravaIfNeeded(target: "appleHealth")

            do {
                try await healthKitManager.requestAuthorization()
                Logger.debug("[DataSourceSwitch] Apple Health 權限請求成功")
            } catch {
                // 即使權限請求失敗，也繼續切換數據源（1.4 既有行為）。
                Logger.debug("[DataSourceSwitch] Apple Health 權限請求失敗: \(error.localizedDescription)")
            }

            profileViewModel.currentDataSource = .appleHealth

            do {
                try await profileViewModel.updateAndSyncDataSource(newDataSource)
                Logger.firebase("切換到Apple Health成功", level: .info, labels: [
                    "module": "DataSourceSwitchCoordinator",
                    "action": "switchDataSource",
                    "target": "appleHealth"
                ])
            } catch is CancellationError {
                Logger.debug("[DataSourceSwitch] 同步數據源設定已取消")
            } catch {
                Logger.firebase("切換到Apple Health失敗", level: .error, labels: [
                    "module": "DataSourceSwitchCoordinator",
                    "action": "switchDataSource",
                    "target": "appleHealth",
                    "error": error.localizedDescription
                ])
            }

        case .garmin:
            await disconnectStravaIfNeeded(target: "garmin")
            // 總是啟動 OAuth：確保連接狀態最新，並處理 token 過期。
            // 數據源偏好的更新在 OAuth 成功後由 `GarminManager` 處理。
            await garminManager.startConnection()
            await waitForOAuth { garminManager.isConnecting }

        case .strava:
            await disconnectGarminIfNeeded()
            await stravaManager.startConnection()
            await waitForOAuth { stravaManager.isConnecting }
        }
    }

    /// 中斷目前來源（設計 frame-24 的「中斷」鈕）——落到既有的 `.unbound` 路徑。
    func disconnectCurrentSource() async {
        await disconnectGarminIfNeeded()
        await disconnectStravaIfNeeded(target: "unbound")
        await switchDataSource(to: .unbound)
    }

    // MARK: - Private

    private func disconnectGarminIfNeeded() async {
        guard garminManager.isConnected else { return }
        do {
            let result = try await GarminDisconnectService.shared.disconnectGarmin()
            Logger.debug("[DataSourceSwitch] Garmin解除綁定成功: \(result.message)")
        } catch {
            Logger.error("[DataSourceSwitch] Garmin解除綁定失敗: \(error.localizedDescription)")
        }
        // 不論後端成功與否都本地斷開（remote: false 避免重複調用）。
        await garminManager.disconnect(remote: false)
    }

    private func disconnectStravaIfNeeded(target: String) async {
        guard stravaManager.isConnected else { return }
        do {
            let result = try await StravaDisconnectService.shared.disconnectStrava()
            Logger.debug("[DataSourceSwitch] Strava解除綁定成功: \(result.message)")
            await stravaManager.disconnect(remote: false)
        } catch is CancellationError {
            Logger.debug("[DataSourceSwitch] Strava解除綁定已取消")
        } catch {
            Logger.error("[DataSourceSwitch] Strava解除綁定失敗: \(error.localizedDescription)")
            await stravaManager.disconnect(remote: false)
            Logger.firebase("切換數據源時Strava斷開失敗", level: .error, labels: [
                "module": "DataSourceSwitchCoordinator",
                "action": "switchDataSource",
                "target": target,
                "error": error.localizedDescription
            ])
        }
    }

    private func waitForOAuth(_ isConnecting: () -> Bool) async {
        let startTime = Date()
        while isConnecting(), Date().timeIntervalSince(startTime) < Self.oauthTimeout {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}
