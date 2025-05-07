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
    @Published var hasCompletedOnboarding = false
    
    static let shared = AuthenticationService()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Listen to auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            
            if user != nil {
                // If user is authenticated with Firebase, fetch their profile from backend
                self?.fetchUserProfile()
                
                // 同時觸發週計劃更新
                Task {
                    await self?.refreshWeeklyPlanAfterLogin()
                }
            } else {
                self?.appUser = nil
                self?.hasCompletedOnboarding = false
            }
        }
        
        
        // 從 UserDefaults 讀取 hasCompletedOnboarding
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // 新增一個方法來刷新週計劃
    private func refreshWeeklyPlanAfterLogin() async {
        do {
            //let newPlan = try await TrainingPlanService.shared.getWeeklyPlan()
            //TrainingPlanStorage.saveWeeklyPlan(newPlan)
            print("登入後成功更新週訓練計劃")
        } catch {
            print("登入後更新週訓練計劃失敗: \(error)")
        }
    }
    
    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            loginError = nil
        }
        
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthError.missingClientId
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                throw AuthError.presentationError
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingToken
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // 建立 Firebase 認證憑證
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            
            // 使用憑證登入 Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            self.user = authResult.user
            
            // 獲取 Firebase ID token，而非使用 Google ID token
            let firebaseToken = try await authResult.user.getIDToken()
            print("已獲取 Firebase ID token，長度：\(firebaseToken.count)")
            
            // 與後端同步 (使用 Firebase Token)
            try await syncUserWithBackend(idToken: firebaseToken)
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("Google 登入失敗: \(error)")
            await MainActor.run {
                isLoading = false
                loginError = error
            }
        }
    }
    
    private func syncUserWithBackend(idToken: String) async throws {
        do {
            print("正在與後端同步，使用 Firebase ID Token")
            // 嘗試使用 Firebase Token 登入並獲取用戶數據
            let user = try await UserService.shared.loginWithGoogle(idToken: idToken)
            
            await MainActor.run {
                self.appUser = user
            }
            
            // 判斷用戶是否已完成 onboarding
            checkOnboardingStatus(user: user)
            
            // 同步用戶偏好
            UserService.shared.syncUserPreferences(with: user)
            
            print("後端同步成功，已獲取用戶資料")
        } catch {
            print("與後端同步失敗: \(error.localizedDescription)")
            throw error
        }
    }
    
    // 檢查用戶是否已完成 onboarding
    private func checkOnboardingStatus(user: User) {
        // 如果用戶有 active_weekly_plan_id，則表示已完成 onboarding
        let completed = user.data.activeWeeklyPlanId != nil
        
        // 在主線程更新狀態並儲存到 UserDefaults
        Task { @MainActor in
            self.hasCompletedOnboarding = completed
            UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")
        }
        
        print("用戶 onboarding 狀態: \(completed ? "已完成" : "未完成")")
    }
    
    func fetchUserProfile() {
        isLoading = true
        
        UserService.shared.getUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("無法獲取用戶資料: \(error)")
                }
            } receiveValue: { [weak self] user in
                self?.appUser = user
                
                // 檢查 onboarding 狀態
                self?.checkOnboardingStatus(user: user)
                
                // 同步用戶偏好
                UserService.shared.syncUserPreferences(with: user)
            }
            .store(in: &cancellables)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        try GIDSignIn.sharedInstance.signOut()
        
        // 在登出時重置各種狀態
        appUser = nil
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserPreferenceManager.shared.clearUserData()
        // 登出時清除 WorkoutSummary 快取
        WorkoutService.shared.clearWorkoutSummaryCache()
    }
    
    // Get the current ID token
    func getIdToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        return try await user.getIDToken()
    }
    
    func resetOnboarding() {
        // 在主線程更新狀態
        Task { @MainActor in
            self.hasCompletedOnboarding = false
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        
        // 清除相關的 onboarding 數據，但保留用戶登入狀態
        TrainingPlanStorage.shared.clearAll()
        
        // 廣播 Onboarding 已重置／完成事件
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        
        print("已重置 onboarding 狀態")
    }
}

enum AuthError: Error {
    case missingClientId
    case presentationError
    case missingToken
    case notAuthenticated
    
    var localizedDescription: String {
        switch self {
        case .missingClientId:
            return "Firebase client ID 不存在"
        case .presentationError:
            return "無法顯示登入畫面"
        case .missingToken:
            return "認證 token 不存在"
        case .notAuthenticated:
            return "用戶未登入"
        }
    }
}
