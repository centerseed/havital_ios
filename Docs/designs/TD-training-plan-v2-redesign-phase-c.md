---
type: TD
id: TD-training-plan-v2-redesign-phase-c
status: Draft
l2_entity: training-plan-v2
created: 2026-05-19
updated: 2026-05-19
depends_on: TD-training-plan-v2-redesign-phase-b
---

# 技術設計：TrainingPlanV2 視覺重構 — Phase C

## 0. Context

Phase A/B 完成（主頁 cards + race header / mode header / badge wire / DayCard 互動模型 B4 push for past workouts）。

Phase C 觸發：用戶要求「點 day card 就要進訓練詳細說明頁面」、設計稿在 `/tmp/paceriz-design/paceriz-app/project/workout-detail.jsx`（481 行，5 變體：easy / interval / LSD / progression / fastFinish）。

## 1. Investigation Report

### 1.1 設計 source-of-truth

`/tmp/paceriz-design/paceriz-app/project/workout-detail.jsx`:
- 5 variants：`easy` / `interval` / `long` / `progression` / `fastFinish`
- Sheet 樣式：handle bar 頂 → 「星期 X X/X · 訓練詳情」title → 大 hero card（type color gradient + EASY chip + 訓練類型名 + 距離/時間/配速）→ 本次訓練目標（教練 intent）→ 訓練結構（segments）→ 目標區間（4 個 stat pill：配速/心率/RPE/消耗）→ 氣候提醒（如果有）→「什麼是 X？」+「調整這一天」次要按鈕 → sticky 底部 CTA（已在 Phase B5 完成的「開始今日訓練」相同設計）
- 補充訓練 section（如果有 strength / cross）
- Easy 簡化版（無 segments / 無組數）

### 1.2 iOS 現況

`Havital/Views/Training/WorkoutDetailViewV2.swift`（V1 / V2 共用）：
- 接受 `WorkoutV2` entity（已完成的 workout record）
- 顯示 distance / pace / HR zone / segments / share / RPE / notes / delete
- **不支援 planned mode**（無 WorkoutV2 record 進不來）

`WeekTimelineViewV2.swift` TimelineItemViewV2 互動：
- Today: inline expand
- Rest: sheet
- Past day with workout: push WorkoutDetailViewV2(workout:)
- 其他: toggle expand isExpanded（**用戶 explicit 要拿掉**）

### 1.3 [unconfirmed]

- WorkoutDetailViewV2 是否能接收純 `DayDetail.session`（無 WorkoutV2）渲染 — 要 audit
- 5 variant 的 runType / interval block / segments mapping 細節
- 補充訓練 entity（StrengthActivity / CrossActivity） rendering 規則

## 2. AC Compliance Matrix

| AC ID | AC | Verification |
|---|---|---|
| AC-TPV2-C-01 | WorkoutDetailViewV2 視覺對齊 design jsx（hero card + 教練註解 + segments + zones pill + 補充訓練） | 截圖 vs design canvas 比對 |
| AC-TPV2-C-02 | 5 variants 各自 UX 差異（interval 顯示組數結構、LSD 簡化、progression 漸速、fastFinish 加速、easy 最簡單） | 模擬器切不同 workout type 截圖 |
| AC-TPV2-C-03 | Planned mode 接受 DayDetail.session 渲染（未來日無 WorkoutV2 也可顯示） | 模擬器 tap 未來日 → detail page render | 
| AC-TPV2-C-04 | DayCard 互動模型：拿掉 isExpanded toggle、interval/補充 always inline、其他 collapsed only、tap (非今日非rest) → push detail | 模擬器逐項驗 |
| AC-TPV2-C-05 | 今日 inline expand 不變 / rest sheet 不變 / past with record push history detail 不變 | regression check |
| AC-TPV2-C-06 | Build PASS、Phase A/B 視覺全保留 | xcodebuild + screenshot |

## 3. Task Breakdown

### C1 — Audit WorkoutDetailViewV2

Developer 讀 `Havital/Views/Training/WorkoutDetailViewV2.swift` 全文：
- 列出 init params / required data
- 列出哪些 fields 是 `WorkoutV2` only（無 record 拿不到）
- 設計：怎麼擴成接受 `DayDetail.session` planned mode

**輸出**：audit report + planned mode 接入方案（最簡 vs 全重構）

### C2 — Redesign WorkoutDetailViewV2 per design jsx

Per `workout-detail.jsx` L?-? 重設計：
- Sheet handle bar + title
- Hero card（type color gradient + 訓練類型 + 距離 / 時間 / 配速 大字）
- 教練註解 section（accent box，跟 Phase A DayCard 風格一致）
- 訓練結構 section（reuse RedesignedSegmentsView 或新寫）
- 目標區間 4 pills（配速 / 心率 / RPE / 消耗）
- 氣候提醒（如果 day.climate）
- 補充訓練 section（如果 day.session.supplementary）
- 「什麼是 X？」+「調整這一天」次要按鈕（既有 functionality）
- 底部 sticky CTA 「開始今日訓練」（reuse Phase B5 button 樣式）

5 variants 各別處理：
- Easy: 簡化（無 segments、無組數，主就是 distance + pace）
- LSD: 同 easy + 帶水補給提醒
- Interval: 完整 segments + interval block + 組數 + 恢復
- Progression: 多段漸速顯示
- FastFinish: 多段加速顯示

### C3 — Planned mode

讓 view 接受 `DayDetail` 或 `(DayDetail, WorkoutV2?)` 構造，無 WorkoutV2 時 fallback 用 day.session 資料。

如果 WorkoutDetailViewV2 太緊耦合 WorkoutV2 entity → 新 view `WorkoutDetailPlannedView` 或 wrap with adapter。

### C4 — DayCard 互動模型重構

`WeekTimelineViewV2.swift` TimelineItemViewV2:
- **刪 `@State isExpanded`**
- **刪 toggle 邏輯**
- Today 仍 inline expand（保留 Phase B5 CTA button）
- Rest day 仍 sheet
- **Interval / 補充訓練 days: 預設 inline 顯示 segments / 補充列表（always visible，不需 tap）**
- **Single segment days: collapsed only（不顯示 segments inline）**
- **Tap (非今日非rest): 永遠 push WorkoutDetailViewV2**
  - 有 WorkoutV2 record → push(workout)
  - 無 WorkoutV2 → push(planned with day.session)

## 4. Cross-Repo Impact

- iOS: 1-2 view 重寫 + 1 view 大改 + 可能新增 PlannedView
- Backend: 無
- Android: 無

## 5. Risk Assessment

### 5.1 不確定點
- WorkoutDetailViewV2 改動範圍未知（先 audit 再決定）
- 5 variant 視覺差異多大、邏輯多複雜
- 補充訓練 rendering 沿用既有 `SupplementaryTrainingView` 或重寫

### 5.2 替代方案
- 全重寫 vs 大改 vs 兩個 view (history + planned)
- 漸進 vs 一次到位

### 5.3 最壞情況
- WorkoutDetailViewV2 改動破其他 navigation flow（has share / RPE / delete 等其他用戶flow）
- 防護：保留所有既有 functionality，只動視覺 + 加 planned mode

## 6. Dispatch Plan

**Phase C kickoff dispatch**：1 個 Developer 從 C1 → C2 → C3 → C4 串行。

預估 4-8 小時 wall clock（含 audit + 重寫 + 5 variants + planned + 互動重構 + build/install/截圖每步）。

若 Developer 中途遇到 blocker（如 WorkoutDetailViewV2 過於緊耦合）→ 回報 TPM, TPM 重新切分。
