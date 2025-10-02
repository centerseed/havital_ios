import Foundation
import HealthKit

class HealthKitManager: ObservableObject, TaskManageable {
    public var healthStore: HKHealthStore { _healthStore }
    private let _healthStore = HKHealthStore()
    
    // MARK: - TaskManageable
    let taskRegistry = TaskRegistry()
    
    // 專用的 HealthKit 操作序列隊列
    private let healthKitQueue = DispatchQueue(label: "com.havital.healthkit", qos: .userInitiated)
    
    // MARK: - 初始化和授權
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit 不可用")
            throw HealthError.notAvailable
        }
        
        // 定義需要讀取的數據類型
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
            HKObjectType.quantityType(forIdentifier: .runningStrideLength)!,
            HKObjectType.quantityType(forIdentifier: .runningGroundContactTime)!,
            HKObjectType.quantityType(forIdentifier: .runningVerticalOscillation)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!
        ]
        
        // 定義需要寫入的數據類型
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthError.authorizationDenied)
                }
            }
        }
    }
    
    // MARK: - 跑步數據獲取
    
    // 獲取速度數據
    func fetchSpeedData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        guard let runningSpeedType = HKObjectType.quantityType(forIdentifier: .runningSpeed) else {
            throw HealthError.notAvailable
        }

        return try await fetchQuantitySamples(
            sampleType: runningSpeedType,
            workout: workout,
            unit: HKUnit.meter().unitDivided(by: HKUnit.second())
        )
    }

    // 獲取步幅數據
    func fetchStrideLengthData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        guard let strideLengthType = HKObjectType.quantityType(forIdentifier: .runningStrideLength) else {
            throw HealthError.notAvailable
        }
        
        return try await fetchQuantitySamples(
            sampleType: strideLengthType,
            workout: workout,
            unit: HKUnit.meter()
        )
    }

    // 獲取觸地時間數據
    func fetchGroundContactTimeData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        guard let groundContactTimeType = HKObjectType.quantityType(forIdentifier: .runningGroundContactTime) else {
            throw HealthError.notAvailable
        }
        
        return try await fetchQuantitySamples(
            sampleType: groundContactTimeType,
            workout: workout,
            unit: HKUnit.secondUnit(with: .milli)
        )
    }

    // 獲取垂直振幅數據
    func fetchVerticalOscillationData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        guard let verticalOscillationType = HKObjectType.quantityType(forIdentifier: .runningVerticalOscillation) else {
            throw HealthError.notAvailable
        }
        
        return try await fetchQuantitySamples(
            sampleType: verticalOscillationType,
            workout: workout,
            unit: HKUnit.meter()
        )
    }
    
    // 獲取步頻數據 (先嘗試直接獲取，失敗則通過步數計算)
    func fetchCadenceData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        print("🔍 [Cadence] 開始獲取步頻數據...")
        
        // 方法1: 嘗試直接獲取步頻數據 (某些第三方設備可能提供)
        // 檢查是否有第三方應用寫入的步頻數據
        do {
            let directCadence = try await fetchDirectCadenceData(for: workout)
            if !directCadence.isEmpty {
                print("✅ [Cadence] 找到直接步頻數據: \(directCadence.count) 筆")
                return directCadence
            }
        } catch {
            print("⚠️ [Cadence] 無法獲取直接步頻數據: \(error.localizedDescription)")
        }
        
        // 方法2: 通過步數計算步頻
        print("🔄 [Cadence] 嘗試通過步數計算步頻...")
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthError.notAvailable
        }
        
        let stepCounts = try await fetchQuantitySamples(
            sampleType: stepCountType,
            workout: workout,
            unit: HKUnit.count()
        )
        
        print("📊 [Cadence] 獲取到步數數據: \(stepCounts.count) 筆")
        
        // 如果步數數據不足，返回空數組
        if stepCounts.count < 3 {
            print("⚠️ [Cadence] 步數數據不足，無法計算步頻: \(stepCounts.count) < 3")
            return []
        }
        
        // 計算步頻
        return calculateCadence(stepCount: stepCounts)
    }
    
    // 嘗試直接獲取步頻數據 (從第三方設備或應用)
    private func fetchDirectCadenceData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        // 注意：iOS HealthKit 沒有標準的步頻數據類型
        // 但某些第三方應用可能會使用自定義的方式存儲步頻數據
        // 這裡我們檢查一些可能的數據來源
        
        // 檢查是否有其他可能的步頻數據類型
        // (目前 Apple HealthKit 沒有直接的步頻類型，所以這個方法會返回空數組)
        
        return []
    }

    // 輔助方法：計算步頻 (步/分鐘) - 先分析原始數據
    private func calculateCadence(stepCount: [(Date, Double)]) -> [(Date, Double)] {
        var cadenceData: [(Date, Double)] = []
        
        // 需要至少2個時間點來計算步頻
        if stepCount.count < 2 {
            print("⚠️ [Cadence] 步數數據不足，無法計算步頻: \(stepCount.count) < 2")
            return cadenceData
        }
        
        print("📊 [Cadence] ========== 開始分析原始步數數據 ==========")
        print("📊 [Cadence] 總數據點: \(stepCount.count)")
        
        // 按時間排序步數數據
        let sortedStepCount = stepCount.sorted { $0.0 < $1.0 }
        
        // 詳細分析前20個數據點
        print("📊 [Cadence] 前20個步數數據點詳細分析:")
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        for (index, point) in sortedStepCount.prefix(20).enumerated() {
            let timeStr = formatter.string(from: point.0)
            print("  [\(String(format: "%2d", index))] 時間: \(timeStr), 步數: \(String(format: "%8.1f", point.1))")
            
            if index > 0 {
                let prevPoint = sortedStepCount[index-1]
                let timeDiff = point.0.timeIntervalSince(prevPoint.0)
                let stepDiff = point.1 - prevPoint.1
                print("       -> 時間差: \(String(format: "%6.1f", timeDiff))秒, 步數差: \(String(format: "%6.1f", stepDiff))")
            }
        }
        
        // 分析數據的整體特性
        let firstPoint = sortedStepCount.first!
        let lastPoint = sortedStepCount.last!
        let totalTime = lastPoint.0.timeIntervalSince(firstPoint.0)
        
        let allSteps = sortedStepCount.map { $0.1 }
        let minSteps = allSteps.min() ?? 0
        let maxSteps = allSteps.max() ?? 0
        let totalSteps = maxSteps - minSteps
        
        print("📊 [Cadence] ========== 整體數據分析 ==========")
        print("📊 [Cadence] 運動開始時間: \(formatter.string(from: firstPoint.0))")
        print("📊 [Cadence] 運動結束時間: \(formatter.string(from: lastPoint.0))")
        print("📊 [Cadence] 總運動時間: \(String(format: "%.1f", totalTime))秒 (\(String(format: "%.1f", totalTime/60))分鐘)")
        print("📊 [Cadence] 步數最小值: \(String(format: "%.1f", minSteps))")
        print("📊 [Cadence] 步數最大值: \(String(format: "%.1f", maxSteps))")
        print("📊 [Cadence] 總步數變化: \(String(format: "%.1f", totalSteps))")
        
        // 分析步數變化模式
        var positiveChanges = 0
        var negativeChanges = 0
        var zeroChanges = 0
        var maxPositiveChange = 0.0
        var maxNegativeChange = 0.0
        
        for i in 1..<sortedStepCount.count {
            let stepDiff = sortedStepCount[i].1 - sortedStepCount[i-1].1
            if stepDiff > 0 {
                positiveChanges += 1
                maxPositiveChange = max(maxPositiveChange, stepDiff)
            } else if stepDiff < 0 {
                negativeChanges += 1
                maxNegativeChange = min(maxNegativeChange, stepDiff)
            } else {
                zeroChanges += 1
            }
        }
        
        print("📊 [Cadence] ========== 步數變化模式分析 ==========")
        print("📊 [Cadence] 步數增加的時間點: \(positiveChanges) 次")
        print("📊 [Cadence] 步數減少的時間點: \(negativeChanges) 次") 
        print("📊 [Cadence] 步數不變的時間點: \(zeroChanges) 次")
        print("📊 [Cadence] 最大單次步數增加: \(String(format: "%.1f", maxPositiveChange))")
        print("📊 [Cadence] 最大單次步數減少: \(String(format: "%.1f", maxNegativeChange))")
        
        // 分析時間間隔模式
        var timeIntervals: [Double] = []
        for i in 1..<sortedStepCount.count {
            let timeDiff = sortedStepCount[i].0.timeIntervalSince(sortedStepCount[i-1].0)
            timeIntervals.append(timeDiff)
        }
        
        let minInterval = timeIntervals.min() ?? 0
        let maxInterval = timeIntervals.max() ?? 0
        let avgInterval = timeIntervals.reduce(0, +) / Double(timeIntervals.count)
        
        print("📊 [Cadence] ========== 時間間隔分析 ==========")
        print("📊 [Cadence] 最小時間間隔: \(String(format: "%.1f", minInterval))秒")
        print("📊 [Cadence] 最大時間間隔: \(String(format: "%.1f", maxInterval))秒")
        print("📊 [Cadence] 平均時間間隔: \(String(format: "%.1f", avgInterval))秒")
        
        // 基於瞬時步數數據計算步頻
        print("📊 [Cadence] ========== 瞬時步數分析 ==========")
        print("📊 [Cadence] 發現：這是瞬時步數數據，不是累積值")
        print("📊 [Cadence] 採樣間隔: 2.6秒，數值範圍: 5-10步")
        
        // 使用滑動窗口計算平滑的步頻數據
        // 改為生成時間序列數據而不是單一平均值
        print("📊 [Cadence] 開始計算平滑化步頻 (30秒滑動窗口)...")
        
        let windowDuration: TimeInterval = 30.0 // 30秒滑動窗口
        let stepInterval: TimeInterval = 15.0   // 每15秒輸出一個數據點
        
        // 計算運動的總時長和需要輸出的時間點
        let startTime = firstPoint.0
        let endTime = lastPoint.0
        let totalDuration = endTime.timeIntervalSince(startTime)
        
        print("📊 [Cadence] 滑動窗口參數: 窗口大小=\(windowDuration)秒, 輸出間隔=\(stepInterval)秒")
        print("📊 [Cadence] 運動總時長: \(String(format: "%.1f", totalDuration))秒")
        
        // 生成時間點序列 (從運動開始後15秒開始，每15秒一個點)
        var currentTime = startTime.addingTimeInterval(windowDuration / 2) // 從第一個窗口中心開始
        var timePointIndex = 0
        
        while currentTime <= endTime.addingTimeInterval(-windowDuration / 2) {
            // 計算當前時間點的30秒窗口範圍
            let windowStart = currentTime.addingTimeInterval(-windowDuration / 2)
            let windowEnd = currentTime.addingTimeInterval(windowDuration / 2)
            
            // 找出窗口內的所有步數數據點
            let windowSteps = sortedStepCount.filter { point in
                point.0 >= windowStart && point.0 <= windowEnd
            }
            
            if !windowSteps.isEmpty {
                // 計算窗口內的總步數和時間跨度
                let totalSteps = windowSteps.reduce(0.0) { sum, point in sum + point.1 }
                let actualWindowDuration = min(windowDuration, windowEnd.timeIntervalSince(windowStart))
                
                // 計算該窗口的平均步頻 (步/分鐘)
                let averageCadence = (totalSteps / actualWindowDuration) * 60.0
                
                // 過濾合理的步頻範圍
                if averageCadence >= 100 && averageCadence <= 250 {
                    cadenceData.append((currentTime, averageCadence))
                    
                    if timePointIndex < 10 { // 顯示前10個點的詳細信息
                        let timeStr = formatter.string(from: currentTime)
                        print("  [\(String(format: "%2d", timePointIndex))] 時間: \(timeStr), 窗口步數: \(String(format: "%6.1f", totalSteps)), 步頻: \(String(format: "%6.1f", averageCadence)) spm")
                    }
                } else if timePointIndex < 10 {
                    let timeStr = formatter.string(from: currentTime)
                    print("  [\(String(format: "%2d", timePointIndex))] 時間: \(timeStr), 窗口步數: \(String(format: "%6.1f", totalSteps)), 步頻: \(String(format: "%6.1f", averageCadence)) spm (異常值，已過濾)")
                }
            }
            
            // 移動到下一個時間點
            currentTime = currentTime.addingTimeInterval(stepInterval)
            timePointIndex += 1
        }
        
        // 如果沒有有效數據，嘗試更寬鬆的範圍和更小的窗口
        if cadenceData.isEmpty {
            print("⚠️ [Cadence] 30秒窗口沒有找到有效步頻，嘗試15秒窗口和放寬範圍...")
            
            let smallerWindow: TimeInterval = 15.0
            currentTime = startTime.addingTimeInterval(smallerWindow / 2)
            timePointIndex = 0
            
            while currentTime <= endTime.addingTimeInterval(-smallerWindow / 2) {
                let windowStart = currentTime.addingTimeInterval(-smallerWindow / 2)
                let windowEnd = currentTime.addingTimeInterval(smallerWindow / 2)
                
                let windowSteps = sortedStepCount.filter { point in
                    point.0 >= windowStart && point.0 <= windowEnd
                }
                
                if !windowSteps.isEmpty {
                    let totalSteps = windowSteps.reduce(0.0) { sum, point in sum + point.1 }
                    let actualWindowDuration = min(smallerWindow, windowEnd.timeIntervalSince(windowStart))
                    let averageCadence = (totalSteps / actualWindowDuration) * 60.0
                    
                    // 使用更寬鬆的範圍 (50-400 spm)
                    if averageCadence >= 50 && averageCadence <= 400 {
                        cadenceData.append((currentTime, averageCadence))
                        
                        if timePointIndex < 10 {
                            let timeStr = formatter.string(from: currentTime)
                            print("  [\(String(format: "%2d", timePointIndex))] 時間: \(timeStr), 窗口步數: \(String(format: "%6.1f", totalSteps)), 步頻: \(String(format: "%6.1f", averageCadence)) spm (15秒窗口)")
                        }
                    }
                }
                
                currentTime = currentTime.addingTimeInterval(stepInterval)
                timePointIndex += 1
            }
        }
        
        // 統計結果
        if !cadenceData.isEmpty {
            let cadenceValues = cadenceData.map { $0.1 }
            let averageCadence = cadenceValues.reduce(0, +) / Double(cadenceValues.count)
            let minCadence = cadenceValues.min()!
            let maxCadence = cadenceValues.max()!
            
            print("📊 [Cadence] ========== 計算結果統計 ==========")
            print("📊 [Cadence] 有效步頻數據點: \(cadenceData.count)")
            print("📊 [Cadence] 平均步頻: \(String(format: "%.1f", averageCadence)) spm")
            print("📊 [Cadence] 步頻範圍: \(String(format: "%.1f", minCadence)) - \(String(format: "%.1f", maxCadence)) spm")
            print("✅ [Cadence] 成功生成 \(cadenceData.count) 個時間序列步頻數據點")
        } else {
            print("⚠️ [Cadence] 沒有找到任何有效的步頻數據")
        }
        
        print("📊 [Cadence] ========== 分析完成 ==========")
        print("✅ [Cadence] 最終有效數據點: \(cadenceData.count)")
        
        return cadenceData
    }
    
    // 輔助方法：找到最接近特定日期的數據點
    private func findClosestDataPoint(_ dataPoints: [(Date, Double)], to targetDate: Date) -> (Date, Double)? {
        guard !dataPoints.isEmpty else { return nil }
        
        var closestPoint: (Date, Double)? = nil
        var minTimeDifference = Double.greatestFiniteMagnitude
        
        for point in dataPoints {
            let timeDifference = abs(point.0.timeIntervalSince(targetDate))
            if timeDifference < minTimeDifference {
                minTimeDifference = timeDifference
                closestPoint = point
            }
        }
        
        return closestPoint
    }
    
    // 通用方法：獲取數量樣本數據
    private func fetchQuantitySamples(
        sampleType: HKQuantityType,
        workout: HKWorkout,
        unit: HKUnit,
        forceRefresh: Bool = false,
        retryAttempt: Int = 0
    ) async throws -> [(Date, Double)] {
        // 使用 TaskManageable 確保不會有重複的查詢
        // 如果是強制刷新或重試，使用包含時間戳和重試次數的唯一TaskID
        let taskId: TaskID
        if forceRefresh || retryAttempt > 0 {
            let timestamp = Int(Date().timeIntervalSince1970)
            taskId = TaskID("fetch_\(sampleType.identifier)_\(workout.uuid.uuidString)_retry_\(retryAttempt)_\(timestamp)")
            print("🔄 [HealthKit] 強制刷新/重試獲取 \(sampleType.identifier) 數據，重試: \(retryAttempt)")
        } else {
            taskId = TaskID("fetch_\(sampleType.identifier)_\(workout.uuid.uuidString)")
        }
        
        let result = await executeTask(id: taskId) { [weak self] in
            guard let self = self else { return [(Date, Double)]() }
            
            print("🔍 [TaskRegistry] 開始執行任務 - 數據類型: \(sampleType.identifier)")
            
            return try await withCheckedThrowingContinuation { continuation in
                self.healthKitQueue.async {
                    let predicate = HKQuery.predicateForSamples(
                        withStart: workout.startDate,
                        end: workout.endDate,
                        options: .strictEndDate
                    )
                    
                    let query = HKSampleQuery(
                        sampleType: sampleType,
                        predicate: predicate,
                        limit: HKObjectQueryNoLimit,
                        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                    ) { _, samples, error in
                        if let error = error {
                            print("獲取數據時出錯 (\(sampleType.identifier)): \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        guard let quantitySamples = samples as? [HKQuantitySample] else {
                            continuation.resume(returning: [])
                            return
                        }
                        
                        let dataPoints = quantitySamples.map { sample -> (Date, Double) in
                            let value = sample.quantity.doubleValue(for: unit)
                            return (sample.startDate, value)
                        }
                        
                        print("🔍 [TaskRegistry] 任務完成 - 獲得數據點: \(dataPoints.count)")
                        
                        continuation.resume(returning: dataPoints)
                    }
                    
                    self.healthStore.execute(query)
                }
            }
        }
        
        if let result = result {
            print("✅ [TaskRegistry] fetchQuantitySamples任務成功返回結果 - 數據點: \(result.count)")
            return result
        } else {
            print("❌ [TaskRegistry] fetchQuantitySamples任務返回nil - 可能被TaskRegistry取消或阻擋")
            return []
        }
    }
    
    // MARK: - 心率數據

    func fetchHeartRateData(for workout: HKWorkout, forceRefresh: Bool = false, retryAttempt: Int = 0) async throws -> [(Date, Double)] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.notAvailable
        }
        
        let result = try await fetchQuantitySamples(
            sampleType: heartRateType,
            workout: workout,
            unit: HKUnit(from: "count/min"),
            forceRefresh: forceRefresh,
            retryAttempt: retryAttempt
        )
        
        // 記錄心率數據獲取狀態
        let workoutStart = workout.startDate.formatted(date: .abbreviated, time: .shortened)
        print("❤️ [HealthKit] 心率數據獲取完成 - 運動時間: \(workoutStart), 數據點: \(result.count), 重試次數: \(retryAttempt), 強制刷新: \(forceRefresh)")
        
        if result.count < 2 {
            print("⚠️ [HealthKit] 心率數據不足 - 運動: \(workout.uuid.uuidString.prefix(8))..., 獲得: \(result.count) 筆，需要至少: 2 筆")
        }
        
        return result
    }
    
    func fetchSleepHeartRateAverage(for date: Date) async throws -> Double? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZoneManager.shared.getCurrentTimeZone()
        let startOfDay = calendar.startOfDay(for: date)
        let endTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: startOfDay)!
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.notAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endTime, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let heartRates = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Double], Error>) in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let rates = samples?.compactMap { sample -> Double? in
                    guard let heartRateSample = sample as? HKQuantitySample else { return nil }
                    return heartRateSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } ?? []
                
                continuation.resume(returning: rates)
            }
            
            healthStore.execute(query)
        }
        
        guard !heartRates.isEmpty else {
            print("未找到心率數據")
            return nil
        }
        
        return calculateStableSleepHeartRate(heartRates)
    }
    
    // MARK: - 運動數據
    
    func fetchWorkoutsForDateRange(start: Date, end: Date) async throws -> [HKWorkout] {
        // 使用 TaskManageable 確保不會有重複的查詢
        let taskId = TaskID("fetch_workouts_\(start.timeIntervalSince1970)_\(end.timeIntervalSince1970)")
        
        let result = await executeTask(id: taskId) { [weak self] in
            guard let self = self else { return [HKWorkout]() }
            
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                self.healthKitQueue.async {
                    let predicate = HKQuery.predicateForSamples(
                        withStart: start,
                        end: end,
                        options: .strictStartDate
                    )
                    
                    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                    let sampleType = HKObjectType.workoutType()
                    
                    let query = HKSampleQuery(
                        sampleType: sampleType,
                        predicate: predicate,
                        limit: HKObjectQueryNoLimit,
                        sortDescriptors: [sortDescriptor]
                    ) { _, samples, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        guard let samples = samples else {
                            continuation.resume(returning: [])
                            return
                        }
                        
                        let workouts = samples.compactMap { $0 as? HKWorkout }
                        
                        continuation.resume(returning: workouts)
                    }
                    
                    self.healthStore.execute(query)
                }
            }
        }
        
        return result ?? []
    }
    
    func fetchWorkouts(completion: @escaping ([HKWorkout]) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: now)!
        
        Task {
            do {
                let workouts = try await fetchWorkoutsForDateRange(start: startDate, end: now)
                DispatchQueue.main.async {
                    completion(workouts)
                }
            } catch {
                print("Error fetching workouts: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    func fetchHRVData(start: Date, end: Date) async throws -> [(Date, Double)] {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthError.notAvailable
        }
        
        // Diagnostic: print HRV authorization status
        let hrvAuth = healthStore.authorizationStatus(for: hrvType)
        print(" HRV authorization status: \(hrvAuth.rawValue)")

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Diagnostic: print raw HRV samples count and sources
                let rawSamples = samples as? [HKQuantitySample] ?? []
                let sources = Set(rawSamples.map { $0.sourceRevision.source.name })
                print(" HRV raw samples count: \(rawSamples.count), sources: \(sources)")

                let hrvValues = samples?.compactMap { sample -> (Date, Double)? in
                    guard let hrvSample = sample as? HKQuantitySample else { return nil }
                    return (hrvSample.startDate, hrvSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                } ?? []
                
                continuation.resume(returning: hrvValues)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - 心率數據
    
    private func fetchSleepTimes(start: Date, end: Date) async throws -> [(Date, Date)] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.notAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sleepPeriods = samples?.compactMap { sample -> (Date, Date)? in
                    guard let categorySample = sample as? HKCategorySample,
                          categorySample.categoryType.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
                          categorySample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    else { return nil }
                    return (categorySample.startDate, categorySample.endDate)
                } ?? []
                
                continuation.resume(returning: sleepPeriods)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRates(start: Date, end: Date) async throws -> [Double] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.notAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let heartRates = samples?.compactMap { sample -> Double? in
                    guard let heartRateSample = sample as? HKQuantitySample else { return nil }
                    return heartRateSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } ?? []
                
                continuation.resume(returning: heartRates)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchPaceData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        guard let runningSpeedType = HKObjectType.quantityType(forIdentifier: .runningSpeed) else {
            throw HealthError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictEndDate
            )
            
            let runningSpeedQuery = HKSampleQuery(
                sampleType: runningSpeedType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    print("獲取速度數據時出錯: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let runningSpeedSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let speeds = runningSpeedSamples.map { sample -> (Date, Double) in
                    let speed = sample.quantity.doubleValue(for: HKUnit.meter().unitDivided(by: HKUnit.second()))
                    return (sample.startDate, speed)
                }
                
                continuation.resume(returning: speeds)
            }
            
            healthStore.execute(runningSpeedQuery)
        }
    }

    
    func fetchHeartRatesForWorkout(_ workout: HKWorkout) async throws -> [Double] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.notAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let heartRateSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(throwing: HealthError.dataNotAvailable)
                    return
                }
                
                let heartRates = heartRateSamples.map { sample in
                    sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                }
                
                continuation.resume(returning: heartRates)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func calculateStableSleepHeartRate(_ rates: [Double]) -> Double {
        guard !rates.isEmpty else { return 0 }
        
        let sortedRates = rates.sorted()
        let q1Index = Int(Double(sortedRates.count) * 0.25)
        let q3Index = Int(Double(sortedRates.count) * 0.75)
        
        let q1 = sortedRates[q1Index]
        let q3 = sortedRates[q3Index]
        let iqr = q3 - q1
        
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr
        
        // 過濾離群值並計算平均值
        let stableHeartRates = sortedRates.filter { $0 >= lowerBound && $0 <= upperBound }
        return stableHeartRates.reduce(0.0, +) / Double(stableHeartRates.count)
    }
    
    func fetchMaxHeartRate() async -> Double {
        // 從 UserPreferenceManager 獲取用戶年齡
        let age = UserPreferenceManager.shared.age ?? 30
        // 使用 220 - age 公式計算最大心率
        return Double(220 - age)
    }
    
    func fetchRestingHeartRate() async -> Double {
        guard let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return 60.0 // 默認值
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: predicate,
                limit: 1, // 只需要最新的一個值
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("獲取靜息心率時出錯: \(error.localizedDescription)")
                    continuation.resume(returning: 60.0)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    let restingHR = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: restingHR)
                } else {
                    continuation.resume(returning: 60.0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Heart Rate Zone
    
    struct HeartRateZone: Identifiable {
        let id: Int
        let zone: Int
        let range: ClosedRange<Double>
        let description: String
        let benefit: String
        
        static func calculateZones(maxHR: Double) -> [HeartRateZone] {
            return [
                HeartRateZone(
                    id: 1,
                    zone: 1,
                    range: (maxHR * 0.5)...(maxHR * 0.6),
                    description: "非常放鬆的配速，有助於運動前的熱身與體能恢復的區間。",
                    benefit: "初級心肺訓練。幫助熱身、放鬆。"
                ),
                HeartRateZone(
                    id: 2,
                    zone: 2,
                    range: (maxHR * 0.6)...(maxHR * 0.7),
                    description: "舒服且可以聊天的配速，也是燃脂比例最高的心率區間。",
                    benefit: "基礎心肺訓練。提升恢復能力、促進新陳代謝，以及協助恢複。"
                ),
                HeartRateZone(
                    id: 3,
                    zone: 3,
                    range: (maxHR * 0.7)...(maxHR * 0.8),
                    description: "有助於體能基礎訓練的最佳訓練配速。",
                    benefit: "提高有氧能力，優化心血管的訓練。"
                ),
                HeartRateZone(
                    id: 4,
                    zone: 4,
                    range: (maxHR * 0.8)...(maxHR * 0.9),
                    description: "跑馬拉松的建議心率，建議跑全馬時不要超過這個區間的上限。",
                    benefit: "改善無氧能力及乳酸閾值，提高速度。"
                ),
                HeartRateZone(
                    id: 5,
                    zone: 5,
                    range: (maxHR * 0.9)...(maxHR),
                    description: "此區間是以無氧代謝為主要的能量來源，因此無法長時間維持，但可以訓練耐乳酸能力與最大攝氧量。",
                    benefit: "提升無氧能力與肌耐力，增加功率。"
                )
            ]
        }
    }
    
    // MARK: - HealthKit Manager Extension
    
    func getHeartRateZones() async -> [HeartRateZone] {
        let maxHR = await fetchMaxHeartRate()
        return HeartRateZone.calculateZones(maxHR: maxHR)
    }
    
    func calculateZoneDistribution(heartRates: [(Date, Double)]) async -> [Int: TimeInterval] {
        let zones = await getHeartRateZones()
        var distribution: [Int: TimeInterval] = [:]
        
        // 初始化所有區間的時間為 0
        for zone in zones {
            distribution[zone.zone] = 0
        }
        
        // 如果只有一個心率數據點，返回空的分佈
        guard heartRates.count > 1 else { return distribution }
        
        // 計算每個心率點所屬的區間和持續時間
        for i in 0..<(heartRates.count - 1) {
            let currentHR = heartRates[i].1
            let duration = heartRates[i + 1].0.timeIntervalSince(heartRates[i].0)
            
            // 找到對應的心率區間
            if let zone = zones.first(where: { $0.range.contains(currentHR) }) {
                distribution[zone.zone, default: 0] += duration
            }
        }
        
        return distribution
    }
    
    func getZoneForHeartRate(_ heartRate: Double) async -> Int? {
        let zones = await getHeartRateZones()
        return zones.first(where: { $0.range.contains(heartRate) })?.zone
    }
    
    // MARK: - Weekly Heart Rate Analysis
    
    struct WeeklyHeartRateAnalysis {
        var zoneDistribution: [Int: TimeInterval]
        var moderateActivityTime: TimeInterval  // 第1-2區
        var vigorousActivityTime: TimeInterval  // 第3-5區
        
        var totalActivityTime: TimeInterval {
            moderateActivityTime + vigorousActivityTime
        }
    }
    
    func fetchWeeklyHeartRateAnalysis() async throws -> WeeklyHeartRateAnalysis {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: endDate))!
        
        // 獲取這段時間內的所有運動
        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
            
            let query = HKSampleQuery(sampleType: .workoutType(),
                                    predicate: predicate,
                                    limit: HKObjectQueryNoLimit,
                                    sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
        
        var totalZoneDistribution: [Int: TimeInterval] = [:]
        var moderateTime: TimeInterval = 0
        var vigorousTime: TimeInterval = 0
        
        // 獲取每個運動的心率區間分佈
        for workout in workouts {
            let heartRateData = try await fetchHeartRateData(for: workout)
            let distribution = await calculateZoneDistribution(heartRates: heartRateData)
            
            // 累加各區間時間
            for (zone, duration) in distribution {
                totalZoneDistribution[zone, default: 0] += duration
                
                // 計算中等強度和高強度時間
                if zone > 1 && zone <= 3 {
                    moderateTime += duration
                } else if zone > 3 {
                    vigorousTime += duration
                }
            }
        }
        
        return WeeklyHeartRateAnalysis(
            zoneDistribution: totalZoneDistribution,
            moderateActivityTime: moderateTime,
            vigorousActivityTime: vigorousTime
        )
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return String(format: "%d小時%d分鐘", hours, minutes)
        } else {
            return String(format: "%d分鐘", minutes)
        }
    }
    
    /// 獲取用戶的心率區間（使用心率儲備方法，從UserPreferences獲取）
        func getHRRHeartRateZones() async -> [HeartRateZone] {
            // 確保心率區間已計算並儲存
            await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
            
            // 從 HeartRateZonesManager 獲取區間
            let hrZones = HeartRateZonesManager.shared.getHeartRateZones()
            
            // 轉換為 HealthKitManager.HeartRateZone
            return HeartRateZonesBridge.shared.convertToHealthKitManagerZones(hrZones)
        }
        
        /// 計算特定時間範圍內的心率區間分佈（使用心率儲備方法）
        func calculateHRRZoneDistribution(heartRates: [(Date, Double)]) async -> [Int: TimeInterval] {
            // 確保心率區間已計算並儲存
            await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
            
            let hrZones = HeartRateZonesManager.shared.getHeartRateZones()
            var distribution: [Int: TimeInterval] = [:]
            
            // 初始化所有區間的時間為0
            for zone in hrZones {
                distribution[zone.zone] = 0
            }
            
            // 如果沒有心率數據則返回空分佈
            guard heartRates.count > 1 else {
                return distribution
            }
            
            // 排序心率數據（按時間）
            let sortedHeartRates = heartRates.sorted { $0.0 < $1.0 }
            
            // 計算各區間的時間分佈
            for i in 0..<(sortedHeartRates.count - 1) {
                let currentPoint = sortedHeartRates[i]
                let nextPoint = sortedHeartRates[i + 1]
                
                let heartRate = currentPoint.1
                let timeInterval = nextPoint.0.timeIntervalSince(currentPoint.0)
                
                // 獲取該心率所屬的區間
                let zone = HeartRateZonesManager.shared.getZoneForHeartRate(heartRate)
                
                // 累加該區間的時間
                distribution[zone] = (distribution[zone] ?? 0) + timeInterval
            }
            
            return distribution
        }
        
        /// 獲取週心率區間分析（使用心率儲備方法）
        func fetchHRRWeeklyHeartRateAnalysis() async throws -> WeeklyHeartRateAnalysis {
            // 確保心率區間已計算並儲存
            await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
            
            let calendar = Calendar.current
            let now = Date()
            let startDate = calendar.date(byAdding: .day, value: -7, to: now)!
            
            // 獲取過去一週的跑步鍛煉
            let workouts = try await fetchWorkoutsForDateRange(start: startDate, end: now)
            
            var combinedDistribution: [Int: TimeInterval] = [:]
            var totalModerateTime: TimeInterval = 0
            var totalVigorousTime: TimeInterval = 0
            
            // 處理每個鍛煉的心率數據
            for workout in workouts {
                // 獲取心率數據
                let heartRates = try await fetchHeartRateData(for: workout)
                if heartRates.isEmpty { continue }
                
                // 計算區間分佈（使用心率儲備方法）
                let distribution = await calculateHRRZoneDistribution(heartRates: heartRates)
                
                // 合併到總計中
                for (zone, time) in distribution {
                    combinedDistribution[zone] = (combinedDistribution[zone] ?? 0) + time
                    
                    // 計算中等和高強度運動時間
                    if zone <= 2 {
                        totalModerateTime += time
                    } else {
                        totalVigorousTime += time
                    }
                }
            }
            
            return WeeklyHeartRateAnalysis(
                zoneDistribution: combinedDistribution,
                moderateActivityTime: totalModerateTime,
                vigorousActivityTime: totalVigorousTime
            )
        }
    
    // MARK: - HRV 診斷
    /// Diagnostic: get HRV authorization status, raw sample count, and sources
    func fetchHRVDiagnostics(start: Date, end: Date) async throws -> (authStatus: HKAuthorizationStatus, rawSampleCount: Int, sources: [String]) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthError.notAvailable
        }
        // 授權狀態
        let authStatus = healthStore.authorizationStatus(for: hrvType)
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let rawSamples = samples as? [HKQuantitySample] ?? []
                let sources = Array(Set(rawSamples.map { $0.sourceRevision.source.name }))
                continuation.resume(returning: (authStatus, rawSamples.count, sources))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - HRV 讀取權限檢查
    /// 檢查 HRV (SDNN) 讀取授權狀態，回傳 HKAuthorizationRequestStatus
    func checkHRVReadAuthorization() async throws -> HKAuthorizationRequestStatus {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthError.notAvailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: [hrvType]) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    // MARK: - 分圈數據

    /// 提取 workout 的分圈資料
    func fetchLapData(for workout: HKWorkout) async throws -> [LapData] {
        let taskId = TaskID("fetch_lap_data_\(workout.uuid.uuidString)")

        let result = await executeTask(id: taskId) { [weak self] in
            guard let self = self else { return [LapData]() }

            print("🏃‍♂️ [LapData] 開始提取分圈資料 - Workout: \(workout.uuid.uuidString.prefix(8))...")

            // 提取 workout events
            let workoutEvents = workout.workoutEvents ?? []
            print("🏃‍♂️ [LapData] 發現 \(workoutEvents.count) 個 workout events")

            // 先列出所有事件類型，幫助調試
            print("🔍 [LapData] 所有事件類型詳情：")
            for (index, event) in workoutEvents.enumerated() {
                let typeName: String
                switch event.type {
                case .lap: typeName = "lap"
                case .segment: typeName = "segment"
                case .pause: typeName = "pause"
                case .resume: typeName = "resume"
                case .motionPaused: typeName = "motionPaused"
                case .motionResumed: typeName = "motionResumed"
                case .marker: typeName = "marker"
                case .pauseOrResumeRequest: typeName = "pauseOrResumeRequest"
                @unknown default: typeName = "unknown(\(event.type.rawValue))"
                }
                print("   [\(index+1)] 類型: \(typeName), 持續: \(String(format: "%.0f", event.dateInterval.duration))秒")
            }

            // 篩選分圈相關的事件（.lap、.marker、.segment）
            let lapEvents = workoutEvents.filter { event in
                return event.type == .lap || event.type == .marker || event.type == .segment
            }

            let lapCount = workoutEvents.filter { $0.type == .lap }.count
            let markerCount = workoutEvents.filter { $0.type == .marker }.count
            let segmentCount = workoutEvents.filter { $0.type == .segment }.count

            print("🏃‍♂️ [LapData] 篩選出 \(lapEvents.count) 個分圈事件 (lap: \(lapCount), marker: \(markerCount), segment: \(segmentCount))")

            if lapEvents.isEmpty {
                print("🏃‍♂️ [LapData] 此運動沒有分圈資料")
                return []
            }

            // 按時間排序
            let sortedEvents = lapEvents.sorted { $0.dateInterval.start < $1.dateInterval.start }

            var laps: [LapData] = []

            // 累積計算每圈的開始時間偏移
            var cumulativeOffset: TimeInterval = 0
            print("🔍 [LapData] 開始計算累積偏移 - 初始值: \(cumulativeOffset)秒")

            for (index, event) in sortedEvents.enumerated() {
                let lapNumber = index + 1

                // 使用累積偏移作為該圈的開始時間
                let startTimeOffset = cumulativeOffset
                let duration = event.dateInterval.duration

                print("🔍 [LapData] 第 \(lapNumber) 圈 BEFORE - 累積偏移: \(String(format: "%.0f", cumulativeOffset))秒, 本圈時長: \(String(format: "%.0f", duration))秒")

                // 更新累積偏移，為下一圈做準備
                cumulativeOffset += duration

                print("🔍 [LapData] 第 \(lapNumber) 圈 AFTER  - 累積偏移: \(String(format: "%.0f", cumulativeOffset))秒")

                // 嘗試從 metadata 獲取距離資訊
                var distance: Double? = nil
                var metadata: [String: String]? = nil

                if let eventMetadata = event.metadata {
                    var metadataDict: [String: String] = [:]

                    // 提取距離資訊
                    if let distanceQuantity = eventMetadata[HKMetadataKeyLapLength] as? HKQuantity {
                        distance = distanceQuantity.doubleValue(for: .meter())
                        metadataDict["lap_length"] = String(distance!)
                    }

                    // 提取其他可能的 metadata
                    for (key, value) in eventMetadata {
                        if let stringValue = value as? String {
                            metadataDict[key] = stringValue
                        } else if let numberValue = value as? NSNumber {
                            metadataDict[key] = numberValue.stringValue
                        }
                    }

                    if !metadataDict.isEmpty {
                        metadata = metadataDict
                    }
                }

                // 計算平均配速（如果有距離）
                var averagePace: Double? = nil
                if let lapDistance = distance, lapDistance > 0 {
                    // 配速 = 時間（秒）/ 距離（公里）
                    averagePace = duration / (lapDistance / 1000.0)
                }

                // 確定分圈類型
                let lapType: String
                switch event.type {
                case .lap:
                    lapType = "lap"         // 等距離圈數標記
                case .marker:
                    lapType = "marker"      // 興趣點標記
                case .segment:
                    lapType = "segment"     // 運動分段
                default:
                    lapType = "unknown"     // 未知類型
                }

                // 獲取該分圈時間範圍內的平均心率
                let averageHeartRate = await self.calculateAverageHeartRate(
                    for: workout,
                    startTime: event.dateInterval.start,
                    endTime: event.dateInterval.end
                )

                // 使用 LapData.fromAppleHealth 創建統一格式的分圈數據
                let lapData = LapData.fromAppleHealth(
                    lapNumber: lapNumber,
                    startTimeOffset: startTimeOffset,  // 使用相對偏移而非絕對時間
                    duration: duration,
                    distance: distance,
                    averagePace: averagePace,
                    averageHeartRate: averageHeartRate,
                    type: lapType,
                    metadata: metadata
                )

                laps.append(lapData)

                print("🏃‍♂️ [LapData] 第 \(lapNumber) 圈 - 偏移: \(String(format: "%.0f", startTimeOffset))秒, 持續: \(String(format: "%.0f", duration))秒, 距離: \(distance?.description ?? "N/A")米, 配速: \(averagePace?.description ?? "N/A")秒/公里, 心率: \(averageHeartRate?.description ?? "N/A")bpm")
            }

            print("✅ [LapData] 成功提取 \(laps.count) 圈資料")
            return laps
        }

        return result ?? []
    }

    /// 計算指定時間範圍內的平均心率
    private func calculateAverageHeartRate(for workout: HKWorkout, startTime: Date, endTime: Date) async -> Double? {
        do {
            // 獲取該時間範圍內的心率數據
            let heartRateData = try await fetchHeartRateDataInRange(
                for: workout,
                startTime: startTime,
                endTime: endTime
            )

            if heartRateData.isEmpty {
                return nil
            }

            let totalHeartRate = heartRateData.reduce(0.0) { $0 + $1.1 }
            let averageHeartRate = totalHeartRate / Double(heartRateData.count)

            return averageHeartRate
        } catch {
            print("⚠️ [LapData] 無法計算平均心率: \(error.localizedDescription)")
            return nil
        }
    }

    /// 獲取指定時間範圍內的心率數據
    private func fetchHeartRateDataInRange(for workout: HKWorkout, startTime: Date, endTime: Date) async throws -> [(Date, Double)] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthKitQueue.async {
                let predicate = HKQuery.predicateForSamples(
                    withStart: startTime,
                    end: endTime,
                    options: .strictEndDate
                )

                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let quantitySamples = samples as? [HKQuantitySample] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let dataPoints = quantitySamples.map { sample -> (Date, Double) in
                        let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                        return (sample.startDate, value)
                    }

                    continuation.resume(returning: dataPoints)
                }

                self.healthStore.execute(query)
            }
        }
    }

    // MARK: - 卡路里數據
    
    func fetchCaloriesData(for workout: HKWorkout) async throws -> Double {
        // 直接從workout獲取總卡路里
        let totalCalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        return totalCalories
    }
    
    func fetchCaloriesDataPoints(for workout: HKWorkout) async throws -> [(Date, Double)] {
        guard let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthError.notAvailable
        }
        
        return try await fetchQuantitySamples(
            sampleType: caloriesType,
            workout: workout,
            unit: HKUnit.kilocalorie()
        )
    }
}

// MARK: - 錯誤定義

extension HealthKitManager {
    enum HealthError: Error {
        case notAvailable
        case authorizationDenied
        case networkError
        case dataNotAvailable
    }
}
