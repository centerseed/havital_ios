import SwiftUI
import HealthKit

struct WorkoutSummaryRow: View {
    let workout: HKWorkout
    @ObservedObject var viewModel: TrainingPlanViewModel
    @State private var averageHeartRate: Double? = nil
    @State private var isLoadingHeartRate = false
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
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
            
            VStack(alignment: .leading, spacing: 2) {
                // 時間
                /*Text(viewModel.formatTime(workout.startDate))
                    .font(.subheadline)
                    .foregroundColor(.white)*/
                Text("動態跑力：35.68")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                // 配速、距離和平均心率
                HStack(spacing: 12) {
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                        Text("\(viewModel.formatDistance(distance))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()), distance > 0 {
                        let paceInSeconds = workout.duration / distance * 1000
                        Text("\(viewModel.formatPace(paceInSeconds))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // 新增：顯示平均心率
                    if isLoadingHeartRate {
                        Text("心率計算中...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if let avgHR = averageHeartRate {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.red)
                            Text("\(Int(avgHR.rounded()))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 訓練時長
            Text(WorkoutUtils.formatDuration(workout.duration))
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
        .task {
            await loadAverageHeartRate()
        }
    }
    
    // 計算剔除首尾資料的平均心率
    private func loadAverageHeartRate() async {
        isLoadingHeartRate = true
        defer { isLoadingHeartRate = false }
        
        do {
            let heartRateData = try await healthKitManager.fetchHeartRateData(for: workout)
            
            // 確保至少有3筆資料，才能剔除首尾
            if heartRateData.count >= 3 {
                // 剔除第一筆和最後一筆
                let trimmedHeartRates = heartRateData[1..<(heartRateData.count - 1)]
                
                // 計算平均值
                let sum = trimmedHeartRates.reduce(0) { $0 + $1.1 }
                let avgHR = sum / Double(trimmedHeartRates.count)
                
                await MainActor.run {
                    self.averageHeartRate = avgHR
                }
            } else if !heartRateData.isEmpty {
                // 如果資料不足3筆，則計算所有資料的平均值
                let sum = heartRateData.reduce(0) { $0 + $1.1 }
                let avgHR = sum / Double(heartRateData.count)
                
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
                Text("\(viewModel.formatDistance(distance))")
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
            
            if workouts.count > 1 {
                Text("+\(workouts.count - 1)筆")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 2)
    }
}
