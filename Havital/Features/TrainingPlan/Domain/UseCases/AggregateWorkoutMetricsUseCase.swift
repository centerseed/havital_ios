import Foundation

// MARK: - Aggregate Workout Metrics Use Case
/// 聚合訓練記錄的指標數據（距離、強度）
/// Domain Layer - 封裝計算邏輯
struct AggregateWorkoutMetricsUseCase {

    // MARK: - Dependencies

    private let workoutRepository: WorkoutRepository

    // MARK: - Output Types

    /// 週訓練指標
    struct WeeklyMetrics {
        /// 總跑步距離（公里）
        let totalDistanceKm: Double

        /// 強度分布（分鐘）
        let intensity: WeeklyPlan.IntensityTotalMinutes
    }

    // MARK: - Initialization

    init(workoutRepository: WorkoutRepository) {
        self.workoutRepository = workoutRepository
    }

    // MARK: - Execute

    /// 執行用例：計算指定週的訓練指標
    /// - Parameter weekInfo: 週日期資訊
    /// - Returns: 週訓練指標
    func execute(weekInfo: WeekDateInfo) -> WeeklyMetrics {
        Logger.debug("[AggregateWorkoutMetricsUseCase] Calculating metrics from \(weekInfo.startDate) to \(weekInfo.endDate)")

        // 從 Repository 獲取訓練記錄
        let weekWorkouts = workoutRepository.getWorkoutsInDateRange(
            startDate: weekInfo.startDate,
            endDate: weekInfo.endDate
        )

        // 計算距離
        let totalDistance = calculateTotalDistance(workouts: weekWorkouts)

        // 計算強度
        let intensity = calculateIntensity(workouts: weekWorkouts)

        Logger.debug("[AggregateWorkoutMetricsUseCase] Distance: \(totalDistance) km, Intensity - low: \(intensity.low), medium: \(intensity.medium), high: \(intensity.high)")

        return WeeklyMetrics(
            totalDistanceKm: totalDistance,
            intensity: intensity
        )
    }

    // MARK: - Private Methods

    /// 計算跑步總距離
    private func calculateTotalDistance(workouts: [WorkoutV2]) -> Double {
        let runWorkouts = workouts.filter { $0.activityType == "running" }
        let totalMeters = runWorkouts.compactMap { $0.distance }.reduce(0, +)
        return totalMeters / 1000.0 // 轉換為公里
    }

    /// 計算訓練強度分布
    private func calculateIntensity(workouts: [WorkoutV2]) -> WeeklyPlan.IntensityTotalMinutes {
        // 過濾掉非有氧運動
        let aerobicWorkouts = workouts.filter { shouldIncludeInTrainingLoad(activityType: $0.activityType) }

        var totalLow: Double = 0
        var totalMedium: Double = 0
        var totalHigh: Double = 0

        for workout in aerobicWorkouts {
            var foundIntensityData = false

            // 從 advancedMetrics.intensityMinutes 提取強度數據
            if let advancedMetrics = workout.advancedMetrics,
               let intensityMinutes = advancedMetrics.intensityMinutes {
                let low = intensityMinutes.low ?? 0.0
                let medium = intensityMinutes.medium ?? 0.0
                let high = intensityMinutes.high ?? 0.0

                totalLow += low
                totalMedium += medium
                totalHigh += high
                foundIntensityData = true
            }

            // 如果沒有找到強度數據，使用持續時間作為備選方案（計入低強度）
            if !foundIntensityData {
                let fallbackLowIntensity = Double(workout.durationSeconds) / 60.0
                if fallbackLowIntensity > 0 {
                    totalLow += fallbackLowIntensity
                }
            }
        }

        return WeeklyPlan.IntensityTotalMinutes(
            low: totalLow,
            medium: totalMedium,
            high: totalHigh
        )
    }

    /// 判斷運動類型是否應該包含在訓練負荷計算中
    private func shouldIncludeInTrainingLoad(activityType: String) -> Bool {
        let aerobicActivityTypes: Set<String> = [
            "running",
            "walking",
            "cycling",
            "swimming",
            "hiit",
            "mixedCardio",
            "hiking",
            "cross_training"
        ]
        return aerobicActivityTypes.contains(activityType.lowercased())
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 AggregateWorkoutMetricsUseCase
    func makeAggregateWorkoutMetricsUseCase() -> AggregateWorkoutMetricsUseCase {
        // 確保 WorkoutRepository 已註冊
        if !isRegistered(WorkoutRepository.self) {
            registerWorkoutModule()
        }

        let workoutRepository: WorkoutRepository = resolve()
        return AggregateWorkoutMetricsUseCase(workoutRepository: workoutRepository)
    }
}
