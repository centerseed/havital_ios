import Foundation
import Combine

class TargetService {
    static let shared = TargetService()
    private let networkService = NetworkService.shared
    
    private init() {}
    
    /// 創建新的賽事目標
    func createTarget(_ target: Target) async throws -> Target {
        print("開始建立賽事目標")
        
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user/targets") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證 token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加認證 token")
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        // 序列化目標數據
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(target)
            print("成功編碼目標資料")
        } catch {
            print("編碼目標資料時發生錯誤: \(error)")
            throw error
        }
        
        // 發送請求
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode > 201 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // 解析回應數據 - 修正泛型類型問題
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(TargetResponse.self, from: data)
            
            // 保存到本地儲存
            TargetStorage.shared.saveTarget(response.data)
            
            print("成功建立賽事目標")
            return response.data
        } catch {
            print("解析回應數據失敗: \(error)")
            throw error
        }
    }
    
    /// 獲取所有賽事目標
    func getTargets() async throws -> [Target] {
        print("開始獲取所有賽事目標")
        
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user/targets") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 添加認證 token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加認證 token")
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        // 發送請求
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode > 201 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // 解析回應數據 - 使用專門的 TargetsResponse 類型
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(TargetsResponse.self, from: data)
            
            // 保存到本地儲存
            TargetStorage.shared.saveTargets(response.data)
            
            print("成功獲取所有賽事目標")
            return response.data
        } catch {
            print("解析回應數據失敗: \(error)")
            throw error
        }
    }
    
    /// 獲取特定賽事目標詳情
    func getTarget(id: String) async throws -> Target {
        print("開始獲取賽事目標，ID: \(id)")
        
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user/targets/\(id)") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 添加認證 token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加認證 token")
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        // 發送請求
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode > 201 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // 解析回應數據 - 使用 TargetResponse
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(TargetResponse.self, from: data)
            
            // 保存到本地儲存
            TargetStorage.shared.saveTarget(response.data)
            
            print("成功獲取賽事目標")
            return response.data
        } catch {
            print("解析回應數據失敗: \(error)")
            throw error
        }
    }
    
    /// 更新特定賽事目標
    func updateTarget(id: String, target: Target) async throws -> Target {
        print("開始更新賽事目標，ID: \(id)")
        
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user/targets/\(id)") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加認證 token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加認證 token")
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        // 序列化目標數據
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(target)
            print("成功編碼目標資料")
        } catch {
            print("編碼目標資料時發生錯誤: \(error)")
            throw error
        }
        
        // 發送請求
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode > 201 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // 解析回應數據 - 使用 TargetResponse
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(TargetResponse.self, from: data)
            
            // 更新本地儲存
            TargetStorage.shared.saveTarget(response.data)
            
            print("成功更新賽事目標")
            return response.data
        } catch {
            print("解析回應數據失敗: \(error)")
            throw error
        }
    }
    
    /// 刪除特定賽事目標
    func deleteTarget(id: String) async throws {
        print("開始刪除賽事目標，ID: \(id)")
        
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user/targets/\(id)") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // 添加認證 token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加認證 token")
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        // 發送請求
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode > 201 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // 從本地儲存中移除
        TargetStorage.shared.removeTarget(id: id)
        
        print("成功刪除賽事目標")
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
struct TargetResponse: Decodable {
    let data: Target
}

// 多個目標回應結構
struct TargetsResponse: Decodable {
    let data: [Target]
}
