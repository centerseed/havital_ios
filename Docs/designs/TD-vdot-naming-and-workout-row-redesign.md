---
type: TD
id: TD-vdot-naming-and-workout-row-redesign
spec: SPEC-vdot-naming-and-workout-row-redesign
status: Draft
ontology_entity: 跑步科學指標
created: 2026-04-28
updated: 2026-04-28
---

# 技術設計：VDOT 命名統一與訓練紀錄卡片重設

## 調查報告

### 已讀文件（附具體發現）

- `docs/specs/SPEC-vdot-naming-and-workout-row-redesign.md`（v3 全文）— 18 條 P0 AC，2 條 P1，1 條 P2
- `Havital/Views/Training/WorkoutSummaryRow.swift` — **dead code（zero callers）**，SPEC 鎖錯目標檔
- `Havital/Views/Training/TrainingRecordView.swift:63` — 訓練紀錄頁，render 的是 `WorkoutV2RowView`（非 SPEC 指定的 `WorkoutSummaryRow`）
- `Havital/Views/Components/WorkoutV2RowView.swift`（**真正的 list 卡片**）— 已實作 70% SPEC 需求：
  - line 19-37：運動類型 · 訓練類型已實作（AC-10, AC-10b）
  - line 41-56：VDOT 顯示（label 是 `"VDOT %.1f"`）
  - line 42 `if let dynamicVdot`：整行隱藏邏輯已實作（AC-09b）
  - line 60-105：主秀資訊是「距離 / 時間 / 卡路里」（缺配速）
  - line 113-116：日期格式 `yyyy/MM/dd HH:mm`（非相對時間）
  - line 135-162：attribution badge 已是可擴展設計（Strava/Garmin component 分離）（AC-13b）
- `Havital/Views/Training/WorkoutDetailViewV2.swift` — 單次紀錄詳細頁，**目前完全沒有 VDOT 顯示** → 用戶要求新增動態跑力副名顯示
- `Havital/Views/Components/VDOTChartView.swift` — VDOT 詳細頁 / 趨勢圖：line 122/238 仍用「加權跑力」、line 244 用「最新跑力」；說明頁尚無官網連結
- `Havital/Features/UserProfile/Presentation/ViewModels/UserProfileFeatureViewModel.swift:222` — 訓練準備度 `currentVDOT = latestDynamicVdot`，**已是單一數字**，AC-15（P1）大部分已滿足，只需 label audit
- `Havital/Resources/{en,ja}.lproj/Localizable.strings` — 三語 VDOT strings 完整，副名翻譯需重寫：
  - en: `Dynamic VDOT` / `Weighted VDOT` / `Latest VDOT` → `Live VDOT` / `VDOT` / `VDOT`
  - ja: `ダイナミックVDOT` / `加重VDOT` / `最新VDOT` → `ライブ VDOT` / `VDOT` / `VDOT`
- `Havital/Views/UserProfileView.swift:1465` — Garmin badge label hardcode `"Garmin Connect™"`，已含 ™（部分 AC-11 滿足）。`GarminAttributionView` component 需 audit 確認所有 callsites 顯示 ™
- `Havital/Resources/zh-Hant.lproj/Localizable.strings` 已存在完整訓練類型字典（line 380-394）

### 搜尋但未找到

- `docs/designs/TD-*vdot*` → 無
- `docs/decisions/ADR-*vdot*` → 無
- `WorkoutSummaryRow(` instantiation → 無（dead code 確認）

### 我不確定的事

- ⚠️ AC-08 是否砍掉「卡路里」欄位以容納「配速」？卡片寬度有限，主秀只能放 3 欄左右
- ⚠️ WorkoutDetailViewV2 新增「動態跑力」要放哪個 section？候選：頂部 summary、heart rate 旁、advanced metrics 內
- ⚠️ 官網 blog `paceriz.com/blog/dynamic_vdot.html` 的 en/ja 版本是否存在（跨團隊事項，spec 開放問題）

### 結論

可以開始設計，但 Phase 1.5 用戶確認 gate 必須先解 2 個未決點（卡路里 vs 配速、DetailView 動態跑力位置）。

---

## AC Compliance Matrix（含 PM SPEC 18 條 + Architect 新增 1 條 = 19 條）

| AC ID | 描述 | 實作位置 | Test Function | 狀態 |
|---|---|---|---|---|
| AC-VDOT-NAME-01 | 主名 VDOT 三語 label 一致 | `*.strings` / `VDOTChartView.swift:238` / `UserProfileFeatureViewModel.swift:222` | `test_ac_vdot_name_01_main_label_consistent` | STUB |
| AC-VDOT-NAME-02 | 副名 zh=動態跑力/en=Live VDOT/ja=ライブ VDOT | `*.strings` / `WorkoutDetailViewV2`（新）| `test_ac_vdot_name_02_subname_per_locale` | STUB |
| AC-VDOT-NAME-03 | 圖表軸/標題用 VDOT | `VDOTChartView.swift:160-176, 238` | `test_ac_vdot_name_03_chart_axis` | STUB |
| AC-VDOT-NAME-04 | 說明頁不提徐國峰/RQ | `*.strings vdot_description` | `test_ac_vdot_name_04_no_competitor_mention` | STUB |
| AC-VDOT-NAME-04b | 說明頁底部官網連結 | `VDOTChartView.swift` 說明頁 sheet | `test_ac_vdot_name_04b_blog_link_present` | STUB |
| AC-VDOT-NAME-05 | 中文 strings 無「加權跑力/最新跑力/跑力」殘留 | `zh-Hant.lproj/Localizable.strings` | `test_ac_vdot_name_05_no_legacy_terms_zh` | STUB |
| AC-VDOT-NAME-06 | i18n 三檔對齊 | 三檔 strings | `test_ac_vdot_name_06_keys_aligned` | STUB |
| AC-VDOT-NAME-07 | 卡片顯示日期/相對時間 | `WorkoutV2RowView.swift:113-116, 164-168` | `test_ac_vdot_name_07_relative_date` | STUB |
| AC-VDOT-NAME-08 | 距離+配速為主秀 | `WorkoutV2RowView.swift:60-105` | `test_ac_vdot_name_08_pace_in_primary` | STUB |
| AC-VDOT-NAME-09 | 跑步且有 VDOT 顯示 (PIVOT: 卡片用 VDOT 主名 / DetailView 用副名) | `WorkoutV2RowView.swift:47` (主名 OK) / `WorkoutDetailViewV2.swift`（副名新）| `test_ac_vdot_name_09_show_when_running` | STUB |
| AC-VDOT-NAME-09b | 非跑步或無 VDOT → 整行隱藏 | `WorkoutV2RowView.swift:42` | `test_ac_vdot_name_09b_hide_when_no_vdot` | **已實作** |
| AC-VDOT-NAME-10 | V2 對應 → 訓練類型 tag | `WorkoutV2RowView.swift:30-37` | `test_ac_vdot_name_10_show_training_type` | **已實作** |
| AC-VDOT-NAME-10b | 未對應 → 不顯示 tag | `WorkoutV2RowView.swift:30 if let trainingType` | `test_ac_vdot_name_10b_hide_training_type` | **已實作** |
| AC-VDOT-NAME-11 | Garmin badge 含 ™ | `GarminAttributionView` / 各 callsite | `test_ac_vdot_name_11_garmin_trademark` | STUB |
| AC-VDOT-NAME-12 | Apple Health badge | `WorkoutV2RowView.swift:135-162` | `test_ac_vdot_name_12_apple_health_badge` | STUB |
| AC-VDOT-NAME-13 | 多筆 badge 樣式一致 | attribution component | `test_ac_vdot_name_13_badge_style_consistent` | STUB |
| AC-VDOT-NAME-13b | Badge 可擴展設計 | attribution component 分離 | `test_ac_vdot_name_13b_extensible_design` | **已實作** |
| AC-VDOT-NAME-14 | 三語環境下卡片資訊正確 | dependent on AC-01,02,06 | `test_ac_vdot_name_14_locale_rendering` | STUB |
| AC-VDOT-NAME-15 (P1) | 主畫面 VDOT 單一主數字 | `UserProfileFeatureViewModel:222` | `test_ac_vdot_name_15_single_main_number` | **已實作（label 待確認）** |
| AC-VDOT-NAME-16 (P1) | 詳細頁主數字 VDOT，副資訊動態跑力與趨勢圖 | `VDOTChartView.swift:238, 244` | `test_ac_vdot_name_16_detail_page_layout` | STUB |
| AC-VDOT-NAME-17 (P2) | 清理 dead code WorkoutSummaryRow + WorkoutRowView | 2 個 .swift 檔 | `test_ac_vdot_name_17_dead_code_removed` | STUB |
| **AC-VDOT-NAME-18 (NEW)** | WorkoutDetailViewV2 新增動態跑力副名顯示 | `WorkoutDetailViewV2.swift`（新 section）| `test_ac_vdot_name_18_detail_dynamic_vdot` | STUB |

**AC 統計（v4 修訂）**：P0 = 17 (16 + 1 NEW) / P1 = 2 / P2 = 1，共 20 條。已實作 5 條（AC-09b, 10, 10b, 13b, 15 部分）。

---

## Component 架構

```
┌─────────────────────────────────────────────────────────────┐
│ TrainingRecordView (entry to workout list)                  │
│   ├── List → ForEach(workouts)                              │
│   │     └── WorkoutV2RowView ★ (修改：補配速、相對時間、    │
│   │                              Apple Health badge、Garmin ™ audit)
│   └── .sheet → WorkoutDetailViewV2 ★ (新增：動態跑力 row)   │
├─────────────────────────────────────────────────────────────┤
│ UserProfileView (主畫面 / 訓練準備度)                        │
│   └── currentVDOT (label 確認 = "VDOT")                     │
├─────────────────────────────────────────────────────────────┤
│ VDOTChartView ★ (修改：軸標題 / 圖例 / 說明 sheet)           │
│   ├── 圖表 axis label: 「VDOT」                             │
│   ├── 圖例: 「VDOT」（去掉「加權跑力」/「最新跑力」二分）   │
│   └── 說明 sheet                                            │
│         ├── 內文：「VDOT 由 Jack Daniels 提出...」          │
│         └── 底部：閱讀更多 → paceriz.com/blog/dynamic_vdot  │
├─────────────────────────────────────────────────────────────┤
│ Resources/*.lproj/Localizable.strings ★ (三語改寫)           │
│   ├── zh-Hant: 加權/最新/平均加權跑力 → VDOT；副名「動態跑力」│
│   ├── en: Dynamic/Weighted/Latest VDOT → VDOT；副名 Live VDOT│
│   └── ja: 加重/最新/ダイナミックVDOT → VDOT；副名 ライブ VDOT│
├─────────────────────────────────────────────────────────────┤
│ Dead code 清理 (P2)                                          │
│   ├── Havital/Views/Training/WorkoutSummaryRow.swift (刪除)  │
│   ├── Havital/Views/Components/WorkoutRowView.swift  (刪除)  │
│   └── Havital/Utils/LocalizationKeys.swift:147 enum (清理)  │
└─────────────────────────────────────────────────────────────┘
```

★ = 本次修改範圍

---

## 介面合約清單（無新增 API；本次純 UI / strings 變更）

| 介面 | 動作 | 說明 |
|---|---|---|
| `Localizable.strings` keys | 改寫文案 | 詳見 PLAN S01 字串對照表 |
| `WorkoutV2RowView.body` | 修改 layout | 補配速、相對時間、Apple Health badge |
| `WorkoutDetailViewV2.body` | 新增 row | 顯示動態跑力（副名） |
| `VDOTChartView.body + sheet` | 修改 label + 加 link | chart 軸、說明頁底部連結 |

---

## DB Schema 變更

無。本 SPEC 明確不改 Firestore schema，不改 weighted_vdot/dynamic_vdot 演算法。

---

## 任務拆分

| # | 任務 | 角色 | Done Criteria（含對應 AC ID）|
|---|---|---|---|
| S01 | i18n strings rewrite（zh/en/ja 三語） | Developer | strings 改寫完成；AC-01, 02, 03, 04, 05, 06 對應 test 從 FAIL → PASS |
| S02 | `WorkoutV2RowView` 微調 | Developer + Designer | 補配速、相對時間、Apple Health badge；AC-07, 08, 11, 12, 13, 14 對應 test PASS |
| S03 | `WorkoutDetailViewV2` 新增動態跑力 row | Developer | 副名顯示；AC-02 (DetailView 部分), AC-18 對應 test PASS |
| S04 | `VDOTChartView` 重設（軸/圖例/說明頁含官網連結） | Developer | chart label 統一 VDOT、說明頁加 link；AC-03, 04, 04b, 16 對應 test PASS |
| S05 | Dead code 清理 | Developer | 刪除 `WorkoutSummaryRow.swift` + `WorkoutRowView.swift`；AC-17 PASS |
| S06 | AC 全套驗證 + Build gate | QA | `xcodebuild clean build` 過；20 條 AC test 全 PASS（含 5 條已實作）；3 語 simulator 截圖驗證 AC-14 |

**Dependencies**：S01 → {S02, S03, S04}（strings 先改才能 reference）；S05 獨立；S06 全部後。

---

## Risk Assessment

### 1. 不確定的技術點

- **配速計算單位**：iOS 端有 `PaceFormatterHelper.swift` / `PaceCalculator.swift`，需確認單位（min/km vs min/mi）能跟用戶 `UnitManager` 設定一致
- **Apple Health 「來源」判定邏輯**：當 workout `provider != "garmin"` 且 `provider != "strava"` 時，是否一律視為 Apple Health？或需更精細判定（例如純 iPhone vs Apple Watch）？

### 2. 替代方案與選擇理由

- **vs 完全重寫 `WorkoutV2RowView`**：拒絕，現況已 70% 滿足 SPEC，重寫風險高且工時多
- **vs 在卡片上保留所有 4 個欄位（距離/時間/卡路里/配速）**：拒絕，卡片寬度容不下 4 欄並排
- **vs 把「動態跑力」也放卡片**：拒絕，跟 user 對齊「卡片用 VDOT 主名簡化、DetailView 才用副名」

### 3. 需要用戶確認的決策

- **D1**：AC-08 卡片主秀「距離 + 配速 + 時間」三欄，**砍掉現況的「卡路里」**？或別的方案？
- **D2**：AC-18 WorkoutDetailViewV2 「動態跑力」放哪個 section？建議：頂部 summary card 內，跟「距離/時間/配速」並列做為 advanced metric

### 4. 最壞情況與修正成本

- **i18n 改寫遺漏 1 條 key** → AC-06 fail；修正成本：改 1 行 strings
- **`WorkoutV2RowView` layout 改後 simulator 跑出醜版** → Designer 重新調整；修正成本：1-2 hour Designer iteration
- **dead code 刪除誤刪** → grep 已驗證無 caller，風險近零；最壞情況 git revert
- **官網 blog en/ja 版本不存在** → AC-04b 暫定三語都連 zh-Hant 版（PM 已默認）；無 dev 阻塞
