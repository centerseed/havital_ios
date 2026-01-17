import Foundation

// MARK: - MonthlyStats Remote Data Source
/// 月度統計 Remote Data Source - Data Layer
/// 負責從遠端 API 獲取月度統計數據
final class MonthlyStatsRemoteDataSource {

    // MARK: - Properties

    private let httpClient: any HTTPClient
    private let parser: any APIParser

    // MARK: - Initialization

    init(httpClient: any HTTPClient = DefaultHTTPClient.shared,
         parser: any APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
        Logger.debug("[MonthlyStatsRemoteDataSource] 初始化完成")
    }

    // MARK: - API Methods

    /// 獲取指定月份的運動統計數據
    /// - Parameters:
    ///   - year: 年份 (1900-2100)
    ///   - month: 月份 (1-12)
    /// - Returns: 月度統計 DTO
    /// - Throws: API 錯誤或網路錯誤
    func fetchMonthlyStats(year: Int, month: Int) async throws -> MonthlyStatsDTO {
        // ✅ 驗證參數範圍
        guard (1...12).contains(month) else {
            Logger.error("[MonthlyStatsRemoteDataSource] Invalid month: \(month)")
            throw DomainError.validationFailure("Month must be between 1-12")
        }

        guard (1900...2100).contains(year) else {
            Logger.error("[MonthlyStatsRemoteDataSource] Invalid year: \(year)")
            throw DomainError.validationFailure("Year must be between 1900-2100")
        }

        // 構建查詢參數
        let queryItems = [
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "month", value: "\(month)"),
            URLQueryItem(name: "activity_type", value: "running")
        ]

        let path = URLBuilderHelper.buildPath("/v2/workout/monthly_stats", queryItems: queryItems)

        Logger.debug("[MonthlyStatsRemoteDataSource] fetchMonthlyStats - year: \(year), month: \(month)")

        // 調用 API
        let rawData = try await httpClient.request(path: path, method: .GET, body: nil)

        // 解析響應
        let response = try parser.parse(MonthlyStatsDTO.self, from: rawData)

        // 驗證響應成功
        guard response.success else {
            let errorMessage = response.message ?? "Unknown error"
            Logger.error("[MonthlyStatsRemoteDataSource] API 返回失敗: \(errorMessage)")
            throw DomainError.badRequest(errorMessage)
        }

        Logger.debug("[MonthlyStatsRemoteDataSource] 成功獲取月度數據，數量: \(response.data.dailyStats.count)")
        return response
    }
}
