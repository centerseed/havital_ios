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
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!
        ]
        
        // 定義需要寫入的數據類型
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
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
        // 默認最大心率計算公式：220 - 年齡
        // 這裡先返回一個默認值，後續可以根據實際情況調整
        return 180.0
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
