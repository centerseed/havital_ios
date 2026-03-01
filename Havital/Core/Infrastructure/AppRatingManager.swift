import Foundation
import StoreKit
import SwiftUI

/// App 評分管理器
/// 負責在適當時機調用 Apple 原生評分彈窗
class AppRatingManager: ObservableObject, @preconcurrency TaskManageable {

    // MARK: - TaskManageable Properties
    let taskRegistry = TaskRegistry()

    // MARK: - Dependencies
    private let userService = UserService.shared
    private let userProfileLocalDataSource = UserProfileLocalDataSource()
    private let trainingPlanLocalDataSource = TrainingPlanLocalDataSource()

    // MARK: - Local Cache Keys
    private let hasPromptedKey = "app_rating_has_prompted"
    private let promptCountKey = "app_rating_prompt_count"
    private let lastPromptDateKey = "app_rating_last_prompt_date"

    // MARK: - Singleton
    static let shared = AppRatingManager()

    private init() {}

    // MARK: - Public Methods

    /// 清除本地評分記錄（測試用）
    func clearLocalRatingCache() {
        UserDefaults.standard.removeObject(forKey: hasPromptedKey)
        UserDefaults.standard.removeObject(forKey: promptCountKey)
        UserDefaults.standard.removeObject(forKey: lastPromptDateKey)
        print("🧹 [AppRatingManager] 已清除本地評分快取")

        Logger.firebase(
            "清除本地評分快取",
            level: .info,
            labels: ["action": "clear_rating_cache"]
        )
    }

    /// 強制顯示評分彈窗（跳過所有檢查，測試用）
    @MainActor
    func forceShowRating() async {
        print("🔧 [AppRatingManager] 強制顯示評分（測試模式）")

        // 記錄 debug 信息到 Firebase
        let cachedUser = userProfileLocalDataSource.getUserProfile()
        Logger.firebase(
            "強制顯示評分測試",
            level: .info,
            labels: [
                "user_exists": String(cachedUser != nil),
                "overview_exists": String(trainingPlanLocalDataSource.getOverview() != nil),
                "prompt_count": String(cachedUser?.ratingPromptCount ?? -1)
            ]
        )

        requestSystemReview()
    }

    /// 獲取當前評分狀態信息（用於 debug）
    func getRatingDebugInfo() -> [String: Any] {
        let user = userProfileLocalDataSource.getUserProfile()
        let overview = trainingPlanLocalDataSource.getOverview()

        let currentWeek = overview.flatMap { TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: $0.createdAt) } ?? 0

        return [
            "user_loaded": user != nil,
            "overview_loaded": overview != nil,
            "prompt_count": user?.ratingPromptCount ?? 0,
            "last_prompt_date": user?.lastRatingPromptDate ?? "never",
            "current_week": currentWeek,
            "local_prompt_count": UserDefaults.standard.integer(forKey: promptCountKey),
            "local_last_date": UserDefaults.standard.string(forKey: lastPromptDateKey) ?? "never"
        ]
    }

    /// 在 App 啟動時檢查是否應顯示評分提示
    @MainActor
    func checkOnAppLaunch(delaySeconds: Double = 0) async {

        // 可配置的延遲時間
        if delaySeconds > 0 {
            print("⏳ [AppRatingManager] 延遲 \(delaySeconds) 秒後檢查...")
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }

        print("🎯 [AppRatingManager] 開始檢查評分條件")
        print("   - UserProfile cache 是否存在: \(userProfileLocalDataSource.getUserProfile() != nil)")
        print("   - TrainingPlanOverview cache 是否存在: \(trainingPlanLocalDataSource.getOverview() != nil)")

        // 記錄檢查開始到 Firebase（用於 TestFlight debug）
        let debugInfo = getRatingDebugInfo()
        Logger.firebase(
            "評分檢查開始",
            level: .info,
            labels: ["action": "rating_check_start"],
            jsonPayload: debugInfo
        )

        guard await shouldPromptForRating() else {
            print("⚠️ [AppRatingManager] 不符合評分提示條件")

            // 記錄失敗原因到 Firebase
            Logger.firebase(
                "評分檢查失敗",
                level: .info,
                labels: ["action": "rating_check_failed"],
                jsonPayload: debugInfo
            )
            return
        }

        // 記錄檢查通過到 Firebase
        Logger.firebase(
            "評分檢查通過，顯示評分彈窗",
            level: .info,
            labels: ["action": "rating_check_passed"],
            jsonPayload: debugInfo
        )

        // 直接調用 Apple 原生評分彈窗
        requestSystemReview()

        // 記錄已提示
        await recordPromptShown()
    }

    /// 調用 Apple 原生評分彈窗
    @MainActor
    func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            Logger.firebase(
                "無法獲取 WindowScene",
                level: .error,
                labels: ["action": "request_system_review"]
            )
            return
        }

        SKStoreReviewController.requestReview(in: scene)
        print("✅ [AppRatingManager] 已調用 Apple 原生評分彈窗")

        Logger.firebase(
            "調用系統評分彈窗",
            level: .info,
            labels: ["action": "request_system_review"]
        )
    }

    /// 記錄評分提示已顯示
    private func recordPromptShown() async {
        await executeTask(id: TaskID("record_prompt_shown")) { [weak self] in
            guard let self = self else { return }

            let currentCount = self.userProfileLocalDataSource.getUserProfile()?.ratingPromptCount ?? UserDefaults.standard.integer(forKey: self.promptCountKey)
            let newCount = currentCount + 1
            let dateString = ISO8601DateFormatter().string(from: Date())

            // 先更新本地快取（立即生效）
            UserDefaults.standard.set(newCount, forKey: self.promptCountKey)
            UserDefaults.standard.set(dateString, forKey: self.lastPromptDateKey)
            print("✅ [AppRatingManager] 已記錄提示：promptCount=\(newCount), lastPromptDate=\(dateString)")

            // 嘗試更新後端（失敗不影響本地）
            do {
                try await self.userService.recordRatingPrompt(
                    promptCount: newCount,
                    lastPromptDate: dateString
                )
                print("✅ [AppRatingManager] 已同步後端")
            } catch {
                print("⚠️ [AppRatingManager] 後端同步失敗（本地已記錄）: \(error.localizedDescription)")
            }

            Logger.firebase(
                "評分提示已記錄",
                level: .info,
                labels: ["prompt_count": String(newCount)]
            )
        }
    }

    // MARK: - Private Methods

    /// 判斷是否應顯示評分提示
    private func shouldPromptForRating() async -> Bool {
        guard let user = userProfileLocalDataSource.getUserProfile() else {
            Logger.firebase(
                "❌ 用戶資料未載入",
                level: .debug,
                labels: ["action": "should_prompt_rating"]
            )
            print("⚠️ [AppRatingManager] 用戶資料未載入")
            return false
        }

        print("✅ [AppRatingManager] 用戶資料已載入")
        print("   - ratingPromptCount: \(user.ratingPromptCount?.description ?? "nil")")
        print("   - lastRatingPromptDate: \(user.lastRatingPromptDate ?? "nil")")

        // 1. 檢查用戶使用時長（至少第 2 週）- 使用 TrainingDateUtils 計算實際週數
        let trainingOverview = TrainingPlanStorage.loadTrainingPlanOverview()
        
        if trainingOverview.id == "" {
            print("⚠️ [AppRatingManager] 訓練計劃未載入，跳過提示")
            return false
        }

        let currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: trainingOverview.createdAt) ?? 0
        print("   - 實際訓練週數: \(currentWeek) (從 createdAt 計算)")

        if currentWeek < 2 {
            print("⚠️ [AppRatingManager] 用戶使用時間不足（第 \(currentWeek) 週），跳過提示")
            return false
        }

        // 2. 檢查年度次數限制（最多 3 次，後端優先，本地快取備用）
        let promptCount = user.ratingPromptCount ?? UserDefaults.standard.integer(forKey: promptCountKey)
        print("   - 當前提示次數: \(promptCount) (後端: \(user.ratingPromptCount?.description ?? "nil"), 本地: \(UserDefaults.standard.integer(forKey: promptCountKey)))")
        if promptCount >= 3 {
            Logger.firebase(
                "❌ 達到年度提示上限",
                level: .debug,
                labels: ["action": "should_prompt_rating", "count": String(promptCount)]
            )
            print("⚠️ [AppRatingManager] 達到年度提示上限（\(promptCount)次），跳過提示")
            return false
        }

        // 3. 檢查時間間隔（至少 90 天，後端優先，本地快取備用）
        let lastDateString = user.lastRatingPromptDate ?? UserDefaults.standard.string(forKey: lastPromptDateKey)
        
        if let dateString = lastDateString {
            let daysSinceLastPrompt = calculateDaysSince(dateString: dateString)
            print("   - 距離上次提示: \(daysSinceLastPrompt) 天")
            if daysSinceLastPrompt < 90 {
                Logger.firebase(
                    "❌ 距離上次提示不足 90 天",
                    level: .debug,
                    labels: [
                        "action": "should_prompt_rating",
                        "days_since_last": String(daysSinceLastPrompt)
                    ]
                )
                print("⚠️ [AppRatingManager] 距離上次提示不足 30 天（\(daysSinceLastPrompt)天），跳過提示")
                return false
            }
        } else {
            print("   - 首次提示（無歷史記錄）")
        }

        print("✅ [AppRatingManager] 所有檢查通過，應顯示評分提示")
        return true
    }

    /// 計算距離指定日期的天數
    private func calculateDaysSince(dateString: String) -> Int {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return Int.max // 無法解析日期時，視為很久以前
        }

        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days
    }

    deinit {
        cancelAllTasks()
    }
}

// MARK: - Rating Trigger Enum

/// 評分觸發時機
enum RatingTrigger: String {
    case appLaunch = "app_launch"  // App 啟動時檢查
}
