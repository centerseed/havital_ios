import Foundation
import WatchConnectivity
import Combine

/// Watch 同步設置
struct WatchSyncSettings: Codable {
    var autoSync: Bool = true                    // 自動同步開關
    var syncOnPlanChange: Bool = true            // 課表變更時同步
    var syncInterval: TimeInterval = 3600        // 自動同步間隔（1小時）

    // UserDefaults key
    static let userDefaultsKey = "watchSyncSettings"

    static func load() -> WatchSyncSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(WatchSyncSettings.self, from: data) else {
            return WatchSyncSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: WatchSyncSettings.userDefaultsKey)
        }
    }
}

/// WatchConnectivity 服務（iOS 端）
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isWatchPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isReachable: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?

    private var session: WCSession?
    private let logger = Logger.shared
    private var backgroundTask: Task<Void, Never>?
    private var settings: WatchSyncSettings

    private override init() {
        self.settings = WatchSyncSettings.load()
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }

        // 啟動背景同步（如果啟用）
        if settings.autoSync {
            startBackgroundSync()
        }
    }

    // MARK: - 公開 API

    /// 同步當週課表到 Watch
    func syncWeeklyPlan() async {
        logger.debug("WatchConnectivity: 開始同步週課表")

        guard let session = session, session.isPaired, session.isWatchAppInstalled else {
            await MainActor.run {
                self.syncError = "Apple Watch 未配對或未安裝 app"
            }
            logger.warning("WatchConnectivity: Apple Watch 未準備好")
            return
        }

        do {
            // 獲取用戶數據
            guard let userProfile = try await buildUserProfile() else {
                throw WatchSyncError.userDataNotAvailable
            }

            // 獲取當週課表
            let weeklyPlan = try await buildWeeklyPlan()

            // 構建同步數據
            let syncData = WatchSyncData(
                weeklyPlan: weeklyPlan,
                userProfile: userProfile
            )

            // 編碼並發送
            let data = try JSONEncoder().encode(syncData)

            if session.isReachable {
                // Watch 可達，使用實時消息
                try await sendMessage(data: data)
            } else {
                // Watch 不可達，使用 application context（背景傳輸）
                try await updateApplicationContext(data: data)
            }

            await MainActor.run {
                self.lastSyncTime = Date()
                self.syncError = nil
            }

            logger.info("WatchConnectivity: 同步成功")
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
            }
            logger.error("WatchConnectivity: 同步失敗 - \(error.localizedDescription)")
        }
    }

    /// 更新同步設置
    func updateSettings(_ newSettings: WatchSyncSettings) {
        settings = newSettings
        settings.save()

        // 根據設置啟動或停止背景同步
        if settings.autoSync {
            startBackgroundSync()
        } else {
            stopBackgroundSync()
        }

        logger.info("WatchConnectivity: 同步設置已更新 - autoSync: \(settings.autoSync)")
    }

    /// 獲取當前設置
    func getSettings() -> WatchSyncSettings {
        return settings
    }

    // MARK: - 私有方法

    private func buildUserProfile() async throws -> WatchUserProfile? {
        let userPrefs = UserPreferenceManager.shared

        // 獲取心率數據
        guard let maxHR = userPrefs.userMaxHeartRate,
              let restingHR = userPrefs.userRestingHeartRate else {
            logger.warning("WatchConnectivity: 心率數據未設置")
            return nil
        }

        // 獲取 VDOT
        guard let vdot = userPrefs.userVdot else {
            logger.warning("WatchConnectivity: VDOT 未設置")
            return nil
        }

        // 計算心率區間
        let zones = HeartRateZonesManager.shared.calculateHeartRateZones(
            maxHR: maxHR,
            restingHR: restingHR
        )

        return WatchUserProfile(
            maxHR: maxHR,
            restingHR: restingHR,
            vdot: vdot,
            zones: zones
        )
    }

    private func buildWeeklyPlan() async throws -> WatchWeeklyPlan? {
        // 獲取訓練計劃管理器
        let planManager = TrainingPlanManager.shared

        // 等待訓練概覽載入
        guard let overview = planManager.trainingOverview else {
            logger.info("WatchConnectivity: 尚無訓練計劃")
            return nil
        }

        // 獲取當週課表
        guard let weeklyPlan = planManager.weeklyPlan else {
            logger.info("WatchConnectivity: 當週課表尚未載入")
            return nil
        }

        return WatchWeeklyPlan(from: weeklyPlan)
    }

    private func sendMessage(data: Data) async throws {
        guard let session = session, session.isReachable else {
            throw WatchSyncError.watchNotReachable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let message: [String: Any] = [
                "type": "sync_data",
                "data": data
            ]

            session.sendMessage(message, replyHandler: { reply in
                logger.debug("WatchConnectivity: 收到 Watch 回應")
                continuation.resume()
            }, errorHandler: { error in
                logger.error("WatchConnectivity: 發送失敗 - \(error.localizedDescription)")
                continuation.resume(throwing: error)
            })
        }
    }

    private func updateApplicationContext(data: Data) async throws {
        guard let session = session else {
            throw WatchSyncError.sessionNotAvailable
        }

        let context: [String: Any] = [
            "type": "sync_data",
            "data": data,
            "timestamp": Date().timeIntervalSince1970
        ]

        try session.updateApplicationContext(context)
        logger.info("WatchConnectivity: Application Context 已更新")
    }

    private func startBackgroundSync() {
        stopBackgroundSync()  // 停止舊的

        backgroundTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(settings.syncInterval * 1_000_000_000))

                if !Task.isCancelled {
                    await syncWeeklyPlan()
                }
            }
        }

        logger.info("WatchConnectivity: 背景同步已啟動")
    }

    private func stopBackgroundSync() {
        backgroundTask?.cancel()
        backgroundTask = nil
        logger.info("WatchConnectivity: 背景同步已停止")
    }

    // MARK: - 錯誤定義

    enum WatchSyncError: LocalizedError {
        case sessionNotAvailable
        case watchNotReachable
        case userDataNotAvailable
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .sessionNotAvailable:
                return "WatchConnectivity session 不可用"
            case .watchNotReachable:
                return "Apple Watch 無法連接"
            case .userDataNotAvailable:
                return "用戶數據未設置"
            case .encodingFailed:
                return "數據編碼失敗"
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }

        if let error = error {
            logger.error("WatchConnectivity: 激活失敗 - \(error.localizedDescription)")
        } else {
            logger.info("WatchConnectivity: 激活成功 - state: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WatchConnectivity: Session 變為 inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WatchConnectivity: Session 已 deactivate")
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        logger.info("WatchConnectivity: 可達性變更 - reachable: \(session.isReachable)")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        logger.debug("WatchConnectivity: 收到 Watch 消息")

        // 處理來自 Watch 的同步請求
        if let type = message["type"] as? String, type == "sync_request" {
            Task {
                await syncWeeklyPlan()
            }
        }
    }
}
