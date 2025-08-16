import Foundation
import Combine

class TargetService {
    static let shared = TargetService()
    
    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser
    
    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }
    
    // MARK: - Unified API Call Method
    
    /// 統一的 API 調用方法
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
    
    /// 無回應數據的 API 調用
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
    
    /// 創建新的賽事目標
    func createTarget(_ target: Target) async throws -> Target {
        let body = try JSONEncoder().encode(target)
        let response = try await makeAPICall(TargetResponse.self,
            path: "/user/targets", method: .POST, body: body)
        return response
    }
    
    /// 獲取所有賽事目標
    func getTargets() async throws -> [Target] {
        let response = try await makeAPICall(TargetsResponse.self, path: "/user/targets")
        return response
    }
    
    /// 獲取特定賽事目標詳情
    func getTarget(id: String) async throws -> Target {
        let response = try await makeAPICall(TargetResponse.self, path: "/user/targets/\(id)")
        return response
    }
    
    /// 更新特定賽事目標
    func updateTarget(id: String, target: Target) async throws -> Target {
        let body = try JSONEncoder().encode(target)
        let response = try await makeAPICall(TargetResponse.self,
            path: "/user/targets/\(id)", method: .PUT, body: body)
        return response
    }
    
    /// 刪除特定賽事目標
    func deleteTarget(id: String) async throws {
        try await makeAPICallNoResponse(path: "/user/targets/\(id)", method: .DELETE)
    }
    
    /// 使用 Combine 的方式獲取所有賽事目標
    func getTargetsPublisher() -> AnyPublisher<[Target], Error> {
        return Future<[Target], Error> { [weak self] promise in
            Task {
                do {
                    let targets = try await self?.getTargets() ?? []
                    promise(.success(targets))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 使用 Combine 的方式獲取特定賽事目標詳情
    func getTargetPublisher(id: String) -> AnyPublisher<Target, Error> {
        return Future<Target, Error> { [weak self] promise in
            Task {
                do {
                    guard let self = self else {
                        throw APIError.system(SystemError.unknownError("Service deallocated"))
                    }
                    let target = try await self.getTarget(id: id)
                    promise(.success(target))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// 單一目標回應結構
typealias TargetResponse = Target

// 多個目標回應結構
typealias TargetsResponse = [Target]
