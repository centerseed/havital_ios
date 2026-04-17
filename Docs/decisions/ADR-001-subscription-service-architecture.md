---
type: ADR
id: ADR-001
status: Proposed
created: 2026-04-09
updated: 2026-04-09
---

# ADR-001: 訂閱服務層架構設計

## Context

後端已完成 IAP 訂閱 Phase 1+2，iOS 需要整合訂閱狀態管理。核心問題是：`SubscriptionRepository` 應如何放進現有的 `Presentation → Domain → Data → Core` 架構，以及訂閱狀態緩存要放在哪裡。

現有 codebase 已有的 pattern：
- 所有 feature 都有 `Protocol`（Domain）、`Impl`（Data）、`LocalDataSource`、`RemoteDataSource` 四層
- Local cache 統一用 `UserDefaults + JSONEncoder + TTL timestamp`，key 帶版本號（如 `target_cache_v3`）
- `DependencyContainer` 用 `register(_:forProtocol:)` + `resolve()` 管理依賴
- `AppDependencyBootstrap.registerAllModules()` 是模組註冊的唯一入口

API 行為（來自後端文件）：
- `GET /api/v1/subscription/status` 首次呼叫自動初始化試用期
- 每次 App 進前景必須呼叫一次（用戶需求 T6）
- Status API 不可用時，用本機緩存繼續運作（寬鬆策略）
- `trial_active` / `subscribed` / `cancelled` = 放行；`expired` = 顯示付費牆
- 首次呼叫自動初始化試用期是**有意為之**：App 啟動 → 呼叫 status API → 試用期自動開始。這個設計省去額外的「啟動試用」API，App 端不需要判斷是否為首次用戶。接受的 trade-off 是：用戶在看到試用說明前，試用期已開始計時（後端以 status API 首次呼叫時間為起點）。

## Decision

**統一為 Repository 模式（與現有所有 feature 一致），SubscriptionRepository 放在 Domain 層，不引入獨立 Service 層。**

具體決策：

1. **選擇 Repository 而非 Service**：現有所有 feature（Target、TrainingPlan、UserProfile、Workout）都用 Repository 模式。引入 Service 層會讓 ViewModel 的依賴分兩種形狀（有時 Repository、有時 Service），增加認知負擔。訂閱狀態本質是數據存取，Repository 語意正確。

2. **緩存策略：統一使用 UserDefaults + JSON + TTL**：與 `TargetLocalDataSource` 相同的 pattern。key 用 `subscription_status_v1`。TTL 設為 300 秒（5 分鐘），因為訂閱狀態不像 Target 那麼靜態，但進前景刷新是強制的，所以 TTL 只是 API 故障時的後備。

   **不選 Keychain**：訂閱狀態不是 credential，是可重新 fetch 的業務狀態。Keychain 對 JSON struct 的讀寫需要額外封裝，且 Keychain 的沙盒限制讓 unit test 更難。若未來發現有安全疑慮再遷移。

   **不選純記憶體緩存**：App 殺掉重啟後重新 fetch 才能有緩存，如果啟動時網路差會閃付費牆給已付費用戶，體驗不可接受。

3. **DI 整合**：在 `SubscriptionRepositoryImpl.swift` 的 `DependencyContainer` extension 裡定義 `registerSubscriptionModule()`，在 `AppDependencyBootstrap.registerAllModules()` 加入呼叫，順序排在 Authentication 之後（因為 Subscription remote 呼叫需要 auth token，但不直接依賴 AuthRepository）。`SubscriptionRepositoryImpl` 以 Singleton 方式註冊（與所有其他 RepositoryImpl 一致），確保緩存狀態全域唯一。

4. **前景刷新掛載點**：在 `AppViewModel.onAppBecameActive()` 加入 `subscriptionRepository.refreshStatus()`，與其他刷新各自開 Task 並行執行。不在 HTTPClient 層自動觸發。

5. **付費牆阻擋策略**：
   - 付費牆判斷由 `AppViewModel` 持有 `SubscriptionStatusEntity`，並透過 `@Published var subscriptionStatus` 向下傳遞。
   - 各 feature 的進入點（如 AI Coach、Training Plan）在 View 層用 `.task` 或 `.onAppear` 時檢查 `appViewModel.subscriptionStatus.status == .expired`，若是則導向 PaywallView。
   - 不在 Navigation layer 全域攔截（過度集中），也不在各 ViewModel 各自判斷（分散且難維護）——集中在 View 層的 feature 入口做條件渲染。

## Alternatives

| 方案 | 優點 | 缺點 | 為什麼不選 |
|------|------|------|----------|
| 獨立 SubscriptionService（非 Repository） | 明確區分「業務邏輯」與「數據存取」 | 打破 codebase 所有其他 feature 的一致性；ViewModel 需要同時注入 Repository 和 Service | 現有 feature 全是 Repository，引入第二種形狀增加複雜度；訂閱邏輯在後端，App 端只是讀狀態 |
| Keychain 緩存 | 更安全，App 重裝後仍保留 | 需要額外封裝；不可序列化複雜 JSON struct；unit test 困難 | 訂閱狀態不是 credential，Keychain 的安全性收益不抵開發成本 |
| 純記憶體緩存 | 實作最簡單 | App 冷啟動無緩存，若啟動時網路差，已付費用戶看到付費牆 | 離線體驗不可接受，違反 T6 驗收標準「斷網時用緩存運作」 |
| 全域 Singleton SubscriptionManager | 任何地方都能直接取狀態 | 與現有 DI 機制衝突；難以 mock；隱式依賴 | 架構規則明確：ViewModel 依賴 Repository Protocol，不依賴 Singleton |

## Consequences

**正面**：
- 與現有所有 feature 一致，新開發者不需要學習新 pattern
- ViewModel 對 `SubscriptionRepository` protocol 依賴，unit test 可注入 mock
- `AppDependencyBootstrap` 是唯一入口，新模組的加入是可追蹤的

**負面**：
- 購買流程（RevenueCat）和狀態輪詢的邏輯會放在 ViewModel 裡，ViewModel 複雜度上升，需要拆成 `PaywallViewModel`
- UserDefaults 的 JSON 大小有限制（通常不是問題，但狀態物件需保持精簡）

**需要注意**：
- `SubscriptionStatusEntity`（Domain）和 `SubscriptionStatusDTO`（Data）必須分開，不能在 Entity 上加 `Codable`（架構規則）
- 緩存 key 帶版本號 `subscription_status_v1`，未來欄位變更時遷移方便
- `PaywallViewModel` 必須實作 `TaskManageable`（`TaskRegistry` + `cancelAllTasks()` in deinit），RevenueCat 購買流程是 async task，取消必須處理
- `SubscriptionRemoteDataSource` 的所有 API call 必須 chain `.tracked(from: "SubscriptionRemote: methodName")`
- `clearCache()` 的呼叫時機：在 `AuthViewModel.logout()` 完成後、新用戶 `AuthViewModel.login()` 開始前呼叫，確保帳號切換不污染緩存
- `subscription_status_v1` key 升版時，舊 key 由 `registerSubscriptionModule()` 在模組初始化時一次性清除

## Implementation

### 檔案結構

```
Havital/Features/Subscription/
├── Domain/
│   ├── Entities/
│   │   └── SubscriptionStatusEntity.swift   # status, expiresAt, planType, rizoUsage, billingIssue
│   └── Repositories/
│       └── SubscriptionRepository.swift      # protocol
├── Data/
│   ├── DTOs/
│   │   └── SubscriptionStatusDTO.swift       # snake_case + CodingKeys, Codable
│   ├── DataSources/
│   │   ├── SubscriptionLocalDataSource.swift
│   │   └── SubscriptionRemoteDataSource.swift
│   ├── Mappers/
│   │   └── SubscriptionMapper.swift          # DTO → Entity
│   └── Repositories/
│       └── SubscriptionRepositoryImpl.swift  # + DependencyContainer extension
```

### SubscriptionRepository Protocol（必填方法）

```swift
protocol SubscriptionRepository {
    /// 取得訂閱狀態（最佳可得值語意）：
    /// 有未過期緩存 → 直接回緩存；無緩存或已過期 → 打 API。
    /// 不做背景刷新，前景刷新由呼叫方透過 refreshStatus() 負責。
    func getStatus() async throws -> SubscriptionStatusEntity
    /// 強制從 API 刷新，更新緩存，回傳最新狀態
    func refreshStatus() async throws -> SubscriptionStatusEntity
    /// 取得緩存狀態（同步，用於啟動時快速判斷）
    func getCachedStatus() -> SubscriptionStatusEntity?
    /// 清除緩存（登出時調用）
    func clearCache()
}
```

### DI 註冊（加入 AppDependencyBootstrap）

```swift
// AppDependencyBootstrap.registerAllModules() 裡加：
// 2. Subscription 模組 (依賴 Authentication)
registerSubscriptionModule()
```

### 前景刷新（AppViewModel.onAppBecameActive()）

```swift
// 各刷新任務各自開 Task 並行執行，互不阻塞
Task {
    do {
        try await subscriptionRepository.refreshStatus()
    } catch {
        Logger.shared.error("Subscription refresh failed: \(error)")
    }
}
// 其他刷新同樣各自開 Task，錯誤各自處理，不中斷彼此
```
