# 週回顧故事化 — iOS Block B Implementation Plan（兩頁版面 + story hero）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS 週回顧從「單頁長捲」改成**兩頁**(第一頁回顧本週、第二頁規劃下週),並在第一頁最上面 render 後端新欄位 `weekly_story` 的「本週的故事」hero。

**Architecture:** 沿用現有 DTO→Entity→Mapper→View 三層。新增 `WeeklyStory` DTO/Entity + Mapper 對應(additive optional,缺值降級);`WeeklySummaryV2View.loadedView` 的單一 `ScrollView` 改成 paged `TabView` 兩頁。**第二頁須整組搬 `AdjustmentsSectionV2`(含勾選)+ NL 輸入 + 行動按鈕,保住 apply→generate 順序**(紅隊 🟡-5)。

**Tech Stack:** Swift / SwiftUI / Codable / XCTest / Maestro。Build:iPhone 17 Pro。

**前置依賴:** 後端 Block A(`weekly_story` 欄位已上 dev)。本計畫可在 Block A 之後做;`weekly_story` 缺時第一頁不顯示 hero(=舊行為),不阻擋。

**Spec:** `cloud/api_service/docs/superpowers/specs/2026-06-25-weekly-review-story-design.md`(§3.1 兩頁 + §4 Block B)

**鐵律(iOS):**
- DTO 在 Data 層(snake_case + CodingKeys);Entity 在 Domain;Mapper 轉換。新欄位全 optional + `decodeIfPresent`,舊資料不炸。
- `thread` 在 iOS decode 成 `String?`(不硬解 enum;未知值不炸)——紅隊 🟢-6。
- View 只渲染、零業務邏輯。`.tracked(from:)` 不適用(無新 API call)。
- 驗收:**讀 code 不算測試**;必 build + 模擬器/Maestro 跑 + 截圖(iOS testing rule)。
- 不 deploy、不 auto-commit。

**v1 備註:** 後端 v1 仍會寫 `observations`(跑量漸進);本計畫第一頁同時保留 observations 區塊 + story hero(輕微重疊可接受),「observations 併入故事」的去重列 v2。

---

## File Structure

| 檔案 | 職責 | 動作 |
|---|---|---|
| `Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift` | 加 `WeeklyStoryDTO` + `weeklyStory` 欄位 + CodingKey | Modify |
| `Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift` | 加 `WeeklyStory` entity + `weeklyStory` 欄位 + CodingKey | Modify |
| `Features/TrainingPlanV2/Data/Mappers/WeeklySummaryV2Mapper.swift` | 加 `toWeeklyStory` + 主轉換接線 | Modify |
| `Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift` | story hero 元件 + 單頁 ScrollView → 兩頁 TabView | Modify |
| `HavitalTests/.../WeeklySummaryV2DTODecodeTests.swift` | DTO 解碼(缺值/有值/未知 thread) | Create |
| `HavitalTests/.../WeeklySummaryV2MapperTests.swift`（既有則追加） | Mapper weekly_story 對應 | Create/Modify |
| `.maestro/flows/weekly-review-two-page.yaml` | 兩頁切換 + hero 顯示 + 第二頁行動 | Create |

---

## Task 1: DTO 加 `weekly_story`

**Files:**
- Modify: `Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift`
- Test: `HavitalTests/Features/TrainingPlanV2/WeeklySummaryV2DTODecodeTests.swift`(Create)

- [ ] **Step 1: 寫失敗測試**

```swift
import XCTest
@testable import Havital

final class WeeklySummaryV2DTODecodeTests: XCTestCase {
    private func decode(_ json: String) throws -> WeeklySummaryV2DTO {
        try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: Data(json.utf8))
    }
    private let minimal = """
    {"id":"x_1_summary","week_of_training":1,
     "training_completion":{},"training_analysis":{},
     "weekly_highlights":{},"next_week_adjustments":{}}
    """

    func test_missing_weekly_story_is_nil() throws {
        let dto = try decode(minimal)
        XCTAssertNil(dto.weeklyStory)
    }
    func test_present_weekly_story_parsed() throws {
        let json = minimal.replacingOccurrences(
            of: "\"next_week_adjustments\":{}",
            with: "\"next_week_adjustments\":{},\"weekly_story\":{\"text\":\"你已連續 4 週守住節奏。\",\"thread\":\"consistency\"}")
        let dto = try decode(json)
        XCTAssertEqual(dto.weeklyStory?.text, "你已連續 4 週守住節奏。")
        XCTAssertEqual(dto.weeklyStory?.thread, "consistency")
    }
    func test_unknown_thread_does_not_crash() throws {
        let json = minimal.replacingOccurrences(
            of: "\"next_week_adjustments\":{}",
            with: "\"next_week_adjustments\":{},\"weekly_story\":{\"text\":\"x\",\"thread\":\"future_thread_v9\"}")
        let dto = try decode(json)
        XCTAssertEqual(dto.weeklyStory?.thread, "future_thread_v9") // thread 是 String，不炸
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HavitalTests/WeeklySummaryV2DTODecodeTests -parallel-testing-enabled NO`
Expected: FAIL（`weeklyStory` 不存在,編譯錯）

- [ ] **Step 3: 實作 DTO**

```swift
// WeeklySummaryV2DTO.swift：struct 內 observations 之後加
    let weeklyStory: WeeklyStoryDTO?
```
```swift
// CodingKeys enum 內 observations 之後加
        case weeklyStory = "weekly_story"
```
```swift
// 檔案末（struct 外）新增
struct WeeklyStoryDTO: Codable {
    let text: String?
    let thread: String?       // 不解成 enum：未知值不炸
    let callback: String?
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: commit**

```bash
git add Havital/Features/TrainingPlanV2/Data/DTOs/WeeklySummaryV2DTO.swift HavitalTests/Features/TrainingPlanV2/WeeklySummaryV2DTODecodeTests.swift
git commit -m "feat(weekly-story-ios): add weekly_story DTO (optional, string thread)"
```

---

## Task 2: Entity 加 `WeeklyStory`

**Files:**
- Modify: `Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift`

- [ ] **Step 1: 寫失敗測試**（複用 Mapper 測試,見 Task 3;此處先加 Entity 讓編譯過 + 一個建構測試）

```swift
// HavitalTests/.../WeeklySummaryV2EntityTests.swift
import XCTest
@testable import Havital
final class WeeklySummaryV2EntityTests: XCTestCase {
    func test_weekly_story_entity_constructs() {
        let s = WeeklyStory(text: "你已連續 4 週守住。", thread: "consistency", callback: nil)
        XCTAssertEqual(s.thread, "consistency")
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test ... -only-testing:HavitalTests/WeeklySummaryV2EntityTests ...`
Expected: FAIL（`WeeklyStory` 未定義）

- [ ] **Step 3: 實作 Entity**

```swift
// WeeklySummaryV2.swift：struct 內 observations 之後加
    /// 本週的故事（hero）
    let weeklyStory: WeeklyStory?
```
```swift
// CodingKeys enum 內 observations 之後加
        case weeklyStory = "weekly_story"
```
```swift
// 檔案內（同層 struct 外）新增
struct WeeklyStory: Codable {
    let text: String?
    let thread: String?
    let callback: String?
}
```

> 注意:`WeeklySummaryV2` 用 memberwise init(Mapper 呼叫),加欄位後 Task 3 的 Mapper 呼叫要補參數。

- [ ] **Step 4: 跑測試確認通過**

Run: 同 Step 2
Expected: PASS

- [ ] **Step 5: commit**

```bash
git add Havital/Features/TrainingPlanV2/Domain/Entities/WeeklySummaryV2.swift HavitalTests/Features/TrainingPlanV2/WeeklySummaryV2EntityTests.swift
git commit -m "feat(weekly-story-ios): add WeeklyStory entity"
```

---

## Task 3: Mapper 對應

**Files:**
- Modify: `Features/TrainingPlanV2/Data/Mappers/WeeklySummaryV2Mapper.swift`
- Test: `HavitalTests/Features/TrainingPlanV2/WeeklySummaryV2MapperTests.swift`(Create/追加)

- [ ] **Step 1: 寫失敗測試**

```swift
import XCTest
@testable import Havital
final class WeeklySummaryV2MapperTests: XCTestCase {
    func test_maps_weekly_story() throws {
        let json = """
        {"id":"x_1_summary","week_of_training":1,
         "training_completion":{},"training_analysis":{},
         "weekly_highlights":{},"next_week_adjustments":{},
         "weekly_story":{"text":"打底第 3 週，離賽事還有 13 週。","thread":"campaign"}}
        """
        let dto = try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: Data(json.utf8))
        let entity = WeeklySummaryV2Mapper.toEntity(from: dto)
        XCTAssertEqual(entity.weeklyStory?.thread, "campaign")
        XCTAssertEqual(entity.weeklyStory?.text, "打底第 3 週，離賽事還有 13 週。")
    }
    func test_nil_weekly_story_maps_nil() throws {
        let json = """
        {"id":"x_1_summary","week_of_training":1,"training_completion":{},
         "training_analysis":{},"weekly_highlights":{},"next_week_adjustments":{}}
        """
        let dto = try JSONDecoder().decode(WeeklySummaryV2DTO.self, from: Data(json.utf8))
        XCTAssertNil(WeeklySummaryV2Mapper.toEntity(from: dto).weeklyStory)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test ... -only-testing:HavitalTests/WeeklySummaryV2MapperTests ...`
Expected: FAIL（toEntity 缺 weeklyStory 參數 / 編譯錯）

- [ ] **Step 3: 實作 Mapper**

```swift
// WeeklySummaryV2Mapper.swift：toEntity(...) 內 observations 那行之後加
            observations: dto.observations,
            weeklyStory: dto.weeklyStory.map { toWeeklyStory(from: $0) }
```
（注意:把原本 `observations: dto.observations` 結尾逗號補上,新行接續。）
```swift
// Nested Conversions 區新增
    private static func toWeeklyStory(from dto: WeeklyStoryDTO) -> WeeklyStory {
        WeeklyStory(text: dto.text, thread: dto.thread, callback: dto.callback)
    }
```

- [ ] **Step 4: 跑測試確認通過**

Run: 同 Step 2
Expected: PASS（2 tests）

- [ ] **Step 5: commit**

```bash
git add Havital/Features/TrainingPlanV2/Data/Mappers/WeeklySummaryV2Mapper.swift HavitalTests/Features/TrainingPlanV2/WeeklySummaryV2MapperTests.swift
git commit -m "feat(weekly-story-ios): map weekly_story DTO→Entity"
```

---

## Task 4: story hero 元件

**Files:**
- Modify: `Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`

- [ ] **Step 1: 加 hero 元件(放 loadedView 之外的 private func)**

```swift
// WeeklySummaryV2View.swift：新增
    @ViewBuilder
    private func storyHeroView(_ story: WeeklyStory) -> some View {
        if let text = story.text, !text.isEmpty {
            HStack(alignment: .top, spacing: Layout.iconSpacing) {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.blue)
                    .font(AppFont.headline())
                    .frame(width: 20)
                Text(text)
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)
            .accessibilityIdentifier("v2.summary.story_hero")
        }
    }
```

- [ ] **Step 2: build 驗證編譯**

Run: `xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED（元件尚未被呼叫,Task 5 接入）

- [ ] **Step 3: commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift
git commit -m "feat(weekly-story-ios): add story hero view component"
```

---

## Task 5: 單頁 ScrollView → 兩頁 TabView（保住行動耦合）

**Files:**
- Modify: `Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift`(改 `loadedView`,line 95-179)

- [ ] **Step 1: 加分頁 state**

```swift
// WeeklySummaryV2View.swift：與既有 @State expandedSections 同層
    @State private var currentPage: Int = 0
```

- [ ] **Step 2: 把 loadedView 改成兩頁 TabView**（整段替換 line 95-179 的 loadedView body）

```swift
    private func loadedView(summary: WeeklySummaryV2) -> some View {
        TabView(selection: $currentPage) {
            reviewPage(summary: summary).tag(0)        // 第一頁：回顧本週
            planNextPage(summary: summary).tag(1)      // 第二頁：規劃下週
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .accessibilityIdentifier("v2.summary.loaded_content")
    }

    // 第一頁：回顧本週（story hero + 完成度 + 亮點 + 觀察 + 分析）
    private func reviewPage(summary: WeeklySummaryV2) -> some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                if let story = summary.weeklyStory { storyHeroView(story) }
                CompletionSectionV2(completion: summary.trainingCompletion)
                CollapsibleSectionV2(
                    id: .highlights, icon: "star.fill", iconColor: .yellow,
                    title: NSLocalizedString("training.highlights", comment: "本週亮點"),
                    preview: highlightsPreview(summary.weeklyHighlights),
                    accessibilityIdentifier: "v2.summary.highlights_toggle",
                    expandedSections: $expandedSections
                ) { HighlightsSectionV2(highlights: summary.weeklyHighlights, showImprovements: true).padding(.top, 8) }
                if let observations = summary.observations, !observations.isEmpty {
                    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                        ForEach(observations, id: \.self) { obs in
                            HStack(alignment: .top, spacing: Layout.iconSpacing) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.blue).font(AppFont.caption()).frame(width: 16)
                                Text(obs).font(AppFont.subheadline()).foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }.padding(.horizontal)
                }
                CollapsibleSectionV2(
                    id: .analysis, icon: "chart.bar.fill", iconColor: .purple,
                    title: NSLocalizedString("training.analysis", comment: "訓練分析"),
                    preview: analysisPreview(summary.trainingAnalysis),
                    accessibilityIdentifier: "v2.summary.analysis_toggle",
                    expandedSections: $expandedSections
                ) { AnalysisSectionV2(analysis: summary.trainingAnalysis).padding(.top, 8) }
            }
            .padding(.horizontal).padding(.vertical, 16)
        }
    }

    // 第二頁：規劃下週（下週調整 + NL/Rizo + 行動按鈕）——整組搬，保住 apply→generate
    private func planNextPage(summary: WeeklySummaryV2) -> some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                CollapsibleSectionV2(
                    id: .nextWeek, icon: "arrow.triangle.2.circlepath", iconColor: .blue,
                    title: NSLocalizedString("training.next_week_adjustments", comment: "下週調整建議"),
                    preview: nextWeekPreview(summary.nextWeekAdjustments),
                    accessibilityIdentifier: "v2.summary.next_week_toggle",
                    expandedSections: $expandedSections
                ) {
                    VStack(spacing: Layout.contentSpacing) {
                        if !summary.weeklyHighlights.areasForImprovement.isEmpty {
                            ImprovementsSectionV2(areas: summary.weeklyHighlights.areasForImprovement)
                        }
                        AdjustmentsSectionV2(
                            adjustments: summary.nextWeekAdjustments,
                            coordinator: viewModel.summary,
                            showToggles: onGenerateNextWeek != nil
                        )
                    }.padding(.top, 8)
                }
                actionButtonsView(summary: summary)   // 產生下週課表 / 設定新目標,順序與耦合不變
            }
            .padding(.horizontal).padding(.vertical, 16)
        }
    }
```

> ⚠️ 紅隊 🟡-5:`AdjustmentsSectionV2`(含勾選,綁 `viewModel.summary`)+ `actionButtonsView`(`onGenerateNextWeek`/`onSetNewGoal`)整組搬到第二頁,**不改參數、不改 generateButtonText / applySelectedAdjustments 接線**(在 `TrainingPlanV2View.swift:544-568`)。預設停第一頁(`currentPage=0`),但第二頁 CTA 要可達。

- [ ] **Step 3: build**

Run: `xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/WeeklySummaryV2View.swift
git commit -m "feat(weekly-story-ios): split weekly review into 2 pages (review / plan-next)"
```

---

## Task 6: Maestro 兩頁 UI 驗證（iOS testing rule：必跑模擬器）

**Files:**
- Create: `.maestro/flows/weekly-review-two-page.yaml`

- [ ] **Step 1: 寫 flow**（沿用 `weekly-review-nl-input.yaml` 的導航到週回顧,加兩頁斷言）

```yaml
appId: com.havital.Havital.dev
---
- launchApp: { stopApp: true, clearState: false, arguments: { -skipHealthKitAuth: "true" } }
- tapOn: { id: "AnnouncementPopup_CloseButton", optional: true }
- tapOn: { text: "Plan|計劃|計畫|プラン", optional: true }
- tapOn: { text: "Plan|計劃|計畫|プラン", optional: true }
- extendedWaitUntil: { visible: { id: "ellipsis.circle" }, timeout: 15000 }
- tapOn: { id: "ellipsis.circle" }
- tapOn: "🐛 Debug 工具"
- tapOn: "🐛 產生週回顧"
- extendedWaitUntil: { visible: "訓練完成度|Completion", timeout: 90000 }
# 第一頁：story hero + 完成度可見，下週調整不在第一頁
- assertVisible: { id: "v2.summary.story_hero" }
- assertVisible: "訓練完成度|Completion"
- takeScreenshot: weekly_review_page1
# 滑到第二頁
- swipe: { direction: LEFT }
- assertVisible: "下週調整建議|Next Week Adjustments"
- takeScreenshot: weekly_review_page2
```

- [ ] **Step 2: 跑 flow + 看截圖**

Run: `maestro test .maestro/flows/weekly-review-two-page.yaml`
Expected: 全 step PASS;page1 截圖見 story hero(藍底)在最上、完成度在下;page2 見下週調整 + 產生按鈕。

> 若 `v2.summary.story_hero` 不可見:先確認該 dev 帳號 `weekly_story` 有值(後端 Block A 已上 dev + 該週型有命中);無命中週型→hero 本就不顯示(非 bug,換有命中的帳號/週驗)。

- [ ] **Step 3: 人工確認(classify)**

依 iOS QA 格式:測試方法(本 flow)+ 兩張截圖 + classify(app/script/env)。視覺對齊待 Designer/user sign-off(不可自評「視覺 OK」)。

- [ ] **Step 4: commit**

```bash
git add .maestro/flows/weekly-review-two-page.yaml
git commit -m "test(weekly-story-ios): maestro two-page weekly review flow"
```

---

## Self-Review（對 spec §3.1 / §4 Block B）

- **Spec 覆蓋**:兩頁(Task 5)/ story hero render(Task 4+5)/ DTO·Entity·Mapper additive(Task 1-3)/ thread 字串容錯(Task 1)/ 第二頁整組搬+耦合保留(Task 5 紅隊註)/ 模擬器驗證(Task 6)。
- **缺值降級**:`weekly_story` nil → 第一頁無 hero(Task 5 `if let story`)。✅
- **Placeholder**:無 TBD;每個 code step 有實碼。
- **型別一致**:`WeeklyStoryDTO(text,thread,callback)` ↔ `WeeklyStory(text,thread,callback)`;Mapper `toWeeklyStory`;View `storyHeroView(_:)` / `reviewPage` / `planNextPage` 前後一致。
- **已知待確認**:① `AdjustmentsSectionV2` / `actionButtonsView` / `onGenerateNextWeek` 為現有成員,Task 5 只搬位置不改簽名——執行時若 view 取得 `onGenerateNextWeek` 的方式與假設不符,對齊現有宣告即可;② TabView paged 樣式在長內容下的捲動體感,Task 6 模擬器確認;③「observations 併入故事去重」列 v2,不在本計畫。
