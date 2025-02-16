import Foundation

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
    
    func getCurrentUser() async throws -> User {
        let endpoint = try Endpoint(
            path: "/user",
            method: .get,
            requiresAuth: true
        )
        
        return try await networkService.request(endpoint)
    }
    
    func loginWithGoogle(idToken: String) async throws -> User {
        let request = GoogleLoginRequest(idToken: idToken)
        let endpoint = try Endpoint(
            path: "/login/google",
            method: .post,
            requiresAuth: false,
            body: request
        )
        
        return try await networkService.request(endpoint)
    }
    
    func syncUserPreferences(with user: User) {
        userPreferenceManager.email = user.email
        userPreferenceManager.name = user.name
        userPreferenceManager.photoURL = user.photoURL
    }
}
