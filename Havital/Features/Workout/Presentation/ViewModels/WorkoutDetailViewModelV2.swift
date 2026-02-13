import SwiftUI
import Combine
import HealthKit

/// WorkoutDetailViewModelV2 - Clean Architecture Presentation Layer
/// Phase 3 重構：使用 ViewState 統一狀態管理，注入 WorkoutRepository
class WorkoutDetailViewModelV2: ObservableObject, TaskManageable {

    // MARK: - ViewState (主要狀態)

    @Published private(set) var state: ViewState<WorkoutV2Detail> = .loading

    // MARK: - Backward Compatibility Computed Properties

    /// 訓練詳情（向後兼容）
    var workoutDetail: WorkoutV2Detail? {
        state.data
    }

    /// 是否正在載入（向後兼容）
    var isLoading: Bool {
        state.isLoading
    }

    /// 錯誤訊息（向後兼容）
    var error: String? {
        state.error?.localizedDescription
    }

    // MARK: - Chart Data (圖表數據)

    @Published var heartRates: [DataPoint] = []
    @Published var paces: [DataPoint] = []
    @Published var speeds: [DataPoint] = []
    @Published var altitudes: [DataPoint] = []
    @Published var cadences: [DataPoint] = []

    // MARK: - Gait Analysis Data (步態分析數據)

    @Published var stanceTimes: [DataPoint] = []
    @Published var verticalRatios: [DataPoint] = []
    @Published var groundContactTimes: [DataPoint] = []
    @Published var verticalOscillations: [DataPoint] = []

    /// 原始流是否存在（用於控制是否顯示分頁）
    @Published var hasStanceTimeStream: Bool = false

    // MARK: - Zone Distribution (區間分佈)

    @Published var hrZoneDistribution: [String: Double] = [:]
    @Published var paceZoneDistribution: [String: Double] = [:]

    // MARK: - Chart Properties (圖表相關屬性)

    @Published var yAxisRange: (min: Double, max: Double) = (60, 180)

    // MARK: - Dependencies

    let workout: WorkoutV2
    private let repository: WorkoutRepository

    // MARK: - TaskManageable

    let taskRegistry = TaskRegistry()

    // MARK: - Initialization

    /// ✅ Clean Architecture: 建構子注入 Repository Protocol（不依賴 Singleton）
    init(workout: WorkoutV2,
         repository: WorkoutRepository) {
        self.workout = workout
        self.repository = repository

        Logger.debug("[WorkoutDetailViewModelV2] 初始化完成 - workout: \(workout.id)")
    }

    /// 便利初始化器（使用 DI Container 解析依賴）
    convenience init(workout: WorkoutV2) {
        let container = DependencyContainer.shared

        // 確保 Workout 模組已註冊
        if !container.isRegistered(WorkoutRepository.self) {
            container.registerWorkoutModule()
        }

        let repository: WorkoutRepository = container.resolve()

        self.init(
            workout: workout,
            repository: repository
        )
    }
    
    deinit {
        cancelAllTasks()
        // 確保所有異步任務都被取消
        heartRates.removeAll()
        paces.removeAll()
        speeds.removeAll()
        altitudes.removeAll()
        cadences.removeAll()
        
        // 步態分析數據
        stanceTimes.removeAll()
        verticalRatios.removeAll()
        groundContactTimes.removeAll()
        verticalOscillations.removeAll()
    }
    
    // MARK: - 刪除功能

    /// 刪除運動記錄 - 使用 Repository
    /// - Returns: 是否刪除成功
    func deleteWorkout() async -> Bool {
        do {
            // 使用 Repository 刪除（會同時處理 API 和緩存）
            try await repository.deleteWorkout(id: workout.id)

            // ✅ Clean Architecture: 發布 CacheEventBus 事件通知其他模組
            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (刪除)")

            Logger.firebase(
                "成功刪除運動記錄",
                level: .info,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "delete_workout"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": workout.activityType
                ]
            )

            return true
        } catch {
            Logger.firebase(
                "刪除運動記錄失敗",
                level: .error,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "delete_workout",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "error": error.localizedDescription
                ]
            )
            return false
        }
    }

    // MARK: - 訓練心得更新功能

    /// 更新訓練心得
    /// - Parameter notes: 訓練心得文本（最多 \(WorkoutConstants.maxTrainingNotesLength) 字符）
    /// - Returns: 是否更新成功
    func updateTrainingNotes(_ notes: String) async -> Bool {
        // 驗證字符數限制
        guard notes.count <= WorkoutConstants.maxTrainingNotesLength else {
            Logger.error("[WorkoutDetailViewModelV2] 訓練心得超過\(WorkoutConstants.maxTrainingNotesLength)字符限制")
            return false
        }

        do {
            Logger.debug("[WorkoutDetailViewModelV2] 更新訓練心得 - workout_id: \(workout.id)")

            // ✅ Clean Architecture: 使用 Repository 更新訓練心得
            try await repository.updateTrainingNotes(id: workout.id, notes: notes)

            // Repository 已經清除了緩存，現在刷新詳情以立即顯示更新
            await refreshWorkoutDetail()

            // ✅ Clean Architecture: 發布 CacheEventBus 事件通知其他模組
            await MainActor.run {
                CacheEventBus.shared.publish(.dataChanged(.workouts))
            }
            Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (訓練心得更新)")

            Logger.firebase(
                "訓練心得更新成功",
                level: .info,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "update_training_notes"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "notes_length": notes.count
                ]
            )

            return true
        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 訓練心得更新已取消")
            return false
        } catch {
            Logger.firebase(
                "訓練心得更新失敗",
                level: .error,
                labels: [
                    "module": "WorkoutDetailViewModelV2",
                    "action": "update_training_notes",
                    "cloud_logging": "true"
                ],
                jsonPayload: [
                    "workout_id": workout.id,
                    "error": error.localizedDescription
                ]
            )
            return false
        }
    }

    // MARK: - 重新上傳功能 (Apple Health Only)

    /// 重新上傳結果枚舉
    enum ReuploadResult {
        case success(hasHeartRate: Bool)
        case insufficientHeartRate(count: Int)
        case failure(message: String)
    }
    
    /// 從 HealthKit 查找匹配的運動記錄
    private func findMatchingHKWorkout() async -> HKWorkout? {
        let healthStore = HKHealthStore()
        let workoutType = HKObjectType.workoutType()

        let startTime = workout.startDate.addingTimeInterval(-60)
        let endTime = workout.endDate.addingTimeInterval(60)
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)

        let targetDuration = TimeInterval(self.workout.durationSeconds)
        let targetDistance = self.workout.distanceMeters ?? 0

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    print("❌ 查詢 HealthKit 運動記錄失敗: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    print("❌ 找不到對應的 HealthKit 運動記錄")
                    continuation.resume(returning: nil)
                    return
                }

                let matchingWorkout = workouts.first { hkWorkout in
                    let durationDiff = abs(hkWorkout.duration - targetDuration)
                    let distance = hkWorkout.totalDistance?.safeDoubleValue(for: .meter()) ?? 0
                    let distanceDiff = abs(distance - targetDistance)
                    return durationDiff <= 5 && distanceDiff <= 50
                } ?? workouts.first

                continuation.resume(returning: matchingWorkout)
            }

            healthStore.execute(query)
        }
    }

    /// 重新上傳 Apple Health 的運動記錄（包含心率檢查）
    func reuploadWorkoutWithHeartRateCheck() async -> ReuploadResult {
        let provider = workout.provider.lowercased()
        guard provider.contains("apple") || provider.contains("health") || provider == "apple_health" else {
            print("⚠️ 只有 Apple Health 資料才能重新上傳")
            return .failure(message: "只有 Apple Health 資料才能重新上傳")
        }

        print("🔄 開始重新上傳運動記錄（含心率檢查）- ID: \(workout.id)")

        guard let hkWorkout = await findMatchingHKWorkout() else {
            return .failure(message: "找不到匹配的 HealthKit 運動記錄")
        }

        do {
            let healthKitManager = HealthKitManager()
            let heartRateData = try await healthKitManager.fetchHeartRateData(for: hkWorkout, forceRefresh: true, retryAttempt: 0)

            print("🔍 心率數據檢查: \(heartRateData.count) 筆")

            if heartRateData.count < 2 {
                print("⚠️ 心率數據不足: \(heartRateData.count) < 2 筆")
                return .insufficientHeartRate(count: heartRateData.count)
            }

            let uploadService = AppleHealthWorkoutUploadService.shared
            let result = try await uploadService.uploadWorkout(
                hkWorkout,
                force: true,
                retryHeartRate: true,
                source: "apple_health"
            )

            switch result {
            case .success(let hasHeartRate):
                print("✅ 運動記錄重新上傳成功，心率資料: \(hasHeartRate ? "有" : "無")")
                await MainActor.run {
                    CacheEventBus.shared.publish(.dataChanged(.workouts))
                }
                Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (心率檢查上傳)")
                return .success(hasHeartRate: hasHeartRate)

            case .failure(let error):
                print("❌ 運動記錄重新上傳失敗: \(error.localizedDescription)")
                return .failure(message: "重新上傳失敗: \(error.localizedDescription)")
            }
        } catch {
            print("❌ 重新上傳過程發生錯誤: \(error.localizedDescription)")
            return .failure(message: "重新上傳過程發生錯誤: \(error.localizedDescription)")
        }
    }
    
    /// 強制重新上傳（忽略心率檢查）
    func forceReuploadWorkout() async -> Bool {
        return await reuploadWorkout()
    }
    
    /// 重新上傳 Apple Health 的運動記錄
    func reuploadWorkout() async -> Bool {
        let provider = workout.provider.lowercased()
        guard provider.contains("apple") || provider.contains("health") || provider == "apple_health" else {
            print("⚠️ 只有 Apple Health 資料才能重新上傳")
            return false
        }

        print("🔄 開始重新上傳運動記錄 - ID: \(workout.id)")

        guard let hkWorkout = await findMatchingHKWorkout() else {
            print("❌ 找不到匹配的 HealthKit 運動記錄")
            return false
        }

        print("✅ 找到匹配的 HealthKit 運動記錄: \(hkWorkout.uuid)")

        do {
            let uploadService = AppleHealthWorkoutUploadService.shared
            let result = try await uploadService.uploadWorkout(
                hkWorkout,
                force: true,
                retryHeartRate: true,
                source: "apple_health"
            )

            switch result {
            case .success(let hasHeartRate):
                print("✅ 運動記錄重新上傳成功，心率資料: \(hasHeartRate ? "有" : "無")")
                await MainActor.run {
                    CacheEventBus.shared.publish(.dataChanged(.workouts))
                }
                Logger.debug("[WorkoutDetailViewModelV2] 發布 .dataChanged(.workouts) 事件 (重新上傳)")
                return true

            case .failure(let error):
                print("❌ 運動記錄重新上傳失敗: \(error.localizedDescription)")
                return false
            }
        } catch {
            print("❌ 重新上傳過程發生錯誤: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 時間序列數據處理
    
    /// 處理時間序列數據，轉換成圖表格式
    private func processTimeSeriesData(from detail: WorkoutV2Detail) {
        // 基於實際 API 回應格式處理時間序列數據
        if let timeSeriesData = detail.timeSeries {
            processTimeSeriesFromAPI(timeSeriesData)
        }
    }
    
    /// 處理來自 API 的時間序列數據
    private func processTimeSeriesFromAPI(_ timeSeries: V2TimeSeries) {
        let baseTime = workout.startDate

        // 處理心率數據
        if let heartRateData = timeSeries.heartRatesBpm,
           let timestamps = timeSeries.timestampsS {
            
            var heartRatePoints: [DataPoint] = []
            
            for (index, heartRate) in heartRateData.enumerated() {
                if index < timestamps.count,
                   let hr = heartRate,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    heartRatePoints.append(DataPoint(time: time, value: Double(hr)))
                }
            }
            
            // 數據降採樣以提升效能
            self.heartRates = downsampleData(heartRatePoints, maxPoints: 500)
        }

        // 處理配速數據，使用 paces_s_per_km 直接顯示配速
        if let pacesData = timeSeries.pacesSPerKm,
           let timestamps = timeSeries.timestampsS {
            
            var pacePoints: [DataPoint] = []
            
            for (index, pace) in pacesData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的配速值
                    if let paceValue = pace,
                       paceValue > 0 && paceValue < 3600 && paceValue.isFinite { // 合理的配速範圍：0-60分鐘/公里
                        pacePoints.append(DataPoint(time: time, value: paceValue))
                    }
                    // 如果配速是null或異常值，就直接跳過該數據點
                    // 這樣圖表會在該時間段出現斷點，正確顯示間歇訓練的休息段
                }
            }
            
            // 直接使用所有有效數據點，不進行降採樣
            self.paces = pacePoints
        }
        
        // 處理步態分析數據 - 觸地時間 (毫秒)
        print("📊 [GaitAnalysis] 檢查觸地時間數據...")
        print("📊 [GaitAnalysis] stanceTimesMs 存在: \(timeSeries.stanceTimesMs != nil)")
        print("📊 [GaitAnalysis] groundContactTimesMs 存在: \(timeSeries.groundContactTimesMs != nil)")
        print("📊 [GaitAnalysis] timestampsS 存在: \(timeSeries.timestampsS != nil)")

        // 優先使用 stance_times_ms，若缺失則回退到 ground_contact_times_ms
        let stanceTimeSource: String
        let stanceTimeDataFallback = timeSeries.stanceTimesMs ?? timeSeries.groundContactTimesMs
        if timeSeries.stanceTimesMs != nil {
            stanceTimeSource = "stance_times_ms"
        } else if timeSeries.groundContactTimesMs != nil {
            stanceTimeSource = "ground_contact_times_ms"
        } else {
            stanceTimeSource = "none"
        }
        self.hasStanceTimeStream = stanceTimeSource != "none"

        if let stanceTimeData = stanceTimeDataFallback,
           let timestamps = timeSeries.timestampsS {

            print("📊 [GaitAnalysis] 使用資料來源: \(stanceTimeSource)")
            print("📊 [GaitAnalysis] 觸地時間原始數據點數: \(stanceTimeData.count)")
            print("📊 [GaitAnalysis] 時間戳數據點數: \(timestamps.count)")

            var stanceTimePoints: [DataPoint] = []
            var validPointsCount = 0
            var invalidPointsCount = 0

            for (index, stanceTime) in stanceTimeData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))

                    // 合理的觸地時間範圍過濾 (50-600ms)
                    if let stanceValue = stanceTime,
                       stanceValue > 50 && stanceValue < 600 && stanceValue.isFinite {
                        stanceTimePoints.append(DataPoint(time: time, value: stanceValue))
                        validPointsCount += 1

                        if validPointsCount <= 5 { // 顯示前5個有效數據點
                            print("📊 [GaitAnalysis] 觸地時間[\(validPointsCount)]: \(String(format: "%.1f", stanceValue)) ms")
                        }
                    } else {
                        invalidPointsCount += 1
                        if invalidPointsCount <= 3 { // 顯示前3個無效數據點的詳細信息
                            if stanceTime == nil {
                                print("📊 [GaitAnalysis] 無效觸地時間[\(invalidPointsCount)]: null (索引 \(index))")
                            } else {
                                print("📊 [GaitAnalysis] 無效觸地時間[\(invalidPointsCount)]: \(stanceTime!) ms (索引 \(index))")
                            }
                        }
                    }
                }
            }

            print("📊 [GaitAnalysis] 有效觸地時間數據點: \(validPointsCount)")
            print("📊 [GaitAnalysis] 無效觸地時間數據點: \(invalidPointsCount)")

            self.stanceTimes = downsampleData(stanceTimePoints, maxPoints: 500)
            print("📊 [GaitAnalysis] 降採樣後觸地時間數據點: \(self.stanceTimes.count)")
        } else {
            print("⚠️ [GaitAnalysis] 沒有觸地時間數據或時間戳數據")
            self.stanceTimes = []
        }
        
        // 處理步態分析數據 - 垂直比率/移動效率 (%)
        if let verticalRatioData = timeSeries.verticalRatios,
           let timestamps = timeSeries.timestampsS {
            
            var verticalRatioPoints: [DataPoint] = []
            
            for (index, verticalRatio) in verticalRatioData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的垂直比率值 (3-15%是合理範圍)
                    if let ratioValue = verticalRatio,
                       ratioValue > 0 && ratioValue < 30 && ratioValue.isFinite {
                        verticalRatioPoints.append(DataPoint(time: time, value: ratioValue))
                    }
                }
            }
            
            self.verticalRatios = downsampleData(verticalRatioPoints, maxPoints: 500)
        }
        
        // 處理步態分析數據 - 地面接觸時間 (毫秒) 
        if let groundContactData = timeSeries.groundContactTimesMs,
           let timestamps = timeSeries.timestampsS {
            
            var groundContactPoints: [DataPoint] = []
            
            for (index, contactTime) in groundContactData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的地面接觸時間值 (150-400毫秒是合理範圍)
                    if let contactValue = contactTime,
                       contactValue > 100 && contactValue < 500 && contactValue.isFinite {
                        groundContactPoints.append(DataPoint(time: time, value: contactValue))
                    }
                }
            }
            
            self.groundContactTimes = downsampleData(groundContactPoints, maxPoints: 500)
        }
        
        // 處理步態分析數據 - 垂直振幅 (毫米)
        if let verticalOscillationData = timeSeries.verticalOscillationsMm,
           let timestamps = timeSeries.timestampsS {
            
            var verticalOscillationPoints: [DataPoint] = []
            
            for (index, oscillation) in verticalOscillationData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))
                    
                    // 只處理有效的垂直振幅值 (50-150毫米是合理範圍)
                    if let oscillationValue = oscillation,
                       oscillationValue > 30 && oscillationValue < 200 && oscillationValue.isFinite {
                        verticalOscillationPoints.append(DataPoint(time: time, value: oscillationValue))
                    }
                }
            }
            
            self.verticalOscillations = downsampleData(verticalOscillationPoints, maxPoints: 500)
        }
        
        // 處理步頻數據 (每分鐘步數)
        if let cadenceData = timeSeries.cadencesSpm,
           let timestamps = timeSeries.timestampsS {

            var cadencePoints: [DataPoint] = []

            for (index, cadence) in cadenceData.enumerated() {
                if index < timestamps.count,
                   let timestamp = timestamps[index] {
                    let time = baseTime.addingTimeInterval(TimeInterval(timestamp))

                    // 只處理有效的步頻值 (120-220 spm是合理範圍)
                    if let cadenceValue = cadence,
                       cadenceValue > 100 && cadenceValue < 250 && cadenceValue != 0 {
                        cadencePoints.append(DataPoint(time: time, value: Double(cadenceValue)))
                    }
                }
            }

            self.cadences = downsampleData(cadencePoints, maxPoints: 500)
        }
    }
    
    /// 數據降採樣以提升圖表效能
    private func downsampleData(_ dataPoints: [DataPoint], maxPoints: Int) -> [DataPoint] {
        guard dataPoints.count > maxPoints else { return dataPoints }
        
        let step = dataPoints.count / maxPoints
        var sampledPoints: [DataPoint] = []
        
        for i in stride(from: 0, to: dataPoints.count, by: step) {
            sampledPoints.append(dataPoints[i])
        }
        
        // 確保包含最後一個點
        if let lastPoint = dataPoints.last, sampledPoints.last != lastPoint {
            sampledPoints.append(lastPoint)
        }
        
        return sampledPoints
    }
    
    // MARK: - 數據載入
    
    /// 載入運動詳細資料（只載入一次，不支援刷新）
    func loadWorkoutDetail() async {
        // 如果已經載入過，直接返回
        if state.hasData {
            return
        }

        await executeTask(id: TaskID("load_workout_detail_\(workout.id)"), cooldownSeconds: 5) {
            await self.performLoadWorkoutDetail()
        }
    }
    
    /// 重新載入運動詳細資料（用於下拉刷新）
    func refreshWorkoutDetail() async {
        await executeTask(id: TaskID("refresh_workout_detail_\(workout.id)"), cooldownSeconds: 5) {
            await self.performRefreshWorkoutDetail()
        }
    }
    
    /// 取消載入任務
    func cancelLoadingTasks() {
        cancelAllTasks()
    }
    
    @MainActor
    private func performRefreshWorkoutDetail() async {
        // 保持當前數據，設置載入中狀態
        state = .loading

        do {
            // 檢查任務是否被取消
            try Task.checkCancellation()

            // ✅ Clean Architecture: 使用 Repository 強制刷新詳細數據
            let response = try await repository.refreshWorkoutDetail(id: workout.id)

            // 檢查任務是否被取消
            try Task.checkCancellation()

            // 清除舊的圖表數據
            self.heartRates.removeAll()
            self.paces.removeAll()
            self.speeds.removeAll()
            self.altitudes.removeAll()
            self.cadences.removeAll()

            // 清除步態分析數據
            self.stanceTimes.removeAll()
            self.verticalRatios.removeAll()
            self.groundContactTimes.removeAll()
            self.verticalOscillations.removeAll()

            // 處理時間序列數據，轉換成圖表格式
            self.processTimeSeriesData(from: response)

            // 設置心率 Y 軸範圍
            if !heartRates.isEmpty {
                let hrValues = heartRates.map { $0.value }
                let minHR = hrValues.min() ?? 60
                let maxHR = hrValues.max() ?? 180
                let margin = (maxHR - minHR) * 0.1
                self.yAxisRange = (max(minHR - margin, 50), min(maxHR + margin, 220))
            }

            // 更新狀態
            self.state = .loaded(response)

            Logger.firebase(
                "運動詳情刷新成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "refresh_detail"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": response.activityType
                ]
            )

        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 刷新任務被取消")
            // 取消時不更新狀態，保持原有數據
        } catch {
            self.state = .error(error.toDomainError())

            // 記錄詳細錯誤資訊到 Firebase Cloud Logging
            let errorDetails: [String: Any] = [
                "error_type": String(describing: type(of: error)),
                "error_description": error.localizedDescription,
                "error_domain": (error as NSError).domain,
                "error_code": (error as NSError).code,
                "workout_id": workout.id,
                "activity_type": workout.activityType,
                "has_cached_detail": workoutDetail != nil,
                "context": "workout_detail_refresh"
            ]

            Logger.firebase("Workout detail refresh failed with detailed error info",
                          level: .error,
                          labels: ["cloud_logging": "true", "component": "WorkoutDetailViewModelV2", "operation": "refreshWorkoutDetail"],
                          jsonPayload: errorDetails)
        }
    }

    @MainActor
    private func performLoadWorkoutDetail() async {
        state = .loading

        do {
            // 檢查任務是否被取消
            try Task.checkCancellation()

            // ✅ Clean Architecture: 使用 Repository 獲取詳細數據（自動處理緩存）
            let response = try await repository.getWorkoutDetail(id: workout.id)

            // 檢查任務是否被取消
            try Task.checkCancellation()

            // 處理時間序列數據，轉換成圖表格式
            self.processTimeSeriesData(from: response)

            // 設置心率 Y 軸範圍
            if !heartRates.isEmpty {
                let hrValues = heartRates.map { $0.value }
                let minHR = hrValues.min() ?? 60
                let maxHR = hrValues.max() ?? 180
                let margin = (maxHR - minHR) * 0.1
                self.yAxisRange = (max(minHR - margin, 50), min(maxHR + margin, 220))
            }

            // 更新狀態
            self.state = .loaded(response)

            Logger.firebase(
                "運動詳情載入成功",
                level: .info,
                labels: ["module": "WorkoutDetailViewModelV2", "action": "load_detail"],
                jsonPayload: [
                    "workout_id": workout.id,
                    "activity_type": response.activityType
                ]
            )

        } catch is CancellationError {
            Logger.debug("[WorkoutDetailViewModelV2] 載入任務被取消")
            // 取消時不更新狀態
        } catch {
            self.state = .error(error.toDomainError())

            // 記錄詳細錯誤資訊到 Firebase Cloud Logging
            let errorDetails: [String: Any] = [
                "error_type": String(describing: type(of: error)),
                "error_description": error.localizedDescription,
                "error_domain": (error as NSError).domain,
                "error_code": (error as NSError).code,
                "workout_id": workout.id,
                "activity_type": workout.activityType,
                "has_cached_detail": workoutDetail != nil,
                "context": "workout_detail_load"
            ]

            Logger.firebase("Workout detail load failed with detailed error info",
                          level: .error,
                          labels: ["cloud_logging": "true", "component": "WorkoutDetailViewModelV2", "operation": "loadWorkoutDetail"],
                          jsonPayload: errorDetails)
        }
    }
    
    // MARK: - 格式化方法
    
    var workoutType: String {
        workout.activityType
    }
    
    var duration: String {
        let duration = workout.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var distance: String? {
        guard let distance = workout.distance else { return nil }
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    var calories: String? {
        guard let calories = workout.calories else { return nil }
        return String(format: "%.0f kcal", calories)
    }
    
    var pace: String? {
        guard let distance = workout.distance, distance > 0 else { return nil }
        
        let paceSecondsPerMeter = workout.duration / distance
        let paceInSecondsPerKm = paceSecondsPerMeter * 1000
        let paceMinutes = Int(paceInSecondsPerKm) / 60
        let paceRemainingSeconds = Int(paceInSecondsPerKm) % 60
        return String(format: "%d:%02d/km", paceMinutes, paceRemainingSeconds)
    }
    
    var averageHeartRate: String? {
        return workout.basicMetrics?.avgHeartRateBpm.map { "\($0) bpm" }
    }
    
    var maxHeartRate: String? {
        return workout.basicMetrics?.maxHeartRateBpm.map { "\($0) bpm" }
    }
    
    var dynamicVdot: String? {
        return workout.dynamicVdot.map { String(format: "%.1f", $0) }
    }
    
    var trainingType: String? {
        guard let type = workout.trainingType else { return nil }
        
        switch type.lowercased() {
        case "easy_run", "easy":
            return L10n.Training.TrainingType.easy.localized
        case "recovery_run":
            return L10n.Training.TrainingType.recovery.localized
        case "long_run":
            return L10n.Training.TrainingType.long.localized
        case "tempo":
            return L10n.Training.TrainingType.tempo.localized
        case "threshold":
            return L10n.Training.TrainingType.threshold.localized
        case "interval":
            return L10n.Training.TrainingType.interval.localized
        case "fartlek":
            return L10n.Training.TrainingType.fartlek.localized
        case "combination":
            return L10n.Training.TrainingType.combination.localized
        case "hill_training":
            return L10n.Training.TrainingType.hill.localized
        case "race":
            return L10n.Training.TrainingType.race.localized
        case "rest":
            return L10n.Training.TrainingType.rest.localized
        default:
            return type
        }
    }
    
    // MARK: - 圖表相關屬性
    
    var maxHeartRateString: String {
        guard let max = heartRates.map({ $0.value }).max(), !heartRates.isEmpty else { return "--" }
        return "\(Int(max)) bpm"
    }
    
    var minHeartRateString: String {
        guard let min = heartRates.map({ $0.value }).min(), !heartRates.isEmpty else { return "--" }
        return "\(Int(min)) bpm"
    }
    
    var chartAverageHeartRate: Double? {
        guard !heartRates.isEmpty else { return nil }
        let sum = heartRates.reduce(0.0) { $0 + $1.value }
        return sum / Double(heartRates.count)
    }
} 
