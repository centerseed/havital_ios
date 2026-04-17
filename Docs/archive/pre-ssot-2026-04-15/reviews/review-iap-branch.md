# Review Report: iap branch

**Scope:** 51 files changed, +3169/-308 lines
**Spec:** PLAN-error-handling-refactor.md
**Reviewers:** 3 parallel code-reviewer agents + 人工逐條驗證

## Verdict

**NEEDS REWORK** — 2 blocking issues, 8 important issues

---

## Issues Found

### 🔴 Blocking (must fix before merge)

1. **PaywallView.swift:62** — `onChange(of:)` 使用 iOS 16 的單參數 closure 形式。iOS 18 上 Swift compiler 選到新 overload，`state` 拿到的是**舊值**不是新值。購買成功後 `dismiss()` 不會觸發——用戶卡在 PaywallView。
   ```swift
   // 現在（收到舊值）：
   .onChange(of: viewModel.purchaseState) { state in
   // 修正（收到新值）：
   .onChange(of: viewModel.purchaseState) { _, newState in
   ```

2. **PaywallViewModel.swift:55-57** — `restorePurchases()` 的 catch 沒有過濾 `CancellationError`/`NSURLErrorCancelled`。用戶離開 PaywallView 時，取消的 restore 操作會設 `purchaseState = .failed(error.localizedDescription)`，觸發「購買錯誤」alert。違反 CLAUDE.md 硬約束 #5。
   ```swift
   // 現在：
   } catch {
       purchaseState = .failed(error.localizedDescription)  // ← cancel 也走這
       throw error
   }
   // 修正：
   } catch {
       if error.isCancellationError { return }
       purchaseState = .failed(error.localizedDescription)
       throw error
   }
   ```

### 🟡 Important (should fix)

3. **SubscriptionRepositoryImpl.swift:33,46** — Repository 直接呼叫 `SubscriptionStateManager.shared.update()`。雖然 SubscriptionStateManager 不是 CacheEventBus（硬約束 #7 的字面對象），但 Repository 層主動 publish 全局狀態是設計問題——任何 `getStatus()` 呼叫都有 side effect，ViewModel 無法控制時機。建議將 update 移到 ViewModel/Service 層。

4. **TrainingPlanV2View.swift** — 8 個 `.sheet` modifier（L247,251,260,270,289,333,373,380）。SwiftUI 同一 view node 上同時只能有一個 active sheet。`paywallTrigger`（L380）和 `showFeedbackReport`（L373）在同一層級——雖然同時 true 的機率低，但付費牆是 IAP 核心功能，一旦被靜默丟棄後果嚴重。建議將 paywall sheet 移到更內層或用 `fullScreenCover` 隔離。

5. **SubscriptionStateManager.shared 直接在 ViewModel 使用** — `TrainingPlanV2ViewModel.swift:1065,1238`、`WeeklySummaryViewModel.swift:65`、`PaywallViewModel.swift:106` 直接讀 singleton 做業務判斷，繞過 DI，無法 mock 測試。應透過注入的 `SubscriptionRepository` 讀取。

6. **PaywallView/PaywallViewModel 所有 API 呼叫缺少 `.tracked(from:)`** — `PaywallView.swift` 的 Task blocks、`PaywallViewModel.swift:50,64,94,121`。production incident 無法歸因。違反 CLAUDE.md API call tracking 規則。

7. **LoginViewModel.swift:209-212** — `publishAuthenticationEvent` 中的 `subscriptionRepository.refreshStatus()` 缺少 `.tracked(from:)`。

8. **WeeklySummaryViewModel.swift:302-304** — `confirmAdjustments` 的 catch 直接 `summaryError = error`（raw Error），且沒有 `subscriptionRequired`/`trialExpired` 攔截。403 會顯示為 error 而非 paywall。

9. **WeeklySummaryViewModel.swift:152-153** — `loadWeeklySummary` 的 catch 有 cancellation guard 但沒有 subscription error 攔截（同檔的 `createWeeklySummary` 有）。且 `summaryError = error` 是 raw error 而非 domainError。

10. **SubscriptionRepositoryImpl.swift:17-20** — DataSource 用 default init 建構，未註冊到 DI container，無法被 mock 替換。其他 Repository（Target, MonthlyStats）都透過 DI 解析 DataSource。

### 🟢 Minor (optional)

11. **TrainingPlanV2ViewModel.swift:1314,1341** — debug 函式的 catch 直接 assign raw `Error` 到 `networkError`，沒走 `toDomainError()`。Debug-only 路徑，但共享 production UI 的 `networkError` 屬性。

12. **AppDependencyBootstrap.swift:51** — SubscriptionModule 註冊順序在最後（step 8），但 TrainingPlanV2ViewModel 依賴 subscription status。建議移到 step 6（TrainingPlanV2 之前）。目前因為 lazy resolution 不會 crash，但脆弱。

---

## PLAN-error-handling-refactor.md AC 驗證

| AC | 狀態 | 驗證位置 |
|----|------|---------|
| S01: APICallHelper.handleError 簡化 | ❌ 未執行 | APICallHelper.swift:129-144 仍是舊程式碼 |
| S02: 12 個函式統一 catch | ⚠️ 部分完成 | 3/15 函式已改。12 個仍用舊模式，功能正確但風格不統一 |
| S03: @Observable 遷移 | ❌ 未執行 | ViewModel 仍是 ObservableObject |
| toDomainError() 兜底 | ✅ 已完成 | DomainError.swift:150 — isCancellationError 就位 |
| HTTPError 新增 case | ✅ 已完成 | HTTPClient.swift:359-360 — subscriptionRequired + rizoQuotaExceeded |
| HTTPError.toDomainError() 映射 | ✅ 已完成 | DomainError.swift:178-181 — 所有 case 覆蓋 |

---

## 驗證方法

所有 blocking/important issues 經人工讀取原始碼確認：
- 🔴1: PaywallView.swift:62 確認 `{ state in` 單參數形式
- 🔴2: PaywallViewModel.swift:55-57 確認 catch 無 cancel guard
- 🟡3: SubscriptionRepositoryImpl.swift:33,46 確認 `SubscriptionStateManager.shared.update()` 呼叫
- 🟡4: TrainingPlanV2View.swift 確認 8 處 `.sheet(`
- 🟡8: WeeklySummaryViewModel.swift:304 確認 `summaryError = error` raw assign
- 🟡9: WeeklySummaryViewModel.swift:152-153 確認 `summaryError = error` 且無 subscription guard

原始 agent 報告中 🔴3 和 🔴4 經人工驗證後降級為 🟡（見下方理由）。

**🔴3 降級理由：** SubscriptionStateManager 不是 CacheEventBus，不直接違反硬約束 #7 的字面定義。是設計問題不是規則違反。
**🔴4 降級理由：** 8 個 sheet 分布在兩個 view node 層級（5 個在 NavigationStack 內，3 個在外層）。paywall 和 feedback 同時觸發的機率極低（需 API 返回 403 且用戶同時開了 feedback sheet）。

---

## Summary

2 個 blocking issues 都在 PaywallView/PaywallViewModel——IAP 購買核心路徑。`onChange` 棄用 API 導致購買成功不 dismiss（P0），`restorePurchases` 取消錯誤洩漏到 alert（P1）。

Error handling hotfix（toDomainError 兜底 + 3 個 catch 統一）功能正確，但 PLAN 中的 S01/S02/S03 都還沒執行，目前靠兜底邏輯撐住。

**建議：** 修 2 個 blocking → 按 PLAN 執行 S01→S02→S03 → 處理 important issues。
