---
type: TD
id: TD-target-race-edit-selection
status: Draft
ontology_entity: target-race-edit-selection
spec: SPEC-target-race-edit-selection.md
created: 2026-04-22
updated: 2026-04-22
---

# 技術設計：目標賽事編輯支援賽事資料庫選擇

## 調查報告

### 已讀文件（附具體發現）

**Spec**
- `Docs/specs/SPEC-target-race-edit-selection.md` — 7 條 AC（P0×6, P1×1），技術約束：iOS Target.swift 缺 raceId、ViewModel 需帶入 raceId、race picker 需解耦
- `Docs/specs/SPEC-onboarding-race-selection.md` — 既有 race picker 行為源頭（AC-ONB-RACE-01~08），本 TD 不重寫
- `Docs/specs/SPEC-target-lifecycle-and-supporting-races.md` — AC-TARGET-04（編輯 supporting）/AC-TARGET-06（刷新依賴）
- `Docs/specs/SPEC-race-database.md` — 後端 `GET /v2/races` 與 `race_id` 欄位已定義

**iOS 原始碼**
- `Havital/Models/Target.swift:3-26` — `Target` struct 缺 `raceId` 欄位與 CodingKey
- `Havital/Views/Onboarding/RaceEventListView.swift:61-62` — 耦合點：`@EnvironmentObject OnboardingFeatureViewModel` + `OnboardingCoordinator.shared.goBack()`
- `Havital/Views/Onboarding/RaceDistanceSelectionSheet.swift:15-21` — 已 callback-based，可零修改複用
- `Havital/Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift:149-164, 972-1011` — race state + `loadCuratedRaces()` / `selectRaceEvent(_:distance:)` / `clearSelectedRace()`
- `Havital/Features/Race/Domain/Entities/RaceEvent.swift:1-40` — `RaceEvent` / `RaceDistance` Domain entity 齊全
- `Havital/Views/EditView/EditTargetView.swift:110-279` — `EditTargetViewModel.updateTarget()` 組 Target 時無 raceId
- `Havital/Features/Target/Presentation/ViewModels/BaseSupportingTargetViewModel.swift:43-57` — `createTargetObject()` 無 raceId
- `Havital/Views/EditView/EditSupportingTargetView.swift:3-113` — `Form`-based sheet，結構與 EditTargetView 對稱
- `Havital/Features/Target/Data/DataSources/TargetRemoteDataSource.swift:58-61` — PUT `/user/targets/{id}`（v1）

**後端**
- `cloud/api_service/api/v1/user.py:164-196` — `PUT /user/targets/{id}`，validate → `update_target(merge=True)`，race_id 透傳
- `cloud/api_service/domains/user/target_types.py:18-24` — `RaceRunTarget` 已含 `race_id: Optional[str]`
- `cloud/api_service/domains/user/target_service.py:453-519` — `merge=True` Firestore 寫入

### 不確定的事項
- `[未確認]` 後端 `GET /user/targets` 回傳時是否已帶 `race_id` 欄位（`RaceRunTarget` 定義有，但未實測 response payload）→ **處理方案**：S01 加入 iOS decode 時 `decodeIfPresent`，容忍後端暫未回傳

### 結論
SPEC 有 7 條 AC IDs，可執行；無衝突；race picker 解耦三方案已知；進入設計。

---

## Spec Compliance Matrix

| AC ID | AC 描述（Given/When/Then） | 實作位置 | Test | 狀態 |
|-------|-------------|---------|------|------|
| AC-TREDIT-01 | 編輯畫面載入同時呈現「從資料庫選擇」+「手動輸入」 | `EditTargetView.swift`（新 Section）<br>`EditSupportingTargetView.swift`（新 Section） | `edit-target-race-dual-entry.yaml`（Maestro） | STUB |
| AC-TREDIT-02 | 有 race_id 時 race picker 預選該賽事 | `TargetEditRacePickerViewModel.init(initialRaceId:)` + loadCuratedRaces 後 lookup | `edit-target-race-preselect.yaml`（Maestro）<br>`TargetEditRacePickerViewModelTests.testPreselect` | STUB |
| AC-TREDIT-03 | 無 race_id 時 race picker 從空白開始 | `TargetEditRacePickerViewModel.init(initialRaceId: nil)` | `TargetEditRacePickerViewModelTests.testNoPreselect` | STUB |
| AC-TREDIT-04 | 選完賽事距離後自動回填 name/date/distance，raceId 寫入 target | `EditTargetViewModel.applyRaceSelection(_:distance:)`<br>`BaseSupportingTargetViewModel.applyRaceSelection(_:distance:)` | `edit-target-race-autofill.yaml`（Maestro）<br>`EditTargetViewModelTests.testApplyRaceSelectionWritesRaceId` | STUB |
| AC-TREDIT-05 | 手動輸入儲存後 race_id 清為 null | `EditTargetViewModel.clearRaceSelection()` + update path<br>同 Base | `EditTargetViewModelTests.testManualEditClearsRaceId` | STUB |
| AC-TREDIT-06 | API 失敗時保留手動輸入入口，不卡死 | `RaceEventListView` 失敗態 + 「手動輸入」按鈕始終可見 | `edit-target-race-api-failure.yaml`（Maestro）+ mocked repo | STUB |
| AC-TREDIT-07 (P1) | 多距離賽事強制完成距離選擇才回填 | `RaceDistanceSelectionSheet` 既有行為（無修改） | `edit-target-race-multi-distance.yaml`（Maestro） | STUB（reuse onboarding sheet） |

AC test stubs 檔案：
- Maestro：`.maestro/flows/spec-compliance/target-race-edit/*.yaml`
- XCTest：`HavitalTests/SpecCompliance/TargetRaceEditACTests.swift`

---

## Component 架構

```
┌─────────────────────────────────────────────────────────┐
│ Presentation                                            │
│  ├─ EditTargetView (修改)                               │
│  │   └─ 新增 Section: "從資料庫選擇" NavigationLink     │
│  ├─ EditSupportingTargetView / AddSupportingTargetView  │
│  │   └─ 新增 Section: 同上                              │
│  ├─ RaceEventListView (解耦，泛化)                      │
│  │   • 原 @EnvironmentObject OnboardingFeatureViewModel │
│  │     → @ObservedObject DataSource: RacePickerDataSource│
│  │   • 原 OnboardingCoordinator.shared.goBack()         │
│  │     → @Environment(\.dismiss)                        │
│  └─ RaceDistanceSelectionSheet (無修改，既有 callback)  │
├─────────────────────────────────────────────────────────┤
│ ViewModel                                                │
│  ├─ EditTargetViewModel (修改)                          │
│  │   • +raceId: String?                                 │
│  │   • +applyRaceSelection(_:distance:)                 │
│  │   • +clearRaceSelection()                            │
│  │   • updateTarget() 帶入 raceId                       │
│  ├─ BaseSupportingTargetViewModel (修改，對稱)          │
│  ├─ TargetEditRacePickerViewModel (新增)                │
│  │   conform RacePickerDataSource                       │
│  │   init(initialRaceId: String?, raceRepository:)      │
│  │   onRaceSelected: ((RaceEvent, RaceDistance) -> Void)│
│  └─ OnboardingFeatureViewModel (無行為變更，僅 extension│
│      declare conformance)                               │
├─────────────────────────────────────────────────────────┤
│ Domain                                                  │
│  └─ RacePickerDataSource protocol (新增)                │
│      required vars + methods（見介面合約）              │
├─────────────────────────────────────────────────────────┤
│ Data                                                    │
│  └─ Target.swift (修改)                                 │
│      +raceId: String?                                   │
│      +CodingKeys.raceId = "race_id"                     │
└─────────────────────────────────────────────────────────┘
```

---

## 介面合約清單

### `RacePickerDataSource` protocol（新增，Race feature / Domain layer）

| 成員 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `raceEvents` | `[RaceEvent]` (get) | ✓ | 當前載入的賽事清單 |
| `isLoadingRaces` | `Bool` (get) | ✓ | 載入中 flag（驅動 skeleton） |
| `selectedRegion` | `String` (get/set) | ✓ | "tw" / "jp"，segment picker 綁定 |
| `isRaceAPIAvailable` | `Bool` (get) | ✓ | API 失敗判定，驅動降級提示 |
| `loadCuratedRaces()` | `async -> Void` | ✓ | 載入 curated=true 的賽事 |
| `selectRaceEvent(_:distance:)` | `(RaceEvent, RaceDistance) -> Void` | ✓ | 回傳選擇結果 |

### `Target` struct（修改）

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `raceId` | `String?` | optional | 新增，CodingKey `"race_id"`，`decodeIfPresent` 容錯 |

### `EditTargetViewModel` / `BaseSupportingTargetViewModel`（修改）

| 成員 | 型別 | 說明 |
|------|------|------|
| `raceId` | `@Published var String?` | 當前 binding 的 race_id（init 時從 target 帶入） |
| `applyRaceSelection(_:distance:)` | `(RaceEvent, RaceDistance) -> Void` | 從 race picker 回來呼叫；設 raceId + raceName + raceDate + selectedDistance |
| `clearRaceSelection()` | `() -> Void` | 用戶改走手動時手動呼叫；**或** 當用戶直接編輯 raceName/selectedDistance 欄位時自動呼叫（見 Decision 4） |

### `TargetEditRacePickerViewModel`（新增）

| 成員 | 型別 | 說明 |
|------|------|------|
| `init(initialRaceId:raceRepository:onRaceSelected:)` | `(String?, RaceRepository, (RaceEvent, RaceDistance) -> Void)` | 依賴注入 |
| `loadCuratedRaces()` | `async` | 首次進入或 region 切換時呼叫 |
| `selectRaceEvent(_:distance:)` | `(RaceEvent, RaceDistance) -> Void` | 觸發 `onRaceSelected` callback |

### `RaceEventListView`（修改簽名）

```swift
// Before
struct RaceEventListView: View {
    @EnvironmentObject var viewModel: OnboardingFeatureViewModel
    @ObservedObject var coordinator = OnboardingCoordinator.shared
}

// After
struct RaceEventListView<DataSource: RacePickerDataSource>: View {
    @ObservedObject var dataSource: DataSource
    @Environment(\.dismiss) var dismiss
}
```

Onboarding call site 改為：`RaceEventListView(dataSource: onboardingViewModel)`。

---

## DB Schema 變更

**無**。後端 `RaceRunTarget.race_id: Optional[str]` 已定義，merge 寫入 Firestore，無 schema 改動。

---

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| S01 | `Target.swift` 加 `raceId: String?` + CodingKey + `decodeIfPresent` | Developer | clean build pass；既有 onboarding 流程 smoke 正常（不 crash） |
| S02 | 定義 `RacePickerDataSource` protocol；`RaceEventListView` 泛化改造；`OnboardingFeatureViewModel` extension 聲明 conformance；移除 `OnboardingCoordinator.shared.goBack()` 改用 `@Environment(\.dismiss)` | Developer | clean build pass；onboarding race-selection flow Maestro 回歸（`.maestro/flows/onboarding-race-selection.yaml` 若存在）不退步 |
| S03 | 新增 `TargetEditRacePickerViewModel`（conform `RacePickerDataSource`） | Developer | Unit test `TargetEditRacePickerViewModelTests` 覆蓋 AC-TREDIT-02/03 全綠 |
| S04 | `EditTargetViewModel` 改造：加 raceId 欄位、`applyRaceSelection`/`clearRaceSelection`、`updateTarget()` 帶入 raceId | Developer | Unit test `EditTargetViewModelTests` 覆蓋 AC-TREDIT-04/05 全綠 |
| S05 | `BaseSupportingTargetViewModel` 對稱改造 | Developer | Unit test 覆蓋 support race 的 raceId 流程 |
| S06 | `EditTargetView` / `EditSupportingTargetView` / `AddSupportingTargetView` 加「從資料庫選擇」Section + NavigationLink wiring | Developer | clean build pass；UI 呈現雙入口 |
| S07 | Maestro flows：`spec-compliance/target-race-edit/*.yaml`（5 條 flow，對應 AC-TREDIT-01/02/04/06/07） | Developer | 5 條 flow 在 iPhone 17 Pro simulator 全部 PASS |
| S08 | 整體 QA 驗收（build + 所有 AC test + simulator 回歸） | QA | QA Verdict：所有 AC PASS，附 screenshot/log 證據 |

**執行順序**：S01 → S02（並行：S03, S04, S05）→ S06 → S07 → S08

---

## Alternatives（為何選 Option A）

| 方案 | 優點 | 缺點 | 為何不選 |
|------|------|------|---------|
| **A. 協議解耦（選用）** | UX 100% 一致（同一個 View）；最小行為風險；符合既有「ViewModel 依賴 Protocol」架構；OnboardingFeatureViewModel 無邏輯改動 | RaceEventListView 需改簽名（由 `@EnvironmentObject` 改為泛型 `@ObservedObject`），onboarding call site 需改 1 處 | — |
| B. Callback 改造 | 顯式 API；無共享協議 | 同樣要改 RaceEventListView 簽名；失去 `@EnvironmentObject` 的自動注入便利；onboarding call site 需改更多地方（手動傳 6 個 callback） | 改動量 ≥ A 但收益 < A |
| C. 新建 RacePickerView 包裝層 | 對 onboarding 代碼零風險 | UI 代碼重複（race card/filter/skeleton/search bar 全部要複製 300+ 行）；兩份 UX 維護易不一致，違反用戶「體驗一致」要求 | UX 一致性是硬需求，不能用複製實現 |

Option A 關鍵細節：
- `OnboardingFeatureViewModel` 已實作所有 protocol 成員（`raceEvents`, `isLoadingRaces`, `selectedRegion`, `isRaceAPIAvailable`, `loadCuratedRaces()`, `selectRaceEvent(_:distance:)`）→ 聲明 conformance 是純 `extension` 一行，**無行為變更**
- Navigation 解耦：onboarding 原用 `coordinator.goBack()` 返回 RaceSetup 頁；改為 `@Environment(\.dismiss)` 後，onboarding flow 需驗證 dismiss 行為等效（NavigationStack push 的 dismiss() 會 pop）

---

## Risk Assessment

### 1. 不確定的技術點
- `[未確認]` 後端 `GET /user/targets` response 是否已含 `race_id`。**緩解**：S01 iOS decode 用 `decodeIfPresent`，後端有則解析、無則 nil；無阻塞。
- `[未確認]` Onboarding flow 中 `OnboardingCoordinator.shared.goBack()` 與 `@Environment(\.dismiss)` 的等效性。**緩解**：S02 完成後跑現有 onboarding Maestro 回歸；若 dismiss 行為不等效，回退為傳入 `onDismiss` closure（仍比 shared coordinator 乾淨）。

### 2. 替代方案與選擇理由
見上方 Alternatives 表。Option A 以最小改動達成 UX 一致性硬需求。

### 3. 需要用戶確認的決策
- **D1（已確認）**：race picker 優先重用而非複製 — 用戶明確表態「體驗一致」
- **D2（本 TD 決定）**：Option A 協議解耦 — 若用戶偏好更保守（Option C），請在 Phase 1.5 Gate 提出
- **D3（需用戶決定）**：AC-TREDIT-05「手動輸入路徑清除 race_id」的觸發時機 — **提案**：當用戶手動編輯 raceName **或** selectedDistance 時自動呼叫 `clearRaceSelection()`；另一選項為儲存時才比對。自動清除的 UX 較直覺（用戶改了名稱即脫離資料庫綁定），但可能被意外觸發。→ **推薦自動清除**，請確認。

### 4. 最壞情況與修正成本
- **最壞**：S02 解耦後 onboarding race 選擇流程退步 → 回滾 RaceEventListView 簽名改動（~半天），改走 Option C 新建包裝層（~1 天）
- **次壞**：S04/S05 ViewModel 改動讓既有 target 編輯退步（plan 未刷新、距離未帶入）→ Repository/ViewModel 層單元測試能抓到
- **可控**：後端 race_id 回傳未落地 → 用戶看不到預選效果，但不 crash，可後續後端補

---

## Done Criteria（Dispatch Developer 用）

以下 AC test 必須從 FAIL 變 PASS：
- `AC-TREDIT-01`（Maestro: dual entry）
- `AC-TREDIT-02`（Maestro + Unit: pre-select）
- `AC-TREDIT-03`（Unit: no preselect）
- `AC-TREDIT-04`（Maestro + Unit: auto-fill, write raceId）
- `AC-TREDIT-05`（Unit: clear raceId on manual save）
- `AC-TREDIT-06`（Maestro: API failure 保留手動入口）
- `AC-TREDIT-07` P1（Maestro: multi-distance force）

額外 Done Criteria：
- clean build pass (`xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`)
- Onboarding race-selection 回歸 Maestro 流程不退步
- `Target.swift` raceId 欄位能正確 encode/decode（E2E：編輯→儲存→重啟 app→race picker 預選正確）
- 無 `print()` / emoji logs；新增 API 呼叫 `.tracked(from:)`
- Repository 不碰 `CacheEventBus`（專案 Hard Constraint #7）
- ViewModel 皆 `@MainActor`，依賴 Repository Protocol
- `/simplify` 已執行

---

## Resume Point

**當前狀態**：TD Draft 完成，等用戶確認（Phase 1.5 Gate）。
**下一步**：
1. 用戶確認 D2（Option A）+ D3（自動清除 raceId）→ TD status 改為 Approved
2. 建立 AC test stubs（Maestro 5 條 + XCTest 3 個測試類）
3. 建 PLAN 檔 + dispatch S01 給 Developer
