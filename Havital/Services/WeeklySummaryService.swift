import Foundation

class WeeklySummaryService {
    static let shared = WeeklySummaryService()
    
    private init() {}
    
    func fetchWeeklySummary(weekNumber: Int? = nil) async throws -> WeeklyTrainingSummary {
        // 使用 APIClient 請求週訓練回顧
        let path = weekNumber != nil ?
            "/summary/run_race/week/\(weekNumber!)" :
            "/summary/run_race/week"
        return try await APIClient.shared.request(WeeklyTrainingSummary.self,
            path: path, method: "POST")
    }
    
    /// 取得所有週訓練摘要列表
    func fetchWeeklySummaries() async throws -> [WeeklySummaryItem] {
        return try await APIClient.shared.request([WeeklySummaryItem].self,
                                                  path: "/summary/weekly/",
                                                  method: "GET")
    }
}
