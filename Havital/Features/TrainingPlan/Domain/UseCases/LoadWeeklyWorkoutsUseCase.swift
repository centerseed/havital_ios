import Foundation

// MARK: - Load Weekly Workouts Use Case
/// 載入並分組指定週的訓練記錄
/// Domain Layer - 封裝業務邏輯
struct LoadWeeklyWorkoutsUseCase {

    // MARK: - Dependencies

    private let workoutRepository: WorkoutRepository

    // MARK: - Initialization

    init(workoutRepository: WorkoutRepository) {
        self.workoutRepository = workoutRepository
    }

    // MARK: - Execute

    /// 執行用例：載入指定週的訓練記錄並按天分組
    /// - Parameters:
    ///   - weekInfo: 週日期資訊
    ///   - activityTypes: 要包含的運動類型（預設為跑步相關）
    /// - Returns: 按 dayIndex 分組的訓練記錄
    func execute(
        weekInfo: WeekDateInfo,
        activityTypes: Set<String> = ["running", "walking", "hiking", "cross_training"]
    ) async -> [Int: [WorkoutV2]] {
        Logger.debug("[LoadWeeklyWorkoutsUseCase] Loading workouts from \(weekInfo.startDate) to \(weekInfo.endDate)")

        // ✅ 使用 async 版本從 LocalDataSource 獲取訓練記錄
        let weekWorkouts = await workoutRepository.getWorkoutsInDateRangeAsync(
            startDate: weekInfo.startDate,
            endDate: weekInfo.endDate
        )

        Logger.debug("[LoadWeeklyWorkoutsUseCase] Found \(weekWorkouts.count) workouts in week")

        // 按天分組
        let grouped = groupWorkoutsByDay(weekWorkouts, weekInfo: weekInfo, activityTypes: activityTypes)

        Logger.debug("[LoadWeeklyWorkoutsUseCase] Grouped into days: \(grouped.keys.sorted())")

        return grouped
    }

    // MARK: - Private Methods

    /// 將訓練記錄按天分組
    private func groupWorkoutsByDay(
        _ workouts: [WorkoutV2],
        weekInfo: WeekDateInfo,
        activityTypes: Set<String>
    ) -> [Int: [WorkoutV2]] {
        let calendar = Calendar.current
        var grouped: [Int: [WorkoutV2]] = [:]

        for workout in workouts {
            // 過濾運動類型
            guard activityTypes.contains(workout.activityType) else {
                continue
            }

            // 使用 weekDateInfo 的日期映射找到對應的 dayIndex
            var dayIndex: Int?
            for (index, dateInWeek) in weekInfo.daysMap {
                if calendar.isDate(workout.startDate, inSameDayAs: dateInWeek) {
                    dayIndex = index
                    break
                }
            }

            // 後備方案：使用 Calendar.weekday
            if dayIndex == nil {
                let weekday = calendar.component(.weekday, from: workout.startDate)
                dayIndex = weekday == 1 ? 7 : weekday - 1
                Logger.debug("[LoadWeeklyWorkoutsUseCase] Using fallback dayIndex: \(dayIndex ?? 0)")
            }

            guard let dayIndex = dayIndex else {
                Logger.error("[LoadWeeklyWorkoutsUseCase] Failed to calculate dayIndex for workout: \(workout.startDate)")
                continue
            }

            if grouped[dayIndex] == nil {
                grouped[dayIndex] = []
            }
            grouped[dayIndex]?.append(workout)
        }

        // 按結束時間排序（最新的在前）
        for (dayIndex, workouts) in grouped {
            grouped[dayIndex] = workouts.sorted { $0.endDate > $1.endDate }
        }

        return grouped
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 LoadWeeklyWorkoutsUseCase
    func makeLoadWeeklyWorkoutsUseCase() -> LoadWeeklyWorkoutsUseCase {
        // 確保 WorkoutRepository 已註冊
        if !isRegistered(WorkoutRepository.self) {
            registerWorkoutModule()
        }

        let workoutRepository: WorkoutRepository = resolve()
        return LoadWeeklyWorkoutsUseCase(workoutRepository: workoutRepository)
    }
}
