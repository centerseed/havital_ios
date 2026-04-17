# Review Report: 2026-04-14 Session (VDOT Fix + Simplify)

## Verdict
PASS WITH MINOR ISSUES

## Scope
- **Commit `63daeda`**: fix: Profile 配速區間不顯示（VDOTManager 載入時機）
- **Uncommitted**: simplify — 9 項 code reuse / quality / efficiency 修復

## Issues Found

### 🔴 Blocking (must fix before merge)

None.

### 🟡 Important (should fix)

- [ ] `SubscriptionStatusEntity.swift:44-49` — Equatable 實作漏掉 `rizoUsage`。當 rizoUsage.used 變動但其他欄位不變時，`StateManager.update()` 的 no-op guard 會吞掉更新，UI 不會反映最新的 Rizo 配額。應加上 `RizoUsage: Equatable` 並在 `==` 中比較。

- [ ] `SubscriptionRepositoryImpl.swift:15` — `cachedOfferings` 是 `private var` 但 `SubscriptionRepositoryImpl` 是 non-actor class。如果 `fetchOfferings()` 和 `purchase()` 從不同 Task 同時存取，有 data race 的理論風險。目前 UI 流程是先 fetch 再 purchase（sequential），實際風險低，但 Sendable 檢查開嚴可能會報 warning。考慮加 `@MainActor` 或用 actor isolation。

### 🟢 Minor (optional)

- [ ] `PaywallView.swift:94` — `if case .failed(let message) = viewModel.purchaseState { Text(message) }` 在 alert message ViewBuilder 裡。如果 `purchaseState` 在 alert 顯示後被重置為 `.idle`（理論上 alert dismiss 前不會），message 會消失。當前流程安全，但可考慮在 alert binding 的 `set` 裡統一處理。

- [ ] `UserProfileFeatureViewModel.swift:217-222` — Combine 訂閱 `VDOTManager.shared.$statistics` 用了 `.receive(on: DispatchQueue.main)`。ViewModel 已是 `@MainActor`，理論上不需要。不會造成問題（多一次 dispatch），但略冗餘。

## Change-by-Change Verification

### VDOT Fix (`63daeda`)
| 項目 | 驗證 | 位置 |
|------|------|------|
| Combine 訂閱 VDOTManager.$statistics | ✅ `[weak self]` + `.store(in: &cancellables)` | `UserProfileFeatureViewModel.swift:217-222` |
| loadVDOT() 先載入本地快取 | ✅ `loadLocalCacheSync()` 在 `currentVDOT` 賦值前 | `UserProfileFeatureViewModel.swift:270-272` |
| 不改 VDOTManager 本身 | ✅ 只動 ViewModel 和 View | — |
| Clean build | ✅ BUILD SUCCEEDED | — |

### Simplify（未 commit）
| # | 修復 | 驗證 | 風險 |
|---|------|------|------|
| 1 | `periodLengthInDays` → `SubscriptionOfferPeriodUnit.lengthInDays(value:)` | ✅ 算式等價，兩處呼叫端更新 | 無 |
| 2 | `trialDaysRemaining` → `SubscriptionStatusEntity.daysRemaining` | ✅ 公式等價，3 處呼叫端更新，舊 helper 刪除 | 無 |
| 3 | 移除冗餘 `NSURLErrorCancelled` 檢查 | ✅ `isCancellationError` 已涵蓋（見 ErrorHelpers.swift） | 無 |
| 4 | 刪除 `purchaseErrorMessage` 雙態 | ✅ alert 從 `purchaseState` 衍生，單一狀態源 | 低（見 Minor #1） |
| 6 | `UITestPaywallHostView` 加 `#if DEBUG` | ✅ 檔案 + HavitalApp 引用都加了 guard | 無 |
| 8 | `ISO8601DateFormatter` 改 `static let` | ✅ 格式設定不變 | 無 |
| 9 | `cachedOfferings` 避免 purchase 重複拉取 | ✅ fetch 時快取，purchase 優先用快取，fallback 仍拉新的 | 低（見 Important #2） |
| 10 | `StateManager.update()` no-op guard | ✅ 但 Equatable 漏掉 rizoUsage | 中（見 Important #1） |

## Architecture Compliance
- [x] ViewModel 依賴 Repository Protocol（PaywallViewModel → SubscriptionRepository）
- [x] Entity 無 Codable（SubscriptionStatusEntity）
- [x] `[weak self]` in async closures
- [x] TaskManageable 正確實作（PaywallViewModel + UserProfileFeatureViewModel）
- [x] Debug code 包在 `#if DEBUG`（UITestPaywallHostView）
- [ ] API calls 缺 `.tracked()` — 不在此 session scope，已記錄為 backlog

## Summary

本 session 的改動品質良好。VDOT fix 用 Combine 訂閱解決了載入時機問題，是合乎架構的正確做法。Simplify 的 9 項修復都是等價重構，build 通過。

唯一需要在 merge 前修的是 **Equatable 漏掉 rizoUsage**（Important #1），否則 Rizo 配額更新會被 no-op guard 吞掉。其餘都是低風險的 optional 改善。
