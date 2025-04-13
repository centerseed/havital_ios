import Foundation
import Combine

class UserService {
    static let shared = UserService()
    private let networkService = NetworkService.shared
    private let userPreferenceManager = UserPreferenceManager.shared
    
    private init() {}
    
    func createTarget(_ target: Target) async throws {
        print("開始建立賽事目標")
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user/targets") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        do {
            if let token = try await AuthenticationService.shared.user?.getIDToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("成功添加認證 token")
            } else {
                print("無法獲取認證 token")
                throw URLError(.userAuthenticationRequired)
            }
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(target)
            print("成功編碼目標資料")
        } catch {
            print("編碼目標資料時發生錯誤: \(error)")
            throw error
        }
        
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        print("成功建立賽事目標")
    }
   
    func updatePersonalBestData(_ performanceData: [String: Any]) async throws {
        print("開始更新用戶性能數據")
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user/pb/race_run") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加認證 token")
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: performanceData)
        request.httpBody = jsonData
        
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        print("成功更新用戶性能數據")
    }

    func updateUserData(_ userData: [String: Any]) async throws {
        print("開始更新用戶資料")
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/user") else {
            print("URL 無效")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token
        do {
            let token = try await AuthenticationService.shared.getIdToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("成功添加認證 token")
        } catch {
            print("獲取 token 時發生錯誤: \(error)")
            throw error
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: userData)
        request.httpBody = jsonData
        
        print("開始發送請求")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw URLError(.badServerResponse)
        }
        
        print("收到回應，狀態碼: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        print("成功更新用戶資料")
    }
    
    func getUserProfile() -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            Task {
                do {
                    let endpoint = try Endpoint(
                        path: "/user",
                        method: .get,
                        requiresAuth: true
                    )
                    
                    let user: User = try await self.networkService.request(endpoint)
                    promise(.success(user))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func loginWithGoogle(idToken: String) async throws -> User {
        print("嘗試使用 Google 登入，ID Token 長度: \(idToken.count)")
        
        // 確保請求正確的URL
        guard let url = URL(string: "https://api-service-364865009192.asia-east1.run.app/login/google") else {
            throw URLError(.badURL)
        }
        
        // 建立請求 - 根據JS代碼匹配格式
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 關鍵修改：將 idToken 放在 Authorization 標頭而不是請求體中
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        // 不需要請求體
        print("發送登入請求到: \(url.absoluteString)")
        print("Authorization: Bearer \(idToken.prefix(20))...")
        
        // 發送請求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("回應不是 HTTP 回應")
            throw NetworkError.invalidResponse
        }
        
        print("Google 登入回應狀態: \(httpResponse.statusCode)")
        
        // 檢查回應
        if httpResponse.statusCode >= 400 {
            if let responseText = String(data: data, encoding: .utf8) {
                print("登入錯誤回應: \(responseText)")
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // 解析回應數據
        do {
            // 嘗試正常解析
            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                print("成功解析用戶資料: \(user.data.displayName)")
                return user
            } catch {
                // 如果正常解析失敗，查看是否回應格式為 { data: User }
                print("嘗試備用解析方法")
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responseData = jsonObject["data"] as? [String: Any] {
                    // 如果有 data 欄位，嘗試只解析該欄位
                    let dataJSON = try JSONSerialization.data(withJSONObject: responseData)
                    let userProfile = try JSONDecoder().decode(UserProfileData.self, from: dataJSON)
                    let user = User(data: userProfile)
                    print("成功使用備用方法解析用戶資料: \(user.data.displayName)")
                    return user
                } else {
                    // 顯示原始 JSON 以便調試
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("無法解析的 JSON 資料: \(jsonString)")
                    }
                    throw error
                }
            }
        } catch {
            print("解析用戶數據失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Updated to access nested user.data properties
    func syncUserPreferences(with user: User) {
        userPreferenceManager.email = user.data.email ?? ""
        userPreferenceManager.name = user.data.displayName
        userPreferenceManager.photoURL = user.data.photoUrl
        
        // Additionally, we can sync more user preferences if needed
        if let age = calculateAge(from: user.data.lastLogin) {
            userPreferenceManager.age = age
        }
        
        userPreferenceManager.maxHeartRate = user.data.maxHr
        
        // Update week of training if available
        userPreferenceManager.weekOfTraining = user.data.weekOfTraining
    }
    
    // Helper function to calculate age (placeholder implementation)
    private func calculateAge(from dateString: String) -> Int? {
        // This is just a placeholder - you would implement proper age calculation
        // based on your actual data structure
        return nil
    }
}
