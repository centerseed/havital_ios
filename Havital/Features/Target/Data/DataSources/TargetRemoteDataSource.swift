import Foundation

// MARK: - TargetRemoteDataSource Protocol
protocol TargetRemoteDataSourceProtocol {
    func getTargets() async throws -> [Target]
    func getTarget(id: String) async throws -> Target
    func createTarget(_ target: Target) async throws -> TargetMutationResult
    func updateTarget(id: String, target: Target) async throws -> TargetMutationResult
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
        return try await tracked("TargetRemoteDataSource: getTargets") {
            try await apiHelper.get([Target].self, path: "/user/targets")
        }
    }

    /// Fetch single target by ID from API
    func getTarget(id: String) async throws -> Target {
        Logger.debug("[TargetRemoteDS] Fetching target: \(id)")
        return try await tracked("TargetRemoteDataSource: getTarget") {
            try await apiHelper.get(Target.self, path: "/user/targets/\(id)")
        }
    }

    // MARK: - Write Operations

    /// Create new target via API
    func createTarget(_ target: Target) async throws -> TargetMutationResult {
        Logger.debug("[TargetRemoteDS] Creating target: \(target.name)")
        return try await tracked("TargetRemoteDataSource: createTarget") {
            let response = try await apiHelper.postWithMessage(
                Target.self,
                path: "/user/targets",
                body: target
            )
            return TargetMutationResult(target: response.data, message: response.message)
        }
    }

    /// Update target via API
    func updateTarget(id: String, target: Target) async throws -> TargetMutationResult {
        Logger.debug("[TargetRemoteDS] Updating target: \(id)")
        return try await tracked("TargetRemoteDataSource: updateTarget") {
            let response = try await apiHelper.putWithMessage(
                Target.self,
                path: "/user/targets/\(id)",
                body: target
            )
            return TargetMutationResult(target: response.data, message: response.message)
        }
    }

    /// Delete target via API
    func deleteTarget(id: String) async throws {
        Logger.debug("[TargetRemoteDS] Deleting target: \(id)")
        try await tracked("TargetRemoteDataSource: deleteTarget") {
            try await apiHelper.delete(path: "/user/targets/\(id)")
        }
    }
}
