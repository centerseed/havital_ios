import SwiftUI
import Charts
import HealthKit

struct PerformanceChartView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var performancePoints: [PerformancePoint] = []
    @State private var isLoading = true
    @State private var selectedPoint: PerformancePoint?
    private let banisterModel = BanisterModel()
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else {
                if performancePoints.isEmpty {
                    Text("沒有足夠的訓練資料")
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("近三個月訓練表現")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // 圖例
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("訓練日")
                                    .font(.caption)
                            }
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text("休息日")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                        
                        Chart {
                            ForEach(performancePoints) { point in
                                LineMark(
                                    x: .value("日期", point.date),
                                    y: .value("表現指數", point.performance)
                                )
                                .foregroundStyle(Color.blue.gradient)
                                
                                PointMark(
                                    x: .value("日期", point.date),
                                    y: .value("表現指數", point.performance)
                                )
                                .foregroundStyle(point.hasWorkout ? Color.orange : Color.blue)
                                .symbolSize(point.hasWorkout ? 100 : 50)
                            }
                        }
                        .chartYScale(domain: calculateYAxisRange())
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date.formatted(.dateTime.month().day()))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 200)
                        .padding(.vertical)
                        
                        if let selectedPoint = selectedPoint {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedPoint.date.formatted(.dateTime.year().month().day()))
                                    .font(.subheadline)
                                if selectedPoint.hasWorkout {
                                    Text(selectedPoint.workoutName ?? "未知運動")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                Text(String(format: "表現指數: %.1f", selectedPoint.performance))
                                    .font(.subheadline)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadPerformanceData()
        }
    }
    
    private func loadPerformanceData() async {
        print("開始加載性能數據")
        do {
            try await healthKitManager.requestAuthorization()
            
            // 獲取最大心率和靜息心率
            let maxHR = try await healthKitManager.fetchMaxHeartRate()
            let restingHR = try await healthKitManager.fetchRestingHeartRate()
            
            print("最大心率: \(maxHR), 靜息心率: \(restingHR)")
            
            // 設定日期範圍
            let calendar = Calendar.current
            let now = Date()
            print("當前時間: \(now)")
            
            // 設定結束時間為今天的23:59:59
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 23
            components.minute = 59
            components.second = 59
            let endDate = calendar.date(from: components)!
            
            // 開始時間為一個月前的00:00:00
            let startDate = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: endDate))!
            
            print("查詢範圍 - 開始: \(startDate), 結束: \(endDate)")
            
            // 重置模型
            self.banisterModel.reset()
            
            // 獲取訓練數據
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: startDate, end: endDate)
            print("獲取到 \(workouts.count) 條訓練記錄")

            
            var validWorkouts: [(Date, Double, HKWorkoutActivityType)] = []
            
            // 處理每個訓練記錄
            for workout in workouts {
                // 獲取心率數據
                let heartRates = try await healthKitManager.fetchHeartRateData(for: workout)
                guard !heartRates.isEmpty else {
                    print("訓練記錄被排除 - 日期: \(workout.startDate), 無心率數據")
                    continue
                }
                
                // 計算平均心率
                let avgHR = heartRates.map { $0.1 }.reduce(0, +) / Double(heartRates.count)
                
                // 計算TRIMP
                let trimp = self.banisterModel.calculateTrimp(
                    duration: workout.duration,
                    avgHR: avgHR,
                    restingHR: restingHR,
                    maxHR: maxHR
                )
                
                // 如果心率太低，將TRIMP設為較小的值而不是完全排除
                let effectiveTrimp = avgHR > 50 ? trimp : trimp * 0.5
                print("訓練記錄 - 日期: \(workout.startDate), 心率數據: \(heartRates.count)筆, 平均心率: \(avgHR), TRIMP: \(effectiveTrimp)")
                
                validWorkouts.append((workout.startDate, effectiveTrimp, workout.workoutActivityType))
            }
            
            // 按日期排序訓練記錄
            validWorkouts.sort { $0.0 < $1.0 }
            
            // 從第一個有效訓練日開始
            guard let firstWorkoutDate = validWorkouts.first?.0 else {
                print("沒有有效的訓練記錄")
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            // 使用第一個訓練日作為起始日期
            var points: [PerformancePoint] = []
            var currentDate = calendar.startOfDay(for: firstWorkoutDate)
            
            print("生成性能點 - 開始日期: \(currentDate), 結束日期: \(endDate)")
            while currentDate <= endDate {
                // 查找當天所有的訓練
                let todaysWorkouts = validWorkouts.filter { workoutDate in
                    calendar.isDate(workoutDate.0, inSameDayAs: currentDate)
                }
            
                
                if !todaysWorkouts.isEmpty {
                    // 計算當天的總 TRIMP
                    let totalTrimp = todaysWorkouts.reduce(0.0) { sum, workout in
                        sum + workout.1
                    }
                    print("當天總 TRIMP: \(totalTrimp)")
                    
                    // 更新模型並計算表現
                    self.banisterModel.update(date: currentDate, trimp: totalTrimp)
                    
                    let hasWorkout = true
                    let workoutName = WorkoutUtils.workoutTypeString(for: todaysWorkouts[0].2)
                    
                    // 計算當天的表現指數，結合HRV數據
                    var performance = self.banisterModel.performance()
                
            
                    let point = PerformancePoint(
                        date: currentDate,
                        performance: performance,
                        hasWorkout: hasWorkout,
                        workoutName: workoutName
                    )
                    points.append(point)
                    print("添加性能點 - 日期: \(currentDate), 性能: \(point.performance), TRIMP: \(totalTrimp)")
                } else {
                    // 如果當天沒有訓練，更新模型並添加點
                    self.banisterModel.update(date: currentDate)
                    
                    let point = PerformancePoint(
                        date: currentDate,
                        performance: self.banisterModel.performance(),
                        hasWorkout: false,
                        workoutName: nil
                    )
                    points.append(point)
                    print("添加休息日性能點 - 日期: \(currentDate), 性能: \(point.performance)")
                }
                
                // 移至下一天
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            print("所有訓練數據處理完成，共有 \(points.count) 個數據點")
            await MainActor.run {
                self.performancePoints = points
                self.isLoading = false
            }
            
        } catch {
            print("處理訓練數據時出錯: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // 計算Y軸範圍
    private func calculateYAxisRange() -> ClosedRange<Double> {
        guard !performancePoints.isEmpty else { return 0...100 }
        
        let minPerformance = performancePoints.map { $0.performance }.min() ?? 0
        let maxPerformance = performancePoints.map { $0.performance }.max() ?? 100
        
        // 計算值的範圍
        let range = maxPerformance - minPerformance
        
        // 根據最小值是否為負數來計算下界
        let lowerBound: Double
        if minPerformance < 0 {
            // 如果是負數，則下界為最小值減去範圍的20%
            lowerBound = minPerformance - (range * 0.2)
        } else {
            // 如果是正數，則下界為最小值的80%
            lowerBound = minPerformance * 0.8
        }
        
        // 上界為最大值加上範圍的10%
        let upperBound = maxPerformance + (range * 0.1)
        
        print("性能範圍 - 最小值: \(minPerformance), 最大值: \(maxPerformance)")
        print("圖表範圍 - 下界: \(lowerBound), 上界: \(upperBound)")
        
        return lowerBound...upperBound
    }
}

struct PerformancePoint: Identifiable {
    let id = UUID()
    let date: Date
    let performance: Double
    let hasWorkout: Bool
    let workoutName: String?
}
