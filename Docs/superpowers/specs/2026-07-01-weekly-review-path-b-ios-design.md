# iOS 週回顧接上路徑 B（deferred 改課表）設計

- **日期**：2026-07-01
- **範圍**：iOS only（`apps/ios/Havital/`）。後端零改動。
- **相關 task**：重定義 [[T-0029-rizo-weekly-review-nl-input-ios]]（status: in-progress）。
- **後端定調**：`cloud/api_service/docs/superpowers/specs/2026-06-30-rizo-plan-change-paths-CONSOLIDATED.md`（路徑 A/B 對照）。

---

## 1. 背景與問題

後端「改課表路徑 B（週回顧 deferred）」在 2026-06-30 整條重建為「路徑 A 鏡像」，已 merge main、已部署 prod（merge `850e6ab3`、deployed revision `56e3f223`）。流程：

```
用戶在週回顧講自由 NL
  → POST /v2/agent/chat (scenario="weekly_situation")
  → 後端回 pending_plan_change 提案卡（確定性 allocator 預覽；封鎖日/減量）
  → 用戶確認 POST /v2/agent/plan-change/confirm { proposal_id }
  → 後端存 user_nl（application_mode="deferred_next_week"，零課表寫入）
  → 下週 generate() 那一次確定性套用
```

**iOS 落差**：iOS 週回顧目前的自由 NL 入口（T-0029，2026-06-23 merge iOS main）是照**舊後端設計**（一次性 chat → `deferred_stored:true` → 顯示回覆文字）做的：

- `WeeklySummaryCoordinator.submitUserNlEdit()`（`WeeklySummaryCoordinator.swift:110`）只呼叫一次 `rizoRepository.sendChat(scenario:"weekly_situation")`，且 `userNlSubmitState = .loaded(reply.reply)`（`:120`）——**只取回覆文字，把 `reply.pendingPlanChange` 丟掉**。
- 週回顧 View（`WeeklySummaryV2View`）**沒有提案卡 / 確認按鈕**（grep `pendingPlanChange` / `planChangeCard` 零命中）。

淨結果：用戶在週回顧打「下週不能跑」，後端回一張需確認的提案卡，iOS 收到就丟 → **propose→confirm→apply 這條無法從 App 端走完**。

---

## 2. 核心洞察：不是造新輪子，是接上既有引擎

`StateRizoChatViewModel(scenario:)`（`Features/Rizo/Presentation/ViewModels/StateRizoChatViewModel.swift`）**已經是 scenario-agnostic 的完整多輪對話引擎**：

- 接受 `scenario` 參數（`:60` init）→ 傳 `"weekly_situation"` 即跑路徑 B。
- 已渲染 `pendingPlanChange`（`:37` published、`:153` 從 reply 帶入）。
- `acceptPlanChange()`（`:92`）→ `repository.confirmPlanChange(proposalId:)`（只送 `proposal_id`，後端自行從 proposal 讀 `application_mode`，見 `plan_change_service.py:184`）。
- `dismissPlanChange()`（`:127`）→ 繼續討論（提案留後端，下次提案自動取代）。
- 付費牆 `paywallTrigger`（`:43`）+ 訂閱錯誤分流（`:110` `isSubscriptionError`）。

`RizoChatView`（`Features/Rizo/Presentation/Views/RizoChatView.swift:20`）吃 `@ObservedObject var viewModel: StateRizoChatViewModel`，`body` 已含 header / 泡泡 / typing / `planChangeCard(pending)` / `inputBar` + `@FocusState`。

**結論**：把週回顧接到這個既有引擎 + 拆掉舊一次性小框，即可。多輪對話、提案卡、confirm、反提案、付費牆全部免費拿到。

---

## 3. 設計決策（已與用戶逐項確認）

| # | 決策 | 選定 |
|---|------|------|
| D1 | 用哪種介面 | **複用完整對話介面**（`StateRizoChatViewModel` + `RizoChatView`），非擴充舊一次性小框 |
| D2 | 入口 | **週回顧內嵌完整對話**（非另開 sheet/push） |
| D3 | 開場 | **懶載入**——不呼叫 `startOpening()`；先顯靜態引導 + 輸入框，用戶打字才發第一次 chat（避免每次進週回顧都燒開場白 LLM） |
| D4 | confirm 後語意 | 依 scenario 決定文案：`weekly_situation` → 延後語意；`body_status` 維持即時語意 |

**複用理由**（記錄，防未來反覆）：多輪對話在週回顧 View 沒有任何技術障礙；選複用不是因為別的 surface「做不到」，而是 `StateRizoChatViewModel` 已寫好 message list / 提案卡 / confirm / paywall / dismiss，擴充舊 box 等於把這些再抄一遍。

---

## 4. 改動清單（iOS）

### ① 週回顧內嵌對話（主要工）
- `WeeklySummaryV2View`：**移除** T-0029 的一次性 NL 小框區塊（含 `userNlDraft` 綁定的輸入框 + Send 膠囊鈕 + reply 氣泡）。
- 改內嵌 `RizoChatView(viewModel:)`，viewModel 為 `StateRizoChatViewModel(scenario: "weekly_situation")`（lazy 建立、由 Coordinator 持有，見下）。
- **懶載入**：進頁不 `startOpening()`。內嵌區先顯一行靜態引導文字（i18n）+ 既有 `inputBar`，用戶送第一句才 `send(_:)`。
- **移除** `WeeklySummaryCoordinator` 的一次性路徑：`userNlDraft`（`:45`）、`userNlSubmitState`（`:47`）、`submitUserNlEdit()`（`:110`）——由內嵌對話取代。Coordinator 改持有/注入 `StateRizoChatViewModel`（或由 View 建立並由 Coordinator 提供 `RizoRepository` 依賴）。

### ② 延後語意（正確性關鍵）
- `StateRizoChatViewModel` confirm 成功後 append `Self.appliedText`（`:105`，字串 `rizo.plan_change.applied` = 「已為你套用，課表更新囉」）——此為**路徑 A（即時）語意**。
- 改法：把 `appliedText` 從 `static let`（`:131`）改為**依 `self.scenario` 決定的 instance 屬性**：
  - `scenario == "weekly_situation"` → 新 i18n key `rizo.plan_change.applied_deferred`（例：「已記下，下週生成課表時會自動幫你套用」）。
  - 其他 scenario → 沿用 `rizo.plan_change.applied`。
- 三語系（zh-TW / ja-JP / en-US）補 `rizo.plan_change.applied_deferred` + 內嵌引導文字 key。

### ③ 提案卡 / 反提案 / 不支援 —— iOS 零特別處理
- 封鎖日 → 後端回 `pendingPlanChange` → `RizoChatView.planChangeCard` 已渲染。
- 跑天太少 → 後端反提案（reply 文字 + 可能新卡）→ 多輪對話天生承接。
- 換質量型（不想跑間歇）→ 後端誠實回 unsupported 文字 → 一則 reply。

### ④ 失敗通知 —— 已就緒，保留
- `deferred_edit_failed` 本地通知（`AppDelegate.swift`）+ `weekly_review.deferred_failed.*` 三語 T-0029 已建，**不動**。

---

## 5. 技術風險 / 待驗

- **巢狀捲動 + 鍵盤**（唯一技術風險）：`RizoChatView` 原設計為卡片詳細頁下半、非嵌在另一個 ScrollView。內嵌到週回顧 `WeeklySummaryV2View`（ScrollView）時，其 message list（`ForEach` in `VStack`）+ `inputBar` + 鍵盤在外層 scroll 內的行為需驗。
  - **plan 第一步做 layout spike**：確認捲動不打架、鍵盤彈出時 `inputBar` 可見（沿用 T-0029 已建的 `@FocusState` + 完成鈕收鍵盤模式）。
  - 若巢狀 scroll 無法乾淨解 → fallback 為 D2 的替代（CTA→sheet 開全屏 `RizoChatView`），需回頭與用戶確認（但先嘗試內嵌）。

---

## 6. 不做（YAGNI）
- 不做「下週課表視覺標示 applied 調整」的狀態顯示（T-0029 DTO 的 `user_nl_edit_status` 欄位變半退役，留著不擴充）。
- 不動任何後端。
- 不新增 endpoint。

---

## 7. 驗收標準（Done Criteria）

1. **內嵌對話可多輪**：週回顧下方內嵌 `RizoChatView`，用戶打「下週五六爬山不能跑」→ 收到後端 `pending_plan_change` 提案卡（顯 summary/diff）→ 可「繼續討論」再改 → 可「接受」。
2. **confirm 走通**：按接受 → `POST /v2/agent/plan-change/confirm { proposal_id }` → `applied:true` → append 的教練訊息為**延後語意**（`applied_deferred`，非「已套用」）。
3. **懶載入**：進週回顧不觸發任何 chat LLM 呼叫；用戶送第一句才有 network（可用 network log / Charles 佐證）。
4. **路徑 A 零回歸**：今日卡片（`body_status`）confirm 後仍顯「已為你套用」即時語意；既有 `StateRizoChatViewModelTests` 綠。
5. **付費牆**：免費帳號按接受被 gate → 彈付費牆（`paywallTrigger`），不 append 假「已套用」。
6. **Maestro**：改寫 `.maestro/flows/weekly-review-nl-input.yaml` 成 propose→提案卡→confirm→斷言延後語意回覆；對 dev 後端 live 跑通（`--device iPhone17Pro`，不加 `--no-window`）。
7. `xcodebuild clean build`（iPhone 17 Pro）零錯誤；三語 i18n key 齊。

---

## 8. 與 T-0029 的關係

T-0029（in-progress）原設計（`2026-06-23-weekly-review-nl-input-ios-design.md`）是照舊 deferred_stored 機制做的一次性小框，已被後端 2026-06-30 重建 supersede。本 spec 重定義 T-0029 的實作範圍。實作開工時：
- T-0029 稽核軌跡補一行指向本 spec + 說明時序落差。
- `inflight.manifest.json`（iOS probe）+ `item_slug=weekly-review-deferred-nl-edit`（沿用）。
