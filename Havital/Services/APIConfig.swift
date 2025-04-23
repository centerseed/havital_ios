import Foundation

/// 應用的 API 環境與端點設定
struct APIConfig {
    /// 根據 Build Configuration 切換不同的 Base URL
    static var baseURL: String {
        // TODO: 設定不同環境 Base URL
        return "https://api-service-364865009192.asia-east1.run.app"
    }
}
