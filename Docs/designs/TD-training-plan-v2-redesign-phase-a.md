---
type: TD
id: TD-training-plan-v2-redesign-phase-a
status: Draft
l2_entity: training-plan-v2
created: 2026-05-18
updated: 2026-05-18
---

# 技術設計：TrainingPlanV2 視覺重構 — Phase A

## 0. Context

2026-05 設計團隊產出 Paceriz 全 app 現代化重新設計（11 個 artboards）。本 TD 範圍：**只 cover「訓練計畫」首頁的 Phase A — 純視覺重做、不引入新資料層、不改互動模型**。

Phase B（徽章資料源整合、Race header 聚合、Starter/Maintain header、DayCard tap 互動模型變更）將以獨立 TD 處理。

設計來源（已下載解壓）：`/tmp/paceriz-design/paceriz-app/`
- `project/training-plan.jsx`（1311 行）— 設計唯一來源
- `project/Paceriz Redesign.html` — Canvas 入口
- `chats/chat1.md` — 設計決策脈絡

---

## 1. Investigation Report

### 1.1 已讀檔案

| 檔案 | 內容 |
|---|---|
| `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift` (892 行) | 主頁面，VStack(spacing:24) 依序排 TrainingProgressCardV2 → WeekOverviewCardV2 → WeekTimelineViewV2 |
| `Havital/Features/TrainingPlanV2/Presentation/Views/Components/TrainingProgressCardV2.swift` (201 行) | 階段進度卡。`stageProgressBar(overview:)` slider 邏輯已符合設計 |
| `Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekOverviewCardV2.swift` (336 行) | 週概況卡。當前布局：圓環 + 3 條 `CompactIntensityBarV2` + 兩按鈕 |
| `Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekTimelineViewV2.swift` (1302 行) | timeline。`TimelineItemViewV2` 是每日卡片，今日 expanded inline，其他日 tap toggle expand |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/WeeklyPlanLoader.swift` | 暴露 `currentWeekDistance`、`currentWeekIntensity (low/medium/high minutes)`、`workoutsByDay[Int:[WorkoutV2]]` |
| `Havital/Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift` | `RunActivity.distanceKm`、`durationMinutes`、`durationSeconds` 提供日計畫資料 |
| `Havital/Features/TrainingPlanV2/Domain/Entities/PlanOverviewV2.swift:100-110` | `isRaceMode / isBeginnerMode / isMaintenanceMode` 已存在 |

### 1.2 Specific findings

- **Slider 邏輯（stageProgressBar）已符合設計**，不需重做演算法，只需移除外圍 3-row 布局壓成 single-row header + slider。
- **CompactIntensityBarV2** 僅在 WeekOverviewCardV2.swift 內被引用（grep 驗證），可安全刪除。
- **Intensity 單位是分鐘**（`viewModel.loader.currentWeekIntensity.low/medium/high : Int minutes`），設計用 km 但只需相對比例 → 直接用分鐘做 segmented bar，不轉 km。
- **iOS bundle 沒有 badge image asset**（`find Havital/Assets.xcassets -name "*badge*"` 空）。Placeholder 用 SF Symbol。
- **`viewModel.getDate(for: dayIndex)` 已存在**，可推算本週日期區間 (5/11 – 5/17)。

### 1.3 [unconfirmed]

- **Dynamic Type 行為**：redesign 設計稿是 pixel-perfect 固定字級。是否要保留 AppFont 的 Dynamic Type scaling？決策：Phase A 用固定字級（與設計一致），未來再評估 Dynamic Type 影響。
- **i18n 長字串**：日文/英文 chip 文字寬度未驗證。Done Criteria 要求 QA 在 zh-TW 之外至少抽測一個語言。

---

## 2. AC Compliance Matrix

> SwiftUI 視覺重構，AC 以「視覺驗證 + 行為保留」為主，無傳統單元測試 AC。

| AC ID | AC Description | Implementation Location | Verification |
|---|---|---|---|
| AC-TPV2-A-01 | 設計 token（色票、PRChip、PRDotLegendItem、PRSegmentedIntensityBar、PRPlaceholderBadge）集中在單一檔，feature view 不得直接寫 hex | `Havital/Core/Presentation/PacerizDesignSystem.swift` | grep `Color(red:` in WeekOverviewCardV2/TrainingProgressCardV2 → 應為 0 |
| AC-TPV2-A-02 | TrainingProgressCardV2 壓成 single-row header (icon · stage name · 第 N/M 週 chip · ▸) + slider | `TrainingProgressCardV2.swift` | 模擬器截圖：階段名與 slider 同卡，無第三行 stage label |
| AC-TPV2-A-03 | WeekOverviewCardV2 改成：title + week range · badge hero + 距離 + 分段 intensity bar + dot legend · 兩按鈕 | `WeekOverviewCardV2.swift` | 模擬器截圖：72px placeholder badge 可見、單一水平 intensity bar、無圓環 |
| AC-TPV2-A-04 | DayCard 加 type accent 左條（rest 日除外）、過去完成日加「課表 / 實際」雙行對比、今日 outline 改 2px | `WeekTimelineViewV2.swift` (TimelineItemViewV2) | 模擬器截圖：今日卡 2px blue outline、已完成日有 "課表" gray + "實際" green 兩行 |
| AC-TPV2-A-05 | 互動行為不變：今日 inline expanded、其他日 tap toggle expand、所有 sheet binding 保留 | `WeekTimelineViewV2.swift` | 模擬器：tap 過去日卡仍 toggle、tap 訓練類型 chip 仍開 TrainingTypeInfoView |
| AC-TPV2-A-06 | 清 build 0 error、原有 Maestro flow 仍可 run | `xcodebuild clean build` + `maestro test .maestro/flows/regression-full-suite.yaml`（若存在 plan 相關 flow） | CI-style verification |
| AC-TPV2-A-07 | 所有 redesign 程式碼有清楚註解標明「PACERIZ REDESIGN 2026-05」，避免日後誤改舊邏輯 | 全部 3 個改動檔 | grep `PACERIZ REDESIGN` → 至少 3 處 |
| AC-TPV2-A-08 | 徽章是 placeholder，明確標示 `PHASE_B_BADGE` 註解 token | `PacerizDesignSystem.swift` + `WeekOverviewCardV2.swift` | grep `PHASE_B_BADGE` → 至少 2 處 |
| AC-TPV2-A-09 | **Design parity** — 模擬器截圖與 design canvas artboard 1:1 比對，每一項漸層 / 陰影 / 字級 / 間距都要對齊 §3.5 Parity Checklist | 全部 3 個改動檔 | QA 在 A4 用 side-by-side 截圖逐項打勾，列出任何偏差 |

---

## 3. Task Breakdown

> 依序執行；每個 task 完成後 Developer 必須 `xcodebuild clean build` 跑過再進下一個。

### Task A0 — Design System 基底（新檔）

**檔案**：建立 `Havital/Core/Presentation/PacerizDesignSystem.swift`

**內容**（最小集合）：
- `enum PacerizColor`：blue / blueDeep / blue12 / green / greenDeep / green12 / orange / orangeDeep / orange12 / error
  - 對應 design jsx tokens：`#3F86F6` / `#76C893` / `#FF7F50` / `#E64B4B`
  - `*12` = 12% opacity 版本
  - `*Deep` = 加深版本（design 用於 active text / icon）
- `enum PacerizRadius`：card=14, inner=10
- `struct PRChip`：膠囊 label，傳 text/fg/bg/fontSize；用於「第 N/M 週」「✨ 即將推出」「百分比」chip
- `struct PRDotLegendItem`：小方塊 dot + label（用於 ● 輕鬆/中等/強度）
- `struct PRSegmentedIntensityBar`：水平 3 色分段（綠/橘/紅）+ 灰底；輸入 low/medium/high/total（同單位）、proportional 寬度
- `struct PRPlaceholderBadge`：SF Symbol `rosette` + 漸層 blue tint + drop shadow；參數 size（預設 72）
  - 必須在註解標明 `PHASE_B_BADGE`，說明 Phase B 會替換成真實 BadgeRepository 資料

**Done Criteria**：
- [ ] 檔案頂端有 `MARK: - Paceriz Redesign Design System (introduced 2026-05)` 區塊註解，說明用途與「Do NOT define ad-hoc hex」原則
- [ ] 5 個 component view 都可獨立 compile（沒有跨檔依賴）
- [ ] `xcodebuild clean build` 0 error 0 warning（new file）

### Task A1 — TrainingProgressCardV2 壓單行 header

**檔案**：`Havital/Features/TrainingPlanV2/Presentation/Views/Components/TrainingProgressCardV2.swift`

**改動**：
- 保留：`stageProgressBar`、`makeGradientStops`、`stageColorFor`、`getCurrentStage`、`getStageColor`、`showTrainingProgress` sheet binding
- 改：body VStack 內 3 row → 2 row
  - Row 1（新 single-row header）：`Image("chart.line.uptrend.xyaxis")`（顏色 = 當前階段色）+ `Text(currentStage.stageName)` + `PRChip(第 N / M 週, fg: stageColor, bg: stageColor.opacity(0.14))` + `Spacer()` + `Image("chevron.right")` 細
  - Row 2：`stageProgressBar(overview:)`（原樣）
- 刪：原本第 3 row 的「stage dot + name + week range」（資訊已合併到 header chip）
- 字級：header 用 `.font(.system(size: 14, weight: .bold))` 對齊設計

**Done Criteria**：
- [ ] Card 高度比改前低（少一 row）
- [ ] PHASE-fallback：若 `planOverview == nil`，header 顯示「訓練進度」當 fallback 標題（不可 crash）
- [ ] 不影響 `showTrainingProgress` sheet 行為
- [ ] grep `PACERIZ REDESIGN 2026-05` 至少 1 處註解
- [ ] `xcodebuild clean build` 0 error

### Task A2 — WeekOverviewCardV2 全重寫

**檔案**：`Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekOverviewCardV2.swift`

**保留**：
- `showWeekTargetDetail`、`showTrainingCalendar` sheet binding
- `WeekTargetDetailViewV2` struct（檔尾的 sheet 內容）— **完全不動**
- 對 `unitManager`、`plan.intensityTotalMinutes`、`viewModel.loader.currentWeekDistance/Intensity` 的依賴

**刪除**：
- `CompactIntensityBarV2`（grep 驗證僅此檔使用，可安全刪）
- 圓環進度（ZStack with Circle）整段

**新 layout（從上到下）**：
1. **Header row**：`chart.pie.fill` icon + 標題 "週跑量和訓練強度" + Spacer + 右側日期 chip（如 "📅 5/11 – 5/17"，從 `viewModel.getDate(for: 1)` 和 `(for: 7)` 推算；無法推算則隱藏）
2. **Hero row（HStack alignment .top）**：
   - 左：`PRPlaceholderBadge(size: 72)` ⚠️ 標 `PHASE_B_BADGE`
   - 右 VStack：
     - 徽章名（placeholder）：`Text("本週進度")` + `PRChip("✨ 即將推出", fg: blueDeep, bg: blue12, fontSize: 9)` — i18n key + `PHASE_B_BADGE` 標
     - 距離 row：大字 `"23"` (22pt bold rounded) + 小字 `"/ 30 km"` + Spacer + `PRChip("77%")`
     - `PRSegmentedIntensityBar(low: i.low, medium: i.medium, high: i.high, total: max(actualTotal, plannedTotal))` ← 確保未到 100% 也有相對比例顯示
     - `HStack(spacing: 12)` 三個 `PRDotLegendItem`：● 輕鬆（green）、● 中等（orange）、● 強度（error）
3. **Divider**
4. **Action row**：兩個按鈕 — 本週目標（blue）、訓練日曆（green）。改用 `PacerizColor` token + `PRChip`-style flat 設計，高度 34，icon + label + chevron-right

**i18n key（新增）**：
- `training_plan.weekly_badge_placeholder_name` → "本週進度"
- `training_plan.weekly_badge_coming_soon` → "✨ 即將推出"
- 加到 `zh-Hant.lproj/`、`en.lproj/`、`ja.lproj/Localizable.strings`（iOS 慣例為 `zh-Hant` 非 `zh-TW`，Architect 已驗證）

**Done Criteria**：
- [ ] 圓環已刪、不可見
- [ ] Placeholder badge 可見、72×72
- [ ] Intensity bar 為單一水平條
- [ ] 兩按鈕（本週目標 / 訓練日曆）功能不變，sheet 仍能開
- [ ] `WeekTargetDetailViewV2` 一字未動
- [ ] grep `PHASE_B_BADGE` ≥ 2 處
- [ ] grep `PACERIZ REDESIGN 2026-05` ≥ 1 處
- [ ] `xcodebuild clean build` 0 error

### Task A3 — TimelineItemViewV2 視覺加工

**檔案**：`Havital/Features/TrainingPlanV2/Presentation/Views/Components/WeekTimelineViewV2.swift` — **只動 `TimelineItemViewV2` struct（行 62–414）**，其他 struct（DataBadge、PhaseRow、ClimateBadgeView … 等）一字不動。

**互動模型不變**：保留 `isExpanded`、`Button(action: { if !isToday { isExpanded.toggle() }})`、`isToday || isExpanded` 條件展開、sheet binding。

**視覺改動**：
1. **Type accent 左條**：card 內加一條 3px wide / 全 card 高的彩色長條（type color），rest 日不顯示。可用 `.overlay(alignment: .leading)` 加 Rectangle。
2. **Today outline**：將現有 `.overlay(RoundedRectangle().strokeBorder(...))` 線寬從 `1.5` 改 `2.0`、色用 `PacerizColor.blue`。
3. **「課表 / 實際」雙行**（取代或補充現有的 workouts list）：
   - **計畫 row**（always show for 非 rest）：小灰字 `"課表"` label（uppercase, 9pt, tracking 0.4, tertiary）+ 計畫距離 + " · " + 計畫時間，從 `day.primaryRunActivity?.distanceKm` + `durationMinutes/durationSeconds`
   - **實際 row**（when `!workouts.isEmpty`，取 workouts.first）：綠字 `"實際"` label + 實際距離 + " · " + 實際時間
   - 兩 row 字級對等、上下排，不是「綠色刪除線」也不是「替換」
4. **Type chip**：保留現有 `day.type.localizedName` chip 邏輯，色彩沿用既有 `getTypeColor()`。
5. **Chevron**：保留現有 expand/collapse chevron 邏輯（Phase B 會改成 chevron-right + push，Phase A 先不動）。

**Done Criteria**：
- [ ] 今日卡 outline = 2.0pt blue
- [ ] 非 rest 日卡有 3px type accent 左條
- [ ] 已完成日同時顯示「課表 X km · YY:ZZ」（灰）和「實際 X km · YY:ZZ」（綠）兩行
- [ ] 互動行為不變（手動 simulator tap 確認）
- [ ] grep `PACERIZ REDESIGN 2026-05` ≥ 1 處
- [ ] `xcodebuild clean build` 0 error

### Task A3.5 — Design Parity Checklist（給 Developer 自驗 + QA 比對的明細）

**所有數值都來自設計 source-of-truth**：`/tmp/paceriz-design/paceriz-app/project/training-plan.jsx` + `styles.css`。Developer 必須對照寫；QA 必須對照驗。任何「視覺上差不多」不算 PASS。

#### A. PacerizDesignSystem.swift (A0) — 色彩 token

| Token | 設計值 | 來源 |
|---|---|---|
| `PacerizColor.blue` | `#3F86F6` | `--p-blue` |
| `PacerizColor.blueDeep` | `#1E62D0` | `linear-gradient(135deg, #3F86F6 0%, #1E62D0 100%)` 中的 deep stop |
| `PacerizColor.blue12` | `#3F86F6` @ opacity 0.12 | `--p-blue-12` |
| `PacerizColor.green` | `#76C893` | `--p-green` |
| `PacerizColor.greenDeep` | `#4FA070` | styles.css grep (Architect 已驗) |
| `PacerizColor.green12` | adaptive: light=0.14 / dark=0.20 | `--p-green-12` 有 dark mode variant |
| `PacerizColor.orange` | `#FF7F50` | `--p-orange` |
| `PacerizColor.orangeDeep` | `#E5613A` | styles.css grep (Architect 已驗) |
| `PacerizColor.orange12` | adaptive: light=0.14 / dark=0.22 | `--p-orange-12` 有 dark mode variant |
| `PacerizColor.error` | `#F44336` | `--s-error` (Architect 已驗) |

> **⚠️ 重要**：`blue12 / green12 / orange12` 三個 token **不是固定 alpha**。styles.css 為 light/dark 設不同值（light: 0.12/0.14/0.14；dark: 0.22/0.20/0.22）。SwiftUI 實作必須用 `Color(UIColor { trait in ... })` 做 adaptive，**不能**寫死 `.opacity(0.12)`。
>
> **Developer 必須**：寫前 grep `/tmp/paceriz-design/paceriz-app/project/styles.css` 把 `--p-*-deep`、`--p-*-12`、`--s-error` 等實際值看一次（Architect 已驗，這裡是驗收後的值），不要憑感覺。

#### B. PRPlaceholderBadge — 漸層 + 陰影

| 屬性 | 設計值 |
|---|---|
| Size | 72×72 pt |
| Symbol | SF Symbol `rosette`（regular weight）|
| Tint | `LinearGradient(colors: [PacerizColor.blue, PacerizColor.blueDeep], startPoint: .topLeading, endPoint: .bottomTrailing)` |
| Shadow | jsx 對應 `filter: drop-shadow(0 8px 18px rgba(63,134,246,0.30))` → SwiftUI `.shadow(color: PacerizColor.blue.opacity(0.30), radius: 9, x: 0, y: 8)` |

> **註**：SwiftUI `radius` ≈ CSS `stdDeviation`；CSS `drop-shadow(0 8px 18px)` 中 18 是 blur radius，SwiftUI 約取一半（≈ 9）。Developer 寫完用模擬器截圖比對 design canvas，若不夠暈再微調 radius（10/11）。

#### C. PRChip — 各場景樣式

| 場景 | text | fg | bg | fontSize | 來源 |
|---|---|---|---|---|---|
| 第 N/M 週（PhaseStepper） | "第 3 / 12 週" | currentStageColor | currentStageColor @ 0.13 (`${currentColor}22`) | 10pt bold | jsx L56-60 |
| 百分比（VolumeIntensityCard） | "77%" | `PacerizColor.blueDeep` | `PacerizColor.blue12` | 10pt bold | jsx L436-438 |
| ✨ 即將推出（placeholder） | "✨ 即將推出" | **`.white`** | **`PacerizColor.blue`（solid）** | 9pt bold | jsx L410-415（**TPM 校準 2026-05-18：原 spec 寫 blueDeep+blue12 是錯的，設計用 solid blue 飽和 chip + 白字**）|
| Letter-spacing | tracking 0.3pt | — | — | — | jsx `letterSpacing: 0.04` (em) ≈ SwiftUI `.tracking(0.3)` for 10pt |

#### D. VolumeIntensityCard — 卡片本身

| 屬性 | 設計值 |
|---|---|
| Padding | 14pt（jsx `padding: '14px 16px'` → 簡化為 14pt 四向）|
| Corner radius | 14pt (`PacerizRadius.card`) |
| Background（**TPM 校準 2026-05-18**）| `LinearGradient([PacerizColor.blue.opacity(0.06), Color(.tertiarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)` with gradient stops at 0% / 60%（jsx `linear-gradient(135deg, rgba(63,134,246,0.06) 0%, var(--card) 60%)`）— **用戶 explicit 在乎的「漸層暈開」就是這個**。Placeholder 階段一律當 isEarned 開啟此漸層；Phase B 接真實 badge data 後再加 isEarned 條件 |
| Title row（**TPM 校準 2026-05-18**）| **完全不要**！設計沒有「週跑量和訓練強度」title 整行 — 卡片直接從 badge hero row 開始。Date chip 放在 badge name row 右端，不是另開 title row |
| Card shadow | `.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)`（沿用原有）|
| Hero row spacing | HStack(spacing: 14)（jsx `gap-3` ≈ 12-14pt）|
| Hero row alignment | `.top`（徽章與右側 VStack 頂端對齊）|
| Distance number font | `.system(size: 22, weight: .bold, design: .rounded)`（jsx `mono` `fontSize: 22 fontWeight: 800 letterSpacing: -0.03 lineHeight: 1`）|
| "/ 30 km" font | `.system(size: 11, weight: .semibold)` 灰色 |
| Intensity bar height | 8pt |
| Intensity bar background | `Color(.systemGray5)` 或 `Color.black.opacity(0.06)`（jsx `rgba(0,0,0,0.06)`）|
| Intensity bar corner radius | 4pt（height/2）|
| Dot legend dot | 6×6 pt, corner radius 1.5pt（jsx `border-radius: 1.5px`）|
| Dot legend label | 10pt semibold secondary |
| Dot legend HStack spacing | 12pt |
| Divider | 原生 SwiftUI `Divider()` |

#### E. VolumeIntensityCard — Action button row

| 屬性 | 設計值 |
|---|---|
| Height | 34pt（jsx `height: 34px`）|
| Background（本週目標）| `PacerizColor.blue12` |
| Background（訓練日曆）| `PacerizColor.green12` |
| Icon size | 12pt bold |
| Icon color | `PacerizColor.blue` / `PacerizColor.greenDeep` |
| Label font | 12pt bold primary |
| Chevron-right | 10pt semibold secondary |
| HStack spacing | 6pt |
| Padding horizontal | 12pt |
| Inter-button spacing | 8pt |
| Corner radius | 10pt (`PacerizRadius.inner`) |

#### F. TrainingProgressCardV2 (A1) — header row

| 屬性 | 設計值 |
|---|---|
| Trend icon | `chart.line.uptrend.xyaxis`, 14pt semibold, 顏色 = currentStageColor |
| Stage name | 14pt bold primary |
| Week chip | 見 §C 第一行 |
| Chevron-right | 11pt semibold secondary |
| HStack spacing | 8pt |
| Card padding | 沿用既有 `.padding()`（系統預設 16pt）|

#### G. TimelineItemViewV2 (A3) — 卡片視覺加工

| 屬性 | 設計值 |
|---|---|
| Type accent 左條 | width 3pt, color = `getTypeColor()`, 從 card top+8 到 bottom-8（jsx `top: 8, bottom: 8`），corner radius 2pt, `.overlay(alignment: .leading)` |
| Type accent 不顯示條件 | `day.type == .rest` |
| Today outline | `.strokeBorder(PacerizColor.blue, lineWidth: 2.0)` |
| 課表 label | text "課表", 9pt bold, tracking 0.4pt, color `.secondary` (tertiary 系統色), uppercase, minWidth 28pt |
| 計畫 row 數字 | 11.5pt semibold secondary（jsx `fontSize: 11.5 fontWeight: 600`）|
| 實際 label | text "實際", 9pt bold, tracking 0.4pt, color `PacerizColor.greenDeep`, uppercase, minWidth 28pt |
| 實際 row 數字 | 12pt bold primary（jsx `fontSize: 12 fontWeight: 700`）|
| 兩 row 間距 | VStack(spacing: 4) |

> **Developer 必須**：實作完每個 sub-task 都跑模擬器截圖一張，自己對照本 checklist 逐項確認；任何偏差先修再交付。

---

### Task A4 — QA 驗收

**負責 agent**：QA

**驗收項目**：

1. **Build**：`xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,id=BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4' -parallel-testing-enabled NO` → 0 error
2. **取得 design canvas 截圖（reference image）**：
   - 用 Chrome 開 `file:///tmp/paceriz-design/paceriz-app/project/Paceriz Redesign.html`
   - 用 mcp__claude-in-chrome MCP（或截圖工具）擷取 artboard `01 · 今日訓練 · 目標賽事`、`02 · 新手訓練模式`、`03 · 維持訓練模式` 三張全螢幕截圖
   - 存到 `/tmp/parity/design_01.png` ~ `/tmp/parity/design_03.png`
3. **取得模擬器截圖（actual image）**：
   - iPhone 17 Pro / iOS 26.4
   - 跑 `logout-and-demo-login.yaml`，登入測試帳號
   - 截圖：訓練計畫主畫面 zh-TW + 英文兩語言版本
   - 存到 `/tmp/parity/actual_zh.png`、`/tmp/parity/actual_en.png`
4. **逐項 design parity 比對**：
   - **必須**逐項對照 §3.5 Parity Checklist A-G 全部 checklist；每個 row 標 PASS / FAIL，FAIL 要寫差在哪（如「badge shadow 比設計弱，幾乎看不到」「week chip 字級太大」）
   - 把 design + actual 兩張圖左右排截一張對比圖，存 `/tmp/parity/side_by_side.png`
   - 任何「漸層、陰影、玻璃感、配色飽和度」差異一律記為 FAIL，**不要**用「看起來差不多」放水
5. **互動 smoke test**（在模擬器直接點，全部 PASS 才算通過）：
   - Tap 訓練進度卡 → 應開 TrainingProgressViewV2 sheet
   - Tap 本週目標按鈕 → 應開 WeekTargetDetailViewV2 sheet
   - Tap 訓練日曆按鈕 → 應開 TrainingCalendarView sheet
   - Tap 任一非今日卡 → 應 toggle expand
   - Tap 訓練類型 chip → 應開 TrainingTypeInfoView sheet
6. **Dark mode 截圖**：模擬器 dark mode 截一張主畫面，檢查 placeholder badge / chip / intensity bar 在 dark 下對比度可讀
7. **i18n smoke test**：切英文回主畫面截圖。chip 文字是否破版（不要求完美 i18n，只要求不爆畫面）
8. **Regression**：若 `.maestro/flows/` 有 training-plan 相關 flow，至少跑一條確認不破

**QA 輸出格式**（依 `.claude/rules/testing.md` 強化版）：

```
=== Build ===
✅ / ❌ xcodebuild clean build

=== Design Parity (AC-TPV2-A-09) ===
A. PacerizColor tokens:     [PASS / FAIL: list deviations]
B. PRPlaceholderBadge:      [PASS / FAIL: ...]
C. PRChip (各場景):         [PASS / FAIL: ...]
D. VolumeIntensityCard 卡片: [PASS / FAIL: ...]
E. Action button row:        [PASS / FAIL: ...]
F. TrainingProgressCardV2:   [PASS / FAIL: ...]
G. TimelineItemViewV2:       [PASS / FAIL: ...]

=== Screenshots ===
- /tmp/parity/design_01.png        (Chrome canvas, race mode)
- /tmp/parity/design_02.png        (Chrome canvas, starter mode)
- /tmp/parity/design_03.png        (Chrome canvas, maintain mode)
- /tmp/parity/actual_zh.png        (simulator, zh-TW)
- /tmp/parity/actual_en.png        (simulator, en)
- /tmp/parity/actual_dark.png      (simulator, dark mode)
- /tmp/parity/side_by_side.png     (comparison)

=== Interaction smoke ===
[5 個 tap test PASS / FAIL]

=== AC-by-AC verdict ===
AC-TPV2-A-01: PASS / FAIL (evidence: ...)
AC-TPV2-A-02: ...
... A-09

=== Verdict ===
✅ PASS / ❌ FAIL（要列出所有 FAIL 的 fix-it list）

FAIL classification（每條 FAIL 必須三選一）:
- app bug   → Developer 修
- script bug → QA 修
- environment issue → fix env then retry
```

**禁止**：
- ❌ 沒做完 §3.5 全 checklist 就回 PASS
- ❌ 「視覺上差不多」「應該沒問題」這種模糊敘述
- ❌ 沒附 design canvas 截圖就 sign-off
- ❌ 沒做 side-by-side 對比就說 parity OK

---

## 4. Cross-Repo Impact

| Repo | Impact |
|---|---|
| iOS (`apps/ios/Havital`) | 3 改動檔 + 1 新增檔 + 3 個 .strings 加 i18n key |
| Android | 無 |
| Backend (`cloud/api_service`) | 無 |

---

## 5. Risk Assessment

### 5.1 不確定技術點

- **Dynamic Type 衝擊**：固定字級若用戶開很大 Dynamic Type 可能 truncation。Phase A 範圍內接受此風險，Phase B 再評估。
- **Dark mode 對比度**：`Color(UIColor.tertiarySystemBackground)` + `PacerizColor.*12` 在 dark 下對比度未測。QA 需 dark mode 截圖。

### 5.2 替代方案

- **A0 拆成更細的 token files** vs **單檔包所有**：選單檔（複雜度小、後續 search/maintain 簡單）。Phase B 若資料增多再拆。
- **Intensity bar 單位用 km vs minutes**：選 minutes（iOS ViewModel 原本就提供，零轉換）。Bar 視覺只需相對比例，單位不影響。

### 5.3 需用戶確認的決策

- ✅ 已確認：徽章用 placeholder（用戶 OK）
- ✅ 已確認：分 Phase A / B 分階段做（用戶 OK）
- ✅ 已確認：互動模型 Phase A 不動，Phase B 再改（用戶 OK）

### 5.4 最壞情況與修正成本

- **Build 過但模擬器 crash**：rollback 用 git checkout，~5 分鐘。
- **某個 sub-task 偏離設計**：Architect 退回 Developer 重做該 sub-task，~半天。
- **設計 token 漏覆蓋（A0 不完整）**：A1/A2/A3 動工時發現缺，回頭補 A0，~1 小時。

---

## 6. Dispatch Plan

TPM 將以本 TD 作為 dispatch 內容 handoff 給 **iOS Architect subagent**。

Architect 職責：
1. 讀本 TD 全文 + 已標示的 iOS 源檔（路徑都在 §1.1）
2. 將 A0、A1、A2、A3 dispatch 給 iOS Developer subagent（可串行或並行；A0 必須最先完成）
3. Developer 交付每個 task 後，Architect 自己跑 `xcodebuild` 驗 build pass
4. 全部完成後，dispatch QA 跑 A4 驗收
5. 將 QA Verdict + 截圖 + 改動檔清單回報 TPM

**Architect 不得擅自擴大 scope**：
- 不動 ViewModel / Repository / Mapper
- 不動 `WeekTargetDetailViewV2`、`TrainingProgressViewV2`、`TrainingCalendarView`、`WeekTimelineViewV2` 內除 `TimelineItemViewV2` 以外的任何 struct
- 不改 V1 (`Havital/Views/Training/TrainingPlanView.swift`)
- 不順手清 dead code（rollback 風險）
- 不 commit（TPM 驗收後由用戶決定）

---

## 6.5. Out-of-Scope / 已記錄為 Phase B 候選

以下視覺差異 QA Round 3 截圖逐項比對時發現，但**超出 Phase A scope**（A3 明訂「只動 TimelineItemViewV2 struct，其他 struct 一字不動」），記錄供 Phase B 處理：

| 項目 | 設計 | 實際 | 處置 |
|---|---|---|---|
| **「📅 每日訓練」section header** | 設計只有「每日訓練」純文字、無 icon prefix、字級較大（17pt+）| 實際有 `📅` calendar icon prefix、字級較小 | Phase B：改 `WeekTimelineViewV2` main wrapper 移除 icon、放大字級 |
| **Today card 內部 segments 渲染樣式** | 設計用圓角灰底 pill 包每個 segment（暖身/節奏/緩和）+ accent 細條 | 實際走既有 `TrainingDetailsViewV2` 渲染 | Phase B：要不要把 TrainingDetailsViewV2 也重做、或開新 segment renderer，需另開 TD |

## 7. Phase B Preview (not in this TD)

僅供 context，不在本次 dispatch 內：
- Race header（倒數 + 預估 vs 目標 + 適能）
- Starter / Maintain mode header
- 徽章資料層（BadgeRepository）+ VolumeIntensityCard 真實徽章接入
- DayCard 互動：未來日 tap 改 push WorkoutDetailViewV2

Phase B 將在 Phase A 驗收通過後另開 TD。
