---
type: TD
id: TD-global-interrupt-queue-and-presentation-priority
status: Draft
spec: SPEC-global-interrupt-queue-and-presentation-priority.md
created: 2026-04-23
updated: 2026-04-23
---

# 技術設計：全域 Interrupt Queue 與主動介入畫面優先級

## 調查報告

### 已讀文件（附具體發現）

- `apps/ios/Havital/Docs/specs/SPEC-global-interrupt-queue-and-presentation-priority.md` — 發現：已明確定義 `AC-INT-01 ~ AC-INT-12`，可直接進 executable TD；優先級已定死為 `session/auth > paywall > announcement > data source reminder > other nudge`。
- `apps/ios/Havital/Docs/specs/SPEC-app-shell-routing-and-global-guardrails.md` — 發現：`ContentView` 已被定義為 app shell 與全域 guardrail 的主要宿主；route-level blocker 與主 app guardrail 已是既有概念。
- `apps/ios/Havital/Docs/specs/SPEC-onboarding-delayed-data-source-binding.md` — 發現：`data_source = unbound` 後的主提醒目前產品規格已要求沿用 `ContentView` 路徑，且頻率固定為每 3 天最多一次。
- `apps/ios/Havital/Docs/specs/SPEC-subscription-management-and-status-ui.md` — 發現：expired / trial reminder 與 paywall 已是正式產品面的一部分，未來必然屬於 interrupt queue 範圍，不是單純某個 feature 的 local sheet。
- `apps/ios/Havital/Docs/specs/SPEC-profile-and-data-integration-management.md` — 發現：`UserProfileView` 是資料來源管理與 paywall 入口之一，但它本身是 settings surface，不應被誤收成 queue host。
- `apps/ios/Havital/Docs/designs/TD-version-gate-announcements.md` — 發現：公告系統是以 `AnnouncementViewModel` 管 message center + popup queue，且本來就和 app shell / version gate 同一脈絡。
- `apps/ios/Havital/Havital/Features/Announcement/Presentation/ViewModels/AnnouncementViewModel.swift` — 發現：目前公告已有自己的 `popupQueue`、`currentPopup`、`presentNextPopup()`，並透過 `Notification.Name.announcementPopupDidPresent / announcementPopupQueueDidDrain` 跟其他提醒做脆弱協調。
- `apps/ios/Havital/Havital/Core/Presentation/ViewModels/AppViewModel.swift` — 發現：`showDataSourceNotBoundAlert`、`isAnnouncementPopupVisible`、`hasPendingDataSourceNotBoundAlert` 現在都塞在 `AppViewModel`，代表資料來源提醒已經在和公告做 ad hoc queue，但不是通用機制。
- `apps/ios/Havital/Havital/Views/ContentView.swift` — 發現：`ContentView` 目前直接掛 `DataSourceBindingReminderOverlay` 與 `UserProfileView` sheet，是 data-source reminder 的真正 presenter host。
- `apps/ios/Havital/Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift` — 發現：同一個 view 同時持有 `paywallTrigger` 的 `.sheet(item:)` 與 `announcementViewModel.currentPopup` 的 `.sheet(item:)`；這就是目前 presenter ownership 分裂的熱點。
- `apps/ios/Havital/Havital/Features/Subscription/Domain/Managers/SubscriptionReminderManager.swift` — 發現：trial / expired reminder 已有 `pendingReminder`、session gate、UserDefaults gate，這是 queue policy 可以沿用的現成模式。
- `apps/ios/Havital/Havital/Views/UserProfileView.swift` — 發現：profile 自己也能 `.sheet(item: $paywallTrigger)`，證明 paywall 現在不是單一 presenter，而是多 feature 各自持有。
- `apps/ios/Havital/Havital/Extensions/Notification+Extension.swift` — 發現：目前只有 announcement 相關的 queue notification，沒有通用 interrupt 事件。
- `apps/ios/Havital/Havital/Views/Components/DataSourceBindingReminderOverlay.swift` — 發現：資料來源提醒已經不是原生 `.alert`，而是自家 overlay；所以問題不是 SwiftUI `.alert` 類型，而是 presenter owner 分裂。

### 搜尋但未找到

- `Docs/specs/SPEC-*interrupt*` → 無既有 interrupt queue spec，本次屬新增規格。
- `Docs/designs/TD-*interrupt*` → 無既有 TD。
- `Havital/` 中搜尋 `InterruptCoordinator` → 無結果。
- `Havital/` 中搜尋 `GlobalModalCoordinator` / `PresentationCoordinator` → 無結果。
- `Havital/` 中搜尋單一全域 paywall host → 無結果；現況是多 feature 自己 `.sheet(item:)`。

### 我不確定的事（明確標記）

- subscription reminder 與 paywall 最終是否要用「一個 interrupt item 內含 CTA -> paywall」還是兩個分離 item → `[未確認]`，本 TD 先保留為同優先級群組，不先硬綁成單一路徑。
- 除 `TrainingPlanV2View`、`UserProfileView` 外，是否還有其他 production surface 自行持有 paywall sheet → `[未完全盤點]`，目前已確認至少這兩個。

### 結論

可以開始設計。現況真正缺的是「單一 interrupt owner + 單一 current item + 單一 queue policy」，不是再修 announcement 和 reminder 之間的例外判斷。

## 文件可執行性判定

- `SPEC-global-interrupt-queue-and-presentation-priority.md` 已有穩定 AC IDs，可作為 executable spec。
- 本 TD 會補 `Spec Compliance Matrix` 與 `Done Criteria`，可作為 Developer handoff。
- `ADR` 目前不是必需；現階段先用 TD 收斂即可。

## Spec 衝突檢查

- 與 `SPEC-app-shell-routing-and-global-guardrails.md`：無衝突；本 TD 只是把全域 guardrail 的 presenter 規則做成單一 queue。
- 與 `SPEC-onboarding-delayed-data-source-binding.md`：無衝突；`Data Source Required` 仍保留產品語意，只是改走統一 queue。
- 與 `SPEC-subscription-management-and-status-ui.md`：無衝突；paywall / subscription reminder 只是改 presenter ownership，不改產品矩陣。

結論：Spec 衝突檢查：無衝突。

## AC Compliance Matrix

| AC ID | AC 描述 | 實作位置 | Test Function | 狀態 |
|-------|---------|---------|---------------|------|
| AC-INT-01 | 所有主動介入畫面走 app root 單一 queue | `Havital/Core/Presentation/Interrupts/InterruptCoordinator.swift` + `Havital/Views/ContentView.swift` | `test_ac_int_01_all_global_interrupts_go_through_root_queue` | STUB |
| AC-INT-02 | 區分 route-level blocker 與 in-app interrupt | `Havital/Views/ContentView.swift` + `Havital/Core/Presentation/Interrupts/InterruptRoutePolicy.swift` | `test_ac_int_02_route_level_blockers_do_not_enter_interrupt_queue` | STUB |
| AC-INT-03 | 使用固定優先級，不由各 feature 搶 presenter | `Havital/Core/Presentation/Interrupts/InterruptItem.swift` + `InterruptCoordinator.swift` | `test_ac_int_03_priority_order_is_fixed` | STUB |
| AC-INT-04 | 同優先級 FIFO，跨優先級高者先出 | `InterruptCoordinator.swift` | `test_ac_int_04_same_priority_is_fifo` | STUB |
| AC-INT-05 | 被高優先級擋住的項目保留 pending，前一個關閉後自動補出 | `InterruptCoordinator.swift` | `test_ac_int_05_pending_interrupt_reappears_after_higher_priority_drains` | STUB |
| AC-INT-06 | cooldown 只在使用者真的消費後才開始計算 | `InterruptCoordinator.swift` + existing reminder managers | `test_ac_int_06_cooldown_starts_only_after_user_consumes_interrupt` | STUB |
| AC-INT-07 | data source reminder 收斂進全域 queue | `AppViewModel.swift` + `ContentView.swift` + `InterruptCoordinator.swift` | `test_ac_int_07_data_source_reminder_enqueues_instead_of_direct_present` | STUB |
| AC-INT-08 | announcement popup 收斂進全域 queue | `AnnouncementViewModel.swift` + `TrainingPlanV2View.swift` + `InterruptCoordinator.swift` | `test_ac_int_08_announcement_popup_uses_global_queue_host` | STUB |
| AC-INT-09 | paywall 視為全域 interrupt 類型之一 | `TrainingPlanV2ViewModel.swift` + `UserProfileView.swift` + `InterruptCoordinator.swift` | `test_ac_int_09_paywall_requests_use_global_interrupt_queue` | STUB |
| AC-INT-10 | 對外暴露單一 current interrupt state | `InterruptCoordinator.swift` | `test_ac_int_10_only_one_current_interrupt_is_visible_at_a_time` | STUB |
| AC-INT-11 | 支援 type-based display policy | `InterruptPolicy.swift` + existing reminder managers | `test_ac_int_11_interrupt_type_declares_display_policy` | STUB |
| AC-INT-12 | 不把 feature-specific sheet 誤收進 queue | `InterruptCoordinator.swift` + feature call sites | `test_ac_int_12_feature_specific_sheets_do_not_enter_global_interrupt_queue` | STUB |

## Component 架構

### 1. 新增 InterruptCoordinator 作為唯一 owner

新增：

- `Havital/Core/Presentation/Interrupts/InterruptCoordinator.swift`
- `Havital/Core/Presentation/Interrupts/InterruptItem.swift`
- `Havital/Core/Presentation/Interrupts/InterruptPolicy.swift`
- `Havital/Core/Presentation/Interrupts/InterruptHostView.swift`

責任切分：

- `InterruptItem`：定義 interrupt type、payload、priority、display policy、stable id
- `InterruptCoordinator`：唯一 queue owner；負責 enqueue / dequeue / current item / pending item / consume / dismiss
- `InterruptHostView`：唯一 presenter host；根據 `currentItem` 決定掛哪個 view
- 既有 feature/view model：只能 submit request，不再直接 present

### 2. Interrupt type 分群

本期先收以下 production 類型：

- `.sessionBlocking`
- `.paywall(trigger: PaywallTrigger)`
- `.announcement(Announcement)`
- `.dataSourceBindingReminder`
- `.subscriptionReminder(SubscriptionReminder)`

不收：

- picker / edit sheet / share sheet / feedback sheet
- system permission dialog
- onboarding 內部局部 alert

### 3. Presenter host 掛點

`InterruptHostView` 掛在 `ContentView.mainAppContent()` 同層，作為 root overlay/sheet host。

決策：

- 只保留一個全域 interrupt presenter
- feature subtree 不再直接持有 paywall / announcement popup 的最終 `.sheet`
- `TrainingPlanV2View` 與 `UserProfileView` 改成 submit request 給 coordinator

### 4. Policy 與 ReminderManager 的邊界

不要把所有頻率規則都重寫進 queue。

採分層：

- queue 決定「誰先出、是否 pending、何時 current」
- reminder manager 決定「該 type 現在有沒有資格 enqueue」

例如：

- `DataSourceBindingReminderManager` 決定 3 天 cadence
- `SubscriptionReminderManager` 決定 trial/expired cadence
- `InterruptCoordinator` 只保證：符合資格才 enqueue；被高優先級擋住不算消費；dismiss 後才呼叫 manager consume

## 介面合約清單

| 函式/API | 參數 | 型別 | 必填 | 說明 |
|----------|------|------|------|------|
| `InterruptCoordinator.enqueue(_:)` | `item` | `InterruptItem` | 是 | 提交新的 interrupt request；若已存在同 stable id 項目需去重 |
| `InterruptCoordinator.dismissCurrent(reason:)` | `reason` | `InterruptDismissReason` | 是 | 關閉目前 interrupt，並依 policy 決定是否記錄 consume / cooldown |
| `InterruptCoordinator.currentItem` | - | `InterruptItem?` | - | 對外暴露目前唯一正在顯示的 interrupt |
| `InterruptCoordinator.hasPendingInterrupts` | - | `Bool` | - | 供 QA/debug 驗證 queue 狀態 |
| `AnnouncementViewModel.nextPopupInterrupt()` | - | `InterruptItem?` | 否 | 把現有公告 queue 轉成全域 interrupt item，不再自己持有最終 presenter |
| `AppViewModel.enqueueDataSourceBindingReminderIfNeeded()` | - | `Void` | 否 | 將 data source reminder 改成 enqueue path |
| `PaywallTriggering.requestPaywall(_:)` | `trigger` | `PaywallTrigger` | 是 | feature 不再自己 present，改提交 paywall interrupt |

## DB Schema 變更

無。

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| S01 | 建立 interrupt core types 與 root host | Developer | 新增 `InterruptCoordinator` / `InterruptItem` / `InterruptHostView`，並掛到 `ContentView` root |
| S02 | 遷移 data source reminder | Developer | `AppViewModel` 與 `ContentView` 不再直接以 local bool 作為 presenter source of truth，而是 enqueue `.dataSourceBindingReminder` |
| S03 | 遷移 announcement popup | Developer | `TrainingPlanV2View` 不再直接 `.sheet(item: $announcementViewModel.currentPopup)`；公告改透過 global queue 顯示 |
| S04 | 遷移 paywall trigger | Developer | `TrainingPlanV2View`、`UserProfileView` 至少這兩個 production hot path 不再直接 `.sheet(item: $paywallTrigger)`，改 submit paywall interrupt |
| S05 | 補 SpecCompliance / unit / Maestro 驗證 | QA | AC-INT-01~12 對應 stub 有明確 PASS/FAIL 歸屬；至少交叉驗 announcement + data source reminder + paywall 三方不互卡 |

## Done Criteria

1. `ContentView` 只有一個 production global interrupt host。
2. `AnnouncementViewModel` 不再直接擁有最終 popup presenter；公告 popup 透過 global queue 出場。
3. `AppViewModel.showDataSourceNotBoundAlert` 不再作為唯一 presenter source of truth；資料來源提醒改提交 interrupt item。
4. `TrainingPlanV2View` 與 `UserProfileView` 至少兩個 production paywall 熱點不再自己直接 `.sheet(item: $paywallTrigger)`。
5. announcement 與 data source reminder 同時存在時，只會先顯示 announcement；announcement 關閉後自動補出 data source reminder。
6. `DataSourceBindingReminderManager` 的 3 天 cadence 只有在使用者真的消費提醒後才開始計算。
7. 以下 AC test 必須從 FAIL 變 PASS：`AC-INT-01`、`AC-INT-03`、`AC-INT-05`、`AC-INT-07`、`AC-INT-08`、`AC-INT-09`、`AC-INT-10`。

## Risk Assessment

### 1. 不確定的技術點

- `[未確認]` SwiftUI 單一 host 若同時需要支援 overlay-style reminder 與 sheet-style paywall/announcement，最終是統一成單一 enum presenter，還是 host 內分派到 overlay / sheet 兩種容器，需在實作時證明不會重新引入競態。

### 2. 替代方案與選擇理由

- 替代方案 A：維持 announcement queue，僅針對 data source reminder / paywall 補更多 notification 協調。
  - 不選理由：只會把目前的例外判斷再擴大，長期一定再炸。
- 替代方案 B：每個 feature 保留本地 presenter，但用共用 `PresentationLock` 避免同時 present。
  - 不選理由：只能避免同時 present，無法解決 pending / cooldown / consume ownership。
- 選擇方案：建立單一 global interrupt queue。
  - 理由：只有這個方案能同時解掉 presenter ownership、priority、pending、cooldown consume 四件事。

### 3. 需要用戶確認的決策

- 無。priority 與 queue 原則已由 spec 定死，可直接往下實作。

### 4. 最壞情況與修正成本

- 最壞情況是第一版遷移只收 announcement + data source reminder + paywall，其他潛在 interrupt 尚未完全納入。
- 修正成本可控：root host 與 coordinator 一旦建立，後續只是把剩餘 interrupt 類型逐步遷入，不需要再重做架構。
