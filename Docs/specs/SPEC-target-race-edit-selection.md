---
type: SPEC
id: SPEC-target-race-edit-selection
status: Draft
ontology_entity: target-race-edit-selection
created: 2026-04-22
updated: 2026-04-22
investigation: completed
---

# Feature Spec: 目標賽事編輯支援賽事資料庫選擇

## 背景與動機

Onboarding 已可從賽事資料庫選擇賽事（`SPEC-onboarding-race-selection.md`），但「我的訓練目標」的編輯目標賽事流程仍只有手動輸入。同樣要找賽事、填日期、選距離，卻要自己查資料再手動打，體驗不一致，也無法建立 `race_id` 關聯（影響未來賽事通知、聚合分析）。

這份 spec 將相同的賽事選擇能力延伸到目標賽事的**編輯**入口。

## 目標用戶

- 已完成 onboarding、要修改主目標賽事的用戶
- 要新增或修改支援賽事的用戶

## Spec 相容性

已比對的既有 Spec：
- `SPEC-onboarding-race-selection.md` — 賽事選擇核心行為（AC-ONB-RACE-01~08）。本 spec 重用相同 race picker，不重複定義搜尋/篩選/回填規則，只定義**編輯情境**特有行為。
- `SPEC-target-lifecycle-and-supporting-races.md` — 擁有 AC-TARGET-04（編輯 supporting target）。本 spec 補充其未定義的資料庫選賽事能力，不修改既有 AC。
- `SPEC-race-database.md` — 後端 API `GET /v2/races` 已定義，target `race_id` 欄位已定義。後端無需新增。

衝突：無。

## 明確不包含

- 賽事資料庫搜尋規則、race picker UI 元件切法 → 依 `SPEC-onboarding-race-selection.md`
- 目標刪除、目標刷新邏輯 → `SPEC-target-lifecycle-and-supporting-races.md`
- 非賽事型目標（如 Beginner、Maintenance）的編輯流程

---

## 需求

### P0（必須有）

#### 1. 編輯入口提供雙路徑

- **描述**：進入目標賽事編輯時，系統提供「從賽事資料庫選擇」與「手動輸入」兩個入口，與 onboarding 體驗一致。
- **Acceptance Criteria**：
  - `AC-TREDIT-01`: Given 用戶開啟目標賽事編輯畫面（主目標或支援賽事），When 畫面載入，Then 系統必須同時呈現「從賽事資料庫選擇」和「手動輸入」兩個可操作入口，不得只顯示手動表單。

#### 2. 已有 race_id 的目標預選對應賽事

- **描述**：若該目標已透過資料庫選擇（有 `race_id`），開啟編輯時 race picker 應預先選中該賽事，讓用戶可以確認或換選，而非從空白開始。
- **Acceptance Criteria**：
  - `AC-TREDIT-02`: Given 目標的 `race_id` 不為 null，When 用戶選擇「從資料庫選擇」路徑，Then race picker 必須以該 `race_id` 對應的賽事作為初始選中狀態。
  - `AC-TREDIT-03`: Given 目標的 `race_id` 為 null（手動輸入建立），When 用戶選擇「從資料庫選擇」路徑，Then race picker 從空白/預設清單開始，不預選任何賽事。

#### 3. 選定賽事後自動回填核心欄位

- **描述**：用戶從資料庫確認賽事與距離後，系統自動帶入名稱、日期、距離，用戶只需補完目標完賽時間（同 `AC-ONB-RACE-04`）。
- **Acceptance Criteria**：
  - `AC-TREDIT-04`: Given 用戶在 race picker 完成賽事與距離選擇，When 返回編輯畫面，Then 賽事名稱、日期、距離三個欄位必須自動更新，`race_id` 寫入 target；用戶仍可自行修改目標完賽時間。

#### 4. 手動輸入路徑清除 race_id

- **描述**：用戶切回手動輸入並儲存後，`race_id` 應清為 null，避免 target 持有不符的 race_id。
- **Acceptance Criteria**：
  - `AC-TREDIT-05`: Given 目標原有 `race_id`，When 用戶改走手動輸入路徑並儲存，Then 儲存的 target `race_id` 必須為 null。

#### 5. API 失敗不阻擋編輯

- **描述**：race API 失敗或空結果時，用戶仍能改走手動輸入完成編輯（同 `AC-ONB-RACE-07`）。
- **Acceptance Criteria**：
  - `AC-TREDIT-06`: Given race API 回傳錯誤或空結果，When 用戶嘗試從資料庫選擇，Then 系統必須顯示錯誤提示並保留「手動輸入」入口，不得讓編輯畫面卡死。

### P1（應該有）

#### 6. 多距離賽事要求選距離

- **描述**：賽事有多個距離選項時，必須讓用戶完成距離選擇才能回填（同 `AC-ONB-RACE-03`）。
- **Acceptance Criteria**：
  - `AC-TREDIT-07`: Given 用戶選擇包含多個距離的賽事，When 尚未選定距離，Then 系統不得讓用戶完成選擇並回填；必須強制完成距離選擇步驟。

---

## 技術約束（給 Architect 參考）

### 後端（已確認無需修改）
- 更新目標使用 `PUT /v1/user/targets/{id}`，後端 `update_target` 以 `merge=True` 寫 Firestore，已可接受 `race_id` 欄位
- `GET /v2/races` 已定義（`SPEC-race-database.md`），`RaceRunTarget` TypedDict 已有 `race_id: Optional[str]`

### iOS 必要改動（已確認）
1. **`Target.swift`** 需新增 `raceId: String?` 欄位與 `CodingKeys.raceId = "race_id"`，才能在 PUT payload 帶入並從 response 解析
2. **`EditTargetViewModel.updateTarget()`** 需在建立 `Target` 物件時帶入 `raceId`
3. **`BaseSupportingTargetViewModel.createTargetObject()`** 同上

### Race Picker 重用架構（Architect 需決定方案）
`RaceEventListView` 深度耦合 `OnboardingFeatureViewModel`（狀態）和 `OnboardingCoordinator.shared`（導航），**無法直接複用**。`RaceDistanceSelectionSheet` 已是純 callback pattern，可零修改複用。

重用方案（擇一）：
- **A. 協議解耦**：抽出 `RacePickerDataSource` 協議（`raceEvents`、`loadCuratedRaces()`、`selectRaceEvent()`），讓 `RaceEventListView` 泛化；`OnboardingFeatureViewModel` 和新的目標編輯 ViewModel 均 conform
- **B. Callback 改造**：`RaceEventListView` 改接 closure（`onRaceSelected`、`onLoadRaces`）和 binding（`region`、`events`），移除對 `OnboardingCoordinator.shared` 的直接呼叫，改用 `@Environment(\.dismiss)`
- **C. 新建輕量 RacePickerView**：獨立封裝 race 載入邏輯，不碰 `RaceEventListView` 現有代碼

三個方案重用程度相同、體驗一致；A/B 需修改現有 onboarding 組件，C 隔離性最高但有少量重複代碼。

### 編輯後刷新
遵循既有 AC-TARGET-06（依賴 target 的畫面需刷新）

## 開放問題

無。（所有技術問題已在 spec 確認階段調查完畢）

## AC ID Index

| AC ID | 對應需求 | 優先級 |
|-------|----------|--------|
| AC-TREDIT-01 | 編輯入口提供雙路徑 | P0 |
| AC-TREDIT-02 | 有 race_id 目標預選對應賽事 | P0 |
| AC-TREDIT-03 | 無 race_id 目標從空白開始 | P0 |
| AC-TREDIT-04 | 選定賽事後自動回填核心欄位 | P0 |
| AC-TREDIT-05 | 手動輸入路徑清除 race_id | P0 |
| AC-TREDIT-06 | API 失敗不阻擋編輯 | P0 |
| AC-TREDIT-07 | 多距離賽事強制距離選擇 | P1 |
