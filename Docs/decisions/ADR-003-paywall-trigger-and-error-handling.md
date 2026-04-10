---
type: ADR
id: ADR-003
status: Draft
created: 2026-04-09
updated: 2026-04-09
---

# ADR-003: 付費牆觸發機制與 403/429 統一處理

## Context

後端閘門會在兩種情況下返回非 2xx：
- `HTTP 403`：expired 用戶呼叫受限 API，body 含 `{"error": "subscription_required", "subscription": {...}}`
- `HTTP 429`：Rizo 配額用完，body 含 `{"error": "rizo_quota_exceeded", "rizo_usage": {...}}`

現有 `DefaultHTTPClient.validateHTTPResponse()` 的行為：
- 403 → `throw HTTPError.forbidden(String)`（body 轉成 raw string，結構丟失）
- 429 → `throw HTTPError.httpError(429, String)`（同上，body 結構丟失）

這意味著 ViewModel 在 catch 到 `HTTPError.forbidden` 時，無法直接拿到 subscription 物件，必須重新解析 error string，很脆。

付費牆觸發來源有兩個：
1. **主動**：App 進前景拉取 status → `status == "expired"` → 顯示付費牆
2. **被動**：用戶操作某功能 → API 回 403 → 顯示付費牆

架構問題：被動觸發是否要在每個 ViewModel 各自處理，還是統一攔截？

## Decision

**採用「HTTPClient 解析 + DomainError 傳遞 + ViewModel 各自響應」的三層策略，不引入全域攔截器。**

具體決策：

1. **HTTPClient 解析 403/429 body（關鍵改動）**：在 `validateHTTPResponse()` 裡針對 403 和 429 嘗試解析 JSON body，解析成功時 throw 攜帶結構化資訊的專屬 error case：

   ```swift
   // HTTPError 新增兩個 case：
   case subscriptionRequired(SubscriptionErrorPayload)   // 403
   case rizoQuotaExceeded(RizoUsagePayload)              // 429
   ```

   `SubscriptionErrorPayload` 和 `RizoUsagePayload` 是 Data 層的輕量 struct（只需 Decodable，存在 `HTTPClient.swift` 旁邊的 `HTTPErrorPayloads.swift`）。解析失敗時 fallback 到原有的 `HTTPError.forbidden(String)` 和 `HTTPError.httpError(429, String)`。

2. **Repository 層轉換為 DomainError**：`SubscriptionRemoteDataSource` 和所有 feature 的 RemoteDataSource 在 catch HTTPError 時，將 `.subscriptionRequired` 轉為 `DomainError.subscriptionRequired`，將 `.rizoQuotaExceeded` 轉為 `DomainError.rizoQuotaExceeded`。這樣 ViewModel 收到的是 Domain 語意，不是 HTTP 細節。

3. **付費牆觸發：不引入全域攔截器，各 ViewModel 自行響應**：

   選擇不在 HTTPClient 或 AppViewModel 層做全域攔截的原因：
   - 不同功能對「無法使用」的 UI 響應不同（有些是 sheet、有些是 banner、有些是 inline 提示）
   - 全域攔截需要 ViewModel → Service 的反向通知機制，引入 NotificationCenter 或 Combine publisher，比讓各 ViewModel 自己 catch 更複雜
   - 現有 codebase 沒有全域 error coordinator 的 precedent

   統一做法：在需要閘門保護的 ViewModel 的 catch block 加：
   ```swift
   } catch DomainError.subscriptionRequired {
       paywallTrigger = .apiGated  // @Published var paywallTrigger: PaywallTrigger?
   } catch DomainError.rizoQuotaExceeded {
       showRizoQuotaExceededBanner = true
   }
   ```

4. **主動觸發（前景刷新）**：`AppViewModel.onAppBecameActive()` 呼叫 `subscriptionRepository.refreshStatus()`，結果存入緩存。各 ViewModel 需要時從緩存取，或訂閱 `@Published` 的 status。

   具體機制：建立 `SubscriptionStateManager`（Core 層，Singleton），持有 `@Published var currentStatus: SubscriptionStatusEntity?`。`SubscriptionRepositoryImpl.refreshStatus()` 更新後通知 `SubscriptionStateManager`。需要顯示試用剩餘天數、billing_issue banner 的 View 訂閱 `SubscriptionStateManager.currentStatus`。

5. **NSURLErrorCancelled 規則同樣適用於 SubscriptionRepository**：遵循 CLAUDE.md 規則，filter `HTTPError.cancelled` 後不更新 UI state。

## Alternatives

| 方案 | 優點 | 缺點 | 為什麼不選 |
|------|------|------|----------|
| HTTPClient 全域攔截 403 直接顯示付費牆 | 無需各 ViewModel 處理 | HTTPClient 是 Core 層，直接調 UI 違反依賴方向（Core 不能知道 Presentation）；不同場景 UI 不同 | 違反架構依賴方向，且 HTTPClient 無法知道應顯示哪種 UI |
| NotificationCenter 廣播 subscriptionRequired | 去耦合，任何地方都能響應 | 隱式依賴，難追蹤觸發源；通知漏掉或重複觸發難 debug | 現有 codebase 對 NC 的使用是 backward compatibility 用途，不是主要通信機制 |
| 不改 HTTPClient，ViewModel 自己解析 error string | 不改動現有 HTTPClient | 每個 ViewModel 都要解析 JSON string，重複且脆 | 違反 DRY，error string 格式一旦改變所有 ViewModel 都要改 |
| 全域 SubscriptionGuard middleware | 統一邏輯 | 需要引入全新的 middleware 機制，現有 codebase 無此 pattern | YAGNI，現有 feature 數量不多，各 ViewModel 處理的重複量可接受 |

## Consequences

**正面**：
- HTTPClient 解析一次，所有 caller 得到結構化 error，不需要各自解析 JSON string
- DomainError 語意清晰，ViewModel 的 catch block 易讀
- 不引入新機制，與現有 codebase 一致

**負面**：
- 每個有付費牆需求的 ViewModel 都要加 catch block（估計 4-6 個 ViewModel：TrainingPlan 生成、Rizo、Overview、WeeklySummary）
- `SubscriptionStateManager` 是一個新的 Singleton，需要謹慎管理其生命週期和測試 isolation

**需要注意**：
- HTTPClient 的 `validateHTTPResponse` 改動影響所有 feature，需要確保 fallback 邏輯完整，解析失敗不能 crash
- `SubscriptionStateManager` 的 `@Published` 屬性必須在 `@MainActor` 上更新，避免 threading 問題
- `DomainError` enum 目前是否已存在 [未確認]，若無需新建

## Implementation

### HTTPErrorPayloads.swift（新增，放在 Services/Core/ 旁）

```swift
struct SubscriptionErrorPayload: Decodable {
    let error: String           // "subscription_required"
    let subscription: SubscriptionStatusRaw
}

struct RizoUsagePayload: Decodable {
    let error: String           // "rizo_quota_exceeded"
    let rizoUsage: RizoUsageRaw
}
```

### HTTPClient 改動（validateHTTPResponse）

```swift
case 403:
    if let payload = try? JSONDecoder().decode(SubscriptionErrorPayload.self, from: data) {
        throw HTTPError.subscriptionRequired(payload)
    }
    throw HTTPError.forbidden(errorBody)

// 在 httpError default 之前：
case 429:
    if let payload = try? JSONDecoder().decode(RizoUsagePayload.self, from: data) {
        throw HTTPError.rizoQuotaExceeded(payload)
    }
    throw HTTPError.httpError(429, errorBody)
```

### SubscriptionStateManager（新增，Core 層）

```swift
@MainActor
final class SubscriptionStateManager: ObservableObject {
    static let shared = SubscriptionStateManager()
    @Published private(set) var currentStatus: SubscriptionStatusEntity?

    func update(_ status: SubscriptionStatusEntity) {
        currentStatus = status
    }
}
```

### 需要處理付費牆的 ViewModel（估計範圍）

- `TrainingPlanGenerationViewModel` — 生成課表 → 403
- `RizoViewModel` — Rizo AI → 403 / 429
- `WeeklySummaryViewModel` — Summary 生成 → 403
- `OverviewViewModel` — Overview 分析 → 403

各 ViewModel 在 catch `DomainError.subscriptionRequired` 時設置 `@Published var showPaywall = true`，對應的 View 顯示 `PaywallSheet`。
