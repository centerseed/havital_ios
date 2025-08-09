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
    func createWeeklySummary(weekNumber: Int? = nil) async throws -> WeeklyTrainingSummary {
        let path = weekNumber != nil ?
            "/summary/run_race/week/\(weekNumber!)" :
            "/summary/run_race/week"
        return try await makeAPICall(WeeklyTrainingSummary.self, path: path, method: .POST)
    }
    
    func getWeeklySummary(weekNumber: Int? = nil) async throws -> WeeklyTrainingSummary {
        let path = weekNumber != nil ?
            "/summary/run_race/week/\(weekNumber!)" :
            "/summary/run_race/week"
        return try await makeAPICall(WeeklyTrainingSummary.self, path: path, method: .GET)
    }
    
    // MARK: - GET 週訓練摘要列表
    /// 取得所有週訓練摘要列表 (GET)
    func fetchWeeklySummaries(weekNumber: Int? = nil) async throws -> [WeeklySummaryItem] {
        return try await makeAPICall([WeeklySummaryItem].self, path: "/summary/weekly/")
    }
}
