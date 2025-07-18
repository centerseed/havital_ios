import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import Combine
import AuthenticationServices
import CryptoKit // For SHA256 nonce
import FirebaseMessaging // For FCM token

class AuthenticationService: NSObject, ObservableObject, TaskManageable {
    @Published var user: FirebaseAuth.User?
    @Published var appUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var loginError: Error?
    @Published var hasCompletedOnboarding = false
    @Published var isReonboardingMode = false // 新增：標識是否處於重新 Onboarding 模式
    
    static let shared = AuthenticationService()
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String?
    
    // TaskManageable 協議實作
    var activeTasks: [String: Task<Void, Never>] = [:]
    
    override private init() {
        super.init() // Call super.init() first
        
        // Now it's safe to use self
        // Listen to auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.isAuthenticated = user != nil
            
            if user != nil {
                // If user is authenticated with Firebase, fetch their profile from backend
                self.fetchUserProfile()
                // 嘗試同步當前 FCM token
                if let token = Messaging.messaging().fcmToken {
                    Task {
                        do {
                            try await UserService.shared.updateUserData(["fcm_token": token])
                            print("✅ 已於登入後同步 FCM token 到後端")
                        } catch {
                            print("⚠️ 登入後同步 FCM token 失敗: \(error.localizedDescription)")
                        }
                    }
                }
                
                // 同時觸發週計劃更新
                Task {
                    await self.refreshWeeklyPlanAfterLogin()
                }
            } else {
                self.appUser = nil
                self.hasCompletedOnboarding = false
            }
        }
        
        // 從 UserDefaults 讀取 hasCompletedOnboarding
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        // 注意：isReonboardingMode 不需要持久化，它是一個臨時狀態
    }

    // Helper to generate a random nonce for Apple Sign In
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    // Helper to SHA256 hash a string
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
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
        await executeTask(id: "sign_in_google") {
            await self.performGoogleSignIn()
        }
    }
    
    private func performGoogleSignIn() async {
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
            
            // 從 Google 登入結果取出 profile，更新 Firebase 使用者檔案
            if let profile = result.user.profile {
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = profile.name
                if let url = profile.imageURL(withDimension: 200) {
                    changeRequest.photoURL = url
                }
                try await changeRequest.commitChanges()
                // 同步本地 user
                self.user = Auth.auth().currentUser
            }
            
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

    @MainActor // Ensure UI updates are on the main thread
    func signInWithApple() async {
        await executeTask(id: "sign_in_apple") {
            await self.performAppleSignIn()
        }
    }
    
    private func performAppleSignIn() async {
        await MainActor.run {
            isLoading = true
            loginError = nil
        }

        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce) // Send the SHA256 hash of the nonce

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    internal func syncUserWithBackend(idToken: String) async throws {
        _ = await executeTask(id: "sync_user_backend") {
            try await self.performUserSync(idToken: idToken)
        }
    }
    
    private func performUserSync(idToken: String) async throws {
        // 從後端取得完整用戶資料
        var user = try await APIClient.shared.request(User.self, path: "/user")
        // 若後端未返回名稱或頭像，使用 Firebase 資料更新後端
        if let firebaseUser = Auth.auth().currentUser {
            var updateData = [String: Any]()
            if user.data.displayName == nil, let name = firebaseUser.displayName {
                updateData["display_name"] = name
            }
            if user.data.photoUrl == nil, let photo = firebaseUser.photoURL?.absoluteString {
                updateData["photo_url"] = photo
            }
            if !updateData.isEmpty {
                try await UserService.shared.updateUserData(updateData)
                // 重新抓取更新後的用戶資料
                user = try await APIClient.shared.request(User.self, path: "/user")
            }
        }
        await MainActor.run {
            self.appUser = user
        }
        // 更新 onboarding 與用戶偏好
        checkOnboardingStatus(user: user)
        UserService.shared.syncUserPreferences(with: user)

        // 同步過去兩個月未上傳的 workout
        Task {
            await self.syncRecentWorkouts()
        }
    }
    
    // 檢查用戶是否已完成 onboarding
    // 檢查用戶是否已完成 onboarding，並在完成時重設 isReonboardingMode
    private func checkOnboardingStatus(user: User) {
        // 如果用戶有 active_weekly_plan_id，則表示已完成 onboarding
        let completed = user.data.activeWeeklyPlanId != nil
        
        print("🔍 檢查 onboarding 狀態 - activeWeeklyPlanId: \(String(describing: user.data.activeWeeklyPlanId))")
        print("🔍 當前 hasCompletedOnboarding: \(hasCompletedOnboarding), 新值: \(completed)")
        
        // 在主線程更新狀態並儲存到 UserDefaults
        Task { @MainActor in
            print("🔄 更新 onboarding 狀態: \(completed)")
            self.hasCompletedOnboarding = completed
            UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")
            if completed {
                print("✅ 用戶已完成 onboarding")
                self.isReonboardingMode = false // 如果 Onboarding 完成，結束重新 Onboarding 模式
            } else {
                print("⏳ 用戶未完成 onboarding")
            }
        }
        
        print("📝 用戶 onboarding 狀態: \(completed ? "已完成" : "未完成"), isReonboardingMode: \(isReonboardingMode)")
    }
    
    func fetchUserProfile() {
        isLoading = true
        
        UserService.shared.getUserProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("無法獲取用戶資料: \(error)")
                    // 若為解析錯誤，重置並導回登入
                    if let self = self, error is DecodingError {
                        self.appUser = nil
                        self.isAuthenticated = false
                    }
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
    
    deinit {
        cancelAllTasks()
        cancellables.removeAll()
    }
    
    func signOut() throws {
        // 先解除 Garmin 綁定（如果已連接）
        Task {
            if GarminManager.shared.isConnected {
                await GarminManager.shared.disconnect()
            }
        }
        
        try Auth.auth().signOut()
        try GIDSignIn.sharedInstance.signOut()
        
        // 在登出時重置各種狀態
        appUser = nil
        hasCompletedOnboarding = false
        isReonboardingMode = false
        
        // 清除所有 UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        // 使用 CacheEventBus 統一清除所有快取
        CacheEventBus.shared.invalidateCache(for: .userLogout)
        
        // 清除非快取相關的本地存儲
        UserPreferenceManager.shared.clearUserData()
        WorkoutV2Service.shared.clearWorkoutSummaryCache()
        WorkoutUploadTracker.shared.clearUploadedWorkouts()
        SyncNotificationManager.shared.reset()
        
        // 清除 Keychain 中的敏感資料
        let secItemClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        for secItemClass in secItemClasses {
            let query: [String: Any] = [kSecClass as String: secItemClass]
            SecItemDelete(query as CFDictionary)
        }
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
        }
    }
    
    // Get the current ID token
    // MARK: - Reonboarding Logic

    func startReonboarding() {
        Task { @MainActor in
            // 1. 標記 Onboarding 未完成
            self.hasCompletedOnboarding = false
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            
            // 2. 進入重新 Onboarding 模式
            self.isReonboardingMode = true
            
            // 3. 清除可能影響重新 Onboarding 的舊狀態 (例如：activeWeeklyPlanId)
            // 這部分可能需要與後端協調，或在 Onboarding 流程中處理
            // 例如，在 UserService 中增加一個 clearActivePlanId 的方法，然後在這裡呼叫
            // await UserService.shared.clearActivePlanId()
            // 或者，更簡單的方式是讓後續的 Onboarding 流程覆蓋舊資料
            
            // 4. 清除本地與訓練計畫相關的緩存，確保重新 Onboarding 時是乾淨的狀態
            CacheEventBus.shared.invalidateCache(for: .dataChanged(.trainingPlan))
            // VDOTStorage.shared.clearVDOTData() // VDOT 可能基於賽事目標，看是否需要清除
            // UserPreferenceManager.shared.clearTrainingPreferences() // 清除用戶訓練偏好，讓他們重新設定
            
            print("AuthenticationService: 開始重新 Onboarding 流程。 hasCompletedOnboarding: \(self.hasCompletedOnboarding), isReonboardingMode: \(self.isReonboardingMode)")
        }
    }

    // Get the current ID token
    public func syncRecentWorkouts() async {
        await executeTask(id: "sync_recent_workouts") {
            await self.performRecentWorkoutsSync()
        }
    }
    
    private func performRecentWorkoutsSync() async {
        guard isAuthenticated, appUser != nil else {
            print("使用者未登入，跳過同步最近 workout")
            return
        }
        print("準備同步最近兩個月的 workout")
        do {
            let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
            // HealthKitManager 通常是自行初始化，而非 singleton
            let healthKitManager = HealthKitManager()
            let workoutsToSync = try await healthKitManager.fetchWorkoutsForDateRange(start: twoMonthsAgo, end: Date())
            
            if workoutsToSync.isEmpty {
                print("最近兩個月沒有新的 workout 需要同步")
                return
            }
            
            print("發現 \(workoutsToSync.count) 個 workout 需要檢查並可能同步")
            // WorkoutBackgroundUploader 是 singleton
            let uploadedCount = await WorkoutBackgroundUploader.shared.uploadPendingWorkouts(workouts: workoutsToSync, sendNotifications: true, force: false)
            print("已成功上傳 \(uploadedCount) 個最近的 workout")
            
        } catch {
            print("同步最近 workout 失敗: \(error)")
        }
    }

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

// 用於檢查 email 驗證狀態的結構
struct EmailVerification: Decodable {
    let email_verified: Bool
}

// MARK: - Apple Sign In Delegate Methods
extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("Apple Sign In: Failed to get Apple ID Credential")
            Task {
                await MainActor.run {
                    self.isLoading = false
                    self.loginError = AuthError.unknown
                }
            }
            return
        }

        guard let nonce = currentNonce else {
            print("Apple Sign In: Invalid nonce.")
            Task {
                await MainActor.run {
                    self.isLoading = false
                    self.loginError = AuthError.unknown // Or a more specific nonce error
                }
            }
            return
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            print("Apple Sign In: Unable to fetch identity token.")
            Task {
                await MainActor.run {
                    self.isLoading = false
                    self.loginError = AuthError.missingToken
                }
            }
            return
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Apple Sign In: Unable to serialize token string from data: \(appleIDToken.debugDescription)")
            Task {
                await MainActor.run {
                    self.isLoading = false
                    self.loginError = AuthError.missingToken
                }
            }
            return
        }

        // Create Firebase credential
        // The more specific appleCredential helper might not always be available or might have signature issues depending on SDK versions.
        // Using the generic OAuthProvider.credential is safer.
        let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                      idToken: idTokenString,
                                                      rawNonce: nonce)
        
        // You can still access fullName and email from appleIDCredential if needed for your backend
        // For example, when creating a new user profile in your backend:
        // let userFullName = appleIDCredential.fullName
        // let userEmail = appleIDCredential.email
        
        // Note: appleIDCredential.fullName and appleIDCredential.email are only provided on the first sign-in.
        // You should securely store them (e.g., in Keychain) if you need them later.
        // For example:
        // if let fullName = appleIDCredential.fullName, let email = appleIDCredential.email {
        //     print("User's full name: \(fullName), email: \(email)")
             // Save to Keychain or your backend during user creation/update
        // }

        Task {
            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                self.user = authResult.user
                
                let firebaseToken = try await authResult.user.getIDToken()
                print("Apple Sign In: Successfully signed in with Firebase. Firebase ID token length: \(firebaseToken.count)")
                
                try await syncUserWithBackend(idToken: firebaseToken)
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                print("Apple Sign In: Firebase sign-in failed: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.loginError = error
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Apple Sign In: Authorization failed: \(error.localizedDescription)")
        Task {
            await MainActor.run {
                self.isLoading = false
                // Check if the error is ASAuthorizationError.canceled
                if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                    // User cancelled the sign-in. Don't show an error message.
                    self.loginError = nil
                } else {
                    self.loginError = error
                }
            }
        }
    }
}

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign In presentation")
        }
        return window
    }
}

// MARK: - Email Verification and Password Reset
enum AuthError: Error {
    case missingClientId
    case presentationError
    case missingToken
    case notAuthenticated
    case emailNotVerified
    case unknown // Added for general errors
    
    var localizedDescription: String {
        switch self {
        case .missingClientId:
            return "Firebase client ID 不存在"
        case .presentationError:
            return "無法顯示登入畫面"
        case .missingToken:
            return "缺少 Token"
        case .unknown:
            return "發生未知錯誤，請稍後再試"
        case .notAuthenticated:
            return "用戶未登入"
        case .emailNotVerified:
            return "郵箱未驗證"
        }
    }
}
