---
type: SPEC
id: SPEC-vdot-naming-and-workout-row-redesign
status: Under Review
l2_entity: 跑步科學指標
created: 2026-04-28
updated: 2026-04-28 (v3: 全 7 開放問題收斂，僅留 1 項 Architect-scope + 1 項跨團隊確認)
---

# Feature Spec: VDOT 命名統一與訓練紀錄卡片重設

## 背景與動機

App 上對「VDOT / 跑力」這個指標的用語不一致，i18n strings 中至少存在 6 種變體：

- 動態跑力（`workout.detail.dynamic_vdot`, `performance.vdot.dynamic_vdot`）
- VDOT（`performance.vdot_trend`）
- 動態跑力 (VDOT)（`performance.vdot.vdot_title`）
- 跑力（`performance.chart.vdot_value`）
- 加權跑力（`performance.vdot.weighted_vdot`）
- 最新跑力（`performance.vdot.latest_vdot`）

兩個核心問題：

1. **品牌混淆風險**：「跑力」是徐國峰 RQ（runningquotient）服務的品牌詞，台灣跑者看到「跑力」會聯想到 RQ。Paceriz 直接用「跑力」當主名會被誤認為抄 RQ。
2. **用語層級不清**：「動態跑力」「加權跑力」「最新跑力」並列，用戶無法辨識「哪個才是我該關注的主要數字」。

同時，訓練紀錄頁的 list 卡片（`WorkoutSummaryRow.swift`）目前以「動態跑力：38.5」當主秀，但缺少日期、訓練類型、資料來源等基本資訊，掃讀效率低，與市場主流跑步 app（Strava、Nike Run Club）的訓練紀錄列表體驗有落差。

## 目標用戶

- **主要**：所有 Paceriz 跑者（zh-Hant / ja-JP / en-US 三語），尤其關注訓練數據的進階跑者
- **場景 A**：跑後打開訓練紀錄列表，掃過去看「我這幾次跑得怎樣」
- **場景 B**：點進主畫面或訓練準備度卡片，看到 VDOT 數字想知道「我目前的有氧能力如何 / 距離目標賽事還多遠」

## Spec 相容性

已比對的既有 SPEC（grep `vdot|跑力|race.fitness|比賽適能`）：

- `SPEC-performance-insights-dashboard.md`
- `SPEC-heart-rate-and-training-readiness-surfaces.md`
- `SPEC-monthly-stats-and-calendar-performance-surfaces.md`

**結果**：上述 spec 文件本身未直接提及 VDOT / 跑力命名（grep 無匹配）。但這些 spec 對應的 UI 頁面實際會顯示 VDOT 數字，本 SPEC 的命名統一變更會穿透這些頁面。Architect 階段需逐頁 audit layout 不破壞。

**衝突**：無語意衝突。本 SPEC 為命名與顯示層調整，不改演算法、不改數據結構。

## 需求

### P0（必須有）

#### 需求 1：VDOT 命名體系統一（i18n 三語）

**描述**：建立統一命名體系，「VDOT」成為主名（對標 Daniels VDOT，加權平均得到的穩定值），「動態跑力 / Live VDOT / ライブ VDOT」為副名（單次跑後即時計算的瞬時值）。所有「加權跑力」「最新跑力」「跑力（chart 軸）」等變體全部收掉。

**最終命名表**：

| 場景 | zh-Hant | en-US | ja-JP |
|---|---|---|---|
| 主名（穩定值，加權平均） | VDOT | VDOT | VDOT |
| 副名（單次跑後瞬時值） | 動態跑力 | Live VDOT | ライブ VDOT |
| 主名說明全稱 | VDOT（有氧能力指標） | VDOT (Aerobic Capacity) | VDOT（有酸素能力指標） |
| 圖表軸標題 | VDOT | VDOT | VDOT |

**Acceptance Criteria**：

- `AC-VDOT-NAME-01`：Given 用戶開啟訓練準備度卡片或 VDOT 詳細頁，When 顯示加權平均後的穩定值，Then 該數值的 label 一律顯示為「VDOT」（zh-Hant / en-US / ja-JP 三語一致）
- `AC-VDOT-NAME-02`：Given 用戶開啟單次訓練紀錄細節，When 顯示該次跑步即時計算的瞬時值，Then label 顯示為 zh-Hant「動態跑力」/ en-US「Live VDOT」/ ja-JP「ライブ VDOT」
- `AC-VDOT-NAME-03`：Given 用戶開啟 VDOT 趨勢圖，When 圖表 y 軸與標題渲染，Then 一律使用「VDOT」（不可出現「跑力」「加權跑力」字樣）
- `AC-VDOT-NAME-04`：Given 用戶開啟「什麼是 VDOT？」說明頁，When 閱讀說明文字，Then 文字明確說明「VDOT 由 Jack Daniels 博士提出，是國際通用的有氧能力指標」並描述「VDOT」與「動態跑力」的關係（穩定值 vs 瞬時值）；**不得提及「徐國峰」「跑力」「RQ」「runningquotient」等競品/品牌名**
- `AC-VDOT-NAME-04b`：Given 用戶在 VDOT 說明頁底部，When 渲染頁面，Then 必須顯示「閱讀更多 / Learn more / 詳しく見る」連結，點擊後開啟官網文章 `https://paceriz.com/blog/dynamic_vdot.html`（zh-Hant；en-US / ja-JP 對應連結若官網有翻譯版本則切換語系，否則統一連回 zh-Hant 版）
- `AC-VDOT-NAME-05`：Given grep 整個 codebase 的中文 strings，When 搜尋「加權跑力」「最新跑力」「平均加權跑力」「最新動態跑力」「跑力」（單獨出現作為標題的情況），Then 應全數消失或僅以 deprecated key 形式存在但不再 reference
- `AC-VDOT-NAME-06`：Given i18n strings 三檔（zh-Hant / en-US / ja-JP），When 比對任一 VDOT 相關 key，Then 三檔都必須有對應翻譯，不可缺漏

#### 需求 2：訓練紀錄 list 卡片重新設計

**描述**：重新設計 `WorkoutSummaryRow.swift`，主秀資訊改為「日期 + 距離 + 配速」，其餘資訊（時長、動態跑力、訓練類型、資料來源 badge）以副資訊呈現。視覺風格對標 Strava / Nike Run Club 的訓練紀錄列表。

**卡片必須呈現的資訊**：

- 日期 / 相對時間（今天、昨天、N 天前 + 時間）
- 距離
- 配速
- 時長
- 動態跑力（數值 + 適當的視覺權重；僅在跑步紀錄且有計算出時顯示，否則整行隱藏）
- 訓練類型（沿用既有 `training.type.*` 字典：輕鬆跑 / 節奏跑 / 間歇訓練 / 長距離跑 / 恢復跑 / 比賽 / 法特雷克 / 爬坡訓練 / 速度訓練 / 長距離輕鬆跑；**未對應到 V2 課表時不顯示**，不引入「自由跑」「未分類」等替代詞）
- 資料來源 badge（Apple Health / Garmin Connect™；Garmin 必須包含 ™ trademark 符號，依 Garmin 官方品牌規範）

**Acceptance Criteria**：

- `AC-VDOT-NAME-07`：Given 用戶開啟訓練紀錄列表，When 載入一則紀錄，Then 卡片必須顯示日期/相對時間（例：「今天 18:30」「3 天前」）
- `AC-VDOT-NAME-08`：Given 卡片渲染主秀資訊，When 用戶掃讀，Then 距離與配速以最大視覺權重呈現（字級最大、位置最顯眼），時長為次級資訊
- `AC-VDOT-NAME-09`：Given 卡片載入**跑步紀錄**，When 該紀錄有計算出動態跑力，Then 卡片需顯示「動態跑力 38.5」（zh-Hant）/「Live VDOT 38.5」（en-US）/「ライブ VDOT 38.5」（ja-JP）
- `AC-VDOT-NAME-09b`：Given 卡片載入非跑步紀錄（騎車、游泳、健行等）**或**跑步紀錄但動態跑力未能計算（HR 缺失等），When 渲染卡片，Then **不顯示**動態跑力 row（不可顯示「動態跑力：--」之類 placeholder）
- `AC-VDOT-NAME-10`：Given 卡片載入跑步紀錄，When 該紀錄對應到 V2 課表中具有 `training_type` 欄位的 workout，Then 卡片必須顯示對應的訓練類型 tag（使用既有 `training.type.*` strings 字典翻譯）
- `AC-VDOT-NAME-10b`：Given 跑步紀錄未對應到任何 V2 課表 workout（隨意跑、舊資料等），When 渲染卡片，Then **不顯示訓練類型 tag**（不顯示「自由跑」「未分類」「Free Run」等替代詞）
- `AC-VDOT-NAME-11`：Given 跑步紀錄來自 Garmin Connect，When 渲染卡片，Then 卡片必須顯示「Garmin Connect™」badge，**包含 ™ trademark 符號**（依 Garmin 官方品牌規範強制要求；不可省略 ™）
- `AC-VDOT-NAME-12`：Given 紀錄來自 Apple Health（iPhone / Apple Watch），When 渲染卡片，Then 卡片必須顯示對應的「Apple Health」badge
- `AC-VDOT-NAME-13`：Given 多筆紀錄並列（不同資料來源混合），When 用戶滑動列表，Then 所有資料來源 badge 樣式一致、位置一致、可掃讀辨識
- `AC-VDOT-NAME-13b`：Given 未來新增第三方資料來源（Strava / Coros / Polar 等），When 在卡片上呈現 badge，Then **不得需要重寫 badge component**——badge UI 必須以可擴展方式設計（如 enum/mapping table 驅動），新增來源僅需追加 logo asset + 字串對應即可
- `AC-VDOT-NAME-14`：Given 卡片在 zh-Hant / en-US / ja-JP 三語環境下渲染，When 載入相同紀錄，Then 顯示資訊（日期格式、單位、訓練類型 tag、副 label）必須對應該語系正確翻譯

### P1（應該有）

#### 需求 3：VDOT 主畫面 layout 簡化

**描述**：主畫面 / 訓練準備度卡片只露出「VDOT」一個主數字（不再同時顯示動態跑力與加權跑力兩個值）。「動態跑力」副資訊降位至「VDOT 詳細頁」與「單次訓練紀錄」兩個 context 才顯示。

**Acceptance Criteria**：

- `AC-VDOT-NAME-15`：Given 用戶在主畫面或訓練準備度卡片，When 該位置原同時顯示「動態跑力」+「加權跑力」兩個數字，Then 改為只顯示「VDOT」一個主數字
- `AC-VDOT-NAME-16`：Given 用戶點進「VDOT 詳細頁」，When 頁面渲染，Then 主數字仍是「VDOT」，並可看到「動態跑力（最新一次）」與「VDOT 趨勢圖」作為副資訊

### P2（可以有）

#### 需求 4：清理 dead code

**描述**：`Havital/Views/Components/WorkoutRowView.swift` 經 grep 確認無任何 import / 引用，建議刪除以避免未來誤用為 list 卡片。

**Acceptance Criteria**：

- `AC-VDOT-NAME-17`：Given codebase 經整理，When grep 搜尋「WorkoutRowView」，Then 應無任何 reference OR 該檔案已刪除

## 明確不包含

- **不改 VDOT 演算法**：`weighted_vdot` 與 `dynamic_vdot` 計算邏輯維持不變
- **不改 Firestore schema**：數據結構不動
- **不改 race_fitness（比賽適能）命名**：這是另一個獨立指標，不在本 SPEC 範圍
- **不引入新的訓練類型分類邏輯**：用既有的 workout type / methodology 對應，不重新設計
- **不改 WorkoutRowView 內容**：已是 dead code，P2 才考慮刪除
- **不動 ja-JP 中除「動態跑力」以外的「跑力」相關翻譯**：日文版本全部以 VDOT / ライブ VDOT 為主，不引入「走力」（そうりょく）等新詞

## 技術約束（給 Architect 參考）

- **i18n strings 檔案**：`Havital/Resources/{zh-Hant,ja,en}.lproj/Localizable.strings`
- **LocalizationKeys**：`Havital/Utils/LocalizationKeys.swift` 內 `Performance.VDOT.*` 系列 key
- **資料來源偵測**：已有 `HKWorkout.sourceRevision.source.name` 機制（見 `Havital/Core/Infrastructure/HealthKitManager.swift:718, 1294`）；翻譯字串已存在於 `LocalizationKeys.swift:441-455`（`datasource.apple_health` / `datasource.garmin_connect`）—— 直接複用即可，不需新建
- **依賴 entity**：跑步科學指標（L2，ZenOS id `f1feaf74326c40c38abcf71cb0b8d3e5`）
- **影響檔案範圍**（從 grep `動態跑力|VDOT|跑力` 得出，Architect 需 audit 完整名單）：
  - `Havital/Resources/{zh-Hant,ja,en}.lproj/Localizable.strings`（i18n 三檔）
  - `Havital/Utils/LocalizationKeys.swift`
  - `Havital/Models/{VDOTModels.swift, VDOTCalculator.swift, WorkoutSummary.swift, WorkoutV2Models.swift, UserPreference.swift}`
  - `Havital/Views/Training/WorkoutSummaryRow.swift`（**重設目標**）
  - `Havital/Views/Components/VDOTChartView.swift`
  - `Havital/Views/Components/WorkoutRowView.swift`（dead code）
  - `Havital/Features/UserProfile/Domain/UseCases/VDOTManager.swift`
  - `Havital/Features/UserProfile/Presentation/ViewModels/UserProfileFeatureViewModel.swift`
  - `Havital/Features/UserProfile/Data/{DataSources/UserPreferencesLocalDataSource.swift, Repositories/UserPreferencesRepositoryImpl.swift}`
  - `Havital/Features/UserProfile/Domain/Repositories/UserPreferencesRepository.swift`
  - `Havital/Features/TrainingPlan/Infrastructure/VDOTService.swift`
  - `Havital/Features/TrainingPlan/Presentation/ViewModels/{TrainingPlanViewModel, EditScheduleViewModel, VDOTChartViewModel}.swift`
  - `Havital/Features/TrainingPlanV2/Data/{DTOs/WeeklySummaryV2DTO.swift, Mappers/WeeklySummaryV2Mapper.swift}`
  - `Havital/Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift`
  - `Havital/Features/TrainingPlanV2/Presentation/ViewModels/EditScheduleV2ViewModel.swift`
  - `Havital/Features/TrainingPlanV2/Presentation/Views/{EditScheduleViewV2.swift, Components/WeekTimelineViewV2.swift}`
  - `Havital/Features/Workout/Presentation/ViewModels/WorkoutListViewModel.swift`
  - `Havital/Storage/VDOTStorage.swift`
  - `Havital/Legacy/UserPreferencesManager.swift`
  - `Havital/Utils/{PaceFormatterHelper.swift, PaceCalculator.swift, PaceCalculationHelper.swift, CacheEventBus.swift}`

## 已決議（PM 階段確認）

- **Garmin badge trademark**：必須包含 ™ 符號（Garmin 官方品牌規範強制要求）—— 已固化為 AC-VDOT-NAME-11
- **訓練類型 tag 來源**：沿用 V2 課表的 `training_type` 欄位 + 既有 `training.type.*` strings 字典，不重新設計
- **未對應到課表的跑步**：直接不顯示訓練類型 tag，**不引入「自由跑」「未分類」等替代詞**（codebase 無此概念）—— 已固化為 AC-VDOT-NAME-10b
- **動態跑力缺失情境**：非跑步紀錄、或跑步但無 dynamic VDOT 結果，**整行隱藏**，不顯示「動態跑力：--」placeholder —— 已固化為 AC-VDOT-NAME-09b
- **資料來源 badge 可擴展**：badge UI 必須以可擴展方式設計，未來新增 Strava / Coros / Polar 等來源僅需追加 asset 與字串對應 —— 已固化為 AC-VDOT-NAME-13b
- **VDOT 說明頁不提徐國峰跑力**：徹底切開，說明頁不得出現「徐國峰」「跑力」「RQ」「runningquotient」等品牌詞 —— 已固化為 AC-VDOT-NAME-04
- **VDOT 說明頁連結官網文章**：底部加「閱讀更多」連結至 `https://paceriz.com/blog/dynamic_vdot.html` —— 已固化為 AC-VDOT-NAME-04b

## 開放問題

1. **P1 影響範圍 audit**：主畫面 layout 簡化（只露 VDOT 一個數字）的完整影響清單，Architect 需逐頁列出哪些 view 顯示 VDOT/動態跑力雙數字，並評估是否全部簡化或留例外（**此問題 PM 不解，劃給 Architect**）
2. **官網 blog 多語版本確認**：`paceriz.com/blog/dynamic_vdot.html` 目前是 zh-Hant 版，en-US / ja-JP 版本是否存在？若無，AC-04b 暫定三語都連回 zh-Hant 版，Architect 階段 reconfirm（屬於跨團隊協調，非 iOS 內可決定）
