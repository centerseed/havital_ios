//
//  MockHTTPClient.swift
//  HavitalTests
//
//  Mock HTTP Client for unit testing - simulates API responses
//

import Foundation
@testable import paceriz_dev

/// Mock HTTP Client for unit testing
/// - Allows configuring expected responses for specific endpoints
/// - Records request history for verification
final class MockHTTPClient: HTTPClient {

    // MARK: - Response Configuration

    /// Map of "METHOD:path" -> Result<Data, Error>
    var mockResponses: [String: Result<Data, Error>] = [:]

    /// Request history for verification
    private(set) var requestHistory: [(path: String, method: HTTPMethod, body: Data?)] = []

    /// 每一支請求要求的逾時（`nil` ＝ 沒指定，走 `DefaultHTTPClient` 的共用預設）
    private(set) var timeoutHistory: [(path: String, timeout: TimeInterval?)] = []

    // MARK: - HTTPClient Protocol

    func request(
        path: String,
        method: HTTPMethod,
        body: Data?,
        customHeaders: [String: String]?,
        timeout: TimeInterval?
    ) async throws -> Data {
        // Record request
        requestHistory.append((path, method, body))
        timeoutHistory.append((path, timeout))

        // Build response key
        let key = "\(method.rawValue):\(path)"

        // Check if we have a configured response
        guard let response = mockResponses[key] else {
            throw HTTPError.notFound("No mock response configured for \(key)")
        }

        switch response {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Configure a successful response for a path
    func setResponse(for path: String, method: HTTPMethod = .GET, data: Data) {
        let key = "\(method.rawValue):\(path)"
        mockResponses[key] = .success(data)
    }

    /// Configure a successful JSON response for a path
    func setJSONResponse<T: Encodable>(for path: String, method: HTTPMethod = .GET, response: T) throws {
        let encoder = JSONEncoder()
        // Remove keyEncodingStrategy to match production DefaultAPIParser behavior
        // encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(response)
        setResponse(for: path, method: method, data: data)
    }

    /// Configure an error response for a path
    func setError(for path: String, method: HTTPMethod = .GET, error: Error) {
        let key = "\(method.rawValue):\(path)"
        mockResponses[key] = .failure(error)
    }

    /// Clear all mock responses and history
    func reset() {
        mockResponses.removeAll()
        requestHistory.removeAll()
        timeoutHistory.removeAll()
    }

    /// 某一支請求要求的逾時（找不到就是沒發出去）
    func requestedTimeout(forPathContaining fragment: String) -> TimeInterval?? {
        timeoutHistory.first { $0.path.contains(fragment) }.map { $0.timeout }
    }

    /// Get the number of requests made
    var requestCount: Int {
        requestHistory.count
    }

    /// Get the last request made
    var lastRequest: (path: String, method: HTTPMethod, body: Data?)? {
        requestHistory.last
    }

    /// Check if a specific path was called
    func wasPathCalled(_ path: String, method: HTTPMethod = .GET) -> Bool {
        requestHistory.contains { $0.path == path && $0.method == method }
    }

    /// Get call count for a specific path
    func callCount(for path: String, method: HTTPMethod = .GET) -> Int {
        requestHistory.filter { $0.path == path && $0.method == method }.count
    }
}
