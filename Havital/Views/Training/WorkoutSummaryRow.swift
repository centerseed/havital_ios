import SwiftUI
import HealthKit

// MARK: - WorkoutV2 組件

struct WorkoutV2SummaryRow: View {
    let workout: WorkoutV2
    @ObservedObject var viewModel: TrainingPlanViewModel
    let trainingType: DayType?  // 新增訓練類型參數
    
    // MARK: - 訓練指標顯示邏輯
    
    /// 根據訓練類型判斷是否顯示配速資訊
    private var shouldShowPace: Bool {
        guard let type = trainingType else { return true }
        switch type {
        case .easyRun, .easy, .recovery_run, .longRun, .lsd:
            return false  // 輕鬆跑、恢復跑、長跑、LSD 隱藏配速
        case .interval, .tempo, .threshold, .progression:
            return true   // 間歇、節奏跑、閾值跑、漸進跑 顯示配速
        default:
            return true   // 其他類型預設顯示配速
        }
    }
    
    /// 根據訓練類型判斷是否顯示心率資訊
    private var shouldShowHeartRate: Bool {
        guard let type = trainingType else { return true }
        switch type {
        case .interval:
            return false  // 間歇訓練隱藏心率
        case .easyRun, .easy, .recovery_run, .longRun, .lsd, .tempo, .threshold, .progression:
            return true   // 有氧訓練顯示心率
        default:
            return true   // 其他類型預設顯示心率
        }
    }
    
    // 根據 workout type 選擇圖示
    private var workoutIconName: String {
        switch workout.activityType {
        case "running": return "figure.run"
        case "walking": return "figure.walk"
        case "cycling": return "bicycle"
        case "swimming": return "drop.fill"
        case "hiking": return "figure.hiking"
        default: return "questionmark"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 圓形圖標顯示運動類型
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: workoutIconName)
                    .foregroundColor(.blue)
                    .font(AppFont.body())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 顯示動態跑力 (Dynamic VDOT)
                if workout.activityType == "running" {
                    if let vdot = workout.dynamicVdot {
                        Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：\(String(format: "%.1f", vdot))")
                            .font(AppFont.bodySmall())
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：--")
                            .font(AppFont.bodySmall())
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：--")
                        .font(AppFont.bodySmall())
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 配速、距離和平均心率
                HStack(spacing: 12) {
                    if let distance = workout.distance {
                        HStack(spacing: 2) {
                            Image(systemName: "ruler")
                                .font(AppFont.captionSmall())
                                .foregroundColor(.blue)
                            Text(UnitManager.shared.formatDistance(distance / 1000))
                                .font(AppFont.caption())
                                .foregroundColor(.gray)
                        }
                    }

                    if shouldShowPace, let paceInSeconds = workout.displayPaceSecondsPerKm {
                        HStack(spacing: 2) {
                            Image(systemName: "speedometer")
                                .font(AppFont.captionSmall())
                                .foregroundColor(.green)
                            Text(UnitManager.shared.formatPace(secondsPerKm: paceInSeconds))
                                .font(AppFont.caption())
                                .foregroundColor(.gray)
                        }
                    }

                    // 顯示平均心率
                    if shouldShowHeartRate, let avgHR = workout.basicMetrics?.avgHeartRateBpm {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(AppFont.captionSmall())
                                .foregroundColor(.red)
                            Text("\(avgHR)")
                                .font(AppFont.caption())
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 訓練時長
                    HStack(spacing: 2) {
                        Image(systemName: "fitness.timer.fill")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.gray)
                        Text(WorkoutUtils.formatDurationSimple(workout.duration))
                            .font(AppFont.caption())
                            .foregroundColor(.gray)
                    }
                   
                }
            }

        }
        .padding(.vertical, 4)
    }
}

struct CollapsedWorkoutV2Summary: View {
    let workouts: [WorkoutV2]
    @ObservedObject var viewModel: TrainingPlanViewModel
    let trainingType: DayType?  // 新增訓練類型參數
    
    // MARK: - 訓練指標顯示邏輯
    
    /// 根據訓練類型判斷是否顯示配速資訊
    private var shouldShowPace: Bool {
        guard let type = trainingType else { return true }
        switch type {
        case .easyRun, .easy, .recovery_run, .longRun, .lsd:
            return false  // 輕鬆跑、恢復跑、長跑、LSD 隱藏配速
        case .interval, .tempo, .threshold, .progression:
            return true   // 間歇、節奏跑、閾值跑、漸進跑 顯示配速
        default:
            return true   // 其他類型預設顯示配速
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let workout = workouts.first {
                    // 配速、距離和時長
                    HStack(spacing: 12) {
                        if let distance = workout.distance {
                            HStack(spacing: 2) {
                                Image(systemName: "ruler")
                                    .font(AppFont.captionSmall())
                                    .foregroundColor(.blue)
                                Text(UnitManager.shared.formatDistance(distance / 1000))
                                    .font(AppFont.caption())
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if shouldShowPace, let paceInSeconds = workout.displayPaceSecondsPerKm {
                            HStack(spacing: 2) {
                                Image(systemName: "speedometer")
                                    .font(AppFont.captionSmall())
                                    .foregroundColor(.green)
                                Text(UnitManager.shared.formatPace(secondsPerKm: paceInSeconds))
                                    .font(AppFont.caption())
                                    .foregroundColor(.gray)
                            }
                        }

                        // 訓練時長
                        HStack(spacing: 2) {
                            Image(systemName: "fitness.timer.fill")
                                .font(AppFont.captionSmall())
                                .foregroundColor(.gray)
                            Text(WorkoutUtils.formatDurationSimple(workout.duration))
                                .font(AppFont.caption())
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
