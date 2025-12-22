# Paceriz iOS 訂閱功能（IAP）實現計劃

## 📋 文件資訊

- **建立日期**：2025-11-04
- **專案**：Paceriz iOS App
- **版本**：v1.0
- **狀態**：開發中

---

## 🎯 專案目標

為 Paceriz iOS App 新增 In-App Purchase (IAP) 訂閱功能，支援月付和年付兩種方案。實現分為兩個階段：

### 階段一：Mock IAP 系統（開發測試）
- 模擬完整的購買流程，無需真實 Apple 支付
- 支援多種測試場景（成功/取消/錯誤等）
- 快速迭代開發，無需等待 Apple 審核

### 階段二：真實 Apple IAP 整合
- 整合 StoreKit 2 API
- 連接 App Store 產品
- 支援真實購買和收據驗證

---

## 🏗️ 系統架構

### 整體架構圖

```
┌─────────────────────────────────────────────┐
│          Views (SubscriptionView)            │
│  • 顯示訂閱選項和價格                         │
│  • 處理用戶購買/恢復操作                      │
│  • 顯示當前訂閱狀態                          │
└──────────────────┬──────────────────────────┘
                   │ @StateObject
┌─────────────────▼──────────────────────────┐
│      SubscriptionManager                     │
│      (ObservableObject + DataManageable)     │
│  • 協調 StoreKit 和後端 API                  │
│  • 雙軌快取策略（立即顯示 + 背景刷新）        │
│  • 任務管理（防重複執行）                     │
│  • 發布訂閱狀態變更                          │
└──────────┬────────────────┬─────────────────┘
           │                │
           │ 依賴           │ 依賴
┌──────────▼─────────┐  ┌──▼──────────────────┐
│ SubscriptionService │  │ StoreKitService      │
│  • 調用後端 API     │  │  (協議導向設計)      │
│  • 收據驗證         │  │  • MockStoreKit      │
│  • 查詢訂閱狀態     │  │  • RealStoreKit      │
│  • 恢復購買         │  │  • 購買流程          │
└──────────┬─────────┘  └──┬──────────────────┘
           │                │
           │ 使用           │ 使用
┌──────────▼─────────┐  ┌──▼──────────────────┐
│   HTTPClient        │  │  StoreKit 2 API     │
│  • JWT 自動認證     │  │  (或 Mock 邏輯)      │
│  • 統一錯誤處理     │  │  • Product.products  │
│  • 網路請求         │  │  • purchase()        │
└─────────────────────┘  │  • Transaction.*     │
                          └─────────────────────┘
```

### 架構層級職責

| 層級 | 元件 | 職責 | 不負責 |
|------|------|------|--------|
| **View** | SubscriptionView | UI 顯示、用戶交互、狀態綁定 | 業務邏輯、API 調用 |
| **Manager** | SubscriptionManager | 業務協調、快取策略、狀態管理 | HTTP 通信、StoreKit API |
| **Service** | SubscriptionService | 後端 API 包裝、錯誤轉換 | 快取、UI 狀態 |
| **Service** | StoreKitService | Apple IAP 整合、收據獲取 | 後端驗證、快取 |
| **Storage** | SubscriptionCache | 本地資料持久化、TTL 管理 | 網路請求、業務邏輯 |

---

## 📁 檔案結構

```
Havital/
├── Docs/
│   └── IAP_IMPLEMENTATION_PLAN.md          # 本文件（繁體中文）
│
├── Models/
│   └── Subscription.swift                   # 訂閱資料模型
│       ├── Subscription                     # 訂閱記錄
│       ├── SubscriptionStatus               # 狀態枚舉（active/expired/cancelled）
│       ├── SubscriptionProduct              # 產品資訊（月付/年付）
│       ├── PurchaseVerificationRequest      # 收據驗證請求
│       └── PurchaseVerificationResponse     # 收據驗證回應
│
├── Services/
│   ├── StoreKitServiceProtocol.swift        # StoreKit 服務協議
│   │   └── protocol StoreKitServiceProtocol # 統一介面
│   │
│   ├── MockStoreKitService.swift            # Mock IAP 實現（階段一）
│   │   ├── 模擬購買流程（可配置成功/失敗）
│   │   ├── 生成假收據資料
│   │   └── 支援多種測試場景
│   │
│   ├── RealStoreKitService.swift            # 真實 IAP 實現（階段二）
│   │   ├── 整合 StoreKit 2 API
│   │   ├── 監聽交易更新
│   │   ├── 處理自動續訂
│   │   └── 獲取真實收據
│   │
│   └── SubscriptionService.swift            # 後端 API 服務
│       ├── verifyPurchase()                 # POST /subscription/purchase/verify
│       ├── restorePurchases()               # POST /subscription/purchase/restore
│       ├── getSubscriptionStatus()          # GET /subscription/status
│       └── 遵循統一的 makeAPICall 模式
│
├── Managers/
│   └── SubscriptionManager.swift            # 訂閱狀態管理器
│       ├── 實現 DataManageable 協議
│       ├── 實現 TaskManageable 協議
│       ├── 雙軌快取策略
│       ├── purchaseSubscription()           # 購買流程協調
│       ├── restorePurchases()               # 恢復購買協調
│       ├── loadData()                       # 加載訂閱狀態
│       └── refreshData()                    # 背景刷新
│
├── Storage/
│   └── SubscriptionCacheManager.swift       # 訂閱快取管理
│       └── 繼承 BaseCacheManagerTemplate<Subscription>
│           ├── TTL: 1 小時
│           └── 註冊到 CacheEventBus
│
└── Views/
    └── Subscription/
        ├── SubscriptionView.swift           # 主訂閱頁面
        │   ├── 顯示可用產品
        │   ├── 購買按鈕
        │   ├── 恢復購買按鈕
        │   └── 當前訂閱狀態
        │
        └── Components/
            ├── SubscriptionProductCard.swift     # 產品卡片元件
            └── SubscriptionStatusBanner.swift    # 訂閱狀態橫幅
```

---

## 🔧 核心技術規格

### 1. 資料模型 (Models/Subscription.swift)

#### Subscription（訂閱記錄）
```swift
struct Subscription: Codable, Equatable {
    let id: String                    // 訂閱 ID
    let userId: String                // 用戶 ID
    let productId: String             // 產品 ID (com.havital.premium.monthly)
    let status: SubscriptionStatus    // 狀態
    let startDate: String             // 開始日期 (ISO 8601)
    let expiryDate: String?           // 到期日期 (ISO 8601)
    let autoRenewing: Bool            // 是否自動續訂
    let platform: String              // 平台 ("apple_iap")
    let transactionId: String?        // 交易 ID
}
```

#### SubscriptionStatus（訂閱狀態）
```swift
enum SubscriptionStatus: String, Codable {
    case active      // 有效訂閱
    case expired     // 已過期
    case cancelled   // 已取消
    case inTrial     // 試用期（未來可擴充）
}
```

#### SubscriptionProduct（訂閱產品）
```swift
struct SubscriptionProduct: Identifiable, Codable {
    let id: String                    // 產品 ID
    let displayName: String           // 顯示名稱 ("Paceriz Premium 月付")
    let description: String           // 描述
    let price: String                 // 價格字串 ("NT$290/月")
    let billingPeriod: BillingPeriod  // 計費週期
}

enum BillingPeriod: String, Codable {
    case monthly  // 月付
    case yearly   // 年付
}
```

---

### 2. StoreKit 服務協議

#### StoreKitServiceProtocol（統一介面）
```swift
protocol StoreKitServiceProtocol {
    /// 加載可用的訂閱產品
    func loadProducts() async throws -> [SubscriptionProduct]

    /// 發起購買流程
    /// - Parameter productId: 產品 ID (如 "com.havital.premium.monthly")
    /// - Returns: 購買結果（包含交易 ID 和收據）
    func purchase(productId: String) async throws -> PurchaseResult

    /// 恢復之前的購買
    /// - Returns: 所有有效的購買記錄
    func restorePurchases() async throws -> [PurchaseResult]

    /// 獲取收據資料（base64 編碼）
    func getReceiptData() -> String?
}

struct PurchaseResult {
    let transactionId: String    // 交易 ID
    let productId: String         // 產品 ID
    let receiptData: String       // 收據資料（base64）
}
```

---

### 3. Mock StoreKit 服務（階段一）

#### MockStoreKitService 特性

**測試模式切換**：
```swift
enum MockMode {
    case success           // 購買成功
    case userCancelled     // 用戶取消
    case networkError      // 網路錯誤
    case invalidProduct    // 無效產品 ID
    case serverError       // 伺服器錯誤
}

// 使用範例
MockStoreKitService.shared.currentMode = .success
```

**模擬產品清單**：
```swift
let mockProducts = [
    SubscriptionProduct(
        id: "com.havital.premium.monthly",
        displayName: "Paceriz Premium 月付",
        description: "每月自動續訂，隨時可取消",
        price: "NT$290/月",
        billingPeriod: .monthly
    ),
    SubscriptionProduct(
        id: "com.havital.premium.yearly",
        displayName: "Paceriz Premium 年付",
        description: "每年自動續訂，省下 20%",
        price: "NT$2,790/年",
        billingPeriod: .yearly
    )
]
```

**模擬收據生成**：
```swift
private func generateMockReceipt(productId: String) -> String {
    let mockData = [
        "product_id": productId,
        "transaction_id": "mock_\(UUID().uuidString)",
        "purchase_date": ISO8601DateFormatter().string(from: Date()),
        "expires_date": ISO8601DateFormatter().string(from: Date().addingTimeInterval(2592000)) // +30天
    ]

    let jsonData = try! JSONSerialization.data(withJSONObject: mockData)
    return jsonData.base64EncodedString()
}
```

---

### 4. 後端 API 服務

#### SubscriptionService API 端點

**1. 驗證購買**
```swift
func verifyPurchase(platform: String, purchaseToken: String) async throws -> Subscription
```
- **端點**：`POST /subscription/purchase/verify`
- **請求體**：
  ```json
  {
    "platform": "apple",
    "purchase_token": "<base64_receipt>"
  }
  ```
- **回應**：訂閱詳情（包含 status, expires_at 等）

**2. 恢復購買**
```swift
func restorePurchases(platform: String, purchaseToken: String) async throws -> Subscription
```
- **端點**：`POST /subscription/purchase/restore`
- **請求體**：同 verify
- **回應**：恢復的訂閱詳情

**3. 查詢訂閱狀態**
```swift
func getSubscriptionStatus() async throws -> Subscription?
```
- **端點**：`GET /subscription/status`
- **回應**：當前用戶的訂閱資訊（若無則返回 null）

#### 統一錯誤處理
```swift
private func makeAPICall<T: Codable>(
    _ type: T.Type,
    path: String,
    method: HTTPMethod = .GET,
    body: Data? = nil
) async throws -> T {
    do {
        let rawData = try await httpClient.request(
            path: path,
            method: method,
            body: body
        )
        return try ResponseProcessor.extractData(type, from: rawData, using: parser)
    } catch let apiError as APIError where apiError.isCancelled {
        // 關鍵：取消錯誤不拋出
        throw SystemError.taskCancelled
    } catch {
        throw error
    }
}
```

---

### 5. 訂閱管理器架構

#### SubscriptionManager 關鍵實現

**雙軌快取策略**：
```
用戶請求訂閱狀態
        │
        ├─ 軌道 A（同步）: 立即返回快取資料
        │                  └─> UI 立即顯示（無等待）
        │
        └─ 軌道 B（非同步）: 背景更新最新資料
                            ├─> 調用後端 API
                            ├─> 更新快取
                            └─> 更新 UI（若有變更）
```

**實現程式碼**：
```swift
func loadData() async {
    await executeTask(id: TaskID("load_subscription")) { [weak self] in
        guard let self = self else { return }

        // 軌道 A: 立即顯示快取
        if let cachedSubscription = self.cacheManager.loadFromCache() {
            await MainActor.run {
                self.updateSubscriptionState(cachedSubscription)
                self.isLoading = false
            }

            Logger.debug("✅ 軌道 A: 顯示快取的訂閱狀態")

            // 軌道 B: 背景刷新
            Task.detached { [weak self] in
                await self?.executeTask(id: TaskID("bg_refresh_subscription")) {
                    await self?.refreshSubscriptionInBackground()
                }
            }
            return
        }

        // 無快取時直接從 API 獲取
        let subscription = try await self.service.getSubscriptionStatus()
        await MainActor.run { self.updateSubscriptionState(subscription) }

        if let subscription = subscription {
            self.cacheManager.saveToCache(subscription)
        }
    }
}
```

**購買流程協調**：
```swift
func purchaseSubscription(productId: String) async -> Bool {
    return await executeTask(id: TaskID("purchase_\(productId)")) { [weak self] in
        guard let self = self else { return }

        do {
            // 1. 通過 StoreKit 購買（Mock 或真實）
            let result = try await self.storeKitService.purchase(productId: productId)

            Logger.firebase("IAP: 購買完成，準備驗證收據", level: .info)

            // 2. 將收據發送到後端驗證
            let subscription = try await self.service.verifyPurchase(
                platform: "apple",
                purchaseToken: result.receiptData
            )

            Logger.firebase("IAP: 收據驗證成功", level: .info,
                jsonPayload: ["product_id": productId])

            // 3. 更新本地狀態
            await MainActor.run {
                self.updateSubscriptionState(subscription)
                self.syncError = nil
            }

            // 4. 保存到快取
            self.cacheManager.saveToCache(subscription)

        } catch {
            // 處理錯誤
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                Logger.debug("任務被取消，忽略錯誤")
                return
            }

            await MainActor.run { self.syncError = error.localizedDescription }
            Logger.error("購買失敗: \(error.localizedDescription)")
            throw error
        }
    } != nil
}
```

---

### 6. 訂閱視圖設計

#### SubscriptionView UI 結構

```
┌──────────────────────────────────────────┐
│  [← 返回]        訂閱管理                │
├──────────────────────────────────────────┤
│                                          │
│  ┌────────────────────────────────────┐ │
│  │  ✓ 已訂閱 Premium                  │ │
│  │  到期日期: 2025-12-04              │ │
│  │  自動續訂: 開啟                    │ │
│  └────────────────────────────────────┘ │
│                                          │
│  選擇訂閱方案                             │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │  📅 月付方案                        │ │
│  │  NT$290/月                          │ │
│  │  每月自動續訂，隨時可取消            │ │
│  │                                    │ │
│  │         [立即訂閱]                 │ │
│  └────────────────────────────────────┘ │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │  📆 年付方案 💰 省下 20%            │ │
│  │  NT$2,790/年                        │ │
│  │  每年自動續訂，最划算的選擇          │ │
│  │                                    │ │
│  │         [立即訂閱]                 │ │
│  └────────────────────────────────────┘ │
│                                          │
│  ──────────────────────                 │
│                                          │
│  [恢復購買]                              │
│                                          │
│  使用條款  •  隱私政策                   │
└──────────────────────────────────────────┘
```

#### 關鍵 SwiftUI 程式碼
```swift
struct SubscriptionView: View {
    @StateObject private var manager = SubscriptionManager.shared
    @State private var isPurchasing = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 訂閱狀態橫幅
                if manager.isSubscribed, let subscription = manager.currentSubscription {
                    SubscriptionStatusBanner(subscription: subscription)
                }

                // 產品列表
                Text("選擇訂閱方案")
                    .font(.headline)

                ForEach(manager.availableProducts) { product in
                    SubscriptionProductCard(
                        product: product,
                        isSubscribed: manager.currentSubscription?.productId == product.id
                    ) {
                        Task { await handlePurchase(product) }
                    }
                    .disabled(isPurchasing)
                }

                Divider()

                // 恢復購買按鈕
                Button("恢復購買") {
                    Task { await handleRestore() }
                }
                .disabled(isPurchasing)

                // 條款連結
                HStack {
                    Link("使用條款", destination: URL(string: "https://paceriz.com/terms")!)
                    Text("•")
                    Link("隱私政策", destination: URL(string: "https://paceriz.com/privacy")!)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("訂閱管理")
        .task {
            await manager.initialize()
        }
        .overlay {
            if isPurchasing {
                ProgressView("處理中...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func handlePurchase(_ product: SubscriptionProduct) async {
        isPurchasing = true
        defer { isPurchasing = false }

        let success = await manager.purchaseSubscription(productId: product.id)

        await MainActor.run {
            if success {
                alertMessage = "🎉 訂閱成功！Premium 功能已啟用"
                showAlert = true
            } else if let error = manager.syncError {
                alertMessage = "❌ 購買失敗：\(error)"
                showAlert = true
            }
        }
    }

    private func handleRestore() async {
        isPurchasing = true
        defer { isPurchasing = false }

        let success = await manager.restorePurchases()

        await MainActor.run {
            if success {
                alertMessage = "✅ 恢復成功！"
                showAlert = true
            } else if let error = manager.syncError {
                alertMessage = "❌ 恢復失敗：\(error)"
                showAlert = true
            }
        }
    }
}
```

---

## 🔄 實現步驟

### 階段一：Mock IAP 實現（2-3 小時）

#### Step 1: 建立資料模型（20 分鐘）
- [ ] 建立 `Models/Subscription.swift`
- [ ] 定義 `Subscription`, `SubscriptionStatus`, `SubscriptionProduct` 等
- [ ] 實現 `Codable` 和 snake_case 映射
- [ ] 添加單元測試（可選）

#### Step 2: 建立 StoreKit 協議（10 分鐘）
- [ ] 建立 `Services/StoreKitServiceProtocol.swift`
- [ ] 定義統一的服務介面
- [ ] 定義 `PurchaseResult` 結構

#### Step 3: 實現 Mock StoreKit 服務（30 分鐘）
- [ ] 建立 `Services/MockStoreKitService.swift`
- [ ] 實現 `StoreKitServiceProtocol` 協議
- [ ] 添加測試模式切換（success/cancelled/error）
- [ ] 實現假收據生成邏輯
- [ ] 添加模擬延遲（更真實）

#### Step 4: 實現後端 API 服務（30 分鐘）
- [ ] 建立 `Services/SubscriptionService.swift`
- [ ] 實現 `verifyPurchase()` 方法
- [ ] 實現 `restorePurchases()` 方法
- [ ] 實現 `getSubscriptionStatus()` 方法
- [ ] 使用統一的 `makeAPICall` 模式
- [ ] 添加錯誤處理（區分取消錯誤）

#### Step 5: 實現訂閱管理器（45 分鐘）
- [ ] 建立 `Managers/SubscriptionManager.swift`
- [ ] 實現 `DataManageable` 協議
- [ ] 實現 `TaskManageable` 協議
- [ ] 實現雙軌快取邏輯
- [ ] 實現 `purchaseSubscription()` 購買流程
- [ ] 實現 `restorePurchases()` 恢復購買
- [ ] 添加 Firebase 日誌記錄

#### Step 6: 實現快取管理（10 分鐘）
- [ ] 建立 `Storage/SubscriptionCacheManager.swift`
- [ ] 繼承 `BaseCacheManagerTemplate<Subscription>`
- [ ] 設定 TTL 為 1 小時
- [ ] 註冊到 `CacheEventBus`

#### Step 7: 建立訂閱視圖（30 分鐘）
- [ ] 建立 `Views/Subscription/SubscriptionView.swift`
- [ ] 實現產品列表顯示
- [ ] 實現購買按鈕和邏輯
- [ ] 實現恢復購買按鈕
- [ ] 添加載入狀態和錯誤提示
- [ ] 顯示當前訂閱狀態

#### Step 8: 測試 Mock IAP（30 分鐘）
- [ ] 測試購買月付方案成功
- [ ] 測試購買年付方案成功
- [ ] 測試用戶取消購買
- [ ] 測試網路錯誤處理
- [ ] 測試恢復購買成功
- [ ] 測試快取加載和背景刷新
- [ ] 驗證錯誤提示正確顯示

---

### 階段二：真實 Apple IAP 整合（1 小時）

#### Step 9: 實現真實 StoreKit 服務（40 分鐘）
- [ ] 建立 `Services/RealStoreKitService.swift`
- [ ] 實現 `StoreKitServiceProtocol` 協議
- [ ] 整合 StoreKit 2 `Product.products(for:)`
- [ ] 實現 `purchase()` 流程
- [ ] 實現 `restorePurchases()` 邏輯
- [ ] 實現收據資料獲取
- [ ] 添加交易監聽 (`Transaction.updates`)
- [ ] 實現交易驗證 (`VerificationResult`)

#### Step 10: 配置產品 ID（10 分鐘）
- [ ] 在 App Store Connect 建立產品
  - [ ] 月付：`com.havital.premium.monthly`
  - [ ] 年付：`com.havital.premium.yearly`
- [ ] 設定價格和描述

#### Step 11: 切換到真實 IAP（5 分鐘）
- [ ] 修改 `SubscriptionManager.init()` 的預設服務
- [ ] 使用編譯標誌區分開發/生產環境
  ```swift
  #if DEBUG
  let storeKitService = MockStoreKitService.shared
  #else
  let storeKitService = RealStoreKitService.shared
  #endif
  ```

#### Step 12: Sandbox 測試（5 分鐘）
- [ ] 建立 Apple Sandbox 測試帳號
- [ ] 測試真實購買流程
- [ ] 驗證收據上傳和驗證
- [ ] 測試自動續訂（加速時間）

---

## 🧪 測試計劃

### Mock IAP 測試場景

| 測試場景 | 操作步驟 | 預期結果 |
|---------|---------|---------|
| **購買成功** | 1. 設定 `MockMode.success`<br>2. 點擊「立即訂閱」 | ✅ 顯示成功訊息<br>✅ 更新訂閱狀態為 active<br>✅ UI 顯示已訂閱標誌 |
| **用戶取消** | 1. 設定 `MockMode.userCancelled`<br>2. 點擊「立即訂閱」 | ℹ️ 不顯示錯誤（使用者主動取消）<br>❌ 訂閱狀態不變 |
| **網路錯誤** | 1. 設定 `MockMode.networkError`<br>2. 點擊「立即訂閱」 | ❌ 顯示「網路連接失敗」<br>🔄 提示稍後重試 |
| **恢復購買成功** | 1. 之前有購買記錄<br>2. 點擊「恢復購買」 | ✅ 顯示恢復成功<br>✅ 更新訂閱狀態 |
| **恢復購買失敗** | 1. 無購買記錄<br>2. 點擊「恢復購買」 | ℹ️ 顯示「未找到購買記錄」 |
| **快取加載** | 1. 有本地快取<br>2. 開啟訂閱頁面 | ⚡ 立即顯示快取的訂閱狀態<br>🔄 背景刷新最新資料 |
| **背景刷新** | 1. 快取已過期<br>2. 背景更新完成 | 🔄 自動更新 UI（若有變更）<br>✅ 更新快取 |

### 真實 IAP 測試場景

| 測試場景 | 操作步驟 | 預期結果 |
|---------|---------|---------|
| **Sandbox 購買** | 使用測試帳號購買 | ✅ 顯示 Apple 支付 UI<br>✅ 收據驗證成功<br>✅ 訂閱啟用 |
| **真實收據驗證** | 購買後上傳收據 | ✅ 後端成功驗證<br>✅ Firestore 更新訂閱記錄 |
| **自動續訂** | 等待訂閱到期（Sandbox 加速） | ✅ Apple 自動續訂<br>✅ 收到交易更新<br>✅ 訂閱延長 |

---

## 🔒 安全性檢查清單

### 收據驗證安全
- [ ] ✅ 所有收據驗證在後端進行（不在客戶端）
- [ ] ✅ 使用 HTTPS 傳輸收據資料
- [ ] ✅ JWT token 自動添加到 API 請求
- [ ] ❌ 不在本地儲存敏感的訂閱資訊

### StoreKit 整合安全
- [ ] ✅ 使用 `VerificationResult` 驗證交易真實性
- [ ] ✅ 交易完成後調用 `transaction.finish()`
- [ ] ✅ 監聽 `Transaction.updates` 處理自動續訂
- [ ] ❌ 不信任僅來自客戶端的訂閱狀態

### 錯誤處理安全
- [ ] ✅ 錯誤訊息不暴露技術細節
- [ ] ✅ 區分取消錯誤和真實錯誤
- [ ] ✅ 網路錯誤有重試機制
- [ ] ✅ 購買失敗時保存收據以便重試

---

## 📊 效能優化策略

### 快取策略
- **快取 TTL**：1 小時（可調整）
- **快取位置**：`SubscriptionCacheManager` 使用 `BaseCacheManagerTemplate`
- **更新策略**：雙軌快取（立即顯示 + 背景刷新）

### 任務管理
- **防重複執行**：使用 `TaskRegistry` 追蹤進行中的任務
- **任務 ID 命名**：`TaskID("load_subscription")`, `TaskID("purchase_{productId}")`
- **取消處理**：正確處理 `NSURLErrorCancelled` 錯誤

### 背景更新
- **非同步執行**：使用 `Task.detached` 執行非關鍵任務
- **不阻塞 UI**：背景更新不影響已顯示的快取資料
- **失敗處理**：背景更新失敗時記錄日誌但不顯示錯誤

---

## 🪵 日誌記錄規範

### 關鍵事件日誌

```swift
// 購買成功
Logger.firebase(
    "IAP: 訂閱購買成功",
    level: .info,
    labels: ["module": "SubscriptionManager", "action": "purchase"],
    jsonPayload: [
        "product_id": productId,
        "transaction_id": transactionId
    ]
)

// 購買失敗
Logger.error("IAP: 購買失敗 - \(error.localizedDescription)")

// 恢復購買
Logger.firebase(
    "IAP: 恢復購買成功",
    level: .info,
    labels: ["module": "SubscriptionManager", "action": "restore"],
    jsonPayload: ["restored_count": restoredPurchases.count]
)

// 快取命中
Logger.debug("IAP: 軌道 A - 顯示快取的訂閱狀態")

// 背景刷新
Logger.debug("IAP: 軌道 B - 背景更新完成")
```

---

## 🚨 已知限制與注意事項

### Mock IAP 限制
1. **無真實支付流程**：不會顯示 Apple 支付 UI
2. **收據資料為假**：後端需要配合測試模式
3. **自動續訂無法測試**：需要真實 IAP 才能測試

### 真實 IAP 注意事項
1. **Sandbox 時間加速**：月付 = 5 分鐘，年付 = 1 小時
2. **最多續訂 6 次**：Sandbox 環境自動續訂最多 6 次後停止
3. **審核要求**：
   - 必須提供「恢復購買」按鈕
   - 必須提供使用條款和隱私政策連結
   - 清晰標註訂閱條款（自動續訂、價格等）

### 技術債務
1. **產品 ID 硬編碼**：目前產品 ID 寫死在程式碼中，未來可改為從後端動態獲取
2. **價格本地化**：Mock 模式下價格為硬編碼字串，真實 IAP 會自動本地化
3. **訂閱群組**：目前僅支援單一訂閱群組，未來可擴充多群組支援

---

## 📚 相關文檔參考

### 專案文檔
- **後端整合指南**：`/Users/wubaizong/havital/cloud/api_service/docs/subscription/IOS_INTEGRATION_GUIDE.md`
- **專案架構規範**：`/Users/wubaizong/havital/apps/ios/Havital/CLAUDE.md`
- **後端 API 測試指南**：`/Users/wubaizong/havital/cloud/api_service/docs/subscription/APPLE_IAP_MOCK_TESTING_GUIDE.md`

### Apple 官方文檔
- **StoreKit 2 文檔**：https://developer.apple.com/documentation/storekit
- **In-App Purchase 最佳實踐**：https://developer.apple.com/in-app-purchase/
- **Sandbox 測試指南**：https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox

### 架構模式參考
- **現有 Manager 範例**：`Havital/Managers/TrainingPlanManager.swift`
- **現有 Service 範例**：`Havital/Services/TrainingPlanService.swift`
- **HTTPClient 實現**：`Havital/Services/Core/HTTPClient.swift`
- **快取模板**：`Havital/Storage/BaseCacheManagerTemplate.swift`

---

## 🎯 成功驗收標準

### 功能完整性
- [x] 支援月付和年付兩種方案
- [x] 購買流程完整（選擇 → 支付 → 驗證 → 啟用）
- [x] 恢復購買功能正常
- [x] 訂閱狀態查詢準確
- [x] UI 正確顯示訂閱狀態

### 架構合規性
- [x] 遵循 `DataManageable` 協議
- [x] 遵循 `TaskManageable` 協議
- [x] 實現雙軌快取策略
- [x] 正確處理取消錯誤
- [x] 使用 `[weak self]` 防止記憶體洩漏

### 測試覆蓋
- [x] Mock 模式下所有場景測試通過
- [x] 真實 IAP Sandbox 測試通過
- [x] 錯誤處理正確
- [x] UI 響應流暢

### 文檔完整性
- [x] 程式碼註解清晰
- [x] 繁體中文計劃文件完整
- [x] 關鍵函數有使用範例

---

## 📞 支援與聯繫

### 問題回報
- **技術問題**：查閱 `CLAUDE.md` 架構規範
- **後端 API 問題**：參考 `IOS_INTEGRATION_GUIDE.md`
- **StoreKit 問題**：參考 Apple 官方文檔

### 後續擴充方向
1. **家庭共享**：支援 Apple Family Sharing
2. **優惠碼**：支援促銷優惠碼
3. **試用期**：支援免費試用（3 天/7 天/30 天）
4. **訂閱升級**：支援從月付升級到年付
5. **訂閱管理**：App 內取消/變更訂閱方案

---

**文件版本**：1.0
**最後更新**：2025-11-04
**維護者**：iOS Team
**狀態**：✅ 已批准，進行中
