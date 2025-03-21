import SwiftUI
import HealthKit

struct WorkoutSummaryRow: View {
    let workout: HKWorkout
    @ObservedObject var viewModel: TrainingPlanViewModel
    @State private var averageHeartRate: Double? = nil
    @State private var dynamicVDOT: Double? = nil
    @State private var isLoadingHeartRate = false
    @State private var isLoadingVDOT = false
    @EnvironmentObject private var healthKitManager: HealthKitManager
    private let vdotCalculator = VDOTCalculator()
    
    var body: some View {
        HStack(spacing: 12) {
            // 圓形圖標顯示運動類型
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "figure.run")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 顯示動態跑力 (Dynamic VDOT)
                if isLoadingVDOT {
                    Text("計算動態跑力中...")
                        .font(.subheadline)
                        .foregroundColor(.white)
                } else if let vdot = dynamicVDOT {
                    Text("動態跑力：\(String(format: "%.1f", vdot))")
                        .font(.subheadline)
                        .foregroundColor(.white)
                } else {
                    Text("動態跑力：--")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                // 配速、距離和平均心率
                HStack(spacing: 12) {
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                        HStack(spacing: 2) {
                            Image(systemName: "ruler")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("\(viewModel.formatDistance(distance/1000))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 {
                        let paceInSeconds = workout.duration / distance * 1000
                        HStack(spacing: 2) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("\(viewModel.formatPace(paceInSeconds))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 新增：顯示平均心率
                    if isLoadingHeartRate {
                        Text("心率計算中...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if let avgHR = averageHeartRate {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                            Text("\(Int(avgHR.rounded()))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 訓練時長
                    HStack(spacing: 2) {
                        Image(systemName: "fitness.timer.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(WorkoutUtils.formatDurationSimple(workout.duration))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                   
                }
            }

        }
        .padding(.vertical, 4)
        .task {
            await loadWorkoutData()
        }
    }
    
    // 計算剔除首尾資料的平均心率並計算動態跑力
    private func loadWorkoutData() async {
        isLoadingHeartRate = true
        isLoadingVDOT = true
        
        defer {
            isLoadingHeartRate = false
            isLoadingVDOT = false
        }
        
        do {
            let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
            var avgHR: Double = 0
            
            // 確保至少有3筆資料，才能剔除首尾
            if heartRateData.count >= 3 {
                // 剔除第一筆和最後一筆
                let trimmedHeartRates = heartRateData[1..<(heartRateData.count - 1)]
                
                // 計算平均值
                let sum = trimmedHeartRates.reduce(0) { $0 + $1.1 }
                avgHR = sum / Double(trimmedHeartRates.count)
            } else if !heartRateData.isEmpty {
                // 如果資料不足3筆，則計算所有資料的平均值
                let sum = heartRateData.reduce(0) { $0 + $1.1 }
                avgHR = sum / Double(heartRateData.count)
            } else {
                return // 沒有心率數據，無法計算
            }
            
            // 獲取用戶的最大心率和靜息心率
            let maxHR = UserPreferenceManager.shared.maxHeartRate ?? 180
            let restingHR = UserPreferenceManager.shared.restingHeartRate ?? 60
            
            // 計算動態跑力 (Dynamic VDOT)
            if let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 {
                let distanceKm = distance / 1000
                let paceInSeconds = workout.duration / distance * 1000
                let paceMinutes = Int(paceInSeconds) / 60
                let paceSeconds = Int(paceInSeconds) % 60
                let paceStr = String(format: "%d:%02d", paceMinutes, paceSeconds)
                
                // 使用 VDOT 計算器計算動態跑力
                let vdot = vdotCalculator.calculateDynamicVDOTFromPace(
                    distanceKm: distanceKm,
                    paceStr: paceStr,
                    hr: avgHR,
                    maxHR: Double(maxHR),
                    restingHR: Double(restingHR)
                )
                
                await MainActor.run {
                    self.averageHeartRate = avgHR
                    self.dynamicVDOT = vdot
                }
            } else {
                await MainActor.run {
                    self.averageHeartRate = avgHR
                }
            }
        } catch {
            print("獲取心率數據失敗: \(error)")
        }
    }
}

struct CollapsedWorkoutSummary: View {
    let workouts: [HKWorkout]
    @ObservedObject var viewModel: TrainingPlanViewModel
    
    var body: some View {
        HStack {
            if let workout = workouts.first, let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                Text("\(viewModel.formatDistance(distance/1000))")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.trailing, 4)
                
                if distance > 0 {
                    let paceInSeconds = workout.duration / distance * 1000
                    Text("\(viewModel.formatPace(paceInSeconds))")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.trailing, 4)
                }
            }
        }
        .padding(.top, 2)
    }
}
