---
spec: SPEC-vdot-naming-and-workout-row-redesign
td: TD-vdot-naming-and-workout-row-redesign
created: 2026-04-28
status: in-progress
---

# PLAN: VDOT 命名統一與訓練紀錄卡片重設

**Plan ID (ZenOS)**: `460853fc24dd4a16a034dde73dae7088`
**Parent Task ID**: `db6a1273655e43bcb990b37c832e251f`

## Resume Point

**2026-04-28 update v2**：Developer 完成 S01–S05 並交 Completion Report。Architect 審查發現多處錯誤並修正：

### Architect 階段錯誤（已 surface 並修正）

1. **🔴 grep case-sensitive 失誤**：原 `grep "vdot"` 沒抓到 `dynamicVdot`（V 大寫），導致誤判 `WorkoutDetailViewV2` 沒 VDOT。**實際上 `line 707 advancedMetricsCard` 原本就有「動態跑力」DataItem**，i18n key 已是 `L10n.WorkoutDetail.dynamicVdot.localized`，S01 strings 改寫後自動顯示新副名。

2. **🔴 因為 #1，TD 寫了不必要的 S03**：要求 Developer 在 `basicInfoCard:258-265` 新加 dynamicVdot DataItem。實作後 DetailView 同一頁出現**兩處重複動態跑力**。**Architect 已 revert** S03 新加的 block（line 258-265 移除）。

3. **🟡 AC test stub bugs**：AC-05 用錯讀法（binary plist）/ AC-11 同 / AC-17 用 `Bundle.path(...:ofType:"swift")` 邏輯錯（.swift 不入 bundle）。已全數修正 stub。

### 確認的事實

- ✅ Build pass / 7 strings AC PASS / dead code 已處理 / /simplify 完成
- ✅ `WorkoutDetailViewV2:707 advancedMetricsCard` 內既有的「動態跑力」DataItem 透過 S01 i18n 改寫自動實現 D2 意圖
- 🔴 `VDOTChartView` 是 orphan（無 live caller）—— **user 確認暫不處理**，S04 既有 code 保留不 revert（沒 caller 等於沒部署）
- 🔴 `WorkoutSummaryRow.swift` 內 `WorkoutV2SummaryRow` 被 `DailyTrainingCard:145` 引用，必須保留

### AC 重新對齊

- **AC-VDOT-NAME-18 (Architect 加的)** → **N/A**（前提錯誤；DetailView 原本就有副名顯示）
- **AC-VDOT-NAME-16 (P1)** → **N/A**（VDOT 詳細頁無 live view，user 確認不處理）

### 下一步

1. ✅ Revert WorkoutDetailViewV2:258-265 完成
2. ⏳ 跑 build gate 確認 revert 沒破壞編譯
3. ⏳ Dispatch QA 處理 simulator 視覺驗證
4. ⏳ Architect 最終 AC sign-off → 部署

## Pivot 紀錄（Architect 階段發現）

- **2026-04-28**：SPEC v3 鎖定的「重設目標檔案」`WorkoutSummaryRow.swift` 經 grep 確認為 dead code（zero callers）。真正的 list row 是 `WorkoutV2RowView.swift`（在 `TrainingRecordView:63` 引用）。User 同意 PLAN 檔記錄 pivot、SPEC frontmatter 不動。
- **2026-04-28**：User 補充新需求：卡片仍用 VDOT 主名（簡化），但 `WorkoutDetailViewV2` 必須新增「動態跑力 / Live VDOT / ライブ VDOT」副名顯示。新增 AC-VDOT-NAME-18。

## Tasks

### S01：i18n strings rewrite（三語對齊）

- [ ] **檔案**：`Havital/Resources/{zh-Hant,ja,en}.lproj/Localizable.strings`
- [ ] **影響 AC**：01, 02, 03, 04, 05, 06, 14
- [ ] **改寫對照表**（精確）：

  | key | zh-Hant 改 | en-US 改 | ja-JP 改 |
  |---|---|---|---|
  | `workout.detail.dynamic_vdot` | 動態跑力 | Live VDOT | ライブ VDOT |
  | `performance.vdot_trend` | VDOT 趨勢 | VDOT Trend | VDOT トレンド |
  | `performance.vdot_explanation` | （重寫，不提跑力/徐國峰）| （重寫）| （重寫） |
  | `performance.chart.vdot_value` | VDOT | VDOT | VDOT |
  | `performance.vdot.dynamic_vdot` | 動態跑力 | Live VDOT | ライブ VDOT |
  | `performance.vdot.weighted_vdot` | VDOT | VDOT | VDOT |
  | `performance.vdot.latest_vdot` | VDOT | VDOT | VDOT |
  | `performance.vdot.vdot_title` | VDOT | VDOT | VDOT |
  | `performance.vdot.what_is_vdot` | 什麼是 VDOT？ | What is VDOT? | VDOT とは？ |
  | `performance.vdot.vdot_description` | （重寫，不提徐國峰/跑力）| （重寫）| （重寫） |
  | `performance.vdot.calculating_vdot` | 計算 VDOT 中… | Calculating VDOT… | VDOT を計算中… |
  | `performance.vdot.average_weighted_vdot` | 平均 VDOT | Average VDOT | 平均 VDOT |
  | `performance.vdot.latest_dynamic_vdot` | 最新動態跑力 | Latest Live VDOT | 最新ライブ VDOT |
  | （新）`performance.vdot.read_more` | 閱讀更多 | Learn more | 詳しく見る |
  | （新）`performance.vdot.blog_url` | https://paceriz.com/blog/dynamic_vdot.html | （同 zh，待跨團隊確認 en 版）| （同 zh，待跨團隊確認 ja 版）|
- [ ] **新 vdot_description 三語草稿**：
  - **zh-Hant**：「VDOT 是國際通用的有氧能力指標，由 Jack Daniels 博士提出。數值越高，代表您的有氧基礎越好。\n\nPaceriz 為您追蹤兩個 VDOT 數字：\n\n**VDOT**\n您的穩定有氧能力，根據近期跑步數據加權平均得出，能反映您對目標賽事的當前實力。\n\n**動態跑力**\n每次跑步後即時計算的當下表現值，會受到當天氣溫、心率、身體狀況影響而起伏。想看穩定趨勢請看 VDOT。」
  - **en-US**：「VDOT is an internationally recognized aerobic capacity indicator proposed by Dr. Jack Daniels. A higher value reflects a stronger aerobic base.\n\nPaceriz tracks two VDOT values for you:\n\n**VDOT**\nYour stable aerobic capacity, calculated as a weighted average of recent runs. This reflects your current readiness for your target race.\n\n**Live VDOT**\nA real-time value calculated after each run. It fluctuates based on temperature, heart rate, and your daily condition. Use VDOT for stable trends.」
  - **ja-JP**：「VDOT は Jack Daniels 博士が提唱した、国際的に認知された有酸素能力の指標です。数値が高いほど、有酸素ベースが強いことを示します。\n\nPaceriz では 2 つの VDOT 値を追跡しています：\n\n**VDOT**\n直近のランニングデータの加重平均で算出される安定した有酸素能力。目標レースへの現在の実力を反映します。\n\n**ライブ VDOT**\n各ランの後に即時計算されるリアルタイム値。気温、心拍数、当日のコンディションによって変動します。安定したトレンドを見るには VDOT をご覧ください。」
- [ ] **驗證**：grep zh-Hant.lproj 不可有「加權跑力」「最新跑力」「跑力 趨勢」字眼殘留；三檔 keys count 一致

### S02：`WorkoutV2RowView` 微調

- [ ] **檔案**：`Havital/Views/Components/WorkoutV2RowView.swift`
- [ ] **影響 AC**：07, 08, 11, 12, 13, 14
- [ ] **改動**：
  - line 60-105 數據網格：加入「配速」欄；**砍卡路里 OR 改 layout 待 D1 拍板**
  - line 113-116 / 164-168 日期：改用相對時間 helper（今天 18:30 / 昨天 / 3 天前 09:00 等）；建議新增 `formatRelativeDate(_:)` private func 或共用 `Date+Extensions`
  - line 135-162 attribution：新增 Apple Health badge case（當 provider 既不是 garmin 也不是 strava 時 render `AppleHealthAttributionView`，需新建此 component）
  - audit `GarminAttributionView` 確保 `Garmin Connect™` 字樣含 ™（grep 已確認 UserProfileView:1465 有 ™，但需確認 attribution component 內部）
- [ ] **新檔案**：`Havital/Views/Components/AppleHealthAttributionView.swift`（仿 `GarminAttributionView` 結構）
- [ ] **驗證**：simulator 三語截圖；多筆 workout 來源混合測試 badge 樣式一致

### S03：`WorkoutDetailViewV2` 新增動態跑力 row

- [ ] **檔案**：`Havital/Views/Training/WorkoutDetailViewV2.swift`
- [ ] **影響 AC**：02 (DetailView 部分), 18
- [ ] **改動**：在頂部 summary card 內，跟距離/時間/配速並列新增「動態跑力」欄位（依 D2 決策），label 用 `L10n.WorkoutDetail.dynamicVdot.localized`
- [ ] **條件**：跑步紀錄且有 `dynamicVdot` 才顯示，非跑步或 nil 則隱藏整個 row（沿用 AC-09b 規則）
- [ ] **驗證**：simulator 開啟一筆跑步 workout 詳情頁，三語下確認顯示「動態跑力 / Live VDOT / ライブ VDOT」

### S04：`VDOTChartView` 重設

- [ ] **檔案**：`Havital/Views/Components/VDOTChartView.swift`
- [ ] **影響 AC**：03, 04, 04b, 16
- [ ] **改動**：
  - line 122/153/160/170/176/182：圖例 color mapping 改用單一「VDOT」label（去掉「加權跑力」二分）
  - line 238/244：兩張卡片標題改「VDOT」+ 副資訊「動態跑力（最新一次）」（依 SPEC AC-16）
  - 說明頁 sheet：底部新增「閱讀更多」按鈕，使用 `Link(destination: URL(string: ...))` 打開官網 blog
- [ ] **驗證**：圖表 zh-Hant / en / ja 三語下軸標題與圖例都顯示 VDOT；說明頁底部點連結能在 Safari 開啟 blog

### S05：Dead code 清理

- [ ] **檔案**：
  - 刪除 `Havital/Views/Training/WorkoutSummaryRow.swift`
  - 刪除 `Havital/Views/Components/WorkoutRowView.swift`
  - 清理 `Havital/Utils/LocalizationKeys.swift:147` 的 `enum WorkoutSummaryRow {...}`（若無其他 caller）
- [ ] **影響 AC**：17
- [ ] **驗證**：`xcodebuild clean build` 過；grep 全 codebase 無 `WorkoutSummaryRow` / `WorkoutRowView` reference

### S06：AC 全套驗證 + Build gate

- [ ] **角色**：QA
- [ ] **驗證項目**：
  - `xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` 通過
  - 20 條 AC test 全 PASS（含 5 條已實作 + 15 條新實作）
  - 三語 simulator 截圖：zh-Hant / en-US / ja-JP 各跑：訓練紀錄頁、單次紀錄詳情頁、VDOT 趨勢圖、VDOT 說明頁
  - regression：grep 全 codebase 無「加權跑力」「最新跑力」殘留
- [ ] **Maestro flows**（如 `.maestro/flows/` 有 vdot 相關 flow，optional 補強）

## Decisions

- 2026-04-28：採用 Decision 1(c) PLAN 檔記 pivot、SPEC frontmatter 不動
- 2026-04-28：採用 Decision 2(b) 卡片保留 VDOT 主名 + DetailView 加副名（新增 AC-18）
- 2026-04-28：採用 Decision 3(a) 兩個 dead code 都清掉

## Open Questions（需 user 拍板才能 dispatch）

- **D1**：AC-08 卡片主秀，砍卡路里換配速 OK？還是用其他 layout（如時間/距離為一行 + 配速/卡路里為次行）？
- **D2**：AC-18 WorkoutDetailViewV2 動態跑力放哪個 section？建議：頂部 summary card 內，跟距離/時間/配速並列
- **D3 (跨團隊)**：`paceriz.com/blog/dynamic_vdot.html` en/ja 版本是否存在？若無，三語連結都先指 zh-Hant 版

---

## 子 Task 拆分計畫（待 D1/D2 解後 ZenOS create）

依序：
1. ZenOS task create S01 i18n strings rewrite
2. ZenOS task create S02 WorkoutV2RowView 微調
3. ZenOS task create S03 WorkoutDetailViewV2 新增 vdot row
4. ZenOS task create S04 VDOTChartView 重設
5. ZenOS task create S05 dead code cleanup
6. ZenOS task create S06 QA verification

每個子 task：parent_task_id = `db6a1273655e43bcb990b37c832e251f`，plan_id = `460853fc24dd4a16a034dde73dae7088`，product_id = `615254597b914c83977e5619d672198b`。
