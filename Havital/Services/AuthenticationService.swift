import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import Combine

class AuthenticationService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var appUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var loginError: Error?
    @Published var loginErrorOccurred = false
    
    static let shared = AuthenticationService()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 監聽 Firebase Auth 的狀態變更
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            
            print("user:", user)
            
            if user != nil {
                // 如果用戶通過 Firebase 認證，就從後端取得用戶資料
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            // 如果用戶通過 Firebase 認證，就從後端取得用戶資料
                            self?.fetchUserProfile()
                        }
            } else {
                self?.appUser = nil
            }
        }
    }
    
    func signInWithGoogle() async {
        isLoading = true
        loginError = nil
        
        do {
            // 1. 獲取客戶端 ID
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthError.missingClientId
            }
            
            // 2. 配置 Google Sign-In
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // 3. 取得根視圖控制器
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                throw AuthError.presentationError
            }
            
            // 4. 實施 Google 登入
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            // 5. 確保取得 ID token
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingToken
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // 6. 建立 Firebase 憑證
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // 7. 使用憑證登入 Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            self.user = authResult.user
            
            // 8. 重要：獲取 Firebase ID token，而不是使用 Google ID token
            let firebaseToken = try await authResult.user.getIDToken()
            print("已獲取 Firebase ID token，長度：\(firebaseToken.count)")
            
            // 9. 使用 Firebase ID token 同步用戶資料到後端
            try await syncUserWithBackend(idToken: firebaseToken)
            
            await MainActor.run {
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loginError = error
                self.loginErrorOccurred = true
                self.isLoading = false
                print("Google 登入失敗: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncUserWithBackend(idToken: String) async throws {
        do {
            // 嘗試獲取現有用戶
            print("嘗試與後端同步用戶資料，Token 類型: \(type(of: idToken))")
            let user = try await UserService.shared.loginWithGoogle(idToken: idToken)
            
            await MainActor.run {
                self.appUser = user
                UserService.shared.syncUserPreferences(with: user)
                print("成功與後端同步用戶資料: \(user.data.displayName)")
            }
        } catch {
            print("無法同步用戶資料到後端: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchUserProfile() {
        isLoading = true
        
        UserService.shared.getUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("獲取用戶資料失敗: \(error)")
                }
            } receiveValue: { [weak self] user in
                self?.appUser = user
                UserService.shared.syncUserPreferences(with: user)
            }
            .store(in: &cancellables)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        try GIDSignIn.sharedInstance.signOut()
        appUser = nil
        UserPreferenceManager.shared.clearUserData()
    }
    
    // 獲取當前 ID token
    func getIdToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        do {
            // 嘗試獲取令牌，如果過期會自動刷新
            return try await user.getIDToken(forcingRefresh: true)
        } catch {
            print("令牌獲取/刷新失敗: \(error.localizedDescription)")
            throw error
        }
    }

}

enum AuthError: Error {
    case missingClientId
    case presentationError
    case missingToken
    case notAuthenticated
    case loginFailed
    
    var localizedDescription: String {
        switch self {
        case .missingClientId:
            return "缺少 Firebase 客戶端 ID"
        case .presentationError:
            return "無法顯示登入畫面"
        case .missingToken:
            return "缺少認證 token"
        case .notAuthenticated:
            return "用戶未登入"
        case .loginFailed:
            return "登入失敗"
        }
    }
    
    // 在 AuthenticationService 中添加
    func getCurrentToken() -> String? {
        // 從存儲中獲取當前令牌
        return UserDefaults.standard.string(forKey: "cached_auth_token")
    }

    // 在每次獲取令牌成功後緩存它
    func cacheCurrentToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "cached_auth_token")
    }

    // 修改 getIdToken 方法以緩存令牌
    func getIdToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        let token = try await user.getIDToken(forcingRefresh: true)
        cacheCurrentToken(token)
        return token
    }
}
