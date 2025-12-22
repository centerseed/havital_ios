# 邀請碼功能實作文檔

## 📋 目錄

- [功能概述](#功能概述)
- [架構設計](#架構設計)
- [核心組件](#核心組件)
- [API 整合](#api-整合)
- [UI 流程](#ui-流程)
- [Deep Link 配置](#deep-link-配置)
- [測試指南](#測試指南)
- [故障排除](#故障排除)

---

## 功能概述

### 業務目標

實作推薦獎勵系統，讓用戶可以邀請好友加入 Paceriz，雙方各獲得 **7 天 Premium 訂閱**獎勵。

### 核心特性

- ✅ 生成專屬邀請碼（8 位英數字）
- ✅ 分享邀請碼（社交媒體、訊息、複製連結）
- ✅ 兌換邀請碼
- ✅ 查看邀請統計（總邀請數、已發放獎勵、待發放獎勵）
- ✅ 自動獎勵發放（後端處理）
- ⚠️ Deep Link 支援（需額外配置）

### 業務規則

| 項目 | 規範 | 備註 |
|------|------|------|
| **邀請碼格式** | 8 位大寫英數字 | 範例：`ABCD1234` |
| **有效期** | 90 天 | 過期後需重新生成 |
| **最大使用次數** | 100 次/碼 | 達上限需聯繫管理員 |
| **邀請者獎勵** | 7 天 Premium | 每次成功邀請 |
| **被邀請者獎勵** | 7 天 Premium | 首次使用邀請碼 |
| **退款等待期** | 14 天 | 雙方通過退款期後自動發放 |
| **使用限制** | 每人僅能使用一次邀請碼 | 無法使用自己的邀請碼 |

---

## 架構設計

### 整體架構

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  ┌─────────────────┐  ┌──────────────────────────────┐  │
│  │ InviteCodeView  │  │ InviteCodeRedemptionView      │  │
│  └─────────────────┘  └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│                     Manager Layer                        │
│            InviteCodeManager (Singleton)                 │
│  • DataManageable      • Published 狀態                  │
│  • TaskManageable      • 雙軌緩存                         │
└─────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│                     Service Layer                        │
│            InviteCodeService (Singleton)                 │
│  • 生成邀請碼          • 驗證邀請碼                        │
│  • 使用邀請碼          • 查詢統計                          │
└─────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Network Layer                          │
│      HTTPClient (JWT 認證) + APIParser                   │
└─────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Backend API                            │
│  /user/invite-code/generate                              │
│  /user/invite-code/use                                   │
│  /user/invite-code/statistics                            │
│  /user/invite-code/validate/:code                        │
└─────────────────────────────────────────────────────────┘
```

### 設計原則

1. **一致性**：遵循現有 IAP（訂閱）功能的架構模式
2. **可測試性**：Service 和 Manager 層分離，便於單元測試
3. **可維護性**：清晰的職責劃分，單一職責原則
4. **效能優化**：雙軌緩存策略，減少不必要的 API 調用
5. **錯誤處理**：統一錯誤處理機制，區分取消錯誤

---

## 核心組件

### 1. 數據模型層 (Models/InviteCode.swift)

#### InviteCode

```swift
struct InviteCode: Codable, Identifiable {
    let id: String              // 邀請碼 ID
    let code: String            // 8 位邀請碼
    let ownerUid: String        // 擁有者 UID
    let usageCount: Int         // 已使用次數
    let maxUsage: Int           // 最大使用次數
    let rewardDays: Int         // 獎勵天數
    let expiresAt: String       // 到期時間（ISO 8601）
    let isActive: Bool          // 是否有效
    let shareUrl: String        // 分享連結
    let createdAt: String       // 創建時間

    var isExpired: Bool         // 是否已過期
    var formattedExpiryDate: String? // 格式化到期日期
    var remainingUsage: Int     // 剩餘可用次數
    var isAvailable: Bool       // 是否可用
}
```

#### InviteStatistics

```swift
struct InviteStatistics: Codable {
    let myInviteCode: String?           // 我的邀請碼
    let shareUrl: String?               // 分享連結
    let codeExpiresAt: String?          // 到期時間
    let codeIsExpired: Bool             // 是否已過期
    let totalInvites: Int               // 總邀請數
    let successfulConversions: Int      // 已發放獎勵數
    let pendingRewards: Int             // 待發放獎勵數
    let totalRewardsEarnedDays: Int     // 總獲得天數
    let recentInvites: [InviteCodeUsage] // 最近邀請記錄
}
```

#### InviteCodeError

```swift
enum InviteCodeError: Error {
    case invalidCode                // 無效格式
    case codeNotFound              // 邀請碼不存在
    case codeExpired               // 已過期
    case codeMaxUsageReached       // 達使用上限
    case alreadyUsedCode           // 已經使用過
    case cannotUseSelfCode         // 不能使用自己的邀請碼
    case networkError(String)      // 網路錯誤
    case unknownError              // 未知錯誤
}
```

### 2. Service 層 (Services/InviteCodeService.swift)

#### 職責

- 與後端 API 通信
- 處理 JSON 序列化/反序列化
- 統一錯誤處理
- 取消錯誤過濾

#### 核心方法

```swift
final class InviteCodeService {
    static let shared = InviteCodeService()

    /// 生成邀請碼
    func generateInviteCode(validityDays: Int = 90) async throws -> InviteCode

    /// 使用邀請碼
    func useInviteCode(_ code: String) async throws -> UseInviteCodeData

    /// 查詢邀請統計
    func getStatistics() async throws -> InviteStatistics

    /// 驗證邀請碼（可選）
    func validateCode(_ code: String) async throws -> Bool

    /// 錯誤處理
    func handleAPIError(_ error: Error) -> String
}
```

#### 使用範例

```swift
// 生成邀請碼
do {
    let inviteCode = try await InviteCodeService.shared.generateInviteCode()
    print("邀請碼：\(inviteCode.code)")
} catch {
    print("生成失敗：\(error.localizedDescription)")
}

// 使用邀請碼
do {
    let result = try await InviteCodeService.shared.useInviteCode("ABCD1234")
    print("獲得 \(result.rewardDays) 天獎勵")
} catch InviteCodeError.alreadyUsedCode {
    print("您已經使用過邀請碼了")
}
```

### 3. Manager 層 (Managers/InviteCodeManager.swift)

#### 職責

- 管理邀請碼狀態
- 雙軌緩存策略實現
- 任務管理（防止重複執行）
- UI 狀態管理

#### 核心屬性

```swift
@MainActor
final class InviteCodeManager: ObservableObject, DataManageable, TaskManageable {
    @Published var myInviteCode: InviteCode?
    @Published var statistics: InviteStatistics?
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var syncError: String?
    @Published var lastSyncTime: Date?
}
```

#### 核心方法

```swift
// 初始化
func initialize() async

// 刷新數據
func refreshData() async

// 生成邀請碼
func generateCode(validityDays: Int = 90) async -> Bool

// 兌換邀請碼
func redeemCode(_ code: String) async -> Bool

// 驗證邀請碼
func validateCode(_ code: String) async -> Bool

// 獲取分享文案
func getShareMessage() -> String
```

#### 雙軌緩存策略

```swift
// 軌道 A：立即顯示緩存（同步）
if let cachedData = cacheManager.loadData() {
    self.myInviteCode = cachedData.myInviteCode
    self.statistics = cachedData.statistics
}

// 軌道 B：背景更新（非同步）
Task.detached {
    await self.refreshDataInternal()
}
```

### 4. UI 層

#### InviteCodeView（主要邀請頁面）

**功能：**
- 顯示我的邀請碼（大型可複製顯示）
- 分享按鈕（呼叫 UIActivityViewController）
- 邀請統計展示（總邀請數、已/待發放獎勵）
- 重新生成邀請碼（若過期）

**使用範例：**
```swift
NavigationView {
    InviteCodeView()
}
```

#### InviteCodeRedemptionView（兌換頁面）

**功能：**
- 輸入邀請碼（自動大寫轉換）
- 即時格式驗證
- 提交兌換
- 成功/失敗反饋
- 跳過選項

**使用範例：**
```swift
// 獨立使用
InviteCodeRedemptionView()

// 帶預填邀請碼（來自 Deep Link）
InviteCodeRedemptionView(prefilledCode: "ABCD1234")

// 自訂完成回調
InviteCodeRedemptionView {
    // 完成後的操作
    dismiss()
}
```

#### InviteFriendsCard（SubscriptionView 整合）

**位置：** `SubscriptionView` 產品列表下方

**功能：**
- 吸引用戶點擊的漸層卡片
- 點擊進入 InviteCodeView
- 顯示「雙方各得 7 天 Premium」提示

---

## API 整合

### 1. 生成邀請碼

**端點：** `POST /user/invite-code/generate`

**請求：**
```json
{
  "validity_days": 90
}
```

**回應：**
```json
{
  "success": true,
  "data": {
    "code": "ABCD1234",
    "share_url": "https://havital.com/invite/ABCD1234",
    "expires_at": "2025-02-04T12:00:00+00:00",
    "reward_days": 7,
    "max_usage": 100,
    "current_usage": 0
  }
}
```

### 2. 使用邀請碼

**端點：** `POST /user/invite-code/use`

**請求：**
```json
{
  "code": "ABCD1234"
}
```

**回應（成功）：**
```json
{
  "success": true,
  "data": {
    "message": "Invite code used successfully",
    "reward_days": 7,
    "reward_status": "pending",
    "estimated_grant_date": "2024-11-18T12:00:00+00:00"
  }
}
```

**錯誤回應：**
```json
{
  "success": false,
  "error": "Invite code not found"
}
```

**可能的錯誤訊息：**
- `"Invite code not found"` → 邀請碼不存在
- `"Invite code has expired"` → 邀請碼已過期
- `"Cannot use your own invite code"` → 不能使用自己的邀請碼
- `"You have already used an invite code"` → 已經使用過邀請碼
- `"Invite code has reached maximum usage"` → 達使用上限

### 3. 查詢邀請統計

**端點：** `GET /user/invite-code/statistics`

**回應：**
```json
{
  "success": true,
  "data": {
    "my_invite_code": "ABCD1234",
    "share_url": "https://havital.com/invite/ABCD1234",
    "code_expires_at": "2025-02-04T12:00:00+00:00",
    "code_is_expired": false,
    "total_invites": 15,
    "successful_conversions": 10,
    "pending_rewards": 5,
    "total_rewards_earned_days": 70,
    "recent_invites": [
      {
        "invitee_uid": "user_abc",
        "used_at": "2024-11-01T10:00:00+00:00",
        "reward_granted": true,
        "reward_granted_at": "2024-11-15T02:00:00+00:00"
      }
    ]
  }
}
```

### 4. 驗證邀請碼（可選）

**端點：** `GET /user/invite-code/validate/:code`

**回應：**
```json
{
  "success": true,
  "data": {
    "valid": true,
    "reward_days": 7,
    "message": "Valid invite code"
  }
}
```

---

## UI 流程

### 流程 1：用戶生成邀請碼

```
用戶進入「訂閱管理」頁面
    ↓
點擊「邀請好友」卡片
    ↓
進入 InviteCodeView
    ↓
點擊「生成邀請碼」按鈕
    ↓
[InviteCodeManager.generateCode()]
    ↓
[InviteCodeService.generateInviteCode()]
    ↓
顯示大型邀請碼卡片
    ↓
用戶選擇：
  • 複製邀請碼
  • 分享（UIActivityViewController）
```

### 流程 2：新用戶兌換邀請碼

```
新用戶註冊/登入完成
    ↓
（可選）顯示 InviteCodeRedemptionView
    ↓
輸入邀請碼（自動大寫）
    ↓
即時格式驗證
    ↓
點擊「兌換獎勵」
    ↓
[InviteCodeManager.redeemCode()]
    ↓
[InviteCodeService.useInviteCode()]
    ↓
顯示成功訊息：
  「您將在 14 天後獲得 7 天 Premium」
    ↓
2 秒後自動完成
```

### 流程 3：Deep Link 流程（需額外配置）

```
用戶點擊分享連結
  havital://invite/ABCD1234
    ↓
App 啟動（或從背景喚醒）
    ↓
SceneDelegate 解析 URL
    ↓
檢查用戶登入狀態：
  • 已登入 → 直接顯示 InviteCodeRedemptionView
  • 未登入 → 暫存邀請碼 → 顯示登入頁面
    ↓
登入後自動填入邀請碼
    ↓
用戶確認兌換
```

---

## Deep Link 配置

### ⚠️ 注意

Deep Link 功能需要額外的配置才能正常運作。以下是配置步驟：

### 步驟 1：配置 URL Scheme

在 `Info.plist` 中添加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.havital.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>havital</string>
        </array>
    </dict>
</array>
```

**支援的 URL 格式：** `havital://invite/ABCD1234`

### 步驟 2：配置 Universal Links

在 `Info.plist` 中添加：

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:havital.com</string>
    <string>applinks:www.havital.com</string>
</array>
```

**支援的 URL 格式：** `https://havital.com/invite/ABCD1234`

### 步驟 3：在 SceneDelegate 中處理 URL

```swift
// SceneDelegate.swift

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    handleIncomingURL(url)
}

func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    // 處理 Universal Links
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
        handleIncomingURL(url)
    }
}

private func handleIncomingURL(_ url: URL) {
    // 解析 URL
    // 格式：havital://invite/ABCD1234 或 https://havital.com/invite/ABCD1234

    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let host = components.host,
          (host == "invite" || url.path.contains("/invite/")) else {
        return
    }

    // 提取邀請碼
    let inviteCode = url.lastPathComponent

    // 檢查用戶登入狀態
    if AuthenticationService.shared.isAuthenticated {
        // 已登入：顯示兌換頁面
        showInviteCodeRedemption(code: inviteCode)
    } else {
        // 未登入：暫存邀請碼
        UserDefaults.standard.set(inviteCode, forKey: "pending_invite_code")
        // 顯示登入頁面
        showLogin()
    }
}

private func showInviteCodeRedemption(code: String) {
    // 在主視窗顯示 InviteCodeRedemptionView
    // 實作方式取決於你的導航架構
}
```

### 步驟 4：登入後自動兌換

在登入成功後檢查是否有待處理的邀請碼：

```swift
// 登入成功後
if let pendingCode = UserDefaults.standard.string(forKey: "pending_invite_code") {
    // 顯示兌換頁面
    presentInviteCodeRedemption(prefilledCode: pendingCode)

    // 清除暫存
    UserDefaults.standard.removeObject(forKey: "pending_invite_code")
}
```

### 測試 Deep Link

**測試 URL Scheme：**
```bash
xcrun simctl openurl booted "havital://invite/TEST1234"
```

**測試 Universal Link：**
1. 在 Notes 或 Safari 中輸入 `https://havital.com/invite/TEST1234`
2. 長按連結 → 在 App 中開啟

---

## 測試指南

### 單元測試

#### 測試 InviteCodeService

```swift
// InviteCodeServiceTests.swift

func testGenerateInviteCode() async throws {
    let service = InviteCodeService.shared
    let inviteCode = try await service.generateInviteCode(validityDays: 90)

    XCTAssertEqual(inviteCode.rewardDays, 7)
    XCTAssertEqual(inviteCode.maxUsage, 100)
    XCTAssertFalse(inviteCode.isExpired)
}

func testUseInviteCode_Success() async throws {
    let service = InviteCodeService.shared
    let result = try await service.useInviteCode("VALID123")

    XCTAssertEqual(result.rewardDays, 7)
    XCTAssertTrue(result.isPending)
}

func testUseInviteCode_AlreadyUsed() async {
    let service = InviteCodeService.shared

    do {
        _ = try await service.useInviteCode("USED1234")
        XCTFail("應該拋出 alreadyUsedCode 錯誤")
    } catch InviteCodeError.alreadyUsedCode {
        // 預期的錯誤
    } catch {
        XCTFail("錯誤類型不正確")
    }
}
```

#### 測試 InviteCodeManager

```swift
// InviteCodeManagerTests.swift

@MainActor
func testGenerateCode_Success() async {
    let manager = InviteCodeManager.shared
    let success = await manager.generateCode()

    XCTAssertTrue(success)
    XCTAssertNotNil(manager.myInviteCode)
    XCTAssertNil(manager.syncError)
}

@MainActor
func testRedeemCode_Success() async {
    let manager = InviteCodeManager.shared
    let success = await manager.redeemCode("VALID123")

    XCTAssertTrue(success)
    XCTAssertNil(manager.syncError)
}

@MainActor
func testValidateCode_ValidFormat() async {
    let manager = InviteCodeManager.shared
    let isValid = await manager.validateCode("ABCD1234")

    // 假設這個邀請碼在後端是有效的
    XCTAssertTrue(isValid)
}
```

### UI 測試

#### 測試 InviteCodeView

```swift
func testInviteCodeView_GenerateCode() {
    let app = XCUIApplication()
    app.launch()

    // 導航到邀請頁面
    app.buttons["邀請好友"].tap()

    // 點擊生成邀請碼
    app.buttons["生成邀請碼"].tap()

    // 等待載入
    sleep(2)

    // 驗證邀請碼顯示
    XCTAssertTrue(app.staticTexts["我的邀請碼"].exists)

    // 測試複製功能
    app.buttons["複製"].tap()
    XCTAssertTrue(app.alerts["提示"].exists)
}
```

#### 測試 InviteCodeRedemptionView

```swift
func testInviteCodeRedemptionView_RedeemCode() {
    let app = XCUIApplication()
    app.launch()

    // 輸入邀請碼
    let textField = app.textFields["請輸入 8 位邀請碼"]
    textField.tap()
    textField.typeText("TEST1234")

    // 點擊兌換
    app.buttons["兌換獎勵"].tap()

    // 驗證成功訊息
    XCTAssertTrue(app.staticTexts["兌換成功！"].waitForExistence(timeout: 3))
}
```

### 手動測試 Checklist

- [ ] **生成邀請碼**
  - [ ] 首次生成成功
  - [ ] 生成後顯示正確的邀請碼
  - [ ] 顯示正確的到期日期
  - [ ] 顯示正確的使用次數（0/100）

- [ ] **複製功能**
  - [ ] 點擊「複製」按鈕
  - [ ] 剪貼板包含正確的邀請碼
  - [ ] 顯示「已複製」提示

- [ ] **分享功能**
  - [ ] 點擊「分享」按鈕
  - [ ] UIActivityViewController 正確顯示
  - [ ] 分享文案包含邀請碼和連結
  - [ ] 可分享到各種 App

- [ ] **兌換邀請碼**
  - [ ] 輸入有效邀請碼成功兌換
  - [ ] 輸入無效格式顯示錯誤
  - [ ] 輸入不存在的邀請碼顯示錯誤
  - [ ] 使用已過期的邀請碼顯示錯誤
  - [ ] 重複使用邀請碼顯示錯誤
  - [ ] 使用自己的邀請碼顯示錯誤

- [ ] **統計顯示**
  - [ ] 總邀請數正確
  - [ ] 已發放獎勵數正確
  - [ ] 待發放獎勵數正確
  - [ ] 總獲得天數正確
  - [ ] 最近邀請列表正確顯示

- [ ] **邀請碼過期**
  - [ ] 過期後顯示「已過期」提示
  - [ ] 顯示「重新生成」按鈕
  - [ ] 重新生成成功

- [ ] **訂閱整合**
  - [ ] SubscriptionView 顯示「邀請好友」卡片
  - [ ] 點擊卡片進入邀請頁面
  - [ ] 獎勵發放後訂閱期限延長

---

## 故障排除

### 常見問題

#### 1. 無法生成邀請碼

**症狀：** 點擊「生成邀請碼」後顯示錯誤

**可能原因：**
- 網路連接問題
- JWT token 過期
- 後端 API 錯誤

**解決方案：**
```swift
// 檢查網路連接
if !NetworkMonitor.shared.isConnected {
    print("無網路連接")
}

// 檢查 JWT token
if let token = AuthenticationService.shared.jwtToken {
    print("JWT token: \(token)")
} else {
    print("JWT token 不存在，請重新登入")
}

// 查看詳細錯誤
print("錯誤訊息：\(InviteCodeManager.shared.syncError ?? "無")")
```

#### 2. 兌換邀請碼失敗

**症狀：** 輸入邀請碼後顯示「兌換失敗」

**可能原因：**
- 邀請碼格式錯誤
- 邀請碼不存在
- 已經使用過邀請碼
- 使用自己的邀請碼

**解決方案：**
```swift
// 驗證邀請碼格式
let code = "ABCD1234"
if InviteCodeConstants.isValidFormat(code) {
    print("格式正確")
} else {
    print("格式錯誤：必須是 8 位大寫英數字")
}

// 檢查具體錯誤
if let error = InviteCodeManager.shared.syncError {
    print("兌換失敗原因：\(error)")
}
```

#### 3. 統計數據不更新

**症狀：** 邀請成功後統計數據沒有更新

**可能原因：**
- 緩存未刷新
- 網路請求失敗

**解決方案：**
```swift
// 手動刷新統計數據
await InviteCodeManager.shared.refreshData()

// 清除緩存並重新載入
await InviteCodeManager.shared.clearCache()
await InviteCodeManager.shared.initialize()
```

#### 4. Deep Link 無法正常運作

**症狀：** 點擊分享連結後 App 沒有打開

**可能原因：**
- Info.plist 配置錯誤
- URL Scheme 未正確註冊
- SceneDelegate 未處理 URL

**解決方案：**
```swift
// 檢查 Info.plist 配置
// 確認 CFBundleURLSchemes 包含 "havital"
// 確認 Associated Domains 包含 "applinks:havital.com"

// 在 SceneDelegate 中添加日誌
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    print("收到 URL：\(url)")
    handleIncomingURL(url)
}

// 測試 URL Scheme
// xcrun simctl openurl booted "havital://invite/TEST1234"
```

#### 5. 分享功能沒有反應

**症狀：** 點擊「分享」按鈕後沒有顯示分享選單

**可能原因：**
- UIActivityViewController 未正確初始化
- 分享內容為空

**解決方案：**
```swift
// 檢查分享內容
let message = InviteCodeManager.shared.getShareMessage()
print("分享內容：\(message)")

// 確保在主線程上顯示
DispatchQueue.main.async {
    let activityVC = UIActivityViewController(
        activityItems: [message],
        applicationActivities: nil
    )

    // iPad 需要設定 popoverPresentationController
    if let popover = activityVC.popoverPresentationController {
        popover.sourceView = self.view
        popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
    }

    self.present(activityVC, animated: true)
}
```

### 調試技巧

#### 啟用詳細日誌

```swift
// 在 InviteCodeManager 中添加更多日誌
Logger.debug("InviteCodeManager: 開始生成邀請碼")
Logger.debug("InviteCodeManager: API 調用完成")
Logger.debug("InviteCodeManager: 邀請碼 = \(inviteCode)")
```

#### 使用 Xcode Console 過濾

```
# 只顯示 InviteCodeManager 相關日誌
InviteCodeManager

# 只顯示錯誤
error:

# 只顯示 Firebase 日誌
firebase:
```

#### 使用 Network Link Conditioner

模擬慢速網路，測試載入狀態：
1. 設定 > 開發者 > Network Link Conditioner
2. 選擇「3G」或「Edge」
3. 測試 App 在慢速網路下的行為

---

## 總結

邀請碼功能已完整實作，遵循專案既有架構模式，確保一致性和可維護性。

### 已實作功能

✅ 數據模型層（InviteCode, InviteStatistics, 錯誤類型）
✅ Service 層（API 整合、錯誤處理）
✅ Manager 層（雙軌緩存、任務管理）
✅ UI 層（InviteCodeView, InviteCodeRedemptionView）
✅ SubscriptionView 整合（邀請好友卡片）
✅ 完整文檔（本文件）

### 待配置功能

⚠️ Deep Link 支援（需手動配置 Info.plist 和 SceneDelegate）

### 下一步

1. **配置 Deep Link**（依照本文檔的 Deep Link 配置章節）
2. **後端 API 測試**（確認所有 API 端點正常運作）
3. **集成測試**（完整流程測試）
4. **上線前檢查**（使用測試 Checklist）

---

**文檔版本：** 1.0
**最後更新：** 2025-11-04
**作者：** Claude Code
**相關文檔：** `SUBSCRIPTION_UI_INTEGRATION.md`, `IAP_IMPLEMENTATION_PLAN.md`
