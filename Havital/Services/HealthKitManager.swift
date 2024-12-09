import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let workoutTypes: [HKWorkoutActivityType] = [
        .running,
        .walking,
        .cycling,
        .swimming
    ]
    
    private var userPreference: UserPreference? {
        guard let data = UserDefaults.standard.data(forKey: "userPreference") else {
            print("無法獲取用戶偏好設置數據")
            return nil
        }
        
        do {
            let preference = try JSONDecoder().decode(UserPreference.self, from: data)
            print("成功讀取用戶年齡: \(preference.age)")
            return preference
        } catch {
            print("解析用戶偏好設置失敗: \(error)")
            return nil
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit 不可用")
            completion(false)
            return
        }
        
        // 定義所有需要讀取的數據類型
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)! // 添加睡眠分析權限
        ]
        
        // 定義需要寫入的數據類型
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
        ]
        
        print("請求 HealthKit 授權，包括 HRV 和睡眠分析權限")
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit 授權錯誤: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // 檢查 HRV 授權狀態
            if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                let hrvStatus = self.healthStore.authorizationStatus(for: hrvType)
                print("HRV 授權狀態: \(hrvStatus.rawValue)")
            }
            
            // 檢查睡眠分析授權狀態
            if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                let sleepStatus = self.healthStore.authorizationStatus(for: sleepType)
                print("睡眠分析授權狀態: \(sleepStatus.rawValue)")
            }
            
            print("HealthKit 授權結果: \(success)")
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    func fetchWorkoutsForDateRange(start: Date, end: Date) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("獲取訓練記錄時出錯: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchWorkouts(completion: @escaping ([HKWorkout]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // 設定時間範圍為最近一個月
        let now = Date()
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: oneMonthAgo, end: now, options: .strictEndDate)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,  // 添加時間範圍限制
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { (query, samples, error) in
            DispatchQueue.main.async {
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    print("獲取訓練記錄失敗: \(error?.localizedDescription ?? "未知錯誤")")
                    completion([])
                    return
                }
                print("成功獲取最近一個月的訓練記錄: \(workouts.count) 條")
                completion(workouts)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchHeartRateData(for workout: HKWorkout) async -> [(Date, Double)] {
        await withCheckedContinuation { continuation in
            guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                continuation.resume(returning: [])
                return
            }
            
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    print("獲取心率數據時出錯: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                let heartRates = samples?.compactMap { sample -> (Date, Double)? in
                    guard let heartRateSample = sample as? HKQuantitySample else { return nil }
                    let heartRate = heartRateSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    return (heartRateSample.startDate, heartRate)
                } ?? []
                
                continuation.resume(returning: heartRates)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchHeartRateData(for workout: HKWorkout, completion: @escaping ([(Date, Double)]) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { (query, samples, error) in
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                completion([])
                return
            }
            
            let heartRates = samples.map { sample in
                (
                    sample.startDate,
                    sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                )
            }
            
            DispatchQueue.main.async {
                completion(heartRates)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchRestingHeartRate(completion: @escaping (Double?) -> Void) {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: restingHeartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            DispatchQueue.main.async {
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil)
                    return
                }
                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                completion(heartRate)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func checkHeartRateData(for workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,  // 只需要檢查是否有數據，所以限制為1
            sortDescriptors: nil
        ) { (query, samples, error) in
            let hasHeartRate = (samples?.count ?? 0) > 0
            DispatchQueue.main.async {
                completion(hasHeartRate)
            }
        }
        
        healthStore.execute(query)
    }
    
    func calculateMaxHeartRate() -> Double {
        let age = userPreference?.age ?? 30
        let maxHR = 220 - Double(age)
        print("使用者年齡: \(age)，計算最大心率: \(maxHR)")
        return maxHR
    }
    
    func fetchMaxHeartRate() async -> Double {
        return calculateMaxHeartRate()
    }
    
    func fetchRestingHeartRate() async -> Double {
        // 暫時返回固定值，之後可以從 HealthKit 獲取
        return 60.0
    }
    
    // 新增 HRV 數據獲取方法
    func fetchHRVData(start: Date, end: Date) async -> [(Date, Double)] {
        // 檢查授權狀態
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            print("無法獲取 HRV 類型")
            return []
        }
        
        let authStatus = healthStore.authorizationStatus(for: hrvType)
        print("HRV 授權狀態: \(authStatus.rawValue)")
        
        guard authStatus == .sharingAuthorized else {
            print("HRV 數據未獲得授權，當前狀態: \(authStatus.rawValue)")
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    print("獲取 HRV 數據時出錯: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                let hrvData = samples?.compactMap { sample -> (Date, Double)? in
                    guard let hrvSample = sample as? HKQuantitySample else { return nil }
                    let hrvValue = hrvSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    return (hrvSample.startDate, hrvValue)
                } ?? []
                
                print("成功獲取 \(hrvData.count) 條 HRV 數據")
                continuation.resume(returning: hrvData)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func calculateStableSleepHeartRate(_ heartRates: [Double]) -> Double? {
        guard heartRates.count >= 4 else {
            print("心率數據點不足")
            return nil
        }
        
        // 排序心率數據
        let sortedRates = heartRates.sorted()
        
        // 計算四分位數
        let q1Index = sortedRates.count / 4
        let q3Index = (sortedRates.count * 3) / 4
        
        let q1 = sortedRates[q1Index]
        let q3 = sortedRates[q3Index]
        
        // 計算四分位距（IQR）
        let iqr = q3 - q1
        
        // 設定異常值的範圍（通常使用 1.5 * IQR）
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr
        
        // 過濾掉異常值
        let stableHeartRates = sortedRates.filter { rate in
            rate >= lowerBound && rate <= upperBound
        }
        
        print("原始心率數據: \(heartRates.count) 個點")
        print("穩定心率數據: \(stableHeartRates.count) 個點")
        print("Q1: \(q1), Q3: \(q3), IQR: \(iqr)")
        print("過濾範圍: \(lowerBound) - \(upperBound)")
        
        // 計算穩定心率的平均值
        let averageStableRate = stableHeartRates.reduce(0.0, +) / Double(stableHeartRates.count)
        print("穩定睡眠心率平均值: \(averageStableRate)")
        
        return averageStableRate
    }
    
    func fetchSleepHeartRateAverage(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        
        // 設定當天凌晨00:00
        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = 0
        startComponents.minute = 0
        startComponents.second = 0
        guard let startDate = calendar.date(from: startComponents) else {
            print("無法創建開始時間")
            return nil
        }
        
        // 設定當天早上6:00
        var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
        endComponents.hour = 6
        endComponents.minute = 0
        endComponents.second = 0
        guard let endDate = calendar.date(from: endComponents) else {
            print("無法創建結束時間")
            return nil
        }
        
        print("獲取 \(date.formatted()) 的睡眠心率，時間範圍：\(startDate.formatted()) - \(endDate.formatted())")
        
        // 獲取心率數據
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let heartRatePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let heartRateSamples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: heartRatePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            
            healthStore.execute(query)
        }
        
        let heartRates = heartRateSamples.map { sample in
            sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        }
        
        print("在指定時間範圍內找到 \(heartRates.count) 個心率數據點")
        
        // 使用四分位數方法計算穩定心率
        return calculateStableSleepHeartRate(heartRates)
    }
    
    func requestSleepAuthorization() async throws {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let typesToRead: Set<HKObjectType> = [sleepType, heartRateType]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
}
