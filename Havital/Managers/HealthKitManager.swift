import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
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
            HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
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
    
    // MARK: - HRV 數據
    
    func fetchHRVData(start: Date, end: Date) async throws -> [(Date, Double)] {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthError.typeNotAvailable
        }
        
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
                
                let hrvValues = samples?.compactMap { sample -> (Date, Double)? in
                    guard let hrvSample = sample as? HKQuantitySample else { return nil }
                    return (hrvSample.startDate, hrvSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                } ?? []
                
                continuation.resume(returning: hrvValues)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - 運動數據
    
    func fetchWorkoutsForDateRange(start: Date, end: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let sampleType = HKObjectType.workoutType()
        
        return try await withCheckedThrowingContinuation { continuation in
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
                
                let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
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
    
    // MARK: - 心率數據
    
    func fetchSleepHeartRateAverage(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: startOfDay)!
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.typeNotAvailable
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
    
    private func fetchSleepTimes(start: Date, end: Date) async throws -> [(Date, Date)] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthError.typeNotAvailable
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
            throw HealthError.typeNotAvailable
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
            throw HealthError.typeNotAvailable
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

    func fetchHeartRateData(for workout: HKWorkout) async throws -> [(Date, Double)] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.typeNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictEndDate
            )
            
            let heartRateQuery = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    print("獲取心率數據時出錯: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let heartRateSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let heartRates = heartRateSamples.map { sample -> (Date, Double) in
                    let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    return (sample.startDate, heartRate)
                }
                
                continuation.resume(returning: heartRates)
            }
            
            healthStore.execute(heartRateQuery)
        }
    }
    
    func fetchHeartRatesForWorkout(_ workout: HKWorkout) async throws -> [Double] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthError.typeNotAvailable
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
                    continuation.resume(throwing: HealthError.noData)
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
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
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
                    if zone == 2 || zone == 3 {
                        totalModerateTime += time
                    } else if zone >= 4 {
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
}

// MARK: - 錯誤定義

extension HealthKitManager {
    enum HealthError: Error {
        case typeNotAvailable
        case noData
        case authorizationDenied
        case notAvailable
    }
}
