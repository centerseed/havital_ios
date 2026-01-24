import UIKit
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    // MARK: - Clean Architecture Dependencies
    private let userProfileRepository: UserProfileRepository
    private let authSessionRepository: AuthSessionRepository

    // 防止重複上傳相同的 FCM token
    private var lastUploadedFCMToken: String?

    override init() {
        // 初始化 Repository (在 super.init() 之前)
        self.userProfileRepository = DependencyContainer.shared.resolve()
        self.authSessionRepository = DependencyContainer.shared.resolve()
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 設定 Firebase Messaging 代理
        Messaging.messaging().delegate = self
        
        // 向 APNs 註冊遠端通知
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知權限請求失敗: \(error.localizedDescription)")
            }
            print("通知權限\(granted ? "已允許" : "被拒絕")")
            // 無論是否允許，都嘗試向 APNs 註冊，iOS 會自行判斷
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }

        // 初次先嘗試取得現有 FCM token（若已產生）並同步
        if let existingToken = Messaging.messaging().fcmToken {
            print("🔍 DEBUG: 應用啟動時發現現有 FCM token: \(existingToken.prefix(20))...")
            syncFCMTokenToBackend(existingToken)
        } else {
            print("🔍 DEBUG: 應用啟動時尚無 FCM token")
        }

        return true
    }
    
    // 將 APNs deviceToken 提供給 Firebase
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    private func syncFCMTokenToBackend(_ fcmToken: String) {
        // 防止重複上傳相同的 token
        guard fcmToken != lastUploadedFCMToken else {
            print("🔍 DEBUG: FCM token 未變更，跳過上傳")
            return
        }

        print("🔍 DEBUG: 嘗試上傳 FCM token: \(fcmToken.prefix(20))...")

        // Clean Architecture: Use AuthSessionRepository instead of AuthenticationService
        let isAuthenticated = authSessionRepository.isAuthenticated()
        print("🔍 DEBUG: 用戶認證狀態: \(isAuthenticated)")

        guard isAuthenticated else {
            print("使用者尚未登入，暫不上傳 FCM token")
            return
        }

        // ✅ CRITICAL FIX: 在開始上傳前就標記，防止重複調用
        // 如果上傳失敗，會在 catch 中清除，下次重試
        lastUploadedFCMToken = fcmToken

        Task {
            await TrackedTask("AppDelegate: syncFCMTokenToBackend") {
                do {
                    // ✅ 優化：FCM token 更新不需要返回完整的 User，丟棄返回值
                    _ = try await self.userProfileRepository.updateUserProfile(["fcm_token": fcmToken])
                    print("✅ 已於登入後同步 FCM token 到後端")
                } catch {
                    // ⚠️ 上傳失敗，清除標記，下次重試
                    self.lastUploadedFCMToken = nil
                    print("❌ 上傳 FCM token 失敗: \(error.localizedDescription)")
                }
            }.value
        }
    }

    // 監聽 FCM token 更新
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("📲 收到新的 FCM token: \(fcmToken)")
        syncFCMTokenToBackend(fcmToken)
    }
} 