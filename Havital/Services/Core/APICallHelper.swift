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
    /// 3. Cancellation error detection and conversion to SystemError.taskCancelled
    /// 4. Logging for debugging
    ///
    /// - Parameters:
    ///   - type: Expected response type (must be Codable)
    ///   - path: API endpoint path
    ///   - method: HTTP method (defaults to GET)
    ///   - body: Request body data (optional)
    /// - Returns: Parsed response of type T
    /// - Throws: SystemError.taskCancelled for cancelled requests, or original error
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
            throw handleError(error)
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
    /// - Throws: SystemError.taskCancelled for cancelled requests, or original error
    func callNoResponse(
        path: String,
        method: HTTPMethod = .DELETE,
        body: Data? = nil
    ) async throws {
        do {
            _ = try await httpClient.request(path: path, method: method, body: body)
        } catch {
            throw handleError(error)
        }
    }

    // MARK: - Error Handling

    /// Handle API errors with unified logic
    ///
    /// This method centralizes the cancellation detection logic that was
    /// previously duplicated across 30+ files.
    ///
    /// - Parameter error: The original error
    /// - Returns: Processed error (SystemError.taskCancelled or original)
    private func handleError(_ error: Error) -> Error {
        // Check for cancellation using the unified isCancellationError extension
        if error.isCancellationError {
            Logger.debug("[\(moduleName)] Task cancelled, converting to SystemError.taskCancelled")
            return SystemError.taskCancelled
        }

        // Check for APIError.isCancelled (for backward compatibility)
        if let apiError = error as? APIError, apiError.isCancelled {
            Logger.debug("[\(moduleName)] APIError cancelled, converting to SystemError.taskCancelled")
            return SystemError.taskCancelled
        }

        // Return original error
        return error
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
