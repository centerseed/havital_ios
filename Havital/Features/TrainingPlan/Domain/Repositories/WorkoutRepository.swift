import Foundation

// MARK: - Workout Repository Protocol
/// 定義訓練記錄數據存取介面
/// Domain Layer - 只定義介面，不涉及實作細節
protocol WorkoutRepository {

    // MARK: - Query

    /// 獲取指定日期範圍內的訓練記錄
    /// - Parameters:
    ///   - startDate: 開始日期
    ///   - endDate: 結束日期
    /// - Returns: 訓練記錄列表
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2]

    /// 獲取所有已載入的訓練記錄
    /// - Returns: 訓練記錄列表
    func getAllWorkouts() -> [WorkoutV2]

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
