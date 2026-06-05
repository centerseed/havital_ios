# Apple Watch 精簡核心版 — iOS Companion（Plan B）實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓既有 iPhone Paceriz app 能（下行）把當日課表單向傳到 Apple Watch、（上行）把 Watch 寫入 HealthKit 的 workout 的 RPE 補進既有上傳流程。

**Architecture:** 不新增後端邏輯。下行：今日 `RunActivity` 經 `WatchPlanProjector` 投影成 `WatchPlanSnapshotDTO`，透過 `WatchCompanionService`（WCSession `transferUserInfo`）單向送出。上行：`AppleHealthWorkoutUploadService` 上傳完拿到 `workoutId` 後讀 metadata `com.paceriz.rpe`，呼叫既有 `WorkoutRepository.updateRPE(id:rpe:)`。Watch workout 的 dedup 沿用既有 `makeWorkoutId = type_start_distance`，無需改動。

**Tech Stack:** Swift / SwiftUI / WatchConnectivity / HealthKit / XCTest

**依據 spec:** `docs/superpowers/specs/2026-06-05-apple-watch-mvp-lean-design.md`（§3.1 下行、§3.2/§3.4 上行、§4.2 iOS 改動）

**已驗證的既有介面（本 plan 對接點）:**
- `WorkoutRepository.updateRPE(id: String, rpe: Int?) async throws`（protocol L164 / impl `WorkoutRepositoryImpl` L481）
- `AppleHealthWorkoutUploadService.makeWorkoutId(for: HKWorkout) -> String`（L62，= `"\(type)_\(start)_\(distM)"`，既有 dedup key）
- `AppleHealthWorkoutUploadService.extractPauseEvents(from:)`（L756，已解 `.pause`/`.resume`，**未解 `.segment`**）
- `AppleHealthWorkoutUploadService` metadata 讀取點（L860 `workout.metadata`）
- `TrainingSession.primary` → `.run(RunActivity)`（`TrainingSessionModels.swift` L223/307）
- `RunActivity`：`runType` / `segments: [RunSegment]?` / `interval: IntervalBlock?`（L88）
- `PlannedSessionDetailView.secondaryButtons`（L556，用 `SecondaryActionButton` 元件）

---

## ⚠️ 實作前必讀

1. **backlog plan**：與 Plan C（watchOS app）共享 `WatchPlanSnapshotDTO` 線格式契約。Plan C Task 3 已定義該 DTO；本 plan Task 1 把它加進 iOS target membership（不重複建檔）。
2. **兩個需在實作時確認的資料點**（標 `// CONFIRM:`）：
   - `RunSegment.intensity` 的實際列舉值（用來判斷哪些 segment 是 warmup/cooldown 該過濾）
   - `RunSegment.pace` / `IntervalBlock.workPace` 的字串格式（`"4:30"` 假設；需確認是否帶單位）
3. **UI 驗證 loop**：改 `PlannedSessionDetailView` 後跑 `build → install → terminate → launch → screenshot`，自己 Read 截圖。
4. **不改後端**：RPE 走既有 `updateRPE`；dedup 走既有 `makeWorkoutId`。

---

## File Structure

```
Havital/
  Features/Watch/                                    ← 新增 iOS 端 Watch companion
    Data/
      DTOs/WatchPlanSnapshotDTO.swift                ← 與 HavitalWatch 共用（target membership 兩端勾）
      WatchPlanProjector.swift                       RunActivity → WatchPlanSnapshotDTO（純邏輯）
      WatchCompanionService.swift                    WCSession：送 auth + 今日課表
  Features/TrainingPlanV2/Presentation/Views/
    PlannedSessionDetailView.swift                   MODIFY：secondaryButtons 加「傳送到 Apple Watch」
  Services/Integrations/AppleHealth/
    AppleHealthWorkoutUploadService.swift            MODIFY：讀 com.paceriz.rpe → updateRPE；（可選）解 .segment
HavitalTests/
  Watch/
    WatchPlanProjectorTests.swift
    PacerizRPEMetadataTests.swift
```

---

## Task 1: 共用 WatchPlanSnapshotDTO target membership

**Files:**
- Modify: `Havital.xcodeproj`（target membership）
- 依賴: Plan C Task 3 的 `HavitalWatch/Data/DTOs/WatchPlanSnapshotDTO.swift`

> 若先做 Plan B（Plan C 尚未建 DTO），則在此先建立同一份 DTO 檔（內容見 Plan C Task 3），並把 target membership 同時勾 `Havital` + `HavitalWatch`。

- [ ] **Step 1: 將 DTO 檔加入 iOS target**

Xcode → 選 `WatchPlanSnapshotDTO.swift` → File Inspector → Target Membership 勾選 `Havital`（與 `HavitalWatch`）。

- [ ] **Step 2: build iOS app 確認 DTO 可見**

Run: `xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Havital.xcodeproj
git commit -m "iOS Developer: WatchPlanSnapshotDTO 加入 iOS target membership (Plan B Task 1)"
```

---

## Task 2: WatchPlanProjector — interval block 展開

**Files:**
- Create: `Havital/Features/Watch/Data/WatchPlanProjector.swift`
- Test: `HavitalTests/Watch/WatchPlanProjectorTests.swift`

> interval 課表的 `IntervalBlock`（repeats × work/recovery）展開成主段 segments，帶 rep_index/rep_total。
> 暖身/緩和**不投影**（Watch 自己補 open）。

- [ ] **Step 1: Write the failing test**

```swift
// HavitalTests/Watch/WatchPlanProjectorTests.swift
import XCTest
@testable import Havital

final class WatchPlanProjectorTests: XCTestCase {
    func test_intervalBlock_expandsToWorkRestPairs() {
        let block = IntervalBlock(
            repeats: 3, workDistanceKm: nil, workDistanceM: 800, workDistanceDisplay: nil,
            workDistanceUnit: nil, workPaceUnit: nil, workDurationMinutes: nil, workPace: "4:30",
            workDescription: nil, recoveryDistanceKm: nil, recoveryDistanceM: nil,
            recoveryDurationMinutes: nil, recoveryPace: nil, recoveryDescription: nil,
            recoveryDurationSeconds: 120, variant: nil
        )
        let activity = RunActivity.stub(runType: "interval", interval: block)

        let dto = WatchPlanProjector.project(activity: activity, date: "2026-06-05", planId: "p")

        XCTAssertEqual(dto.runType, "interval")
        XCTAssertEqual(dto.segments.count, 6)                  // 3 組 × (work + recovery)
        XCTAssertEqual(dto.segments[0].kind, "run")
        XCTAssertEqual(dto.segments[0].measure, "distance")
        XCTAssertEqual(dto.segments[0].targetMeters, 800)
        XCTAssertEqual(dto.segments[0].repIndex, 1)
        XCTAssertEqual(dto.segments[0].repTotal, 3)
        XCTAssertEqual(dto.segments[0].paceLowSecPerKm, 270)   // "4:30" = 270s
        XCTAssertEqual(dto.segments[1].kind, "rest")
        XCTAssertEqual(dto.segments[1].measure, "time")
        XCTAssertEqual(dto.segments[1].targetSeconds, 120)
        XCTAssertEqual(dto.segments[5].repIndex, 3)            // 最後一組 recovery
    }
}
```

> 需在 test 檔加 `RunActivity.stub(...)` / `IntervalBlock` memberwise（若既有 init 不可達，於 `HavitalTests/Watch/` 加 test helper extension）。

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（`WatchPlanProjector` 未定義）

- [ ] **Step 3: Write implementation**

```swift
// Havital/Features/Watch/Data/WatchPlanProjector.swift
import Foundation

enum WatchPlanProjector {
    static func project(activity: RunActivity, date: String, planId: String) -> WatchPlanSnapshotDTO {
        let segments: [WatchSegmentDTO]
        if let block = activity.interval {
            segments = expandInterval(block)
        } else {
            segments = projectSegments(activity.segments ?? [])
        }
        return WatchPlanSnapshotDTO(
            date: date,
            runType: activity.runType,
            totalDistanceMeters: activity.distanceKm.map { $0 * 1000 },
            totalSeconds: activity.durationSeconds ?? activity.durationMinutes.map { $0 * 60 },
            planId: planId,
            segments: segments
        )
    }

    private static func expandInterval(_ b: IntervalBlock) -> [WatchSegmentDTO] {
        var out: [WatchSegmentDTO] = []
        for rep in 1...max(b.repeats, 1) {
            // work
            out.append(WatchSegmentDTO(
                kind: "run",
                measure: b.workDistanceM != nil ? "distance" : "time",
                targetMeters: b.workDistanceM.map(Double.init),
                targetSeconds: b.workDurationMinutes.map { $0 * 60 },
                paceLowSecPerKm: paceToSec(b.workPace),
                paceHighSecPerKm: paceToSec(b.workPace),     // 課表單值 → low=high；範圍 buffer 待產品定
                label: "\(b.workDistanceM ?? 0)m",
                repIndex: rep, repTotal: b.repeats))
            // recovery（最後一組仍給 recovery；若課表無 recovery 資料則略過）
            let hasRecovery = b.recoveryDistanceM != nil || b.recoveryDurationSeconds != nil || b.recoveryDurationMinutes != nil
            if hasRecovery {
                out.append(WatchSegmentDTO(
                    kind: "rest",
                    measure: b.recoveryDistanceM != nil ? "distance" : "time",
                    targetMeters: b.recoveryDistanceM.map(Double.init),
                    targetSeconds: b.recoveryDurationSeconds ?? b.recoveryDurationMinutes.map { $0 * 60 },
                    paceLowSecPerKm: paceToSec(b.recoveryPace),
                    paceHighSecPerKm: paceToSec(b.recoveryPace),
                    label: NSLocalizedString("watch.segment.rest", comment: "休息"),
                    repIndex: rep, repTotal: b.repeats))
            }
        }
        return out
    }

    // Task 3 補 projectSegments / paceToSec
    static func projectSegments(_ segs: [RunSegment]) -> [WatchSegmentDTO] { [] }
    static func paceToSec(_ pace: String?) -> Int? { nil }
}
```

- [ ] **Step 4: Run test to verify it passes**（先讓 paceToSec 回 nil → 該 assert 暫失敗；Task 3 完成 pace 後再綠。本 task 先驗 interval 結構，pace assert 移到 Task 3）

> 調整：本 task 的 test 先**移除** pace 相關 assert（`paceLowSecPerKm`），只驗結構（count / kind / measure / target / rep）。pace assert 在 Task 3 加回。

Run: `xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HavitalTests/WatchPlanProjectorTests/test_intervalBlock_expandsToWorkRestPairs`
Expected: PASS（結構部分）

- [ ] **Step 5: Commit**

```bash
git add Havital/Features/Watch/Data/WatchPlanProjector.swift HavitalTests/Watch/WatchPlanProjectorTests.swift
git commit -m "iOS Developer: WatchPlanProjector interval 展開 (Plan B Task 2)"
```

---

## Task 3: WatchPlanProjector — pace 轉換 + 一般 segments 過濾暖身緩和

**Files:**
- Modify: `Havital/Features/Watch/Data/WatchPlanProjector.swift`
- Test: `HavitalTests/Watch/WatchPlanProjectorTests.swift`（加 case）

- [ ] **Step 1: Write the failing test**

```swift
extension WatchPlanProjectorTests {
    func test_paceToSec_parsesMinutesSeconds() {
        XCTAssertEqual(WatchPlanProjector.paceToSec("4:30"), 270)
        XCTAssertEqual(WatchPlanProjector.paceToSec("5:00"), 300)
        XCTAssertNil(WatchPlanProjector.paceToSec(nil))
        XCTAssertNil(WatchPlanProjector.paceToSec("--"))
    }

    func test_segments_filterOutWarmupCooldown() {
        let warm = RunSegment.stub(intensity: "warmup", distanceM: 1000)
        let main = RunSegment.stub(intensity: "tempo", distanceM: 3000, pace: "4:00")
        let cool = RunSegment.stub(intensity: "cooldown", distanceM: 1000)
        let result = WatchPlanProjector.projectSegments([warm, main, cool])
        XCTAssertEqual(result.count, 1)                       // 只剩主段
        XCTAssertEqual(result[0].targetMeters, 3000)
        XCTAssertEqual(result[0].paceLowSecPerKm, 240)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL

- [ ] **Step 3: Implement paceToSec + projectSegments**

```swift
// 取代 Task 2 的 stub：
static func paceToSec(_ pace: String?) -> Int? {
    guard let pace, let colon = pace.firstIndex(of: ":") else { return nil }
    let mm = String(pace[..<colon])
    let rest = pace[pace.index(after: colon)...]
    let ss = String(rest.prefix(while: { $0.isNumber }))   // 容忍 "4:30/km" 尾綴 // CONFIRM: 實際格式
    guard let m = Int(mm), let s = Int(ss) else { return nil }
    return m * 60 + s
}

static func projectSegments(_ segs: [RunSegment]) -> [WatchSegmentDTO] {
    segs.filter { !isWarmupOrCooldown($0) }.map { s in
        WatchSegmentDTO(
            kind: "work",
            measure: s.distanceM != nil ? "distance" : "time",
            targetMeters: s.distanceM.map(Double.init),
            targetSeconds: s.durationSeconds ?? s.durationMinutes.map { $0 * 60 },
            paceLowSecPerKm: paceToSec(s.pace),
            paceHighSecPerKm: paceToSec(s.pace),
            label: s.description ?? "",
            repIndex: nil, repTotal: nil)
    }
}

// CONFIRM: RunSegment.intensity 實際列舉值；先以字串包含 warmup/cooldown 判斷
private static func isWarmupOrCooldown(_ s: RunSegment) -> Bool {
    let i = (s.intensity ?? "").lowercased()
    return i.contains("warm") || i.contains("cool")
}
```

- [ ] **Step 4: 把 Task 2 移除的 pace assert 加回並全測** — Expected: PASS（interval pace 270 + 本 task 4 assert）

- [ ] **Step 5: Commit**

```bash
git add Havital/Features/Watch/Data/WatchPlanProjector.swift HavitalTests/Watch/WatchPlanProjectorTests.swift
git commit -m "iOS Developer: WatchPlanProjector pace 轉換 + 過濾暖身緩和 (Plan B Task 3)"
```

---

## Task 4: WatchCompanionService（WCSession 送 auth + 今日課表）

**Files:**
- Create: `Havital/Features/Watch/Data/WatchCompanionService.swift`

> framework 相依，不純測。對接 Plan C `WCSessionClient` 的 `userInfo` 契約：
> `{"type":"today_plan","payload":<DTO json Data>}` / `{"type":"auth","logged_in":Bool}`。

- [ ] **Step 1: 實作骨架**

```swift
// Havital/Features/Watch/Data/WatchCompanionService.swift
import Foundation
import WatchConnectivity

final class WatchCompanionService: NSObject, WCSessionDelegate {
    static let shared = WatchCompanionService()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 使用者按「傳送到 Apple Watch」→ 單向送當日課表（背景可達）
    func sendTodayPlan(_ dto: WatchPlanSnapshotDTO) {
        guard let data = try? JSONEncoder().encode(dto) else { return }
        WCSession.default.transferUserInfo(["type": "today_plan", "payload": data])
    }

    /// 登入/登出時 push auth 狀態
    func pushAuth(loggedIn: Bool) {
        WCSession.default.transferUserInfo(["type": "auth", "logged_in": loggedIn])
    }

    /// 配對 / watch app 安裝狀態（決定傳送按鈕三態）。只有 iPhone 端讀得到。
    enum WatchAvailability { case ready, appNotInstalled, noWatch, unavailable }
    var sendAvailability: WatchAvailability {
        let s = WCSession.default
        guard WCSession.isSupported(), s.activationState == .activated else { return .unavailable }
        if !s.isPaired { return .noWatch }               // 沒配對 Apple Watch
        if !s.isWatchAppInstalled { return .appNotInstalled } // 有 watch 但沒裝 Paceriz watch app
        return .ready
    }

    // 必要 delegate stubs
    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }
    func sessionDidBecomeInactive(_ s: WCSession) {}
    func sessionDidDeactivate(_ s: WCSession) { WCSession.default.activate() }
    // 配對 / 安裝狀態改變（裝/移除 watch app、配對/解除）→ 通知 UI 重新評估按鈕
    func sessionWatchStateDidChange(_ s: WCSession) {
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }
}

extension Notification.Name {
    static let watchAvailabilityChanged = Notification.Name("paceriz.watch.availabilityChanged")
}
```

- [ ] **Step 2: 在 app 啟動 activate**：於既有 App 啟動流程（AppDelegate / App init）call `WatchCompanionService.shared.activate()`。
- [ ] **Step 3: 在既有登入/登出流程** call `pushAuth(loggedIn:)`（找既有 Auth 成功/登出點掛入）。
- [ ] **Step 4: Commit**

```bash
git add Havital/Features/Watch/Data/WatchCompanionService.swift
git commit -m "iOS Developer: WatchCompanionService WCSession 送課表/auth (Plan B Task 4)"
```

---

## Task 5: PlannedSessionDetailView 加「傳送到 Apple Watch」按鈕

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift`（`secondaryButtons` L556 區）

- [ ] **Step 1: 在 `secondaryButtons` 依配對三態加按鈕（僅跑步類 session）**

```swift
// 於 PlannedSessionDetailView.secondaryButtons（L556 附近）加入：
// 註：用 @State var watchAvailability 持有，並 .onReceive(.watchAvailabilityChanged) 更新以即時重繪。
if case .run(let activity)? = day.session?.primary {
    switch WatchCompanionService.shared.sendAvailability {
    case .ready:
        SecondaryActionButton(
            icon: "applewatch",
            label: NSLocalizedString("training.detail.send_to_watch", comment: "傳送到 Apple Watch"),
            action: {
                let dto = WatchPlanProjector.project(
                    activity: activity,
                    date: day.dateString,             // CONFIRM: day 的日期欄位名（yyyy-MM-dd local）
                    planId: day.planId ?? "")         // CONFIRM: planId 取得處
                WatchCompanionService.shared.sendTodayPlan(dto)
                // 顯示輕量成功提示（toast / haptic）
            })
    case .appNotInstalled:
        SecondaryActionButton(
            icon: "applewatch.slash",
            label: NSLocalizedString("training.detail.install_watch_app", comment: "在 Apple Watch 安裝 Paceriz"),
            action: { showInstallWatchAppGuide = true })   // 引導 sheet：說明去 iPhone Watch app 安裝
    case .noWatch, .unavailable:
        EmptyView()        // 沒配對 Apple Watch → 不顯示按鈕
    }
}
```

- [ ] **Step 2: 補 i18n key**：`training.detail.send_to_watch`（zh-TW「傳送到 Apple Watch」/ en「Send to Apple Watch」/ ja「Apple Watch に送信」）、`training.detail.install_watch_app`（zh-TW「在 Apple Watch 安裝 Paceriz」/ en「Install Paceriz on Apple Watch」/ ja「Apple Watch に Paceriz をインストール」）。

- [ ] **Step 3: 模擬器驗證 loop（三態各驗一次）**：
  - `ready`：iPhone 模擬器配對 watch 模擬器 + 裝 watch app → 按鈕顯示「傳送到 Apple Watch」
  - `appNotInstalled`：配對 watch 但移除 watch app → 按鈕顯示「在 Apple Watch 安裝 Paceriz」
  - `noWatch`：未配對 watch → 按鈕不顯示
  build → install → terminate → launch → 進今日課表 detail → 三態各截圖。自己 Read 截圖逐項驗。

- [ ] **Step 4: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift Havital/**/Localizable.xcstrings
git commit -m "iOS Developer: 今日課表 detail 加傳送到 Apple Watch 按鈕 (Plan B Task 5)"
```

---

## Task 6: 上傳後讀 RPE metadata → updateRPE

**Files:**
- Modify: `Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift`
- Test: `HavitalTests/Watch/PacerizRPEMetadataTests.swift`

> watch workout 上傳成功後，讀 metadata `com.paceriz.rpe`，呼叫既有 `WorkoutRepository.updateRPE(id:rpe:)`。
> RPE 讀取邏輯（純函數）TDD；掛鉤上傳流程為整合。

- [ ] **Step 1: Write the failing test（純讀取邏輯）**

```swift
// HavitalTests/Watch/PacerizRPEMetadataTests.swift
import XCTest
import HealthKit
@testable import Havital

final class PacerizRPEMetadataTests: XCTestCase {
    private func workout(metadata: [String: Any]?) -> HKWorkout {
        HKWorkout(activityType: .running, start: Date(), end: Date().addingTimeInterval(60),
                  workoutEvents: nil, totalEnergyBurned: nil, totalDistance: nil, metadata: metadata)
    }
    func test_validRPE_extracted() {
        let w = workout(metadata: ["com.paceriz.rpe": 7])
        XCTAssertEqual(AppleHealthWorkoutUploadService.extractPacerizRPE(from: w), 7)
    }
    func test_outOfRange_ignored() {
        XCTAssertNil(AppleHealthWorkoutUploadService.extractPacerizRPE(from: workout(metadata: ["com.paceriz.rpe": 0])))
        XCTAssertNil(AppleHealthWorkoutUploadService.extractPacerizRPE(from: workout(metadata: ["com.paceriz.rpe": 11])))
    }
    func test_missing_returnsNil() {
        XCTAssertNil(AppleHealthWorkoutUploadService.extractPacerizRPE(from: workout(metadata: nil)))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL（未定義）

- [ ] **Step 3: 加 extractPacerizRPE（static，純函數）**

```swift
// AppleHealthWorkoutUploadService.swift（與 makeWorkoutId 同區）
static func extractPacerizRPE(from workout: HKWorkout) -> Int? {
    guard let raw = workout.metadata?["com.paceriz.rpe"] as? Int,
          (1...10).contains(raw) else { return nil }
    return raw
}
```

- [ ] **Step 4: 掛鉤上傳成功後（`performUploadWorkout` 成功分支）**

```swift
// 在上傳成功、已有 workoutId 之後加入：
let workoutId = makeWorkoutId(for: workout)
if let rpe = Self.extractPacerizRPE(from: workout) {
    Task {
        try? await workoutRepository.updateRPE(id: workoutId, rpe: rpe)  // CONFIRM: 取得 repository 的 DI 方式
        Logger.debug("[Upload] applied watch RPE \(rpe) to \(workoutId)")
    }
}
```

> `workoutRepository` 取得方式：依既有 DI（`DependencyContainer`）注入 `AppleHealthWorkoutUploadService`，或在 call site 經既有容器取 `WorkoutRepository`。**CONFIRM**：確認既有 service 是否已持有 repository，避免循環依賴（Repository → Service 禁止；此處是 Service → Repository，方向合法）。

- [ ] **Step 5: Run test to verify it passes** — Expected: PASS（4 tests）

- [ ] **Step 6: Commit**

```bash
git add Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift HavitalTests/Watch/PacerizRPEMetadataTests.swift
git commit -m "iOS Developer: 上傳後讀 watch RPE metadata 走既有 updateRPE (Plan B Task 6)"
```

---

## Task 7（可選 / 驗證後決定）: parser 解 `.segment` event

**Files:**
- Modify: `Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift`（`extractPauseEvents` 鄰近）

> 既有 `extractPauseEvents`（L756）只處理 `.pause`/`.resume`，不解 `.segment`。
> **MVP 不阻塞**：不解 segment 時 workout 仍完整上傳（距離/時間/HR/route/pause 都在），只是後端不知課表分段邊界。
> 是否要做，取決於 spike：「後端 workout_v2 是否需要分段邊界做課表完成度核對」。

- [ ] **Step 1: spike 決策**：與後端確認 workout_v2 是否消費 `.segment`。若否 → 本 task 不做，於 design §9 記錄。
- [ ] **Step 2（若要做）: 擴充 event 解析**，把 `.segment` event 也收進 `WorkoutEventData`（既有 struct L1611），與 pause events 一起送 `workoutEvents`。沿用既有 `extractPauseEvents` 模式，新增 `extractSegmentEvents(from:)`，合併後傳 `postWorkoutDetails`。
- [ ] **Step 3: Commit（若做）**

```bash
git commit -m "iOS Developer: parser 解 .segment event (Plan B Task 7, 視 spike)"
```

---

## Task 8: 端到端整合驗證（連動 Plan C）

**Files:** 無新檔。

- [ ] **Step 1: 下行**：iPhone 今日課表 detail 按「傳送到 Apple Watch」→ Watch（Plan C）收到 `planUpdated` → 主頁顯示課表。截圖兩端。
- [ ] **Step 2: 上行**：Watch 跑完寫 HealthKit（Plan C）→ iPhone sync → 訓練紀錄頁出現該筆一次且僅一次（驗 `makeWorkoutId` 去重）。
- [ ] **Step 3: RPE 端到端**：Watch 選 RPE 7 → metadata `com.paceriz.rpe=7` → iPhone 上傳後 `updateRPE` → workout_v2 帶 rpe=7 → 訓練紀錄頁顯示 RPE 7。
- [ ] **Step 4: 漏選 RPE fallback**：Watch 跳過 RPE → workout 無 rpe metadata → iPhone detail 由既有 `WorkoutReflectionGate` 自動彈出補問（驗證既有 gate 接住）。
- [ ] **Step 5: 自己 Read 所有截圖逐項驗**，不合格退回對應 task。
- [ ] **Step 6: Commit**

```bash
git commit -m "iOS Developer: iOS companion 端到端整合驗證 (Plan B Task 8)"
```

---

## Self-Review

- **Spec 覆蓋**：§3.1 下行→Task 2/3/4/5；§3.2 上行 RPE→Task 6；§3.4 dedup（既有 makeWorkoutId，無需改）→Task 8 Step 2 驗證；§3.3 segment parser→Task 7（視 spike）；漏選 RPE fallback→Task 8 Step 4。✅
- **Placeholder**：核心投影器（Task 2/3）+ RPE 讀取（Task 6）為完整 TDD code；WCSession/按鈕/掛鉤標 `// CONFIRM:`（既有 DI / 欄位名 / pace 格式 / intensity 值）為實作時需確認的真實接點，非空白。
- **型別一致**：`WatchPlanSnapshotDTO` / `WatchSegmentDTO`（Plan C Task 3 定義）跨兩 plan 一致；`RunActivity` / `IntervalBlock` / `RunSegment` 用既有 `TrainingSessionModels` 型別；`updateRPE(id:rpe:)` / `makeWorkoutId` 用既有實際簽名。✅
- **未涵蓋（刻意）**：watchOS app 本體 = Plan C；後端 = 不改。

---

## 已知尚未驗證（實作時確認）

1. `RunSegment.intensity` 實際列舉值（Task 3 過濾暖身緩和依此）。
2. `RunSegment.pace` / `IntervalBlock.workPace` 字串格式（Task 3 paceToSec）。
3. `day` 的日期 / planId 欄位名（Task 5）。
4. `AppleHealthWorkoutUploadService` 取得 `WorkoutRepository` 的既有 DI 路徑（Task 6）。
5. 後端 workout_v2 是否需要 `.segment` 邊界（Task 7 去留）。
