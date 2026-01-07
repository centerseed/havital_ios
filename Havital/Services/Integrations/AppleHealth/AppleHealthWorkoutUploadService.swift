import Foundation
import HealthKit

// MARK: - 錯誤類型定義
enum AppleHealthWorkoutUploadError: Error {
    case serverError
}

// MARK: - Apple Health Workout Upload Service
class AppleHealthWorkoutUploadService: @preconcurrency TaskManageable {
    static let shared = AppleHealthWorkoutUploadService()
    private init() {}
    
    private let healthKitManager = HealthKitManager()
    private let workoutUploadTracker = WorkoutUploadTracker.shared
    
    // Task Management - 使用 Actor-based TaskRegistry 防止重複上傳
    let taskRegistry = TaskRegistry()
    
    deinit {
        cancelAllTasks()
    }
    
    // MARK: - Helper - workout type -> string
    private func getWorkoutTypeString(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running, .trackAndField:                           return "run"
        case .walking:                                           return "walk"
        case .cycling, .handCycling:                             return "cycling"
        case .swimming, .swimBikeRun:                            return "swim"
        case .highIntensityIntervalTraining:                     return "hiit"
        case .crossTraining:                                     return "cross"
        case .mixedCardio:                                       return "mixedCardio"
        case .pilates:                                           return "pilates"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength"
        case .yoga, .mindAndBody:                                return "yoga"
        case .hiking:                                            return "hiking"
        default:                                                 return "other"
        }
    }
    
    // MARK: - Public Helper
    func makeWorkoutId(for workout: HKWorkout) -> String {
        let type  = getWorkoutTypeString(workout.workoutActivityType)
        let start = Int(workout.startDate.timeIntervalSince1970)
        let distM = Int(workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
        return "\(type)_\(start)_\(distM)"
    }

    /// 判斷是否為跑步相關的運動
    private func isRunningRelatedWorkout(_ workout: HKWorkout) -> Bool {
        let activityType = workout.workoutActivityType
        return activityType == .running ||
               activityType == .trackAndField ||
               activityType == .hiking ||
               activityType == .walking
    }

    /// 判斷是否有可靠的速度/距離資訊（優先級驗證）
    /// - 優先級 1: GPS 速度樣本
    /// - 優先級 2: 分圈中有距離資訊
    /// - 優先級 3: 總距離 > 0
    /// - 優先級 4: 至少有步頻資訊
    private func hasReliableSpeedData(requiredData: WorkoutRequiredData) -> Bool {
        // 優先級 1: GPS 速度樣本 (最可靠)
        if requiredData.speedData.count >= 2 {
            print("✅ [驗證] 優先級 1 - GPS 速度樣本可用 (\(requiredData.speedData.count) 筆)")
            return true
        }

        // 優先級 2: 分圈中有距離資訊
        if let laps = requiredData.lapData, !laps.isEmpty {
            let hasDistanceInLaps = laps.contains { ($0.totalDistanceM ?? 0) > 0 }
            if hasDistanceInLaps {
                let lapDistances = laps.compactMap { $0.totalDistanceM }.reduce(0, +)
                print("✅ [驗證] 優先級 2 - 分圈距離可用 (總計: \(String(format: "%.0f", lapDistances)) m，\(laps.count) 圈)")
                return true
            }
        }

        // 優先級 3: 總距離 > 0
        if let distance = requiredData.workout.totalDistance?.doubleValue(for: .meter()),
           distance > 0 {
            print("✅ [驗證] 優先級 3 - 總距離可用 (\(String(format: "%.0f", distance)) m)")
            return true
        }

        // 優先級 4: 至少有步頻資訊（可在後端推算速度）
        if requiredData.cadenceData.count >= 2 {
            print("⚠️ [驗證] 優先級 4 - 只有步頻資訊，無距離資訊")
            return true
        }

        // 都沒有可靠資訊
        print("❌ [驗證] 無可靠速度或距離資訊")
        return false
    }

    /// 判斷是否需要重試速度資料
    /// 策略：只有當既無GPS速度也無任何距離來源時才不重試
    /// 如果有分圈距離或總距離，就不重試（已有可靠的速度計算基礎）
    private func shouldRetrySpeedData(workout: HKWorkout, speedData: [(Date, Double)], lapData: [LapData]?) -> Bool {
        let isRunning = isRunningRelatedWorkout(workout)
        let noSpeedData = speedData.count < 2

        // 只在跑步運動且無 GPS 速度時考慮
        if !isRunning || !noSpeedData {
            return false  // 非跑步運動或有速度就不重試
        }

        // 檢查是否有其他可靠的距離來源
        // 如果有分圈距離，就不重試速度（分圈已有平均速度）
        if let laps = lapData, !laps.isEmpty {
            let hasDistanceInLaps = laps.contains { ($0.totalDistanceM ?? 0) > 0 }
            if hasDistanceInLaps {
                print("⚠️ [驗證] 有分圈距離但無 GPS 速度樣本，分圈已有平均速度，跳過速度重試")
                return false
            }
        }

        // 檢查是否有總距離（即使沒有分圈也有距離）
        if let totalDistance = workout.totalDistance?.doubleValue(for: .meter()), totalDistance > 0 {
            print("⚠️ [驗證] 有總距離但無 GPS 速度樣本，可推算平均速度，跳過速度重試")
            return false
        }

        // 都沒有距離來源，才重試速度（最多 3 次）
        print("⚠️ [驗證] 無 GPS 速度也無距離來源，進行速度重試...")
        return true
    }

    // MARK: - Core Upload API
    func uploadWorkout(_ workout: HKWorkout,
                       force: Bool = false,
                       retryHeartRate: Bool = false,
                       source: String = "apple_health",
                       device: String? = nil) async throws -> UploadResult {
        
        // 使用 workout ID 作為任務標識符防止重複上傳
        let workoutId = makeWorkoutId(for: workout)
        let taskId = TaskID("upload_workout_\(workoutId)")
        
        print("🚀 [TaskRegistry] 開始上傳任務 - WorkoutID: \(workoutId), Force: \(force), RetryHeartRate: \(retryHeartRate)")
        
        guard let result = await executeTask(id: taskId, operation: { [weak self] in
            guard let self = self else { throw WorkoutV2ServiceError.invalidWorkoutData }
            print("🔄 [TaskRegistry] 執行上傳操作 - WorkoutID: \(workoutId)")
            return try await self.performUploadWorkout(workout, force: force, retryHeartRate: retryHeartRate, source: source, device: device)
        }) else {
            print("❌ [TaskRegistry] 上傳任務返回nil - WorkoutID: \(workoutId)")
            throw WorkoutV2ServiceError.invalidWorkoutData
        }
        
        print("✅ [TaskRegistry] 上傳任務完成 - WorkoutID: \(workoutId), 結果: \(result)")
        return result
    }
    
    // MARK: - Internal Upload Implementation
    private func performUploadWorkout(_ workout: HKWorkout,
                                    force: Bool = false,
                                    retryHeartRate: Bool = false,
                                    source: String = "apple_health",
                                    device: String? = nil) async throws -> UploadResult {
        // 選擇檢查：確保當前資料來源是 Apple Health
        guard UserPreferencesManager.shared.dataSourcePreference == .appleHealth else {
            throw WorkoutV2ServiceError.invalidWorkoutData
        }
        
        // 檢查是否已經上傳（除非強制上傳）
        if !force && workoutUploadTracker.isWorkoutUploaded(workout, apiVersion: .v2) {
            let hasHeartRate = workoutUploadTracker.workoutHasHeartRate(workout, apiVersion: .v2)
            print("🚨 運動已上傳到 V2 API，跳過重複上傳")
            return .success(hasHeartRate: hasHeartRate)
        }
        
        // 檢查基本數據（時間和距離）
        let duration = workout.duration
        let _ = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        
        // 基本數據驗證：必須有有效的持續時間
        guard duration > 0 else {
            throw WorkoutV2ServiceError.invalidWorkoutData
        }

        let workoutId = makeWorkoutId(for: workout)

        // 驗證並獲取所有必要的數據（心率、速度、步頻）
        print("🚀 [Upload] 開始驗證運動所需的關鍵數據 - 運動ID: \(workoutId)")
        let requiredData = await validateAndFetchRequiredWorkoutData(
            for: workout,
            retryHeartRate: retryHeartRate
        )

        // 顯示數據驗證摘要
        requiredData.logSummary(workoutId: workoutId)

        // 第一次驗證：使用嚴格要求
        var finalRequiredData = requiredData
        if !requiredData.isAllRequiredDataAvailable(relaxed: false) {
            print("❌ [Upload] 第一次數據驗證失敗 - 運動ID: \(workoutId)")
            print("⏳ [Upload] 等待 5 秒後重新收集數據（Apple Watch 數據可能還沒準備好）...")

            // 等待 5 秒讓數據準備好
            try? await Task.sleep(nanoseconds: 5_000_000_000)

            print("🔄 [Upload] 重新收集運動數據...")
            // 重新收集數據
            let retryRequiredData = await validateAndFetchRequiredWorkoutData(
                for: workout,
                retryHeartRate: retryHeartRate
            )

            retryRequiredData.logSummary(workoutId: workoutId)

            // 第二次驗證：放寬限制（只要有心率就可以上傳）
            if !retryRequiredData.isAllRequiredDataAvailable(relaxed: true) {
                print("❌ [Upload] 第二次數據驗證失敗（放寬限制後）- 運動ID: \(workoutId)")

                var missingData: [String] = []

                // 放寬限制後，只檢查心率
                if retryRequiredData.heartRateData.count < 2 {
                    print("   ❌ 心率數據不足 (\(retryRequiredData.heartRateData.count) < 2) [必需]")
                    missingData.append("heart_rate")
                }

                // 記錄上傳失敗
                let failureReason = "缺少必要數據（放寬限制後）: \(missingData.joined(separator: ", "))"
                workoutUploadTracker.markWorkoutAsFailed(workout, reason: failureReason, apiVersion: .v2)

                throw WorkoutV2ServiceError.invalidWorkoutData
            } else {
                print("✅ [Upload] 第二次驗證通過（放寬限制）- 運動ID: \(workoutId)")
                finalRequiredData = retryRequiredData
            }
        }

        print("✅ [Upload] 數據驗證通過 - 運動ID: \(workoutId)，即將延遲5秒後上傳...")

        // 所有必要數據都滿足條件，延遲5秒再上傳
        // 優化：從20秒減少到5秒，因為數據已經通過驗證
        let delayInNanoseconds: UInt64 = 5_000_000_000 // 5秒
        try? await Task.sleep(nanoseconds: delayInNanoseconds)

        print("📤 [Upload] 延遲完成，現在開始上傳 - 運動ID: \(workoutId)")

        // 獲取設備信息
        let deviceInfo = getWorkoutDeviceInfo(workout)
        let actualSource = deviceInfo.source
        let actualDevice = deviceInfo.device

        // 轉成 DataPoint（使用最終驗證通過的數據）
        let heartRates      = finalRequiredData.heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
        let speeds          = finalRequiredData.speedData.map { DataPoint(time: $0.0, value: $0.1) }
        let strides         = finalRequiredData.strideLengthData?.map { DataPoint(time: $0.0, value: $0.1) }
        let cadences        = finalRequiredData.cadenceData.map { DataPoint(time: $0.0, value: $0.1) }
        let contacts        = finalRequiredData.groundContactTimeData?.map { DataPoint(time: $0.0, value: $0.1) }
        let oscillations    = finalRequiredData.verticalOscillationData?.map { DataPoint(time: $0.0, value: $0.1) }

        // 🌡️ 獲取環境數據（溫度、天氣、濕度）
        let temperature = healthKitManager.fetchEnvironmentTemperature(for: workout)
        let weatherCondition = healthKitManager.fetchWeatherCondition(for: workout)
        let humidity = healthKitManager.fetchHumidity(for: workout)

        // 🎯 獲取 Effort Score (iOS 18+)
        var effortScore: Double? = nil
        if #available(iOS 18.0, *) {
            effortScore = try? await healthKitManager.fetchEffortScore(for: workout)
            if let rpe = effortScore {
                print("🎯 [Upload] Effort Score: \(String(format: "%.1f", rpe)) (0-10 scale)")
            } else {
                print("🎯 [Upload] No Effort Score available for this workout")
            }
        }

        // 如果有任何環境數據或 Effort Score，則創建 metadata
        var workoutMetadata: WorkoutMetadata? = nil
        if temperature != nil || weatherCondition != nil || humidity != nil || effortScore != nil {
            workoutMetadata = WorkoutMetadata(
                temperatureCelsius: temperature,
                weatherCondition: weatherCondition,
                humidityPercent: humidity,
                effortScore: effortScore
            )
            print("🌡️ [Upload] 環境數據 - 溫度: \(temperature.map { String(format: "%.1f°C", $0) } ?? "N/A"), 天氣: \(weatherCondition ?? "N/A"), 濕度: \(humidity.map { String(format: "%.1f%%", $0) } ?? "N/A"), Effort Score: \(effortScore.map { String(format: "%.1f", $0) } ?? "N/A")")
        }

        try await postWorkoutDetails(workout: workout,
                                     heartRates: heartRates,
                                     speeds: speeds,
                                     strideLengths: strides,
                                     cadences: cadences,
                                     groundContactTimes: contacts,
                                     verticalOscillations: oscillations,
                                     totalCalories: finalRequiredData.totalCalories,
                                     laps: finalRequiredData.lapData,
                                     source: actualSource,
                                     device: actualDevice,
                                     metadata: workoutMetadata)

        // 標記為已上傳（所有必要數據都已驗證）
        let hasHeartRateData = finalRequiredData.heartRateData.count >= 2
        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRateData, apiVersion: .v2)

        // 清除失敗記錄（如果有的話）
        workoutUploadTracker.clearFailureRecord(workout)

        print("✅ [Upload] 上傳成功 - 運動ID: \(workoutId)")
        return .success(hasHeartRate: hasHeartRateData)
    }
    
    // MARK: - Batch Upload
    func uploadWorkouts(_ workouts: [HKWorkout],
                        force: Bool = false,
                        retryHeartRate: Bool = false) async -> UploadBatchResult {
        
        // 使用統一的批次任務ID防止重複批次上傳
        let batchId = workouts.map { makeWorkoutId(for: $0) }.joined(separator: ",")
        let batchTaskId = TaskID("upload_batch_\(batchId.hash)")
        
        return await executeTask(id: batchTaskId, operation: { [weak self] in
            guard let self = self else { 
                return UploadBatchResult(total: workouts.count, success: 0, failed: workouts.count, failedWorkouts: workouts.map { FailedWorkout(workout: $0, error: WorkoutV2ServiceError.invalidWorkoutData) })
            }
            return await self.performBatchUpload(workouts, force: force, retryHeartRate: retryHeartRate)
        }) ?? UploadBatchResult(total: workouts.count, success: 0, failed: workouts.count, failedWorkouts: workouts.map { FailedWorkout(workout: $0, error: WorkoutV2ServiceError.invalidWorkoutData) })
    }
    
    // MARK: - Internal Batch Upload Implementation
    private func performBatchUpload(_ workouts: [HKWorkout],
                                  force: Bool = false,
                                  retryHeartRate: Bool = false) async -> UploadBatchResult {
        var success = 0
        var failed  = 0
        var failedList: [FailedWorkout] = []

        print("🚨 批次上傳開始：\(workouts.count) 筆 workout，將暫停通知避免頻繁 API 調用")

        for (index, w) in workouts.enumerated() {
            let workoutId = makeWorkoutId(for: w)
            print("📤 [批次上傳] 正在處理 \(index + 1)/\(workouts.count) - \(workoutId)")

            do {
                // 為每個運動設置 60 秒超時限制，避免整個批次被阻塞
                let result = try await withThrowingTaskGroup(of: UploadResult.self) { group in
                    // 任務 1: 實際上傳
                    group.addTask {
                        try await self.uploadWorkout(w, force: force, retryHeartRate: retryHeartRate)
                    }

                    // 任務 2: 60 秒超時
                    group.addTask {
                        try await Task.sleep(nanoseconds: 60_000_000_000)
                        throw WorkoutV2ServiceError.invalidWorkoutData
                    }

                    // 返回第一個完成的任務結果
                    let result = try await group.next()!
                    group.cancelAll()  // 取消另一個任務
                    return result
                }

                _ = result
                success += 1
                print("✅ [批次上傳] \(workoutId) 上傳成功")

                // 減少批次間隔到 200ms
                try? await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                failed += 1
                let errorMsg = error.localizedDescription

                if errorMsg.contains("cancelled") || errorMsg == "invalidWorkoutData" {
                    print("⏰ [批次上傳] \(workoutId) 超時或被取消，跳過")
                } else {
                    print("❌ [批次上傳] \(workoutId) 上傳失敗: \(errorMsg)")
                }

                failedList.append(FailedWorkout(workout: w, error: error))
            }
        }

        // 🚨 批次上傳完成後，只發送一次統一通知，避免每個 workout 都觸發 GET API
        if success > 0 {
            print("🚨 批次上傳完成：成功 \(success) 筆，失敗 \(failed) 筆")
            // 延遲發送通知，給 UI 足夠時間準備
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒

            NotificationCenter.default.post(
                name: .workoutsDidUpdate,
                object: ["batchUpload": true, "count": success]
            )

            // 發布 CacheEventBus 事件通知其他模組（TrainingPlan、VDOT 等）
            CacheEventBus.shared.publish(.dataChanged(.workouts))
            Logger.debug("[AppleHealthWorkoutUploadService] 發布 .dataChanged(.workouts) 事件，通知 \(success) 筆新訓練")
        }

        return UploadBatchResult(total: workouts.count, success: success, failed: failed, failedWorkouts: failedList)
    }

    // MARK: - Required Data Validation
    /// 驗證並獲取運動上傳所需的關鍵數據
    ///
    /// 對於跑步相關運動（跑步、田徑、健行、步行）：需要心率、速度、步頻三個條件，每個都會進行重試
    /// 對於其他運動：只需要心率數據
    ///
    /// 如果任何必要數據不足，會自動進行重試，最多 5 次，每次間隔 30 秒
    private func validateAndFetchRequiredWorkoutData(
        for workout: HKWorkout,
        retryHeartRate: Bool = false
    ) async -> WorkoutRequiredData {
        // 判斷是否為跑步相關運動
        let isRunning = isRunningRelatedWorkout(workout)
        print("🏃 [驗證] 運動類型: \(isRunning ? "跑步相關 (需要心率、速度、步頻)" : "其他運動 (只需要心率)")")

        // 1. 獲取心率數據（所有運動都需要）
        var heartRateData: [(Date, Double)] = []
        do {
            heartRateData = try await healthKitManager.fetchHeartRateData(for: workout, forceRefresh: false, retryAttempt: 0)
            print("📊 [驗證] 初次心率數據獲取: \(heartRateData.count) 筆")

            // 心率數據不足，進行多次重試
            if heartRateData.count < 2 {
                heartRateData = await retryFetchingData(
                    name: "心率",
                    currentData: heartRateData,
                    fetchOperation: { _ in
                        try await self.healthKitManager.fetchHeartRateData(
                            for: workout,
                            forceRefresh: true,
                            retryAttempt: 0
                        )
                    },
                    workout: workout
                )
            }
        } catch {
            print("❌ [驗證] 無法獲取心率數據: \(error.localizedDescription)")
            await reportHealthKitDataError(workout: workout, dataType: "heart_rate", error: error)
        }

        // 2. 先獲取分圈資料（需要在速度驗證之前）
        var lapData: [LapData]?
        do {
            lapData = try await healthKitManager.fetchLapData(for: workout)
            if let laps = lapData {
                let hasDistance = laps.contains { ($0.totalDistanceM ?? 0) > 0 }
                print("🏃‍♂️ [驗證] 分圈資料獲取成功: \(laps.count) 圈，有距離: \(hasDistance)")
            }
        } catch {
            lapData = nil
            await reportHealthKitDataError(workout: workout, dataType: "lap_data", error: error)
            print("⚠️ [驗證] 分圈資料獲取失敗，將繼續驗證其他數據")
        }

        // 3. 獲取速度數據（基於分圈決定是否重試）
        var speedData: [(Date, Double)] = []
        do {
            speedData = try await healthKitManager.fetchSpeedData(for: workout)
            print("📊 [驗證] 初次速度數據獲取: \(speedData.count) 筆")

            // 根據分圈決定是否重試速度
            if shouldRetrySpeedData(workout: workout, speedData: speedData, lapData: lapData) {
                speedData = await retryFetchingData(
                    name: "速度",
                    currentData: speedData,
                    fetchOperation: { _ in
                        try await self.healthKitManager.fetchSpeedData(for: workout)
                    },
                    workout: workout
                )
            }
        } catch {
            print("❌ [驗證] 無法獲取速度數據: \(error.localizedDescription)")
            await reportHealthKitDataError(workout: workout, dataType: "speed", error: error)
        }

        // 4. 獲取步頻數據（跑步運動才需要重試，其他運動只嘗試一次）
        var cadenceData: [(Date, Double)] = []
        do {
            cadenceData = try await healthKitManager.fetchCadenceData(for: workout)
            print("📊 [驗證] 初次步頻數據獲取: \(cadenceData.count) 筆")

            // 只有跑步相關運動才進行步頻數據重試
            if isRunning && cadenceData.count < 2 {
                cadenceData = await retryFetchingData(
                    name: "步頻",
                    currentData: cadenceData,
                    fetchOperation: { _ in
                        try await self.healthKitManager.fetchCadenceData(for: workout)
                    },
                    workout: workout
                )
            }
        } catch {
            print("❌ [驗證] 無法獲取步頻數據: \(error.localizedDescription)")
            await reportHealthKitDataError(workout: workout, dataType: "cadence", error: error)
        }

        // 5. 獲取輔助數據（可選）
        var strideLengthData: [(Date, Double)]?
        do {
            strideLengthData = try await healthKitManager.fetchStrideLengthData(for: workout)
        } catch {
            strideLengthData = nil
            await reportHealthKitDataError(workout: workout, dataType: "stride_length", error: error)
        }

        var groundContactTimeData: [(Date, Double)]?
        do {
            groundContactTimeData = try await healthKitManager.fetchGroundContactTimeData(for: workout)
        } catch {
            groundContactTimeData = nil
            await reportHealthKitDataError(workout: workout, dataType: "ground_contact_time", error: error)
        }

        var verticalOscillationData: [(Date, Double)]?
        do {
            verticalOscillationData = try await healthKitManager.fetchVerticalOscillationData(for: workout)
        } catch {
            verticalOscillationData = nil
            await reportHealthKitDataError(workout: workout, dataType: "vertical_oscillation", error: error)
        }

        var totalCalories: Double?
        do {
            totalCalories = try await healthKitManager.fetchCaloriesData(for: workout)
        } catch {
            totalCalories = nil
            await reportHealthKitDataError(workout: workout, dataType: "calories", error: error)
        }

        return WorkoutRequiredData(
            workout: workout,
            heartRateData: heartRateData,
            speedData: speedData,
            cadenceData: cadenceData,
            strideLengthData: strideLengthData,
            groundContactTimeData: groundContactTimeData,
            verticalOscillationData: verticalOscillationData,
            totalCalories: totalCalories,
            lapData: lapData
        )
    }

    /// 重試獲取必要數據（用於心率、速度等非可選數據）
    /// - 心率: 2 次重試（優化用戶體驗，避免過長等待）
    /// - 速度: 2 次重試（可用分圈或總距離替代）
    /// - 步頻: 2 次重試（可用分圈替代）
    private func retryFetchingData(
        name: String,
        currentData: [(Date, Double)],
        fetchOperation: @escaping (_ attempt: Int) async throws -> [(Date, Double)],
        workout: HKWorkout? = nil
    ) async -> [(Date, Double)] {
        var data = currentData

        // 檢查是否為第三方數據源（如 Garmin Connect）
        let isThirdParty = workout.map { isThirdPartyWorkout($0) } ?? false
        let sourceName = workout?.sourceRevision.source.name ?? "Unknown"

        // 根據數據類型和來源調整重試策略
        let maxRetries: Int
        let retryInterval: UInt64

        if isThirdParty {
            // 第三方數據源（如 Garmin）通常只有摘要信息，不重試
            maxRetries = 1
            retryInterval = 5_000_000_000 // 5秒
            print("🔍 [驗證] 檢測到第三方數據源 (\(sourceName))，減少重試次數")
        } else if name.contains("速度") {
            maxRetries = 2  // 速度有分圈和總距離可替代，2次即可
            retryInterval = 10_000_000_000 // 10秒
        } else {
            maxRetries = 2  // 心率和步頻優化為2次，避免過長等待
            retryInterval = 10_000_000_000 // 10秒
        }

        print("🔄 [驗證] \(name)數據不足(\(data.count) < 2)，開始重試流程... (最多 \(maxRetries) 次，間隔 \(retryInterval/1_000_000_000)秒)")

        for attempt in 1...maxRetries {
            let intervalSeconds = retryInterval / 1_000_000_000
            print("🔄 [驗證] \(name)數據重試 \(attempt)/\(maxRetries)，等待\(intervalSeconds)秒...")

            try? await Task.sleep(nanoseconds: retryInterval)

            do {
                let retryData = try await fetchOperation(attempt)
                print("🔄 [驗證] 重試第 \(attempt) 次獲取\(name)數據：\(retryData.count) 筆")

                if retryData.count > data.count {
                    data = retryData
                    print("✅ [驗證] 重試成功，更新\(name)數據：\(data.count) 筆")
                }

                if data.count >= 2 {
                    print("✅ [驗證] \(name)數據充足，停止重試")
                    break
                }
            } catch {
                let errorMessage = error.localizedDescription
                print("⚠️ [驗證] 重試第 \(attempt) 次失敗: \(errorMessage)")

                // 檢查是否為手機鎖定導致的錯誤
                if errorMessage.contains("Protected health data is inaccessible") {
                    print("🔒 [驗證] 檢測到手機鎖定錯誤，停止重試（請解鎖手機後數據會自動上傳）")
                    break  // 快速失敗，不繼續重試
                }

                // 檢查是否為第三方數據源授權問題
                if isThirdParty && (errorMessage.contains("authorization") || errorMessage.contains("not determined")) {
                    print("🔐 [驗證] 第三方數據源授權問題，停止重試")
                    break
                }
            }
        }

        if data.count < 2 {
            if isThirdParty {
                print("ℹ️ [驗證] 第三方數據源 (\(sourceName)) 通常只有摘要信息，缺少詳細\(name)數據是正常的")
            } else {
                print("⚠️ [驗證] 重試 \(maxRetries) 次後\(name)數據仍不足：\(data.count) 筆")
            }
        }

        return data
    }

    /// 檢查是否為第三方應用同步的運動
    private func isThirdPartyWorkout(_ workout: HKWorkout) -> Bool {
        let sourceName = workout.sourceRevision.source.name
        let bundleId = workout.sourceRevision.source.bundleIdentifier
        return isThirdPartyDataSource(sourceName: sourceName, bundleId: bundleId)
    }

    /// 重試獲取可選數據
    private func retryFetchingOptionalData(
        name: String,
        currentData: [(Date, Double)],
        fetchOperation: @escaping (_ attempt: Int) async throws -> [(Date, Double)]?
    ) async -> [(Date, Double)]? {
        var data: [(Date, Double)]? = currentData.isEmpty ? nil : currentData
        let maxRetries = 5
        let retryInterval: UInt64 = 30_000_000_000 // 30秒

        guard (data?.count ?? 0) < 2 else { return data }

        print("🔄 [驗證] \(name)數據不足(\(data?.count ?? 0) < 2)，開始重試流程...")

        for attempt in 1...maxRetries {
            print("🔄 [驗證] \(name)數據重試 \(attempt)/\(maxRetries)，等待30秒...")

            try? await Task.sleep(nanoseconds: retryInterval)

            do {
                if let retryData = try await fetchOperation(attempt) {
                    print("🔄 [驗證] 重試第 \(attempt) 次獲取\(name)數據：\(retryData.count) 筆")

                    if (data?.count ?? 0) < retryData.count {
                        data = retryData
                        print("✅ [驗證] 重試成功，更新\(name)數據：\(data?.count ?? 0) 筆")
                    }

                    if (data?.count ?? 0) >= 5 {
                        print("✅ [驗證] \(name)數據充足，停止重試")
                        break
                    }
                }
            } catch {
                print("⚠️ [驗證] 重試第 \(attempt) 次失敗: \(error.localizedDescription)")
            }
        }

        if (data?.count ?? 0) < 5 {
            print("⚠️ [驗證] 重試 \(maxRetries) 次後\(name)數據仍不足：\(data?.count ?? 0) 筆")
        }

        return data
    }

    // MARK: - Internal request helper
    private func postWorkoutDetails(workout: HKWorkout,
                                    heartRates: [DataPoint],
                                    speeds: [DataPoint],
                                    strideLengths: [DataPoint]? = nil,
                                    cadences: [DataPoint]? = nil,
                                    groundContactTimes: [DataPoint]? = nil,
                                    verticalOscillations: [DataPoint]? = nil,
                                    totalCalories: Double? = nil,
                                    laps: [LapData]? = nil,
                                    source: String,
                                    device: String?,
                                    metadata: WorkoutMetadata? = nil) async throws {
        // 建立 WorkoutData 結構
        let workoutData = WorkoutData(
            id: makeWorkoutId(for: workout),
            name: workout.workoutActivityType.name,
            type: getWorkoutTypeString(workout.workoutActivityType),
            startDate: workout.startDate.timeIntervalSince1970,
            endDate: workout.endDate.timeIntervalSince1970,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            heartRates: heartRates.map { HeartRateData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            speeds: speeds.map { SpeedData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            strideLengths: strideLengths?.map { StrideData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            cadences: cadences?.map { CadenceData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            groundContactTimes: groundContactTimes?.map { GroundContactTimeData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            verticalOscillations: verticalOscillations?.map { VerticalOscillationData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            totalCalories: totalCalories,
            laps: laps,
            source: source,
            device: device,
            metadata: metadata)
        
        do {
            // 先嘗試上傳，如果成功就結束
            let _: EmptyResponse = try await APIClient.shared.request(
                EmptyResponse.self,
                path: "/v2/workouts",
                method: "POST",
                body: try JSONEncoder().encode(workoutData)
            )
        } catch {
            // 記錄上傳失敗
            let errorDescription = error.localizedDescription
            workoutUploadTracker.markWorkoutAsFailed(workout, reason: "API 上傳失敗: \(errorDescription)", apiVersion: .v2)

            // 如果失敗，記錄詳細錯誤
            await reportDetailedUploadError(
                workout: workout,
                workoutData: workoutData,
                error: error
            )
            throw error
        }
    }
    
    // MARK: - Summary Helpers (cache)
    func getWorkoutSummary(workoutId: String) async throws -> WorkoutSummary {
        let path = "/workout/summary/\(workoutId)" // v2 未提供 summary 端點，暫沿用舊端點
        let response: WorkoutSummaryResponse = try await APIClient.shared.request(WorkoutSummaryResponse.self, path: path, method: "GET")
        return response.data.workout
    }
    
    func saveCachedWorkoutSummary(_ summary: WorkoutSummary, for id: String) {
        var dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data] ?? [:]
        if let data = try? JSONEncoder().encode(summary) {
            dict[id] = data
            UserDefaults.standard.set(dict, forKey: "WorkoutSummaryCache")
        }
    }
    func getCachedWorkoutSummary(for id: String) -> WorkoutSummary? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "WorkoutSummaryCache") as? [String: Data], let data = dict[id], let summary = try? JSONDecoder().decode(WorkoutSummary.self, from: data) else { return nil }
        return summary
    }
    func clearWorkoutSummaryCache() {
        UserDefaults.standard.removeObject(forKey: "WorkoutSummaryCache")
    }
    
    // MARK: - Device Info Helper
    private func getWorkoutDeviceInfo(_ workout: HKWorkout) -> (source: String, device: String?) {
        // 預設值
        var source = "apple_health"
        var deviceBrand: String? = nil
        
        // 檢查 metadata 中的裝置資訊
        if let metadata = workout.metadata {
            // 1. 先檢查是否有製造商資訊
            if let manufacturer = metadata[HKMetadataKeyDeviceManufacturerName] as? String {
                let lowercased = manufacturer.lowercased()
                if lowercased.contains("apple") {
                    source = "apple_watch"
                    deviceBrand = "Apple"
                } else if lowercased.contains("garmin") {
                    source = "garmin"
                    deviceBrand = "Garmin"
                } else if lowercased.contains("polar") {
                    source = "polar"
                    deviceBrand = "Polar"
                } else if lowercased.contains("suunto") {
                    source = "suunto"
                    deviceBrand = "Suunto"
                } else if lowercased.contains("coros") {
                    source = "coros"
                    deviceBrand = "Coros"
                } else if lowercased.contains("huawei") || lowercased.contains("honor") {
                    source = "huawei"
                    deviceBrand = "Huawei"
                } else if lowercased.contains("samsung") || lowercased.contains("galaxy") {
                    source = "samsung"
                    deviceBrand = "Samsung"
                } else if lowercased.contains("fitbit") {
                    source = "fitbit"
                    deviceBrand = "Fitbit"
                } else {
                    // 其他未列出的製造商
                    deviceBrand = manufacturer
                }
            }
            
            // 2. 如果有裝置名稱，且尚未識別出品牌，則從裝置名稱中嘗試識別
            if deviceBrand == nil, let deviceName = metadata[HKMetadataKeyDeviceName] as? String {
                let lowercased = deviceName.lowercased()
                
                // 檢查常見品牌
                let brandMappings: [(String, String)] = [
                    ("apple", "Apple"),
                    ("garmin", "Garmin"),
                    ("polar", "Polar"),
                    ("suunto", "Suunto"),
                    ("coros", "Coros"),
                    ("huawei", "Huawei"),
                    ("honor", "Huawei"),
                    ("samsung", "Samsung"),
                    ("galaxy", "Samsung"),
                    ("fitbit", "Fitbit")
                ]
                
                for (keyword, brand) in brandMappings {
                    if lowercased.contains(keyword) {
                        deviceBrand = brand
                        break
                    }
                }
                
                // 如果還是無法識別品牌，但有名稱，則使用名稱
                if deviceBrand == nil {
                    deviceBrand = deviceName
                }
            }
            
            // 3. 嘗試從 device 物件獲取更詳細的信息
            if let device = workout.device {
                if deviceBrand == nil, let manufacturer = device.manufacturer {
                    deviceBrand = manufacturer
                }
                
                // 如果有型號信息，將其附加到品牌名稱中
                if let model = device.model, let brand = deviceBrand {
                    deviceBrand = "\(brand) \(model)"
                } else if let model = device.model, deviceBrand == nil {
                    deviceBrand = model
                }
            }
        }
        
        // 如果無法識別品牌，但已經有來源，則使用來源作為品牌
        if deviceBrand == nil && source != "apple_health" {
            deviceBrand = source.capitalized
        }
        
        return (source, deviceBrand)
    }
    
    // MARK: - Error Reporting
    
    /// 詳細的運動上傳錯誤回報
    private func reportDetailedUploadError(
        workout: HKWorkout,
        workoutData: WorkoutData,
        error: Error
    ) async {
        // 收集基本運動資訊
        var errorReport: [String: Any] = [
            "workout_id": workoutData.id,
            "workout_type": workoutData.type,
            "workout_name": workoutData.name,
            "duration_seconds": workoutData.duration,
            "distance_meters": workoutData.distance,
            "start_date": workoutData.startDate,
            "end_date": workoutData.endDate,
            "source": workoutData.source ?? "unknown",
            "device": workoutData.device ?? "unknown",
            "heart_rate_samples": workoutData.heartRates.count,
            "speed_samples": workoutData.speeds.count,
            "total_calories": workoutData.totalCalories ?? 0
        ]
        
        // 收集詳細設備資訊
        if let device = workout.device {
            errorReport["device_details"] = [
                "name": device.name ?? "unknown",
                "manufacturer": device.manufacturer ?? "unknown", 
                "model": device.model ?? "unknown",
                "hardware_version": device.hardwareVersion ?? "unknown",
                "software_version": device.softwareVersion ?? "unknown"
            ]
        }
        
        // 收集來源應用資訊
        errorReport["source_details"] = [
            "name": workout.sourceRevision.source.name,
            "bundle_id": workout.sourceRevision.source.bundleIdentifier
        ]
        
        // 收集可選數據狀態
        var optionalDataStatus: [String: Any] = [:]
        if let strides = workoutData.strideLengths {
            optionalDataStatus["stride_samples"] = strides.count
        }
        if let cadences = workoutData.cadences {
            optionalDataStatus["cadence_samples"] = cadences.count
        }
        if let groundTimes = workoutData.groundContactTimes {
            optionalDataStatus["ground_contact_samples"] = groundTimes.count
        }
        if let oscillations = workoutData.verticalOscillations {
            optionalDataStatus["vertical_oscillation_samples"] = oscillations.count
        }
        if let laps = workoutData.laps {
            optionalDataStatus["lap_count"] = laps.count
            optionalDataStatus["has_lap_distances"] = laps.contains { $0.totalDistanceM != nil }
            optionalDataStatus["has_lap_heart_rates"] = laps.contains { $0.avgHeartRateBpm != nil }
        }
        errorReport["optional_data_status"] = optionalDataStatus
        
        // 錯誤詳情
        var errorDetails: [String: Any] = [
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]
        var errorType = "unknown"
        
        // 分析錯誤類型並提取 HTTP 狀態碼
        if let nsError = error as? NSError {
            errorDetails["error_domain"] = nsError.domain
            errorDetails["error_code"] = nsError.code
            
            // 檢查是否是 HTTP 錯誤（來自 APIClient）
            if nsError.domain == "APIClient" {
                errorType = "http_error"
                errorDetails["http_status_code"] = nsError.code
                
                // 嘗試從 userInfo 獲取回應內容
                if let errorMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                    errorDetails["response_body"] = errorMessage
                }
                
                // 根據 HTTP 狀態碼分類
                switch nsError.code {
                case 400...499:
                    errorDetails["error_category"] = "client_error"
                case 500...599:
                    errorDetails["error_category"] = "server_error"
                default:
                    errorDetails["error_category"] = "unknown_http_error"
                }
            }
        } else if let urlError = error as? URLError {
            errorType = "network_error"
            errorDetails["url_error_code"] = urlError.code.rawValue
            errorDetails["url_error_localized"] = urlError.localizedDescription
        } else if error is EncodingError {
            errorType = "encoding_error"
        } else if error is DecodingError {
            errorType = "decoding_error"
        }
        
        errorReport["error_details"] = errorDetails
        
        // 數據完整性分析
        var dataQualityAnalysis: [String: Any] = [
            "has_heart_rate": !workoutData.heartRates.isEmpty,
            "has_speed": !workoutData.speeds.isEmpty,
            "has_distance": workoutData.distance > 0,
            "has_calories": (workoutData.totalCalories ?? 0) > 0,
            "duration_reasonable": workoutData.duration > 0 && workoutData.duration < 86400 // 0-24小時
        ]
        
        // 心率數據品質
        if !workoutData.heartRates.isEmpty {
            let hrValues = workoutData.heartRates.map { $0.value }
            dataQualityAnalysis["hr_min"] = hrValues.min()
            dataQualityAnalysis["hr_max"] = hrValues.max()
            dataQualityAnalysis["hr_avg"] = hrValues.reduce(0, +) / Double(hrValues.count)
            dataQualityAnalysis["hr_reasonable_range"] = hrValues.allSatisfy { $0 >= 30 && $0 <= 250 }
        }
        
        errorReport["data_quality"] = dataQualityAnalysis
        
        // 使用 Firebase 記錄錯誤 - 標記需要上傳到雲端
        // 只記錄非預期的錯誤為 error，預期的錯誤記為 warning
        let shouldLogAsError = !isExpectedError(error)
        Logger.firebase(
            "Apple Health 運動記錄 V2 API 上傳失敗 - 詳細分析",
            level: shouldLogAsError ? .error : .warn,
            labels: [
                "module": "AppleHealthWorkoutUploadService",
                "action": "workout_upload_error",
                "error_type": errorType,
                "workout_type": workoutData.type,
                "device_manufacturer": (errorReport["device_details"] as? [String: String])?["manufacturer"] ?? "unknown",
                "source_bundle_id": (errorReport["source_details"] as? [String: String])?["bundle_id"] ?? "unknown",
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                "cloud_logging": "true"  // 標記需要上傳到雲端
            ],
            jsonPayload: errorReport
        )
        
        // 本地 debug 日誌
        print("❌ [詳細錯誤分析] AppleHealthWorkoutUploadService 上傳失敗")
        print("   - 運動: \(workoutData.name) (\(workoutData.type))")
        print("   - 時長: \(workoutData.duration)秒")
        print("   - 設備: \(workoutData.device ?? "unknown")")
        print("   - 錯誤類型: \(errorType)")
        if let httpStatus = errorDetails["http_status_code"] as? Int {
            print("   - HTTP 狀態: \(httpStatus)")
        }
        print("   - 錯誤訊息: \(error.localizedDescription)")
    }
    
    /// HealthKit 數據獲取錯誤回報
    private func reportHealthKitDataError(workout: HKWorkout, dataType: String, error: Error) async {
        var errorReport: [String: Any] = [
            "workout_uuid": workout.uuid.uuidString,
            "workout_type": workout.workoutActivityType.rawValue,
            "workout_type_name": workout.workoutActivityType.name,
            "duration_seconds": Int(workout.duration),
            "data_type": dataType,
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]
        
        // 收集設備資訊
        if let device = workout.device {
            errorReport["device_info"] = [
                "name": device.name ?? "unknown",
                "manufacturer": device.manufacturer ?? "unknown",
                "model": device.model ?? "unknown"
            ]
        }
        
        // 收集來源資訊
        let sourceName = workout.sourceRevision.source.name
        let bundleId = workout.sourceRevision.source.bundleIdentifier
        errorReport["source_info"] = [
            "name": sourceName,
            "bundle_id": bundleId
        ]
        
        // 檢查是否為第三方設備數據源
        let isThirdPartySource = isThirdPartyDataSource(sourceName: sourceName, bundleId: bundleId)
        errorReport["is_third_party_source"] = isThirdPartySource
        
        // 錯誤分類
        var errorCategory = "unknown"
        if let hkError = error as? HKError {
            errorCategory = "healthkit_error"
            errorReport["hk_error_code"] = hkError.code.rawValue
            
            // 針對第三方數據源的授權問題提供特殊處理
            if isThirdPartySource && (hkError.code == .errorAuthorizationNotDetermined || hkError.code == .errorAuthorizationDenied) {
                errorCategory = "third_party_authorization_error"
                print("🔧 [第三方設備] \(sourceName) 的 \(dataType) 數據需要額外授權")
                print("💡 [建議] 用戶可以在 iPhone 設定 > 隱私權與安全性 > 健康 > 數據存取與裝置 中重新授權")
            }
        } else if error is CancellationError {
            errorCategory = "cancellation_error"
        }

        // 分圈資料特殊處理 - 沒有分圈是正常現象，不應記為錯誤
        var isExpected = error is CancellationError || errorCategory == "cancellation_error"
        if dataType == "lap_data" {
            // 分圈資料缺失通常是正常的（很多運動沒有分圈）
            errorCategory = "no_lap_data_available"
            isExpected = true
            errorReport["is_lap_data_missing"] = true
        }
        Logger.firebase(
            "HealthKit 數據獲取失敗 - \(dataType)",
            level: isExpected ? LogLevel.warn : LogLevel.error,
            labels: [
                "module": "AppleHealthWorkoutUploadService",
                "action": "healthkit_data_fetch_error",
                "data_type": dataType,
                "error_category": errorCategory,
                "device_manufacturer": (errorReport["device_info"] as? [String: String])?["manufacturer"] ?? "unknown",
                "is_third_party": isThirdPartySource ? "true" : "false",
                "cloud_logging": "true"  // 標記需要上傳到雲端
            ],
            jsonPayload: errorReport
        )
        
        // 根據數據源類型提供不同的錯誤訊息
        if dataType == "lap_data" {
            print("ℹ️ [分圈資料] 此運動沒有分圈資料，這是正常的")
        } else if isThirdPartySource {
            print("⚠️ [第三方設備] 無法獲取來自 \(sourceName) 的 \(dataType) 數據: \(error.localizedDescription)")
        } else {
            print("⚠️ [HealthKit 錯誤] 無法獲取 \(dataType) 數據: \(error.localizedDescription)")
        }
    }
    
    /// 檢查是否為預期的錯誤（不應記為 error）
    private func isExpectedError(_ error: Error) -> Bool {
        // 取消錯誤
        if error is CancellationError { return true }
        if (error as NSError).code == NSURLErrorCancelled { return true }
        
        // 網路暫時性錯誤
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return true
            default:
                break
            }
        }
        
        // 429 Too Many Requests
        if (error as NSError).code == 429 { return true }
        
        return false
    }
    
    /// 檢測是否為第三方數據源（Garmin, Polar, Strava 等）
    /// - 只有「已知的第三方」才返回 true
    /// - 未知來源返回 false，會套用嚴格驗證（更安全，避免誤判）
    /// - 這確保 Apple Watch/iPhone 運動不會被誤判為第三方
    internal func isThirdPartyDataSource(sourceName: String, bundleId: String) -> Bool {
        // Apple 官方來源（正面識別）
        let appleSourceIdentifiers = [
            "com.apple.health",
            "com.apple.Health",
            "com.apple.healthd",
            "com.apple.Fitness"
        ]

        let appleSourceNames = [
            "Health",
            "Apple Watch",
            "iPhone",
            "健康",
            "Fitness"
        ]

        // 如果是 Apple 來源，直接返回 false
        if appleSourceIdentifiers.contains(bundleId) {
            return false
        }

        if appleSourceNames.contains(sourceName) {
            return false
        }

        // 已知的第三方健身設備/應用（正面識別）
        let thirdPartyIdentifiers = [
            "com.garmin.connect.mobile",
            "com.polar.polarflow",
            "com.suunto.suuntolink",
            "com.fitbit.FitbitMobile",
            "com.wahoo.wahoofitnessapp",
            "com.strava.strava",
            "com.runtastic.Runtastic",
            "com.nike.nikeplus-gps"
        ]

        let thirdPartyNames = [
            "Connect",
            "Garmin Connect",
            "Polar Flow",
            "Suunto",
            "Fitbit",
            "Wahoo",
            "Strava",
            "Runtastic",
            "Nike Run Club"
        ]

        // 只有明確識別為已知第三方，才返回 true
        // 未知來源會返回 false，套用嚴格驗證（避免誤判 Apple 設備）
        return thirdPartyIdentifiers.contains(bundleId) || thirdPartyNames.contains(sourceName)
    }

    // MARK: - Upload Tracker Helpers
    func markWorkoutAsUploaded(_ workout: HKWorkout, hasHeartRate: Bool = true) {
        // 使用 V2 API 版本標記已上傳
        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRate, apiVersion: .v2)
    }
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool { 
        // 檢查 V2 API 版本的上傳狀態
        workoutUploadTracker.isWorkoutUploaded(workout, apiVersion: .v2) 
    }
    func workoutHasHeartRate(_ workout: HKWorkout) -> Bool { 
        // 檢查 V2 API 版本的心率狀態
        workoutUploadTracker.workoutHasHeartRate(workout, apiVersion: .v2) 
    }
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? { 
        // 獲取 V2 API 版本的上傳時間
        workoutUploadTracker.getWorkoutUploadTime(workout, apiVersion: .v2) 
    }
    
    // MARK: - Result types
    enum UploadResult {
        case success(hasHeartRate: Bool)
        case failure(error: Error)
    }
    struct UploadBatchResult { let total: Int; let success: Int; let failed: Int; let failedWorkouts: [FailedWorkout] }
    struct FailedWorkout { let workout: HKWorkout; let error: Error }

    // MARK: - Required Data Validation Result
    /// 運動上傳所需的關鍵數據（心率、速度、步頻）驗證結果
    struct WorkoutRequiredData {
        let workout: HKWorkout
        let heartRateData: [(Date, Double)]
        let speedData: [(Date, Double)]
        let cadenceData: [(Date, Double)]
        let strideLengthData: [(Date, Double)]?
        let groundContactTimeData: [(Date, Double)]?
        let verticalOscillationData: [(Date, Double)]?
        let totalCalories: Double?
        let lapData: [LapData]?

        /// 檢查是否為跑步相關的運動
        var isRunningRelated: Bool {
            let activityType = workout.workoutActivityType
            return activityType == .running ||
                   activityType == .trackAndField ||
                   activityType == .hiking ||
                   activityType == .walking
        }

        /// 檢查是否滿足所有必要的數據條件
        /// - Parameter relaxed: 是否放寬驗證要求（第二次重試時使用）
        /// - Returns: 是否滿足所有必要條件
        ///
        /// ## 驗證策略：
        /// ### 第一次驗證（relaxed = false）：
        /// - 所有運動：心率 >= 2
        /// - 跑步運動：心率 >= 2 + 速度/距離來源 + (步頻或分圈)
        ///
        /// ### 第二次驗證（relaxed = true，等待 5 秒後）：
        /// - 所有運動：只需心率 >= 2
        /// - 跑步運動：只需心率 >= 2（Apple Watch 數據可能已準備好，第三方設備則沒有詳細數據）
        func isAllRequiredDataAvailable(relaxed: Bool = false) -> Bool {
            // 第一層：心率是所有運動的必需資料
            guard heartRateData.count >= 2 else {
                return false
            }

            // 如果放寬限制，只要有心率就通過
            if relaxed {
                return true
            }

            // 嚴格驗證模式
            // 檢查是否為第三方數據源
            let isThirdParty = isThirdPartyWorkout()

            if isRunningRelated && !isThirdParty {
                // Apple Watch 跑步運動：需要更嚴格的驗證
                // 第二層：跑步運動需要可靠的速度/距離來源
                let hasReliableSpeed = checkReliableSpeedData()
                guard hasReliableSpeed else {
                    return false
                }

                // 第三層：步頻或分圈（至少一個）
                let hasCadence = cadenceData.count >= 2
                let hasLaps = (lapData?.count ?? 0) > 0
                guard hasCadence || hasLaps else {
                    return false
                }

                return true
            } else {
                // 第三方設備或其他運動：只需要心率
                // Garmin/Polar 等設備的詳細數據在其自己的平台上
                return true
            }
        }

        /// 檢查是否為第三方數據源
        /// 注意：只有「已知的第三方」才返回 true，未知來源會套用嚴格驗證（較安全）
        private func isThirdPartyWorkout() -> Bool {
            let sourceName = workout.sourceRevision.source.name
            let bundleId = workout.sourceRevision.source.bundleIdentifier

            // 使用現有的檢測邏輯（只有已知第三方才返回 true）
            return AppleHealthWorkoutUploadService.shared.isThirdPartyDataSource(
                sourceName: sourceName,
                bundleId: bundleId
            )
        }

        /// 檢查是否有可靠的速度/距離來源（WorkoutRequiredData 內部方法）
        private func checkReliableSpeedData() -> Bool {
            // 優先級 1: GPS 速度樣本 (最可靠)
            if speedData.count >= 2 {
                return true
            }

            // 優先級 2: 分圈中有距離資訊
            if let laps = lapData, !laps.isEmpty {
                let hasDistanceInLaps = laps.contains { ($0.totalDistanceM ?? 0) > 0 }
                if hasDistanceInLaps {
                    return true
                }
            }

            // 優先級 3: 總距離 > 0
            if let distance = workout.totalDistance?.doubleValue(for: .meter()),
               distance > 0 {
                return true
            }

            // 優先級 4: 至少有步頻資訊（可在後端推算速度）
            if cadenceData.count >= 2 {
                return true
            }

            // 都沒有可靠資訊
            return false
        }

        func logSummary(workoutId: String) {
            let isThirdParty = isThirdPartyWorkout()
            let sourceName = workout.sourceRevision.source.name
            let bundleId = workout.sourceRevision.source.bundleIdentifier

            print("📊 [數據驗證] 運動ID: \(workoutId) | 類型: \(isRunningRelated ? "跑步相關" : "其他運動")")

            // 檢測數據來源並記錄詳細資訊
            if isThirdParty {
                print("   🔌 數據來源: \(sourceName) (已知第三方設備)")
                print("      Bundle ID: \(bundleId)")
            } else {
                // 檢查是否為已知的 Apple 設備
                let appleIdentifiers = ["com.apple.health", "com.apple.Health", "com.apple.healthd", "com.apple.Fitness"]
                let appleNames = ["Health", "Apple Watch", "iPhone", "健康", "Fitness"]
                let isKnownApple = appleIdentifiers.contains(bundleId) || appleNames.contains(sourceName)

                if isKnownApple {
                    print("   🍎 數據來源: \(sourceName) (Apple 設備)")
                    print("      Bundle ID: \(bundleId)")
                } else {
                    // 未知來源 - 套用嚴格驗證以策安全
                    print("   ⚠️  數據來源: \(sourceName) (未知來源，套用嚴格驗證)")
                    print("      Bundle ID: \(bundleId)")
                    print("      ⚠️  請檢查此來源是否應加入已知列表")
                }
            }
            print("   📍 第一層驗證 - 心率（所有運動必需）:")
            print("     - 心率: \(heartRateData.count) 筆 \(heartRateData.count >= 2 ? "✅" : "❌")")

            if isRunningRelated && !isThirdParty {
                // Apple Watch 跑步運動需要更多驗證
                print("   📍 第二層驗證 - 速度/距離來源（Apple Watch 跑步必需）:")
                print("     - GPS 速度樣本: \(speedData.count) 筆")
                print("     - 分圈資料: \(lapData?.count ?? 0) 圈")
                if let laps = lapData, !laps.isEmpty {
                    let lapDistances = laps.compactMap { $0.totalDistanceM }.reduce(0, +)
                    print("     - 分圈距離: \(String(format: "%.0f", lapDistances)) m")
                }
                if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                    print("     - 總距離: \(String(format: "%.0f", distance)) m")
                }
                print("     - 可靠速度來源: \(checkReliableSpeedData() ? "✅" : "❌")")

                print("   📍 第三層驗證 - 步頻或分圈（至少一個）:")
                print("     - 步頻: \(cadenceData.count) 筆 \(cadenceData.count >= 2 ? "✅" : "❌")")
                print("     - 分圈: \((lapData?.count ?? 0) > 0 ? "✅" : "❌")")
            } else if isThirdParty {
                // 第三方設備：只需心率
                print("   ℹ️  第三方設備運動：只需心率（詳細數據在原平台）")
                print("     - 速度: \(speedData.count) 筆 (可選)")
                print("     - 步頻: \(cadenceData.count) 筆 (可選)")
                if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                    print("     - 總距離: \(String(format: "%.0f", distance)) m (可選)")
                }
            } else {
                // 其他運動
                print("   📍 其他運動：只需心率")
                print("     - 速度: \(speedData.count) 筆 (可選)")
                print("     - 步頻: \(cadenceData.count) 筆 (可選)")
            }

            print("   📍 可選資料:")
            print("     - 步幅: \(strideLengthData?.count ?? 0) 筆")
            print("     - 觸地時間: \(groundContactTimeData?.count ?? 0) 筆")
            print("     - 垂直振幅: \(verticalOscillationData?.count ?? 0) 筆")
            print("   📋 驗證結果: \(isAllRequiredDataAvailable(relaxed: false) ? "✅ 滿足所有條件" : "❌ 未滿足所有條件")")
        }
    }
}

// Data models for API
struct WorkoutData: Codable {
    let id: String
    let name: String
    let type: String
    let startDate: TimeInterval
    let endDate: TimeInterval
    let duration: TimeInterval
    let distance: Double
    let heartRates: [HeartRateData]
    let speeds: [SpeedData]                  // 改為速度
    let strideLengths: [StrideData]?         // 步幅
    let cadences: [CadenceData]?             // 步頻
    let groundContactTimes: [GroundContactTimeData]? // 觸地時間
    let verticalOscillations: [VerticalOscillationData]? // 垂直振幅
    let totalCalories: Double?               // 總卡路里
    let laps: [LapData]?                     // 分圈資料
    let source: String?                       // 資料來源 (如: apple_health, garmin, polar 等)
    let device: String?                       // 裝置型號 (如: Apple Watch Series 7, Garmin Forerunner 945 等)
    let metadata: WorkoutMetadata?            // 環境數據（溫度、天氣、濕度等）v2.1+ 新增
}

// 環境數據結構 (v2.1+)
struct WorkoutMetadata: Codable {
    let temperatureCelsius: Double?       // 攝氏溫度
    let weatherCondition: String?          // 天氣狀況（數字或字串）
    let humidityPercent: Double?          // 濕度百分比
    let effortScore: Double?               // Effort Score (iOS 18+, 0-10 scale)

    enum CodingKeys: String, CodingKey {
        case temperatureCelsius = "temperature_celsius"
        case weatherCondition = "weather_condition"
        case humidityPercent = "humidity_percent"
        case effortScore = "rpe"  // 映射到後端的 'rpe' 欄位
    }
}

struct HeartRateData: Codable {
    let time: TimeInterval
    let value: Double
}

struct SpeedData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m/s
}

struct StrideData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m
}

struct CadenceData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：steps/min
}

struct GroundContactTimeData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：ms
}

struct VerticalOscillationData: Codable {
    let time: TimeInterval
    let value: Double  // 單位：m
}


struct EmptyResponse: Codable {}

// Extension to get a name for the workout type
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running, .trackAndField:
            return "跑步"
        case .cycling, .handCycling:
            return "騎車"
        case .walking:
            return "步行"
        case .swimming, .swimBikeRun:
            return "游泳"
        case .highIntensityIntervalTraining:
            return "高強度間歇訓練"
        case .crossTraining:
            return "交叉訓練"
        case .mixedCardio:
            return "混合有氧"
        case .traditionalStrengthTraining:
            return "重量訓練"
        case .functionalStrengthTraining:
            return "功能性訓練"
        case .yoga, .mindAndBody:
            return "瑜伽"
        case .pilates:
            return "普拉提"
        case .hiking:
            return "健行"
        default:
            return "其他運動"
        }
    }
}
