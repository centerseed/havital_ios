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
    func calculateIntensity(for workouts: [HKWorkout], healthKitManager: HealthKitManager) async -> TrainingIntensityManager.IntensityMinutes {
        // 設定預設值
        let defaultMaxHR = 180
        let defaultRestingHR = 60
        
        // 使用預設值或使用者設定的值，並確保數值合理
        var maxHRInt = UserPreferenceManager.shared.maxHeartRate ?? defaultMaxHR
        var restingHRInt = UserPreferenceManager.shared.restingHeartRate ?? defaultRestingHR
        
        // 驗證心率值是否合理，如果無效則使用預設值
        if !(maxHRInt > 0 && restingHRInt > 0 && maxHRInt > restingHRInt) {
            print("TrainingIntensityManager: 無效的心率設定 - 最大心率: \(maxHRInt), 靜息心率: \(restingHRInt)。使用預設值 (180/60)。")
            maxHRInt = defaultMaxHR
            restingHRInt = defaultRestingHR
        }
        
        let maxHR = Double(maxHRInt)
        let restingHR = Double(restingHRInt)
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
            var workoutHighIntensity: Double = 0.0
            var actualHeartRateDataSpanMinutes: Double? = nil // 用於比較計算出的強度總和與心率數據的實際時間跨度
            var gapAtStartMinutes: Double = 0.0
            var gapAtEndMinutes: Double = 0.0
            
            do {
                // 使用與 WorkoutDetailView 相同的方式獲取心率數據
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
                
                if !heartRateData.isEmpty {
                    if heartRateData.count >= 2 {
                        actualHeartRateDataSpanMinutes = heartRateData.last!.0.timeIntervalSince(heartRateData.first!.0) / 60.0
                    } else { // count == 1
                        actualHeartRateDataSpanMinutes = 0.0 // 單個數據點的時間跨度為0
                    }
                }
                print("獲取到 \(heartRateData.count) 個心率數據點")
                print("HIM_DEBUG: Workout Details: UUID=\(workout.uuid), HKStart=\(workout.startDate), HKEnd=\(workout.endDate), HKDuration=\(workout.duration / 60.0) mins")
                if !heartRateData.isEmpty {
                    let firstHRSampleTime = heartRateData.first!.0
                    let lastHRSampleTime = heartRateData.last!.0
                    let hrDataSpan = lastHRSampleTime.timeIntervalSince(firstHRSampleTime) / 60.0
                    print("HIM_DEBUG: HR Data: First sample at \(firstHRSampleTime) (\(DateFormatter.localizedString(from: firstHRSampleTime, dateStyle: .none, timeStyle: .medium))), Last sample at \(lastHRSampleTime) (\(DateFormatter.localizedString(from: lastHRSampleTime, dateStyle: .none, timeStyle: .medium))). Span of HR samples = \(hrDataSpan) mins")
                    
                    let gapAtStart = firstHRSampleTime.timeIntervalSince(workout.startDate) / 60.0
                    let gapAtEnd = workout.endDate.timeIntervalSince(lastHRSampleTime) / 60.0
                                        gapAtStartMinutes = firstHRSampleTime.timeIntervalSince(workout.startDate) / 60.0
                    gapAtEndMinutes = workout.endDate.timeIntervalSince(lastHRSampleTime) / 60.0
                    print("HIM_DEBUG: Gap analysis: Time from workout start to first HR sample = \(gapAtStartMinutes) mins. Time from last HR sample to workout end = \(gapAtEndMinutes) mins.")

                    // 將間隙時間計入低強度
                    if gapAtStartMinutes > 0 {
                        workoutLowIntensity += gapAtStartMinutes
                        print("HIM_DEBUG: Added \(gapAtStartMinutes) mins from gapAtStart to low intensity.")
                    }
                    if gapAtEndMinutes > 0 {
                        workoutLowIntensity += gapAtEndMinutes
                        print("HIM_DEBUG: Added \(gapAtEndMinutes) mins from gapAtEnd to low intensity.")
                    }

                } else {
                    print("HIM_DEBUG: HR Data is empty for this workout.")
                }
                
                // 計算心率統計信息，用於診斷
                if !heartRateData.isEmpty {
                    let heartRateValues = heartRateData.map { $0.1 }
                    let minHRWorkout = heartRateValues.min() ?? 0
                    let maxHRWorkout = heartRateValues.max() ?? 0
                    let avgHR = heartRateValues.reduce(0, +) / Double(heartRateValues.count)
                    print("心率統計: 最低=\(minHRWorkout), 最高=\(maxHRWorkout), 平均=\(avgHR)")
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
                    print("開始心率分析 - 最大心率 (來自UserPreference): \(maxHR), 靜息心率 (來自UserPreference): \(restingHR)")
                    if let firstHR = heartRateData.first?.1, let lastHR = heartRateData.last?.1 {
                        print("第一個心率讀數: \(firstHR), 最後一個心率讀數: \(lastHR)")
                    }
                    
                    // 計算心率樣本點之間的時間間隔，估算更準確的強度分鐘數
                    if heartRateData.count == 1 {
                        let hr = heartRateData[0].1
                        let hrr = (hr - restingHR) / (maxHR - restingHR) * 100
                        print("HIM_DEBUG: Single HR sample. HR=\(hr), HRR=\(hrr)%. Gaps already added to low intensity. This point contributes 0 minutes to specific HRR zones as per Scheme A.")
                        // For a single point, minutesForThisPoint is 0. Intensity for gaps is already handled (defaulted to low).
                        // No direct minutes are added here based on HRR for the point itself to totalLow/Medium/HighMinutes.
                        // workoutLowIntensity already includes gap times which cover the workout duration if HR data is just one point.
                        // We still need to set lowCount, mediumCount, highCount if we want to log the distribution for this single point.
                        if hrr <= 72 {
                            lowCount = 1
                        } else if hrr <= 84 {
                            mediumCount = 1
                        } else {
                            highCount = 1
                        }
                    } else if heartRateData.count > 1 {
                        // 多個心率樣本點，考慮點與點之間的時間差
                        // 重置計算用的強度分鐘數 (這些是基於HR數據點的，不包括gap)
                        totalLowMinutes = 0
                        totalMediumMinutes = 0
                        totalHighMinutes = 0
                        lowCount = 0
                        mediumCount = 0
                        highCount = 0
                        
                        for i in 0..<heartRateData.count {
                            let (time, hr) = heartRateData[i]
                            let hrr = (hr - restingHR) / (maxHR - restingHR) * 100
                            
                            if i % 30 == 0 || i < 5 || i == heartRateData.count - 1 {
                                print("HIM_DEBUG: HR Sample \(i): Time=\(time), HR=\(hr), HRR=\(hrr)%")
                            }
                            
                            var minutesForThisPoint: Double = 0
                            if i == 0 { // First point
                                let nextTime = heartRateData[i+1].0
                                minutesForThisPoint = (nextTime.timeIntervalSince(time) / 60.0) / 2.0
                            } else if i == heartRateData.count - 1 { // Last point
                                let prevTime = heartRateData[i-1].0
                                minutesForThisPoint = (time.timeIntervalSince(prevTime) / 60.0) / 2.0
                            } else { // Intermediate points
                                let prevTime = heartRateData[i-1].0
                                let nextTime = heartRateData[i+1].0
                                minutesForThisPoint = (nextTime.timeIntervalSince(prevTime) / 60.0) / 2.0
                            }
                            
                            if i % 30 == 0 || i < 5 || i == heartRateData.count - 1 {
                                print("HIM_DEBUG: HR Sample \(i) contributes \(minutesForThisPoint) minutes.")
                            }

                            if hrr <= 72 {
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
                        
                        // 更新 workout 的強度分鐘數 (累加由 HR data points 計算出的部分)
                        // gap times 已經在 workoutLowIntensity 中了
                        workoutLowIntensity += totalLowMinutes
                        workoutMediumIntensity += totalMediumMinutes
                        workoutHighIntensity += totalHighMinutes
                        
                        print("HIM_DEBUG: For workout UUID=\(workout.uuid), intensity minutes from HR data loop (excluding gaps): Low=\(totalLowMinutes), Medium=\(totalMediumMinutes), High=\(totalHighMinutes).")
                        print("HIM_DEBUG: Total workout intensity after adding HR data loop to gaps: Low=\(workoutLowIntensity), Medium=\(workoutMediumIntensity), High=\(workoutHighIntensity).")
                        let totalPoints = Double(heartRateData.count)
                        let lowPercentage = totalPoints > 0 ? (Double(lowCount) / totalPoints * 100) : 0
                        let mediumPercentage = totalPoints > 0 ? (Double(mediumCount) / totalPoints * 100) : 0
                        let highPercentage = totalPoints > 0 ? (Double(highCount) / totalPoints * 100) : 0
                        print("HIM_DEBUG: HR Points Distribution: Low=\(lowCount)(\(Int(lowPercentage))%), Medium=\(mediumCount)(\(Int(mediumPercentage))%), High=\(highCount)(\(Int(highPercentage))%)")
                    }
                    // Note: The 'else' case for heartRateData.isEmpty was handled before this block.
                    // Final workout intensities (workoutLowIntensity, workoutMediumIntensity, workoutHighIntensity)
                    // are now correctly set within the respective heartRateData.count == 1 or heartRateData.count > 1 blocks,
                    // incorporating gap times and HR-derived times.
                }
                
            } catch {
                print("獲取心率數據失敗: \(error.localizedDescription)")
                // 如果獲取心率數據失敗，仍然計入運動時間
                print("獲取心率數據失敗: \(error.localizedDescription). Workout duration \(duration) mins will be added to low intensity.")
                // 如果獲取心率數據失敗，將整個運動持續時間計入低強度
                // 但要避免重複計算已通過 gapAtStart/End 加入的部分 (雖然此時 gaps 應為0)
                // 為簡化，如果完全失敗，則 workoutLowIntensity 直接設為 duration
                // 如果之前 gap 計算已執行且有值，這裡可能需要更細緻處理，但 fetchHeartRateData 失敗意味著 gaps 也無法計算
                workoutLowIntensity = duration
                workoutMediumIntensity = 0 //確保其他強度為0
                workoutHighIntensity = 0
            }
            
            // 將此運動的強度分鐘數累加到總計中
            print("此運動的強度分鐘數: 低=\(workoutLowIntensity), 中=\(workoutMediumIntensity), 高=\(workoutHighIntensity)")
            let calculatedIntensitySumForWorkout = workoutLowIntensity + workoutMediumIntensity + workoutHighIntensity
                print("HIM_DEBUG: For workout UUID=\(workout.uuid), calculated intensity minutes: Low=\(workoutLowIntensity), Medium=\(workoutMediumIntensity), High=\(workoutHighIntensity). Sum = \(calculatedIntensitySumForWorkout) mins")
                if let hrSpan = actualHeartRateDataSpanMinutes {
                    // 心率數據可用並且已計算時間跨度
                    if abs(calculatedIntensitySumForWorkout - hrSpan) > 0.1 { // 0.1 分鐘 (6秒) 的浮點數容許誤差
                        print("HIM_DEBUG: WARNING - 計算出的強度分鐘總和 (\(calculatedIntensitySumForWorkout)) 與心率數據時間跨度 (\(hrSpan)) 不符，運動 UUID=\(workout.uuid). 計算總和: \(calculatedIntensitySumForWorkout), 心率跨度: \(hrSpan)")
                    } else {
                        print("HIM_DEBUG: 計算出的強度分鐘總和 (\(calculatedIntensitySumForWorkout)) 與心率數據時間跨度 (\(hrSpan)) 相符，運動 UUID=\(workout.uuid).")
                    }
                } else {
                    // 心率數據不可用或點數不足以計算時間跨度
                    print("HIM_DEBUG: 心率數據不可用或點數不足，無法計算時間跨度以與計算出的強度進行比較，運動 UUID=\(workout.uuid). 計算總和: \(calculatedIntensitySumForWorkout)")
                }
                print("HIM_DEBUG: Workout HKDuration was \(workout.duration / 60.0) mins. If this differs from calculatedIntensitySumForWorkout, it might be due to HR data not covering the full duration or other logic.")

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
        // maxHR and restingHR will be fetched inside calculateIntensity which is called below
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZoneManager.shared.getCurrentTimeZone()
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
            print("- maxHeartRate: \(String(describing: UserPreferenceManager.shared.maxHeartRate))")
            print("- restingHeartRate: \(String(describing: UserPreferenceManager.shared.restingHeartRate))")
            print("- 從 UserDefaults 直接讀取 max_heart_rate: \(UserDefaults.standard.object(forKey: "max_heart_rate") ?? "nil")")
            print("- 從 UserDefaults 直接讀取 resting_heart_rate: \(UserDefaults.standard.object(forKey: "resting_heart_rate") ?? "nil")")
            // 直接呼叫修改後的 calculateIntensity，它會自行處理心率數據
            return await calculateIntensity(for: workouts, healthKitManager: healthKitManager)
            
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
