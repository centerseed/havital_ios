import Foundation
import HealthKit
import UserNotifications
import BackgroundTasks
import UIKit

// 自定義錯誤類型
enum WorkoutUploadError: Error {
    case missingHeartRateData
    case serverError
}

// 完整的工作記錄背景管理器，含所有必要方法，支持心率資料檢查
class WorkoutBackgroundManager: NSObject {
    static let shared = WorkoutBackgroundManager()
    
    private let healthStore = HKHealthStore()
    private let workoutService = WorkoutService.shared
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
    
    // 批量同步狀態追蹤
    private var syncInProgress = false
    private var syncTotalCount = 0
    private var syncSuccessCount = 0
    private var isFirstLoginSync = false
    
    // 使用中的觀察查詢
    private var activeObserverQuery: HKObserverQuery?
    private var isObservingWorkouts = false
    
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
    
    // 設置觀察者來監聽新的健身記錄 - 修正版
    func setupWorkoutObserver() async {
        do {
            // 1. 請求授權
            try await requestAuthorizations()
            
            // 2. 啟用健康資料更新背景傳遞
            let status = await withCheckedContinuation { continuation in
                healthStore.enableBackgroundDelivery(for: HKObjectType.workoutType(), frequency: .immediate) { success, error in
                    if let error = error {
                        print("設置背景傳遞失敗: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                        return
                    }
                    continuation.resume(returning: success)
                }
            }
            
            if status {
                // 3. 啟動觀察者查詢
                startObservingWorkouts()
                print("已成功設置背景健身記錄觀察器")
                
                // 運行一次上傳邏輯，處理已存在但尚未上傳的記錄
                await checkAndUploadPendingWorkouts()
                
                // 檢查是否需要重試獲取心率資料
                scheduleHeartRateRetryIfNeeded()
                
                // 設置後台刷新確保即使觀察者不觸發也能定期檢查
                setupBackgroundRefresh()
                
                // 標記為非首次登入同步
                isFirstLoginSync = false
            } else {
                print("無法設置背景健身記錄觀察器")
            }
        } catch {
            print("設置健身記錄觀察器時出錯: \(error.localizedDescription)")
        }
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
            try await requestAuthorizations()
            print("成功請求 HealthKit 授權")
        } catch {
            print("請求 HealthKit 授權失敗: \(error.localizedDescription)")
        }
    }
    
    // 檢查並上傳待處理的健身記錄 - 修正版
    func checkAndUploadPendingWorkouts() async {
        print("檢查待上傳的健身記錄...")
        
        // 如果已有同步任務在進行中，則不重複啟動
        if syncInProgress {
            print("已有同步任務在進行中，跳過本次請求")
            return
        }
        
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
            // 標記同步開始
            syncInProgress = true
            
            // 獲取最近的健身記錄
            let workouts = try await fetchRecentWorkouts()
            
            // 處理需要重新獲取心率資料的記錄
            let heartRateRetryWorkouts = workouts.filter { workout in
                if workoutUploadTracker.isWorkoutUploaded(workout) &&
                   !workoutUploadTracker.workoutHasHeartRate(workout) {
                    if let uploadTime = workoutUploadTracker.getWorkoutUploadTime(workout) {
                        let timeElapsed = Date().timeIntervalSince(uploadTime)
                        return timeElapsed >= retryThresholdTime // 超過重試時間的記錄
                    }
                }
                return false
            }
            
            // 過濾出未上傳的記錄
            let newWorkouts = workouts.filter { !workoutUploadTracker.isWorkoutUploaded($0) }
            
            // 只有在有需要處理的記錄時才進行同步
            let totalWorkoutsToProcess = heartRateRetryWorkouts.count + newWorkouts.count
            
            if totalWorkoutsToProcess > 0 {
                print("共發現 \(totalWorkoutsToProcess) 筆需要處理的健身記錄")
                
                // 設置同步狀態
                syncTotalCount = totalWorkoutsToProcess
                syncSuccessCount = 0
                
                // 如果有大量記錄要處理且應該發送通知，則發送開始通知
                if totalWorkoutsToProcess > 10 && shouldSendNotification() {
                    await sendBulkSyncStartNotification(count: totalWorkoutsToProcess)
                }
                
                // 處理需要重試獲取心率資料的記錄
                if !heartRateRetryWorkouts.isEmpty {
                    print("正在重新獲取 \(heartRateRetryWorkouts.count) 筆記錄的心率資料")
                    
                    let retrySuccessCount = await retryUploadingWithHeartRateData(heartRateRetryWorkouts)
                    syncSuccessCount += retrySuccessCount
                }
                
                // 處理新記錄
                if !newWorkouts.isEmpty {
                    print("正在上傳 \(newWorkouts.count) 筆新記錄")
                    
                    // 分離跑步和非跑步記錄
                    let runningWorkouts = newWorkouts.filter { self.isRunningWorkout($0) }
                    let nonRunningWorkouts = newWorkouts.filter { !self.isRunningWorkout($0) }
                    
                    // 處理跑步記錄
                    if !runningWorkouts.isEmpty {
                        let runSuccessCount = await uploadWorkouts(runningWorkouts, sendIndividualNotifications: false)
                        syncSuccessCount += runSuccessCount
                    }
                    
                    // 處理非跑步記錄（不發送個別通知）
                    if !nonRunningWorkouts.isEmpty {
                        let nonRunSuccessCount = await uploadWorkouts(nonRunningWorkouts, sendIndividualNotifications: false)
                        syncSuccessCount += nonRunSuccessCount
                    }
                }
                
                // 完成同步，如果有成功上傳且應該發送通知，則發送完成通知
                if syncSuccessCount > 0 && shouldSendNotification() {
                    await sendBulkSyncCompleteNotification(count: syncSuccessCount)
                }
                
            } else {
                print("沒有發現需要處理的健身記錄")
            }
        } catch {
            print("檢查待上傳健身記錄時出錯: \(error.localizedDescription)")
        }
        
        // 結束同步
        syncInProgress = false
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
            "workout.heartrate.retry"
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
    
    // 請求所需的授權（HealthKit 和 通知）
    private func requestAuthorizations() async throws {
        // 請求 HealthKit 授權
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let typesToRead: Set<HKObjectType> = [
                HKObjectType.workoutType(),
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .runningSpeed)!
            ]
            
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
        
        // 請求通知授權
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "NotificationAuthorization", code: -1, userInfo: [NSLocalizedDescriptionKey: "通知授權被拒絕"]))
                }
            }
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
            
            print("偵測到新的健身記錄，啟動背景處理...")
            
            // 請求背景執行時間
            var backgroundTask: UIBackgroundTaskIdentifier = .invalid
            backgroundTask = UIApplication.shared.beginBackgroundTask {
                // 背景執行時間即將到期
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
                completionHandler()
            }
            
            // 檢測到新的健身記錄，執行上傳邏輯
            Task {
                await self.checkAndUploadPendingWorkouts()
                
                // 完成背景任務
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
                
                // 在後台模式下，主動請求更多背景處理時間
                if UIApplication.shared.applicationState == .background {
                    // 安排後台任務以繼續處理
                    self.scheduleBackgroundTask()
                }
            }
            
            completionHandler()
        }
        
        // 保存查詢引用
        activeObserverQuery = query
        isObservingWorkouts = true
        
        // 執行查詢
        healthStore.execute(query)
        print("已開始監聽健身記錄變化")
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
        // 應用返回前台時，檢查並處理待上傳的健身記錄
        Task {
            await checkAndUploadPendingWorkouts()
        }
    }
    
    // 停止監聽健身記錄變化
    func stopObservingWorkouts() {
        if let query = activeObserverQuery {
            healthStore.stop(query)
            activeObserverQuery = nil
            isObservingWorkouts = false
            print("已停止監聽健身記錄變化")
        }
    }
    
    deinit {
        // 在對象銷毀時停止監聽
        stopObservingWorkouts()
    }
    
    // 安排背景任務
    private func scheduleBackgroundTask() {
        let taskIdentifier = "com.havital.workout-sync"
        
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // 至少 1 小時後執行
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("已安排背景健身記錄同步任務")
        } catch {
            print("無法安排背景同步任務: \(error.localizedDescription)")
        }
    }
    
    // 獲取最近的健身記錄 - 修正版
    private func fetchRecentWorkouts() async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let now = Date()
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let predicate = HKQuery.predicateForSamples(withStart: oneMonthAgo, end: now, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 50, // 只獲取最近的50條記錄
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
    
    // 重試上傳具有心率資料的運動記錄
    @discardableResult
    private func retryUploadingWithHeartRateData(_ workouts: [HKWorkout]) async -> Int {
        print("嘗試重新獲取並上傳心率資料...")
        var successCount = 0
        
        for workout in workouts {
            do {
                // 獲取心率數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                
                // 檢查心率數據是否足夠
                if heartRateData.count < minHeartRateDataPoints {
                    print("運動記錄 \(workout.uuid) 心率數據仍然不足 (\(heartRateData.count)筆)，稍後重試")
                    continue
                }
                
                // 獲取所有擴展數據
                let speedData = try await healthKitManager.fetchSpeedData(for: workout)
                let strideLengthData = try? await healthKitManager.fetchStrideLengthData(for: workout)
                let cadenceData = try? await healthKitManager.fetchCadenceData(for: workout)
                let groundContactTimeData = try? await healthKitManager.fetchGroundContactTimeData(for: workout)
                let verticalOscillationData = try? await healthKitManager.fetchVerticalOscillationData(for: workout)
                
                // 轉換為所需的 DataPoint 格式
                let heartRates = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
                let speeds = speedData.map { DataPoint(time: $0.0, value: $0.1) }
                let strides = strideLengthData?.map { DataPoint(time: $0.0, value: $0.1) }
                let cadences = cadenceData?.map { DataPoint(time: $0.0, value: $0.1) }
                let contactTimes = groundContactTimeData?.map { DataPoint(time: $0.0, value: $0.1) }
                let oscillations = verticalOscillationData?.map { DataPoint(time: $0.0, value: $0.1) }
                
                // 上傳運動數據
                try await workoutService.postWorkoutDetails(
                    workout: workout,
                    heartRates: heartRates,
                    speeds: speeds,
                    strideLengths: strides,
                    cadences: cadences,
                    groundContactTimes: contactTimes,
                    verticalOscillations: oscillations
                )
                
                // 標記為已上傳且包含心率資料
                workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: true)
                print("成功重新上傳運動記錄: \(workout.workoutActivityType.name), 心率數據: \(heartRates.count)筆")
                
                successCount += 1
            } catch {
                print("重新上傳運動記錄失敗: \(workout.uuid), 錯誤: \(error)")
            }
            
            // 添加小延遲
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        return successCount
    }
    
    // 上傳健身記錄
    @discardableResult
    private func uploadWorkouts(_ workouts: [HKWorkout], sendIndividualNotifications: Bool) async -> Int {
        var successCount = 0
        
        for workout in workouts {
            do {
                // 獲取心率數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                
                // 檢查心率數據是否足夠
                if heartRateData.count < minHeartRateDataPoints {
                    let elapsed = Date().timeIntervalSince(workout.endDate)
                    if elapsed < 10 * 60 {
                        print("運動記錄 \(workout.uuid) 心率資料尚未齊全，5秒後重試")
                        // 5秒後重試上傳
                        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                            Task { 
                                print("開始重試上傳運動記錄 \(workout.uuid)")
                                await self.checkAndUploadPendingWorkouts() 
                            }
                        }
                    } else {
                        print("運動記錄 \(workout.uuid) 心率資料仍不完整，超過10分鐘，標記為已上傳無心率")
                        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: false)
                    }
                    continue
                }
                
                // 獲取所有擴展數據
                let speedData = try await healthKitManager.fetchSpeedData(for: workout)
                let strideLengthData = try? await healthKitManager.fetchStrideLengthData(for: workout)
                let cadenceData = try? await healthKitManager.fetchCadenceData(for: workout)
                let groundContactTimeData = try? await healthKitManager.fetchGroundContactTimeData(for: workout)
                let verticalOscillationData = try? await healthKitManager.fetchVerticalOscillationData(for: workout)
                
                // 轉換為所需的 DataPoint 格式
                let heartRates = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
                let speeds = speedData.map { DataPoint(time: $0.0, value: $0.1) }
                let strides = strideLengthData?.map { DataPoint(time: $0.0, value: $0.1) }
                let cadences = cadenceData?.map { DataPoint(time: $0.0, value: $0.1) }
                let contactTimes = groundContactTimeData?.map { DataPoint(time: $0.0, value: $0.1) }
                let oscillations = verticalOscillationData?.map { DataPoint(time: $0.0, value: $0.1) }
                
                // 上傳運動數據
                try await workoutService.postWorkoutDetails(
                    workout: workout,
                    heartRates: heartRates,
                    speeds: speeds,
                    strideLengths: strides,
                    cadences: cadences,
                    groundContactTimes: contactTimes,
                    verticalOscillations: oscillations
                )
                
                // 標記為已上傳且有心率資料
                workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: true)
                print("成功上傳運動記錄: \(workout.workoutActivityType.name), 日期: \(workout.startDate), 心率數據: \(heartRates.count)筆")
                
                successCount += 1
                
                if successCount > 0 {
                    // 收集成功上傳的記錄ID
                    let successIds = workouts.prefix(successCount).map { $0.uuid.uuidString }
                    // 使用 SyncNotificationManager 發送通知
                    await SyncNotificationManager.shared.notifySyncCompletion(count: successCount, workoutIds: successIds)
                }
                
            } catch WorkoutUploadError.missingHeartRateData {
                print("運動記錄 \(workout.uuid) 缺少心率數據，標記為待稍後處理")
                scheduleHeartRateRetryIfNeeded()
            } catch {
                print("上傳運動記錄失敗: \(workout.startDate), 錯誤: \(error)")
            }
            
            // 在上傳之間添加小延遲以避免過度使用服務器
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        return successCount
    }

    
    // 判斷是否為跑步相關的健身記錄
    private func isRunningWorkout(_ workout: HKWorkout) -> Bool {
        return runningActivityTypes.contains(workout.workoutActivityType)
    }
    
    // 如果有缺少心率資料的記錄，安排稍後再次檢查
    private func scheduleHeartRateRetryIfNeeded() {
        // 查詢需要重試的記錄數量
        let retryIds = workoutUploadTracker.getWorkoutsNeedingHeartRateRetry(timeThreshold: retryThresholdTime / 2) // 30分鐘後重試
        
        if !retryIds.isEmpty {
            print("找到 \(retryIds.count) 筆需要重新嘗試獲取心率資料的運動記錄")
            
            // 不發送通知，只在控制台記錄
        }
    }
}


// MARK: - 通知中心代理實現
extension WorkoutBackgroundManager: UNUserNotificationCenterDelegate {
    // 當應用在前台時也顯示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 如果是心率重試通知，則不顯示給用戶
        if notification.request.identifier == "workout.heartrate.retry" {
            completionHandler([])
        } else {
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .list])
            } else {
                completionHandler([.alert, .sound])
            }
        }
    }
    
    // 處理通知的點擊事件
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 處理心率重試通知
        if response.notification.request.identifier == "workout.heartrate.retry" {
            // 當收到重試通知時，再次檢查並上傳運動記錄
            Task {
                print("收到心率資料重試通知，重新檢查運動記錄...")
                await checkAndUploadPendingWorkouts()
                completionHandler()
            }
        } else if response.notification.request.identifier.hasPrefix("sync-training-data") ||
                    response.notification.request.identifier == "first-login-sync" {
            // 處理同步相關通知的點擊
            completionHandler()
        } else {
            // 這裡可以處理用戶點擊通知的邏輯，例如導航到訓練記錄頁面
            completionHandler()
        }
    }
}
