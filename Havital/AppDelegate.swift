import UIKit
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
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
            syncFCMTokenToBackend(existingToken)
        }

        return true
    }
    
    // 將 APNs deviceToken 提供給 Firebase
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    private func syncFCMTokenToBackend(_ fcmToken: String) {
        guard AuthenticationService.shared.isAuthenticated else {
            print("使用者尚未登入，暫不上傳 FCM token")
            return
        }
        Task {
            do {
                try await UserService.shared.updateUserData(["fcm_token": fcmToken])
                print("✅ FCM token 已成功上傳到後端")
            } catch {
                print("❌ 上傳 FCM token 失敗: \(error.localizedDescription)")
            }
        }
    }

    // 監聽 FCM token 更新
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("📲 收到新的 FCM token: \(fcmToken)")
        syncFCMTokenToBackend(fcmToken)
    }
} 