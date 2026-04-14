//
//  APICallHelper.swift
//  Havital
//
//  Created by Claude on 2025-12-12.
//

import Foundation

// MARK: - APICallHelper

/// Unified API call helper that standardizes API calls across Services and DataSources.
///
/// This helper consolidates the duplicate `makeAPICall` patterns found across:
/// - Services (GarminService, StravaService, FeedbackService, etc.)
/// - DataSources (TargetRemoteDataSource, UserProfileRemoteDataSource, etc.)
///
/// **Key Features**:
/// 1. Unified error handling with automatic cancellation detection
/// 2. Standardized logging format
/// 3. Automatic response processing via `ResponseProcessor`
/// 4. DomainError conversion for consistent error handling
///
/// **Usage**:
/// ```swift
/// class MyDataSource {
///     private let apiHelper: APICallHelper
///
///     init(httpClient: HTTPClient = DefaultHTTPClient.shared,
///          parser: APIParser = DefaultAPIParser.shared) {
///         self.apiHelper = APICallHelper(httpClient: httpClient, parser: parser)
///     }
///
///     func fetchData() async throws -> MyModel {
///         return try await apiHelper.call(
///             MyModel.self,
///             path: "/api/data",
///             method: .GET
///         )
///     }
/// }
/// ```
struct APICallHelper {

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let parser: APIParser
    private let moduleName: String

    // MARK: - Initialization

    /// Initialize with dependencies
    /// - Parameters:
    ///   - httpClient: HTTP client for network requests
    ///   - parser: API parser for JSON decoding
    ///   - moduleName: Module name for logging (e.g., "TargetRemoteDS", "GarminService")
    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared,
        moduleName: String = "APICallHelper"
    ) {
        self.httpClient = httpClient
        self.parser = parser
        self.moduleName = moduleName
    }

    // MARK: - API Call Methods

    /// Make an API call and return parsed response
    ///
    /// This method handles:
    /// 1. HTTP request via HTTPClient
    /// 2. Response parsing via ResponseProcessor
    /// 3. Unified cancellation detection (without type re-wrapping)
    /// 4. Logging for debugging
    ///
    /// - Parameters:
    ///   - type: Expected response type (must be Codable)
    ///   - path: API endpoint path
    ///   - method: HTTP method (defaults to GET)
    ///   - body: Request body data (optional)
    /// - Returns: Parsed response of type T
    /// - Throws: Original error from lower layers
    func call<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch {
            throw handleError(error, path: path, method: method)
        }
    }

    /// Make an API call without expecting a response body
    ///
    /// Use this for DELETE, PUT, or POST operations that don't return data.
    ///
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - method: HTTP method (defaults to DELETE)
    ///   - body: Request body data (optional)
    /// - Throws: Original error from lower layers
    func callNoResponse(
        path: String,
        method: HTTPMethod = .DELETE,
        body: Data? = nil
    ) async throws {
        do {
            _ = try await httpClient.request(path: path, method: method, body: body)
        } catch {
            throw handleError(error, path: path, method: method)
        }
    }

    // MARK: - Error Handling

    /// Handle API errors with unified logic
    ///
    /// This method centralizes the cancellation detection logic that was
    /// previously duplicated across 30+ files.
    ///
    /// - Parameter error: The original error
    /// - Returns: Original error (type preserved)
    private func handleError(_ error: Error, path: String, method: HTTPMethod) -> Error {
        if let parseError = error as? ParseError {
            reportDecodeIssue(parseError, path: path, method: method)
        }
        if error.isCancellationError {
            Logger.debug("[\(moduleName)] Task cancelled, preserving original error type")
        }
        return error
    }

    private func reportDecodeIssue(_ error: ParseError, path: String, method: HTTPMethod) {
        var payload: [String: Any] = [
            "module": moduleName,
            "path": path,
            "method": method.rawValue,
            "error_type": "parse_error",
            "error_description": error.localizedDescription
        ]

        if case .decodingFailed(let detail) = error {
            payload["decode_error_kind"] = String(describing: detail.type)
            payload["missing_field"] = detail.missingField ?? ""
            payload["coding_path"] = detail.codingPath
            payload["expected_type"] = detail.expectedType
            payload["response_preview_size"] = detail.responsePreview.count
            payload["response_preview_sanitized"] = sanitizeResponsePreview(detail.responsePreview)
        }

        Logger.firebase(
            "API decode mismatch detected",
            level: .error,
            labels: [
                "cloud_logging": "true",
                "module": moduleName,
                "operation": "decode_mismatch"
            ],
            jsonPayload: payload
        )
    }

    /// Keep schema diagnostics while reducing sensitive payload leakage risk.
    private func sanitizeResponsePreview(_ raw: String) -> String {
        var sanitized = raw

        let patterns: [(String, String)] = [
            // bearer token
            ("(?i)bearer\\s+[A-Za-z0-9\\-\\._~\\+/]+=*", "bearer [REDACTED]"),
            // likely JWT
            ("[A-Za-z0-9\\-_]{16,}\\.[A-Za-z0-9\\-_]{16,}\\.[A-Za-z0-9\\-_]{16,}", "[REDACTED_JWT]"),
            // email
            ("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[REDACTED_EMAIL]"),
            // generic API key field values
            ("(?i)\"(api_?key|token|access_?token|id_?token|authorization)\"\\s*:\\s*\"[^\"]+\"", "\"$1\":\"[REDACTED]\"")
        ]

        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
            }
        }

        return String(sanitized.prefix(160))
    }
}

// MARK: - Convenience Extensions

extension APICallHelper {

    /// Make a GET request
    func get<T: Codable>(_ type: T.Type, path: String) async throws -> T {
        return try await call(type, path: path, method: .GET)
    }

    /// Make a POST request with JSON body
    func post<T: Codable, B: Encodable>(
        _ type: T.Type,
        path: String,
        body: B
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        return try await call(type, path: path, method: .POST, body: bodyData)
    }

    /// Make a POST request with dictionary body
    func post<T: Codable>(
        _ type: T.Type,
        path: String,
        bodyDict: [String: Any]
    ) async throws -> T {
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        return try await call(type, path: path, method: .POST, body: bodyData)
    }

    /// Make a PUT request with JSON body
    func put<T: Codable, B: Encodable>(
        _ type: T.Type,
        path: String,
        body: B
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        return try await call(type, path: path, method: .PUT, body: bodyData)
    }

    /// Make a PUT request with dictionary body
    func put<T: Codable>(
        _ type: T.Type,
        path: String,
        bodyDict: [String: Any]
    ) async throws -> T {
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        return try await call(type, path: path, method: .PUT, body: bodyData)
    }

    /// Make a DELETE request
    func delete(path: String) async throws {
        try await callNoResponse(path: path, method: .DELETE)
    }
}

// MARK: - DomainError Integration

extension APICallHelper {

    /// Make an API call and convert errors to DomainError
    ///
    /// Use this method when you need DomainError for UI error handling.
    ///
    /// - Parameters:
    ///   - type: Expected response type
    ///   - path: API endpoint path
    ///   - method: HTTP method
    ///   - body: Request body data
    /// - Returns: Parsed response
    /// - Throws: DomainError
    func callWithDomainError<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            return try await call(type, path: path, method: method, body: body)
        } catch {
            throw error.toDomainError()
        }
    }

    /// Make an API call without response and convert errors to DomainError
    func callNoResponseWithDomainError(
        path: String,
        method: HTTPMethod = .DELETE,
        body: Data? = nil
    ) async throws {
        do {
            try await callNoResponse(path: path, method: method, body: body)
        } catch {
            throw error.toDomainError()
        }
    }
}
