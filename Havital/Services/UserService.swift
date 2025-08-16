import Foundation
import Combine
import FirebaseAuth

class UserService {
    static let shared = UserService()
    private let userPreferenceManager = UserPreferenceManager.shared
    
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
            // 忽略取消錯誤
            throw SystemError.taskCancelled
        } catch {
            // 其他錯誤按原樣傳遞
            throw error
        }
    }
    
    /// 無回應數據的 API 調用
    private func makeAPICallNoResponse(
        path: String,
        method: HTTPMethod = .POST,
        body: Data? = nil
    ) async throws {
        do {
            _ = try await httpClient.request(path: path, method: method, body: body)
        } catch let apiError as APIError where apiError.isCancelled {
            // 忽略取消錯誤
            throw SystemError.taskCancelled
        } catch {
            // 其他錯誤按原樣傳遞
            throw error
        }
    }
    
    func createTarget(_ target: Target) async throws {
        let body = try JSONEncoder().encode(target)
        try await makeAPICallNoResponse(path: "/user/targets", method: .POST, body: body)
    }
   
    func updatePersonalBestData(_ performanceData: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: performanceData)
        try await makeAPICallNoResponse(path: "/user/pb/race_run", method: .POST, body: body)
    }

    func updateUserData(_ userData: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: userData)
        try await makeAPICallNoResponse(path: "/user", method: .PUT, body: body)
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
        return Future<User, Error> { [weak self] promise in
            Task {
                do {
                    guard let self = self else {
                        throw APIError.system(SystemError.unknownError("Service deallocated"))
                    }
                    let user = try await self.makeAPICall(User.self, path: "/user")
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
        
        // Google 登入需要特殊的認證處理，使用自定義邏輯
        let data = try await makeGoogleLoginRequest(idToken: idToken)
        return try await parseGoogleLoginResponse(data: data)
    }
    
    // MARK: - Google Login Helper Methods
    
    /// Google 登入專用的請求方法（需要特殊的認證頭）
    private func makeGoogleLoginRequest(idToken: String) async throws -> Data {
        print("發送 Google 登入請求")
        print("Authorization: Bearer \(idToken.prefix(20))...")
        
        // 使用自定義 Authorization header
        let customHeaders = ["Authorization": "Bearer \(idToken)"]
        
        do {
            return try await httpClient.request(
                path: "/login/google", 
                method: .POST, 
                body: nil, 
                customHeaders: customHeaders
            )
        } catch {
            print("Google 登入請求失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 解析 Google 登入回應的專用方法
    private func parseGoogleLoginResponse(data: Data) async throws -> User {
        do {
            // 嘗試使用統一的解析器
            return try ResponseProcessor.extractData(User.self, from: data, using: parser)
        } catch {
            // 如果統一解析失敗，使用備用解析邏輯（保持相容性）
            return try await parseGoogleLoginResponseFallback(data: data)
        }
    }
    
    /// Google 登入回應的備用解析方法（保持向後相容）
    private func parseGoogleLoginResponseFallback(data: Data) async throws -> User {
        print("嘗試備用解析方法")
        
        do {
            // 嘗試正常解析
            let user = try JSONDecoder().decode(User.self, from: data)
            print("成功解析用戶資料: \(user.displayName ?? "")")
            return user
        } catch {
            // 如果正常解析失敗，查看是否回應格式為 { data: User }
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = jsonObject["data"] as? [String: Any] {
                // 如果有 data 欄位，嘗試只解析該欄位
                let dataJSON = try JSONSerialization.data(withJSONObject: responseData)
                let user = try JSONDecoder().decode(User.self, from: dataJSON)
                print("成功使用備用方法解析用戶資料: \(user.displayName ?? "")")
                return user
            } else {
                // 顯示原始 JSON 以便調試
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("無法解析的 JSON 資料: \(jsonString)")
                }
                throw error
            }
        }
    }
    
    // Updated to access nested user.data properties
    func syncUserPreferences(with user: User) {
        // 若後端未提供，從 Firebase 使用者檔案取得 Email/Name/Photo
        let firebaseUser = Auth.auth().currentUser
        userPreferenceManager.email = user.email ?? firebaseUser?.email ?? ""
        userPreferenceManager.name = user.displayName ?? firebaseUser?.displayName ?? ""
        userPreferenceManager.photoURL = user.photoUrl ?? firebaseUser?.photoURL?.absoluteString
        
        userPreferenceManager.maxHeartRate = user.maxHr
        
        // Update week of training if available
        userPreferenceManager.weekOfTraining = user.weekOfTraining
        
        // 同步數據源設定（不在這裡檢查連接狀態）
        if let dataSourceString = user.dataSource,
           let dataSourceType = DataSourceType(rawValue: dataSourceString) {
            
            userPreferenceManager.dataSourcePreference = dataSourceType
            print("從後端恢復數據源設定: \(dataSourceType.displayName)")
            
            // 連接狀態檢查交由 AuthenticationService.checkGarminConnectionAfterUserData() 處理
            // 這樣可以確保在正確的時機檢查，避免時序問題
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
        try await makeAPICallNoResponse(path: "/user/\(userId)", method: .DELETE)
    }
}
