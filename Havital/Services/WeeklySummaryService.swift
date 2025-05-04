import Foundation

class WeeklySummaryService {
    static let shared = WeeklySummaryService()
    
    private init() {}
    
    // MARK: - POST 週訓練回顧
    /// 建立或取得單週訓練摘要 (POST)
    func createWeeklySummary(weekNumber: Int? = nil) async throws -> WeeklyTrainingSummary {
        // 使用 APIClient 請求週訓練回顧
        let path = weekNumber != nil ?
            "/summary/run_race/week/\(weekNumber!)" :
            "/summary/run_race/week"
        return try await APIClient.shared.request(WeeklyTrainingSummary.self,
            path: path, method: "POST")
    }
    
    func getWeeklySummary(weekNumber: Int? = nil) async throws -> WeeklyTrainingSummary {
        // 使用 APIClient 請求週訓練回顧
        let path = weekNumber != nil ?
            "/summary/run_race/week/\(weekNumber!)" :
            "/summary/run_race/week"
        return try await APIClient.shared.request(WeeklyTrainingSummary.self,
            path: path, method: "GET")
    }
    
    // MARK: - GET 週訓練摘要列表
    /// 取得所有週訓練摘要列表 (GET)
    func fetchWeeklySummaries(weekNumber: Int? = nil) async throws -> [WeeklySummaryItem] {
        return try await APIClient.shared.request([WeeklySummaryItem].self,
                                                  path: "/summary/weekly/",
                                                  method: "GET")
    }
}
