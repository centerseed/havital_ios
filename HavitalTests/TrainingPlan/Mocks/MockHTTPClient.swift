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

    // MARK: - HTTPClient Protocol

    func request(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?) async throws -> Data {
        // Record request
        requestHistory.append((path, method, body))

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
        encoder.keyEncodingStrategy = .convertToSnakeCase
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
