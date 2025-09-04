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
    
    // 根據 workout type 選擇圖示
    private var workoutIconName: String {
        switch workout.workoutActivityType {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "drop.fill"
        case .hiking: return "figure.hiking"
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
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 顯示動態跑力 (Dynamic VDOT)
                if workout.workoutActivityType == .running {
                    if isLoadingVDOT {
                        Text(L10n.Performance.VDOT.calculatingVdot.localized)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let vdot = dynamicVDOT {
                        Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：\(String(format: "%.1f", vdot))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：--")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：--")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 配速、距離和平均心率
                HStack(spacing: 12) {
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                        HStack(spacing: 2) {
                            Image(systemName: "ruler")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("\(viewModel.formatDistance(distance/1000, unit: "km"))")
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
                        Text(L10n.WorkoutSummaryRow.calculatingHeartRate.localized)
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

        // 組出與後端一致的 workoutId
        let summaryId = WorkoutV2Service.shared.makeWorkoutId(for: workout)

        // 嘗試從快取讀取
        if let cached = WorkoutV2Service.shared.getCachedWorkoutSummary(for: summaryId) {
            await MainActor.run {
                self.dynamicVDOT = cached.vdot
                self.averageHeartRate = cached.avgHR
            }
            return
        }

        // 否則向後端請求
        do {
            let summary = try await WorkoutV2Service.shared.getWorkoutSummary(workoutId: summaryId)
            WorkoutV2Service.shared.saveCachedWorkoutSummary(summary, for: summaryId)
            await MainActor.run {
                self.dynamicVDOT = summary.vdot
                self.averageHeartRate = summary.avgHR
            }
        } catch {
            // 計算未就緒或失敗，保持 placeholder
        }
    }
}

struct CollapsedWorkoutSummary: View {
    let workouts: [HKWorkout]
    @ObservedObject var viewModel: TrainingPlanViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let workout = workouts.first {
                    // 配速、距離和時長
                    HStack(spacing: 12) {
                        if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                            HStack(spacing: 2) {
                                Image(systemName: "ruler")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("\(viewModel.formatDistance(distance/1000, unit: "km"))")
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
                        
                        // 訓練時長 (同 WorkoutSummaryRow)
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
        }
        .padding(.vertical, 2)
    }
}

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
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 顯示動態跑力 (Dynamic VDOT)
                if workout.activityType == "running" {
                    if let vdot = workout.dynamicVdot {
                        Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：\(String(format: "%.1f", vdot))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：--")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("\(L10n.Performance.VDOT.dynamicVdot.localized)：--")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 配速、距離和平均心率
                HStack(spacing: 12) {
                    if let distance = workout.distance {
                        HStack(spacing: 2) {
                            Image(systemName: "ruler")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("\(viewModel.formatDistance(distance/1000, unit: "km"))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if shouldShowPace, let distance = workout.distance, distance > 0 {
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
                    
                    // 顯示平均心率
                    if shouldShowHeartRate, let avgHR = workout.basicMetrics?.avgHeartRateBpm {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                            Text("\(avgHR)")
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
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("\(viewModel.formatDistance(distance/1000, unit: "km"))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if shouldShowPace, let distance = workout.distance, distance > 0 {
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
        }
        .padding(.vertical, 2)
    }
}
