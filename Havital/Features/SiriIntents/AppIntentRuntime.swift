import Foundation
import FirebaseCore

/// App Intents 可能在 app 未前景時被喚起。主 target 的 @main init 通常已跑過 bootstrap，
/// 但為防背景啟動 race，intent perform() 開頭呼叫此 ensure，冪等。
///
/// Firebase 配置邏輯與 HavitalApp.init() 對齊：
///   1. GoogleService-Info.plist（標準名，優先）
///   2. GoogleService-Info-dev.plist / GoogleService-Info-prod.plist（依 DEBUG flag）
///   3. 退回 FirebaseApp.configure()（保底）
/// 這確保 dev/prod plist 選擇與主 app 一致，不會錯指 Firebase project。
enum AppIntentRuntime {
    private static let lock = NSLock()
    private static var ready = false

    static func ensureBootstrapped() {
        lock.lock(); defer { lock.unlock() }
        if ready { return }
        configureFirebaseIfNeeded()
        AppDependencyBootstrap.registerAllModules()  // idempotent: per-module isRegistered guards
        ready = true
    }

    // MARK: - Private

    private static func configureFirebaseIfNeeded() {
        guard FirebaseApp.app() == nil else { return }

        #if DEBUG
        let configFileName = "GoogleService-Info-dev"
        #else
        let configFileName = "GoogleService-Info-prod"
        #endif

        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            // Standard plist present (most common Xcode setup)
            FirebaseApp.configure()
        } else if let path = Bundle.main.path(forResource: configFileName, ofType: "plist"),
                  let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        } else {
            // Last-resort fallback; matches HavitalApp.init() fallback path
            FirebaseApp.configure()
        }
    }
}
