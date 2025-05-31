import Foundation

/// 應用的 API 環境與端點設定
struct APIConfig {
    /// 根據 Build Configuration 切換不同的 Base URL
    static var baseURL: String {
        #if DEBUG
        // 開發環境
        return "https://api-service-364865009192.asia-east1.run.app"
        #else
        // 正式環境
        return "https://api-service-163961347598.asia-east1.run.app"
        #endif
    }
    
    /// 判斷是否為開發環境
    static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
