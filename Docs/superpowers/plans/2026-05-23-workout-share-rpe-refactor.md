# Workout 分享 / RPE+心得 重構 Implementation Plan

> **For agentic workers:** 依序執行各 Task；每 Task 完成後由 Architect/TPM 親自 build + simulator 驗證再進下一步。Steps 用 checkbox 追蹤。

**Goal:** 把目前「撒花 recap」彈窗（分享卡 + RPE + 心得 + 撒花全包一頁）拆成：(1) 一個統一分享畫面（撒花改情境旗標），(2) 一個 RPE+心得合併畫面（進 WorkoutDetailView 且無 RPE 時自動彈）。並刪除被取代的舊分享/編輯器。

**Architecture:** iOS-only。`Presentation → Domain → Data → Core`。沿用既有 `WorkoutRecapContent`（資料模型）與 InterruptCoordinator 自動彈機制；只改 Presentation 層。撒花用旗標控制，自動彈傳 true、從 detail 進傳 false。

**Tech Stack:** SwiftUI, ImageRenderer, InterruptCoordinator, WorkoutRepository(updateRPE/updateTrainingNotes), XCTest。

**模組名（@testable import）：** `paceriz_dev`。**建置模擬器：** iPhone 17 Pro。

---

## 決策（已與用戶確認）

- 統一分享畫面 = 現有 recap 撒花畫面（`RecapShareCard` + 底部分享鈕），**移除 RPE 區 + 訓練日記區**。
- 撒花 = 情境旗標：自動彈（完訓後）→ 撒花；從 WorkoutDetailView 工具列進 → 不撒花。同一畫面。
- WorkoutDetailView「分享訓練成果」改用此 recap 風格畫面，取代 `WorkoutShareCardSheetView`。
- RPE + 心得 → 獨立合併畫面 `WorkoutReflectionView`：上 RPE 色階條（沿用 recap 1-10 pill）、下沿用 `RecapDiaryEditorView` 設計（context strip + 主題 chip + textarea）。
- 名稱沿用 `WorkoutRecapView` / `WorkoutRecapContent` / interrupt `workoutRecap`（降 churn）。

## 硬規矩

- 不可造假：每步驟自己 build / 跑測試 / 截圖，貼實際結果。
- commit message 結尾標 role：`iOS Developer`。
- 不 push、不 amend、不 reset --hard、不 --no-verify。
- 刪檔前先 grep 確認 0 引用，且 build 通過。刪除是獨立 Task，gate 在前面 Task build 成功之後。

---

## File Structure

- 改 `Havital/Features/Workout/Presentation/Recap/WorkoutRecapView.swift` — 加 `showConfetti` 旗標、移除 RPE/心得區。
- 改 `Havital/Core/Presentation/Interrupts/InterruptHostView.swift:47` — `WorkoutRecapView(content:showConfetti:true)`。
- 改 `Havital/Features/TrainingPlanV2/Presentation/Views/TrainingPlanV2View.swift:395`（DEBUG）— 同上傳 true。
- 建 `Havital/Features/Workout/Presentation/Recap/WorkoutReflectionView.swift` — RPE+心得合併畫面。
- 建 `Havital/Features/Workout/Domain/WorkoutReflectionGate.swift` — 純函式 `shouldAutoPrompt`。
- 改 `Havital/Views/Training/WorkoutDetailViewV2.swift` — 分享改接 recap 畫面；RPE/心得改接 WorkoutReflectionView；onAppear 無 RPE 自動彈。
- 測 `HavitalTests/Features/Workout/WorkoutReflectionGateTests.swift`。
- 刪（gate 後）`Havital/Views/Components/ShareCard/WorkoutShareCardSheetView.swift` 及周邊、`Havital/Views/Training/RPEEditorView.swift`、`Havital/Views/Training/TrainingNotesEditorView.swift`、`Havital/Features/Workout/Presentation/Recap/RecapDiaryEditorView.swift`。

---

### Task 1: WorkoutRecapView → 統一分享畫面（撒花旗標化、移除 RPE/心得）

**Files:** Modify `WorkoutRecapView.swift`, `InterruptHostView.swift`, `TrainingPlanV2View.swift`

- [ ] Step 1: `WorkoutRecapView` 加 `var showConfetti: Bool = false`。
- [ ] Step 2: 把 `.task` 內的撒花序列包成 `if showConfetti { ... }`（不撒花時不跑 sleep/動畫）。
- [ ] Step 3: 從 `body` 移除 `rpeSection` 與 `diaryInline`（VStack 只留 RecapShareCard + Spacer）；移除 `.sheet(item:)` 的 `.diary` case、`selectedRPE`/`selectRPE`/`rpeSection`/`rpePill`/`rpeFeedback`/`diaryInline` 相關程式與 `RecapActiveSheet.diary`。保留 `.photo` 與 `.share`。
- [ ] Step 4: navigationTitle 改為 `分享訓練成果`（i18n key `workout.share.title`，三語）。
- [ ] Step 5: `InterruptHostView.swift:47` 與 `TrainingPlanV2View.swift:395`（DEBUG）改傳 `WorkoutRecapView(content: content, showConfetti: true)`。
- [ ] Step 6: build（iPhone 17 Pro）通過。

**Done Criteria:** 分享畫面只剩分享卡 + 照片 + 底部分享鈕；自動彈仍撒花；build 綠。

---

### Task 2: WorkoutReflectionGate（純函式 + 測試）

**Files:** Create `WorkoutReflectionGate.swift`, `WorkoutReflectionGateTests.swift`

- [ ] Step 1: 純函式：
```swift
enum WorkoutReflectionGate {
    /// detail 載入後、無 RPE、且本次尚未自動彈過 → 自動彈一次。
    static func shouldAutoPrompt(hasRPE: Bool, detailLoaded: Bool, alreadyPrompted: Bool) -> Bool {
        detailLoaded && !hasRPE && !alreadyPrompted
    }
}
```
- [ ] Step 2: 測試（`@testable import paceriz_dev`）涵蓋：無RPE+已載入+未彈過→true；有RPE→false；未載入→false；已彈過→false。
- [ ] Step 3: 跑測試綠。

**Done Criteria:** 4 個 case 全綠。

---

### Task 3: WorkoutReflectionView（RPE + 心得合併畫面）

**Files:** Create `WorkoutReflectionView.swift`

- [ ] Step 1: 介面：
```swift
struct WorkoutReflectionView: View {
    let workoutId: String
    let typeName: String?
    let distanceText: String
    let date: Date
    let initialRPE: Int?
    let initialNotes: String?
    let onSaveRPE: (Int?) async -> Bool
    let onSaveNotes: (String) async -> Bool
}
```
- [ ] Step 2: 版面（NavigationStack + 取消/儲存）：
  - 頂部 context strip（沿用 RecapDiaryEditorView 的 contextStrip 樣式：類型·距離 + 日期 + 現選 RPE capsule）。
  - RPE 區：沿用 WorkoutRecapView 移除前的 1-10 色階 pill（`RecapPalette.rpe`），點選即更新本地 selectedRPE。
  - 心得區：沿用 RecapDiaryEditorView 的 promptSection（主題 chip 自動帶起頭）+ editorCard（textarea + 字數 + 「只有你看得到」）。
- [ ] Step 3: 儲存：按「儲存」時先 `onSaveRPE(selectedRPE)`（有改才呼叫）再 `onSaveNotes(notes)`；皆成功才 dismiss，否則顯示錯誤 alert。RPE 也可即點即存（沿用 recap 行為）。
- [ ] Step 4: i18n：標題 `訓練回顧`（key `workout.reflection.title`，三語）；其餘字串沿用既有 key（RPE 量表、心得 placeholder），缺的補三語。
- [ ] Step 5: build 通過。

**Done Criteria:** 一頁含 RPE 選擇 + 心得輸入，存得進 RPE 與 notes。

---

### Task 4: WorkoutDetailView 改接線

**Files:** Modify `WorkoutDetailViewV2.swift`

- [ ] Step 1: 移除 `showShareCardSheet` 對 `WorkoutShareCardSheetView` 的 `.sheet`；改為 present `WorkoutRecapView`：新增 `@State private var shareRecapContent: WorkoutRecapContent?`，工具列「分享訓練成果」按鈕改為 `shareRecapContent = WorkoutRecapContent.make(from: fullWorkout, isPremium: SubscriptionStateManager.shared.hasPremiumAccess, aiAnalysisOverride: viewModel.workoutDetail?.aiSummary?.analysis, rpeOverride: viewModel.currentRPE)`（`fullWorkout` 用 workout + detail 組，可參考 WorkoutShareCardSheetView.prepareFullWorkoutData 的組法），再 `.sheet(item: $shareRecapContent) { WorkoutRecapView(content: $0, showConfetti: false) }`。
- [ ] Step 2: RPE 按鈕（advancedMetricsCard 內，有/無 RPE 兩分支）與 TrainingNotesCard 的 onEdit → 都改為觸發 `showReflection = true`。移除 `showRPEEditor` + `showTrainingNotesEditor` 兩個 sheet 與 `RPEEditorView`/`TrainingNotesEditorView` 用法。
- [ ] Step 3: 新增 `.sheet(isPresented: $showReflection)` → `WorkoutReflectionView`，`onSaveRPE` 接 `viewModel.updateRPE` + 樂觀更新 `displayedRPE`，`onSaveNotes` 接 `viewModel.updateTrainingNotes` + 樂觀更新 `displayedTrainingNotes`（沿用現有 Task.tracked 包法）。
- [ ] Step 4: 自動彈：新增 `@State private var didAutoPromptReflection = false`。在 detail 載入完成處（`onChange(of: viewModel.workoutDetail != nil)` 與 `onAppear`）呼叫 helper：`if WorkoutReflectionGate.shouldAutoPrompt(hasRPE: viewModel.currentRPE != nil, detailLoaded: viewModel.workoutDetail != nil, alreadyPrompted: didAutoPromptReflection) { didAutoPromptReflection = true; showReflection = true }`。
- [ ] Step 5: 移除 init 內的 `print(...)` 調試碼。
- [ ] Step 6: build 通過。

**Done Criteria:** 分享走 recap 畫面（不撒花）；RPE/心得走合併畫面；首次進無 RPE 的 detail 會自動彈一次合併畫面、有 RPE 不彈、同次不重彈。

---

### Task 5: 刪除被取代的舊碼（gate：Task 1-4 build 綠後）

**Files:** Delete after grep-clean

- [ ] Step 1: grep 確認 0 production 引用（排除自身 + #Preview）：`WorkoutShareCardSheetView`、`WorkoutShareCardView`、`WorkoutShareCardViewModel`、`RPEEditorView`、`TrainingNotesEditorView`、`RecapDiaryEditorView`，及 ShareCard 專屬周邊（`TextOverlay`、`ShareCardSize`、`ShareCardLayoutMode`、`ShareCardTutorialOverlay`、`WorkoutShareCardData` 等若僅被刪檔引用）。
- [ ] Step 2: 逐一刪除確認 0 引用者；任何仍被引用的保留並回報。
- [ ] Step 3: build 通過 + 既有測試綠。

**Done Criteria:** 死碼移除、build 綠；無法安全刪的明列原因。

---

## Self-Review

- 涵蓋：分享統一(Task1+4)、撒花情境(Task1)、RPE+心得合併(Task3)、自動彈+測試保護(Task2+4)、清死碼(Task5)。
- 型別一致：`WorkoutReflectionView` 介面在 Task3 定義、Task4 使用一致；`WorkoutReflectionGate.shouldAutoPrompt` 簽章 Task2 定義、Task4 使用一致。
- 風險：刪除範圍大 → 用 grep gate + 獨立 Task 保護。`fullWorkout` 組法需含 detail 的 aiSummary/shareCardContent，否則分享卡缺文案。
