import Foundation
import SafariServices
import SwiftUI
import CommonCrypto

class StravaManager: NSObject, ObservableObject {
    static let shared = StravaManager()
    
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var isConnected = false
    @Published var pendingForceReplace: (state: String, existingUserId: String, errorDescription: String)?
    @Published var stravaAlreadyBoundMessage: String? = nil
    @Published var needsReconnection = false {
        didSet {
            print("🔄 needsReconnection 狀態變更: \(oldValue) -> \(needsReconnection)")
            if needsReconnection {
                print("📍 設置為 true 的位置:")
                Thread.callStackSymbols.prefix(5).forEach { print("  \($0)") }
            }
        }
    }
    @Published var reconnectionMessage: String? = nil

    // OAuth 2.0 with PKCE 參數
    private var state: String?
    private var codeVerifier: String?
    private var safariViewController: SFSafariViewController?
    
    // Strava OAuth 配置
    private let stravaAuthURL = "https://www.strava.com/oauth/authorize"
    private let scope = "activity:read_all,profile:read_all"
    
    // 環境相關配置
    private let clientID: String
    private let clientSecret: String
    private let redirectURI: String
    
    override init() {
        // 根據環境讀取對應的 Strava Client ID 和 Secret
        if let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            
            // 根據 build configuration 選擇對應的 Client ID 和 Secret
            let clientIDKey: String
            let clientSecretKey: String
            #if DEBUG
            clientIDKey = "StravaClientID_Dev"
            clientSecretKey = "StravaClientSecret_Dev"
            #else
            clientIDKey = "StravaClientID_Prod"
            clientSecretKey = "StravaClientSecret_Prod"
            #endif
            
            if let stravaClientID = plist[clientIDKey] as? String,
               let stravaClientSecret = plist[clientSecretKey] as? String,
               !stravaClientID.isEmpty && !stravaClientSecret.isEmpty &&
               !stravaClientID.contains("NOT_SET") && !stravaClientSecret.contains("NOT_SET") {
                self.clientID = stravaClientID
                self.clientSecret = stravaClientSecret
                print("✅ StravaManager: 成功讀取 \(clientIDKey): \(stravaClientID)")
            } else {
                // 如果正式環境的 Client ID 或 Secret 為空，使用佔位符
                self.clientID = "STRAVA_CLIENT_ID_NOT_SET"
                self.clientSecret = "STRAVA_CLIENT_SECRET_NOT_SET"
                print("⚠️ 警告：\(clientIDKey) 或 \(clientSecretKey) 未設定或為空，Strava 功能將不可用")
            }
        } else {
            self.clientID = "STRAVA_CLIENT_ID_NOT_SET"
            self.clientSecret = "STRAVA_CLIENT_SECRET_NOT_SET"
            print("❌ 錯誤：無法讀取 APIKeys.plist")
        }
        
        // 根據環境設定重定向 URI
        #if DEBUG
        self.redirectURI = "https://api-service-364865009192.asia-east1.run.app/connect/strava/redirect"
        #else
        self.redirectURI = "https://api-service-163961347598.asia-east1.run.app/connect/strava/redirect"
        #endif
        
        super.init()
        // 檢查連接狀態
        loadConnectionStatus()
    }
    
    /// 檢查 Client ID 和 Secret 是否有效
    var isClientCredentialsValid: Bool {
        return !clientID.isEmpty && clientID != "STRAVA_CLIENT_ID_NOT_SET" &&
               !clientSecret.isEmpty && clientSecret != "STRAVA_CLIENT_SECRET_NOT_SET"
    }
    
    // MARK: - 連接狀態管理
    
    private func loadConnectionStatus() {
        // 從 UserDefaults 讀取連接狀態
        isConnected = UserDefaults.standard.bool(forKey: "strava_connected")
        
        // 初始化時重置重新連接相關狀態，避免舊狀態殘留
        needsReconnection = false
        reconnectionMessage = nil
        
        // 如果已經連接，清除任何舊的錯誤信息
        if isConnected {
            connectionError = nil
            Logger.firebase("Strava 連接狀態已載入，清除舊錯誤信息", level: .info, labels: [
                "module": "StravaManager",
                "action": "loadConnectionStatus",
                "isConnected": "true"
            ])
        }
        
        print("🔄 StravaManager 初始化狀態:")
        print("  - isConnected: \(isConnected)")
        print("  - needsReconnection: \(needsReconnection)")
    }
    
    private func saveConnectionStatus(_ connected: Bool) {
        UserDefaults.standard.set(connected, forKey: "strava_connected")
        isConnected = connected
    }
    
    /// 清除連接錯誤信息
    func clearConnectionError() {
        connectionError = nil
    }
    
    /// 檢查 Strava 連線狀態
    func checkConnectionStatus() async {
        print("🔍 [開始] checkConnectionStatus() - 當前 needsReconnection: \(needsReconnection)")
        
        do {
            print("🔍 開始檢查 Strava 連線狀態...")
            
            let response = try await StravaConnectionStatusService.shared.checkConnectionStatus()
            
            await MainActor.run {
                print("🔍 後端 Strava 狀態檢查結果:")
                print("  - connected: \(response.connected)")
                print("  - provider: \(response.provider)")
                print("  - status: '\(response.status)'")
                print("  - isActive: \(response.isActive) (計算結果: connected=\(response.connected) && status='\(response.status)')")
                print("  - message: '\(response.message)'")
                print("  - connectedAt: \(response.connectedAt ?? "nil")")
                print("  - lastUpdated: \(response.lastUpdated ?? "nil")")
                
                // 更新本地連接狀態
                saveConnectionStatus(response.isActive)
                
                if response.isActive {
                    // 連線正常
                    print("✅ 設置狀態：needsReconnection = false")
                    needsReconnection = false
                    reconnectionMessage = nil
                    connectionError = nil
                    
                    // 強制觸發 UI 更新
                    objectWillChange.send()
                    
                    // 如果 Strava 連線正常但本地偏好設定不是 Strava，恢復偏好設定
                    if UserPreferenceManager.shared.dataSourcePreference != .strava {
                        print("🔄 恢復 Strava 資料來源偏好設定")
                        UserPreferenceManager.shared.dataSourcePreference = .strava
                        
                        // 同步到後端
                        Task {
                            do {
                                try await UserService.shared.updateDataSource(DataSourceType.strava.rawValue)
                                print("✅ Strava 資料來源偏好設定已同步到後端")
                            } catch {
                                print("⚠️ 同步 Strava 資料來源偏好設定到後端失敗: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    Logger.firebase("Strava 連線狀態正常", level: .info, labels: [
                        "module": "StravaManager",
                        "action": "checkConnectionStatus",
                        "status": response.status
                    ])
                } else {
                    // 狀態不是 "active"，檢查是否需要重連
                    print("⚠️ Strava 狀態不是 active: '\(response.status)'")
                    
                    // 只對真正的錯誤狀態顯示對話框
                    let problemStatuses = ["bound_to_other_user", "inactive", "expired", "revoked", "suspended", "error"]
                    let shouldShowReconnection = problemStatuses.contains { problemStatus in
                        response.status.lowercased().contains(problemStatus.lowercased())
                    }
                    
                    if shouldShowReconnection {
                        print("❌ 檢測到問題狀態 '\(response.status)'，設置 needsReconnection = true")
                        needsReconnection = true
                        reconnectionMessage = response.message.isEmpty ? "Strava 連接需要重新授權" : response.message
                        
                        Logger.firebase("Strava 需要重新綁定", level: .warn, labels: [
                            "module": "StravaManager",
                            "action": "checkConnectionStatus",
                            "status": response.status,
                            "connected": "\(response.connected)"
                        ])
                    } else {
                        print("🔄 狀態 '\(response.status)' 不需要重連，設置 needsReconnection = false")
                        needsReconnection = false
                        reconnectionMessage = nil
                    }
                }
            }
            
        } catch {
            Logger.firebase("檢查 Strava 連線狀態失敗: \(error.localizedDescription)", level: .error, labels: [
                "module": "StravaManager",
                "action": "checkConnectionStatus"
            ])
            
            await MainActor.run {
                // 檢查失敗時不改變現有狀態，但清除重新連接提示
                print("❌ API 調用失敗，設置 needsReconnection = false")
                needsReconnection = false
                reconnectionMessage = nil
            }
        }
        
        print("🔍 [結束] checkConnectionStatus() - 最終 needsReconnection: \(needsReconnection)")
    }
    
    /// 清除重新連接提示
    func clearReconnectionMessage() {
        needsReconnection = false
        reconnectionMessage = nil
    }
    
    // MARK: - Standard OAuth 2.0 流程
    
    // 產生 state 字串（JSON encode + base64）
    private func buildState(forceReplace: Bool, customState: String?) -> String {
        var stateDict: [String: Any] = [
            "oauth_state": customState ?? generateState()
        ]
        if forceReplace {
            stateDict["force_replace"] = true
        }
        let stateData = try! JSONSerialization.data(withJSONObject: stateDict)
        return stateData.base64EncodedString()
    }

    /// 開始 Strava 連接流程
    func startConnection(force: Bool = false, state: String? = nil) async {
        print("🔧 StravaManager: 開始連接流程 (force: \(force), state: \(state ?? "nil"))")
        
        // 檢查 Client 憑證是否有效
        guard isClientCredentialsValid else {
            await MainActor.run {
                connectionError = "Strava 功能暫時不可用，請稍後再試"
                print("❌ StravaManager: Client 憑證無效，無法啟動連接流程")
            }
            return
        }
        
        await MainActor.run {
            isConnecting = true
            connectionError = nil
        }
        
        do {
            print("🔧 StravaManager: 使用 Client ID: \(clientID)")
            print("🔧 StravaManager: 回調 URL: \(redirectURI)")
            
            // 生成 state 參數
            let stateString = buildState(forceReplace: force, customState: state)
            
            print("🔧 StravaManager: 生成 OAuth 參數")
            print("  - State: \(stateString)")
            
            // 儲存 state 以供後續使用
            self.state = stateString
            
            // 建構授權 URL
            let authURL = try buildAuthorizationURL(state: stateString)
            
            print("🔧 StravaManager: 完整授權 URL: \(authURL)")
            print("🔧 StravaManager: URL 組件:")
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
            print("❌ StravaManager: 初始化連接失敗: \(error)")
            await MainActor.run {
                isConnecting = false
                connectionError = "初始化連接失敗: \(error.localizedDescription)"
            }
        }
    }
    
    /// 處理深度連結回調（從後端重定向）
    func handleCallback(url: URL) async {
        print("StravaManager: 收到回調 URL: \(url)")
        print("🔐 PKCE 狀態檢查:")
        print("  - Code Verifier 已保存: \(codeVerifier != nil)")
        if let verifier = codeVerifier {
            print("  - Verifier 長度: \(verifier.count)")
        }

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
        let errorDescription = queryItems.first { $0.name == "error_description" }?.value ?? "該 Strava 帳號已經綁定至另一個 Paceriz 帳號。請先使用原本綁定的 Paceriz 帳號登入，並在個人資料頁解除 Strava 綁定後，再用本帳號進行連接。"
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
                    self.stravaAlreadyBoundMessage = errorDescription
                    self.pendingForceReplace = nil
                }
            }
            return
        }
        
        // 檢查是否有錯誤
        if let error = error {
            await handleConnectionError("Strava 授權失敗: \(error)")
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
                
                print("✅ Strava 連接成功")
                
                // 記錄連接成功和錯誤清除
                Logger.firebase("Strava 連接成功，錯誤信息已清除", level: .info, labels: [
                    "module": "StravaManager",
                    "action": "handleCallback",
                    "result": "success"
                ])
                
                // 連接成功後自動切換到Strava數據源
                UserPreferenceManager.shared.dataSourcePreference = .strava
                
                // 同步到後端
                Task {
                    do {
                        try await UserService.shared.updateDataSource(DataSourceType.strava.rawValue)
                        print("數據源設定已同步到後端: Strava")
                    } catch {
                        print("同步Strava數據源設定到後端失敗: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            await handleConnectionError("Strava 連接失敗")
        }
    }
    
    /// 中斷 Strava 連接
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
                print("Strava 本地連接狀態已重置")
            }
            return
        }

        do {
            // 使用統一架構的 StravaDisconnectService 移除連接
            let response = try await StravaDisconnectService.shared.removeStravaConnection()
            
            if (200...299).contains(response.statusCode) {
                await MainActor.run {
                    saveConnectionStatus(false)
                    clearStoredCredentials()
                    isConnecting = false
                    
                    print("Strava 連接已中斷")
                }
            } else {
                throw NSError(domain: "StravaManager", code: response.statusCode, 
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
    
    private func generateState() -> String {
        let data = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        return data.base64URLEncodedString()
    }

    // MARK: - PKCE 相關方法

    /// 生成 PKCE code verifier
    /// - Returns: 43-128 字符的隨機字符串
    private func generateCodeVerifier() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let length = 128 // 使用最大長度以提高安全性
        let verifier = String((0..<length).map { _ in characters.randomElement()! })
        return verifier
    }

    /// 生成 PKCE code challenge (S256)
    /// - Parameter verifier: Code verifier
    /// - Returns: Base64 URL 編碼的 SHA256 哈希
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            return ""
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }

        return Data(digest).base64URLEncodedString()
    }
    
    private func buildAuthorizationURL(state: String) throws -> URL {
        guard var components = URLComponents(string: stravaAuthURL) else {
            throw NSError(domain: "StravaManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "無效的 Strava 授權 URL"])
        }

        // 生成 PKCE code verifier 和 code challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // 儲存 code verifier 以供後續 token 交換使用
        self.codeVerifier = codeVerifier

        print("🔐 PKCE 參數已生成:")
        print("  - Code Verifier: \(codeVerifier.prefix(20))...")
        print("  - Code Challenge: \(codeChallenge)")

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
            throw NSError(domain: "StravaManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "無法建構授權 URL"])
        }

        return url
    }
    
    private func presentSafariViewController(with url: URL) {
        print("🔧 StravaManager: 嘗試顯示 Safari 視圖")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ StravaManager: 無法獲取視窗場景或視窗")
            connectionError = "無法顯示授權頁面"
            isConnecting = false
            return
        }
        
        // 找到最頂層的視圖控制器
        var presentingViewController = window.rootViewController
        while let presented = presentingViewController?.presentedViewController {
            presentingViewController = presented
        }
        
        print("🔧 StravaManager: 找到頂層視圖控制器: \(String(describing: presentingViewController))")
        
        guard let topViewController = presentingViewController else {
            print("❌ StravaManager: 無法找到可用的視圖控制器")
            connectionError = "無法顯示授權頁面"
            isConnecting = false
            return
        }
        
        print("🔧 StravaManager: 創建 Safari 視圖控制器")
        
        safariViewController = SFSafariViewController(url: url)
        safariViewController?.delegate = self
        safariViewController?.modalPresentationStyle = .pageSheet
        
        print("🔧 StravaManager: 準備在頂層視圖控制器上顯示 Safari 視圖")
        topViewController.present(safariViewController!, animated: true) {
            print("✅ StravaManager: Safari 視圖已顯示")
        }
    }
    
    private func handleConnectionError(_ message: String) async {
        await MainActor.run {
            isConnecting = false
            connectionError = message
            clearStoredCredentials()
        }
    }
    
    private func clearStoredCredentials() {
        state = nil
    }
}

// MARK: - SFSafariViewControllerDelegate

extension StravaManager: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // 用戶手動關閉了 Safari 視圖
        print("🔧 StravaManager: 用戶手動關閉了 Safari 視圖")
        Task {
            await MainActor.run {
                isConnecting = false
                clearStoredCredentials()
            }
        }
    }
    
    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
        print("🔧 StravaManager: Safari 初始載入重定向到: \(URL)")
    }
    
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        print("🔧 StravaManager: Safari 初始載入完成，成功: \(didLoadSuccessfully)")
    }
}

// Note: base64URLEncodedString extension is already defined in GarminManager.swift