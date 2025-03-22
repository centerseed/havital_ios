import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

class TrainingPlanService {
    static let shared = TrainingPlanService()
    private let baseURL = "https://api-service-364865009192.asia-east1.run.app"
    private init() {}
    
    private func makeRequest(path: String, method: String = "POST") async throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        
        // 設置更長的超時時間
        var request = URLRequest(url: url, timeoutInterval: 60) // 增加到 60 秒
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 使用與 NetworkService 相同的令牌獲取邏輯
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加授權令牌，長度: \(token.count)")
        } catch {
            print("獲取授權令牌失敗: \(error.localizedDescription)")
            throw error // 關鍵改變: 如果無法獲取令牌，則拋出錯誤而不是繼續
        }
        
        return request
    }
    
    func getTrainingPlanOverview() async throws -> TrainingPlanOverview {
        let request = try await makeRequest(path: "/plan/race_run/overview")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<TrainingPlanOverview>.self, from: data)
        TrainingPlanStorage.saveTrainingPlanOverview(apiResponse.data)
        return apiResponse.data
    }
    
    // 在 TrainingPlanService.swift 中修改解碼部分
    func getWeeklyPlan() async throws -> WeeklyPlan {
        let request = try await makeRequest(path: "/plan/race_run/weekly", method: "GET")
        print("取得週計畫： /plan/race_run/weekly")
        
        // 建立專用的URLSession配置，優化超時時間和請求設置
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 180 // 增加到180秒
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.httpMaximumConnectionsPerHost = 1 // 限制並發連接數
        let session = URLSession(configuration: configuration)
        
        // 實作重試機制
        let maxRetries = 3
        var currentRetry = 0
        var lastError: Error? = nil
        
        while currentRetry < maxRetries {
            do {
                // 使用withCheckedThrowingContinuation來處理取消
                let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                    let task = session.dataTask(with: request) { data, response, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        guard let data = data, let response = response else {
                            continuation.resume(throwing: URLError(.unknown))
                            return
                        }
                        continuation.resume(returning: (data, response))
                    }
                    task.resume()
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("Weekly Plan API 響應狀態碼: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("錯誤回應內容: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(APIResponse<WeeklyPlan>.self, from: data)
                let plan = apiResponse.data
                
                // 保存到本地存儲
                TrainingPlanStorage.saveWeeklyPlan(plan)
                return plan
                
            } catch {
                lastError = error
                currentRetry += 1
                
                // 檢查是否為取消錯誤
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        print("請求被取消，正在重試 (\(currentRetry)/\(maxRetries))")
                    case .timedOut:
                        print("請求超時，正在重試 (\(currentRetry)/\(maxRetries))")
                    default:
                        print("網路錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
                    }
                } else {
                    print("未知錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
                }
                
                if currentRetry < maxRetries {
                    // 使用指數退避策略
                    let delay = Double(pow(2.0, Double(currentRetry))) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 如果所有重試都失敗，拋出最後一個錯誤
        throw lastError ?? URLError(.unknown)
    }
    
    func createWeeklyPlan(targetWeek: Int? = nil) async throws -> WeeklyPlan {
        var request = try await makeRequest(path: "/plan/race_run/weekly", method: "POST")
            
            // 如果指定了目標週數，將其添加到請求體中
            if let targetWeek = targetWeek {
                let requestBody: [String: Any] = ["week_of_training": targetWeek]
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                print("正在產生第 \(targetWeek) 週的訓練計劃")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("錯誤回應內容: \(responseString)")
                }
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            
            // Debug: Print the JSON string to see its structure
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Received JSON: \(jsonString)")
            }
            
            do {
                let plan = try decoder.decode(WeeklyPlan.self, from: data)
                TrainingPlanStorage.saveWeeklyPlan(plan)
                return plan
            } catch {
                print("Decoding error: \(error)")
                throw error
            }
        }
}
