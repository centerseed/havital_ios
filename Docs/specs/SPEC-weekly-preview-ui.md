---
doc_id: SPEC-weekly-preview-ui
title: 功能規格：週訓練骨架預覽 UI
type: SPEC
ontology_entity: 訓練計畫系統
status: under_review
version: "0.1"
date: 2026-04-04
supersedes: null
---

# Feature Spec: 週訓練骨架預覽 UI

## 背景與動機

後端 `weekly_preview` API 已完成 schema 升級（`daily_schedule` → `quality_options + long_run`），
新格式能清楚表達每週的訓練骨幹：長跑類型、品質訓練類型、強度比例。

目前 App 用戶無法在訓練計畫中看到「接下來幾週大概要練什麼」，
只能看到本週的詳細日課表。這導致用戶對整份訓練計畫缺乏整體感，
不確定計畫的結構與走向。

## 目標用戶

- 正在執行訓練計畫的跑者
- 場景：想了解「接下來幾週的訓練方向」，但不需要看每天的詳細課表

## 需求

### P0（必須有）

#### 主畫面預覽卡片

- **描述**：在 `TrainingPlanV2View` 主畫面，於「訓練進度卡片」下方顯示一個「週訓練骨架」摘要卡片。
  卡片顯示標題與摘要（如「接下來 4 週 · 點擊查看」），點擊後開啟 Bottom Sheet。
- **Acceptance Criteria**：
  - Given 用戶在主畫面，When 有 weekly_preview 資料，Then 顯示摘要卡片
  - Given 用戶點擊卡片，When 觸發，Then 打開 Bottom Sheet 顯示未來四週骨架
  - Given 沒有 weekly_preview 資料或 loading，Then 卡片不顯示（不 fallback 到 loading spinner）

#### Bottom Sheet 週骨架內容

- **描述**：Bottom Sheet 顯示從**當前週**起算的**未來四週**訓練骨架，每週為一個卡片。
- **每週卡片顯示**：
  - 週次 + 階段名稱（例：「第 3 週 · 基礎期 3/4」）
  - 目標週跑量（km）
  - 強度比例視覺條（低強度 / 中強度 / 高強度）
  - 長跑類型（LSD / 馬配速長跑 / 漸進長跑，若無則顯示「—」）
  - 品質課類型（間歇 / 節奏跑 / 法特萊克 / 速度跑 / 上坡跑，若無則顯示「—」）
  - 當前週標示（視覺高亮，例如左側藍色邊線）
- **Acceptance Criteria**：
  - Given 當前週是第 2 週，Then 顯示第 2、3、4、5 週（共 4 週）
  - Given 計畫剩餘不足 4 週，Then 顯示到最後一週（不 pad 空白週）
  - Given quality_options 為空陣列，Then 品質課顯示「—」
  - Given long_run 為 null，Then 長跑顯示「—」

#### Disclaimer 提示

- **描述**：Bottom Sheet 頂部顯示固定說明文字，告知用戶此為初步規劃。
- **文字**：「以下為各週訓練骨架，實際課表將依你的訓練狀態動態調整」
- **Acceptance Criteria**：
  - Given Bottom Sheet 開啟，Then 說明文字永遠顯示在週卡片列表上方

#### Plan Overview Sheet 週骨架 Section

- **描述**：在 `PlanOverviewSheetV2` Tab 2「訓練計畫」，於現有的訓練階段卡片下方，
  新增「接下來四週」inline section，內容與 Bottom Sheet 相同。
- **Acceptance Criteria**：
  - Given 用戶在 Plan Overview Tab 2，When 有 weekly_preview 資料，Then 顯示週骨架 section
  - Given 無資料，Then section 不顯示

### P1（應該有）

#### 訓練類型中文化顯示

- **描述**：將 API 回傳的英文 training_type / category 轉換為用戶易讀的中文標籤。
- **對照表**：
  - `lsd` → 長慢跑
  - `mp_long_run` → 馬配速長跑
  - `progressive_long_run` → 漸進長跑
  - `vo2max_day` → VO₂max 間歇
  - `threshold_day` → 節奏跑
  - `fartlek_day` → 法特萊克
  - `speed_day` → 速度訓練
  - `hills_day` → 上坡跑
  - `quality_day` → 品質訓練
- **Acceptance Criteria**：
  - Given API 回傳 `lsd`，Then UI 顯示「長慢跑」

### P2（可以有）

#### 當前週高亮與視覺區隔

- **描述**：當前週的卡片有更明顯的視覺高亮（例如左側藍色邊線 + 背景略深），
  未來週以較淡樣式呈現，強化「當前位置感」。

## 明確不包含

- 不顯示每日詳細課表（那是主畫面 WeekTimelineViewV2 的職責）
- 不顯示過去已完成的週
- 不提供編輯或調整功能（純展示）
- 不顯示超過四週之後的週

## 技術約束（給 Architect 參考）

- 資料來源：`GET /v2/plan/{overview_id}/weekly-preview`，需要 Bearer token
- 當前週數從 `TrainingPlanV2ViewModel.currentWeek` 取得
- `overview_id` 從 `planOverview.id` 取得
- 新 DTO 需接 `quality_options`（陣列）和 `long_run`（可為 null）
- 舊欄位 `daily_schedule` 和 `intensity_distribution` 已移除，需清除舊對接代碼
- `intensity_ratio` 是新命名（舊名為 `intensity_distribution`），同值
- Bottom Sheet 使用現有 `.sheet` 或 `.presentationDetents` 實作
- 資料可在 Plan Overview 載入時一併 fetch，不需獨立觸發

## 開放問題

- 無
