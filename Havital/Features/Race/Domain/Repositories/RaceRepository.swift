import Foundation

// MARK: - RaceRepository Protocol
/// 賽事資料存取介面 - Domain Layer
/// 只定義介面，不涉及實作細節
protocol RaceRepository {

    /// 查詢賽事列表（支援篩選）
    /// - Parameters:
    ///   - region: 地區（tw 或 jp），nil 為全部
    ///   - distanceMin: 距離下限（km）
    ///   - distanceMax: 距離上限（km）
    ///   - dateFrom: 起始日期（YYYY-MM-DD），nil 預設為今天
    ///   - dateTo: 結束日期（YYYY-MM-DD）
    ///   - query: 賽事名稱關鍵字搜尋
    ///   - curatedOnly: 只回傳精選賽事
    ///   - limit: 每頁數量（1–200），nil 預設 50
    ///   - offset: 分頁偏移，nil 預設 0
    /// - Returns: 賽事列表
    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> [RaceEvent]
}
