import Foundation
import HealthKit
import UserNotifications
import BackgroundTasks
import UIKit

// 完整的工作記錄背景管理器，含所有必要方法，支持心率資料檢查
//
// ⚠️ DEPRECATED: 此類需要重構為 UseCase 模式
// 遷移計劃:
// 1. 創建 SyncWorkoutsBackgroundUseCase
// 2. 使用 WorkoutRepository 替代直接 Service 調用
// 3. 移除 Singleton 模式，改用依賴注入
@available(*, deprecated, message: "Needs refactoring to UseCase pattern")
class WorkoutBackgroundManager: NSObject, @preconcurrency TaskManageable {

    // MARK: - Observer Debouncer
    // 用於合併多次 HKObserverQuery 回調，避免重複處理
    private actor ObserverDebouncer {
        private var pendingTask: Task<Void, Never>?
        private let debounceDelay: UInt64

        init(debounceDelay: UInt64 = 20_000_000_000) { // 預設 20 秒
            self.debounceDelay = debounceDelay
        }

        /// 排程一個 debounced 執行。取消任何待處理的任務並排程新任務。
        func debounce(action: @escaping @Sendable () async -> Void) {
            // 取消任何現有的待處理任務
            pendingTask?.cancel()

            // 創建新任務
            pendingTask = Task {
                do {
                    try await Task.sleep(nanoseconds: debounceDelay)

                    // 只有在未被取消時才執行
                    if !Task.isCancelled {
                        await action()
                    }
                } catch {
                    // Task 被取消，不做任何事
                }
            }
        }

        /// 取消任何待處理的 debounced 任務
        func cancel() {
            pendingTask?.cancel()
            pendingTask = nil
        }
    }
    static let shared = WorkoutBackgroundManager()
    
    private let healthStore = HKHealthStore()
    private let workoutService = WorkoutV2Service.shared
    private let workoutUploadTracker = WorkoutUploadTracker.shared
    private let notificationCenter = UNUserNotificationCenter.current()
    private let healthKitManager = HealthKitManager()
    
    // 通知控制
    private var lastNotificationTime: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastWorkoutSyncNotificationTime") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastWorkoutSyncNotificationTime")
            UserDefaults.standard.synchronize()
        }
    }
    private let notificationCooldown: TimeInterval = 3600 // 1小時冷卻時間，只在必要時通知
    
    // TaskRegistry for thread-safe task management
    let taskRegistry = TaskRegistry()
    
    // 批量同步狀態追蹤
    private var syncTotalCount = 0
    private var syncSuccessCount = 0
    private var isFirstLoginSync = false
    
    // 防止過度觸發的冷卻機制
    private var lastUploadCheckTime: Date?
    private let uploadCheckCooldown: TimeInterval = 30 // 30秒冷卻時間（減少連續運動上傳延遲）
    private var isCurrentlyProcessing = false
    
    // 使用中的觀察查詢
    private var activeObserverQuery: HKObserverQuery?
    private var isObservingWorkouts = false

    // Observer 回調 debouncer（合併多次 HealthKit 回調）
    private let observerDebouncer = ObserverDebouncer(debounceDelay: 20_000_000_000) // 20秒
    
    // 跑步相關的活動類型
    private let runningActivityTypes: [HKWorkoutActivityType] = [
        .running,
        .trackAndField,
        .walking,
        .hiking,
        .mixedCardio,
        .crossTraining
    ]
    
    // 心率數據的最小要求筆數
    private let minHeartRateDataPoints = 5
    
    // 重試閾值時間（秒）
    private let retryThresholdTime: TimeInterval = 3600 // 1小時
    
    // MARK: - 公開方法
    
    // 標記應用第一次登入/重新登入
    func markFirstLogin() {
        isFirstLoginSync = true
        
        // 清除之前的通知
        clearAllWorkoutNotifications()
    }
    
    // 設置觀察者來監聯新的健身記錄 - 修正版
    func setupWorkoutObserver() async {
        // 🔧 多來源判定：避免單一 cache 損壞導致誤判
        let dataSourcePreference = UserPreferencesManager.shared.dataSourcePreference
        let appStateDataSource = await MainActor.run { AppStateManager.shared.userDataSource }
        let isAppleHealthUser = dataSourcePreference == .appleHealth || appStateDataSource == .appleHealth

        print("當前數據來源設定: prefs=\(dataSourcePreference.rawValue), appState=\(appStateDataSource.rawValue)")

        // 📊 Firebase 日誌：記錄 Observer 設置開始
        Logger.firebase(
            "設置 Workout Observer",
            level: .info,
            labels: ["module": "WorkoutBackgroundManager", "action": "setup_observer", "cloud_logging": "true"],
            jsonPayload: [
                "dataSource_userPrefs": dataSourcePreference.rawValue,
                "dataSource_appState": appStateDataSource.rawValue,
                "isAppleHealthUser": isAppleHealthUser,
                "isObservingWorkouts": isObservingWorkouts
            ]
        )

        // 只有 Apple Health 用戶才需要啟動 HealthKit 觀察者
        guard isAppleHealthUser else {
            print("數據來源非 Apple Health，跳過 HealthKit 觀察者設置")
            Logger.firebase(
                "Observer 設置跳過：非 Apple Health",
                level: .info,
                labels: ["module": "WorkoutBackgroundManager", "action": "setup_observer_skipped", "cloud_logging": "true"],
                jsonPayload: [
                    "dataSource_userPrefs": dataSourcePreference.rawValue,
                    "dataSource_appState": appStateDataSource.rawValue
                ]
            )
            stopObservingWorkouts() // 確保停止任何現有的觀察者
            return
        }

        // 1a. 請求 HealthKit 授權（核心功能）
        var healthKitAuthorized = true
        do {
            try await requestHealthKitAuthorizationCore()
        } catch {
            healthKitAuthorized = false
            print("⚠️ HealthKit 授權請求失敗: \(error.localizedDescription)，仍嘗試設置 Observer")
            Logger.firebase(
                "HealthKit 授權失敗 - Observer 可能無法收到更新，用戶需到 設定 > 健康 開啟授權",
                level: .error,
                labels: ["module": "WorkoutBackgroundManager", "action": "healthkit_auth_failed", "cloud_logging": "true"],
                jsonPayload: ["error": error.localizedDescription]
            )
        }

        // 1b. 請求通知授權（非核心，不影響 Observer）
        await requestNotificationAuthorization()

        // 2. 診斷：檢查 HealthKit 授權狀態（write 類型可檢查，read 類型永遠 notDetermined）
        let workoutWriteStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        Logger.firebase(
            "HealthKit 授權狀態診斷",
            level: .info,
            labels: ["module": "WorkoutBackgroundManager", "action": "auth_status_check", "cloud_logging": "true"],
            jsonPayload: [
                "healthKitAuthorized": healthKitAuthorized,
                "workoutWriteStatus": "\(workoutWriteStatus.rawValue)",
                "isHealthDataAvailable": HKHealthStore.isHealthDataAvailable()
            ]
        )

        // 3. 啟用健康資料更新背景傳遞
        let bgDeliveryStatus = await withCheckedContinuation { continuation in
            healthStore.enableBackgroundDelivery(for: HKObjectType.workoutType(), frequency: .immediate) { success, error in
                if let error = error {
                    print("設置背景傳遞失敗: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: success)
            }
        }

        if !bgDeliveryStatus {
            Logger.firebase(
                "Workout Observer 背景傳遞設置失敗",
                level: .error,
                labels: ["module": "WorkoutBackgroundManager", "action": "setup_observer_failed", "cloud_logging": "true"],
                jsonPayload: ["reason": "background_delivery_failed"]
            )
        }

        // 4. 無論背景傳遞是否成功，都啟動觀察者（前台時仍可運作）
        startObservingWorkouts()
        print("已設置健身記錄觀察器（背景傳遞: \(bgDeliveryStatus ? "成功" : "失敗")）")

        Logger.firebase(
            "Workout Observer 設置完成",
            level: .info,
            labels: ["module": "WorkoutBackgroundManager", "action": "setup_observer_success", "cloud_logging": "true"],
            jsonPayload: ["backgroundDelivery": bgDeliveryStatus]
        )

        // 5. 運行一次上傳邏輯，處理已存在但尚未上傳的記錄
        await checkAndUploadPendingWorkouts()

        // 6. 設置後台刷新
        setupBackgroundRefresh()

        // 標記為非首次登入同步
        isFirstLoginSync = false
    }
    
    // 停用觀察者（當切換到 Garmin 數據來源時）
    func stopAndCleanupObserving() {
        print("停用 HealthKit 觀察者...")
        stopObservingWorkouts()
        cancelAllTasks()  // 取消所有正在執行的任務
        print("HealthKit 觀察者已停用")
    }
    
    // 獲取待上傳健身記錄數量
    func getPendingWorkoutsCount() async -> Int {
        do {
            // 獲取最近的健身記錄
            let workouts = try await fetchRecentWorkouts()
            
            // 過濾出未上傳或心率數據不足的記錄
            let pendingWorkouts = workouts.filter {
                !workoutUploadTracker.isWorkoutUploaded($0) ||
                !workoutUploadTracker.workoutHasHeartRate($0)
            }
            
            return pendingWorkouts.count
        } catch {
            print("獲取待上傳記錄數量時出錯: \(error.localizedDescription)")
            return 0
        }
    }
    
    // 請求 HealthKit 授權
    func requestHealthKitAuthorization() async {
        do {
            try await requestHealthKitAuthorizationCore()
            print("成功請求 HealthKit 授權")
        } catch {
            print("請求 HealthKit 授權失敗: \(error.localizedDescription)")
        }
    }
    
    // 檢查並上傳待處理的健身記錄 - 加強版檢查
    func checkAndUploadPendingWorkouts() async {
        // 收集所有狀態用於診斷
        let dataSourcePreference = UserPreferencesManager.shared.dataSourcePreference
        let appStateDataSource = await MainActor.run { AppStateManager.shared.userDataSource }
        let hasCompletedOnboarding = await AuthenticationViewModel.shared.hasCompletedOnboarding
        let isAuthenticated = await AuthenticationViewModel.shared.isAuthenticated

        // 📊 Firebase 日誌：記錄上傳檢查開始的完整狀態
        Logger.firebase(
            "Workout 上傳檢查開始",
            level: .info,
            labels: ["module": "WorkoutBackgroundManager", "action": "check_upload", "cloud_logging": "true"],
            jsonPayload: [
                "dataSource_userPrefs": dataSourcePreference.rawValue,
                "dataSource_appState": appStateDataSource.rawValue,
                "hasCompletedOnboarding": hasCompletedOnboarding,
                "isAuthenticated": isAuthenticated,
                "isCurrentlyProcessing": isCurrentlyProcessing,
                "lastUploadCheckTime": lastUploadCheckTime?.timeIntervalSince1970 ?? 0
            ]
        )

        // 🔧 數據源判定：任一來源顯示 appleHealth 就視為 Apple Health 用戶
        // 避免 UserPreferencesManager cache 損壞導致回傳 .unbound
        let isAppleHealthUser = dataSourcePreference == .appleHealth || appStateDataSource == .appleHealth
        guard isAppleHealthUser else {
            print("⚠️ 數據來源非 Apple Health（prefs: \(dataSourcePreference.rawValue), appState: \(appStateDataSource.rawValue)），跳過上傳")
            Logger.firebase(
                "Workout 上傳跳過：非 Apple Health",
                level: .warn,
                labels: ["module": "WorkoutBackgroundManager", "action": "check_upload_skipped", "cloud_logging": "true"],
                jsonPayload: [
                    "reason": "non_apple_health",
                    "dataSource_userPrefs": dataSourcePreference.rawValue,
                    "dataSource_appState": appStateDataSource.rawValue
                ]
            )
            return
        }

        // 認證守衛：未登入不應上傳（避免無效 API 調用）
        guard isAuthenticated else {
            print("⚠️ 用戶未登入，跳過 HealthKit 數據上傳")
            Logger.firebase(
                "Workout 上傳跳過：未登入",
                level: .warn,
                labels: ["module": "WorkoutBackgroundManager", "action": "check_upload_skipped", "cloud_logging": "true"],
                jsonPayload: ["reason": "not_authenticated", "hasCompletedOnboarding": hasCompletedOnboarding]
            )
            return
        }

        // Onboarding 守衛：未完成 onboarding 的用戶可能缺少 profile 資料（體重、身高等）
        guard hasCompletedOnboarding else {
            print("⚠️ 用戶尚未完成 onboarding，跳過 HealthKit 數據上傳")
            Logger.firebase(
                "Workout 上傳跳過：Onboarding 未完成",
                level: .warn,
                labels: ["module": "WorkoutBackgroundManager", "action": "check_upload_skipped", "cloud_logging": "true"],
                jsonPayload: ["reason": "onboarding_not_completed", "isAuthenticated": isAuthenticated]
            )
            return
        }

        // 防止過度觸發 - 檢查冷卻時間
        let now = Date()
        if let lastTime = lastUploadCheckTime,
           now.timeIntervalSince(lastTime) < uploadCheckCooldown {
            print("⏰ 上傳檢查冷卻中，跳過重複調用（距上次 \(Int(now.timeIntervalSince(lastTime)))秒）")
            return
        }

        // 防止並發執行
        guard !isCurrentlyProcessing else {
            print("🔄 已有上傳任務在進行中，跳過重複調用")
            return
        }
        
        print("檢查待上傳的健身記錄...")
        isCurrentlyProcessing = true
        lastUploadCheckTime = now
        
        defer {
            isCurrentlyProcessing = false
        }
        
        // TaskRegistry 會自動處理重複任務，無需額外檢查
        
        // 為了確保後台任務不會過早結束，使用一個背景任務 ID
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        if UIApplication.shared.applicationState == .background {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                print("健身記錄上傳背景任務即將過期")
                
                // 如果任務即將過期，嘗試請求更多執行時間
                if #available(iOS 13.0, *) {
                    self.scheduleBackgroundTask()
                }
            })
        }
        
        defer {
            // 確保背景任務在函數結束時正確結束
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }
        
        do {

            // 獲取最近的健身記錄
            let workouts = try await fetchRecentWorkouts()

            // 診斷 log：幫助追蹤授權和數據問題
            let uploadedCount = workouts.filter { workoutUploadTracker.isWorkoutUploaded($0, apiVersion: .v2) }.count
            Logger.firebase(
                "HealthKit Workout 查詢結果",
                level: .info,
                labels: ["module": "WorkoutBackgroundManager", "action": "fetch_workouts_result", "cloud_logging": "true"],
                jsonPayload: [
                    "totalFound": workouts.count,
                    "alreadyUploaded": uploadedCount,
                    "notUploaded": workouts.count - uploadedCount
                ]
            )

            if workouts.isEmpty {
                // 重要診斷：空結果可能是授權問題
                Logger.firebase(
                    "⚠️ HealthKit 返回 0 筆 workout - 可能是授權問題",
                    level: .warn,
                    labels: ["module": "WorkoutBackgroundManager", "action": "fetch_workouts_empty", "cloud_logging": "true"],
                    jsonPayload: [
                        "isHealthDataAvailable": HKHealthStore.isHealthDataAvailable(),
                        "suggestion": "用戶可能需要到 設定 > 健康 > 資料取用權限 開啟 Paceriz 的授權"
                    ]
                )
            }

            // 分離真正的新運動和需要心率重試的運動
            let trulyNewWorkouts = workouts.filter {
                !workoutUploadTracker.isWorkoutUploaded($0, apiVersion: .v2)
            }
            
            let workoutsNeedingHeartRateRetry = workouts.filter { workout in
                // 已上傳但缺少心率數據（使用 V2 API 版本）
                guard workoutUploadTracker.isWorkoutUploaded(workout, apiVersion: .v2) && 
                      !workoutUploadTracker.workoutHasHeartRate(workout, apiVersion: .v2) else {
                    return false
                }
                
                // 檢查是否超過1小時的等待時間，可以重試
                if let uploadTime = workoutUploadTracker.getWorkoutUploadTime(workout, apiVersion: .v2) {
                    let timeElapsed = Date().timeIntervalSince(uploadTime)
                    return timeElapsed >= 3600 // 1小時 = 3600秒
                }
                
                return false
            }
            
            let allWorkoutsToProcess = trulyNewWorkouts + workoutsNeedingHeartRateRetry
            let totalWorkoutsToProcess = allWorkoutsToProcess.count
            
            if totalWorkoutsToProcess > 0 {
                print("共發現 \(totalWorkoutsToProcess) 筆需要處理的健身記錄（新運動：\(trulyNewWorkouts.count) 筆，心率重試：\(workoutsNeedingHeartRateRetry.count) 筆）")
                
                // 設置同步狀態
                syncTotalCount = totalWorkoutsToProcess
                syncSuccessCount = 0
                
                // 通知邏輯：只有新運動才發送通知，避免用戶困惑
                let shouldShowNotificationForNewWorkouts = trulyNewWorkouts.count > 0 && shouldSendNotification()
                if shouldShowNotificationForNewWorkouts {
                    await sendBulkSyncStartNotification(count: trulyNewWorkouts.count)
                }
                
                // 處理所有需要處理的記錄
                if !allWorkoutsToProcess.isEmpty {
                    if trulyNewWorkouts.count > 0 {
                        print("正在上傳 \(trulyNewWorkouts.count) 筆新記錄")
                    }
                    if workoutsNeedingHeartRateRetry.count > 0 {
                        print("正在重試 \(workoutsNeedingHeartRateRetry.count) 筆記錄的心率數據")
                    }
                    
                    // 分離跑步和非跑步記錄
                    let runningWorkouts = allWorkoutsToProcess.filter { self.isRunningWorkout($0) }
                    let nonRunningWorkouts = allWorkoutsToProcess.filter { !self.isRunningWorkout($0) }
                    
                    // 如果應該發送通知，先記錄開始處理
                    if shouldShowNotificationForNewWorkouts {
                        print("📱 開始在背景處理 \(trulyNewWorkouts.count) 筆新健身記錄")
                    }
                    
                    // ✅ 修復：使用 TaskGroup 等待所有上傳完成，確保背景任務不會提前結束
                    await withTaskGroup(of: Int.self) { group in
                        if !runningWorkouts.isEmpty {
                            group.addTask { [weak self] in
                                await self?.uploadWorkouts(runningWorkouts, sendIndividualNotifications: false) ?? 0
                            }
                        }

                        if !nonRunningWorkouts.isEmpty {
                            group.addTask { [weak self] in
                                await self?.uploadWorkouts(nonRunningWorkouts, sendIndividualNotifications: false) ?? 0
                            }
                        }

                        var totalSuccess = 0
                        for await count in group {
                            totalSuccess += count
                        }
                        print("✅ 所有記錄上傳完成：\(totalSuccess) 筆成功")
                    }
                }
                
            } else {
                print("沒有發現需要處理的健身記錄")
            }
        } catch {
            print("檢查待上傳健身記錄時出錯: \(error.localizedDescription)")
            Logger.firebase(
                "檢查待上傳健身記錄失敗",
                level: .error,
                labels: ["module": "WorkoutBackgroundManager", "action": "check_upload_error", "cloud_logging": "true"],
                jsonPayload: ["error": error.localizedDescription]
            )
        }
        
        // 結束同步
        syncTotalCount = 0
        syncSuccessCount = 0
    }
    
    // MARK: - 私有方法
    
    // 開始批量同步，發送通知
    private func sendBulkSyncStartNotification(count: Int) async {
        // 首先清除所有之前的通知
        clearAllWorkoutNotifications()
        
        // 如果是首次登入同步且數量很大，就發送一個特別的通知
        if isFirstLoginSync && count > 20 {
            await sendFirstLoginSyncNotification(count: count)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "開始同步訓練數據"
        content.body = "正在同步 \(count) 條訓練記錄，完成後將通知您"
        
        let request = UNNotificationRequest(
            identifier: "sync-training-data-start",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            lastNotificationTime = Date()
            print("已發送批量同步開始通知")
        } catch {
            print("發送批量同步開始通知失敗: \(error)")
        }
    }
    
    // 發送首次登入的特別通知
    private func sendFirstLoginSyncNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "正在處理歷史訓練數據"
        content.body = "系統正在處理您的 \(count) 條歷史訓練記錄，這可能需要一些時間，完成後將通知您"
        
        let request = UNNotificationRequest(
            identifier: "first-login-sync",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            lastNotificationTime = Date()
            print("已發送首次登入同步通知")
        } catch {
            print("發送首次登入同步通知失敗: \(error)")
        }
    }
    
    // 批量同步完成，發送通知
    private func sendBulkSyncCompleteNotification(count: Int) async {
        // 先移除開始同步的通知
        clearAllWorkoutNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = "訓練數據同步完成"
        content.body = "已成功同步 \(count) 條訓練記錄"
        
        let request = UNNotificationRequest(
            identifier: "sync-training-data-completion",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            lastNotificationTime = Date()
            print("已發送批量同步完成通知")
        } catch {
            print("發送批量同步完成通知失敗: \(error)")
        }
    }
    
    // 清除所有訓練相關通知
    private func clearAllWorkoutNotifications() {
        let identifiers = [
            "sync-training-data-start",
            "sync-training-data-completion",
            "first-login-sync",
        ]
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        
        // 同時清除所有與運動上傳相關的通知
        notificationCenter.getDeliveredNotifications { notifications in
            let workoutUploadIdentifiers = notifications
                .filter { $0.request.identifier.hasPrefix("workout-upload-success") }
                .map { $0.request.identifier }
            
            if !workoutUploadIdentifiers.isEmpty {
                self.notificationCenter.removeDeliveredNotifications(withIdentifiers: workoutUploadIdentifiers)
            }
        }
    }
    
    // 決定是否應該發送通知
    private func shouldSendNotification() -> Bool {
        // 首次登入同步總是發送通知
        if isFirstLoginSync {
            return true
        }
        
        guard let lastTime = lastNotificationTime else {
            // 從未發送過通知，允許發送
            return true
        }
        
        let timeElapsed = Date().timeIntervalSince(lastTime)
        return timeElapsed > notificationCooldown
    }
    
    // 請求 HealthKit 授權（核心功能，失敗會 throw）
    private func requestHealthKitAuthorizationCore() async throws {
        if CommandLine.arguments.contains("-skipHealthKitAuth") {
            print("🧪 [UI Test] -skipHealthKitAuth detected, bypass WorkoutBackgroundManager HealthKit authorization request")
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]
            if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
                typesToRead.insert(hrType)
            }
            if let speedType = HKObjectType.quantityType(forIdentifier: .runningSpeed) {
                typesToRead.insert(speedType)
            }

            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "HealthKitAuthorization", code: -1, userInfo: [NSLocalizedDescriptionKey: "Health Kit 授權被拒絕"]))
                }
            }
        }
    }

    // 請求通知授權（非核心，失敗不影響 HealthKit Observer）
    private func requestNotificationAuthorization() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                Logger.firebase(
                    "通知授權被拒絕，同步功能仍正常運作",
                    level: .warn,
                    labels: ["module": "WorkoutBackgroundManager", "action": "notification_denied"]
                )
            }
        } catch {
            Logger.firebase(
                "請求通知授權失敗: \(error.localizedDescription)",
                level: .warn,
                labels: ["module": "WorkoutBackgroundManager", "action": "notification_auth_error"]
            )
        }
    }
    
    // 創建並啟動觀察者查詢
    func startObservingWorkouts() {
        // 如果已經在觀察中，則不重複啟動
        guard !isObservingWorkouts else { return }
        
        // 確保沒有現有的查詢
        stopObservingWorkouts()
        
        let query = HKObserverQuery(sampleType: HKObjectType.workoutType(), predicate: nil) { [weak self] (query, completionHandler, error) in
            guard let self = self else {
                completionHandler()
                return
            }

            if let error = error {
                print("健身記錄觀察者查詢錯誤: \(error.localizedDescription)")
                completionHandler()
                return
            }

            // 使用 debouncer 合併多次回調（HealthKit 可能對同一事件觸發多次回調）
            print("偵測到健身記錄變化，排程處理（將合併多次回調）...")

            Task {
                await self.observerDebouncer.debounce { [weak self] in
                    guard let self = self else { return }

                    print("Debounce 延遲結束，開始處理健身記錄...")
                    await self.checkAndUploadPendingWorkouts()

                    // 在後台模式下，主動請求更多背景處理時間
                    if await MainActor.run(body: { UIApplication.shared.applicationState == .background }) {
                        self.scheduleBackgroundTask()
                    }
                }
            }

            completionHandler()
        }
        
        // 保存查詢引用
        activeObserverQuery = query
        
        // 使用 HealthKitObserverCoordinator 註冊 Observer
        Task {
            let registered = await HealthKitObserverCoordinator.shared.registerObserver(
                type: HealthKitObserverCoordinator.ObserverType.workoutBackground,
                query: query,
                enableBackground: false,  // 背景傳遞已在 setupWorkoutObserver 中設置
                sampleType: nil
            )
            
            if registered {
                isObservingWorkouts = true
                print("WorkoutBackgroundManager: 成功註冊 HealthKit Observer")
            } else {
                print("WorkoutBackgroundManager: HealthKit Observer 已經存在，跳過註冊")
            }
        }
    }
    
    // 設置背景刷新
    private func setupBackgroundRefresh() {
        // 註冊應用程序後台刷新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    // 應用進入後台時觸發
    @objc private func applicationDidEnterBackground() {
        // 在應用進入後台時安排同步任務
        scheduleBackgroundTask()
        
        // 立即開始檢查和上傳
        Task {
            await checkAndUploadPendingWorkouts()
        }
    }
    
    // 應用返回前台時觸發
    @objc private func applicationWillEnterForeground() {
        // 應用返回前台時，延遲後檢查並處理待上傳的健身記錄
        Task {
            // 短暫延遲，讓系統穩定
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
            
            // 重置首次登入標記（避免前景切換觸發大量處理）
            if isFirstLoginSync {
                print("📱 應用返回前景，重置首次登入同步標記")
                isFirstLoginSync = false
            }
            
            await checkAndUploadPendingWorkouts()
        }
    }
    
    // 停止監聽健身記錄變化
    func stopObservingWorkouts() {
        if activeObserverQuery != nil {
            Task {
                // 取消任何待處理的 debounced 任務
                await observerDebouncer.cancel()

                // 使用 HealthKitObserverCoordinator 移除 Observer
                await HealthKitObserverCoordinator.shared.removeObserver(type: HealthKitObserverCoordinator.ObserverType.workoutBackground)

                activeObserverQuery = nil
                isObservingWorkouts = false
                print("已停止監聽健身記錄變化")
            }
        }
    }
    
    // MARK: - TaskManageable Cleanup
    deinit {
        // 取消 debouncer 中的待處理任務
        Task { [observerDebouncer] in
            await observerDebouncer.cancel()
        }
        // 在對象銷毀時停止監聯並取消所有任務
        stopObservingWorkouts()
        cancelAllTasks()
    }
    
    // 安排背景任務 - 委派給 HavitalApp 的 scheduleBackgroundWorkoutSync()
    private func scheduleBackgroundTask() {
        // ✅ 修復：不再在這裡獨立排程任務，而是委派給全局的 scheduleBackgroundWorkoutSync()
        // 這樣避免重複任務競爭和 error 3（NotPermitted）
        scheduleBackgroundWorkoutSync()
    }
    
    // 獲取最近的健身記錄 - 修正版
    private func fetchRecentWorkouts() async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let now = Date()
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now.addingTimeInterval(-30 * 24 * 3600)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let predicate = HKQuery.predicateForSamples(withStart: oneMonthAgo, end: now, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 14, // 只獲取最近的14條記錄
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    
    // 上傳健身記錄
    @discardableResult
    private func uploadWorkouts(_ workouts: [HKWorkout], sendIndividualNotifications: Bool) async -> Int {
        // 使用統一的 WorkoutService 方法進行上傳
        let result = await workoutService.uploadWorkouts(
            workouts,
            force: false,
            retryHeartRate: true
        )
        
        // 處理通知
        if result.success > 0 {
            // 收集成功上傳的記錄ID
            let successIds = result.failedWorkouts.isEmpty ? 
                workouts.prefix(result.success).map { $0.uuid.uuidString } :
                workouts.filter { workout in
                    !result.failedWorkouts.contains { $0.workout.uuid == workout.uuid }
                }.map { $0.uuid.uuidString }
            
            // 使用 SyncNotificationManager 發送通知
            await SyncNotificationManager.shared.notifySyncCompletion(count: result.success, workoutIds: successIds)
        }
        
        print("上傳完成，成功: \(result.success), 失敗: \(result.failed), 總計: \(result.total)")
        return result.success
    }
    
    // 判斷是否為跑步相關的健身記錄
    private func isRunningWorkout(_ workout: HKWorkout) -> Bool {
        return runningActivityTypes.contains(workout.workoutActivityType)
    }
    
}


// MARK: - 通知中心代理實現
extension WorkoutBackgroundManager: UNUserNotificationCenterDelegate {
    // 當應用在前台時也顯示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 正常顯示通知
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // 處理通知的點擊事件
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 處理同步相關通知
        if response.notification.request.identifier.hasPrefix("sync-training-data") ||
                    response.notification.request.identifier == "first-login-sync" {
            // 處理同步相關通知的點擊
            completionHandler()
        } else {
            // 這裡可以處理用戶點擊通知的邏輯，例如導航到訓練記錄頁面
            completionHandler()
        }
    }
}
