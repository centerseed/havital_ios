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
        guard UserPreferenceManager.shared.dataSourcePreference == .appleHealth else {
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

        // 檢查是否滿足所有必要條件
        if !requiredData.isAllRequiredDataAvailable {
            print("❌ [Upload] 數據驗證失敗 - 運動ID: \(workoutId)")

            if requiredData.isRunningRelated {
                print("   運動類型：跑步相關（需要心率、速度、步頻）")
                print("   缺失條件：")
                if requiredData.heartRateData.count < 2 {
                    print("   - 心率數據不足 (\(requiredData.heartRateData.count) < 2) [必需]")
                }
                if requiredData.speedData.count < 2 {
                    print("   - 速度數據不足 (\(requiredData.speedData.count) < 2) [必需]")
                }
                if requiredData.cadenceData.count < 2 {
                    print("   - 步頻數據不足 (\(requiredData.cadenceData.count) < 2) [必需]")
                }
            } else {
                print("   運動類型：其他運動（只需要心率）")
                print("   缺失條件：")
                if requiredData.heartRateData.count < 2 {
                    print("   - 心率數據不足 (\(requiredData.heartRateData.count) < 2) [必需]")
                }
            }
            throw WorkoutV2ServiceError.invalidWorkoutData
        }

        print("✅ [Upload] 數據驗證通過 - 運動ID: \(workoutId)，即將延遲20秒後上傳...")

        // 所有必要數據都滿足條件，延遲20秒再上傳
        // 這樣做是為了給Apple Health更多時間同步所有數據
        let delayInNanoseconds: UInt64 = 20_000_000_000 // 20秒
        try? await Task.sleep(nanoseconds: delayInNanoseconds)

        print("📤 [Upload] 延遲完成，現在開始上傳 - 運動ID: \(workoutId)")

        // 獲取設備信息
        let deviceInfo = getWorkoutDeviceInfo(workout)
        let actualSource = deviceInfo.source
        let actualDevice = deviceInfo.device

        // 轉成 DataPoint
        let heartRates      = requiredData.heartRateData.map { DataPoint(time: $0.0, value: $0.1) }
        let speeds          = requiredData.speedData.map { DataPoint(time: $0.0, value: $0.1) }
        let strides         = requiredData.strideLengthData?.map { DataPoint(time: $0.0, value: $0.1) }
        let cadences        = requiredData.cadenceData.map { DataPoint(time: $0.0, value: $0.1) }
        let contacts        = requiredData.groundContactTimeData?.map { DataPoint(time: $0.0, value: $0.1) }
        let oscillations    = requiredData.verticalOscillationData?.map { DataPoint(time: $0.0, value: $0.1) }

        try await postWorkoutDetails(workout: workout,
                                     heartRates: heartRates,
                                     speeds: speeds,
                                     strideLengths: strides,
                                     cadences: cadences,
                                     groundContactTimes: contacts,
                                     verticalOscillations: oscillations,
                                     totalCalories: requiredData.totalCalories,
                                     laps: requiredData.lapData,
                                     source: actualSource,
                                     device: actualDevice)

        // 標記為已上傳（所有必要數據都已驗證）
        let hasHeartRateData = requiredData.heartRateData.count >= 2
        workoutUploadTracker.markWorkoutAsUploaded(workout, hasHeartRate: hasHeartRateData, apiVersion: .v2)

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
        
        for w in workouts {
            do {
                _ = try await uploadWorkout(w, force: force, retryHeartRate: retryHeartRate)
                success += 1
                try? await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                failed += 1
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
                    }
                )
            }
        } catch {
            print("❌ [驗證] 無法獲取心率數據: \(error.localizedDescription)")
            await reportHealthKitDataError(workout: workout, dataType: "heart_rate", error: error)
        }

        // 2. 獲取速度數據（跑步運動才需要重試，其他運動只嘗試一次）
        var speedData: [(Date, Double)] = []
        do {
            speedData = try await healthKitManager.fetchSpeedData(for: workout)
            print("📊 [驗證] 初次速度數據獲取: \(speedData.count) 筆")

            // 只有跑步相關運動才進行速度數據重試
            if isRunning && speedData.count < 2 {
                speedData = await retryFetchingData(
                    name: "速度",
                    currentData: speedData,
                    fetchOperation: { _ in
                        try await self.healthKitManager.fetchSpeedData(for: workout)
                    }
                )
            }
        } catch {
            print("❌ [驗證] 無法獲取速度數據: \(error.localizedDescription)")
            await reportHealthKitDataError(workout: workout, dataType: "speed", error: error)
        }

        // 3. 獲取步頻數據（跑步運動才需要重試，其他運動只嘗試一次）
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
                    }
                )
            }
        } catch {
            print("❌ [驗證] 無法獲取步頻數據: \(error.localizedDescription)")
            await reportHealthKitDataError(workout: workout, dataType: "cadence", error: error)
        }

        // 4. 獲取輔助數據（可選）
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

        var lapData: [LapData]?
        do {
            lapData = try await healthKitManager.fetchLapData(for: workout)
            print("🏃‍♂️ [驗證] 分圈資料獲取成功: \(lapData?.count ?? 0) 圈")
        } catch {
            lapData = nil
            await reportHealthKitDataError(workout: workout, dataType: "lap_data", error: error)
            print("⚠️ [驗證] 分圈資料獲取失敗，將繼續上傳運動記錄")
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
    private func retryFetchingData(
        name: String,
        currentData: [(Date, Double)],
        fetchOperation: @escaping (_ attempt: Int) async throws -> [(Date, Double)]
    ) async -> [(Date, Double)] {
        var data = currentData
        let maxRetries = 5
        let retryInterval: UInt64 = 30_000_000_000 // 30秒

        print("🔄 [驗證] \(name)數據不足(\(data.count) < 2)，開始重試流程...")

        for attempt in 1...maxRetries {
            print("🔄 [驗證] \(name)數據重試 \(attempt)/\(maxRetries)，等待30秒...")

            try? await Task.sleep(nanoseconds: retryInterval)

            do {
                let retryData = try await fetchOperation(attempt)
                print("🔄 [驗證] 重試第 \(attempt) 次獲取\(name)數據：\(retryData.count) 筆")

                if retryData.count > data.count {
                    data = retryData
                    print("✅ [驗證] 重試成功，更新\(name)數據：\(data.count) 筆")
                }

                if data.count >= 5 {
                    print("✅ [驗證] \(name)數據充足，停止重試")
                    break
                }
            } catch {
                print("⚠️ [驗證] 重試第 \(attempt) 次失敗: \(error.localizedDescription)")
            }
        }

        if data.count < 5 {
            print("⚠️ [驗證] 重試 \(maxRetries) 次後\(name)數據仍不足：\(data.count) 筆")
        }

        return data
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
                                    device: String?) async throws {
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
            device: device)
        
        do {
            // 先嘗試上傳，如果成功就結束
            let _: EmptyResponse = try await APIClient.shared.request(
                EmptyResponse.self,
                path: "/v2/workouts",
                method: "POST",
                body: try JSONEncoder().encode(workoutData)
            )
        } catch {
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
    
    /// 檢查是否為第三方數據源
    private func isThirdPartyDataSource(sourceName: String, bundleId: String) -> Bool {
        // Apple 官方來源
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
        
        // 檢查 bundle ID
        if appleSourceIdentifiers.contains(bundleId) {
            return false
        }
        
        // 檢查來源名稱
        if appleSourceNames.contains(sourceName) {
            return false
        }
        
        // 其他常見的第三方健身設備/應用
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
        /// - 跑步相關運動：需要心率 >= 2, 速度 >= 2, 步頻 >= 2
        /// - 其他運動：只需要心率 >= 2
        var isAllRequiredDataAvailable: Bool {
            if isRunningRelated {
                // 跑步運動需要三個條件都滿足
                return heartRateData.count >= 2 && speedData.count >= 2 && cadenceData.count >= 2
            } else {
                // 其他運動只需要心率
                return heartRateData.count >= 2
            }
        }

        func logSummary(workoutId: String) {
            print("📊 [數據驗證] 運動ID: \(workoutId) | 類型: \(isRunningRelated ? "跑步相關" : "其他運動")")
            print("   - 心率: \(heartRateData.count) 筆 \(heartRateData.count >= 2 ? "✅" : "❌")")
            if isRunningRelated {
                print("   - 速度: \(speedData.count) 筆 \(speedData.count >= 2 ? "✅" : "❌") [跑步必需]")
                print("   - 步頻: \(cadenceData.count) 筆 \(cadenceData.count >= 2 ? "✅" : "❌") [跑步必需]")
            } else {
                print("   - 速度: \(speedData.count) 筆 (可選)")
                print("   - 步頻: \(cadenceData.count) 筆 (可選)")
            }
            print("   - 步幅: \(strideLengthData?.count ?? 0) 筆")
            print("   - 觸地時間: \(groundContactTimeData?.count ?? 0) 筆")
            print("   - 垂直振幅: \(verticalOscillationData?.count ?? 0) 筆")
            print("   - 總體結果: \(isAllRequiredDataAvailable ? "✅ 滿足所有條件" : "❌ 未滿足所有條件")")
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
