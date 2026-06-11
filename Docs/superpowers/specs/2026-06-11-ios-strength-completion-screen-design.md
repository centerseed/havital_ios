# iOS 力量訓練完成回報畫面 — Design Spec

**Date:** 2026-06-11
**Scope:** iOS only（不動後端，用現有 `POST /v2/strength/complete`）
**Goal:** 讓使用者對力量訓練日逐動作標記完成/略過 + 給整體 RPE，送到後端校準引擎，並把「升級」回饋給使用者，讓力量訓練 RPE 閉環在真機上真正啟動。

---

## 背景與問題

力量訓練 RPE 閉環的**後端**已接通並 merge 進 api_service 本機 main（2026-06-11，見後端 spec `cloud/api_service/docs/superpowers/plans/2026-06-11-strength-rpe-loop-backend-wiring.md`）：RPE → `calibrate_after_completion` 校準 series level → 下次週課表用 ladder 反映新處方（帶 `series_id`）。

但 **iOS 端缺口導致 prod 上閉環不會啟動**：目前 iOS 只對跑步送通用 `PATCH /v2/workouts/{id}` 的 `{rpe}`，**從不呼叫** `POST /v2/strength/complete`，也沒有力量專屬的逐動作完成回報畫面。力量訓練日目前**只能看不能回報**（`PlannedSessionDetailView` + `ExercisesListView`，無完成動作）。Watch 端力量標記 `.unsupported`。

本 spec 規劃補上這個 iOS 畫面。

### 後端契約（現況，不改）

`POST /v2/strength/complete`（`api/v2/strength.py`）

Request：
```json
{
  "day_date": "2026-06-11",
  "strength_type": "core_stability",
  "exercises": [
    {"exercise_id": "plank", "series_id": "plank_series", "status": "completed"},
    {"exercise_id": "dead_bug", "series_id": "dead_bug_series", "status": "skipped"}
  ],
  "overall_rpe": 4,
  "duration_minutes": 15,
  "notes": null,
  "weekly_plan_id": "<plan id>"
}
```
- `status` ∈ `completed` | `skipped`（pattern 強制）。
- `overall_rpe` 1-10（強制）。
- `actual_sets` / `actual_reps` / `actual_duration_seconds` 為 Optional —— 本 MVP **不送**（粒度 B）。
- `notes`、`duration_minutes`、`weekly_plan_id` Optional。

Response：
```json
{ "progress_updates": [
  {"series_id": "plank_series", "previous_level": 1, "new_level": 2, "reason": "rpe_upgrade"}
]}
```
- `reason` ∈ `rpe_upgrade` | `rpe_downgrade`。
- 無升降級時 `progress_updates` 為 `[]`。
- **回傳不含** series 顯示名、也不含下次 level 的具體處方（這兩項本 MVP 由 iOS 自理 / 略過，不動後端）。

校準規則（後端 `calibration.py`，供理解，不在 iOS 實作）：每動作的 `status` 驅動「連續略過→降級」；`overall_rpe` 驅動「≤5 連2次→升級、≥8→降級」。**只用 `status` + `overall_rpe` 兩個訊號**，故 iOS 只需捕捉這兩項。

---

## 決策摘要（brainstorm 定案）

| # | 決策 | 選擇 |
|---|------|------|
| 1 | 捕捉粒度 | **B**：逐動作完成/略過開關 + 整體 RPE（不記實際 sets/reps，因後端不用→YAGNI） |
| 2 | 送出後反饋 | **B1**：用現有 API 做精簡升級慶祝（series 名走 iOS 本地 i18n；不顯示具體處方差異，改通用句；不動後端） |
| 3 | 進入點 / 觸發 | 手動 —— 力量訓練日詳情底部「完成訓練」CTA → present sheet（與跑步 RPE 一致為 sheet） |
| 4 | 冪等 / 防重送 | **一次性 + 本地記錄已完成**（後端不冪等、無 GET 查狀態 → 送出後本地標記、CTA 鎖定，擋重送） |

---

## 架構

遵循 iOS 既有分層 `Presentation → Domain → Data → Core`（依賴向內）。新功能掛在 **TrainingPlanV2 feature** 下（力量訓練屬週課表）。

```
PlannedSessionDetailView (既有, 加 CTA)
   │  tap「完成訓練」(僅力量日 + 未完成時顯示)
   ▼
StrengthCompletionSheet (新, Presentation)         ← present 為 sheet
   │  逐動作 toggle(完成/略過) + RPE pill(重用)
   ▼
StrengthCompletionViewModel (新, @MainActor, Factory)
   │  depends on TrainingPlanV2Repository (protocol)
   ▼
TrainingPlanV2Repository.completeStrengthSession(...) (protocol, 加方法)
   ▼
TrainingPlanV2RepositoryImpl → TrainingPlanV2RemoteDataSource.completeStrengthSession(...)
   ▼
POST /v2/strength/complete  →  StrengthCompletionResponseDTO
   │
   ▼ (成功)
StrengthCompletionStore (新, 本地, Core/Data 或既有 local cache): mark(dayDate) 已完成
   │
   ▼
反饋: progress_updates 有升降級 → 升級慶祝; 否則安靜確認
```

### 元件職責（每個可獨立理解/測試）

| 元件 | 層 | 職責 | 依賴 |
|------|----|------|------|
| `StrengthCompletionSheet` | Presentation | 純渲染：動作列 + toggle + RPE + 送出 + 反饋畫面 | ViewModel、共用 RPE 元件 |
| `StrengthCompletionViewModel` | Presentation | 狀態（每動作 status、selectedRPE、ViewState）、組 request、提交、處理 response、寫本地已完成標記 | `TrainingPlanV2Repository` protocol、`StrengthCompletionStore` |
| `StrengthRPESelector`（抽出） | Presentation | 重用：1-10 RPE pill + feedback 文案（從 `WorkoutReflectionView` 抽成共用元件） | 無業務邏輯 |
| `TrainingPlanV2Repository.completeStrengthSession` | Domain(protocol)/Data(impl) | DTO↔Entity、呼叫 DataSource | RemoteDataSource、Mapper |
| `TrainingPlanV2RemoteDataSource.completeStrengthSession` | Data | `POST /v2/strength/complete`，`.tracked(from:)` | HTTPClient |
| `StrengthCompletionMapper` | Data | request entity → DTO；response DTO → entity | 無 |
| `StrengthCompletionStore` | Core/Data | 本地已完成標記讀寫（key = `day_date`(+`strength_type`)） | UserDefaults / 既有 local cache |
| `SeriesDisplayName`（i18n map） | Core/Presentation | `series_id` → 在地顯示名，未知 fallback 通用名 | i18n |

---

## 資料模型改動（必要）

`Exercise` Entity（`Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift`）與 `ExerciseDTO`（`.../Data/DTOs/TrainingSessionDTOs.swift`）**目前沒有 `series_id`**。後端生成端（已接通的 C1）會在力量 supplementary 的每個 exercise 帶 `series_id`，但 iOS DTO 沒解碼它。

- **新增** `ExerciseDTO.seriesId: String?`（`CodingKeys` 對 `series_id`）。
- **新增** `Exercise.seriesId: String?`（Domain entity，camelCase）。
- Mapper 補 `series_id` 對應。
- 沒有 `series_id` 的 exercise（舊資料 / 非 ladder 來源）→ 完成回報時該動作 `series_id` 為 null；仍可送（後端 calibrate 對無 series_id 的動作會跳過，不影響其他）。

新增 request/response DTO：
- `StrengthCompletionRequestDTO`：`dayDate` / `strengthType` / `exercises: [StrengthExerciseStatusDTO]` / `overallRpe` / `durationMinutes?` / `weeklyPlanId?`（CodingKeys → snake_case）。
- `StrengthExerciseStatusDTO`：`exerciseId` / `seriesId?` / `status`（"completed"|"skipped"）。
- `StrengthCompletionResponseDTO`：`progressUpdates: [ProgressUpdateDTO]`。
- `ProgressUpdateDTO`：`seriesId` / `previousLevel` / `newLevel` / `reason`。
- 對應 Domain entity（`StrengthCompletionResult`、`StrengthProgressUpdate`，無 Codable）。

---

## 畫面規格（StrengthCompletionSheet — 粒度 B）

**Sheet header**：`<strength_type 顯示名>` + 「完成回報」。

**動作列表**：每個 planned exercise 一列：
- 左：`exercise.name`（後端給）+ 計畫值副標（`{sets}×{reps}` 或 `{sets}×{duration}秒`，重用 `ExercisesListView` 的呈現邏輯）。
- 右：**完成/略過開關**，**預設 = 完成（on）**。toggle off = 略過（視覺上灰/劃線 + 「略過」chip）。

**整體 RPE**：抽出的 `StrengthRPESelector`（重用 `rpePill` 1-10 色階 + `rpeFeedback` 文案 + `RecapPalette.rpe`）。RPE 為**必填**（未選時送出按鈕 disabled）。

**送出**：固定底部「完成訓練」按鈕；點擊後立即 disable 防連點；提交中顯示 loading。

**反饋（送出成功後，sheet 內切換至反饋態）**：
- `progress_updates` 含升/降級：升級慶祝
  - 升級：「做得輕鬆漂亮 💪 — `<series 顯示名>` 升級 L`<prev>`→L`<new>`」+ 通用句「下次課表會幫你進階」。
  - 降級：對應的鼓勵語（如「這次偏吃力，下次幫你回到適合的強度」），`<series 顯示名>` L`<prev>`→L`<new>`。
  - 多筆 progress_updates → 列出（或取主要一筆 + 「等 N 項調整」）。
- `progress_updates` 為 `[]`：安靜確認「已完成 · `<strength_type>` · RPE `<x>` ✓」。
- 「完成」按鈕關閉 sheet。

**MVP 不含**：實際組數/次數編輯（粒度 C）、備註欄、編輯/撤銷。

---

## 進入點與完成狀態（防重送）

- `PlannedSessionDetailView`（力量訓練日）底部加「完成訓練」CTA。
- 進畫面時 `StrengthCompletionStore.isCompleted(dayDate)` 判斷：
  - 未完成 → 顯示「完成訓練」CTA（可點）。
  - 已完成 → 顯示鎖定態「已完成 · RPE `<x>`」，CTA disabled。
- 送出成功後 → `StrengthCompletionStore.markCompleted(dayDate, rpe:)` 寫本地。
- **已知限制（MVP 接受）**：換裝置/重裝不同步；誤點不能撤；同週重生成課表後舊日期標記仍在。

---

## i18n

- 新增 `strength.completion.*`：title、逐動作提示、「完成」/「略過」、整體 RPE 提示、送出按鈕、升級/降級慶祝語、安靜確認語。
- 新增 `strength.series.<series_id>` 顯示名對照（涵蓋 `progression_ladders.yaml` 全部 series_id：如 `plank_series`、`dead_bug_series`、`bird_dog_series`、`side_plank_series`、`bridge_series`、`clamshell_series`、`squat_series` 等；**實作時以該 YAML 為準枚舉**），未知 fallback 通用名（如「力量動作」）。
- 三語 en-US / ja-JP / zh-rTW（zh-TW 優先）。
- 動作名沿用後端 `Exercise.name`，不本地化。

---

## 測試

- **ViewModel 單元測試**（mock `TrainingPlanV2Repository` protocol）：
  - 逐動作 toggle → 組出正確 request（exercises 的 status、series_id、exercise_id；不含 actual_*）。
  - RPE 未選 → 送出 disabled；RPE 1-10 範圍。
  - 提交成功 → 呼叫 `StrengthCompletionStore.markCompleted`、ViewState 進反饋態。
  - `progress_updates` 升級 → 慶祝態正確（series 名、L prev→new）；`[]` → 安靜確認。
  - 送出失敗 → `DomainError` + ViewState error；不寫已完成標記、不鎖定（可重試）。
- **DataSource/Mapper**：request DTO 序列化為正確 snake_case body（含 series_id、status）；response DTO 解碼 progress_updates。
- **Model 解碼**：`ExerciseDTO` 解 `series_id` → `Exercise.seriesId`。
- **StrengthCompletionStore**：markCompleted / isCompleted 持久化往返。
- **Maestro flow**：進力量訓練日 → 點完成訓練 → sheet → 標記一動作略過 → 選 RPE → 送出 → 看到反饋 → 關閉 → 該天顯示已完成鎖定。
- **架構守門**：ViewModel 依賴 Repository protocol（非 Impl）；DTO 在 Data 層、Entity 在 Domain；所有 API 呼叫鏈 `.tracked(from:)`；async closure `[weak self]`；Repository 不發 `CacheEventBus`（若需事件由 ViewModel republish）。

---

## 明確不做（MVP 範圍外）

- 不動後端（用現有 `POST /v2/strength/complete`）。
- 無 Watch 力量支援（維持 `.unsupported`）。
- 無實際組數/次數記錄（粒度 C）、無備註欄、無編輯/撤銷。
- 無跨裝置同步、無完成歷史頁。
- 不顯示「具體下次處方差異」（需後端加回傳，列為日後 B2 follow-up）。

---

## 日後 follow-up（非本次）

- **B2 後端增強**：`/v2/strength/complete` response 每筆 progress_update 加 series 顯示名 + 新 level 具體處方（從 ladder 算），iOS 即可顯示「棒式 2×20秒→2×30秒」具體差異。
- 跨裝置完成狀態（需後端 GET / 把完成寫回 plan doc）。
- Watch 力量完成回報。
