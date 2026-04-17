---
type: SPEC
id: SPEC-trainingplanv2-cache-cooldown
status: Draft
ontology_entity: 訓練計畫系統
created: 2026-04-17
updated: 2026-04-17
---

# Feature Spec: TrainingPlanV2 背景刷新 Cooldown

## 背景與動機

TrainingPlanV2（以下稱 V2）原本採用純 SWR（stale-while-revalidate）策略：每次讀 cache 都會同時觸發一次背景 refresh，以求資料「永遠最新」。

這個策略在實際使用中暴露兩個問題：

1. **API 呼叫過頻**：使用者在同一畫面短時間內多次進出、或 ViewModel 被重建時，每次讀 cache 都會再打一次後端，造成可觀測到的浪費（planStatus 特別明顯）。
2. **與 V1 不一致**：V1 Workout Repository 已採用 12 小時 cooldown 壓制呼叫頻率，行之有年且穩定；V2 缺此機制，反而成為資源使用上的退步。

同時，我們不希望直接關掉 SWR：使用者手動下拉刷新、編輯課表後、或事件驅動（產生計畫、切週、生成週課表、延遲重算）等情境，仍必須看到最新資料。

本規格定義 V2 背景刷新的 cooldown 行為，讓「節流」與「即時性」在不同路徑上各自成立。

## 目標用戶

- **一般使用者**：打開 App 或停留在訓練計畫頁時，不會在背景產生無謂的 API 呼叫；但主動操作（下拉刷新、編輯課表、產生計畫）後，資料仍然即時更新。
- **開發與維運**：透過降低 planStatus 的冗餘呼叫，降低後端負載與成本，並與 V1 cooldown 行為對齊，減少認知成本。

## 需求

### P0（必須有）

#### R1. V2 背景刷新預設 30 分鐘 cooldown

- **描述**：V2 Repository 在 cache hit 情境下，若距離上一次成功背景刷新尚未超過 30 分鐘，**不再觸發背景 refresh**；直接回傳 cache 即可。
- **Acceptance Criteria**：
  - Given cache 有資料、且距離上次成功刷新 < 30 分鐘, When 畫面讀取 planStatus, Then 只回傳 cache，**不**對後端發出 planStatus 請求
  - Given cache 有資料、且距離上次成功刷新 ≥ 30 分鐘, When 畫面讀取 planStatus, Then 回傳 cache 後，於背景觸發一次 planStatus refresh

#### R2. 強制刷新情境無視 cooldown 並重設計時器

- **描述**：下列情境視為「使用者或系統明確要求最新資料」，**必須繞過 cooldown** 直接呼叫後端；成功後同時**重設 cooldown 計時器**：
  - 手動下拉刷新（pull-to-refresh）
  - 編輯課表儲存完成（`updateOverview` / `updateWeeklyPlan` / `changeMethodology`）
  - 明確事件驅動刷新：產生計畫、切週、生成週課表、延遲重算
- **Acceptance Criteria**：
  - Given cooldown 內（< 30 分鐘）, When 使用者下拉刷新, Then 對後端發出 planStatus 請求，且成功後 cooldown 計時器歸零重計
  - Given 使用者編輯週課表並儲存成功, When UI 層再次讀取 planStatus, Then 使用更新後的資料；外層**不需**依賴 planStatus API 即可看到最新課表內容
  - Given 事件驅動刷新觸發（如產生計畫完成）, When Repository 接收到該事件, Then 無視 cooldown 呼叫後端，成功後重設 cooldown

#### R3. 背景刷新失敗不 mark cooldown

- **描述**：只有「成功完成的背景刷新」才更新 cooldown 時間戳；刷新失敗（網路錯誤、後端 5xx 等）**不**更新，避免使用者被鎖在舊資料 30 分鐘。
- **Acceptance Criteria**：
  - Given cache hit 並觸發背景 refresh, When refresh 失敗, Then cooldown 時間戳不變；下一次 cache hit 仍會再次嘗試背景 refresh

#### R4. Cooldown 僅針對 Track B 背景刷新

- **描述**：cooldown 只影響「Track B：cache hit 時的背景 refresh」。**cache miss**（Track A，首次讀取或 cache 被清空）與**事件驅動路徑**不受 cooldown 影響，確保必要的初次載入與關鍵更新路徑不被阻擋。
- **Acceptance Criteria**：
  - Given cache 為空（cache miss）, When 畫面讀取 planStatus, Then 直接呼叫後端取得資料，**不**檢查 cooldown
  - Given 事件驅動刷新, When 觸發時在 cooldown 內, Then 仍直接呼叫後端（同 R2）

#### R5. Cooldown 狀態僅記憶體

- **描述**：cooldown 時間戳只存在於記憶體（in-memory），**不**持久化。App 冷啟動後第一次讀取應打一次後端，這是合理的新鮮度成本。
- **Acceptance Criteria**：
  - Given App 剛冷啟動, When 首次讀取 planStatus 且 cache 有資料, Then 觸發一次背景 refresh（因為記憶體中無 cooldown 記錄）

### P1（應該有）

#### R6. 為未來 per-resource cooldown 預留擴展空間

- **描述**：V2 未來可能需要對 overview / weeklyPlan / weeklySummary / weeklyPreview 套用各自的 cooldown。本期實作應以 enum 或等價結構表達「資源種類 → cooldown 時間戳」的對應，讓下一期可以直接擴展而不需重寫。
- **Acceptance Criteria**：
  - Given 後續要為 overview 加入 cooldown, When 開發者擴充資源列舉, Then 能在不改動 planStatus 既有行為的前提下新增

## 明確不包含

- **本期只處理 planStatus 的 cooldown**（對應 T1 ~ T5 任務範圍）。
- overview / weeklyPlan / weeklySummary / weeklyPreview 等其他資源**沿用現狀**，待下一期另行規劃。
- 不處理 cooldown 時間可設定（例如從後端遠端設定、或使用者自訂）；本期固定 30 分鐘。
- 不處理跨裝置 / 跨 App 啟動的 cooldown 同步（R5 已明確記憶體內即可）。
- 不改動 V1 Workout Repository 的 12h cooldown 行為。

## 影響範圍

- **主要目標**：`planStatus`（V2 Repository 中目前呼叫最浮濫的資源）。
- **未來可擴展**：overview / weeklyPlan / weeklySummary / weeklyPreview（透過 R6 的 enum 結構預留）。
- **不受影響**：V1 Workout Repository、其他 Feature 的快取策略。

## 技術約束（給 Architect 參考）

- cooldown 必須可被單元測試覆蓋，且**不使用 mock framework**；測試請以真實 in-memory LocalDataSource + fake RemoteDataSource 組合實現。
- cooldown 狀態應可在測試中被注入時間源（避免測試依賴真實 `Date()`）。
- 本期 clean build 必須在 iPhone 17 Pro simulator 上通過。

## Acceptance Criteria（彙整，BDD）

1. **Cache hit 且在 cooldown 內 → 不打 API**
   Given cache 有資料、距離上次成功刷新 < 30 分鐘
   When ViewModel 讀取 planStatus
   Then 只回傳 cache，**不**對後端發出 planStatus 請求

2. **Cache hit 且超過 cooldown → 觸發背景 refresh**
   Given cache 有資料、距離上次成功刷新 ≥ 30 分鐘
   When ViewModel 讀取 planStatus
   Then 立即回傳 cache，並於背景觸發一次 planStatus refresh；成功後更新 cooldown 時間戳

3. **Pull-to-refresh → 無視 cooldown 並重設計時器**
   Given 目前距離上次刷新 < 30 分鐘
   When 使用者手動下拉刷新
   Then 立即呼叫後端；成功後 cooldown 時間戳被重設為當下

4. **編輯課表儲存後外層看到更新後的資料（不依賴 planStatus API）**
   Given 使用者在編輯頁修改週課表
   When 儲存完成（`updateWeeklyPlan` 成功）
   Then 外層 UI 顯示更新後的資料；此流程**不需要**額外呼叫 planStatus API 也能看到最新內容

5. **事件驅動刷新（產生計畫）→ 繞過 cooldown**
   Given 使用者觸發「產生計畫」
   When 流程完成並通知 Repository
   Then Repository 繞過 cooldown 呼叫後端，成功後重設 cooldown

6. **事件驅動刷新（生成週課表）→ 繞過 cooldown**
   Given 使用者觸發「生成本週課表」
   When 流程完成並通知 Repository
   Then Repository 繞過 cooldown 呼叫後端，成功後重設 cooldown

7. **背景 refresh 失敗 → cooldown 不更新**
   Given cache hit 並觸發背景 refresh
   When refresh 因網路或後端錯誤失敗
   Then cooldown 時間戳**不**更新；下一次 cache hit 仍會再次嘗試背景 refresh

8. **Cache miss 不受 cooldown 影響**
   Given cache 為空（例如首次登入或 cache 被清除）
   When ViewModel 讀取 planStatus
   Then 直接呼叫後端取得資料，**不**檢查 cooldown

9. **App 重啟 → cooldown 計時器重置**
   Given App 已冷啟動且 cache 仍有資料
   When 首次讀取 planStatus
   Then 視為無 cooldown 記錄，觸發一次背景 refresh，成功後開始計時

## Done Criteria

- [ ] 以上 9 條 Acceptance Criteria 對應的單元測試全綠
- [ ] **不使用 mock framework**：測試以真實 in-memory `TrainingPlanV2LocalDataSource` + fake `TrainingPlanV2RemoteDataSource` 組合實作
- [ ] Clean build 於 iPhone 17 Pro simulator 上通過
- [ ] V1 Workout Repository 行為不受影響（回歸確認）

## 開放問題

- Cooldown 計時器的時間來源抽象（例如 `Clock` protocol）如何命名與置於何層，由 Architect 決定。
- R6 enum 命名與擺放位置（Domain / Data 層）由 Architect 決定。
- 「編輯課表儲存完成」的事件通知機制（是由 Repository 直接更新 cache，還是透過事件匯流排）由 Architect 決定；本 Spec 僅要求 AC#4 的外層行為成立。
- 後續若要將 cooldown 擴展至其他資源，各資源的 cooldown 時長是否統一為 30 分鐘，待下一期 Spec 決定。
