import Foundation

// MARK: - Workout Repository Protocol
/// 定義訓練記錄數據存取介面
/// Domain Layer - 只定義介面，不涉及實作細節
protocol WorkoutRepository {

    // MARK: - Query (DEPRECATED - Use Async versions)

    /// 獲取指定日期範圍內的訓練記錄
    /// - Warning: Deprecated - Use getWorkoutsInDateRangeAsync() for LocalDataSource consistency
    /// - Parameters:
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    /// - Returns: 訓練記錄列表
    @available(*, deprecated, message: "Use getWorkoutsInDateRangeAsync() for LocalDataSource consistency")
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2]

    /// 獲取所有已載入的訓練記錄
    /// - Warning: Deprecated - Use getAllWorkoutsAsync() for LocalDataSource consistency
    /// - Returns: 訓練記錄列表
    @available(*, deprecated, message: "Use getAllWorkoutsAsync() for LocalDataSource consistency")
    func getAllWorkouts() -> [WorkoutV2]

    // MARK: - Async Query (Clean Architecture - LocalDataSource)

    /// 獲取指定日期範圍內的訓練記錄 (異步版本)
    /// - Parameters:
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    /// - Returns: 訓練記錄列表
    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2]

    /// 獲取所有已載入的訓練記錄 (異步版本)
    /// - Returns: 訓練記錄列表
    func getAllWorkoutsAsync() async -> [WorkoutV2]

    // MARK: - Workout List (Workout 模組使用)

    /// 獲取訓練列表（支援緩存）
    /// - Parameters:
    ///   - limit: 限制返回數量（可選）
    ///   - offset: 偏移量（可選，用於分頁）
    /// - Returns: 訓練列表
    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2]

    /// 強制刷新訓練列表（跳過緩存）
    /// - Returns: 最新的訓練列表
    func refreshWorkouts() async throws -> [WorkoutV2]

    // MARK: - Pagination (Migrated from UnifiedWorkoutManager)

    /// 載入初始運動記錄（分頁版本）
    /// - Parameter pageSize: 每頁數量，預設 10
    /// - Returns: 分頁回應
    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse

    /// 載入更多運動記錄（分頁版本）
    /// - Parameters:
    ///   - afterCursor: 最舊記錄的 ID
    ///   - pageSize: 每頁數量，預設 10
    /// - Returns: 分頁回應
    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse

    /// 刷新最新運動記錄（分頁版本）
    /// - Parameters:
    ///   - beforeCursor: 最新記錄的 ID
    ///   - pageSize: 每頁數量，預設 10
    /// - Returns: 分頁回應
    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse

    // MARK: - Single Workout

    /// 獲取單個訓練
    /// - Parameter id: 訓練 ID
    /// - Returns: 訓練實體
    func getWorkout(id: String) async throws -> WorkoutV2

    /// 獲取完整訓練詳情（包含時間序列數據）
    /// - Parameter id: 訓練 ID
    /// - Returns: 完整訓練詳情
    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail

    /// 刷新訓練詳情（跳過緩存）
    /// - Parameter id: 訓練 ID
    /// - Returns: 最新的完整訓練詳情
    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail

    /// 清除指定訓練的詳情緩存
    /// - Parameter id: 訓練 ID
    func clearWorkoutDetailCache(id: String) async

    /// 同步訓練數據到後端
    /// - Parameter workout: 訓練實體
    /// - Returns: 同步後的訓練實體
    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2

    /// 更新訓練心得
    /// - Parameters:
    ///   - id: 訓練 ID
    ///   - notes: 心得內容
    func updateTrainingNotes(id: String, notes: String) async throws

    /// 刪除訓練
    /// - Parameter id: 訓練 ID
    func deleteWorkout(id: String) async throws

    // MARK: - Cache Management

    /// 無效化背景刷新 cooldown（收到推播時呼叫，讓下次存取觸發 API 刷新）
    func invalidateRefreshCooldown()

    /// 清除所有緩存
    func clearCache() async

    /// 預載入數據（用於優化啟動速度）
    func preloadData() async

    // MARK: - Notifications

    /// 訓練記錄更新的通知名稱
    var workoutsDidUpdateNotification: Notification.Name { get }
}

// MARK: - Workout Repository Errors
enum WorkoutRepositoryError: Error, Equatable {
    /// 資料來源不可用
    case dataSourceUnavailable

    /// 日期範圍無效
    case invalidDateRange

    /// 資料格式錯誤
    case invalidDataFormat(String)
}

// MARK: - WorkoutRepositoryError to DomainError
extension WorkoutRepositoryError {
    func toDomainError() -> DomainError {
        switch self {
        case .dataSourceUnavailable:
            return .networkFailure("Workout data source unavailable")
        case .invalidDateRange:
            return .validationFailure("Invalid date range")
        case .invalidDataFormat(let message):
            return .dataCorruption(message)
        }
    }
}
