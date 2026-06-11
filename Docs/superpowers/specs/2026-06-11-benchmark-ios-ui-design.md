# 指標跑體驗弧線 iOS UI（Design Spec）

> 跨 repo：**iOS 為主**（apps/ios/Havital）+ **後端補欄位**（cloud/api_service）。
> 延續：benchmark v2 後端（已 merged main，merge 6fbd9fbc）。後端機制（同意閘 / 校準 registry / 加權 VDOT）已就緒。
> 狀態：Design 已拍板（2026-06-11 brainstorming），待 writing-plans。

---

## 北極星

讓用戶有完整體感：**「我選擇跑指標跑 → 跑完成果回饋到訓練流程 → 訓練數據更精準」**。

後端 v2 已把機制全部接好，但 iOS 端 `execute_benchmark` / `adjust_vdot` 兩種確認項目前被當成普通灰底建議卡渲染（`AdjustmentItemV2DTO` 連 `type` 欄位都沒有），課表 benchmark 日跟一般訓練日視覺份量相同，校準後「數據變精準」也沒有歸屬。這條弧線在 UI 層幾乎是空白畫布——本 spec 把它接起來。

## 拍板決策（brainstorming 2026-06-11）

1. **四觸點全做**：執行確認卡 / 校準成果卡 / 課表 benchmark 日份量 / readiness 歸因標記。
2. **成果語言**：配速 + 完賽預測為主，VDOT 退為輔助小字。
3. **調性**：教練式冷靜肯定——不彩帶、不獎盃，慶祝（`CelebrationSheet`/`ConfettiView`）留給真比賽 PB，兩者不混淆。
4. **校準成果卡**：**差異展示（before/after）是卡片視覺主角**；toggle「採用這次校準」**主動勾選才套用**（confirm gate，`apply=false` 預設）。
5. **執行確認卡**：`apply=true` 預設（排訓練不靠主動 opt-in，這是 v2 核心）；toggle 標籤「**安排這次指標跑**」。
6. **詳情頁**：弱化配速區間、改強調「全力跑、不用追配速」（照區間跑會讓校準失真）。
7. **實作取向（方案 1）**：地基優先 + 列表內專屬強調卡 + 分層交付。不動週回顧 sheet 結構、不碰既有 toggle / `applied_indices` 機制。
8. **可測試性是第一公民**：注入工具 + Maestro e2e + 後端 dev E2E，讓用戶能逐畫面實機驗收（弧線正常跨數週、需真跑，不可能等著驗收）。

---

## 架構總覽

```
§A 資料地基（後端補 typed field + iOS 三層寬鬆解碼 + fallback）
        │
        ├── §B 執行確認卡（execute_benchmark，下週回顧「我選擇跑」）
        ├── §C 校準成果卡（adjust_vdot，跑完回顧「成果回饋」，差異為主角）
        ├── §D 課表 benchmark 日份量（詳情頁 hero「跑之前」）
        └── §E readiness 歸因標記（「數據變精準」被看見）
        │
§F benchmark 設計資產（色 token / icon / i18n）
§G 可測試性（注入工具 / Maestro / 後端 E2E / SwiftUI Preview）
```

---

## §A 資料地基

### A.1 後端補欄位（cloud/api_service）

料都已存在於 `benchmark_confirmation_section` 的效益句計算與 `race_prediction`，只需抽成 typed field。

- **`adjust_vdot` item 的 value 加 `calibration_preview` 物件**（注入點：`weekly_summary_v2_service._apply_benchmark_review_adjustment`）：
  - `pace_before_s_per_km` / `pace_after_s_per_km`（easy 代表配速，秒/km）
  - `race_distance_label`（i18n，如「半馬」）
  - `race_time_before` / `race_time_after`（如 `1:52:30` → `1:48:10`）
  - `vdot_before` / `vdot_after`（輔助小字用）
- **`execute_benchmark` item 的 value 加 `scheduled_weekday`**（注入點：`_apply_benchmark_confirm_item`），讓卡片能寫「下週四的長跑換成…」。
- **readiness response 加歸因欄位**（只在用戶有 confirmed benchmark 且還在 28 天加權窗內時帶）：`vdot_source: "benchmark"` + `benchmark_date`。

向後相容：欄位全為新增 optional，舊 client 忽略。

### A.2 iOS 三層解碼（寬鬆契約）

跟現有 DTO 哲學與 `DayType` 寬鬆解碼教訓一致：**未知值絕不崩、缺欄位 fallback 普通卡**。

- **DTO**（`WeeklySummaryV2DTO.swift`）：`AdjustmentItemV2DTO` 加 `type: String?`（不是 enum）與 `value: AdjustmentItemValueDTO?`。`AdjustmentItemValueDTO` 把兩種 payload 的欄位全部當 optional 放進去（union of fields），Codable 缺的就 nil（避免 AnyCodable）。
- **Entity**（`WeeklySummaryV2.swift`）：`AdjustmentItemV2` 加 `benchmarkExecute: BenchmarkExecutePayload?` 與 `benchmarkCalibration: BenchmarkCalibrationPayload?` 兩個 typed payload。
- **Mapper**（`WeeklySummaryV2Mapper.swift`）：依 `type` 把 value 解成對應 payload：
  - `type == "execute_benchmark"` 且必要欄位齊 → `benchmarkExecute`
  - `type == "adjust_vdot"` 且 `calibration_preview` 齊 → `benchmarkCalibration`
  - 其餘 / 未知 type / 缺欄位 → 兩者皆 nil
- **渲染分流**（卡片上層 switch，`WeeklySummaryV2View.swift`）：`benchmarkExecute != nil` → 執行卡；`benchmarkCalibration != nil` → 校準卡；否則 → 現有通用 `AdjustmentItemCardV2`。

### A.3 不動的東西（關鍵）

toggle、`apply` 預設值、`coordinator.adjustmentSelections`、`applied_indices` 回傳機制**完全不碰**。專屬卡仍是 adjustment item，照樣有 toggle、照樣靠 index 回傳。後端 index 對齊已驗證（`api/v2/summary.py:373` enumerate 下標 == iOS `ForEach` offset），這層不動就不破壞同意閘。

---

## §B 執行確認卡（`execute_benchmark`）

位置：週回顧「下週調整建議」section 內，indigo hero 小卡版型（借 `PlannedSessionDetailView.heroCard:215` 漸層風格縮成列表卡），在一排普通調整中明顯不同。

元素層級：
1. Eyebrow chip「下週重點 · 實力校準」（`PRChip`，indigo，帶 `stopwatch`/`gauge.with.dots.needle`）。
2. 標題大字「{distance} 公里指標跑」。
3. 教練語：「全力跑一次固定距離，我用它把你的配速基準和完賽預測調準。」（精簡自後端 content/reason）。
4. 安排說明：「{scheduled_weekday}取代長跑；前一天自動安排休息保體力。」
5. Toggle 行：標籤「**安排這次指標跑**」，預設開；微字「取消＝這週先不排，之後可請 Rizo 重排。」
6. 未勾狀態：沿用既有 `opacity 0.4 + grayscale` + 微字「這週先跳過」。

「我選擇」的主動感：底層仍是 `apply=true` 預設（保持勾選＝接受），但正向標籤「安排這次指標跑」讓保持勾選讀起來像主動接受；份量來自 indigo hero 版型，不靠慶祝動畫。

底層：仍是 adjustment item，取消 → index 不送 → 後端 decline pre-scan 標 milestone declined。

---

## §C 校準成果卡（`adjust_vdot`）

觸發：跑完指標跑那週的回顧，後端偵測到有效指標跑 → 卡片出現。

**差異展示是視覺主角**（用戶明確訴求「讓用戶看到指標跑帶來的差異」）：

1. Eyebrow chip「指標跑成果 · 實力校準」（indigo）。
2. 教練肯定開頭：「你 {workout_date} 的 {distance}K 指標跑跑出 {time}，我用它重新校準了你的實力。」（time 由 `benchmark_duration_s` 格式化）。
3. **before/after 對比區（卡片英雄區，視覺重心）**——借 `PBMomentShareCardField:219` 三欄骨架，拿掉彩帶/獎盃：
   - 訓練配速 `{pace_before}→{pace_after}/km`，變化量「快了 X 秒」用克制綠色小箭頭（借 `CelebrationSheet` 進步 Label 邏輯但不慶祝）。
   - 完賽預測 `{race_distance_label} {race_time_before}→{race_time_after}`。
   - VDOT `{vdot_before}→{vdot_after}` 角落輔助小字當「依據」。
4. `should_hedge` 謹慎分支：殘差大時不斷言進步，文案轉「這次測量和你近期狀態有落差，可能是疲勞或設定，我先謹慎調整」。
5. 誠實預告：「課表配速會在 2-3 週逐步反映（系統刻意不追單週起伏）。」
6. Toggle 行：標籤「**採用這次校準**」，**預設關**（`apply=false`，confirm gate）——看完差異後主動勾選才套用。

底層：勾選 → `applied_indices` 含此 index → 後端 apply-items 寫 `benchmark_confirmed_runs` registry + milestone completed。不勾 → 不套用，VDOT 維持。

---

## §D 課表 benchmark 日份量（詳情頁 hero）

在現有 `PlannedSessionDetailView` 的 benchmark 分支增強（不另開頁）：

1. hero 已是 indigo，加 benchmark 專屬 icon（`stopwatch`/`gauge.with.dots.needle`）。
2. 「為什麼這天特別」說明卡：「這是一次實力測量。全力跑完這 {distance}K，我會用你的成績重新校準訓練配速和完賽預測——所以盡力跑。前一天已自動安排休息，讓你保持新鮮。」
3. 閉環埋線：「跑完後，下次週回顧會給你校準成果。」——讓用戶跑之前就期待看到差異，跑完在 §C 兌現。
4. **弱化配速區間**：現況 chip 寫死「BENCHMARK · Z4-Z5」（`PlannedSessionDetailView:116`）+ 顯示配速目標，會誘導用戶照區間跑（非全力 → 校準失真）。改為強調「全力跑、不用追配速」，移除/弱化 Z4-Z5 配速目標呈現。後端 reason 已是「全力測試」，是 iOS chip/配速呈現需對齊。

---

## §E readiness 歸因標記

- 後端 readiness response 帶 `vdot_source: "benchmark"` + `benchmark_date`（§A.1）。
- iOS 在顯示 `current_vdot` 的 readiness 位置加小標記：「實力評估已由你 {date} 的指標跑校準」，點擊可看簡短說明。
- **不改 readiness 計算**（後端加權 VDOT 池已保證 `current_vdot` 反映新值），只加歸因文字——讓「變精準」被看見、有歸屬，閉合「我跑了 → 數據真的因此變了」的回路。
- 歸因欄位缺 → 不顯示標記（不報錯）。

---

## §F benchmark 設計資產

- **色 token**：目前 benchmark 用 SwiftUI 內建 `.indigo`（`DayType+Extensions.swift:71`），design system 另有 `PacerizColor.indigo`（#6366F1）。統一到一個 benchmark 語意別名（如 `PacerizColor.benchmark`）作為 SSOT，四觸點共用。
- **icon**：目前無 benchmark 專屬 icon。選一個 SF Symbol（候選 `stopwatch` / `gauge.with.dots.needle` / `flag.checkered`），四觸點一致。
- **i18n**：目前只有 `training.type.benchmark` 一個 key。新增三語（en / zh-Hant / ja）key 群：執行卡（chip/標題/教練語/安排說明/toggle/取消微字）、校準卡（chip/肯定句/三欄標籤/hedge 文案/2-3 週預告/toggle）、詳情頁（說明卡/閉環句/全力跑提示）、readiness 歸因句。

---

## §G 可測試性（第一公民）

benchmark 弧線每個畫面對應一個「帳號狀態」。要逐畫面實機看到，就要能一鍵把 dev 帳號設成各狀態。

### G.1 展示資料注入工具（Python 腳本，走 dev，唯讀 prod）

一鍵把 dev 帳號設成四種狀態之一，simulator 登入即看到對應畫面：
- `execute`：下週有 active benchmark milestone → 執行確認卡
- `plan-day`：本週課表已含 benchmark 日 → 詳情頁份量
- `calibration`：跑完指標跑、週回顧偵測到（注入一筆全力 workout，三層儲存齊全）→ 校準成果卡
- `attributed`：已 apply 校準 → readiness 歸因標記

借用既有 `reset-v2-weekly-plan` skill、安全注入測試課表法（[[reference_paceriz_envs_accounts]]）、benchmark v2 後端 Task 13 E2E 用過的注入手法（含 workout HR 欄位正確路徑 `basic_metrics.avg_heart_rate_bpm`、`workouts_v2_index/` 寫入、用戶時區日期對齊）。

### G.2 Maestro e2e（每觸點一個 flow）

前置呼叫注入工具設好狀態 → Maestro 走到該畫面 → 截圖 + `assertVisible` 關鍵元素（配速數字 / toggle / 歸因文字）。同時是**回歸測試**與**「帶你直達畫面」工具**——要看哪個畫面跑對應 flow。Maestro 規範：不用 `--no-window`、iPhone 17 Pro、zh-TW locale。

### G.3 後端 dev E2E

延續 benchmark v2 後端 E2E，加驗 `calibration_preview` typed field 的 before/after 數字正確（配速 m/s→秒/km 換算、VDOT→完賽預測換算）、readiness 歸因欄位正確、`scheduled_weekday` 正確。

### G.4 SwiftUI Preview（輔助）

每張卡用 mock payload 做 Xcode Preview，開發期快速比對版型。主力是 G.1 注入工具 + G.2 Maestro。

---

## 錯誤處理

- **寬鬆解碼 fallback**：任何後端欄位變動 / 漏送 / 版本不一致，最壞退回現有普通 `AdjustmentItemCardV2`，不白屏不崩。
- 校準卡缺 `calibration_preview` → 降級（只顯示 VDOT 變化）或 fallback 普通卡。
- readiness 歸因欄位缺 → 不顯示標記。
- Cancelled task / 網路錯誤照既有 `ViewState` 處理（過濾 `NSURLErrorCancelled`）。

---

## 測試策略

- **後端**：`calibration_preview` / 歸因欄位的單元測試（換算正確性）+ dev E2E（§G.3）。
- **iOS**：DTO 解碼單元測試（含未知 type / 缺欄位 fallback 普通卡）、Mapper 測試（type → payload）、卡片 SwiftUI Preview、每觸點 Maestro flow。
- **對照組**：非 benchmark 帳號的週回顧零變化（普通卡照舊渲染、toggle/apply 機制不變）。

---

## 分層交付（方案 1，每層獨立可驗 + 可單獨上線）

1. **地基**：後端 typed field（`calibration_preview` / `scheduled_weekday` / readiness 歸因）+ iOS DTO/Entity/Mapper 三層解碼 + fallback。後端單元 + iOS 解碼單元。
2. **注入工具（G.1）**：優先做，支撐後面各層的實機驗收與 Maestro 前置。
3. **執行確認卡（§B）** + Maestro flow。
4. **校準成果卡（§C）** + Maestro flow。
5. **課表日份量（§D）** + Maestro flow。
6. **readiness 歸因（§E）** + Maestro flow。
7. **設計資產（§F）** 貫穿各層（色 token / icon / i18n 隨用隨加，最後統一收斂）。

---

## 跨 repo / 風險

- **iOS 分支拓撲**（[[project_ios_branch_topology]]）：主開發線是 `ui_revamp` 不是 `main`，當前在 `feature/rizo-plan-change-buttons`。實作前確認分支基點、與用戶確認「合回哪裡」。
- **後端對齊**：補欄位要與 benchmark v2 已 merged 的 confirm / value 注入（`_apply_benchmark_review_adjustment` / `_apply_benchmark_confirm_item`）對齊，不重造。
- **UI parity（iOS ↔ Android）**：此為 iOS 新增體驗，Android 對齊**另議**（不在本 spec 範圍）。
- **注入工具**：走 dev，prod 唯讀。

---

## Out of scope

- 獨立慶祝 moment（方案 2，被否決）。
- workout detail 頁即時觸發校準（校準在週回顧偵測，非 workout 同步當下）。
- Android 對應 UI（另議）。
- benchmark 歷史校準記錄頁 / 多次校準趨勢（未來）。
