---
type: SPEC
id: SPEC-weekly-adjustment-selection
status: Implemented
l2_entity: TBD
created: 2026-04-18
updated: 2026-04-18
---

# Feature Spec: 週回顧調整建議接受／拒絕

## 背景與動機

後端 Scoped Customization（S01-S07）已完成：`WeeklySummaryV2.nextWeekAdjustments.items` 每條建議
附帶 `apply: Bool`（後端推薦是否套用）及 `impact`（套用效果說明）。

現況 iOS 在週回顧的「下週調整建議」section 只做展示，行動只有一個「接受調整並產生下週課表」按鈕，
等同全部接受，用戶沒有篩選空間。

AI 建議不可能 100% 符合每位跑者當週狀況（行程、疲勞度、賽前保守策略等），
無法拒絕個別建議會降低用戶對 AI 教練的信任感與課表黏著度。

**目標：** 在週回顧到產生下週課表的流程中，讓用戶能逐條確認哪些調整建議要套用，
把「最後一哩路」的決策權還給跑者。

## 目標用戶

- 正在執行 V2 訓練計畫的跑者
- 場景：完成某週訓練後，查看 AI 週回顧，準備產生下週課表前的確認步驟

## Spec 相容性

已比對既有 Spec：
- `SPEC-training-hub-and-weekly-plan-lifecycle`：AC-TRAIN-HUB-06 定義「何時顯示產生下週課表按鈕」（`canGenerate == true` + `hasPlan == false`），本 spec 定義按鈕出現後的行為與 toggle UI，互不衝突
- `SPEC-weekly-preview-ui`：涵蓋週骨架預覽，與調整建議無關，無衝突

衝突：無

## 需求

### P0（必須有）

#### 逐條接受／拒絕調整建議

- **描述：** 在週回顧「下週調整建議」section 內，每條建議卡片右側加入 toggle（預設狀態從後端 `apply: Bool` 初始化）。用戶可逐條開關，被關閉的建議以視覺方式標示為「不套用」。

- **Acceptance Criteria：**
  - `AC-WKADJ-01`: Given 週回顧載入完成，When 展開「下週調整建議」，Then 每條建議顯示 toggle，初始狀態對應後端 `apply` 值（`true` = 開啟）
  - `AC-WKADJ-02`: Given 用戶切換某條建議的 toggle off，Then 該卡片顯示視覺弱化（淡出 + 置灰），其餘建議不受影響
  - `AC-WKADJ-03`: Given 用戶有 ≥1 條建議開啟，When 點擊產生按鈕，Then 只有開啟的建議被送往後端套用
  - `AC-WKADJ-04`: Given 用戶把所有建議都關閉，When 點擊產生按鈕，Then 仍可正常生成課表，後端不套用任何調整
  - `AC-WKADJ-05`: Given 建議清單為空（`items.isEmpty`），Then 維持現狀（直接「產生下週課表」，無 toggle 介面）

#### 行動按鈕文字隨選擇動態更新

- **描述：** 底部按鈕文字反映目前接受的建議數量。

- **Acceptance Criteria：**
  - `AC-WKADJ-06`: Given 有 N 條建議開啟（N ≥ 1），Then 按鈕顯示「套用 N 條建議並產生下週課表」
  - `AC-WKADJ-07`: Given 0 條建議開啟，Then 按鈕顯示「不套用調整，直接產生課表」

### P1（應該有）

#### Section header 顯示選擇計數

- **描述：** 「下週調整建議」section header 展開後，顯示「已選 N / M 條」，讓用戶即時知道選擇狀態。

- **Acceptance Criteria：**
  - `AC-WKADJ-08`: Given section 展開且有建議，When 用戶切換任何 toggle，Then header 計數即時更新

#### 顯示每條建議的影響說明（`impact`）

- **描述：** 每條建議卡片在 `reason` 下方顯示 `impact` 欄位，讓用戶清楚知道「套用這條會有什麼效果」。

- **Acceptance Criteria：**
  - `AC-WKADJ-09`: Given `impact` 非空，When 建議卡片顯示，Then `impact` 文字顯示於 `reason` 下方，以不同色調或 icon 與 `reason` 區隔

### P2（可以有）

#### 一鍵還原後端建議預設值

- **描述：** Section 提供「還原預設」入口，點擊後所有 toggle 回到後端 `apply` 初始值。

- **Acceptance Criteria：**
  - `AC-WKADJ-10`: Given 用戶修改過任何 toggle，When 點擊「還原預設」，Then 所有 toggle 回到後端 `apply` 初始值

## 明確不包含

- 不儲存用戶的 toggle 偏好（每次開啟週回顧重置為後端預設值）
- 不提供新增自訂調整項目的功能（只能接受或拒絕 AI 提供的建議）
- 不更動「何時顯示產生下週課表按鈕」的條件邏輯（由 AC-TRAIN-HUB-06 管轄）
- 不影響歷史週的週回顧（toggle 介面只在「有資格產生下週課表」的情境下出現）

## 技術約束（給 Architect 參考）

- **後端 API 參數：** `POST /v2/plan/weekly` 目前接受 `week_of_training`、`force_generate`、`prompt_version`、`methodology`，需確認後端 S01-S07 是否已新增接收「已選調整清單」的參數（如 `applied_adjustment_ids` 或 `applied_scopes`）；若尚未，需與後端對齊合約
- **Toggle 狀態持有：** toggle 選擇狀態為 session-only，建議由 `WeeklySummaryCoordinator` 持有，不需持久化
- **`onGenerateNextWeek` callback：** 目前 `WeeklySummaryV2View` 透過無參 closure 觸發，需擴充為帶有「選中建議清單」的 callback，具體格式由 Architect 決定
- **視覺弱化：** toggle off 的卡片弱化方式（透明度、色彩）由 Designer 決定，Architect 實作時以 `opacity` 為基準即可

## AC ID Index

| AC ID | 需求 | 優先級 |
|-------|------|--------|
| AC-WKADJ-01 | 建議 toggle 預設狀態 | P0 |
| AC-WKADJ-02 | Toggle off 視覺弱化 | P0 |
| AC-WKADJ-03 | 只送已選建議到後端 | P0 |
| AC-WKADJ-04 | 全關仍可生成課表 | P0 |
| AC-WKADJ-05 | 空建議清單不顯示 toggle | P0 |
| AC-WKADJ-06 | 按鈕文字（有選擇） | P0 |
| AC-WKADJ-07 | 按鈕文字（全關閉） | P0 |
| AC-WKADJ-08 | Header 計數即時更新 | P1 |
| AC-WKADJ-09 | Impact 欄位顯示 | P1 |
| AC-WKADJ-10 | 還原後端預設值 | P2 |

## 開放問題

1. **後端 API 合約：** ✅ 已確認（2026-04-18）。調整建議透過 `POST /v2/summary/weekly/apply-items` 送出（`week_of_plan` + `applied_indices: [Int]`），與 `POST /v2/plan/weekly` 完全獨立。生成週課表時後端自動消費，iOS 端不需傳額外參數。
