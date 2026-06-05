# Apple Watch 精簡核心版 — watchOS App 本體（Plan C）實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `HavitalWatch` watchOS app，讓使用者在錶上啟動今日課表（暖身/間歇/組合/緩和 + RPE），並以對齊內建跑步 App 的格式寫入 Apple Health。

**Architecture:** 沿用 iOS 既有分層 `Presentation → Domain → Data → Core`。Domain 為 framework-pure 純邏輯（可單元測）；Data/Infra 包 HealthKit / WatchConnectivity；Presentation 為 SwiftUI。對接 iPhone 端（Plan B）的唯一介面是 WCSession 單日 snapshot（下行）與 HealthKit metadata（上行）。

**Tech Stack:** Swift / SwiftUI / watchOS 10.0+ / HealthKit (`HKLiveWorkoutBuilder`) / WatchConnectivity / WidgetKit / XCTest

**依據 spec:** `docs/superpowers/specs/2026-06-05-apple-watch-mvp-lean-design.md`

---

## ⚠️ 實作前必讀聲明

1. **這是 backlog plan**：觸發條件為 Android 主線上線穩定後。啟動實作前，下列 framework 細節必須先 spike 對齊「當下 watchOS 版本」的 API（TD-apple-watch-app-mvp [TBD-IMPL]）：
   - `HKLiveWorkoutBuilder` 暫停期間 distance/time 累計行為
   - HealthKit metadata 經 sync 到 iPhone 端 `HKWorkout.metadata` 的可靠度與延遲
   - `.segment` event 寫入後 iPhone parser 是否解得到（連動 Plan B）
2. **TDD 範圍**：Task 2–10（Domain / Core 純邏輯）採嚴格 TDD，本檔給完整 test + 實作 code。Task 1、11–17（target / HealthKit / WCSession / SwiftUI / complication）給實作骨架 + 模擬器驗證步驟；骨架中標 `// SPIKE:` 的行需啟動時對齊 API。
3. **模擬器驗證 loop（每個 UI task 收尾必跑，缺一步即 stale 假畫面）**：
   `xcodebuild build → install watchOS app → terminate 既有 process → launch → screenshot`。
4. **不可繞過 HealthKit**：本 app 一律透過 `HKLiveWorkoutBuilder` 寫 Apple Health，禁止直接 call Paceriz API。

---

## File Structure

```
HavitalWatch/                                  ← 新 watchOS app target
  App/
    HavitalWatchApp.swift                      @main，App 入口 + WCSession 啟動
  Domain/                                      ← framework-pure（不 import HealthKit/WatchKit）
    Entities/
      WatchSegment.swift                       主段單元（kind/measure/target/pace/rep）
      WatchPlanSnapshot.swift                  今日課表 domain entity
      WorkoutFlowType.swift                    分流：directStart / warmupMainCooldown / rest / unsupported
      ActiveSegmentEvent.swift                 引擎輸出事件
    SegmentTransitionEngine.swift              主段自動切換 + 5 秒倒數判定（核心）
    WorkoutLauncher.swift                      啟動前置檢查（precondition gate）
    ActiveWorkoutSession.swift                 訓練狀態機（freeze / pause 累計 / 階段）
  Data/
    DTOs/
      WatchPlanSnapshotDTO.swift               WCSession 線上格式（snake_case）
    WorkoutSnapshotStore.swift                 snapshot 存取 + 今日邊界判定
    LocalSnapshotCache.swift                   UserDefaults 持久化
    WCSessionClient.swift                      收 iPhone 單日 snapshot / auth
    HealthKit/
      WorkoutUUIDValidator.swift               uuid v4 fail-fast 驗證
      HKLiveWorkoutBuilderWrapper.swift        workout session + 寫 route/HR/.segment/.pause + metadata
    PermissionGate.swift                       HealthKit/Location/Motion 權限
    HapticPlayer.swift                         震動 + 嗶
  Core/
    RPEFeedback.swift                          1-10 → 體感文字
  Presentation/
    TodayWorkoutView.swift / WelcomeView.swift
    EasyRunMetricsView.swift / IntervalMetricsView.swift / WarmupCooldownView.swift
    WorkoutControlView.swift / RPEView.swift / WorkoutSummaryView.swift / PermissionView.swift
    ViewModels/
      TodayWorkoutViewModel.swift / ActiveWorkoutViewModel.swift
  Complication/
    PacerizComplicationProvider.swift          WidgetKit corner/circular

HavitalWatchTests/                             ← 新 watchOS unit test target
  WorkoutFlowTypeTests.swift
  WatchPlanSnapshotDTOTests.swift
  WorkoutUUIDValidatorTests.swift
  RPEFeedbackTests.swift
  SegmentTransitionEngineTests.swift
  WorkoutLauncherTests.swift
  WorkoutSnapshotStoreTests.swift
  ActiveWorkoutSessionTests.swift
```

---

## Task 1: 建立 watchOS target 與測試 target

**Files:**
- Create: `HavitalWatch/App/HavitalWatchApp.swift`
- Modify: `Havital.xcodeproj/project.pbxproj`（Xcode 自動）

- [ ] **Step 1: 在 Xcode 新增 watchOS App target**

File → New → Target → watchOS → App。Product Name: `HavitalWatch`，Interface: SwiftUI，
Language: Swift，勾「Include Tests」（產生 `HavitalWatchTests`）。Bundle ID: `com.havital.paceriz.watchkitapp`。
Deployment Target: watchOS 10.0。

- [ ] **Step 2: 寫最小 App 入口**

```swift
// HavitalWatch/App/HavitalWatchApp.swift
import SwiftUI

@main
struct HavitalWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Paceriz")   // 暫時佔位，Task 15 換成 TodayWorkoutView
        }
    }
}
```

- [ ] **Step 3: 設定 signing + capabilities**

Signing & Capabilities → 選 team；加 **HealthKit** capability（含 Background Delivery）。
Info.plist 加：`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` /
`NSLocationWhenInUseUsageDescription` / `NSMotionUsageDescription`（值走 i18n）。

- [ ] **Step 4: build 確認 target 可編譯**

Run: `xcodebuild build -project Havital.xcodeproj -scheme HavitalWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch Havital.xcodeproj
git commit -m "iOS Developer: scaffold HavitalWatch watchOS target (Plan C Task 1)"
```

---

## Task 2: WorkoutFlowType 課表分流

**Files:**
- Create: `HavitalWatch/Domain/Entities/WorkoutFlowType.swift`
- Test: `HavitalWatchTests/WorkoutFlowTypeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// HavitalWatchTests/WorkoutFlowTypeTests.swift
import XCTest
@testable import HavitalWatch

final class WorkoutFlowTypeTests: XCTestCase {
    func test_easyTypes_areDirectStart() {
        for t in ["easy_run", "easy", "long_run", "lsd", "recovery_run"] {
            XCTAssertEqual(WorkoutFlowType(runType: t), .directStart, "\(t)")
        }
    }
    func test_structuredTypes_areWarmupMainCooldown() {
        for t in ["interval", "combination", "tempo", "threshold", "progression", "benchmark", "race"] {
            XCTAssertEqual(WorkoutFlowType(runType: t), .warmupMainCooldown, "\(t)")
        }
    }
    func test_rest_isRest() {
        XCTAssertEqual(WorkoutFlowType(runType: "rest"), .rest)
    }
    func test_nonRunning_isUnsupported() {
        for t in ["strength", "yoga", "cycling", "hiking", "cross_training"] {
            XCTAssertEqual(WorkoutFlowType(runType: t), .unsupported, "\(t)")
        }
    }
    func test_unknownType_defaultsToRest() {     // 對齊 iOS 寬鬆解碼契約
        XCTAssertEqual(WorkoutFlowType(runType: "wat_is_this"), .rest)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Havital.xcodeproj -scheme HavitalWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' -only-testing:HavitalWatchTests/WorkoutFlowTypeTests`
Expected: FAIL（`WorkoutFlowType` 未定義 → 編譯失敗）

- [ ] **Step 3: Write minimal implementation**

```swift
// HavitalWatch/Domain/Entities/WorkoutFlowType.swift
enum WorkoutFlowType: Equatable {
    case directStart            // 輕鬆類：無暖身緩和
    case warmupMainCooldown     // 結構化：open 暖身 → 主段 → open 緩和
    case rest                   // 休息日：禁啟動
    case unsupported            // 非跑步類：引導回 iPhone

    init(runType: String) {
        switch runType {
        case "easy_run", "easy", "long_run", "lsd", "recovery_run":
            self = .directStart
        case "interval", "combination", "tempo", "threshold", "progression", "benchmark", "race":
            self = .warmupMainCooldown
        case "rest":
            self = .rest
        case "strength", "yoga", "cycling", "hiking", "cross_training":
            self = .unsupported
        default:
            self = .rest        // 未知 run_type → 視為 rest（不啟動），對齊 iOS DayType(rawValue:) ?? .rest
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch/Domain/Entities/WorkoutFlowType.swift HavitalWatchTests/WorkoutFlowTypeTests.swift
git commit -m "iOS Developer: WorkoutFlowType run_type 分流 (Plan C Task 2)"
```

---

## Task 3: WatchPlanSnapshotDTO 解碼 → entity

**Files:**
- Create: `HavitalWatch/Domain/Entities/WatchSegment.swift`
- Create: `HavitalWatch/Domain/Entities/WatchPlanSnapshot.swift`
- Create: `HavitalWatch/Data/DTOs/WatchPlanSnapshotDTO.swift`
- Test: `HavitalWatchTests/WatchPlanSnapshotDTOTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// HavitalWatchTests/WatchPlanSnapshotDTOTests.swift
import XCTest
@testable import HavitalWatch

final class WatchPlanSnapshotDTOTests: XCTestCase {
    private let json = """
    {
      "date": "2026-06-05",
      "run_type": "interval",
      "total_distance_meters": 6400,
      "total_seconds": null,
      "plan_id": "plan_abc",
      "segments": [
        {"kind":"run","measure":"distance","target_meters":800,"target_seconds":null,
         "pace_low_sec_per_km":270,"pace_high_sec_per_km":290,"label":"800m","rep_index":1,"rep_total":5},
        {"kind":"rest","measure":"time","target_meters":null,"target_seconds":120,
         "pace_low_sec_per_km":null,"pace_high_sec_per_km":null,"label":"休息","rep_index":1,"rep_total":5}
      ]
    }
    """.data(using: .utf8)!

    func test_decodesDTOAndMapsToEntity() throws {
        let dto = try JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: json)
        let entity = dto.toEntity()
        XCTAssertEqual(entity.date, "2026-06-05")
        XCTAssertEqual(entity.flowType, .warmupMainCooldown)
        XCTAssertEqual(entity.totalDistanceMeters, 6400)
        XCTAssertEqual(entity.segments.count, 2)
        XCTAssertEqual(entity.segments[0].kind, .run)
        XCTAssertEqual(entity.segments[0].measure, .distance)
        XCTAssertEqual(entity.segments[0].targetMeters, 800)
        XCTAssertEqual(entity.segments[0].paceLowSecPerKm, 270)
        XCTAssertEqual(entity.segments[0].repIndex, 1)
        XCTAssertEqual(entity.segments[1].kind, .rest)
        XCTAssertEqual(entity.segments[1].targetSeconds, 120)
    }

    func test_unknownSegmentKind_fallsBackToRun() throws {
        let bad = #"{"date":"2026-06-05","run_type":"interval","plan_id":"p","segments":[{"kind":"weird","measure":"distance","target_meters":400,"label":"x"}]}"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: bad)
        XCTAssertEqual(dto.toEntity().segments[0].kind, .run)   // 未知 kind 安全 fallback
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（型別未定義）

- [ ] **Step 3: Write entity**

```swift
// HavitalWatch/Domain/Entities/WatchSegment.swift
struct WatchSegment: Equatable {
    enum Kind { case warmup, run, rest, cooldown, work }   // work：漸速/全力等連續單段
    enum Measure { case distance, time }
    let kind: Kind
    let measure: Measure
    let targetMeters: Double?
    let targetSeconds: Int?
    let paceLowSecPerKm: Int?
    let paceHighSecPerKm: Int?
    let label: String
    let repIndex: Int?
    let repTotal: Int?
}
```

```swift
// HavitalWatch/Domain/Entities/WatchPlanSnapshot.swift
struct WatchPlanSnapshot: Equatable {
    let date: String                // yyyy-MM-dd（local）
    let flowType: WorkoutFlowType
    let totalDistanceMeters: Double?
    let totalSeconds: Int?
    let planId: String
    let segments: [WatchSegment]    // 僅「真正主段」；暖身/緩和不在此（open 由 app 補）
}
```

- [ ] **Step 4: Write DTO + mapper**

```swift
// HavitalWatch/Data/DTOs/WatchPlanSnapshotDTO.swift
import Foundation

struct WatchSegmentDTO: Codable {
    let kind: String
    let measure: String
    let targetMeters: Double?
    let targetSeconds: Int?
    let paceLowSecPerKm: Int?
    let paceHighSecPerKm: Int?
    let label: String
    let repIndex: Int?
    let repTotal: Int?
    enum CodingKeys: String, CodingKey {
        case kind, measure, label
        case targetMeters = "target_meters"
        case targetSeconds = "target_seconds"
        case paceLowSecPerKm = "pace_low_sec_per_km"
        case paceHighSecPerKm = "pace_high_sec_per_km"
        case repIndex = "rep_index"
        case repTotal = "rep_total"
    }
}

struct WatchPlanSnapshotDTO: Codable {
    let date: String
    let runType: String
    let totalDistanceMeters: Double?
    let totalSeconds: Int?
    let planId: String
    let segments: [WatchSegmentDTO]
    enum CodingKeys: String, CodingKey {
        case date, segments
        case runType = "run_type"
        case totalDistanceMeters = "total_distance_meters"
        case totalSeconds = "total_seconds"
        case planId = "plan_id"
    }

    func toEntity() -> WatchPlanSnapshot {
        WatchPlanSnapshot(
            date: date,
            flowType: WorkoutFlowType(runType: runType),
            totalDistanceMeters: totalDistanceMeters,
            totalSeconds: totalSeconds,
            planId: planId,
            segments: segments.map { s in
                WatchSegment(
                    kind: Self.mapKind(s.kind),
                    measure: s.measure == "time" ? .time : .distance,
                    targetMeters: s.targetMeters,
                    targetSeconds: s.targetSeconds,
                    paceLowSecPerKm: s.paceLowSecPerKm,
                    paceHighSecPerKm: s.paceHighSecPerKm,
                    label: s.label,
                    repIndex: s.repIndex,
                    repTotal: s.repTotal
                )
            }
        )
    }

    private static func mapKind(_ raw: String) -> WatchSegment.Kind {
        switch raw {
        case "warmup": return .warmup
        case "rest": return .rest
        case "cooldown": return .cooldown
        case "work": return .work
        default: return .run        // 未知 kind 安全 fallback
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes** — Expected: PASS（2 tests）

- [ ] **Step 6: Commit**

```bash
git add HavitalWatch/Domain/Entities/WatchSegment.swift HavitalWatch/Domain/Entities/WatchPlanSnapshot.swift HavitalWatch/Data/DTOs/WatchPlanSnapshotDTO.swift HavitalWatchTests/WatchPlanSnapshotDTOTests.swift
git commit -m "iOS Developer: WatchPlanSnapshot DTO 解碼 + mapper (Plan C Task 3)"
```

---

## Task 4: WorkoutUUIDValidator（防線 1 fail-fast）

**Files:**
- Create: `HavitalWatch/Data/HealthKit/WorkoutUUIDValidator.swift`
- Test: `HavitalWatchTests/WorkoutUUIDValidatorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// HavitalWatchTests/WorkoutUUIDValidatorTests.swift
import XCTest
@testable import HavitalWatch

final class WorkoutUUIDValidatorTests: XCTestCase {
    func test_validV4_passes() {
        XCTAssertTrue(WorkoutUUIDValidator.isValid("9b2e4f1a-3c4d-4e5f-8a9b-0c1d2e3f4a5b"))
    }
    func test_empty_fails() { XCTAssertFalse(WorkoutUUIDValidator.isValid("")) }
    func test_wrongVersion_fails() {     // 第三組非 4 開頭
        XCTAssertFalse(WorkoutUUIDValidator.isValid("9b2e4f1a-3c4d-1e5f-8a9b-0c1d2e3f4a5b"))
    }
    func test_uppercase_fails() {        // regex 只收小寫
        XCTAssertFalse(WorkoutUUIDValidator.isValid("9B2E4F1A-3C4D-4E5F-8A9B-0C1D2E3F4A5B"))
    }
    func test_generatedUUID_isValid() {  // 產生器產出必過驗證
        XCTAssertTrue(WorkoutUUIDValidator.isValid(WorkoutUUIDValidator.generate()))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（未定義）

- [ ] **Step 3: Write implementation**

```swift
// HavitalWatch/Data/HealthKit/WorkoutUUIDValidator.swift
import Foundation

enum WorkoutUUIDValidator {
    static let metadataKey = "com.paceriz.workout_uuid"
    private static let regex = try! NSRegularExpression(
        pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    )
    static func isValid(_ uuid: String) -> Bool {
        guard !uuid.isEmpty else { return false }
        let range = NSRange(uuid.startIndex..., in: uuid)
        return regex.firstMatch(in: uuid, range: range) != nil
    }
    static func generate() -> String {
        UUID().uuidString.lowercased()   // Foundation 產 v4，小寫後符合 regex
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch/Data/HealthKit/WorkoutUUIDValidator.swift HavitalWatchTests/WorkoutUUIDValidatorTests.swift
git commit -m "iOS Developer: WorkoutUUIDValidator v4 fail-fast (Plan C Task 4)"
```

---

## Task 5: RPEFeedback（1-10 → 體感文字）

**Files:**
- Create: `HavitalWatch/Core/RPEFeedback.swift`
- Test: `HavitalWatchTests/RPEFeedbackTests.swift`

- [ ] **Step 1: Write the failing test**（四級邊界對齊 iOS recap）

```swift
// HavitalWatchTests/RPEFeedbackTests.swift
import XCTest
@testable import HavitalWatch

final class RPEFeedbackTests: XCTestCase {
    func test_lowBand_1to3() {
        for v in 1...3 { XCTAssertEqual(RPEFeedback.text(for: v), "輕巧地完成") }
    }
    func test_mediumBand_4to5() {
        for v in 4...5 { XCTAssertEqual(RPEFeedback.text(for: v), "節奏掌握得不錯") }
    }
    func test_highBand_6to7() {
        for v in 6...7 { XCTAssertEqual(RPEFeedback.text(for: v), "紮實的一次") }
    }
    func test_maxBand_8to10() {
        for v in 8...10 { XCTAssertEqual(RPEFeedback.text(for: v), "硬仗打完了") }
    }
}
```

> 註：實作用 `NSLocalizedString`，此測試在 zh-TW 環境跑（CI locale 設 zh-TW）。i18n key 與 iOS 共用：`workout.rpe.feedback.{low,medium,high,max}`。

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（未定義）

- [ ] **Step 3: Write implementation**

```swift
// HavitalWatch/Core/RPEFeedback.swift
import Foundation

enum RPEFeedback {
    /// RPE 1-10 → 體感文字（沿用 iOS WorkoutReflectionView 四級）
    static func text(for rpe: Int) -> String {
        switch rpe {
        case ...3:  return NSLocalizedString("workout.rpe.feedback.low", comment: "輕巧地完成")
        case 4...5: return NSLocalizedString("workout.rpe.feedback.medium", comment: "節奏掌握得不錯")
        case 6...7: return NSLocalizedString("workout.rpe.feedback.high", comment: "紮實的一次")
        default:    return NSLocalizedString("workout.rpe.feedback.max", comment: "硬仗打完了")
        }
    }
}
```

- [ ] **Step 4: 在 watch Localizable.xcstrings 補 4 個 key**（zh-TW 值如上、en-US / ja-JP 對齊 iOS 既有翻譯）。

- [ ] **Step 5: Run test to verify it passes** — Expected: PASS（4 tests）

- [ ] **Step 6: Commit**

```bash
git add HavitalWatch/Core/RPEFeedback.swift HavitalWatchTests/RPEFeedbackTests.swift HavitalWatch/Core/*.xcstrings
git commit -m "iOS Developer: RPEFeedback 1-10 體感文字對齊 iOS recap (Plan C Task 5)"
```

---

## Task 6: SegmentTransitionEngine — 自動切段

**Files:**
- Create: `HavitalWatch/Domain/Entities/ActiveSegmentEvent.swift`
- Create: `HavitalWatch/Domain/SegmentTransitionEngine.swift`
- Test: `HavitalWatchTests/SegmentTransitionEngineTests.swift`

> 引擎只處理「主段陣列」（暖身/緩和是 open，不進引擎）。輸入為整場累計值；輸出事件序列。
> 嚴格距離門檻（不放水 5%）。暫停時不前進。

- [ ] **Step 1: Write the failing test（切段 + 完成）**

```swift
// HavitalWatchTests/SegmentTransitionEngineTests.swift
import XCTest
@testable import HavitalWatch

final class SegmentTransitionEngineTests: XCTestCase {
    private func seg(_ kind: WatchSegment.Kind, _ measure: WatchSegment.Measure,
                    m: Double? = nil, s: Int? = nil) -> WatchSegment {
        WatchSegment(kind: kind, measure: measure, targetMeters: m, targetSeconds: s,
                     paceLowSecPerKm: nil, paceHighSecPerKm: nil, label: "x", repIndex: nil, repTotal: nil)
    }

    func test_distanceSegment_advancesAtTarget() {
        let engine = SegmentTransitionEngine(segments: [seg(.run, .distance, m: 800),
                                                        seg(.rest, .time, s: 120)])
        // 未達標：不切
        XCTAssertEqual(engine.update(totalMeters: 799, totalSeconds: 200, recentSpeedMps: 4, isPaused: false), [])
        XCTAssertEqual(engine.currentIndex, 0)
        // 達標：切到 index 1
        let events = engine.update(totalMeters: 800, totalSeconds: 201, recentSpeedMps: 4, isPaused: false)
        XCTAssertEqual(events, [.advanced(toIndex: 1)])
        XCTAssertEqual(engine.currentIndex, 1)
    }

    func test_timeSegment_advancesAtTargetSeconds() {
        let engine = SegmentTransitionEngine(segments: [seg(.rest, .time, s: 120),
                                                        seg(.run, .distance, m: 800)])
        // 段起點在 totalSeconds=10；跑到 130s = 該段 120s 達標
        _ = engine.update(totalMeters: 0, totalSeconds: 10, recentSpeedMps: 0, isPaused: false)
        let events = engine.update(totalMeters: 0, totalSeconds: 130, recentSpeedMps: 0, isPaused: false)
        XCTAssertEqual(events, [.advanced(toIndex: 1)])
    }

    func test_lastSegment_emitsFinished() {
        let engine = SegmentTransitionEngine(segments: [seg(.run, .distance, m: 400)])
        let events = engine.update(totalMeters: 400, totalSeconds: 100, recentSpeedMps: 4, isPaused: false)
        XCTAssertEqual(events, [.finished])
    }

    func test_paused_doesNotAdvance() {
        let engine = SegmentTransitionEngine(segments: [seg(.run, .distance, m: 400), seg(.rest, .time, s: 60)])
        XCTAssertEqual(engine.update(totalMeters: 500, totalSeconds: 100, recentSpeedMps: 4, isPaused: true), [])
        XCTAssertEqual(engine.currentIndex, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（未定義）

- [ ] **Step 3: Write event + engine（先不含倒數，Task 7 再加）**

```swift
// HavitalWatch/Domain/Entities/ActiveSegmentEvent.swift
enum ActiveSegmentEvent: Equatable {
    case countdownCue            // 切換前 5 秒
    case advanced(toIndex: Int)  // 進入下一段
    case finished                // 主段全部完成
}
```

```swift
// HavitalWatch/Domain/SegmentTransitionEngine.swift
final class SegmentTransitionEngine {
    let segments: [WatchSegment]
    private(set) var currentIndex: Int = 0
    private var segmentStartMeters: Double = 0
    private var segmentStartSeconds: Int = 0
    private var countdownLatched = false   // Task 7 使用

    init(segments: [WatchSegment]) { self.segments = segments }

    /// 吃整場累計值，回傳本 tick 事件。
    func update(totalMeters: Double, totalSeconds: Int,
                recentSpeedMps: Double, isPaused: Bool) -> [ActiveSegmentEvent] {
        guard !isPaused, currentIndex < segments.count else { return [] }
        let seg = segments[currentIndex]
        let metersInSeg = totalMeters - segmentStartMeters
        let secondsInSeg = totalSeconds - segmentStartSeconds

        let reached: Bool
        switch seg.measure {
        case .distance: reached = metersInSeg >= (seg.targetMeters ?? .infinity)
        case .time:     reached = secondsInSeg >= (seg.targetSeconds ?? .max)
        }
        guard reached else { return [] }

        // 切段
        if currentIndex == segments.count - 1 {
            currentIndex += 1
            return [.finished]
        }
        currentIndex += 1
        segmentStartMeters = totalMeters
        segmentStartSeconds = totalSeconds
        countdownLatched = false
        return [.advanced(toIndex: currentIndex)]
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS（4 tests）

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch/Domain/Entities/ActiveSegmentEvent.swift HavitalWatch/Domain/SegmentTransitionEngine.swift HavitalWatchTests/SegmentTransitionEngineTests.swift
git commit -m "iOS Developer: SegmentTransitionEngine 嚴格距離/時間自動切段 (Plan C Task 6)"
```

---

## Task 7: SegmentTransitionEngine — 切換前 5 秒倒數

**Files:**
- Modify: `HavitalWatch/Domain/SegmentTransitionEngine.swift`
- Test: `HavitalWatchTests/SegmentTransitionEngineTests.swift`（加 case）

> 規則：時間型剩餘 ≤ 5s 觸發；距離型用 `recentSpeedMps` 推估剩餘時間 ≤ 5s 觸發；同段 latch 不重複。

- [ ] **Step 1: Write the failing test**

```swift
extension SegmentTransitionEngineTests {
    func test_timeSegment_countdownAt5sRemaining() {
        let engine = SegmentTransitionEngine(segments: [seg(.rest, .time, s: 60), seg(.run, .distance, m: 400)])
        // 段內 54s：剩 6s，不觸發
        XCTAssertEqual(engine.update(totalMeters: 0, totalSeconds: 54, recentSpeedMps: 0, isPaused: false), [])
        // 段內 55s：剩 5s，觸發一次
        XCTAssertEqual(engine.update(totalMeters: 0, totalSeconds: 55, recentSpeedMps: 0, isPaused: false), [.countdownCue])
        // 段內 56s：已 latch，不重複
        XCTAssertEqual(engine.update(totalMeters: 0, totalSeconds: 56, recentSpeedMps: 0, isPaused: false), [])
    }

    func test_distanceSegment_countdownByEstimatedTime() {
        let engine = SegmentTransitionEngine(segments: [seg(.run, .distance, m: 800), seg(.rest, .time, s: 60)])
        // 速度 4 m/s；剩 24m → 剩 6s，不觸發
        XCTAssertEqual(engine.update(totalMeters: 776, totalSeconds: 200, recentSpeedMps: 4, isPaused: false), [])
        // 剩 20m → 剩 5s，觸發
        XCTAssertEqual(engine.update(totalMeters: 780, totalSeconds: 201, recentSpeedMps: 4, isPaused: false), [.countdownCue])
    }

    func test_countdownResetsAfterAdvance() {
        let engine = SegmentTransitionEngine(segments: [seg(.run, .distance, m: 400), seg(.run, .distance, m: 400)])
        _ = engine.update(totalMeters: 381, totalSeconds: 100, recentSpeedMps: 4, isPaused: false) // 段0 倒數
        _ = engine.update(totalMeters: 400, totalSeconds: 105, recentSpeedMps: 4, isPaused: false) // 切段1（重置 latch）
        // 段1 內剩 5s 應再次觸發
        XCTAssertEqual(engine.update(totalMeters: 780, totalSeconds: 200, recentSpeedMps: 4, isPaused: false), [.countdownCue])
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（目前無倒數）

- [ ] **Step 3: 在 engine 的 `update` 達標判定**前插入倒數判定**

```swift
// 在 `let reached: Bool` 計算後、`guard reached else { return [] }` 之前插入：

if !countdownLatched {
    let remainingSeconds: Double
    switch seg.measure {
    case .time:
        remainingSeconds = Double((seg.targetSeconds ?? .max) - secondsInSeg)
    case .distance:
        let remainingMeters = (seg.targetMeters ?? .infinity) - metersInSeg
        remainingSeconds = recentSpeedMps > 0.1 ? remainingMeters / recentSpeedMps : .infinity
    }
    if remainingSeconds <= 5, remainingSeconds >= 0, !reached {
        countdownLatched = true
        return [.countdownCue]
    }
}
```

> 注意：倒數與切段在同一 tick 互斥（先倒數後切段不會同 tick 發生，因為 reached=true 時不進倒數分支）。

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS（含前 task 共 7 tests）

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch/Domain/SegmentTransitionEngine.swift HavitalWatchTests/SegmentTransitionEngineTests.swift
git commit -m "iOS Developer: SegmentTransitionEngine 5 秒倒數 latch (Plan C Task 7)"
```

---

## Task 8: WorkoutLauncher 啟動前置檢查

**Files:**
- Create: `HavitalWatch/Domain/WorkoutLauncher.swift`
- Test: `HavitalWatchTests/WorkoutLauncherTests.swift`

> 規則：rest → 禁；unsupported → 禁；無 snapshot → 禁（引導靠近 iPhone）；
> snapshot 非今日 → 禁；權限缺 → 要求授權。皆通過才可啟動。

- [ ] **Step 1: Write the failing test**

```swift
// HavitalWatchTests/WorkoutLauncherTests.swift
import XCTest
@testable import HavitalWatch

final class WorkoutLauncherTests: XCTestCase {
    private func snapshot(flow: WorkoutFlowType, date: String) -> WatchPlanSnapshot {
        WatchPlanSnapshot(date: date, flowType: flow, totalDistanceMeters: 1000,
                          totalSeconds: nil, planId: "p", segments: [])
    }

    func test_noSnapshot_blocked() {
        XCTAssertEqual(WorkoutLauncher.evaluate(snapshot: nil, today: "2026-06-05", permissionsGranted: true),
                       .blockedNeedSyncFromPhone)
    }
    func test_restDay_blocked() {
        XCTAssertEqual(WorkoutLauncher.evaluate(snapshot: snapshot(flow: .rest, date: "2026-06-05"),
                                                today: "2026-06-05", permissionsGranted: true),
                       .blockedRestDay)
    }
    func test_unsupported_blocked() {
        XCTAssertEqual(WorkoutLauncher.evaluate(snapshot: snapshot(flow: .unsupported, date: "2026-06-05"),
                                                today: "2026-06-05", permissionsGranted: true),
                       .blockedUnsupportedType)
    }
    func test_staleSnapshot_blocked() {
        XCTAssertEqual(WorkoutLauncher.evaluate(snapshot: snapshot(flow: .directStart, date: "2026-06-04"),
                                                today: "2026-06-05", permissionsGranted: true),
                       .blockedNeedSyncFromPhone)
    }
    func test_permissionsMissing_requiresPermission() {
        XCTAssertEqual(WorkoutLauncher.evaluate(snapshot: snapshot(flow: .directStart, date: "2026-06-05"),
                                                today: "2026-06-05", permissionsGranted: false),
                       .requiresPermission)
    }
    func test_allGood_canStart() {
        XCTAssertEqual(WorkoutLauncher.evaluate(snapshot: snapshot(flow: .warmupMainCooldown, date: "2026-06-05"),
                                                today: "2026-06-05", permissionsGranted: true),
                       .canStart)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（未定義）

- [ ] **Step 3: Write implementation**

```swift
// HavitalWatch/Domain/WorkoutLauncher.swift
enum LaunchDecision: Equatable {
    case canStart
    case requiresPermission
    case blockedRestDay
    case blockedUnsupportedType
    case blockedNeedSyncFromPhone
}

enum WorkoutLauncher {
    static func evaluate(snapshot: WatchPlanSnapshot?, today: String, permissionsGranted: Bool) -> LaunchDecision {
        guard let snapshot else { return .blockedNeedSyncFromPhone }
        guard snapshot.date == today else { return .blockedNeedSyncFromPhone }
        switch snapshot.flowType {
        case .rest: return .blockedRestDay
        case .unsupported: return .blockedUnsupportedType
        case .directStart, .warmupMainCooldown:
            return permissionsGranted ? .canStart : .requiresPermission
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS（6 tests）

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch/Domain/WorkoutLauncher.swift HavitalWatchTests/WorkoutLauncherTests.swift
git commit -m "iOS Developer: WorkoutLauncher 啟動前置檢查 (Plan C Task 8)"
```

---

## Task 9: WorkoutSnapshotStore + LocalSnapshotCache

**Files:**
- Create: `HavitalWatch/Data/LocalSnapshotCache.swift`
- Create: `HavitalWatch/Data/WorkoutSnapshotStore.swift`
- Test: `HavitalWatchTests/WorkoutSnapshotStoreTests.swift`

> Store 負責「存 / 取今日 snapshot」；快取以 `UserDefaults` 持久化（離線可跑，AC-WATCH-17）。
> 用 protocol 包 UserDefaults 以便注入測試。

- [ ] **Step 1: Write the failing test**

```swift
// HavitalWatchTests/WorkoutSnapshotStoreTests.swift
import XCTest
@testable import HavitalWatch

private final class InMemoryCache: SnapshotPersisting {
    var data: Data?
    func save(_ d: Data) { data = d }
    func load() -> Data? { data }
}

final class WorkoutSnapshotStoreTests: XCTestCase {
    func test_saveThenLoad_roundTrips() {
        let store = WorkoutSnapshotStore(cache: InMemoryCache())
        let dto = WatchPlanSnapshotDTO(date: "2026-06-05", runType: "interval",
                                       totalDistanceMeters: 6400, totalSeconds: nil, planId: "p", segments: [])
        store.save(dto)
        let loaded = store.currentSnapshot()
        XCTAssertEqual(loaded?.date, "2026-06-05")
        XCTAssertEqual(loaded?.flowType, .warmupMainCooldown)
    }
    func test_emptyCache_returnsNil() {
        XCTAssertNil(WorkoutSnapshotStore(cache: InMemoryCache()).currentSnapshot())
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（未定義）

- [ ] **Step 3: Write implementation**

```swift
// HavitalWatch/Data/LocalSnapshotCache.swift
import Foundation

protocol SnapshotPersisting {
    func save(_ data: Data)
    func load() -> Data?
}

struct LocalSnapshotCache: SnapshotPersisting {
    private let key = "paceriz.watch.today_snapshot"
    private let defaults = UserDefaults.standard
    func save(_ data: Data) { defaults.set(data, forKey: key) }
    func load() -> Data? { defaults.data(forKey: key) }
}
```

```swift
// HavitalWatch/Data/WorkoutSnapshotStore.swift
import Foundation

final class WorkoutSnapshotStore {
    private let cache: SnapshotPersisting
    init(cache: SnapshotPersisting = LocalSnapshotCache()) { self.cache = cache }

    func save(_ dto: WatchPlanSnapshotDTO) {
        if let data = try? JSONEncoder().encode(dto) { cache.save(data) }
    }
    func currentSnapshot() -> WatchPlanSnapshot? {
        guard let data = cache.load(),
              let dto = try? JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: data) else { return nil }
        return dto.toEntity()
    }
}
```

> DTO 需 `Codable`（已是）。`WatchPlanSnapshotDTO` 的 init 為 memberwise（struct 自動）。

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS（2 tests）

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch/Data/LocalSnapshotCache.swift HavitalWatch/Data/WorkoutSnapshotStore.swift HavitalWatchTests/WorkoutSnapshotStoreTests.swift
git commit -m "iOS Developer: WorkoutSnapshotStore + cache (Plan C Task 9)"
```

---

## Task 10: ActiveWorkoutSession 狀態機（階段 + 暫停累計）

**Files:**
- Create: `HavitalWatch/Domain/ActiveWorkoutSession.swift`
- Test: `HavitalWatchTests/ActiveWorkoutSessionTests.swift`

> 純邏輯狀態機：管理 phase（warmup / main / cooldown / finished）與「有效累計時間」（扣暫停）。
> GPS/HR 由 Task 12 的 HK wrapper 餵入；此處只測狀態轉換與累計，不碰 HealthKit。

- [ ] **Step 1: Write the failing test**

```swift
// HavitalWatchTests/ActiveWorkoutSessionTests.swift
import XCTest
@testable import HavitalWatch

final class ActiveWorkoutSessionTests: XCTestCase {
    private func snap(_ flow: WorkoutFlowType, _ segs: [WatchSegment]) -> WatchPlanSnapshot {
        WatchPlanSnapshot(date: "2026-06-05", flowType: flow, totalDistanceMeters: nil,
                          totalSeconds: nil, planId: "p", segments: segs)
    }
    private func run(_ m: Double) -> WatchSegment {
        WatchSegment(kind: .run, measure: .distance, targetMeters: m, targetSeconds: nil,
                     paceLowSecPerKm: nil, paceHighSecPerKm: nil, label: "x", repIndex: nil, repTotal: nil)
    }

    func test_directStart_startsInMainPhase() {
        let s = ActiveWorkoutSession(snapshot: snap(.directStart, []))
        XCTAssertEqual(s.phase, .main)        // 輕鬆類無暖身，直接 main
    }
    func test_structured_startsInWarmup_thenBeginPlanEntersMain() {
        let s = ActiveWorkoutSession(snapshot: snap(.warmupMainCooldown, [run(400)]))
        XCTAssertEqual(s.phase, .warmup)
        s.beginPlan()
        XCTAssertEqual(s.phase, .main)
    }
    func test_mainFinished_entersCooldown_forStructured() {
        let s = ActiveWorkoutSession(snapshot: snap(.warmupMainCooldown, [run(400)]))
        s.beginPlan()
        s.handleSegmentEvent(.finished)
        XCTAssertEqual(s.phase, .cooldown)
    }
    func test_directStart_finishGoesToFinished() {
        let s = ActiveWorkoutSession(snapshot: snap(.directStart, []))
        s.finish()
        XCTAssertEqual(s.phase, .finished)
    }
    func test_pauseFlagBlocksEngineAdvance() {
        let s = ActiveWorkoutSession(snapshot: snap(.warmupMainCooldown, [run(400), run(400)]))
        s.beginPlan()
        s.setPaused(true)
        XCTAssertTrue(s.isPaused)
        // 暫停時餵累計不應前進（引擎吃 isPaused）
        s.ingest(totalMeters: 999, totalSeconds: 999, recentSpeedMps: 4)
        XCTAssertEqual(s.currentSegmentIndex, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（未定義）

- [ ] **Step 3: Write implementation**

```swift
// HavitalWatch/Domain/ActiveWorkoutSession.swift
import Foundation

final class ActiveWorkoutSession {
    enum Phase: Equatable { case warmup, main, cooldown, finished }

    let snapshot: WatchPlanSnapshot
    private(set) var phase: Phase
    private(set) var isPaused = false
    private let engine: SegmentTransitionEngine?

    /// 訓練啟動時 freeze snapshot（建構後不變）。
    init(snapshot: WatchPlanSnapshot) {
        self.snapshot = snapshot
        switch snapshot.flowType {
        case .directStart:
            self.phase = .main
            self.engine = nil
        case .warmupMainCooldown:
            self.phase = .warmup
            self.engine = SegmentTransitionEngine(segments: snapshot.segments)
        case .rest, .unsupported:
            self.phase = .finished      // 不該走到這（Launcher 擋掉），保險
            self.engine = nil
        }
    }

    var currentSegmentIndex: Int { engine?.currentIndex ?? 0 }

    func beginPlan() { if phase == .warmup { phase = .main } }
    func setPaused(_ p: Bool) { isPaused = p }
    func finish() { phase = .finished }

    /// 餵入整場累計值；轉發給引擎並處理 phase 轉換。回傳引擎事件供上層觸發 haptic。
    @discardableResult
    func ingest(totalMeters: Double, totalSeconds: Int, recentSpeedMps: Double) -> [ActiveSegmentEvent] {
        guard phase == .main, let engine else { return [] }
        let events = engine.update(totalMeters: totalMeters, totalSeconds: totalSeconds,
                                   recentSpeedMps: recentSpeedMps, isPaused: isPaused)
        for e in events { handleSegmentEvent(e) }
        return events
    }

    func handleSegmentEvent(_ event: ActiveSegmentEvent) {
        if case .finished = event {
            phase = (snapshot.flowType == .warmupMainCooldown) ? .cooldown : .finished
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add HavitalWatch/Domain/ActiveWorkoutSession.swift HavitalWatchTests/ActiveWorkoutSessionTests.swift
git commit -m "iOS Developer: ActiveWorkoutSession 階段狀態機 (Plan C Task 10)"
```

---

## Task 11: WCSessionClient（收 iPhone 單日 snapshot / auth）

**Files:**
- Create: `HavitalWatch/Data/WCSessionClient.swift`

> framework 相依（WatchConnectivity），不純測。對接 Plan B 的 `transferUserInfo` payload。
> 契約：`userInfo["type"] == "today_plan"` 時 `userInfo["payload"]` 為 `WatchPlanSnapshotDTO` 的 JSON。

- [ ] **Step 1: 實作骨架**

```swift
// HavitalWatch/Data/WCSessionClient.swift
import Foundation
import WatchConnectivity

final class WCSessionClient: NSObject, WCSessionDelegate {
    static let shared = WCSessionClient()
    private let store = WorkoutSnapshotStore()
    private(set) var isLoggedIn = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // 收到 iPhone transferUserInfo（背景可達）
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        switch userInfo["type"] as? String {
        case "today_plan":
            if let json = userInfo["payload"] as? Data,
               let dto = try? JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: json) {
                store.save(dto)
                NotificationCenter.default.post(name: .watchPlanUpdated, object: nil)
            }
        case "auth":
            isLoggedIn = (userInfo["logged_in"] as? Bool) ?? false
            NotificationCenter.default.post(name: .watchAuthUpdated, object: nil)
        default: break
        }
    }

    // SPIKE: 確認當下 watchOS 必要實作的 delegate stub
    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
}

extension Notification.Name {
    static let watchPlanUpdated = Notification.Name("paceriz.watch.planUpdated")
    static let watchAuthUpdated = Notification.Name("paceriz.watch.authUpdated")
}
```

- [ ] **Step 2: 在 App 入口 activate**：`HavitalWatchApp.init` call `WCSessionClient.shared.activate()`。

- [ ] **Step 3: 驗證**（需 Plan B 的傳送端就緒）：iPhone 按「傳送到 Apple Watch」→ watch log 應印 `planUpdated`；
  store.currentSnapshot() 非 nil。**此驗證列入整合 Task 17。**

- [ ] **Step 4: Commit**

```bash
git add HavitalWatch/Data/WCSessionClient.swift HavitalWatch/App/HavitalWatchApp.swift
git commit -m "iOS Developer: WCSessionClient 收單日 snapshot/auth (Plan C Task 11)"
```

---

## Task 12: HKLiveWorkoutBuilderWrapper（workout session + 寫入 parity）

**Files:**
- Create: `HavitalWatch/Data/HealthKit/HKLiveWorkoutBuilderWrapper.swift`

> ⚠️ **最高 spike 風險 task**。啟動前必須實機驗證 `HKLiveWorkoutBuilder` 的暫停累計、metadata sync、
> `.segment` / `.pause` event 寫入行為。下方骨架標 `// SPIKE:` 處需對齊當下 watchOS API。
> 寫入欄位依 design doc §3.3：running / distance / duration / energy / route / HR / `.pause` / `.resume` / `.segment` / metadata(uuid, rpe, indoor)。

- [ ] **Step 1: 實作骨架（session 啟動 + 即時資料 + 暫停）**

```swift
// HavitalWatch/Data/HealthKit/HKLiveWorkoutBuilderWrapper.swift
import HealthKit
import CoreLocation

final class HKLiveWorkoutBuilderWrapper: NSObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    let workoutUUID = WorkoutUUIDValidator.generate()   // 啟動即產生，寫入時帶入

    // 即時讀數回呼（供 ViewModel 更新畫面）
    var onMetrics: ((_ meters: Double, _ seconds: Int, _ hr: Double, _ recentSpeedMps: Double) -> Void)?

    func start(indoor: Bool) throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = indoor ? .indoor : .outdoor
        // SPIKE: watchOS 版本對 session/builder 建構 API
        session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        builder = session?.associatedWorkoutBuilder()
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        builder?.delegate = self
        session?.startActivity(with: Date())
        builder?.beginCollection(withStart: Date()) { _, _ in }
    }

    func pause() { session?.pause() }    // 系統自動寫 .pause event；SPIKE 驗證
    func resume() { session?.resume() }  // 系統自動寫 .resume event；SPIKE 驗證

    /// 切段時呼叫，寫一個 .segment event（對應課表分區）
    func markSegment(start: Date, end: Date) {
        let seg = HKWorkoutEvent(type: .segment, dateInterval: DateInterval(start: start, end: end), metadata: nil)
        builder?.addWorkoutEvents([seg]) { _, _ in }   // SPIKE: API 簽名
    }

    func appendLocations(_ locs: [CLLocation]) {
        routeBuilder?.insertRouteData(locs) { _, _ in }
    }

    /// 結束 + 寫 metadata（含 uuid + 可選 rpe）。uuid 防線 1：不合法不寫。
    func finish(rpe: Int?, completion: @escaping (Bool) -> Void) {
        guard WorkoutUUIDValidator.isValid(workoutUUID) else {
            // 防線 1 fail-fast：不寫入 + log
            NSLog("[Watch] invalid workout_uuid: %@ — abort finish", workoutUUID)
            completion(false); return
        }
        var metadata: [String: Any] = [
            WorkoutUUIDValidator.metadataKey: workoutUUID,
            HKMetadataKeyIndoorWorkout: false   // SPIKE: 依 start(indoor:) 帶入實際值
        ]
        if let rpe { metadata["com.paceriz.rpe"] = rpe }

        builder?.addMetadata(metadata) { _, _ in }
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { workout, _ in
                guard let workout else { completion(false); return }
                self?.routeBuilder?.finishRoute(with: workout, metadata: nil) { _, _ in completion(true) }
            }
        }
    }
}

extension HKLiveWorkoutBuilderWrapper: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    func workoutBuilder(_ b: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        // SPIKE: 從 b.statistics(for:) 取 distance / HR / speed，換算後 call onMetrics
    }
}
```

- [ ] **Step 2: HealthKit 授權請求**（連 Task 13 PermissionGate）：share `HKWorkoutType` + `HKSeriesType.workoutRoute()`；
  read heartRate / distanceWalkingRunning。

- [ ] **Step 3: 實機/模擬器 spike 驗證清單**（啟動實作時逐項打勾，結果寫回 design doc §9）：
  - 暫停期間 distance/time 是否凍結
  - `.segment` / `.pause` event 是否確實寫入 `HKWorkout`
  - metadata `com.paceriz.workout_uuid` / `com.paceriz.rpe` 是否 sync 到 iPhone（連動 Plan B 驗證）

- [ ] **Step 4: Commit**

```bash
git add HavitalWatch/Data/HealthKit/HKLiveWorkoutBuilderWrapper.swift
git commit -m "iOS Developer: HKLiveWorkoutBuilderWrapper workout session + parity 寫入骨架 (Plan C Task 12, 需 spike)"
```

---

## Task 13: PermissionGate（HealthKit / Location / Motion）

**Files:**
- Create: `HavitalWatch/Data/PermissionGate.swift`

- [ ] **Step 1: 實作**

```swift
// HavitalWatch/Data/PermissionGate.swift
import HealthKit
import CoreLocation
import CoreMotion

final class PermissionGate: NSObject {
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()

    /// 依序請求所有缺漏權限；全部授權才 completion(true)（AC-WATCH-21）。
    func requestAll(completion: @escaping (Bool) -> Void) {
        let share: Set = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate), HKQuantityType(.distanceWalkingRunning)
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { [weak self] ok, _ in
            guard ok, let self else { completion(false); return }
            self.locationManager.requestWhenInUseAuthorization()   // SPIKE: watchOS location 授權回呼時序
            completion(self.allGranted())
        }
    }

    func allGranted() -> Bool {
        // SPIKE: HealthKit share 授權狀態在 watchOS 無法直接讀（隱私），以「曾成功啟動 session」為準；
        // location 用 authorizationStatus 判定。MVP 先以 location + motion 可用為 gate。
        let loc = locationManager.authorizationStatus
        return loc == .authorizedWhenInUse || loc == .authorizedAlways
    }
}
```

- [ ] **Step 2: 驗證**：模擬器首次啟動訓練彈出三權限；拒絕後再啟動顯示引導（PermissionView，Task 15）。

- [ ] **Step 3: Commit**

```bash
git add HavitalWatch/Data/PermissionGate.swift
git commit -m "iOS Developer: PermissionGate 三權限請求 (Plan C Task 13)"
```

---

## Task 14: HapticPlayer（震動 + 嗶）

**Files:**
- Create: `HavitalWatch/Data/HapticPlayer.swift`

- [ ] **Step 1: 實作**

```swift
// HavitalWatch/Data/HapticPlayer.swift
import WatchKit

enum HapticPlayer {
    /// 切換前 5 秒提示：一次震動 + 提示音（AC-WATCH-12）
    static func segmentCue() {
        WKInterfaceDevice.current().play(.notification)
    }
    static func start() { WKInterfaceDevice.current().play(.start) }
    static func stop()  { WKInterfaceDevice.current().play(.stop) }
}
```

- [ ] **Step 2: Commit**

```bash
git add HavitalWatch/Data/HapticPlayer.swift
git commit -m "iOS Developer: HapticPlayer 分段提示震動 (Plan C Task 14)"
```

---

## Task 15: Presentation（ViewModels + 9 個 View）

**Files:**
- Create: `HavitalWatch/Presentation/ViewModels/TodayWorkoutViewModel.swift`
- Create: `HavitalWatch/Presentation/ViewModels/ActiveWorkoutViewModel.swift`
- Create: 9 個 View（見 File Structure）

> View layout 規格見 design doc §5（9 個畫面已定）。本 task 將 ViewModel 綁定 Domain，
> View 純渲染。**每個 View 收尾跑模擬器驗證 loop + 截圖**（聲明 §3）。
> 此處給 ViewModel 完整骨架 + 一個代表性 View（IntervalMetricsView）骨架；其餘 View 照 §5 規格實作。

- [ ] **Step 1: TodayWorkoutViewModel（@MainActor，依 Store + Launcher）**

```swift
// HavitalWatch/Presentation/ViewModels/TodayWorkoutViewModel.swift
import SwiftUI

@MainActor
final class TodayWorkoutViewModel: ObservableObject {
    @Published var snapshot: WatchPlanSnapshot?
    @Published var decision: LaunchDecision = .blockedNeedSyncFromPhone

    private let store = WorkoutSnapshotStore()
    private let permission = PermissionGate()

    func refresh(today: String) {
        snapshot = store.currentSnapshot()
        decision = WorkoutLauncher.evaluate(snapshot: snapshot, today: today,
                                            permissionsGranted: permission.allGranted())
    }
}
```

- [ ] **Step 2: ActiveWorkoutViewModel（綁定 session + HK wrapper + haptic）**

```swift
// HavitalWatch/Presentation/ViewModels/ActiveWorkoutViewModel.swift
import SwiftUI

@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    @Published var meters: Double = 0
    @Published var seconds: Int = 0
    @Published var heartRate: Double = 0
    @Published var recentSpeedMps: Double = 0
    @Published var phase: ActiveWorkoutSession.Phase = .warmup
    @Published var currentSegment: WatchSegment?

    private let session: ActiveWorkoutSession
    private let hk = HKLiveWorkoutBuilderWrapper()

    init(snapshot: WatchPlanSnapshot) {
        self.session = ActiveWorkoutSession(snapshot: snapshot)
        self.phase = session.phase
        hk.onMetrics = { [weak self] m, s, hr, spd in
            Task { @MainActor in self?.onMetrics(m, s, hr, spd) }
        }
    }

    func start(indoor: Bool) { try? hk.start(indoor: indoor) }
    func beginPlan() { session.beginPlan(); phase = session.phase }
    func setPaused(_ p: Bool) { session.setPaused(p); p ? hk.pause() : hk.resume() }
    func finish(rpe: Int?, completion: @escaping (Bool) -> Void) {
        session.finish(); phase = .finished
        hk.finish(rpe: rpe, completion: completion)
    }

    private func onMetrics(_ m: Double, _ s: Int, _ hr: Double, _ spd: Double) {
        meters = m; seconds = s; heartRate = hr; recentSpeedMps = spd
        let events = session.ingest(totalMeters: m, totalSeconds: s, recentSpeedMps: spd)
        for e in events {
            switch e {
            case .countdownCue: HapticPlayer.segmentCue()
            case .advanced(let idx):
                HapticPlayer.start()
                currentSegment = idx < session.snapshot.segments.count ? session.snapshot.segments[idx] : nil
                hk.markSegment(start: Date(), end: Date())   // 切段寫 .segment
            case .finished:
                phase = session.phase
            }
        }
    }
}
```

- [ ] **Step 3: 代表性 View — IntervalMetricsView（§5 ③④ 規格）**

```swift
// HavitalWatch/Presentation/IntervalMetricsView.swift
import SwiftUI

struct IntervalMetricsView: View {
    @ObservedObject var vm: ActiveWorkoutViewModel

    var body: some View {
        let seg = vm.currentSegment
        VStack(alignment: .leading, spacing: 2) {
            Text(stepTitle(seg))                       // 「間歇 3/5」/「休息 3/5」
                .font(.caption2).foregroundStyle(.blue)
            Text(primaryMetric(seg))                   // 剩餘距離/時間倒數（綠・主）
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(.green)
            if let lo = seg?.paceLowSecPerKm, let hi = seg?.paceHighSecPerKm {
                Text("目標 \(pace(lo))–\(pace(hi))").font(.caption2)
            }
            Text("\(pace(currentPaceSecPerKm)) 配速")
                .foregroundStyle(paceColor(seg))       // 範圍內綠/太快橘/太慢紅
            Label("\(Int(vm.heartRate))", systemImage: "heart.fill")
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // helper：stepTitle / primaryMetric / pace / paceColor / currentPaceSecPerKm
    // 依 §5 規格實作（剩餘 = target − 已跑；配速用 recentSpeedMps 換算 sec/km）
    private func stepTitle(_ s: WatchSegment?) -> String { /* 依 kind + rep_index/total */ "" }
    private func primaryMetric(_ s: WatchSegment?) -> String { "" }
    private var currentPaceSecPerKm: Int { vm.recentSpeedMps > 0.1 ? Int(1000 / vm.recentSpeedMps) : 0 }
    private func pace(_ secPerKm: Int) -> String { String(format: "%d:%02d", secPerKm/60, secPerKm%60) }
    private func paceColor(_ s: WatchSegment?) -> Color { .green }
}
```

> 其餘 View（TodayWorkoutView / WelcomeView / EasyRunMetricsView / WarmupCooldownView /
> WorkoutControlView / RPEView / WorkoutSummaryView / PermissionView）照 §5 規格各自實作，
> 每個 View 一個子 step：實作 → 模擬器驗證 loop → 截圖存 `tmp_reports/watch_<view>.png` → 自己 Read 截圖逐項對 §5。

- [ ] **Step 4: RPEView 用 Digital Crown 綁定 1-10**

```swift
// HavitalWatch/Presentation/RPEView.swift（關鍵互動）
@State private var rpe: Double = 5
// ...
Text("\(Int(rpe))").font(.system(size: 48, weight: .bold, design: .rounded))
    .focusable(true)
    .digitalCrownRotation($rpe, from: 1, through: 10, by: 1, sensitivity: .medium)
Text(RPEFeedback.text(for: Int(rpe)))
```

- [ ] **Step 5: 每個 View 模擬器驗證 + 截圖後 Commit**（逐 View commit）

```bash
git add HavitalWatch/Presentation
git commit -m "iOS Developer: watchOS Presentation views 對齊 design §5 (Plan C Task 15)"
```

---

## Task 16: Complication（corner / circular）

**Files:**
- Create: `HavitalWatch/Complication/PacerizComplicationProvider.swift`

> WidgetKit（ComplicationKit 已棄用）。顯示 logo + 今日課表簡述；點擊 deep link 進主頁。
> 每日 00:00 + 課表更新（`NotificationCenter .watchPlanUpdated`）時 `WidgetCenter.shared.reloadAllTimelines()`。

- [ ] **Step 1: 實作 TimelineProvider 骨架**

```swift
// HavitalWatch/Complication/PacerizComplicationProvider.swift
import WidgetKit
import SwiftUI

struct PacerizEntry: TimelineEntry { let date: Date; let summary: String }

struct PacerizProvider: TimelineProvider {
    func placeholder(in context: Context) -> PacerizEntry { .init(date: Date(), summary: "Paceriz") }
    func getSnapshot(in context: Context, completion: @escaping (PacerizEntry) -> Void) {
        completion(.init(date: Date(), summary: Self.todaySummary()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PacerizEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: Date(), summary: Self.todaySummary())], policy: .atEnd))
    }
    // 「8K Easy」/「800m × 5」/「休息日」/「無課表」
    static func todaySummary() -> String {
        guard let s = WorkoutSnapshotStore().currentSnapshot() else { return "無課表" }
        if s.flowType == .rest { return "休息日" }
        return s.segments.first?.label ?? "今日課表"   // SPIKE: 依 §5 摘要規則精修
    }
}

@main
struct PacerizComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PacerizToday", provider: PacerizProvider()) { entry in
            // corner / circular family view；含 widgetURL deep link
            Text(entry.summary).widgetURL(URL(string: "paceriz-watch://today"))
        }
        .supportedFamilies([.accessoryCorner, .accessoryCircular])
    }
}
```

- [ ] **Step 2: 課表更新時 reload timeline**：在 `WCSessionClient.didReceiveUserInfo` 的 today_plan 分支後
  call `WidgetCenter.shared.reloadAllTimelines()`。

- [ ] **Step 3: 模擬器驗證**：watch face 加 complication → 顯示課表簡述 → 點擊進主頁。截圖。

- [ ] **Step 4: Commit**

```bash
git add HavitalWatch/Complication
git commit -m "iOS Developer: WidgetKit complication corner/circular (Plan C Task 16)"
```

---

## Task 17: 端到端整合走查（模擬器，連動 Plan B）

**Files:** 無新檔；整合驗證 + 修補。

- [ ] **Step 1: 串接導航**：TodayWorkoutView →（依 flowType）→ Warmup/EasyRun → Interval → Cooldown →
  Control → RPE → Summary → finish 寫 HealthKit。

- [ ] **Step 2: 模擬器跑 A 流程（輕鬆跑）**：啟動 → 跑（模擬器 location 注入）→ 結束 → RPE → 摘要 → HealthKit 出現 workout。截圖每步。

- [ ] **Step 3: 模擬器跑 B 流程（間歇 800m×5）**：暖身 → 開始課表 → 跑段/休息自動切（驗 5 秒震動）→ 緩和 → 結束 → RPE。截圖每步。

- [ ] **Step 4: 驗證寫入 parity（連動 Plan B）**：iPhone 端讀回該 workout，確認含 route / HR / `.segment` / metadata uuid + rpe。**此項依賴 Plan B 完成。**

- [ ] **Step 5: 自己 Read 所有截圖逐項對 design §5**，不合格退回對應 task 修。

- [ ] **Step 6: Commit**

```bash
git commit -m "iOS Developer: watchOS 端到端整合走查 A/B 流程 (Plan C Task 17)"
```

---

## Self-Review（plan 寫完自查）

- **Spec 覆蓋**：§1 分流→Task 2；§2 狀態機→Task 6/7/10；§3.3 parity 寫入→Task 12；§3.4 uuid→Task 4/12；
  §5 畫面→Task 15；RPE→Task 5/15；complication→Task 16；離線快取→Task 9；權限→Task 13；i18n→Task 5。
  暖身/緩和 open 手動→Task 10（phase）+ Task 15（WarmupCooldownView）。✅
- **Placeholder**：核心邏輯 Task 2–10 為完整可跑 TDD code；Task 11–16 framework 部分以 `// SPIKE:` 標出
  「啟動前須對齊 API」的點 — 這是已知不確定的誠實標註，非待填空白。Task 15 其餘 View 指向 §5 既有規格。
- **型別一致**：`WatchPlanSnapshot` / `WatchSegment` / `WorkoutFlowType` / `LaunchDecision` /
  `ActiveSegmentEvent` / `ActiveWorkoutSession.Phase` 跨 task 命名一致；`SegmentTransitionEngine.update`
  簽名（Task 6 定義、Task 7 擴充、Task 10 呼叫）一致。✅
- **未涵蓋（刻意）**：iPhone 端傳送/接收/上傳 = Plan B；後端 = MVP 不做（design §4.3）。

---

## 已知尚未驗證（誠實標註，啟動實作前處理）

1. Task 12 的 `HKLiveWorkoutBuilder` 全部 `// SPIKE:` 行 — 暫停累計 / `.segment`、`.pause` 寫入 / metadata sync。
2. Task 13 watchOS HealthKit share 授權狀態無法直接讀，MVP 以 location gate 近似 — 需 spike 確認可接受。
3. Task 16 complication 摘要文字規則（§5）與 refresh budget 需實機微調。
