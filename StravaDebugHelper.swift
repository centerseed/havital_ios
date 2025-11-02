import Foundation

/// Strava 調試助手 - 用於排查連接問題
class StravaDebugHelper {
    private let clientID = "175355"
    private let redirectURI = "https://api-service-364865009192.asia-east1.run.app/connect/strava/redirect"
    
    /// 打印當前配置信息
    func printConfiguration() {
        print("🔍 Strava 調試信息")
        print("================")
        print("Client ID: \(clientID)")
        print("重定向 URI: \(redirectURI)")
        print("調試時間: \(Date())")
        print("")
        
        print("📋 檢查清單：")
        print("1. Strava 開發者控制台 (https://www.strava.com/settings/api)")
        print("2. Authorization Callback Domain 應設為: api-service-364865009192.asia-east1.run.app")
        print("3. 檢查 Connected Athletes 數量")
        print("4. 如果已有連接用戶，需要撤銷")
        print("")
        
        // 生成測試 URL
        let testURL = generateAuthURL(state: "debug_\(Int(Date().timeIntervalSince1970))")
        print("🔗 測試 URL:")
        print(testURL)
        print("")
        
        print("⚠️ 常見問題：")
        print("- 錯誤 403 '已超過運動同好連接上限' = 應用已達用戶限制")
        print("- 重定向 URI 不匹配 = Strava 控制台設定錯誤")
        print("- 應用狀態異常 = 可能需要重新創建應用")
    }
    
    /// 生成授權 URL
    func generateAuthURL(state: String) -> String {
        let params = [
            "client_id": clientID,
            "response_type": "code",
            "redirect_uri": redirectURI,
            "scope": "activity:read_all,profile:read_all",
            "state": state
        ]
        
        let queryString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        return "https://www.strava.com/oauth/authorize?\(queryString)"
    }
    
    /// 檢查後端端點
    func checkBackendEndpoint() async {
        print("🔍 檢查後端端點...")
        
        guard let url = URL(string: redirectURI) else {
            print("❌ 無效的重定向 URI")
            return
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ 後端端點回應: \(httpResponse.statusCode)")
            }
        } catch {
            print("⚠️ 後端端點測試失敗: \(error.localizedDescription)")
        }
    }
}

// 使用示例
extension StravaDebugHelper {
    static func runDiagnostics() async {
        let helper = StravaDebugHelper()
        helper.printConfiguration()
        await helper.checkBackendEndpoint()
        
        print("")
        print("🎯 下一步行動：")
        print("1. 複製上面的測試 URL 到瀏覽器")
        print("2. 觀察是否出現 '已超過運動同好連接上限' 錯誤")
        print("3. 如果出現，檢查 Strava 控制台中的 Connected Athletes")
        print("4. 撤銷所有現有連接後重試")
    }
}