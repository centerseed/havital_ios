import Foundation
import Combine
import HealthKit

/// 訓練強度分鐘數結構 - 在 TrainingIntensityManager 命名空間中定義
extension TrainingIntensityManager {
    struct IntensityMinutes {
        let low: Double
        let medium: Double
        let high: Double
        
        static var zero: IntensityMinutes {
            return IntensityMinutes(low: 0, medium: 0, high: 0)
        }
    }
}

class TrainingIntensityManager {
    static let shared = TrainingIntensityManager()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - 訓練強度計算
    
    /// 計算指定時間範圍內的訓練強度
    func calculateIntensity(for workouts: [HKWorkout], maxHR: Double, restingHR: Double, healthKitManager: HealthKitManager) async -> TrainingIntensityManager.IntensityMinutes {
        var totalLowIntensity: Double = 0
        var totalMediumIntensity: Double = 0
        var totalHighIntensity: Double = 0
        
        print("開始計算訓練強度，獲取到 \(workouts.count) 個訓練")
        
        // 處理每個訓練
        for workout in workouts where workout.workoutActivityType == .running {
            let duration = workout.duration / 60 // 轉換為分鐘
            print("處理訓練: \(workout.startDate) 至 \(workout.endDate), 持續 \(duration) 分鐘")
            
            // 局部變數，用於儲存每個運動的強度分鐘數
            var workoutLowIntensity: Double = 0
            var workoutMediumIntensity: Double = 0
            var workoutHighIntensity: Double = 0
            
            do {
                // 使用與 WorkoutDetailView 相同的方式獲取心率數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                
                print("獲取到 \(heartRateData.count) 個心率數據點")
                
                // 計算心率統計信息，用於診斷
                if !heartRateData.isEmpty {
                    let heartRateValues = heartRateData.map { $0.1 }
                    let minHR = heartRateValues.min() ?? 0
                    let maxHRValue = heartRateValues.max() ?? 0
                    let avgHR = heartRateValues.reduce(0, +) / Double(heartRateValues.count)
                    print("心率統計: 最低=\(minHR), 最高=\(maxHRValue), 平均=\(avgHR)")
                }
                
                // 計算每個心率點所屬的強度區間
                if heartRateData.isEmpty {
                    print("沒有心率數據，使用運動時間估算強度")
                    // 如果沒有心率數據，將運動時間全部計入低強度
                    workoutLowIntensity += duration
                } else {
                    print("開始計算心率所屬強度區間")
                    var lowCount = 0, mediumCount = 0, highCount = 0
                    var totalLowMinutes: Double = 0.0, totalMediumMinutes: Double = 0.0, totalHighMinutes: Double = 0.0
                    
                    // 新增更多診斷日誌
                    print("開始心率分析 - 最大心率: \(maxHR), 靜息心率: \(restingHR)")
                    if let firstHR = heartRateData.first?.1, let lastHR = heartRateData.last?.1 {
                        print("第一個心率讀數: \(firstHR), 最後一個心率讀數: \(lastHR)")
                    }
                    
                    // 計算心率樣本點之間的時間間隔，估算更準確的強度分鐘數
                    // 如果只有一個樣本點，則使用運動持續時間
                    if heartRateData.count == 1 {
                        let hr = heartRateData[0].1
                        let hrr = (hr - restingHR) / (maxHR - restingHR) * 100
                        print("只有一個心率樣本點，心率=\(hr), HRR=\(hrr)%")
                        
                        if hrr < 72 {
                            totalLowMinutes += duration
                            lowCount += 1
                        } else if hrr <= 84 {
                            totalMediumMinutes += duration
                            mediumCount += 1
                        } else {
                            totalHighMinutes += duration
                            highCount += 1
                        }
                    } else {
                        // 多個心率樣本點，考慮點與點之間的時間差
                        // 重置計算用的強度分鐘數
                        totalLowMinutes = 0
                        totalMediumMinutes = 0
                        totalHighMinutes = 0
                        
                        for i in 0..<heartRateData.count {
                            let (time, hr) = heartRateData[i]
                            let hrr = (hr - restingHR) / (maxHR - restingHR) * 100
                            
                            // 打印診斷信息
                            if i % 30 == 0 || i < 5 {
                                print("心率樣本 \(i): 時間=\(time), 心率=\(hr)")
                                print("心率保留率(HRR): \(hrr)%")
                            }
                            
                            // 計算此樣本點代表的時間段，單位為分鐘
                            var minutesForThisPoint: Double = 0
                            
                            if i == 0 {
                                // 第一個樣本點，使用運動開始到此點的時間
                                let workoutStartTime = workout.startDate
                                minutesForThisPoint = time.timeIntervalSince(workoutStartTime) / 60.0
                            } else if i == heartRateData.count - 1 {
                                // 最後一個樣本點，使用此點到運動結束的時間
                                let workoutEndTime = workout.endDate
                                minutesForThisPoint = workoutEndTime.timeIntervalSince(time) / 60.0
                            } else {
                                // 中間樣本點，使用前後兩點之間差的一半
                                let prevTime = heartRateData[i-1].0
                                let nextTime = heartRateData[i+1].0
                                let totalInterval = nextTime.timeIntervalSince(prevTime) / 60.0
                                minutesForThisPoint = totalInterval / 2.0
                            }
                            
                            // 根據 HRR 分配時間到相應強度區間
                            if hrr < 72 {
                                totalLowMinutes += minutesForThisPoint
                                lowCount += 1
                            } else if hrr <= 84 {
                                totalMediumMinutes += minutesForThisPoint
                                mediumCount += 1
                            } else {
                                totalHighMinutes += minutesForThisPoint
                                highCount += 1
                            }
                        }
                        
                        // 更新強度分鐘數
                        workoutLowIntensity = totalLowMinutes
                        workoutMediumIntensity = totalMediumMinutes
                        workoutHighIntensity = totalHighMinutes
                        
                        print("計算出的強度分鐘數: 低=\(totalLowMinutes), 中=\(totalMediumMinutes), 高=\(totalHighMinutes)")
                    }
                    
                    
                    // 計算百分比
                    let total = lowCount + mediumCount + highCount
                    let lowPercentage = total > 0 ? Double(lowCount) / Double(total) * 100 : 0
                    let mediumPercentage = total > 0 ? Double(mediumCount) / Double(total) * 100 : 0
                    let highPercentage = total > 0 ? Double(highCount) / Double(total) * 100 : 0
                    
                    print("心率區間分布: 低=\(lowCount)(\(Int(lowPercentage))%), 中=\(mediumCount)(\(Int(mediumPercentage))%), 高=\(highCount)(\(Int(highPercentage))%)")
                    
                    // 將局部強度分鐘數設為此運動的計算結果
                    workoutLowIntensity = totalLowMinutes
                    workoutMediumIntensity = totalMediumMinutes
                    workoutHighIntensity = totalHighMinutes
                }
                
            } catch {
                print("獲取心率數據失敗: \(error.localizedDescription)")
                // 如果獲取心率數據失敗，仍然計入運動時間
                print("將運動時間 \(duration) 分鐘計入低強度")
                workoutLowIntensity = duration
            }
            
            // 將此運動的強度分鐘數累加到總計中
            print("此運動的強度分鐘數: 低=\(workoutLowIntensity), 中=\(workoutMediumIntensity), 高=\(workoutHighIntensity)")
            totalLowIntensity += workoutLowIntensity
            totalMediumIntensity += workoutMediumIntensity
            totalHighIntensity += workoutHighIntensity
        }
        
        print("強度計算結果: 低=\(totalLowIntensity), 中=\(totalMediumIntensity), 高=\(totalHighIntensity)")
        
        return TrainingIntensityManager.IntensityMinutes(
            low: totalLowIntensity,
            medium: totalMediumIntensity,
            high: totalHighIntensity
        )
    }
    
    /// 計算指定週的訓練強度總和
    func calculateWeeklyIntensity(weekStartDate: Date, healthKitManager: HealthKitManager) async -> TrainingIntensityManager.IntensityMinutes {
        let calendar = Calendar.current
        guard let weekEndDate = calendar.date(byAdding: .day, value: 7, to: weekStartDate) else {
            return .zero
        }
        
        do {
            // 獲取指定時間範圍內的訓練
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(
                start: weekStartDate,
                end: weekEndDate
            )
            
            // 從 UserPreferenceManager 獲取使用者的最大心率和靜息心率
            let userPrefs = UserPreferenceManager.shared
            
            // 對 UserPreferenceManager 中的值進行更詳細的檢查
            print("用戶偏好管理器心率設定狀態: ")
            print("- maxHeartRate: \(String(describing: userPrefs.maxHeartRate))")
            print("- restingHeartRate: \(String(describing: userPrefs.restingHeartRate))")
            print("- 從 UserDefaults 直接讀取 max_heart_rate: \(UserDefaults.standard.object(forKey: "max_heart_rate") ?? "nil")")
            print("- 從 UserDefaults 直接讀取 resting_heart_rate: \(UserDefaults.standard.object(forKey: "resting_heart_rate") ?? "nil")")
            
            let maxHR = Double(userPrefs.maxHeartRate ?? 180) // 若無設定，使用預設值180
            let restingHR = Double(userPrefs.restingHeartRate ?? 60) // 若無設定，使用預設值60
            
            print("使用最大心率: \(maxHR), 靜息心率: \(restingHR) 計算訓練強度")
            
            // 計算訓練強度
            return await calculateIntensity(
                for: workouts,
                maxHR: maxHR,
                restingHR: restingHR,
                healthKitManager: healthKitManager
            )
            
        } catch {
            print("計算每週訓練強度失敗: \(error.localizedDescription)")
            return .zero
        }
    }
    
    /// 獲取指定週的訓練強度數據 (Publisher 版本，用於 Combine)
    func getWeeklyIntensity(weekStartDate: Date, healthKitManager: HealthKitManager) -> AnyPublisher<TrainingIntensityManager.IntensityMinutes, Error> {
        Future { promise in
            Task {
                let intensity = await self.calculateWeeklyIntensity(
                    weekStartDate: weekStartDate,
                    healthKitManager: healthKitManager
                )
                promise(.success(intensity))
            }
        }
        .eraseToAnyPublisher()
    }
    

    // MARK: - 輔助方法
    
    // 輔助方法已在上方定義
}
