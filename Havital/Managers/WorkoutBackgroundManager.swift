import Foundation
import HealthKit
import UserNotifications
import BackgroundTasks
import UIKit  // 添加 UIKit 引用，這樣就可以使用 UIApplication


// 完整的工作記錄背景管理器，含所有必要方法
class WorkoutBackgroundManager: NSObject {
    static let shared = WorkoutBackgroundManager()
    
    private let healthStore = HKHealthStore()
    private let workoutService = WorkoutService.shared
    private let workoutUploadTracker = WorkoutUploadTracker.shared
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // 跑步相關的活動類型
    private let runningActivityTypes: [HKWorkoutActivityType] = [
        .running,
        .trackAndField,
        .walking,
        .hiking,
        .mixedCardio,
        .crossTraining
    ]
    
    private override init() {
        super.init()
        // 設置通知中心代理
        notificationCenter.delegate = self
    }
    
    // MARK: - 公開方法
    
    // 設置觀察者來監聽新的健身記錄
    func setupWorkoutObserver() async {
        do {
            // 請求授權
            try await requestAuthorizations()
            
            // 獲取觀察器授權
            let status = await withCheckedContinuation { continuation in
                healthStore.enableBackgroundDelivery(for: HKObjectType.workoutType(), frequency: .immediate) { success, error in
                    if let error = error {
                        print("設置背景交付失敗: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                        return
                    }
                    continuation.resume(returning: success)
                }
            }
            
            if status {
                print("已成功設置背景健身記錄觀察器")
                
                // 創建觀察者查詢
                let query = createWorkoutObserverQuery()
                healthStore.execute(query)
                
                // 運行一次上傳邏輯，處理已存在但尚未上傳的記錄
                await checkAndUploadPendingWorkouts()
                
                // 設置後台刷新確保即使觀察者不觸發也能定期檢查
                setupBackgroundRefresh()
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
            
            // 過濾出未上傳的記錄
            let pendingWorkouts = workouts.filter { !workoutUploadTracker.isWorkoutUploaded($0) }
            
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
    
    // 檢查並上傳待處理的健身記錄
    func checkAndUploadPendingWorkouts() async {
        print("檢查待上傳的健身記錄...")
        
        // 為了確保後台任務不會過早結束，使用一個背景任務 ID
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        if UIApplication.shared.applicationState == .background {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                print("健身記錄上傳背景任務即將過期")
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
            
            // 過濾出未上傳的記錄
            let pendingWorkouts = workouts.filter { !workoutUploadTracker.isWorkoutUploaded($0) }
            
            if !pendingWorkouts.isEmpty {
                print("發現 \(pendingWorkouts.count) 條未上傳的健身記錄")
                
                // 分離跑步和非跑步記錄
                let runningWorkouts = pendingWorkouts.filter { self.isRunningWorkout($0) }
                let nonRunningWorkouts = pendingWorkouts.filter { !self.isRunningWorkout($0) }
                
                // 處理跑步記錄
                if !runningWorkouts.isEmpty {
                    await uploadWorkouts(runningWorkouts, showNotification: true)
                }
                
                // 處理非跑步記錄（上傳但不顯示通知）
                if !nonRunningWorkouts.isEmpty {
                    await uploadWorkouts(nonRunningWorkouts, showNotification: false)
                }
            } else {
                print("沒有發現未上傳的健身記錄")
            }
        } catch {
            print("檢查待上傳健身記錄時出錯: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 私有方法
    
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
    
    // 創建觀察者查詢
    private func createWorkoutObserverQuery() -> HKObserverQuery {
        let query = HKObserverQuery(sampleType: HKObjectType.workoutType(), predicate: nil) { [weak self] (query, completionHandler, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("健身記錄觀察者查詢錯誤: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // 檢測到新的健身記錄，執行上傳邏輯
            Task {
                await self.checkAndUploadPendingWorkouts()
                completionHandler()
            }
        }
        
        return query
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
    
    // 獲取最近的健身記錄
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
    
    // 上傳健身記錄
    private func uploadWorkouts(_ workouts: [HKWorkout], showNotification: Bool) async {
        let healthKitManager = HealthKitManager()
        
        for workout in workouts {
            do {
                // 獲取心率和配速數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                let paceData = try await healthKitManager.fetchPaceData(for: workout)
                
                // 轉換為所需的 DataPoint 格式
                let heartRates = heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
                let paces = paceData.map { DataPoint(time: $0.0, value: $0.1) }
                
                // 上傳運動數據
                try await workoutService.postWorkoutDetails(
                    workout: workout,
                    heartRates: heartRates,
                    paces: paces
                )
                
                // 標記為已上傳
                workoutUploadTracker.markWorkoutAsUploaded(workout)
                print("成功上傳運動記錄: \(workout.workoutActivityType.name), 日期: \(workout.startDate)")
                
                // 如果需要，發送通知
                if showNotification {
                    await sendUploadSuccessNotification(for: workout)
                }
                
            } catch {
                print("上傳運動記錄失敗: \(workout.startDate), 錯誤: \(error)")
            }
            
            // 在上傳之間添加小延遲以避免過度使用服務器
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
    }
    
    // 判斷是否為跑步相關的健身記錄
    private func isRunningWorkout(_ workout: HKWorkout) -> Bool {
        return runningActivityTypes.contains(workout.workoutActivityType)
    }
    
    // 發送上傳成功通知
    private func sendUploadSuccessNotification(for workout: HKWorkout) async {
        // 格式化日期和時間
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateTimeString = dateFormatter.string(from: workout.startDate)
        
        // 格式化距離（如果有）
        var distanceString = ""
        if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
            if distance >= 1000 {
                distanceString = String(format: "%.2f 公里", distance / 1000)
            } else {
                distanceString = String(format: "%.0f 公尺", distance)
            }
        }
        
        // 創建通知內容
        let content = UNMutableNotificationContent()
        content.title = "運動資料已同步"
        content.body = "\(workout.workoutActivityType.name) (\(dateTimeString)) \(distanceString) 已成功上傳到雲端"
        content.sound = UNNotificationSound.default
        
        // 設置觸發器（立即顯示）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 創建請求
        let request = UNNotificationRequest(
            identifier: "workout-upload-success-\(workout.uuid.uuidString)",
            content: content,
            trigger: trigger
        )
        
        // 添加通知請求
        do {
            try await notificationCenter.add(request)
            print("已發送上傳成功通知")
        } catch {
            print("發送通知失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - 通知中心代理實現
extension WorkoutBackgroundManager: UNUserNotificationCenterDelegate {
    // 當應用在前台時也顯示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // 處理通知的點擊事件
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // 這裡可以處理用戶點擊通知的邏輯，例如導航到訓練記錄頁面
        completionHandler()
    }
}

