import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

class TrainingPlanService {
    static let shared = TrainingPlanService()
    private let baseURL = "https://api-service-364865009192.asia-east1.run.app"
    private init() {}
    
    // 日誌統一入口，便於 Xcode 過濾
    private func log(_ message: String) {
        print("[TrainingPlanService] \(message)")
    }
    
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
    
    // 新增的 postTrainingPlanOverview 方法
    func postTrainingPlanOverview() async throws -> TrainingPlanOverview {
        let request = try await makeRequest(path: "/plan/race_run/overview", method: "POST")
        print("生成訓練計劃概覽： /plan/race_run/overview")
        
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
                
                print("生成訓練計劃概覽 API 響應狀態碼: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("錯誤回應內容: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(APIResponse<TrainingPlanOverview>.self, from: data)
                
                // 保存到本地存儲
                TrainingPlanStorage.saveTrainingPlanOverview(apiResponse.data)
                
                print("成功生成訓練計劃概覽")
                return apiResponse.data
                
            } catch {
                lastError = error
                currentRetry += 1
                
                // 檢查是否為取消錯誤
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        print("訓練概覽請求被取消，正在重試 (\(currentRetry)/\(maxRetries))")
                    case .timedOut:
                        print("訓練概覽請求超時，正在重試 (\(currentRetry)/\(maxRetries))")
                    default:
                        print("訓練概覽網路錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
                    }
                } else {
                    print("訓練概覽未知錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
                }
                
                if currentRetry < maxRetries {
                    // the exponential backoff strategy - 指數退避策略
                    let delay = Double(pow(2.0, Double(currentRetry))) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 如果所有重試都失敗，拋出最後一個錯誤
        throw lastError ?? URLError(.unknown)
    }
    
    // 在TrainingPlanService.swift中添加這個方法

    func updateTrainingPlanOverview(overviewId: String) async throws -> TrainingPlanOverview {
        // 確保路徑包含overview_id
        let path = "/plan/race_run/overview/\(overviewId)"
        print("更新訓練計劃概覽： \(path)")
        
        // 創建PUT請求
        var request = try await makeRequest(path: path, method: "PUT")
        
        
        // 再次確認內容類型
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
                
                print("更新訓練計劃概覽 API 響應狀態碼: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("錯誤回應內容: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(APIResponse<TrainingPlanOverview>.self, from: data)
                
                // 保存到本地存儲
                TrainingPlanStorage.saveTrainingPlanOverview(apiResponse.data)
                
                print("成功更新訓練計劃概覽")
                return apiResponse.data
                
            } catch {
                lastError = error
                currentRetry += 1
                
                // 檢查是否為取消錯誤
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        print("更新訓練概覽請求被取消，正在重試 (\(currentRetry)/\(maxRetries))")
                    case .timedOut:
                        print("更新訓練概覽請求超時，正在重試 (\(currentRetry)/\(maxRetries))")
                    default:
                        print("更新訓練概覽網路錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
                    }
                } else {
                    print("更新訓練概覽未知錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
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
    
    // 修改後的 getTrainingPlanOverview 方法
    func getTrainingPlanOverview() async throws -> TrainingPlanOverview {
        let request = try await makeRequest(path: "/plan/race_run/overview", method: "GET")
        print("取得訓練計劃概覽： /plan/race_run/overview")
        
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
                
                print("訓練計劃概覽 API 響應狀態碼: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("錯誤回應內容: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(APIResponse<TrainingPlanOverview>.self, from: data)
                
                // 保存到本地存儲
                TrainingPlanStorage.saveTrainingPlanOverview(apiResponse.data)
                
                print("成功取得訓練計劃概覽")
                return apiResponse.data
                
            } catch {
                lastError = error
                currentRetry += 1
                
                // 檢查是否為取消錯誤
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        print("訓練概覽請求被取消，正在重試 (\(currentRetry)/\(maxRetries))")
                    case .timedOut:
                        print("訓練概覽請求超時，正在重試 (\(currentRetry)/\(maxRetries))")
                    default:
                        print("訓練概覽網路錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
                    }
                } else {
                    print("訓練概覽未知錯誤，正在重試 (\(currentRetry)/\(maxRetries)): \(error.localizedDescription)")
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
    
    // 在 TrainingPlanService.swift 中修改解碼部分
    // path: /plan/race_run/weekly
    // caller: 來源方法名稱，用於追蹤調用者
    func getWeeklyPlan(caller: String = #function) async throws -> WeeklyPlan {
        log("getWeeklyPlan start: /plan/race_run/weekly from [\(caller)]")
        let request = try await makeRequest(path: "/plan/race_run/weekly", method: "GET")
        
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
                
                log("getWeeklyPlan statusCode: \(httpResponse.statusCode)")
                
                
                guard httpResponse.statusCode == 200 else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        log("getWeeklyPlan error response: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                //log("getWeeklyPlan: \(String(data: data, encoding: .utf8))")
                
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
                        log("getWeeklyPlan retry \(currentRetry)/\(maxRetries) cancelled")
                    case .timedOut:
                        log("getWeeklyPlan retry \(currentRetry)/\(maxRetries) timed out")
                    default:
                        log("getWeeklyPlan retry \(currentRetry)/\(maxRetries): \(error.localizedDescription)")
                    }
                } else {
                    log("getWeeklyPlan retry \(currentRetry)/\(maxRetries) unknown error: \(error.localizedDescription)")
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
        print("=== createWeeklyPlan 開始，目標週數：\(String(describing: targetWeek)) ===")
        
        // 構建請求路徑和參數
        let path = "/plan/race_run/weekly"
        
        // 準備請求體
        var requestBody: [String: Any]? = nil
        if let targetWeek = targetWeek {
            requestBody = ["week_of_training": targetWeek]
            print("設置請求體: week_of_training = \(targetWeek)")
        }
        
        // 使用請求體創建請求
        var request = try await makeRequest(path: path, method: "POST")
        
        // 明確設置請求體和Content-Type
        if let requestBody = requestBody {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("JSON請求體: \(jsonString)")
            }
        } else {
            print("未設置請求體，使用後端默認值")
        }
        
        // 檢查最終請求
        print("最終請求路徑: \(request.url?.absoluteString ?? "unknown")")
        print("請求方法: \(request.httpMethod ?? "unknown")")
        print("請求頭: \(request.allHTTPHeaderFields ?? [:])")
        if let httpBody = request.httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
            print("請求體: \(bodyString)")
        } else {
            print("請求體: nil")
        }
        
        // 使用與其他方法相同的優化配置
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration)
        
        // 簡化的請求發送，暫時不使用重試機制以便調試
        print("開始發送請求...")
        let (data, response) = try await session.data(for: request)
        
        print("收到響應，狀態碼: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("響應內容: \(responseString.prefix(200))...")
        }
        
        // 解析和處理響應
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<WeeklyPlan>.self, from: data)
        let plan = apiResponse.data
        
        // 保存到本地存儲
        TrainingPlanStorage.saveWeeklyPlan(plan)
        print("成功產生第 \(plan.weekOfPlan) 週的訓練計劃")
        
        // 記錄最後更新時間
        UserDefaults.standard.set(Date(), forKey: "last_weekly_plan_update")
        
        return plan
    }
    
}
