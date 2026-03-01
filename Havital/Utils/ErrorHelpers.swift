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
}
