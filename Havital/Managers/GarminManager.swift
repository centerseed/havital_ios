import Foundation
import SafariServices
import SwiftUI
import CryptoKit

class GarminManager: NSObject, ObservableObject {
    static let shared = GarminManager()
    
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var isConnected = false
    @Published var pendingForceReplace: (state: String, existingUserId: String, errorDescription: String)?
    @Published var garminAlreadyBoundMessage: String? = nil
    
    // OAuth 2.0 PKCE 參數
    private var codeVerifier: String?
    private var state: String?
    private var safariViewController: SFSafariViewController?
    
    // Garmin OAuth 配置
    private let garminAuthURL = "https://connect.garmin.com/oauth2Confirm"
    private let scope = "activity_read"
    
    // 環境相關配置
    private let clientID: String
    private let redirectURI: String
    
    override init() {
        // 根據環境讀取對應的 Garmin Client ID
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            
            // 根據 build configuration 選擇對應的 Client ID
            let clientIDKey: String
            #if DEBUG
            clientIDKey = "GarminClientID_Dev"
            #else
            clientIDKey = "GarminClientID_Prod"
            #endif
            
            if let garminClientID = plist[clientIDKey] as? String,
               !garminClientID.isEmpty {
                self.clientID = garminClientID
                print("✅ GarminManager: 成功讀取 \(clientIDKey): \(garminClientID)")
            } else {
                // 如果正式環境的 Client ID 為空，使用佔位符
                self.clientID = "GARMIN_CLIENT_ID_NOT_SET"
                print("⚠️ 警告：\(clientIDKey) 未設定或為空，Garmin 功能將不可用")
            }
        } else {
            self.clientID = "GARMIN_CLIENT_ID_NOT_SET"
            print("❌ 錯誤：無法讀取 APIKeys.plist")
        }
        
        // 根據環境設定重定向 URI
        #if DEBUG
        self.redirectURI = "https://api-service-364865009192.asia-east1.run.app/connect/garmin/redirect"
        #else
        self.redirectURI = "https://api-service-163961347598.asia-east1.run.app/connect/garmin/redirect"
        #endif
        
        super.init()
        // 檢查連接狀態
        loadConnectionStatus()
    }
    
    /// 檢查 Client ID 是否有效（不為空且不是佔位符）
    var isClientIDValid: Bool {
        return !clientID.isEmpty && clientID != "GARMIN_CLIENT_ID_NOT_SET"
    }
    
    // MARK: - 連接狀態管理
    
    private func loadConnectionStatus() {
        // 從 UserDefaults 讀取連接狀態
        isConnected = UserDefaults.standard.bool(forKey: "garmin_connected")
        
        // 如果已經連接，清除任何舊的錯誤信息
        if isConnected {
            connectionError = nil
            Logger.firebase("Garmin 連接狀態已載入，清除舊錯誤信息", level: .info, labels: [
                "module": "GarminManager",
                "action": "loadConnectionStatus",
                "isConnected": "true"
            ])
        }
    }
    
    private func saveConnectionStatus(_ connected: Bool) {
        UserDefaults.standard.set(connected, forKey: "garmin_connected")
        isConnected = connected
    }
    
    /// 清除連接錯誤信息
    func clearConnectionError() {
        connectionError = nil
    }
    
    // MARK: - OAuth 2.0 PKCE 流程
    
    // 產生 state 字串（JSON encode + base64）
    private func buildState(forceReplace: Bool, customState: String?) -> String {
        var stateDict: [String: Any] = [
            "pkce_state": customState ?? generateState()
        ]
        if forceReplace {
            stateDict["force_replace"] = true
        }
        let stateData = try! JSONSerialization.data(withJSONObject: stateDict)
        return stateData.base64EncodedString()
    }

    /// 開始 Garmin 連接流程
    func startConnection(force: Bool = false, state: String? = nil) async {
        print("🔧 GarminManager: 開始連接流程 (force: \(force), state: \(state ?? "nil"))")
        
        // 檢查 Client ID 是否有效
        guard isClientIDValid else {
            await MainActor.run {
                connectionError = "Garmin 功能暫時不可用，請稍後再試"
                print("❌ GarminManager: Client ID 無效，無法啟動連接流程")
            }
            return
        }
        
        await MainActor.run {
            isConnecting = true
            connectionError = nil
        }
        
        do {
            print("🔧 GarminManager: 使用 Client ID: \(clientID)")
            print("🔧 GarminManager: 回調 URL: \(redirectURI)")
            
            // 生成 PKCE 參數
            let verifier = generateCodeVerifier()
            let challenge = generateCodeChallenge(from: verifier)
            // 用 buildState 產生 stateString
            let stateString = buildState(forceReplace: force, customState: state)
            
            print("🔧 GarminManager: 生成 PKCE 參數")
            print("  - Code Verifier: \(verifier)")
            print("  - Code Challenge: \(challenge)")
            print("  - State: \(stateString)")
            
            // 儲存參數以供後續使用
            codeVerifier = verifier
            self.state = stateString
            
            // 建構授權 URL
            let authURL = try buildAuthorizationURL(
                codeChallenge: challenge,
                state: stateString
            )
            
            print("🔧 GarminManager: 完整授權 URL: \(authURL)")
            print("🔧 GarminManager: URL 組件:")
            if let components = URLComponents(url: authURL, resolvingAgainstBaseURL: false) {
                print("  - Scheme: \(components.scheme ?? "nil")")
                print("  - Host: \(components.host ?? "nil")")
                print("  - Path: \(components.path)")
                print("  - Query Items:")
                components.queryItems?.forEach { item in
                    print("    - \(item.name): \(item.value ?? "nil")")
                }
            }
            
            // 在主線程打開 Safari
            await MainActor.run {
                presentSafariViewController(with: authURL)
            }
            
        } catch {
            print("❌ GarminManager: 初始化連接失敗: \(error)")
            await MainActor.run {
                isConnecting = false
                connectionError = "初始化連接失敗: \(error.localizedDescription)"
            }
        }
    }
    
    /// 處理深度連結回調（從後端重定向）
    func handleCallback(url: URL) async {
        print("GarminManager: 收到回調 URL: \(url)")
        
        // 關閉 Safari 視圖
        await MainActor.run {
            safariViewController?.dismiss(animated: true)
            safariViewController = nil
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            await handleConnectionError("無效的回調 URL")
            return
        }
        
        // 提取參數 - 現在是從後端傳來的結果
        let error = queryItems.first { $0.name == "error" }?.value
        let errorDescription = queryItems.first { $0.name == "error_description" }?.value ?? "該 Garmin Connect™ 帳號已經綁定至另一個 Paceriz 帳號。請先使用原本綁定的 Paceriz 帳號登入，並在個人資料頁解除 Garmin Connect™ 綁定後，再用本帳號進行連接。"
        let canForceReplace = queryItems.first { $0.name == "can_force_replace" }?.value
        let state = queryItems.first { $0.name == "state" }?.value
        let existingUserId = queryItems.first { $0.name == "existing_user_id" }?.value
        
        // 檢查是否需要強制綁定
        if error == "account_already_connected" {
            if canForceReplace == "true", let state = state, let existingUserId = existingUserId {
                await MainActor.run {
                    self.pendingForceReplace = (state, existingUserId, errorDescription)
                }
            } else {
                await MainActor.run {
                    self.garminAlreadyBoundMessage = errorDescription
                    self.pendingForceReplace = nil
                }
            }
            return
        }
        
        // 檢查是否有錯誤
        if let error = error {
            await handleConnectionError("Garmin 授權失敗: \(error)")
            return
        }
        
        // 驗證 state 參數（如果後端有提供的話）
        if let receivedState = state {
            guard receivedState == self.state else {
                await handleConnectionError("安全驗證失敗")
                return
            }
            print("✅ State 驗證成功")
        } else {
            print("⚠️ 後端未提供 state 參數，跳過驗證（建議後端補上）")
        }
        
        // 原有的 success/failure 處理
        let success = queryItems.first { $0.name == "success" }?.value
        if success == "true" {
            // 後端已經處理完成，直接更新狀態
            await MainActor.run {
                saveConnectionStatus(true)
                clearStoredCredentials()
                isConnecting = false
                connectionError = nil  // 清除之前的錯誤信息
                
                print("✅ Garmin 連接成功")
                
                // 記錄連接成功和錯誤清除
                Logger.firebase("Garmin 連接成功，錯誤信息已清除", level: .info, labels: [
                    "module": "GarminManager",
                    "action": "handleCallback",
                    "result": "success"
                ])
                
                // 連接成功後自動切換到Garmin數據源
                UserPreferenceManager.shared.dataSourcePreference = .garmin
                
                // 同步到後端
                Task {
                    do {
                        try await UserService.shared.updateDataSource(DataSourceType.garmin.rawValue)
                        print("數據源設定已同步到後端: Garmin")
                    } catch {
                        print("同步Garmin數據源設定到後端失敗: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            await handleConnectionError("Garmin 連接失敗")
        }
    }
    
    /// 中斷 Garmin 連接
    /// - Parameter remote: 是否呼叫後端 API。預設 true；若已在其他地方成功解除綁定，可傳入 false 僅做本地狀態清理。
    func disconnect(remote: Bool = true) async {
        await MainActor.run {
            isConnecting = true
            connectionError = nil
        }
        
        // 若僅需本地清理，直接更新狀態並返回
        guard remote else {
            await MainActor.run {
                saveConnectionStatus(false)
                clearStoredCredentials()
                isConnecting = false
                print("Garmin 本地連接狀態已重置")
            }
            return
        }

        do {
            // 呼叫後端 API 移除連接 (使用 RESTful 標準)
            let response = try await APIClient.shared.requestWithStatus(
                path: "/connect/garmin",
                method: "DELETE"
            )
            
            if (200...299).contains(response.statusCode) {
                await MainActor.run {
                    saveConnectionStatus(false)
                    clearStoredCredentials()
                    isConnecting = false
                    
                    print("Garmin 連接已中斷")
                }
            } else {
                throw NSError(domain: "GarminManager", code: response.statusCode, 
                             userInfo: [NSLocalizedDescriptionKey: "中斷連接失敗"])
            }
            
        } catch {
            await MainActor.run {
                isConnecting = false
                connectionError = "中斷連接失敗: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func generateCodeVerifier() -> String {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return data.base64URLEncodedString()
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64URLEncodedString()
    }
    
    private func generateState() -> String {
        let data = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        return data.base64URLEncodedString()
    }
    
    private func buildAuthorizationURL(codeChallenge: String, state: String) throws -> URL {
        // 先將 PKCE 參數傳送給後端儲存
        Task {
            await storePKCEParameters(codeVerifier: codeVerifier!, codeChallenge: codeChallenge, state: state)
        }
        
        guard var components = URLComponents(string: garminAuthURL) else {
            throw NSError(domain: "GarminManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "無效的 Garmin 授權 URL"])
        }
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let url = components.url else {
            throw NSError(domain: "GarminManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "無法建構授權 URL"])
        }
        
        return url
    }
    
    /// 將 PKCE 參數發送給後端儲存
    private func storePKCEParameters(codeVerifier: String, codeChallenge: String, state: String) async {
        do {
            let requestData = [
                "code_verifier": codeVerifier,
                "code_challenge": codeChallenge,
                "state": state
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            
            let response = try await APIClient.shared.requestWithStatus(
                path: "/connect/garmin/store-pkce",
                method: "POST",
                body: jsonData
            )
            
            if (200...299).contains(response.statusCode) {
                print("✅ PKCE 參數已發送給後端")
            } else {
                print("⚠️ 發送 PKCE 參數失敗：\(response.statusCode)")
            }
            
        } catch {
            print("❌ 發送 PKCE 參數錯誤：\(error)")
        }
    }
    
    private func presentSafariViewController(with url: URL) {
        print("🔧 GarminManager: 嘗試顯示 Safari 視圖")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ GarminManager: 無法獲取視窗場景或視窗")
            connectionError = "無法顯示授權頁面"
            isConnecting = false
            return
        }
        
        // 找到最頂層的視圖控制器
        var presentingViewController = window.rootViewController
        while let presented = presentingViewController?.presentedViewController {
            presentingViewController = presented
        }
        
        print("🔧 GarminManager: 找到頂層視圖控制器: \(String(describing: presentingViewController))")
        
        guard let topViewController = presentingViewController else {
            print("❌ GarminManager: 無法找到可用的視圖控制器")
            connectionError = "無法顯示授權頁面"
            isConnecting = false
            return
        }
        
        print("🔧 GarminManager: 創建 Safari 視圖控制器")
        
        safariViewController = SFSafariViewController(url: url)
        safariViewController?.delegate = self
        safariViewController?.modalPresentationStyle = .pageSheet
        
        print("🔧 GarminManager: 準備在頂層視圖控制器上顯示 Safari 視圖")
        topViewController.present(safariViewController!, animated: true) {
            print("✅ GarminManager: Safari 視圖已顯示")
        }
    }
    
    // 由於現在後端處理整個 OAuth 流程，這個方法已不需要
    // 保留作為參考，但實際上不會被調用
    private func completeConnection(authorizationCode: String) async {
        // 這個方法已由後端處理，不再需要客戶端調用
        print("⚠️ completeConnection 已被後端處理取代")
    }
    
    private func handleConnectionError(_ message: String) async {
        await MainActor.run {
            isConnecting = false
            connectionError = message
            clearStoredCredentials()
        }
    }
    
    private func clearStoredCredentials() {
        codeVerifier = nil
        state = nil
    }
}

// MARK: - SFSafariViewControllerDelegate

extension GarminManager: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // 用戶手動關閉了 Safari 視圖
        print("🔧 GarminManager: 用戶手動關閉了 Safari 視圖")
        Task {
            await MainActor.run {
                isConnecting = false
                clearStoredCredentials()
            }
        }
    }
    
    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
        print("🔧 GarminManager: Safari 初始載入重定向到: \(URL)")
    }
    
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        print("🔧 GarminManager: Safari 初始載入完成，成功: \(didLoadSuccessfully)")
    }
}

// MARK: - Data Extensions for Base64URL encoding

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
} 