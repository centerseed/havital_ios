import Foundation

// MARK: - DeduplicatedAPIService Protocol
/// 提供 API 請求去重功能的協議
/// 防止同時發送多個相同的 API 請求
protocol DeduplicatedAPIService: AnyObject {
    /// 活動中的請求字典 (key -> Task)
    /// 使用 Any 類型擦除，實際存儲 Task<T, Error>
    var activeRequests: [String: Any] { get set }

    /// 請求隊列，用於線程安全的訪問 activeRequests
    var requestQueue: DispatchQueue { get }
}

// MARK: - Default Implementation
extension DeduplicatedAPIService {

    /// 生成請求的唯一標識符
    /// - Parameters:
    ///   - path: API 路徑
    ///   - method: HTTP 方法
    ///   - body: 請求體數據
    /// - Returns: 請求的唯一 key
    func generateRequestKey(path: String, method: HTTPMethod, body: Data?) -> String {
        var key = "\(method.rawValue):\(path)"
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            key += ":\(bodyString.prefix(100))" // 只取前 100 個字符避免 key 過長
        }
        return key
    }

    /// 去重的 API 調用
    /// 如果相同的請求正在進行中，則等待並返回相同的結果
    /// - Parameters:
    ///   - type: 期望的返回類型
    ///   - path: API 路徑
    ///   - method: HTTP 方法
    ///   - body: 請求體數據
    ///   - apiCall: 實際執行 API 調用的閉包
    /// - Returns: API 響應數據
    func makeDeduplicatedAPICall<T>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        apiCall: @escaping () async throws -> T
    ) async throws -> T {
        let key = generateRequestKey(path: path, method: method, body: body)

        // 使用類型擦除來存儲和檢索 Task
        let task: Task<T, Error> = await requestQueue.sync {
            // 檢查是否有相同的請求正在進行
            if let existingTask = activeRequests[key] as? Task<T, Error> {
                Logger.debug("[DeduplicatedAPI] Reusing existing request: \(key)")
                return existingTask
            }

            // 創建新的 Task
            let newTask = Task<T, Error> {
                defer {
                    // 請求完成後從 activeRequests 中移除
                    requestQueue.sync {
                        activeRequests.removeValue(forKey: key)
                    }
                }

                Logger.debug("[DeduplicatedAPI] Starting new request: \(key)")
                return try await apiCall()
            }

            // 儲存到 activeRequests (使用 Any 類型擦除)
            activeRequests[key] = newTask
            return newTask
        }

        return try await task.value
    }
}
