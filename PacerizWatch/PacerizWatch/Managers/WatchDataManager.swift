import Foundation
import WatchConnectivity
import Combine

/// watchOS 端數據管理器
@MainActor
class WatchDataManager: NSObject, ObservableObject {
    static let shared = WatchDataManager()

    @Published var weeklyPlan: WatchWeeklyPlan?
    @Published var userProfile: WatchUserProfile?
    @Published var lastSyncTime: Date?
    @Published var isLoading: Bool = false
    @Published var syncError: String?

    private var session: WCSession?
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.havital.paceriz")

    private override init() {
        super.init()

        // 從本地緩存載入
        loadFromCache()

        // 設置 WatchConnectivity
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - 公開 API

    /// 請求同步（手動刷新）
    func requestSync() async {
        isLoading = true
        syncError = nil

        guard let session = session, session.isReachable else {
            syncError = "iPhone 不在附近"
            isLoading = false
            return
        }

        let message: [String: Any] = ["type": "sync_request"]

        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
                session.sendMessage(message, replyHandler: { reply in
                    continuation.resume(returning: reply)
                }, errorHandler: { error in
                    continuation.resume(throwing: error)
                })
            }

            syncError = nil
        } catch {
            syncError = "同步失敗: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 獲取指定日期的訓練
    func getTraining(for date: Date) -> WatchTrainingDay? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        return weeklyPlan?.days.first { $0.dayIndex == dateString }
    }

    /// 獲取今天的訓練
    func getTodayTraining() -> WatchTrainingDay? {
        return getTraining(for: Date())
    }

    // MARK: - 私有方法

    private func loadFromCache() {
        // 載入週課表
        if let planData = appGroupDefaults?.data(forKey: "weeklyPlan"),
           let plan = try? JSONDecoder().decode(WatchWeeklyPlan.self, from: planData) {
            self.weeklyPlan = plan
        }

        // 載入用戶配置
        if let profileData = appGroupDefaults?.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(WatchUserProfile.self, from: profileData) {
            self.userProfile = profile
        }

        // 載入同步時間
        if let timestamp = appGroupDefaults?.double(forKey: "lastSyncTime") {
            self.lastSyncTime = Date(timeIntervalSince1970: timestamp)
        }
    }

    private func saveToCache() {
        // 保存週課表
        if let plan = weeklyPlan,
           let data = try? JSONEncoder().encode(plan) {
            appGroupDefaults?.set(data, forKey: "weeklyPlan")
        }

        // 保存用戶配置
        if let profile = userProfile,
           let data = try? JSONEncoder().encode(profile) {
            appGroupDefaults?.set(data, forKey: "userProfile")
        }

        // 保存同步時間
        if let syncTime = lastSyncTime {
            appGroupDefaults?.set(syncTime.timeIntervalSince1970, forKey: "lastSyncTime")
        }
    }

    private func handleSyncData(_ data: Data) {
        do {
            let syncData = try JSONDecoder().decode(WatchSyncData.self, from: data)

            self.weeklyPlan = syncData.weeklyPlan
            self.userProfile = syncData.userProfile
            self.lastSyncTime = syncData.lastSyncTime

            saveToCache()

            print("✅ WatchDataManager: 數據同步成功")
        } catch {
            print("❌ WatchDataManager: 解碼失敗 - \(error.localizedDescription)")
            self.syncError = "數據解碼失敗"
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchDataManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WatchDataManager: 激活失敗 - \(error.localizedDescription)")
        } else {
            print("✅ WatchDataManager: 激活成功")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            if let type = message["type"] as? String, type == "sync_data",
               let data = message["data"] as? Data {
                handleSyncData(data)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            if let type = applicationContext["type"] as? String, type == "sync_data",
               let data = applicationContext["data"] as? Data {
                handleSyncData(data)
            }
        }
    }
}
