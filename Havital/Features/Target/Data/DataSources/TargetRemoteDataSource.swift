import Foundation

// MARK: - TargetRemoteDataSource Protocol
protocol TargetRemoteDataSourceProtocol {
    func getTargets() async throws -> [Target]
    func getTarget(id: String) async throws -> Target
    func createTarget(_ target: Target) async throws -> Target
    func updateTarget(id: String, target: Target) async throws -> Target
    func deleteTarget(id: String) async throws
}

// MARK: - TargetRemoteDataSource
/// Handles remote API calls for target data
/// Data Layer - Direct HTTP calls following Clean Architecture
final class TargetRemoteDataSource: TargetRemoteDataSourceProtocol {

    // MARK: - Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser

    // MARK: - Initialization
    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - Private Helpers

    /// Unified API call method
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }

    /// API call with no response body
    private func makeAPICallNoResponse(
        path: String,
        method: HTTPMethod = .DELETE,
        body: Data? = nil
    ) async throws {
        do {
            _ = try await httpClient.request(path: path, method: method, body: body)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }

    // MARK: - Read Operations

    /// Fetch all targets from API
    func getTargets() async throws -> [Target] {
        Logger.debug("[TargetRemoteDS] Fetching all targets")
        return try await makeAPICall([Target].self, path: "/user/targets")
    }

    /// Fetch single target by ID from API
    func getTarget(id: String) async throws -> Target {
        Logger.debug("[TargetRemoteDS] Fetching target: \(id)")
        return try await makeAPICall(Target.self, path: "/user/targets/\(id)")
    }

    // MARK: - Write Operations

    /// Create new target via API
    func createTarget(_ target: Target) async throws -> Target {
        Logger.debug("[TargetRemoteDS] Creating target: \(target.name)")
        let body = try JSONEncoder().encode(target)
        return try await makeAPICall(Target.self, path: "/user/targets", method: .POST, body: body)
    }

    /// Update target via API
    func updateTarget(id: String, target: Target) async throws -> Target {
        Logger.debug("[TargetRemoteDS] Updating target: \(id)")
        let body = try JSONEncoder().encode(target)
        return try await makeAPICall(Target.self, path: "/user/targets/\(id)", method: .PUT, body: body)
    }

    /// Delete target via API
    func deleteTarget(id: String) async throws {
        Logger.debug("[TargetRemoteDS] Deleting target: \(id)")
        try await makeAPICallNoResponse(path: "/user/targets/\(id)", method: .DELETE)
    }
}
