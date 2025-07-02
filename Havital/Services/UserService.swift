import Foundation
import Combine
import FirebaseAuth

class UserService {
    static let shared = UserService()
    private let userPreferenceManager = UserPreferenceManager.shared
    
    private init() {}
    
    func createTarget(_ target: Target) async throws {
        // 使用 APIClient 建立賽事目標
        try await APIClient.shared.requestNoResponse(
            path: "/user/targets", method: "POST",
            body: try JSONEncoder().encode(target))
    }
   
    func updatePersonalBestData(_ performanceData: [String: Any]) async throws {
        try await APIClient.shared.requestNoResponse(
            path: "/user/pb/race_run", method: "POST",
            body: try JSONSerialization.data(withJSONObject: performanceData))
    }

    func updateUserData(_ userData: [String: Any]) async throws {
        try await APIClient.shared.requestNoResponse(
            path: "/user", method: "PUT",
            body: try JSONSerialization.data(withJSONObject: userData))
    }
    
    /// 更新數據源設定到後端
    func updateDataSource(_ dataSource: String) async throws {
        let userData = [
            "data_source": dataSource
        ] as [String: Any]
        
        try await updateUserData(userData)
        print("數據源設定已同步到後端: \(dataSource)")
    }
    
    func getUserProfile() -> AnyPublisher<User, Error> {
        // 使用 APIClient 取得用戶資料
        return Future<User, Error> { promise in
            Task {
                do {
                    let user = try await APIClient.shared.request(User.self, path: "/user")
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
        guard let url = URL(string: APIConfig.baseURL + "/login/google") else {
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
            throw URLError(.badServerResponse)
        }
        
        print("Google 登入回應狀態: \(httpResponse.statusCode)")
        
        // 檢查回應
        if httpResponse.statusCode >= 400 {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("登入錯誤回應: \(responseText)")
            throw NSError(domain: "UserService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: responseText])
        }
        
        // 解析回應數據
        do {
            // 嘗試正常解析
            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                print("成功解析用戶資料: \(user.data.displayName ?? "")")
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
                    print("成功使用備用方法解析用戶資料: \(user.data.displayName ?? "")")
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
        // 若後端未提供，從 Firebase 使用者檔案取得 Email/Name/Photo
        let firebaseUser = Auth.auth().currentUser
        userPreferenceManager.email = user.data.email ?? firebaseUser?.email ?? ""
        userPreferenceManager.name = user.data.displayName ?? firebaseUser?.displayName ?? ""
        userPreferenceManager.photoURL = user.data.photoUrl ?? firebaseUser?.photoURL?.absoluteString
        
        userPreferenceManager.maxHeartRate = user.data.maxHr
        
        // Update week of training if available
        userPreferenceManager.weekOfTraining = user.data.weekOfTraining
        
        // 同步數據源設定並檢查不一致情況
        if let dataSourceString = user.data.dataSource,
           let dataSourceType = DataSourceType(rawValue: dataSourceString) {
            
            // 檢查 Garmin 數據源不一致的情況
            if dataSourceType == .garmin && !GarminManager.shared.isConnected {
                // 檢查是否用戶本地已經設定為其他數據源（避免重複警告）
                if userPreferenceManager.dataSourcePreference == .garmin {
                    print("⚠️ 發現數據源不一致：後端為 Garmin 但本地未連接")
                    // 發送通知提示用戶處理數據源不一致問題
                    NotificationCenter.default.post(
                        name: .garminDataSourceMismatch,
                        object: nil
                    )
                } else {
                    print("⚠️ 後端為 Garmin 但本地已設為 \(userPreferenceManager.dataSourcePreference.displayName)，跳過警告")
                }
            } else {
                userPreferenceManager.dataSourcePreference = dataSourceType
                print("從後端恢復數據源設定: \(dataSourceType.displayName)")
            }
        } else {
            // 如果後端沒有數據源設定，使用當前本地設定並同步到後端
            Task {
                do {
                    try await updateDataSource(userPreferenceManager.dataSourcePreference.rawValue)
                } catch {
                    print("同步本地數據源設定到後端失敗: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Helper function to calculate age (placeholder implementation)
    private func calculateAge(from dateString: String) -> Int? {
        // This is just a placeholder - you would implement proper age calculation
        // based on your actual data structure
        return nil
    }
    
    // 刪除用戶帳戶
    func deleteUser(userId: String) async throws {
        try await APIClient.shared.requestNoResponse(
            path: "/user/\(userId)", 
            method: "DELETE"
        )
    }
}
