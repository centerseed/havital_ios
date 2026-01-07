import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import Combine
import AuthenticationServices
import CryptoKit // For SHA256 nonce
import FirebaseMessaging // For FCM token
import FirebaseAnalytics // For user ID tracking

// MARK: - AuthenticationService Protocol
protocol AuthenticationServiceProtocol: AnyObject {
    var isAuthenticated: Bool { get }
    var appUser: User? { get }
    func signOut() async throws
}

/// ⚠️ DEPRECATED: Use AuthenticationViewModel and Repository pattern instead
/// - Presentation Layer: Use AuthenticationViewModel.shared for UI state
/// - Domain/Data Layer: Use AuthSessionRepository and AuthRepository via DependencyContainer
/// - LoginView: Temporary exception, will be migrated when Apple Sign In is refactored
@available(*, deprecated, message: "Use AuthenticationViewModel for UI state and AuthSessionRepository/AuthRepository for data access. See Features/Authentication/Presentation/ViewModels/AuthenticationViewModel.swift")
class AuthenticationService: NSObject, ObservableObject, TaskManageable, AuthenticationServiceProtocol {
    @Published var user: FirebaseAuth.User?
    @Published var appUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var loginError: Error?
    @Published var hasCompletedOnboarding = false
    @Published var isReonboardingMode = false // 新增：標識是否處於重新 Onboarding 模式

    // Demo 模式的 token（直接使用後端返回的 ID token）
    var demoIdToken: String?

    static let shared = AuthenticationService()
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String?

    // TaskManageable 協議實作 (Actor-based)
    let taskRegistry = TaskRegistry()
    
    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser
    private var userProfileRepository: UserProfileRepository {
        DependencyContainer.shared.resolve()
    }
    private var authSessionRepository: AuthSessionRepository {
        DependencyContainer.shared.resolve()
    }
    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
        super.init()

        // 🔒 檢測首次安裝並清除孤立的 Firebase session（必須在 listener 之前）
        Self.checkAndClearOrphanedSessionIfNeeded()

        // Listen to auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user

            // 🎯 如果是 Demo 模式，不要被 Firebase auth state 覆蓋
            if self.demoIdToken == nil {
                self.isAuthenticated = user != nil
            }

            Logger.firebase(
                "認證狀態變更",
                level: .info,
                labels: [
                    "module": "AuthenticationService",
                    "action": "auth_state_changed",
                    "user_id": user?.uid ?? "none"
                ],
                jsonPayload: [
                    "is_authenticated": user != nil,
                    "user_uid": user?.uid ?? "none",
                    "email": user?.email ?? "none"
                ]
            )

            // 設置或清除用戶ID追蹤
            self.setUserIDForAnalytics(user?.uid)

            if user != nil {
                Logger.firebase(
                    "用戶已認證 - 開始獲取用戶資料",
                    level: .info,
                    labels: [
                        "module": "AuthenticationService",
                        "action": "fetch_user_profile",
                        "user_id": user?.uid ?? "unknown"
                    ]
                )

                // If user is authenticated with Firebase, fetch their profile from backend
                self.fetchUserProfile()
                // 嘗試同步當前 FCM token (Clean Architecture: Service → Repository)
                if let token = Messaging.messaging().fcmToken {
                    Task {
                        do {
                            try await self.userProfileRepository.updateUserProfile(["fcm_token": token])
                            print("✅ 已於登入後同步 FCM token 到後端")
                        } catch {
                            print("⚠️ 登入後同步 FCM token 失敗: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                // 🎯 如果是 Demo 模式，不要清除用戶資料
                if self.demoIdToken == nil {
                    Logger.firebase(
                        "用戶未認證 - 清除用戶資料",
                        level: .info,
                        labels: [
                            "module": "AuthenticationService",
                            "action": "clear_user_data"
                        ]
                    )
                    self.appUser = nil
                } else {
                    print("🎯 [Demo] Firebase 無 session，但保持 Demo 用戶資料")
                }
            }
        }
        
        // 從 UserDefaults 讀取 hasCompletedOnboarding
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        // 注意：isReonboardingMode 不需要持久化，它是一個臨時狀態
    }

    // MARK: - 首次安裝檢測

    /// 檢測並清除孤立的 Firebase session
    ///
    /// ⚠️ 已禁用：這個檢測在 app 啟動早期執行時不可靠
    /// 原因：
    /// 1. Token 驗證需要網路請求，但此時網路可能還沒就緒
    /// 2. 即使增加超時時間，仍可能因為 Firebase SDK 初始化中而超時
    /// 3. 會誤判正常登入的用戶並強制登出
    /// 4. Firebase 本身會處理無效 session（API 調用時返回 401）
    ///
    /// 替代方案：
    /// - 只標記 hasLaunchedBefore，不做任何登出操作
    /// - 讓 Firebase 自己處理 session 有效性
    /// - 如果 token 真的無效，fetchUserProfile() 會失敗並自動登出（見 line 532-557）
    private static func checkAndClearOrphanedSessionIfNeeded() {
        let hasLaunchedBeforeKey = "hasLaunchedBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        let currentUser = Auth.auth().currentUser

        // 🔍 診斷資訊：記錄 Keychain 恢復狀態
        print("=== 🔍 認證狀態診斷 ===")
        print("UserDefaults.hasLaunchedBefore: \(hasLaunched)")
        print("Firebase.currentUser: \(currentUser != nil ? "存在" : "不存在")")
        if let user = currentUser {
            print("  - UID: \(user.uid)")
            print("  - Email: \(user.email ?? "無")")
        }
        print("======================")

        Logger.firebase(
            "檢查認證狀態",
            level: .info,
            labels: [
                "module": "AuthenticationService",
                "action": "check_auth_state"
            ],
            jsonPayload: [
                "has_launched_before": hasLaunched,
                "has_current_user": currentUser != nil,
                "current_user_uid": currentUser?.uid ?? "null",
                "current_user_email": currentUser?.email ?? "null"
            ]
        )

        // ✅ 簡化邏輯：只標記已啟動，不做任何登出操作
        // 如果 session 真的無效，fetchUserProfile() 會處理（見 line 532-557）
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
            print("✅ 標記為已啟動過")

            Logger.firebase(
                "標記為已啟動過",
                level: .info,
                labels: [
                    "module": "AuthenticationService",
                    "action": "mark_launched"
                ]
            )

            if currentUser != nil {
                print("ℹ️ 檢測到 Firebase session，將在後續 API 調用中驗證有效性")
                Logger.firebase(
                    "檢測到 Firebase session，延遲驗證",
                    level: .info,
                    labels: [
                        "module": "AuthenticationService",
                        "action": "detect_existing_session"
                    ],
                    jsonPayload: [
                        "user_uid": currentUser?.uid ?? "unknown"
                    ]
                )
            }
        }
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

    // MARK: - User ID Tracking for Analytics

    /// 設置用戶ID用於Firebase Analytics追蹤
    private func setUserIDForAnalytics(_ userID: String?) {
        Analytics.setUserID(userID)
        if let userID = userID {
            print("✅ 已設置Analytics用戶ID: \(userID)")
        } else {
            print("✅ 已清除Analytics用戶ID")
        }
    }
    
    func signInWithGoogle() async {
        await executeTask(id: TaskID("sign_in_google")) {
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

            // 設置用戶ID追蹤
            setUserIDForAnalytics(authResult.user.uid)

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
        await executeTask(id: TaskID("sign_in_apple")) {
            await self.performAppleSignIn()
        }
    }

    @MainActor // Ensure UI updates are on the main thread
    func demoLogin() async {
        await executeTask(id: TaskID("demo_login")) {
            await self.performDemoLogin()
        }
    }

    private func performDemoLogin() async {
        await MainActor.run {
            isLoading = true
            loginError = nil
        }

        do {
            // 步驟 1: 呼叫 Demo 登入 API
            print("🔵 [Demo Login] 步驟 1: 呼叫 /login/demo API")
            let response = try await EmailAuthService.shared.demoLogin()

            guard response.success else {
                print("❌ [Demo Login] API 返回 success=false")
                throw AuthError.unknown
            }

            print("✅ [Demo Login] API 調用成功")
            print("✅ [Demo Login] UID=\(response.data.user.uid)")
            print("✅ [Demo Login] Email=\(response.data.user.email)")
            print("✅ [Demo Login] idToken長度=\(response.data.idToken.count)")

            // 步驟 2: 直接使用後端返回的 ID token（不需要 signInWithCustomToken）
            print("🔵 [Demo Login] 步驟 2: 儲存 Demo ID token")
            self.demoIdToken = response.data.idToken
            
            // Clean Architecture: Sync Demo Token to Repository
            self.authSessionRepository.setDemoToken(response.data.idToken)

            // 設置用戶ID追蹤
            setUserIDForAnalytics(response.data.user.uid)

            Logger.firebase(
                "Demo 登入成功",
                level: .info,
                labels: [
                    "module": "AuthenticationService",
                    "action": "demo_login_success",
                    "user_id": response.data.user.uid
                ]
            )

            // 步驟 3: 獲取用戶資料（使用 demo token）
            print("🔵 [Demo Login] 步驟 3: 獲取用戶資料")
            let user = try await makeAPICall(User.self, path: "/user")

            print("✅ [Demo Login] 用戶資料獲取成功")
            print("✅ [Demo Login] 用戶名稱=\(user.displayName ?? "無")")
            print("🔍 [Demo Login] 🚨 Active Plan=\(user.activeWeeklyPlanId ?? "無") 🚨")
            print("✅ [Demo Login] Email=\(user.email ?? "無")")

            // 🎯 關鍵修復：Demo 模式強制跳過 onboarding
            print("🔵 [Demo Login] Demo 模式 - 強制設置 hasCompletedOnboarding=true")
            print("🔍 [Demo Login] 用戶 activeWeeklyPlanId: \(user.activeWeeklyPlanId ?? "無")")

            await MainActor.run {
                print("🔍 [Demo Login] 進入 MainActor.run，開始更新狀態...")
                print("🔍 [Demo Login] 更新前: isAuthenticated=\(self.isAuthenticated), hasCompletedOnboarding=\(self.hasCompletedOnboarding)")

                self.appUser = user
                print("🔍 [Demo Login] ✅ appUser 已設置")

                // ⚠️ Demo 模式：通常強制設置為 true，跳過 onboarding
                // 除 UI 測試要求 -resetOnboarding 時
                if CommandLine.arguments.contains("-resetOnboarding") {
                    print("🧪 [UI Test] 檢測到 -resetOnboarding，保留 hasCompletedOnboarding = false")
                    self.hasCompletedOnboarding = false
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                } else {
                    self.hasCompletedOnboarding = true
                    print("🔍 [Demo Login] ✅ hasCompletedOnboarding=true 已設置（Demo 模式強制）")
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
                print("🔍 [Demo Login] ✅ UserDefaults 已更新")

                // 🎯 最後才設置為已認證（確保 hasCompletedOnboarding 已更新）
                self.isAuthenticated = true
                print("🔍 [Demo Login] ✅ isAuthenticated=true 已設置")

                self.isLoading = false
                print("🔍 [Demo Login] ✅ isLoading=false 已設置")

                print("🔍 [Demo Login] 更新後: isAuthenticated=\(self.isAuthenticated), hasCompletedOnboarding=\(self.hasCompletedOnboarding)")
                print("🔍 [Demo Login] 🚨 最終檢查: appUser=\(self.appUser != nil), isReonboardingMode=\(self.isReonboardingMode) 🚨")
            }

            UserService.shared.syncUserPreferences(with: user)

            print("✅ [Demo Login] 登入流程完成")
            print("🔍 [Demo Login] 🚨 最終狀態: isAuthenticated=\(self.isAuthenticated), hasCompletedOnboarding=\(self.hasCompletedOnboarding) 🚨")

        } catch let error as AuthError {
            print("❌ [Demo Login] 失敗 (AuthError): \(error)")
            await MainActor.run {
                isLoading = false
                loginError = error
            }

            Logger.firebase(
                "Demo 登入失敗 (AuthError)",
                level: .error,
                labels: [
                    "module": "AuthenticationService",
                    "action": "demo_login_failed"
                ],
                jsonPayload: [
                    "error_type": "AuthError",
                    "error": error.localizedDescription
                ]
            )
        } catch {
            print("❌ [Demo Login] 失敗: \(error)")
            print("   錯誤類型: \(type(of: error))")
            print("   錯誤描述: \(error.localizedDescription)")

            await MainActor.run {
                isLoading = false
                loginError = error
            }

            Logger.firebase(
                "Demo 登入失敗",
                level: .error,
                labels: [
                    "module": "AuthenticationService",
                    "action": "demo_login_failed"
                ],
                jsonPayload: [
                    "error_type": String(describing: type(of: error)),
                    "error": error.localizedDescription
                ]
            )
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
        _ = await executeTask(id: TaskID("sync_user_backend")) {
            try await self.performUserSync(idToken: idToken)
        }
    }
    
    private func performUserSync(idToken: String) async throws {
        // 從後端取得完整用戶資料
        var user = try await makeAPICall(User.self, path: "/user")
        // 若後端未返回名稱或頭像，使用 Firebase 資料更新後端
        if let firebaseUser = Auth.auth().currentUser {
            var updateData = [String: Any]()
            if user.displayName == nil, let name = firebaseUser.displayName {
                updateData["display_name"] = name
            }
            if user.photoUrl == nil, let photo = firebaseUser.photoURL?.absoluteString {
                updateData["photo_url"] = photo
            }
            if !updateData.isEmpty {
                // Clean Architecture: Service → Repository
                try await userProfileRepository.updateUserProfile(updateData)
                // 重新抓取更新後的用戶資料
                user = try await makeAPICall(User.self, path: "/user")
            }
        }
        await MainActor.run {
            self.appUser = user
        }
        // 更新 onboarding 與用戶偏好
        checkOnboardingStatus(user: user)
        UserService.shared.syncUserPreferences(with: user)

        // 在用戶資料完全載入後檢查 Garmin 和 Strava 連線狀態
        await checkGarminConnectionAfterUserData()
        await checkStravaConnectionAfterUserData()

        // 檢查數據源綁定狀態（僅在 onboarding 完成後）
        await checkDataSourceBinding(user: user)

    }
    
    // 檢查用戶是否已完成 onboarding
    // 檢查用戶是否已完成 onboarding，並在完成時重設 isReonboardingMode
    private func checkOnboardingStatus(user: User) {
        // 如果用戶有 active_weekly_plan_id，則表示已完成 onboarding
        let completed = user.activeWeeklyPlanId != nil

        print("🔍 檢查 onboarding 狀態 - activeWeeklyPlanId: \(String(describing: user.activeWeeklyPlanId))")
        print("🔍 當前 hasCompletedOnboarding: \(hasCompletedOnboarding), 新值: \(completed)")

        Logger.firebase(
            "檢查 onboarding 狀態",
            level: .info,
            labels: [
                "module": "AuthenticationService",
                "action": "check_onboarding_status",
                "user_id": self.user?.uid ?? "unknown"
            ],
            jsonPayload: [
                "active_weekly_plan_id": user.activeWeeklyPlanId ?? "null",
                "has_completed_onboarding": completed,
                "previous_has_completed_onboarding": hasCompletedOnboarding,
                "is_reonboarding_mode": isReonboardingMode
            ]
        )

        // ⚠️ CRITICAL FIX: 如果前端已經設置為 true，不要被後端的 nil 覆蓋
        // 這可能是因為後端還沒來得及更新 activeWeeklyPlanId
        // 只允許從 false → true，或 true → true，不允許 true → false（除非明確重置）
        let shouldUpdate = completed || !hasCompletedOnboarding

        if !shouldUpdate {
            print("⚠️ 前端已標記 onboarding 完成，但後端 activeWeeklyPlanId 為空。保持前端狀態，不覆蓋。")
            Logger.firebase(
                "保持前端 onboarding 狀態",
                level: .warn,
                labels: [
                    "module": "AuthenticationService",
                    "action": "skip_onboarding_status_update"
                ],
                jsonPayload: [
                    "reason": "frontend_already_completed",
                    "backend_active_weekly_plan_id": user.activeWeeklyPlanId ?? "null"
                ]
            )
            return
        }

        // 在主線程更新狀態並儲存到 UserDefaults
        Task { @MainActor in
            print("🔄 更新 onboarding 狀態: \(completed)")
            self.hasCompletedOnboarding = completed
            UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")

            Logger.firebase(
                completed ? "用戶已完成 onboarding" : "用戶未完成 onboarding",
                level: completed ? .info : .warn,
                labels: [
                    "module": "AuthenticationService",
                    "action": "update_onboarding_status",
                    "user_id": self.user?.uid ?? "unknown"
                ],
                jsonPayload: [
                    "has_completed_onboarding": completed,
                    "is_reonboarding_mode": self.isReonboardingMode
                ]
            )

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

        Logger.firebase(
            "開始獲取用戶資料",
            level: .info,
            labels: [
                "module": "AuthenticationService",
                "action": "fetch_user_profile_start",
                "user_id": user?.uid ?? "unknown"
            ]
        )

        // Wrap the entire publisher in a Task with TaskLocal context
        Task {
            await APICallTracker.$currentSource.withValue("AuthenticationService: fetchUserProfile") {
                UserService.shared.getUserProfile()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("無法獲取用戶資料: \(error)")

                    Logger.firebase(
                        "獲取用戶資料失敗",
                        level: .error,
                        labels: [
                            "module": "AuthenticationService",
                            "action": "fetch_user_profile_failed",
                            "user_id": self?.user?.uid ?? "unknown"
                        ],
                        jsonPayload: [
                            "error": error.localizedDescription,
                            "error_type": String(describing: type(of: error))
                        ]
                    )

                    // 判斷是否需要重置認證狀態
                    guard let self = self else { return }

                    // 1. 解析錯誤：後端回應格式變更
                    if error is DecodingError {
                        Logger.firebase(
                            "DecodingError - 重置認證狀態",
                            level: .warn,
                            labels: [
                                "module": "AuthenticationService",
                                "action": "reset_auth_decoding_error"
                            ]
                        )
                        self.appUser = nil
                        self.isAuthenticated = false
                        return
                    }

                    // 2. 認證錯誤 (401/403)：Token 無效或已撤銷
                    if let httpError = error as? HTTPError {
                        switch httpError {
                        case .unauthorized, .forbidden:
                            Logger.firebase(
                                "認證錯誤 - 重置認證狀態並登出 Firebase",
                                level: .warn,
                                labels: [
                                    "module": "AuthenticationService",
                                    "action": "reset_auth_http_error",
                                    "user_id": self.user?.uid ?? "unknown"
                                ],
                                jsonPayload: [
                                    "error_type": String(describing: httpError)
                                ]
                            )

                            // 清除 Firebase session（同步）
                            do {
                                try Auth.auth().signOut()
                                print("✅ 已登出 Firebase（因為 API 認證失敗）")
                            } catch {
                                print("⚠️ Firebase 登出失敗: \(error.localizedDescription)")
                            }

                            self.appUser = nil
                            self.isAuthenticated = false
                        default:
                            // 其他 HTTP 錯誤（網路、伺服器錯誤等）不重置認證
                            break
                        }
                    }
                }
            } receiveValue: { [weak self] user in
                self?.appUser = user

                Logger.firebase(
                    "成功獲取用戶資料",
                    level: .info,
                    labels: [
                        "module": "AuthenticationService",
                        "action": "fetch_user_profile_success",
                        "user_id": self?.user?.uid ?? "unknown"
                    ],
                    jsonPayload: [
                        "has_active_weekly_plan": user.activeWeeklyPlanId != nil,
                        "active_weekly_plan_id": user.activeWeeklyPlanId ?? "null",
                        "current_has_completed_onboarding": self?.hasCompletedOnboarding ?? false
                    ]
                )

                // 檢查 onboarding 狀態
                self?.checkOnboardingStatus(user: user)

                // 同步用戶偏好
                UserService.shared.syncUserPreferences(with: user)

                // 在用戶資料載入完成後檢查 Garmin 和 Strava 連線狀態
                Task {
                    await self?.checkGarminConnectionAfterUserData()
                    await self?.checkStravaConnectionAfterUserData()

                    // 檢查數據源綁定狀態（僅在 onboarding 完成後）
                    await self?.checkDataSourceBinding(user: user)
                }
            }
            .store(in: &cancellables)
            }
        }
    }
    
    deinit {
        cancelAllTasks()
        cancellables.removeAll()
    }
    
    func signOut() async throws {
        // 登出時只清除本地 Garmin 狀態，不解除後端綁定
        // 這樣用戶重新登入時可以恢復 Garmin 連接
        if GarminManager.shared.isConnected {
            print("🔄 登出時清除本地 Garmin 狀態（保留後端連接）")
            await GarminManager.shared.disconnect(remote: false)
        }
        
        // ⚠️ 重要: 先設置 isAuthenticated = false,避免顯示 onboarding
        isAuthenticated = false

        try Auth.auth().signOut()
        try GIDSignIn.sharedInstance.signOut()

        // 清除用戶ID追蹤
        setUserIDForAnalytics(nil)

        // 在登出時重置各種狀態
        appUser = nil
        hasCompletedOnboarding = false
        isReonboardingMode = false
        isReonboardingMode = false
        demoIdToken = nil // 清除 Demo token
        
        // Clean Architecture: Clear Demo Token in Repository
        authSessionRepository.setDemoToken(nil)

        print("🔄 已清除所有認證狀態（包括 Demo token）")
        
        // 清除所有 UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        // 使用 CacheEventBus 統一清除所有快取
        CacheEventBus.shared.invalidateCache(for: .userLogout)

        // 清除非快取相關的本地存儲
        await UserPreferencesManager.shared.clearAllData()
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
            // IMPORTANT: Do NOT set hasCompletedOnboarding to false.
            // That flag controls the root view in ContentView.
            // We only want to show the re-onboarding sheet.
            self.isReonboardingMode = true
            OnboardingCoordinator.shared.isReonboarding = true
            print("AuthenticationService: 啟動重新 Onboarding 模式")
        }
    }

    func cancelReonboarding() {
        Task { @MainActor in
            self.isReonboardingMode = false
            print("AuthenticationService: 取消重新 Onboarding 模式")
        }
    }


    func getIdToken() async throws -> String {
        // 優先使用 Demo token（如果存在）
        if let demoToken = demoIdToken {
            return demoToken
        }

        // 否則使用 Firebase token
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }

        // 使用 Firebase SDK 的標準行為（會自動管理 token 刷新）
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
    
    /// 檢查 Garmin 連線狀態（在獲取用戶資料後）
    private func checkGarminConnectionAfterUserData() async {
        // 確保用戶資料已經載入完成
        guard appUser != nil else {
            print("⚠️ 用戶資料尚未載入，跳過 Garmin 狀態檢查")
            return
        }
        
        print("🔍 用戶資料載入完成後檢查 Garmin 連線狀態")
        
        // 顯示當前用戶資訊，檢查是否為用戶身份問題
        if let firebaseUser = Auth.auth().currentUser {
            print("  - Firebase UID: \(firebaseUser.uid)")
            print("  - Provider: \(firebaseUser.providerData.map { $0.providerID })")
            print("  - Email: \(firebaseUser.email ?? "nil")")
        }
        
        // 如果用戶偏好設定為 Garmin，檢查後端的 Garmin 連接狀態
        if UserPreferencesManager.shared.dataSourcePreference == .garmin {
            print("🔍 用戶偏好為 Garmin，檢查連接狀態...")
            await GarminManager.shared.checkConnectionStatus()
            
            // checkConnectionStatus 完成後，檢查是否需要顯示不一致警告
            await MainActor.run {
                if !GarminManager.shared.isConnected && GarminManager.shared.needsReconnection {
                    print("⚠️ Garmin 連接狀態異常，顯示重新綁定提示")
                    NotificationCenter.default.post(
                        name: .garminDataSourceMismatch,
                        object: nil
                    )
                } else if GarminManager.shared.isConnected {
                    print("✅ Garmin 連接狀態正常")
                }
            }
        } else {
            print("🔍 用戶偏好不是 Garmin (\(UserPreferencesManager.shared.dataSourcePreference.displayName))，跳過 Garmin 狀態檢查")
        }
    }

    private func checkStravaConnectionAfterUserData() async {
        // 確保用戶資料已經載入完成
        guard appUser != nil else {
            print("⚠️ 用戶資料尚未載入，跳過 Strava 狀態檢查")
            return
        }

        print("🔍 用戶資料載入完成後檢查 Strava 連線狀態")

        // 如果用戶偏好設定為 Strava，檢查後端的 Strava 連接狀態
        if UserPreferencesManager.shared.dataSourcePreference == .strava {
            print("🔍 用戶偏好為 Strava，檢查連接狀態...")
            await StravaManager.shared.checkConnectionStatus()

            // checkConnectionStatus 完成後，檢查連接狀態
            await MainActor.run {
                if StravaManager.shared.isConnected {
                    print("✅ Strava 連接狀態正常")
                } else {
                    print("⚠️ Strava 連接狀態異常")
                }
            }
        } else {
            print("🔍 用戶偏好不是 Strava，跳過 Strava 狀態檢查")
        }
    }

    /// 檢查數據源綁定狀態（僅在 onboarding 完成後執行）
    private func checkDataSourceBinding(user: User) async {
        // 只有在已完成 onboarding 的情況下才檢查
        guard hasCompletedOnboarding else {
            print("⏭️ Onboarding 未完成，跳過數據源綁定檢查")
            return
        }

        print("🔍 檢查數據源綁定狀態...")

        // 檢查後端的 data_source 字段
        let backendDataSource = user.dataSource

        print("  - 後端 data_source: \(backendDataSource ?? "nil")")
        print("  - 本地偏好: \(UserPreferencesManager.shared.dataSourcePreference.rawValue)")

        // 如果後端沒有設定數據源，發送通知提示用戶綁定
        if backendDataSource == nil || backendDataSource == "unbound" {
            print("⚠️ 檢測到未綁定數據源，發送通知提示用戶")

            await MainActor.run {
                NotificationCenter.default.post(
                    name: .dataSourceNotBound,
                    object: nil
                )
            }

            Logger.firebase("檢測到未綁定數據源", level: .warn, labels: [
                "module": "AuthenticationService",
                "action": "checkDataSourceBinding",
                "backend_data_source": backendDataSource ?? "nil",
                "local_preference": UserPreferencesManager.shared.dataSourcePreference.rawValue
            ])
        } else {
            print("✅ 數據源已綁定: \(backendDataSource!)")

            // 如果後端有設定但本地沒有，同步到本地
            if let dataSourceString = backendDataSource,
               let dataSourceType = DataSourceType(rawValue: dataSourceString),
               UserPreferencesManager.shared.dataSourcePreference != dataSourceType {

                print("🔄 後端數據源與本地不一致，同步到本地: \(dataSourceType.displayName)")
                UserPreferencesManager.shared.dataSourcePreference = dataSourceType
            }
        }
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

                // 設置用戶ID追蹤
                self.setUserIDForAnalytics(authResult.user.uid)

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
