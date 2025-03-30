import Foundation
import Combine

class WeeklySummaryService {
    static let shared = WeeklySummaryService()
    
    private init() {}
    
    func fetchWeeklySummary(weekNumber: Int? = nil) async throws -> WeeklyTrainingSummary {
        // 構建 API URL
        var urlString = "https://api-service-364865009192.asia-east1.run.app/summary/run_race/week"
        if let weekNumber = weekNumber {
            urlString += "/\(weekNumber)"
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // 創建請求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加授權令牌
        if let token = try? await AuthenticationService.shared.getIdToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw NSError(domain: "WeeklySummaryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "未授權，無法獲取令牌"])
        }
        
        // 發送請求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 檢查響應狀態
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("API 錯誤響應: \(responseString)")
            }
            throw NSError(domain: "WeeklySummaryService", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                          userInfo: [NSLocalizedDescriptionKey: "獲取訓練回顧失敗"])
        }
        
        // 解析數據
        do {
            let summaryResponse = try JSONDecoder().decode(WeeklySummaryResponse.self, from: data)
            return summaryResponse.data
        } catch {
            print("解析週訓練回顧時出錯: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("API 響應內容: \(responseString)")
            }
            throw error
        }
    }
}
