import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

class TrainingPlanService {
    static let shared = TrainingPlanService()
    private init() {}
    
    // 公用 URLSession, timeout & background config
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
    }()

    // 日誌統一入口，便於 Xcode 過濾
    private func log(_ message: String) {
        print("[TrainingPlanService] \(message)")
    }
    
    // 建立授權 & 基本 request
    private func makeRequest(path: String, method: String = "GET") async throws -> URLRequest {
        let urlString = APIConfig.baseURL + path
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 使用與 NetworkService 相同的令牌獲取邏輯
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            log("成功添加授權令牌，長度: \(token.count)")
        } catch {
            log("獲取授權令牌失敗: \(error.localizedDescription)")
            throw error // 關鍵改變: 如果無法獲取令牌，則拋出錯誤而不是繼續
        }
        
        return req
    }
    
    // 通用網路請求 & 解析, 自動重試
    private func send<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        var request = try await makeRequest(path: path, method: method)
        if let body = body { request.httpBody = body }
        let maxRetries = 3
        let decoder = JSONDecoder()
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                log("開始發送網路請求: \(method) \(path)")
                let (data, resp) = try await URLSession.shared.data(for: request)
                log("完成網路請求: \(method) \(path)")
                // 打印 HTTP 狀態碼
                if let http = resp as? HTTPURLResponse {
                    log("\(method) \(path) status code: \(http.statusCode)")
                    guard http.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                }
                let api: APIResponse<T> = try decoder.decode(APIResponse<T>.self, from: data)
                return api.data
            } catch {
                lastError = error
                log("Request failed (\(attempt)/\(maxRetries)): \(error.localizedDescription)")
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
    
    // 無回傳的通用 DELETE 請求
    private func sendNoResponse(path: String, method: String = "DELETE") async throws {
        let request = try await makeRequest(path: path, method: method)
        log("開始發送網路請求 (無回應): \(method) \(path)")
        let (_, resp) = try await URLSession.shared.data(for: request)
        log("完成網路請求 (無回應): \(method) \(path)")
        // 打印 HTTP 狀態碼
        if let http = resp as? HTTPURLResponse {
            log("\(method) \(path) status code: \(http.statusCode)")
            guard http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        }
    }
    
    // 精簡後的 postTrainingPlanOverview
    func postTrainingPlanOverview() async throws -> TrainingPlanOverview {
        let overview: TrainingPlanOverview = try await send(path: "/plan/race_run/overview", method: "POST")
        TrainingPlanStorage.saveTrainingPlanOverview(overview)
        return overview
    }
    
    // 精簡後的 updateTrainingPlanOverview
    func updateTrainingPlanOverview(overviewId: String) async throws -> TrainingPlanOverview {
        let path = "/plan/race_run/overview/\(overviewId)"
        let overview: TrainingPlanOverview = try await send(path: path, method: "PUT")
        TrainingPlanStorage.saveTrainingPlanOverview(overview)
        return overview
    }
    
    // MARK: - Modifications APIs
    /// 取得修改描述
    func getModificationsDescription() async throws -> String {
        let desc: String = try await send(path: "/plan/modifications/description", method: "GET")
        return desc
    }

    /// 列出所有修改
    func getModifications() async throws -> [Modification] {
        let mods: [Modification] = try await send(path: "/plan/modifications", method: "GET")
        return mods
    }

    /// 新增修改
    func createModification(_ newMod: NewModification) async throws -> Modification {
        let body = try JSONEncoder().encode(newMod)
        let mod: Modification = try await send(path: "/plan/modifications", method: "POST", body: body)
        return mod
    }

    /// 更新多筆修改
    func updateModifications(_ mods: [Modification]) async throws -> [Modification] {
        let payload = ModificationsUpdateRequest(modifications: mods)
        let updated: [Modification] = try await send(path: "/plan/modifications", method: "PUT", body: try JSONEncoder().encode(payload))
        return updated
    }

    /// 清空所有修改
    func clearModifications() async throws {
        try await sendNoResponse(path: "/plan/modifications", method: "DELETE")
    }
    
    // 修改後的 getTrainingPlanOverview 方法
    func getTrainingPlanOverview() async throws -> TrainingPlanOverview {
        log("取得訓練計劃概覽")
        let overview: TrainingPlanOverview = try await send(path: "/plan/race_run/overview", method: "GET")
        TrainingPlanStorage.saveTrainingPlanOverview(overview)
        return overview
    }
    
    // 在 TrainingPlanService.swift 中修改解碼部分
    // path: /plan/race_run/weekly
    // caller: 來源方法名稱，用於追蹤調用者
    func getWeeklyPlan(caller: String = #function) async throws -> WeeklyPlan {
        log("getWeeklyPlan start from [\(caller)]")
        let plan: WeeklyPlan = try await send(path: "/plan/race_run/weekly", method: "GET")
        TrainingPlanStorage.saveWeeklyPlan(plan)
        return plan
    }
    
    /// 根據 planId 獲取已存在的週計畫
    func getWeeklyPlanById(planId: String) async throws -> WeeklyPlan {
        let path = "/plan/race_run/weekly/\(planId)"
        let request = try await makeRequest(path: path, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // 若無此週計畫
        if http.statusCode == 404 {
            throw WeeklyPlanError.notFound
        }
        guard http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<WeeklyPlan>.self, from: data)
        let plan = apiResponse.data
        // 更新本地存儲
        TrainingPlanStorage.saveWeeklyPlan(plan)
        log("成功讀取週計畫 \(planId)")
        return plan
    }

    func createWeeklyPlan(targetWeek: Int? = nil) async throws -> WeeklyPlan {
        log("=== createWeeklyPlan 開始，目標週數：\(String(describing: targetWeek)) ===")
        
        // 構建請求路徑和參數
        let path = "/plan/race_run/weekly"
        
        // 準備請求體
        var requestBody: [String: Any]? = nil
        if let targetWeek = targetWeek {
            requestBody = ["week_of_training": targetWeek]
            log("設置請求體: week_of_training = \(targetWeek)")
        }
        
        // 使用請求體創建請求
        var request = try await makeRequest(path: path, method: "POST")
        
        // 明確設置請求體和Content-Type
        if let requestBody = requestBody {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                log("JSON請求體: \(jsonString)")
            }
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
            log("響應內容: \(responseString.prefix(200))...")
        }
        
        // 解析和處理響應
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<WeeklyPlan>.self, from: data)
        let plan = apiResponse.data
        
        // 保存到本地存儲
        TrainingPlanStorage.saveWeeklyPlan(plan)
        log("成功產生第 \(plan.weekOfPlan) 週的訓練計劃")
        
        // 記錄最後更新時間
        UserDefaults.standard.set(Date(), forKey: "last_weekly_plan_update")
        
        return plan
    }
    
    // 週計畫查詢錯誤
    enum WeeklyPlanError: Error {
        /// 指定週計畫不存在
        case notFound
    }
    
}
