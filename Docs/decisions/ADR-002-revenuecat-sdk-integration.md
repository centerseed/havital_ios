---
type: ADR
id: ADR-002
status: Draft
created: 2026-04-09
updated: 2026-04-09
---

# ADR-002: RevenueCat SDK 隔離策略

## Context

iOS 需要整合 RevenueCat SDK 處理 IAP 購買流程（任務 T5，目前 BLOCKED 等 App Store Connect 設定）。

關鍵約束（來自後端 API 文件）：
- `appUserID` 必須設為 Firebase UID，這是 webhook 對應 Firestore 用戶的前提，不得用 RevenueCat 自動匿名 ID
- 定價必須從 RevenueCat Offerings API 拉取，不得 hardcode
- **App 端功能閘門以後端為準**：不信任 RevenueCat SDK 的本機訂閱狀態（防 receipt 操控）
- 購買成功後要輪詢後端 status API 直到 `status == subscribed`（最多 30 秒，每 2 秒一次）

架構約束（來自 CLAUDE.md 和 codebase）：
- Domain 層不能 import 任何外部 SDK（`Presentation → Domain → Data → Core`，外部 SDK 只能在 Data 或 Core 層）
- ViewModel 依賴 Repository Protocol，不依賴 RepositoryImpl
- 所有 SDK 初始化在 `HavitalApp.init()` 完成，順序必須正確

現有 SDK 初始化參考：Firebase 在 HavitalApp.init() 最先，DI bootstrap 在 Firebase 之後。

## Decision

**統一採用 Facade 模式：RevenueCat SDK 封裝在 Data 層的 `RevenueCatDataSource` 裡，Domain 層完全不知道 RevenueCat 的存在。**

具體決策：

1. **SDK 初始化位置**：在 `HavitalApp.init()` 的 Step 2（DI bootstrap 完成後）增加 Step 2.5，呼叫 `RevenueCatConfigurator.setup()`。此時 Firebase 已就緒、Auth 模組已註冊，可以安全取得 Firebase UID。初始化代碼：

   ```swift
   // RevenueCatConfigurator.swift（Data 層 Infrastructure）
   Purchases.configure(
     with: .init(withAPIKey: RevenueCatConfig.apiKey)
       .with(appUserID: Auth.auth().currentUser?.uid)
   )
   ```

   `RevenueCatConfig.apiKey` 從環境（`Info.plist` 或 `APIConfig`）讀取，不得 hardcode 在 source。

2. **SDK 封裝位置**：建立 `RevenueCatDataSource`（Data 層），負責三件事：
   - `fetchOfferings()` → 取 RevenueCat Offerings，轉換為 Domain 的 `SubscriptionOfferingEntity`
   - `purchase(package:)` → 呼叫 `Purchases.shared.purchase(package:)`，回傳結果
   - `restorePurchases()` → 呼叫 `Purchases.shared.restorePurchases()`

   `RevenueCatDataSource` 只 import RevenueCat，只在 Data 層使用。

3. **Domain 層隔離**：`SubscriptionRepository` protocol 定義購買介面為：
   ```swift
   func fetchOfferings() async throws -> [SubscriptionOfferingEntity]
   func purchase(offeringId: String, packageId: String) async throws -> PurchaseResultEntity
   func restorePurchases() async throws
   ```
   Domain 層只知道 `SubscriptionOfferingEntity` 和 `PurchaseResultEntity`，不知道 `Package`、`Offerings`、`CustomerInfo` 等 RevenueCat 型別。

4. **功能閘門以後端為準**：購買後不信任 RevenueCat 的本機 CustomerInfo 決定是否解鎖。流程改為：購買成功 → 顯示「處理中」→ 呼叫後端 status API 輪詢 → `status == subscribed` → 解鎖。`SubscriptionRepositoryImpl` 實作此輪詢邏輯。

5. **Firebase UID 同步**：登出時呼叫 `Purchases.shared.logOut()`，登入時呼叫 `Purchases.shared.logIn(uid:)`，確保 RevenueCat 的 appUserID 與 Firebase UID 同步。這個呼叫放在 `AuthRepositoryImpl.signOut()` 和 `signIn()` 裡（Data 層），不污染 Domain。

## Alternatives

| 方案 | 優點 | 缺點 | 為什麼不選 |
|------|------|------|----------|
| 直接在 ViewModel 使用 RevenueCat SDK | 最快實作，少一層 | ViewModel 直接 import RevenueCat，SDK 升級影響所有 ViewModel；無法 mock | 違反 ViewModel 依賴 Protocol 的架構規則 |
| 信任 RevenueCat 本機狀態決定閘門 | 不需輪詢，反應快 | 後端文件明確標注「防 receipt 操控」，且本機狀態可能落後 webhook | 後端已明確要求以後端 status API 為準 |
| 在 Domain 層直接 import RevenueCat | 簡化 Mapper 層 | Domain 層耦合外部 SDK，違反 Clean Architecture 基本原則 | 架構規則硬性禁止 |
| RevenueCat 匿名 ID（不設 appUserID） | 初始化更簡單 | Webhook 無法對應 Firestore 用戶 ID，後端訂閱狀態無法更新 | 後端文件明確標注「必須用 Firebase UID」 |

## Consequences

**正面**：
- Domain 層零 RevenueCat 依賴，SDK 版本升級只改 Data 層
- 購買邏輯可 mock 測試（注入 mock SubscriptionRepository）
- 後端為訂閱閘門唯一真相，防止 receipt 操控

**負面**：
- T5 目前 BLOCKED，RevenueCat API key 和 App Store Connect IAP 設定完成前，`RevenueCatDataSource` 只能有 stub 實作
- 輪詢機制（最多 30 秒）增加購買後的等待時間，UX 需要明確的 loading 狀態

**需要注意**：
- RevenueCat API key 不得 hardcode，存放方式待確認（Info.plist 環境變數或後端動態下發）[未確認]
- T5 BLOCKED 期間，`PaywallViewModel` 的 `fetchOfferings()` 要有 graceful fallback，避免因 stub 拋錯而 crash

## Implementation

### 新增檔案

```
Havital/Features/Subscription/
├── Domain/
│   └── Entities/
│       ├── SubscriptionOfferingEntity.swift   # title, description, packages
│       └── PurchaseResultEntity.swift         # success / cancelled / pending / failed(Error)
├── Data/
│   ├── DataSources/
│   │   └── RevenueCatDataSource.swift         # import RevenueCat，Facade
│   ├── Infrastructure/
│   │   └── RevenueCatConfigurator.swift       # static setup()
│   └── Mappers/
│       └── RevenueCatMapper.swift             # Package/Offering → Entity
```

### 初始化順序（HavitalApp.init()）

```
1. FirebaseApp.configure()
2. AppDependencyBootstrap.registerAllModules()
2.5 RevenueCatConfigurator.setup()    ← 新增，Firebase Auth 已就緒後
3. FirebaseLogConfigurator.setup()
4. registerBackgroundTasks()
```

### 購買後輪詢（SubscriptionRepositoryImpl）

```swift
func purchase(offeringId: String, packageId: String) async throws -> PurchaseResultEntity {
    // 1. 呼叫 RevenueCatDataSource 執行購買
    let result = try await revenueCatDataSource.purchase(...)

    // 2. 購買成功後輪詢後端（最多 30 秒，每 2 秒）
    if result == .success {
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let status = try await remoteDataSource.fetchStatus()
            if status.status == "subscribed" {
                localDataSource.save(status)
                return .success
            }
        }
        return .pendingProcessing  // 超時，讓用戶重啟 App
    }
    return result
}
```

### Auth 整合（AuthRepositoryImpl）

```swift
// signIn 成功後
if let uid = firebaseUser.uid {
    try? await Purchases.shared.logIn(uid)
}

// signOut 前
try? await Purchases.shared.logOut()
```
