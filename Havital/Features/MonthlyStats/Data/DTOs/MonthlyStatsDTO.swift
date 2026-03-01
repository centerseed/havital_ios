import Foundation

// MARK: - Monthly Stats DTO
/// 月度運動統計 API 響應 - Data Layer
/// 與 API JSON 結構一一對應，使用 snake_case 命名
struct MonthlyStatsDTO: Codable {

    // MARK: - Properties

    let success: Bool
    let message: String?
    let data: MonthlyStatsDataDTO

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }
}

// MARK: - Monthly Stats Data DTO
struct MonthlyStatsDataDTO: Codable {

    // MARK: - Properties

    let year: Int
    let month: Int
    let timezone: String
    let dailyStats: [DailyStatsDTO]
    let monthlySummary: MonthlySummaryDTO

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case year
        case month
        case timezone
        case dailyStats = "daily_stats"
        case monthlySummary = "monthly_summary"
    }
}

// MARK: - Daily Stats DTO
struct DailyStatsDTO: Codable {

    // MARK: - Properties

    /// 日期字串（格式：yyyy-MM-dd）
    let date: String

    /// 該日總里程（公里）
    let totalDistanceKm: Double

    /// 加權平均配速（秒/公里），nil 表示無有效數據
    let avgPacePerKm: Int?

    /// 該日運動次數
    let workoutCount: Int

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case date
        case totalDistanceKm = "total_distance_km"
        case avgPacePerKm = "avg_pace_per_km"
        case workoutCount = "workout_count"
    }
}

// MARK: - Monthly Summary DTO
struct MonthlySummaryDTO: Codable {

    // MARK: - Properties

    /// 整月總里程（公里）
    let totalDistanceKm: Double

    /// 整月總運動次數
    let totalWorkouts: Int

    /// 有運動的天數
    let daysWithWorkouts: Int

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case totalDistanceKm = "total_distance_km"
        case totalWorkouts = "total_workouts"
        case daysWithWorkouts = "days_with_workouts"
    }
}
