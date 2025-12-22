import Foundation
import SwiftUI

/// 協調 Onboarding Backfill 流程的管理器
///
/// 職責：
/// - 判斷是否需要顯示 backfill 提示
/// - 檢查用戶是否已有訓練資料
/// - 追蹤 backfill 完成狀態
class OnboardingBackfillCoordinator: ObservableObject {
    static let shared = OnboardingBackfillCoordinator()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let completed = "onboarding_backfill_completed"
        static let lastAttemptDate = "onboarding_backfill_last_attempt"
        static let skippedByUser = "onboarding_backfill_skipped"
    }

    // MARK: - Properties

    private let workoutV2Service = WorkoutV2Service.shared
    private let userDefaults = UserDefaults.standard

    private init() {}

    // MARK: - Public Methods

    /// 判斷是否應該顯示 backfill 提示
    ///
    /// 判斷邏輯：
    /// 1. 檢查是否已完成過 backfill
    /// 2. 檢查資料來源（只支援 Garmin 和 Strava）
    /// 3. 檢查用戶是否已有訓練資料（舊用戶）
    ///
    /// - Parameter dataSource: 用戶選擇的資料來源
    /// - Returns: true 表示需要顯示提示，false 表示跳過
    func shouldShowBackfillPrompt(dataSource: DataSourceType) async -> Bool {
        Logger.debug("OnboardingBackfillCoordinator: 開始檢查是否需要顯示 backfill 提示")
        Logger.debug("  - 資料來源: \(dataSource.rawValue)")

        // 1. 檢查是否已完成過 backfill
        if hasCompletedBackfill() {
            Logger.debug("  - 已完成過 backfill，跳過")
            return false
        }

        // 2. 檢查是否被用戶跳過（在本次 onboarding 中）
        if wasSkippedByUser() {
            Logger.debug("  - 用戶已選擇跳過，不再顯示")
            return false
        }

        // 3. 只支援 Garmin 和 Strava
        guard dataSource == .garmin || dataSource == .strava else {
            Logger.debug("  - 資料來源不支援 backfill (只支援 Garmin 和 Strava)")
            markBackfillCompleted() // Apple Health 直接標記為完成
            return false
        }

        // 4. 檢查用戶是否已有訓練資料（舊用戶）
        let hasWorkouts = await hasExistingWorkoutData()
        if hasWorkouts {
            Logger.debug("  - 用戶已有訓練資料（舊用戶），跳過 backfill")
            markBackfillCompleted() // 自動標記為完成
            return false
        }

        Logger.debug("  - ✅ 需要顯示 backfill 提示")
        return true
    }

    /// 標記 backfill 已完成
    func markBackfillCompleted() {
        Logger.debug("OnboardingBackfillCoordinator: 標記 backfill 已完成")
        userDefaults.set(true, forKey: Keys.completed)
        userDefaults.set(Date(), forKey: Keys.lastAttemptDate)
        userDefaults.removeObject(forKey: Keys.skippedByUser) // 清除跳過標記

        Logger.firebase("Onboarding backfill 已完成", level: .info, labels: [
            "module": "OnboardingBackfillCoordinator",
            "action": "markCompleted"
        ])
    }

    /// 標記用戶選擇跳過 backfill
    func markSkippedByUser() {
        Logger.debug("OnboardingBackfillCoordinator: 用戶選擇跳過 backfill")
        userDefaults.set(true, forKey: Keys.skippedByUser)

        Logger.firebase("用戶跳過 Onboarding backfill", level: .info, labels: [
            "module": "OnboardingBackfillCoordinator",
            "action": "userSkipped"
        ])
    }

    /// 重置 backfill 狀態（用於測試或重新 onboarding）
    func resetBackfillState() {
        Logger.debug("OnboardingBackfillCoordinator: 重置 backfill 狀態")
        userDefaults.removeObject(forKey: Keys.completed)
        userDefaults.removeObject(forKey: Keys.lastAttemptDate)
        userDefaults.removeObject(forKey: Keys.skippedByUser)
    }

    // MARK: - Private Methods

    /// 檢查是否已完成過 backfill
    private func hasCompletedBackfill() -> Bool {
        return userDefaults.bool(forKey: Keys.completed)
    }

    /// 檢查是否被用戶跳過
    private func wasSkippedByUser() -> Bool {
        return userDefaults.bool(forKey: Keys.skippedByUser)
    }

    /// 檢查用戶是否已有訓練資料
    ///
    /// 策略：查詢近 30 天內是否有任何訓練記錄
    ///
    /// - Returns: true 表示有資料（舊用戶），false 表示沒有資料（新用戶）
    private func hasExistingWorkoutData() async -> Bool {
        do {
            Logger.debug("OnboardingBackfillCoordinator: 檢查是否有現有訓練資料...")

            // 計算日期範圍：過去 30 天
            let endDate = Date()
            guard let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) else {
                Logger.error("OnboardingBackfillCoordinator: 無法計算開始日期")
                return false
            }

            // 使用 pageSize: 1 最小化 API 調用，只需確認有無資料
            let startDateString = ISO8601DateFormatter().string(from: startDate)
            let endDateString = ISO8601DateFormatter().string(from: endDate)

            let response = try await workoutV2Service.fetchWorkouts(
                pageSize: 1,
                startDate: startDateString,
                endDate: endDateString
            )

            let hasData = !response.workouts.isEmpty
            Logger.debug("  - 查詢結果: \(hasData ? "有" : "無")訓練資料")

            if hasData {
                Logger.firebase("檢測到舊用戶有訓練資料", level: .info, labels: [
                    "module": "OnboardingBackfillCoordinator",
                    "action": "checkExistingData",
                    "result": "has_data"
                ], jsonPayload: [
                    "workout_count": response.workouts.count
                ])
            }

            return hasData

        } catch {
            // 如果查詢失敗，保守處理：假設沒有資料（顯示 backfill 提示）
            Logger.error("OnboardingBackfillCoordinator: 查詢訓練資料失敗: \(error.localizedDescription)")

            // 檢查是否為取消錯誤
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                Logger.debug("  - 查詢被取消，假設沒有資料")
                return false
            }

            Logger.firebase("查詢現有訓練資料失敗", level: .warn, labels: [
                "module": "OnboardingBackfillCoordinator",
                "action": "checkExistingData",
                "result": "error"
            ], jsonPayload: [
                "error": error.localizedDescription
            ])

            return false
        }
    }
}
