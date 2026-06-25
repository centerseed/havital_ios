# Spec — 週回顧自由文字 NL 入口（iOS · 延後客製化下週課表）

- **Date**: 2026-06-23
- **Scope**: iOS 為主（後端 deferred 鏈核心已備已部署、不動架構；本 spec 額外含小範圍後端補洞：i18n / 輸入驗證 / `deferred_stored` 回饋旗標 / 優先序測試）
- **Task**: `STATUS/tasks/T-0029-rizo-weekly-review-nl-input-ios.md`
- **Track**: 這是「週回顧體驗」兩條獨立子專案的 **Track 1**。Track 2（強化回顧洞察，後端為主）另有 spec。

---

## 1. 背景與目標

### 問題
用戶想在**週回顧**時，用自己的話告訴 Rizo「下週想怎麼調整課表」（Mike 退訂信主訴求）。但現在 iOS 週回顧畫面只有**結構化建議**（`nextWeekAdjustments.items`，打勾套用），**沒有自由文字入口**。全 repo 無 `user_nl_edit`。

### 後端現況（已現查驗證，非背 task）
延後客製化鏈五環節已接通 + 有測試 + 已部署：
1. `POST /v2/agent/chat`（`scenario="weekly_situation"`）+ plan-change 意圖 → `orchestrator_service._chat_v2`（`domains/agents/orchestrator_service.py:267-341`）呼叫 `deferred_review_edit_service.store_user_nl()`。
2. 寫入 Firestore `users/{uid}/weekly_summaries_v2/{overview_id}_{week}_summary` 的 `next_week_adjustments.user_nl_edit`（值）+ `user_nl_edit_status="pending"`。
3. 即時回覆 i18n `rizo.deferred.stored`：「好，我先幫你記下來了 🙌 下週課表生成時會自動套用這個調整。」
4. 下週課表生成（`plan_architect_agent.generate(persist=True)`，`plan_architect_agent.py:149-228` `_apply_deferred_review_edit`）→ 讀 summary(W-1) 的 pending NL → 跑確定性 `plan_editor_service.edit_plan` → 成功 overwrite + `status="applied"`；失敗（hard_unsafe/block）→ 留乾淨 baseline + `status="failed"` + FCM data 通知 `type="deferred_edit_failed"`。
5. 整個 hook try/except 包裹，**永不中斷生成**。

**結論**：iOS 端為主（送自由文字 → 顯示確認 → 顯示狀態）。後端 **deferred 鏈核心架構零改動**，僅小範圍補洞（i18n / 輸入驗證 / `deferred_stored` 回饋旗標 / 優先序測試，見 §2）。

### 成功標準
- 用戶能在 iOS 週回顧打一段自由的話、送出，看到 Rizo 暖場確認 + 「已記下，下週套用」狀態。
- 下週課表生成後，重看該週回顧能看到 applied / failed 狀態；failed 時收到 FCM 並被引導重講。
- 不誤導：UI 清楚表達這是**延後**（下週才套用），不是即時改當前課表。

---

## 2. 範圍

### In scope（iOS）
- `WeeklySummaryV2View` 的「下週調整建議」section 內，結構化 items **下方**新增自由文字子區塊（Approach A）。
- 送出走**既有 Rizo 路徑** `POST /v2/agent/chat`（`scenario="weekly_situation"`）。
- DTO/Entity/Mapper 加 `user_nl_edit` / `user_nl_edit_status` 欄位，用於顯示狀態。
- 狀態顯示：none → pending → applied / failed。
- FCM `deferred_edit_failed` 接收 → 引導用戶重講（輕量：local notification 呈現 + 點擊回週回顧）。

### In scope（後端，小範圍）
- `deferred_edit_failed` 失敗通知文案目前**寫死中文**（`plan_architect_agent.py:179-189`）→ 補 `rizo.deferred.edit_failed` i18n（zh-TW / ja-JP / en-US），改走 `i18n_service`。
- **輸入驗證**：`deferred_review_edit_service.store_user_nl` 加 trim + 非空 + 長度上限（2000 字）防呆（紅隊 #6）。
- **意圖未判定為 plan-change 的回饋**（紅隊 #2）：`scenario="weekly_situation"` 但意圖被判成閒聊/澄清（非 P_PROPOSE）→ 目前**不存** `user_nl_edit`，iOS 卻無從得知。最小修：`/v2/agent/chat` 回應在 weekly_situation 場景帶一個布林 `deferred_stored`（true=已記下/false=沒記成課表調整），iOS 據此給正確回饋（不假裝已記下）。
- **（選/backlog）applied 正向回饋**：目前只有 failed 發 FCM；applied 無任何推播 → 用戶不知有沒有套用（紅隊 #5）。可加 `deferred_edit_applied` FCM 或下週課表頂部 banner。列 backlog，非 Track 1 阻擋。

### Out of scope（明確不做）
- **Track 2**（強化回顧洞察：補週對週趨勢、修 0.0 假數據、教練視角總結、凸顯行動訊號）— 另一 spec。
- 自由文字 → Rizo 即時解析成可勾 item（Approach C）— 後端 deferred 路徑不做此解析，違反「後端零改動」。
- 即時改當前週課表（那是今日卡片 / Siri 的範疇，T-0028）。
- Android（本 task 限 iOS）。

---

## 3. 架構與資料流（已核可）

```
WeeklySummaryV2View
  （下週調整 section 內，結構化 items 下方的自由文字子區塊）
        │ 打字 + 送出
        ▼
WeeklySummaryCoordinator
   ├─(送出) RizoRepository.sendMessage(scenario:"weekly_situation", text:…)   ← 既有路徑
   │          → POST /v2/agent/chat
   │          → 回應 .response = Rizo 暖場確認句（顯示）
   │          → 後端把 text 存進 summary.next_week_adjustments.user_nl_edit (pending)
   │
   └─(狀態) TrainingPlanV2Repository.getWeeklySummary()                        ← 既有路徑
              → DTO 新增 user_nl_edit / user_nl_edit_status → 顯示狀態
```

**分層原則**（照 iOS 既有架構，依賴向內）：
- **送出**複用 `RizoRepository`（已會打 `/v2/agent/chat`，今日卡片在用）— **不**在 `TrainingPlanV2` 重複 endpoint。
- **狀態**走 `TrainingPlanV2Repository`（週回顧本來就它在抓）。
- `WeeklySummaryCoordinator` 同時依賴這兩個 **protocol**（各司其職：一個送、一個讀狀態），不依賴 Impl。

**套用時機（延後，非即時·已現查）**：下週課表生成是**用戶觸發**（按「產生下週課表」→ `POST` 走 `plan_architect_agent.generate`，`api/v2/training_plan.py:306`）——**沒有**背景自動排程偷生成。所以流程是：自由文字記下（pending）→ 用戶按「產生下週課表」→ 後端 hook 讀 `user_nl_edit` 確定性套用 → applied；失敗 → status=failed + FCM。**UI 文案不可承諾具體時刻**（如「週日自動」是錯的），要講「下次你產生下週課表時套用」。

**結構化 items 與自由文字的優先序（已現查·紅隊 #4 降級結論）**：兩者都改下週，但**有明確順序、不是腐爛衝突**——生成時先用 `methodology_customization`（結構化 items 經 `/apply-items` 寫入）塑形 baseline，**之後** `_apply_deferred_review_edit` 才用自由文字 NL 跑 `edit_plan`（`plan_architect_agent.generate` 內 baseline persist 之後才呼叫）。即 **items 先塑形 → 自由文字最後套用 → 自由文字蓋過 items**。這是合理優先序（「你親口說的」最終生效），spec 必須明講此語意，並補一條整合測試證明「NL 蓋過 items」（§7）。**非 P0 redesign。**

---

## 4. 元件設計

### 4.1 DTO（`Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift`）
`NextWeekAdjustmentsV2DTO`（~line 462）新增 3 欄（snake_case + CodingKeys，optional 容錯舊資料）：
```swift
let userNlEdit: String?            // CodingKey "user_nl_edit"
let userNlEditStatus: String?      // CodingKey "user_nl_edit_status"  // "pending"|"applied"|"failed"
let userNlEditFailReason: String?  // CodingKey "user_nl_edit_fail_reason"（failed 時顯示，optional）
```

### 4.2 Entity（`Domain/Entities/WeeklySummaryV2.swift`）
對應 `NextWeekAdjustmentsV2` 加 camelCase 欄位 + 一個封閉狀態列舉：
```swift
enum UserNlEditStatus { case none, pending, applied, failed }
// 對應欄位：userNlEdit: String?, userNlEditStatus: UserNlEditStatus, userNlEditFailReason: String?
```
**注意（紅隊 #3·既有技術債）**：`WeeklySummaryV2` Entity **現況已是 `Codable`**（`WeeklySummaryV2.swift:7`），與 CLAUDE.md「Domain Entity 不加 Codable」相左。本 task **沿用現狀**（不在此 task 順手重構，避免擴大範圍），新增欄位照既有 Codable 模式；該技術債另記，不在 Track 1 處理。

### 4.3 Mapper（`Data/Mappers/WeeklySummaryV2Mapper.swift`）
DTO → Entity：`user_nl_edit_status` 字串映射到 `UserNlEditStatus`，**未知/缺值 fallback `.none`**（不可崩、不可誤判 applied）。

### 4.4 Coordinator（`Presentation/ViewModels/WeeklySummaryCoordinator.swift`）
新增 state + 行為（@MainActor，沿用既有 `applySelectedAdjustments` 範式）：
```swift
var userNlDraft: String = ""
var userNlSubmitState: ViewState<String> = .idle   // 送出中/成功（帶 Rizo 確認句）/錯誤
// 顯示狀態取自 summary entity 的 userNlEditStatus（已套用/沒套用）

func submitUserNlEdit() async   // 呼叫 rizoRepository.sendMessage(scenario:"weekly_situation", userNlDraft)
                                // 成功且後端 deferred_stored=true：userNlSubmitState=.loaded(確認句)、清 draft
                                // 成功但 deferred_stored=false（意圖沒判成 plan-change）：.loaded(回應) 但標「沒記成調整」
                                // 失敗：.error(DomainError)
```
- **依賴注入（紅隊 #1·阻擋修正）**：`WeeklySummaryCoordinator` 現有建構子已 13 參數 + closure 注入，**不可**再加第 14 個建構參數（會被迫改所有建構點、難編譯）。改用既有慣例：在 Coordinator 內 `lazy` 從 `DependencyContainer.resolve()` 取 `RizoRepository`（protocol），或沿用該檔現行的 closure 注入方式。**不走建構子加參數。**
- `NSURLErrorCancelled` 過濾後才動 UI state（iOS 鐵律）。
- 所有 async closure `[weak self]`；TaskManageable / cancelAllTasks。

### 4.5 View（`Presentation/Views/WeeklySummaryV2View.swift`，`AdjustmentsSectionV2` ~line 150-170 下方）
自由文字子區塊（複用 Rizo 輸入框樣式，但**單次送出非滾動對話**）：
```
┌ 想自己跟 Rizo 說？ ───────────────────────┐
│ [TextField: 例「下週五六爬山不能跑，想多休息」]  │
│ 小字：送出會覆蓋你上次記下的調整 · 最多 2000 字   │ ← 紅隊 #3 覆寫提示 + #6 上限
│                                    [送出]    │
│ ── 送出後 ──                                  │
│ 🤖 好，我先幫你記下來了 🙌 下次你產生下週課表時會套用。│ ← API .response（不承諾具體時刻）
│ 狀態：● 已記下，下次生成套用  （pending）         │
│      ✅ 已套用到下週課表      （applied）         │
│      ⚠️ 沒能套用，點我再說一次（failed → 引導重講）  │
│      ℹ️ 我聽到了，但沒記成課表調整，要更明確說一次嗎？│ ← 紅隊 #2：deferred_stored=false
└───────────────────────────────────────────┘
```
- View 純渲染、零業務邏輯；狀態由 Coordinator/Entity 決定。
- 與上方結構化 items **互補且有優先序**：items=Rizo 主動建議勾選（先塑形）；自由文字=用戶自己的話（最後套用、蓋過 items，見 §3）。
- 輸入框 `maxLength` 2000、空字串 disable 送出鈕。

### 4.6 FCM 失敗接收（既有通知管線）
`deferred_edit_failed` data notification → app 既有 FCM handler 認 `type` → 呈現 local notification「沒能套用你上週的調整，打開 Rizo 再說一次」→ 點擊深連回該週回顧。（若 app 既有 data-notification 路由不支援深連，降級為純提示，深連列 stretch。）

---

## 5. 狀態機（`user_nl_edit_status`）

```
none ──(用戶送出 NL)──▶ pending ──(下週生成·套用成功)──▶ applied
                           └────────(下週生成·套用失敗)──▶ failed ──(FCM 通知 + 用戶重講)──▶ pending
```
- **pending**：送出後立即（樂觀），也由後端寫入確認。
- **applied / failed**：在**下週生成時**由後端寫到 summary(W-1)。用戶當下看到 pending；之後重開該週回顧才見 applied/failed。FCM 是 failed 的主動通知。
- 重送（用戶再打一次）→ 覆寫 `user_nl_edit` + 回 pending（後端 `store_user_nl` merge 覆寫）。

---

## 6. 錯誤處理

| 情況 | 處理 |
|---|---|
| 送出網路錯誤 | `userNlSubmitState=.error(DomainError)`；可重試；不污染既有 summary 顯示 |
| `NSURLErrorCancelled`（離開畫面） | 過濾，不顯示 ErrorView（iOS 鐵律） |
| 後端回非 plan-change 意圖（被當聊天，紅隊 #2） | 後端不存 user_nl_edit；回應帶 `deferred_stored=false` → iOS 顯示「我聽到了，但沒記成課表調整，要更明確說一次嗎？」（**不假裝已記下**）。不靠 iOS 猜後端意圖判定 |
| 空 / 超長輸入（紅隊 #6） | iOS：空字串 disable 送出、`maxLength` 2000；後端 `store_user_nl` 再 trim + 非空 + ≤2000 防呆（雙層） |
| 多次送出覆寫（紅隊 #3） | 後端 `store_user_nl` 是覆寫（非 append）→ iOS 輸入框下小字提示「送出會覆蓋上次記下的」。**接受覆寫語意**（不改後端為 append，避免擴大範圍） |
| 套用失敗（failed） | UI 顯示「沒能套用，點我再說一次」+ FCM 主動通知；點擊回週回顧重打 |
| 套用成功（applied）無回饋（紅隊 #5） | Track 1 內：重開該週回顧可見 applied。主動 applied 推播（FCM/banner）列 backlog |
| 舊資料無這些欄位 | DTO optional + Mapper fallback `.none`，不崩 |
| 後端 i18n 文案 | 補 `rizo.deferred.edit_failed` + `edit_applied`（3 語），移除寫死中文 |

---

## 7. 測試

- **單元（ViewModel）**：`WeeklySummaryCoordinator.submitUserNlEdit` 成功 → `.loaded(確認句)` + draft 清空；失敗 → `.error`；cancelled → 不改 state。注入 fake `RizoRepository`。
- **單元（Mapper）**：`user_nl_edit_status` 各值 + 未知 + 缺值 → 正確 `UserNlEditStatus`（未知/缺→`.none`）。
- **Maestro flow**（`.maestro/flows/`）：進週回顧 → 打自由文字 → 送出 → 斷言 Rizo 確認句 + pending 狀態可見。（applied/failed 需跨週生成，列手動/後續。）
- **後端·優先序整合測試（紅隊 #4，必補）**：結構化 item 勾「週三→長跑」+ 自由文字 NL「取消週三強度」→ 生成下週 → 斷言**最終課表反映 NL（週三非強度）**，證明「NL 最後套用、蓋過 items」的優先序成立、兩路不會腐爛衝突。
- **後端·輸入驗證**：`store_user_nl` 空字串/超長 → 拒收（ValueError），不寫髒資料。
- **後端**：`rizo.deferred.edit_failed` + `edit_applied` 三語 key 存在（locales 測試）。既有 deferred e2e（`tests/agent/test_deferred_weekly_review_e2e.py`）不退步。
- 交付前 clean build（iPhone 17 Pro）。

---

## 8. 風險 / 未決

- **狀態可見性時機**（紅隊 #5）：applied/failed 在下週生成時才寫回上週 summary；用戶不重開上週回顧就只在 FCM（failed）看到，applied 無主動回饋。可接受（pending 當下可見、failed 有 FCM）；applied 主動推播列 backlog。
- **FCM 深連**：iOS 已有 FCM handler 認 `type`（`AppDelegate.swift:105`，有 `workout_processed` 先例），加 `deferred_edit_failed` 分支可行；但深連回特定週回顧需 UNUserNotificationCenter delegate 層，**先降級純提示，深連列 stretch**。
- **互補 vs 混淆**：結構化 items + 自由文字兩入口並存，靠文案分流 +（§3 已現查）明確優先序「NL 蓋過 items」。上線後看用戶是否混淆，必要時 Track 2 再整合。
- **已解（紅隊 P0 #4 降級）**：兩路非腐爛衝突，是「items 塑形 → NL 最後蓋過」的明定順序（§3 現查），補整合測試（§7）即可。

---

## 9. 著手檔案清單（iOS）

| 層 | 檔案 | 改動 |
|---|---|---|
| DTO | `Data/DTOs/WeeklySummaryV2DTO.swift` | +3 欄 + CodingKeys |
| Entity | `Domain/Entities/WeeklySummaryV2.swift` | +欄位 + `UserNlEditStatus` enum |
| Mapper | `Data/Mappers/WeeklySummaryV2Mapper.swift` | status 字串→enum，fallback `.none` |
| ViewModel | `Presentation/ViewModels/WeeklySummaryCoordinator.swift` | +state +`submitUserNlEdit` + **lazy 解析** `RizoRepository`（非建構參數，紅隊 #1） |
| View | `Presentation/Views/WeeklySummaryV2View.swift` | +自由文字子區塊（含覆寫提示 + maxLength + 4 種狀態 + 非 plan-change 提示） |
| 後端 i18n | `plan_architect_agent.py` + `locales/*` | `deferred_edit_failed` + `edit_applied` i18n（3 語） |
| 後端驗證 | `deferred_review_edit_service.py` | `store_user_nl` trim/非空/≤2000（紅隊 #6） |
| 後端意圖回饋 | `orchestrator_service._chat_v2`（weekly_situation 段） | 回應帶 `deferred_stored` 布林（紅隊 #2） |
| 後端測試 | `tests/agent/` | NL 蓋過 items 優先序整合測試（紅隊 #4） |

---

## 10. 紅隊審核軌跡（2026-06-23·兩個對抗式 subagent）

派兩個紅旗 subagent 對抗審核（一查 iOS code 假設、一挑設計/UX/edge）。逐項處置（**接受 / 降級並反駁 / backlog**）：

| 紅隊發現 | 嚴重度(紅隊) | 我的處置 | 依據 |
|---|---|---|---|
| #1 Coordinator DI 不可加第 14 建構參數 | 🔴 阻擋 | **接受** → 改 lazy 解析（§4.4/§9） | 現查建構子已 13 參數+closure |
| #2 意圖判閒聊時不存 NL、iOS 無從得知 | 高 | **接受** → 後端回 `deferred_stored` 旗標、iOS 給「沒記成調整」回饋（§4.5/§6） | 真失敗模式 |
| #4 結構化 items × 自由文字「雙路衝突」 | 🔴 極高/P0 | **降級反駁** → 現查為**明定優先序**（items 塑形→NL 最後蓋過），非腐爛衝突；補整合測試即可（§3/§7/§8） | `plan_architect_agent.generate` 順序：baseline 後才 `_apply_deferred_review_edit` |
| #1(時機) 下週生成何時觸發、是否誤導 | 高 | **接受** → 現查為**用戶觸發**（按產生下週課表，無自動排程）；UI 文案不承諾具體時刻（§3/§4.5） | `api/v2/training_plan.py:306` |
| #3 多次送出覆寫、用戶不知 | 中 | **接受（提示）** → 輸入框小字「送出會覆蓋上次」；不改後端為 append（避免擴大範圍）（§4.5/§6） | `store_user_nl` merge 覆寫 |
| #6 空/超長/濫用輸入無防禦 | 中 | **接受** → iOS maxLength+disable、後端 trim/非空/≤2000 雙層（§2/§6/§7） | 無驗證層 |
| #5 applied 無正向回饋 | 中 | **部分接受** → Track 1 內重開回顧可見；主動 applied 推播列 **backlog**（§2/§8） | 避免擴大 Track 1 |
| #3(Entity Codable) 違反架構規則 | 提醒 | **接受（記債）** → 沿用現狀不順手重構（§4.2） | `WeeklySummaryV2.swift:7` 已 Codable |
| #8 i18n 漏 applied 文案 | 低 | **接受** → 補 `edit_applied`（§2/§9） | — |
| FCM 深連 | 提醒 | **接受** → 確認 handler 認 type 可行，深連列 stretch（§8） | `AppDelegate.swift:105` |
| Rizo 路徑是否綁 session（我自己的疑慮） | — | **解除** → 紅隊查證 RizoRepository protocol 不綁 session，可單次送（§3 安全） | RT1 查證 |

**淨結論**：紅隊抓到 1 個真阻擋（DI）+ 數個真 edge case，全納入；對唯一的 P0（雙路衝突）我現查反駁為「明定優先序」、降級為補測試。Spec 已據此修訂。
