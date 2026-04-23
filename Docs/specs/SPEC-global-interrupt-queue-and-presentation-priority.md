---
type: SPEC
id: SPEC-global-interrupt-queue-and-presentation-priority
status: Draft
ontology_entity: app-shell-routing-guardrails
created: 2026-04-23
updated: 2026-04-23
---

# Feature Spec: 全域 Interrupt Queue 與主動介入畫面優先級

## 背景與動機

Paceriz iOS 目前已經有多種會主動打斷使用者的畫面，但它們不是走同一條流程：

1. `AnnouncementViewModel` 自己維護 `popupQueue`，並在 `TrainingPlanV2View` 直接用 `.sheet(item:)` 顯示公告 popup。
2. `ContentView` 直接掛 `DataSourceBindingReminderOverlay`，用 `AppViewModel.showDataSourceNotBoundAlert` 控制資料來源未綁定提醒。
3. paywall 目前仍由各 feature 自己持有 `paywallTrigger` 並各自 `.sheet(item:)` 顯示。
4. 其他全域 guardrail 如 force update、session / auth error、subscription reminder 也各自走不同 presenter 與 state。

這導致同一時間若有兩個以上主動介入事件發生，畫面會互相搶 presenter、搶顯示時機，最後變成：

- 有些畫面被遮住卻被當成已顯示
- 有些提醒被較高優先級畫面吃掉後不會補跳
- 同一個介面一半用 queue、一半用 overlay / alert / sheet，行為不可預測

這份 spec 的目標很單純：把所有「已進主 app 後，會主動跳出來打斷使用者」的畫面收斂成同一套 interrupt queue 規則。

## 目標用戶

1. 正在主 app 內使用課表、紀錄、表現資料等核心 flow 的使用者
2. 需要被系統主動提醒處理某件事，但不該同時看到多個 competing popup 的使用者
3. 需要讓 iOS 團隊後續新增提醒、公告、paywall、guardrail 時有單一接線方式的開發與 QA 團隊

## 相容性

- app shell 與全域 guardrail 邊界遵循 `SPEC-app-shell-routing-and-global-guardrails.md`
- onboarding 後未綁定提醒語意遵循 `SPEC-onboarding-delayed-data-source-binding.md`
- 訂閱提醒與 paywall 狀態語意遵循 `SPEC-subscription-management-and-status-ui.md`
- 公告 popup / 訊息中心脈絡與版本 gate 背景延續 `TD-version-gate-announcements.md`

## 定義

### 1. Interrupt

本 spec 的 `Interrupt` 指的是：

- 使用者已經進入主 app 上下文後
- 系統主動跳出來要求使用者注意、決策或處理
- 且它會搶佔目前畫面的注意力

典型例子包含：

- 公告 popup
- 資料來源未綁定提醒
- 訂閱到期 / 試用即將到期提醒
- paywall
- session 失效後需要重新登入的 blocking 提示

### 2. 不算 Interrupt 的東西

以下不在這個 queue 裡：

- app 入口 routing 本身，例如 loading / login / onboarding / force update full-screen route
- 某個功能頁自己的編輯 sheet、picker、share sheet、feedback sheet
- 原生系統權限 alert（HealthKit、Notification、Apple system dialog）

### 3. Queue Consumption

只有當 interrupt 真的被顯示給使用者，且使用者真的 dismiss / confirm / tap CTA，才算被消費。

被高優先級 interrupt 擋住而尚未顯示的項目，只能是 `pending`，不得視為已顯示。

## 需求

### AC-INT-01: 所有主動介入畫面必須透過 app root 的單一 queue 註冊與顯示

Given 使用者已進入主 app，  
When 系統需要顯示公告、資料來源提醒、訂閱提醒或 paywall 等主動介入畫面，  
Then 這些事件都必須先進入同一個 app root interrupt queue，由單一 presenter 顯示，而不是由各 feature 自己直接 `.sheet` / `.alert` / `.overlay`。

### AC-INT-02: Queue 必須明確區分 route-level blocker 與 in-app interrupt

Given 某個事件本質上屬於入口路由阻擋，例如 force update 或未登入，  
When app 正在決定入口 route，  
Then 該事件不得走 interrupt queue，而必須直接由 app shell route 接管。

Given 某個事件發生時使用者已在主 app 上下文，  
When 該事件需要主動介入，  
Then 它才應進 interrupt queue。

### AC-INT-03: Queue 必須有固定優先級，不能由各 feature 各自搶 presenter

Given 同一時間有多個 interrupt 同時準備顯示，  
When queue 決定出場順序，  
Then 必須依固定優先級只顯示一個，不得同時 present 多個 competing popup。

固定優先級如下：

1. session / auth blocking interrupt
2. paywall / subscription required interrupt
3. announcement popup
4. data source binding reminder
5. 其他非阻斷 nudge（例如 rating / growth 提示）

### AC-INT-04: 同優先級 interrupt 必須採 FIFO，跨優先級則由高優先級先出

Given queue 內有多個同類型且同優先級的 interrupt，  
When 輪到該優先級出場，  
Then 顯示順序必須遵守先進先出。

Given queue 內同時有高優先級與低優先級 interrupt，  
When queue 選下一個要顯示的項目，  
Then 必須先顯示高優先級項目。

### AC-INT-05: 被更高優先級 interrupt 擋住的項目必須保留為 pending，前一個關閉後自動補出

Given `announcement popup` 與 `data source reminder` 同時符合顯示條件，  
When queue 決定先顯示公告，  
Then `data source reminder` 必須保留在 queue 中為 pending，而不是被視為已顯示或直接丟失。

Given 較高優先級 interrupt 已被 dismiss，  
When queue 還有 pending interrupt，  
Then 系統必須自動補出下一個符合條件的 interrupt，不需要使用者手動切頁或重開 app。

### AC-INT-06: Cooldown 只能在使用者真的消費該 interrupt 後才開始計算

Given 某個 interrupt 有提醒頻率限制，  
When 它只是因為被更高優先級項目擋住而尚未實際顯示，  
Then 不得開始計算 cooldown。

Given 使用者真的看到 interrupt 並點擊 `Later`、關閉或完成 CTA，  
When 系統紀錄 reminder 狀態，  
Then 才能開始計算該 interrupt 的 cooldown。

### AC-INT-07: 資料來源未綁定提醒必須遵守 queue 規則，不得再自成一條 presenter 路徑

Given 使用者狀態為 `data_source = unbound`，  
When app 判斷需要顯示 `Data Source Required`，  
Then 該提醒必須先進 interrupt queue，而不是直接由 `ContentView` 或任一 feature 自己 present。

Given 同時存在公告 popup，  
When `Data Source Required` 尚未輪到出場，  
Then 不得被標記成已顯示，也不得吃掉 3 天 cadence。

### AC-INT-08: 公告 popup 必須從獨立 queue 收斂進全域 queue，不得再平行維護第二套 popup 流

Given 有多則未讀公告，  
When 系統建立公告 interrupt 項目，  
Then 公告可以保留自己的內容排序規則，但真正的顯示仍必須交由全域 interrupt queue 控制。

Given 公告 popup 關閉後 queue 仍有其他 pending interrupt，  
When 公告 queue 耗盡，  
Then 系統必須立刻回到全域 queue 選下一個 interrupt，而不是只發通知給某個特定 reminder 自己補救。

### AC-INT-09: Paywall 必須被視為全域 interrupt 類型之一，不得再由各 feature 自己直接開 sheet

Given 某個功能因訂閱狀態需要顯示 paywall，  
When feature 觸發 paywall，  
Then 它必須提交一個 paywall interrupt 給全域 queue，而不是在 local view 直接 `.sheet(item:)`。

Given queue 當下已有更高優先級 blocking interrupt，  
When feature 觸發 paywall，  
Then paywall 必須等待前一個 interrupt 完成後再顯示。

### AC-INT-10: Queue 必須提供單一「當前顯示中」狀態，QA 能用它驗證不會同時出兩個主動介入畫面

Given app 正在顯示某個 interrupt，  
When QA 或自動化需要判斷目前 active interrupt，  
Then 系統必須能對外暴露單一 current interrupt state，代表此刻只允許一個全域 interrupt 正在顯示。

### AC-INT-11: Queue 必須支援 session 級與 item 級的 display policy，但規則要由 interrupt type 宣告

Given 不同 interrupt 有不同顯示頻率需求，  
When queue 評估是否允許 enqueue 或 re-present，  
Then 規則應由 interrupt type 明確宣告，例如：

- announcement：每個 item 最多顯示一次，未讀則可排隊
- data source reminder：每 3 天最多一次，且使用者真的 dismiss 才開始 cooldown
- expired subscription reminder：同一 session 最多一次，但新 session 可再次顯示

### AC-INT-12: queue 不得把 feature-specific sheet / 編輯流程誤收進來

Given 使用者在某頁面打開編輯課表、分享卡、picker 或 feedback sheet，  
When 這些 sheet 是使用者主動觸發且屬於該功能上下文的一部分，  
Then 它們不得進 interrupt queue，也不得和全域 interrupt 搶同一套優先級規則。

## 明確不包含

- 不在本 spec 定義視覺樣式、動畫、陰影或元件外觀
- 不在本 spec 規定 SwiftUI 要用 `.sheet`、`.fullScreenCover`、`.overlay` 還是自訂 presenter；這是 TD 決策
- 不在本 spec 重新設計公告內容模型、paywall 方案內容或 reminder 文案
- 不在本 spec 處理原生系統 alert 的攔截與佇列化

## 技術約束（給 Architect 參考）

1. queue host 必須掛在 app root，與 `ContentView` / app shell 同層，而不是散在 feature subtree。
2. `AnnouncementViewModel` 現有 `popupQueue` 只能保留內容排序責任，不能再直接擁有最終 presenter。
3. `AppViewModel.showDataSourceNotBoundAlert` 應被收斂成 interrupt state，而不是繼續當全域 presenter source of truth。
4. `TrainingPlanV2View` 目前的 paywall / announcement `.sheet(item:)` 是後續必須收斂的主要熱點。
5. 測試必須至少覆蓋：
   - announcement 與 data source reminder 同時到達時只顯示 announcement
   - announcement 關閉後自動補出 data source reminder
   - data source reminder 按 `Later` 後 3 天內不再 enqueue
   - 綁定 Apple Health 後不再 enqueue `unbound` reminder

## 開放問題

1. subscription reminder 與 paywall 是否要拆成兩個 interrupt type，還是 reminder CTA 直接升級成 paywall flow，本 spec 先只定義它們屬於 paywall / subscription 優先級群組，不要求同一張卡完成。

## AC ID Index

| AC ID | 對應需求 |
|------|----------|
| AC-INT-01 | 所有主動介入畫面走 app root 單一 queue |
| AC-INT-02 | 區分 route-level blocker 與 in-app interrupt |
| AC-INT-03 | 使用固定優先級，不由各 feature 搶 presenter |
| AC-INT-04 | 同優先級 FIFO，跨優先級高者先出 |
| AC-INT-05 | 被高優先級擋住的項目保留 pending，前一個關閉後自動補出 |
| AC-INT-06 | cooldown 只在使用者真的消費後才開始計算 |
| AC-INT-07 | data source reminder 收斂進全域 queue |
| AC-INT-08 | announcement popup 收斂進全域 queue |
| AC-INT-09 | paywall 視為全域 interrupt 類型之一 |
| AC-INT-10 | 對外暴露單一 current interrupt state |
| AC-INT-11 | 支援 type-based display policy |
| AC-INT-12 | 不把 feature-specific sheet 誤收進 queue |
