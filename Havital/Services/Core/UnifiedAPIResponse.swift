import Foundation

// MARK: - Unified API Response

/// 統一的 API 回應包裝器
struct UnifiedAPIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
    let error: APIErrorDetail?
    
    enum CodingKeys: String, CodingKey {
        case success, data, message, error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        data = try container.decodeIfPresent(T.self, forKey: .data)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        error = try container.decodeIfPresent(APIErrorDetail.self, forKey: .error)
    }
}

/// 簡化的 API 回應（向後兼容現有的 APIResponse）
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success, data, message
    }
}

// MARK: - API Error Detail

struct APIErrorDetail: Codable {
    let code: String
    let message: String
    let details: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case code, message, details
    }
}

// MARK: - Unified API Error System

/// 統一的 API 錯誤系統
enum APIError: Error {
    // HTTP 層錯誤
    case http(HTTPError)
    
    // 解析層錯誤  
    case parsing(ParseError)
    
    // 業務層錯誤
    case business(BusinessError)
    
    // 系統層錯誤
    case system(SystemError)
}

// MARK: - Business Errors

enum BusinessError: Error, LocalizedError {
    case notFound(String)
    case unauthorized(String)
    case forbidden(String)
    case validationFailed([String])
    case businessLogic(String, code: String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let resource):
            return "找不到資源: \(resource)"
        case .unauthorized(let message):
            return "未授權: \(message)"
        case .forbidden(let message):
            return "禁止訪問: \(message)"
        case .validationFailed(let errors):
            return "驗證失敗: \(errors.joined(separator: ", "))"
        case .businessLogic(let message, let code):
            return "業務邏輯錯誤 [\(code)]: \(message)"
        }
    }
}

// MARK: - System Errors

enum SystemError: Error, LocalizedError {
    case taskCancelled
    case configurationError(String)
    case storageError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .taskCancelled:
            return "任務已取消"
        case .configurationError(let message):
            return "配置錯誤: \(message)"
        case .storageError(let message):
            return "存儲錯誤: \(message)"
        case .unknownError(let message):
            return "未知錯誤: \(message)"
        }
    }
}

// MARK: - API Error Extensions

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .http(let httpError):
            return httpError.errorDescription
        case .parsing(let parseError):
            return parseError.errorDescription
        case .business(let businessError):
            return businessError.errorDescription
        case .system(let systemError):
            return systemError.errorDescription
        }
    }
    
    /// 判斷是否為取消錯誤
    var isCancelled: Bool {
        switch self {
        case .http(let httpError):
            return httpError.isCancelled
        case .system(.taskCancelled):
            return true
        default:
            return false
        }
    }
    
    /// 判斷是否為網路相關錯誤
    var isNetworkError: Bool {
        switch self {
        case .http(let httpError):
            return httpError.isNetworkError
        default:
            return false
        }
    }
    
    /// 判斷是否為可重試錯誤
    var isRetryable: Bool {
        switch self {
        case .http(let httpError):
            return httpError.isNetworkError
        case .system(.taskCancelled):
            return false
        default:
            return true
        }
    }
    
    /// 獲取錯誤代碼（用於分析）
    var errorCode: String {
        switch self {
        case .http(.noConnection):
            return "HTTP_NO_CONNECTION"
        case .http(.timeout):
            return "HTTP_TIMEOUT"
        case .http(.serverError(let code, _)):
            return "HTTP_SERVER_\(code)"
        case .parsing(.decodingFailed):
            return "PARSE_DECODING_FAILED"
        case .business(.notFound):
            return "BUSINESS_NOT_FOUND"
        case .business(.unauthorized):
            return "BUSINESS_UNAUTHORIZED"
        case .system(.taskCancelled):
            return "SYSTEM_TASK_CANCELLED"
        default:
            return "UNKNOWN"
        }
    }
}

// MARK: - Error Mapping Utilities

struct ErrorMapper {
    /// 將 HTTP 狀態碼映射到業務錯誤
    static func mapHTTPStatusToBusiness(_ statusCode: Int, message: String) -> BusinessError {
        switch statusCode {
        case 404:
            return .notFound(message)
        case 401:
            return .unauthorized(message)
        case 403:
            return .forbidden(message)
        case 422:
            // 嘗試解析驗證錯誤
            if let validationErrors = parseValidationErrors(message) {
                return .validationFailed(validationErrors)
            }
            return .businessLogic(message, code: "VALIDATION")
        default:
            return .businessLogic(message, code: "HTTP_\(statusCode)")
        }
    }
    
    /// 將標準錯誤轉換為系統錯誤
    static func mapToSystemError(_ error: Error) -> SystemError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return .taskCancelled
        }
        
        if error is CancellationError {
            return .taskCancelled
        }
        
        return .unknownError(error.localizedDescription)
    }
    
    private static func parseValidationErrors(_ message: String) -> [String]? {
        // 嘗試從錯誤訊息中提取驗證錯誤列表
        // 這裡可以根據後端 API 的實際格式進行調整
        if message.contains("validation") || message.contains("invalid") {
            return [message]
        }
        return nil
    }
}

// MARK: - Response Processing Utilities

struct ResponseProcessor {
    /// 處理統一 API 回應
    static func process<T: Codable>(
        _ response: UnifiedAPIResponse<T>,
        expecting type: T.Type
    ) throws -> T {
        
        // 檢查業務層成功標誌
        guard response.success else {
            if let error = response.error {
                throw APIError.business(.businessLogic(error.message, code: error.code))
            } else {
                throw APIError.business(.businessLogic(
                    response.message ?? "未知業務錯誤", 
                    code: "UNKNOWN"
                ))
            }
        }
        
        // 檢查數據是否存在
        guard let data = response.data else {
            throw APIError.business(.notFound("回應中缺少數據"))
        }
        
        return data
    }
    
    /// 處理簡單 API 回應（向後兼容）
    static func process<T: Codable>(
        _ response: APIResponse<T>
    ) throws -> T {
        guard response.success else {
            throw APIError.business(.businessLogic(
                response.message ?? "API 調用失敗", 
                code: "API_FAILURE"
            ))
        }
        
        return response.data
    }
    
    /// 嘗試從原始數據中提取結果
    static func extractData<T: Codable>(
        _ type: T.Type, 
        from rawData: Data, 
        using parser: APIParser
    ) throws -> T {
        
        Logger.debug("[ResponseProcessor] 開始提取數據，目標類型: \(String(describing: type))")
        Logger.debug("[ResponseProcessor] 原始響應數據預覽: \(String(data: rawData.prefix(200), encoding: .utf8) ?? "無法解析")...")
        
        // 嘗試解析為統一回應格式
        do {
            Logger.debug("[ResponseProcessor] 嘗試解析為 UnifiedAPIResponse<\(String(describing: type))>")
            let unifiedResponse = try parser.parse(UnifiedAPIResponse<T>.self, from: rawData)
            Logger.debug("[ResponseProcessor] 成功解析為統一格式，處理業務邏輯...")
            return try process(unifiedResponse, expecting: type)
        } catch {
            Logger.debug("[ResponseProcessor] 統一格式解析失敗: \(error.localizedDescription)")
            
            // 如果統一格式失敗，嘗試簡單格式
            do {
                Logger.debug("[ResponseProcessor] 嘗試解析為 APIResponse<\(String(describing: type))>")
                let simpleResponse = try parser.parse(APIResponse<T>.self, from: rawData)
                Logger.debug("[ResponseProcessor] 成功解析為簡單格式，處理業務邏輯...")
                return try process(simpleResponse)
            } catch {
                Logger.debug("[ResponseProcessor] 簡單格式解析失敗: \(error.localizedDescription)")
                
                // 最後嘗試直接解析
                Logger.debug("[ResponseProcessor] 嘗試直接解析為 \(String(describing: type))")
                let result = try parser.parse(T.self, from: rawData)
                Logger.debug("[ResponseProcessor] 直接解析成功")
                return result
            }
        }
    }
}