import Foundation
import Combine

class TargetService {
    static let shared = TargetService()
    
    private init() {}
    
    /// 創建新的賽事目標
    func createTarget(_ target: Target) async throws -> Target {
        let response = try await APIClient.shared.request(TargetResponse.self,
            path: "/user/targets", method: "POST",
            body: try JSONEncoder().encode(target))
        return response.data
    }
    
    /// 獲取所有賽事目標
    func getTargets() async throws -> [Target] {
        let response = try await APIClient.shared.request(TargetsResponse.self,
            path: "/user/targets")
        return response.data
    }
    
    /// 獲取特定賽事目標詳情
    func getTarget(id: String) async throws -> Target {
        let response = try await APIClient.shared.request(TargetResponse.self,
            path: "/user/targets/\(id)")
        return response.data
    }
    
    /// 更新特定賽事目標
    func updateTarget(id: String, target: Target) async throws -> Target {
        let response = try await APIClient.shared.request(TargetResponse.self,
            path: "/user/targets/\(id)", method: "PUT",
            body: try JSONEncoder().encode(target))
        return response.data
    }
    
    /// 刪除特定賽事目標
    func deleteTarget(id: String) async throws {
        try await APIClient.shared.requestNoResponse(
            path: "/user/targets/\(id)", method: "DELETE")
    }
    
    /// 使用 Combine 的方式獲取所有賽事目標
    func getTargetsPublisher() -> AnyPublisher<[Target], Error> {
        return Future<[Target], Error> { promise in
            Task {
                do {
                    let targets = try await self.getTargets()
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
        return Future<Target, Error> { promise in
            Task {
                do {
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
struct TargetResponse: Codable {
    let data: Target
}

// 多個目標回應結構
struct TargetsResponse: Codable {
    let data: [Target]
}
