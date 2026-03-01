import Foundation

// MARK: - MonthlyStatsRepository Protocol
/// 月度運動統計 Repository 介面 - Domain Layer
/// 定義"做什麼"，不定義"怎麼做"
protocol MonthlyStatsRepository {

    /// 獲取指定月份的每日統計數據
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: 每日統計數據列表
    /// - Note: 如果該月已同步過（有時間戳），直接返回空數組，避免重複 API 調用
    func getMonthlyStats(year: Int, month: Int) async throws -> [DailyStat]

    /// 檢查指定月份是否已同步過
    /// - Parameters:
    ///   - year: 年份
    ///   - month: 月份 (1-12)
    /// - Returns: true 表示已同步，false 表示未同步
    func hasSyncedMonth(year: Int, month: Int) async -> Bool

    /// 清除所有月度統計緩存和時間戳（登出時調用）
    func clearCache() async
}
