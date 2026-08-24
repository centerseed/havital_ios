import Foundation

/// 應用的 API 環境與端點設定
struct APIConfig {
    /// 根據 Build Configuration 切換不同的 Base URL
    ///
    /// DEBUG build 另外接受 launch argument `-api_base_url <url>`（沿用 repo 既有的
    /// launch-argument harness 慣例）。用途：把模擬器指到本機 `./run.sh dev`，
    /// 驗證雲端 dev 尚未部署到的端點。RELEASE build 完全不看這個值。
    static var baseURL: String {
        #if DEBUG
        if let override = launchArgumentBaseURL {
            return override
        }
        // 開發環境
        return "https://api-service-364865009192.asia-east1.run.app"
        #else
        // 正式環境
        return "https://api-service-163961347598.asia-east1.run.app"
        #endif
    }

    #if DEBUG
    /// `-api_base_url http://localhost:5002` → `http://localhost:5002`
    private static var launchArgumentBaseURL: String? {
        let arguments = CommandLine.arguments
        guard let flagIndex = arguments.firstIndex(of: "-api_base_url"),
              arguments.index(after: flagIndex) < arguments.endIndex else {
            return nil
        }
        let value = arguments[arguments.index(after: flagIndex)]
        guard !value.isEmpty, URL(string: value) != nil else { return nil }
        // 尾斜線會讓 baseURL + path 產生 `//`，統一去掉
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }
    #endif
    
    /// 判斷是否為開發環境
    static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Garmin 功能開關
    /// 使用 Firebase Remote Config 動態控制功能開放
    static var isGarminEnabled: Bool {
        return FeatureFlagManager.shared.isGarminIntegrationAvailable
    }
}
