//
//  ErrorHelpers.swift
//  Havital
//
//  Created by Claude on 2025-12-05.
//

import Foundation

/// 錯誤處理擴展工具
extension Error {
    /// 檢查錯誤是否為任務取消相關錯誤（不應該報告到 Cloud Logging）
    ///
    /// 涵蓋所有可能的取消錯誤類型：
    /// - Swift Concurrency 的 CancellationError
    /// - NSURLError 的 cancelled (-999)
    /// - URLError 的 .cancelled
    /// - SystemError.taskCancelled 和 SystemError.cancelled
    /// - HTTPError.cancelled
    /// - APIError (when isCancelled is true)
    /// - DomainError.cancellation
    var isCancellationError: Bool {
        // 1. Swift Concurrency CancellationError
        if self is CancellationError {
            return true
        }

        // 2. NSURLError cancelled
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        // 3. URLError.cancelled
        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        // 4. SystemError.taskCancelled and SystemError.cancelled
        if let systemError = self as? SystemError {
            switch systemError {
            case .taskCancelled, .cancelled:
                return true
            default:
                break
            }
        }

        // 5. HTTPError.cancelled
        if let httpError = self as? HTTPError, httpError.isCancelled {
            return true
        }

        // 6. APIError.isCancelled
        if let apiError = self as? APIError, apiError.isCancelled {
            return true
        }

        // 7. DomainError.cancellation
        if let domainError = self as? DomainError {
            if case .cancellation = domainError {
                return true
            }
        }

        return false
    }

    /// 檢查錯誤是否為瞬時網路錯誤（逾時 / 連線中斷 / 無網路）。
    ///
    /// 這類錯誤多半來自使用者端網路抖動（行動網路切換、前景/背景轉換等），
    /// 而非後端或 App 本身的缺陷——HTTPClient 已對其自動重試（見 `isRetryableURLError`）。
    /// 因此記錄到 Cloud Logging 時應降為 `.warn`，避免淹沒真正的 `.error`（例如 decode 失敗）。
    ///
    /// 涵蓋各層映射後的同義錯誤：
    /// - URLError：`.timedOut` / `.networkConnectionLost` / `.notConnectedToInternet`
    /// - HTTPError：`.timeout` / `.noConnection`（由 `mapURLErrorToHTTPError` 映射而來）
    /// - DomainError：`.timeout` / `.noConnection`（Repository 邊界映射而來）
    var isTransientNetworkError: Bool {
        // 1. URLError（原始網路層）
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                break
            }
        }

        // 2. HTTPError（HTTPClient 映射後）
        if let httpError = self as? HTTPError {
            switch httpError {
            case .timeout, .noConnection:
                return true
            default:
                break
            }
        }

        // 3. DomainError（Repository 邊界映射後）
        if let domainError = self as? DomainError {
            switch domainError {
            case .timeout, .noConnection:
                return true
            default:
                break
            }
        }

        return false
    }
}
