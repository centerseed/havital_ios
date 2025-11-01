import Foundation

class WeeklySummaryService {
    static let shared = WeeklySummaryService()
    
    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser
    
    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }
    
    // MARK: - Unified API Call Method
    
    /// 統一的 API 調用方法
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }
    
    // MARK: - POST 週訓練回顧
    /// 建立或取得單週訓練摘要 (POST)
    func createWeeklySummary(weekNumber: Int? = nil, forceUpdate: Bool = false) async throws -> WeeklyTrainingSummary {
        let path = weekNumber != nil ?
            "/summary/run_race/week/\(weekNumber!)" :
            "/summary/run_race/week"

        var body: Data? = nil
        if forceUpdate {
            let request = CreateWeeklySummaryRequest(forceUpdate: true)
            body = try JSONEncoder().encode(request)
        }

        return try await makeAPICall(WeeklyTrainingSummary.self, path: path, method: .POST, body: body)
    }
    
    func getWeeklySummary(weekNumber: Int? = nil) async throws -> WeeklyTrainingSummary {
        let path = weekNumber != nil ?
            "/summary/run_race/week/\(weekNumber!)" :
            "/summary/run_race/week"
        return try await makeAPICall(WeeklyTrainingSummary.self, path: path, method: .GET)
    }
    
    // MARK: - GET 週訓練摘要列表
    /// 取得所有週訓練摘要列表 (GET) - 僅當前訓練計劃
    func fetchWeeklySummaries(weekNumber: Int? = nil) async throws -> [WeeklySummaryItem] {
        return try await makeAPICall([WeeklySummaryItem].self, path: "/summary/weekly/")
    }

    /// 取得所有歷史週跑量數據 (GET) - 不限訓練計劃
    /// - Parameter limit: 限制返回的週數，預設為 8 週
    func fetchAllWeeklyVolumes(limit: Int = 8) async throws -> [WeeklySummaryItem] {
        return try await makeAPICall([WeeklySummaryItem].self, path: "/summary/weekly/all/?limit=\(limit)")
    }

    // MARK: - PUT 更新調整建議
    /// 更新週訓練回顧的調整建議 (PUT)
    func updateAdjustments(summaryId: String, items: [AdjustmentItem]) async throws -> UpdateAdjustmentsResponse {
        let requestBody = UpdateAdjustmentsRequest(items: items)
        let jsonData = try JSONEncoder().encode(requestBody)
        let path = "/summary/\(summaryId)/adjustments"
        return try await makeAPICall(UpdateAdjustmentsResponse.self, path: path, method: .PUT, body: jsonData)
    }
}
