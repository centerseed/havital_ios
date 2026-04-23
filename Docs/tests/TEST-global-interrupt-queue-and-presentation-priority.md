---
type: TEST
id: TEST-global-interrupt-queue-and-presentation-priority
status: Draft
spec: SPEC-global-interrupt-queue-and-presentation-priority.md
created: 2026-04-23
updated: 2026-04-23
---

# Test Plan: 全域 Interrupt Queue 與主動介入畫面優先級

## 目標

驗證 iOS app root 的 global interrupt queue 已正確接管 `announcement`、`data-source reminder`、`paywall` 三條 production presenter，且優先級、pending、cooldown 行為符合 spec。

## P0 場景（必過）

### TC-INT-P0-01: 同時有 announcement 與 data-source reminder 時，只先顯示 announcement

- AC 對應：`AC-INT-03`、`AC-INT-05`、`AC-INT-07`、`AC-INT-08`
- 前置條件：
  - 使用者已登入且完成 onboarding
  - `data_source = unbound`
  - app 有至少一則未讀公告
- 步驟：
  1. 進入主 app
  2. 讓 announcement 與 data-source reminder 同時達到可顯示條件
  3. 觀察第一個出現的 interrupt
- 預期：
  - 只先顯示 announcement
  - `Data Source Required` 當下不得同時出現
  - 關閉 announcement 後，自動補出 `Data Source Required`

### TC-INT-P0-02: 被 announcement 擋住的 data-source reminder 不得偷吃 cadence

- AC 對應：`AC-INT-05`、`AC-INT-06`、`AC-INT-07`
- 前置條件：
  - 同 `TC-INT-P0-01`
- 步驟：
  1. 先讓 announcement 蓋住 data-source reminder
  2. 尚未關閉 announcement 前，檢查 reminder state
  3. 關閉 announcement
  4. 讓 `Data Source Required` 出場後點 `Later`
- 預期：
  - reminder 在被 announcement 擋住時只能是 pending
  - cooldown 不能在 pending 階段開始計算
  - 只有使用者真的點 `Later` 或關閉 reminder 後，冷卻才開始

### TC-INT-P0-03: paywall request 必須透過 global interrupt host，而不是 feature local sheet

- AC 對應：`AC-INT-01`、`AC-INT-09`、`AC-INT-10`
- 前置條件：
  - 使用者位於 `TrainingPlanV2View` 或 `UserProfileView`
  - 存在可觸發 paywall 的路徑
- 步驟：
  1. 在 `TrainingPlanV2View` 觸發 paywall
  2. 在 `UserProfileView` 觸發 paywall
  3. 檢查當下 active interrupt
- 預期：
  - paywall 經由同一個 global interrupt host 出場
  - 同一時刻只有一個 active interrupt
  - 不能再看到 feature local presenter 與 global presenter 同時存在

### TC-INT-P0-04: root host 必須是唯一 production interrupt presenter

- AC 對應：`AC-INT-01`、`AC-INT-10`
- 前置條件：
  - app 正常啟動進主畫面
- 步驟：
  1. 依序觸發 announcement、data-source reminder、paywall
  2. 觀察畫面 presenter 行為
- 預期：
  - `ContentView` root host 是唯一全域 interrupt presenter
  - 不應再有 `TrainingPlanV2View` / `UserProfileView` 自己直接 hold production paywall / announcement popup presenter

## P1 場景（應過）

### TC-INT-P1-01: 同優先級 interrupt 依 FIFO 出場

- AC 對應：`AC-INT-04`
- 步驟：
  1. 建立兩個相同優先級 interrupt request
  2. 觀察出場順序
- 預期：
  - 先 enqueue 的先出

### TC-INT-P1-02: feature-local edit / picker sheet 不得被收進 queue

- AC 對應：`AC-INT-12`
- 步驟：
  1. 打開任一編輯課表 / picker / feedback 類型的 local sheet
  2. 驗證 global interrupt state
- 預期：
  - local sheet 不進 global queue
  - queue 不會把這些 local sheet 誤判成 current interrupt

## 驗收證據

QA 至少必須提供：

1. `GlobalInterruptQueueACTests.swift` 的 AC 對照 verdict
2. 至少一條能證明 `announcement -> data-source reminder` 依序出場的實測證據
3. 至少一條能證明 paywall 不再走 feature local presenter 的實測證據

## 明確不包含

- 不在這份 TEST 裡驗 visual polish 或動畫細節
- 不在這份 TEST 裡驗 force update / login / onboarding route-level blocker
