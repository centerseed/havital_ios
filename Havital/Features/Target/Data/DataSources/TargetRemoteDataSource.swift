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
/// Uses APICallHelper for unified error handling
final class TargetRemoteDataSource: TargetRemoteDataSourceProtocol {

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    // MARK: - Initialization

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "TargetRemoteDS"
        )
    }

    // MARK: - Read Operations

    /// Fetch all targets from API
    func getTargets() async throws -> [Target] {
        Logger.debug("[TargetRemoteDS] Fetching all targets")
        return try await apiHelper.get([Target].self, path: "/user/targets")
    }

    /// Fetch single target by ID from API
    func getTarget(id: String) async throws -> Target {
        Logger.debug("[TargetRemoteDS] Fetching target: \(id)")
        return try await apiHelper.get(Target.self, path: "/user/targets/\(id)")
    }

    // MARK: - Write Operations

    /// Create new target via API
    func createTarget(_ target: Target) async throws -> Target {
        Logger.debug("[TargetRemoteDS] Creating target: \(target.name)")
        return try await apiHelper.post(Target.self, path: "/user/targets", body: target)
    }

    /// Update target via API
    func updateTarget(id: String, target: Target) async throws -> Target {
        Logger.debug("[TargetRemoteDS] Updating target: \(id)")
        return try await apiHelper.put(Target.self, path: "/user/targets/\(id)", body: target)
    }

    /// Delete target via API
    func deleteTarget(id: String) async throws {
        Logger.debug("[TargetRemoteDS] Deleting target: \(id)")
        try await apiHelper.delete(path: "/user/targets/\(id)")
    }
}
