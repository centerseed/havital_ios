import Foundation

// MARK: - 統一領域錯誤
/// 所有層級的錯誤最終轉換為 DomainError，供 UI 層使用
enum DomainError: Error, Equatable, LocalizedError {

    // MARK: - 網路相關
    case networkFailure(String)
    case timeout
    case noConnection

    // MARK: - 伺服器相關
    case serverError(Int, String)
    case badRequest(String)
    case notFound(String)

    // MARK: - 認證相關
    case unauthorized
    case forbidden

    // MARK: - 業務邏輯
    case validationFailure(String)
    case dataCorruption(String)

    // MARK: - 訂閱相關
    case subscriptionRequired    // 403 + subscription_required（一般過期）
    case trialExpired            // 403 + subscription_required（試用期到期）
    case rizoQuotaExceeded       // 429 + rizo_quota_exceeded

    // MARK: - 取消（不應顯示 ErrorView）
    case cancellation

    // MARK: - 未知
    case unknown(String)

    // MARK: - LocalizedError
    var errorDescription: String? {
        switch self {
        case .networkFailure(let message):
            return NSLocalizedString("error.network_failure", comment: "") + ": \(message)"
        case .timeout:
            return NSLocalizedString("error.timeout", comment: "Request timed out")
        case .noConnection:
            return NSLocalizedString("error.no_connection", comment: "No internet connection")
        case .serverError(let code, let message):
            return NSLocalizedString("error.server_error", comment: "") + " (\(code)): \(message)"
        case .badRequest(let message):
            return NSLocalizedString("error.bad_request", comment: "") + ": \(message)"
        case .notFound(let message):
            return NSLocalizedString("error.not_found", comment: "") + ": \(message)"
        case .unauthorized:
            return NSLocalizedString("error.unauthorized", comment: "Please sign in again")
        case .forbidden:
            return NSLocalizedString("error.forbidden", comment: "Access denied")
        case .validationFailure(let message):
            return message
        case .dataCorruption(let message):
            return NSLocalizedString("error.data_corruption", comment: "") + ": \(message)"
        case .subscriptionRequired:
            return NSLocalizedString("error.subscription_required", comment: "Subscription required")
        case .trialExpired:
            return NSLocalizedString("error.trial_expired", comment: "Trial period has ended")
        case .rizoQuotaExceeded:
            return NSLocalizedString("error.rizo_quota_exceeded", comment: "Rizo quota exceeded")
        case .cancellation:
            return nil // 取消不需要顯示
        case .unknown(let message):
            return message
        }
    }

    // MARK: - 用戶友好訊息
    var userFriendlyMessage: String {
        switch self {
        case .networkFailure, .timeout, .noConnection:
            return NSLocalizedString("error.check_connection", comment: "Please check your internet connection and try again")
        case .serverError:
            return NSLocalizedString("error.server_issue", comment: "Server is having issues. Please try again later")
        case .unauthorized:
            return NSLocalizedString("error.session_expired", comment: "Your session has expired. Please sign in again")
        case .forbidden:
            return NSLocalizedString("error.no_permission", comment: "You don't have permission to perform this action")
        case .notFound:
            return NSLocalizedString("error.resource_not_found", comment: "The requested resource was not found")
        case .cancellation:
            return ""
        default:
            return errorDescription ?? NSLocalizedString("error.unknown", comment: "An unexpected error occurred")
        }
    }

    // MARK: - 是否可重試
    var isRetryable: Bool {
        switch self {
        case .networkFailure, .timeout, .noConnection, .serverError:
            return true
        case .unauthorized, .forbidden, .badRequest, .notFound, .validationFailure, .dataCorruption:
            return false
        case .subscriptionRequired, .trialExpired, .rizoQuotaExceeded:
            return false
        case .cancellation:
            return false
        case .unknown:
            return true
        }
    }

    // MARK: - 是否應該顯示 ErrorView
    var shouldShowErrorView: Bool {
        switch self {
        case .cancellation, .subscriptionRequired, .trialExpired, .rizoQuotaExceeded, .forbidden:
            return false
        default:
            return true
        }
    }
}

// MARK: - Error 轉換擴展
extension Error {

    /// 將任意 Error 轉換為 DomainError
    func toDomainError() -> DomainError {
        // 已經是 DomainError
        if let domainError = self as? DomainError {
            return domainError
        }

        // HTTPError 轉換
        if let httpError = self as? HTTPError {
            return httpError.toDomainError()
        }

        // ParseError 轉換（API decode/schema mismatch）
        if let parseError = self as? ParseError {
            switch parseError {
            case .decodingFailed(let detail):
                let field = detail.missingField ?? "unknown"
                return .dataCorruption("decode_failed(type=\(detail.expectedType), field=\(field), path=\(detail.codingPath))")
            case .fallbackFailed(let message):
                return .dataCorruption("fallback_failed(\(message))")
            case .invalidData(let message):
                return .dataCorruption(message)
            }
        }

        // 直接 DecodingError（未包成 ParseError 的情況）
        if self is DecodingError {
            return .dataCorruption(localizedDescription)
        }

        // URLError 轉換
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noConnection
            case .timedOut:
                return .timeout
            case .cancelled:
                return .cancellation
            default:
                return .networkFailure(urlError.localizedDescription)
            }
        }

        // 統一取消錯誤檢查（涵蓋 CancellationError, NSURLErrorCancelled,
        // SystemError.taskCancelled, HTTPError.cancelled, APIError 等所有類型）
        if self.isCancellationError {
            return .cancellation
        }

        // 其他錯誤
        return .unknown(localizedDescription)
    }
}

// MARK: - HTTPError 轉換
extension HTTPError {

    func toDomainError() -> DomainError {
        switch self {
        case .invalidURL(let url):
            return .validationFailure("Invalid URL: \(url)")
        case .noConnection:
            return .noConnection
        case .timeout:
            return .timeout
        case .cancelled:
            return .cancellation
        case .badRequest(let message):
            return .badRequest(message)
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .subscriptionRequired:
            return .subscriptionRequired
        case .rizoQuotaExceeded:
            return .rizoQuotaExceeded
        case .notFound(let message):
            return .notFound(message)
        case .httpError(let code, let message):
            return .serverError(code, message)
        case .serverError(let code, let message):
            return .serverError(code, message)
        case .networkError(let message):
            return .networkFailure(message)
        case .invalidResponse(let message):
            return .dataCorruption(message)
        }
    }
}
