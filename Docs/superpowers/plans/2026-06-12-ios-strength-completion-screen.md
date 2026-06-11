# iOS 力量訓練完成回報畫面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓使用者對力量訓練日逐動作標記完成/略過 + 給整體 RPE，送 `POST /v2/strength/complete`，並把後端回傳的升/降級做成「升級慶祝」反饋；一次性提交 + 本地防重送。純 iOS、不動後端。

**Architecture:** 掛在 TrainingPlanV2 feature 下。新 `StrengthCompletionSheet`（present 為 sheet）→ `StrengthCompletionViewModel`（@MainActor）→ 窄協定 `StrengthCompletionRepository`（由既有 `TrainingPlanV2RepositoryImpl` conform）→ `TrainingPlanV2RemoteDataSource.completeStrengthSession` → `apiHelper.post`。成功後寫本地 `StrengthCompletionStore`（UserDefaults）標記已完成、鎖定入口。RPE pill 抽成共用 `RPESelectorView`（重用 `RecapPalette.rpe`）。

**Tech Stack:** Swift / SwiftUI / 既有分層（Presentation→Domain→Data→Core）/ `APICallHelper` / `DependencyContainer` / `ViewState<T>` / `DomainError` / NSLocalizedString / XCTest（target module `paceriz_dev`）。

**Spec:** `Docs/superpowers/specs/2026-06-11-ios-strength-completion-screen-design.md`

---

## ⚠️ 跨專案依賴（實作前必讀，不影響可開工但影響「閉環何時真的動」）

後端校準引擎 `calibrate_after_completion` **完全以 `series_id` 配對**（無 series_id 的動作直接 `continue`、不校準），且 `overall_rpe` 只在「有 series_id 的動作」上才驅動升降級。後端帶 series_id 的課表生成（C1）**已 merge 本機 main 但尚未部署**。

- 在後端部署 + 課表重生成出帶 `series_id` 的力量動作之前：本畫面送出的 completion 仍會被後端**記錄**，但 `progress_updates` 會是 `[]`（levels 不動）→ 反饋落在「安靜確認」。
- 本畫面**不因此阻塞**：照常開發、ship。等後端部署後升級慶祝才會出現。實機 E2E（Task 10）需在後端已部署、且該帳號課表含 series_id 的 dev 環境驗證升級路徑；否則只能驗「安靜確認 + 本地鎖定」。

---

## File Structure

| 檔案 | 動作 | 責任 |
|------|------|------|
| `Havital/Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift` | Modify | `Exercise` 加 `seriesId: String?`（CodingKey `series_id`） |
| `Havital/Features/TrainingPlanV2/Data/DTOs/TrainingSessionDTOs.swift` | Modify | `ExerciseDTO` 加 `seriesId: String?`（CodingKey `series_id`） |
| `Havital/Features/TrainingPlanV2/Data/Mappers/TrainingSessionMapper.swift` | Modify | Exercise toEntity/toDTO 對應 `seriesId` |
| `Havital/Features/TrainingPlanV2/Domain/Entities/StrengthCompletionModels.swift` | Create | Domain：`StrengthExerciseStatus`、`StrengthExerciseInput`、`StrengthProgressUpdate`(+reason)、`StrengthCompletionResult` |
| `Havital/Features/TrainingPlanV2/Data/DTOs/StrengthCompletionDTOs.swift` | Create | `StrengthCompletionRequestDTO`/`StrengthExerciseStatusDTO`(Encodable)、`StrengthCompletionResponseDTO`/`ProgressUpdateDTO`(Codable) |
| `Havital/Features/TrainingPlanV2/Data/Mappers/StrengthCompletionMapper.swift` | Create | request 輸入→RequestDTO；ResponseDTO→`StrengthCompletionResult` |
| `Havital/Features/TrainingPlanV2/Domain/Repositories/StrengthCompletionRepository.swift` | Create | 窄協定 `completeStrengthSession(...)` |
| `Havital/Features/TrainingPlanV2/Data/DataSources/TrainingPlanV2RemoteDataSource.swift` | Modify | 加 `completeStrengthSession(_:)`（+ protocol 簽名） |
| `Havital/Features/TrainingPlanV2/Data/Repositories/TrainingPlanV2RepositoryImpl.swift` | Modify | `extension ...: StrengthCompletionRepository`；DI 註冊窄協定 |
| `Havital/Core/Storage/StrengthCompletionStore.swift` | Create | 本地已完成標記（protocol + UserDefaults impl） |
| `Havital/Features/TrainingPlanV2/Presentation/Components/RPESelectorView.swift` | Create | 共用 1-10 RPE pill + feedback（重用 `RecapPalette.rpe`） |
| `Havital/Features/TrainingPlanV2/Presentation/ViewModels/StrengthCompletionViewModel.swift` | Create | 狀態/組 request/提交/反饋/寫本地 |
| `Havital/Features/TrainingPlanV2/Presentation/Views/StrengthCompletionSheet.swift` | Create | 畫面本體（動作 toggle + RPE + 送出 + 反饋） |
| `Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift` | Modify | 力量活動加「完成訓練」CTA + present sheet + 已完成鎖定 |
| `Havital/Resources/{zh-Hant,en,ja}.lproj/Localizable.strings` | Modify | `strength.completion.*` + `strength.series.*` |
| `HavitalTests/StrengthCompletionTests.swift` | Create | DTO 編碼/Mapper/Store 測試 |
| `HavitalTests/StrengthCompletionViewModelTests.swift` | Create | ViewModel 測試（mock 窄協定 + mock store） |
| `HavitalTests/Mocks/MockStrengthCompletionRepository.swift` | Create | 窄協定 mock |
| `.maestro/flows/strength-completion.yaml` | Create | E2E flow |

**Build 指令**（每個 Task 末用；UDID 以 `xcrun simctl list devices | grep Booted` 現查為準，CLAUDE.md 寫的 UDID 已可能失效）：
```bash
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
**測試指令**：`xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:HavitalTests/<TestClass>`

---

### Task 1: Exercise / DTO / Mapper 加 `seriesId`

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Data/DTOs/TrainingSessionDTOs.swift`（ExerciseDTO）
- Modify: `Havital/Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift`（Exercise）
- Modify: `Havital/Features/TrainingPlanV2/Data/Mappers/TrainingSessionMapper.swift`
- Test: `HavitalTests/StrengthCompletionTests.swift`

- [ ] **Step 1: 寫 failing test（解碼 + mapper 帶 series_id）**

Create `HavitalTests/StrengthCompletionTests.swift`：
```swift
import XCTest
@testable import paceriz_dev

final class StrengthCompletionTests: XCTestCase {

    func test_exerciseDTO_decodes_series_id() throws {
        let json = """
        {"exercise_id":"plank","series_id":"plank_series","name":"棒式","sets":3,"duration_seconds":45}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ExerciseDTO.self, from: json)
        XCTAssertEqual(dto.seriesId, "plank_series")
    }

    func test_mapper_carries_series_id_to_entity() {
        let dto = ExerciseDTO(
            exerciseId: "plank", name: "棒式", sets: 3, reps: nil, repsRange: nil,
            durationSeconds: 45, weightKg: nil, restSeconds: nil, description: nil,
            seriesId: "plank_series"
        )
        let entity = TrainingSessionMapper.toEntity(from: dto)
        XCTAssertEqual(entity.seriesId, "plank_series")
    }

    func test_exercise_without_series_id_decodes_nil() throws {
        let json = """
        {"exercise_id":"plank","name":"棒式","sets":3}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ExerciseDTO.self, from: json)
        XCTAssertNil(dto.seriesId)
    }
}
```

- [ ] **Step 2: 跑 test 確認 FAIL**

Run: `xcodebuild test ... -only-testing:HavitalTests/StrengthCompletionTests`
Expected: 編譯失敗（`ExerciseDTO` 無 `seriesId` argument / `Exercise` 無 `seriesId`）。

- [ ] **Step 3: ExerciseDTO 加 seriesId**

`TrainingSessionDTOs.swift` 的 `ExerciseDTO`：在 `description` 後加欄位、CodingKeys 加對應：
```swift
struct ExerciseDTO: Codable, Equatable {
    let exerciseId: String?
    let name: String
    let sets: Int?
    let reps: Int?
    let repsRange: String?
    let durationSeconds: Int?
    let weightKg: Double?
    let restSeconds: Int?
    let description: String?
    let seriesId: String?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case name
        case sets
        case reps
        case repsRange = "reps_range"
        case durationSeconds = "duration_seconds"
        case weightKg = "weight_kg"
        case restSeconds = "rest_seconds"
        case description
        case seriesId = "series_id"
    }
}
```

- [ ] **Step 4: Exercise entity 加 seriesId**

`TrainingSessionModels.swift` 的 `Exercise`：
```swift
struct Exercise: Codable, Equatable {
    let exerciseId: String?
    let name: String
    let sets: Int?
    let reps: String?
    let durationSeconds: Int?
    let weightKg: Double?
    let restSeconds: Int?
    let description: String?
    let seriesId: String?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case name
        case sets
        case reps
        case durationSeconds = "duration_seconds"
        case weightKg = "weight_kg"
        case restSeconds = "rest_seconds"
        case description
        case seriesId = "series_id"
    }
}
```

> ⚠️ 加新欄位後，**所有手動建構 `Exercise(...)` 的呼叫點**（含其他既有測試 fixtures）都要補 `seriesId:` 參數，否則編譯失敗。Step 6 build 會抓出來；逐一補 `seriesId: nil`。

- [ ] **Step 5: Mapper 對應 seriesId**

`TrainingSessionMapper.swift` 的 Exercise `toEntity` / `toDTO`：
```swift
static func toEntity(from dto: ExerciseDTO) -> Exercise {
    let repsString: String? = dto.repsRange ?? dto.reps.map { String($0) }
    return Exercise(
        exerciseId: dto.exerciseId,
        name: dto.name,
        sets: dto.sets,
        reps: repsString,
        durationSeconds: dto.durationSeconds,
        weightKg: dto.weightKg,
        restSeconds: dto.restSeconds,
        description: dto.description,
        seriesId: dto.seriesId
    )
}

static func toDTO(from entity: Exercise) -> ExerciseDTO {
    let repsInt = entity.reps.flatMap { Int($0) }
    let repsRange: String? = (repsInt == nil) ? entity.reps : nil
    return ExerciseDTO(
        exerciseId: entity.exerciseId,
        name: entity.name,
        sets: entity.sets,
        reps: repsInt,
        repsRange: repsRange,
        durationSeconds: entity.durationSeconds,
        weightKg: entity.weightKg,
        restSeconds: entity.restSeconds,
        description: entity.description,
        seriesId: entity.seriesId
    )
}
```

- [ ] **Step 6: build + 跑 test 確認 PASS**

Run build（修掉所有缺 `seriesId:` 的 `Exercise(...)`/`ExerciseDTO(...)` 呼叫點，補 `seriesId: nil`），再跑：
`xcodebuild test ... -only-testing:HavitalTests/StrengthCompletionTests`
Expected: 3 tests PASS。

- [ ] **Step 7: Commit**

```bash
git add Havital/Features/TrainingPlanV2/Data/DTOs/TrainingSessionDTOs.swift \
  Havital/Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift \
  Havital/Features/TrainingPlanV2/Data/Mappers/TrainingSessionMapper.swift \
  HavitalTests/StrengthCompletionTests.swift
git commit -m "feat(strength): decode series_id on Exercise/DTO/Mapper

iOS Developer"
```

---

### Task 2: 完成回報 DTO + Domain entity + Mapper

**Files:**
- Create: `Havital/Features/TrainingPlanV2/Domain/Entities/StrengthCompletionModels.swift`
- Create: `Havital/Features/TrainingPlanV2/Data/DTOs/StrengthCompletionDTOs.swift`
- Create: `Havital/Features/TrainingPlanV2/Data/Mappers/StrengthCompletionMapper.swift`
- Test: `HavitalTests/StrengthCompletionTests.swift`（同檔追加）

- [ ] **Step 1: 寫 failing test（request 編碼 snake_case + response 解碼 + mapper）**

在 `StrengthCompletionTests.swift` 追加：
```swift
    func test_requestDTO_encodes_snake_case() throws {
        let req = StrengthCompletionRequestDTO(
            dayDate: "2026-06-12",
            strengthType: "core_stability",
            exercises: [
                StrengthExerciseStatusDTO(exerciseId: "plank", seriesId: "plank_series", status: "completed"),
                StrengthExerciseStatusDTO(exerciseId: "dead_bug", seriesId: "dead_bug_series", status: "skipped")
            ],
            overallRpe: 4,
            durationMinutes: 15,
            weeklyPlanId: "wp_1"
        )
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["day_date"] as? String, "2026-06-12")
        XCTAssertEqual(obj["strength_type"] as? String, "core_stability")
        XCTAssertEqual(obj["overall_rpe"] as? Int, 4)
        XCTAssertEqual(obj["weekly_plan_id"] as? String, "wp_1")
        let exs = obj["exercises"] as! [[String: Any]]
        XCTAssertEqual(exs[0]["exercise_id"] as? String, "plank")
        XCTAssertEqual(exs[0]["series_id"] as? String, "plank_series")
        XCTAssertEqual(exs[1]["status"] as? String, "skipped")
        XCTAssertNil(exs[0]["actual_sets"])  // 粒度 B：不送 actual_*
    }

    func test_responseDTO_maps_to_result_with_reason() throws {
        let json = """
        {"progress_updates":[{"series_id":"plank_series","previous_level":1,"new_level":2,"reason":"rpe_upgrade"}]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StrengthCompletionResponseDTO.self, from: json)
        let result = StrengthCompletionMapper.toEntity(from: dto)
        XCTAssertEqual(result.progressUpdates.count, 1)
        let u = result.progressUpdates[0]
        XCTAssertEqual(u.seriesId, "plank_series")
        XCTAssertEqual(u.previousLevel, 1)
        XCTAssertEqual(u.newLevel, 2)
        XCTAssertEqual(u.reason, .upgrade)
    }

    func test_empty_progress_updates_maps_to_empty() throws {
        let json = #"{"progress_updates":[]}"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StrengthCompletionResponseDTO.self, from: json)
        let result = StrengthCompletionMapper.toEntity(from: dto)
        XCTAssertTrue(result.progressUpdates.isEmpty)
    }
```

- [ ] **Step 2: 跑 test 確認 FAIL**（型別未定義，編譯失敗）

- [ ] **Step 3: Domain entity**

Create `StrengthCompletionModels.swift`：
```swift
import Foundation

/// 單一動作的完成狀態（送給後端 / 校準訊號）
enum StrengthExerciseStatus: String, Equatable {
    case completed
    case skipped
}

/// 組 request 用的單一動作輸入
struct StrengthExerciseInput: Equatable {
    let exerciseId: String?
    let seriesId: String?
    let status: StrengthExerciseStatus
}

/// 後端回傳的升/降級原因
enum StrengthProgressReason: Equatable {
    case upgrade
    case downgrade
    case unknown
}

/// 單一 series 的 level 變化
struct StrengthProgressUpdate: Equatable {
    let seriesId: String
    let previousLevel: Int
    let newLevel: Int
    let reason: StrengthProgressReason
}

/// 完成回報結果
struct StrengthCompletionResult: Equatable {
    let progressUpdates: [StrengthProgressUpdate]
}
```

- [ ] **Step 4: DTO**

Create `StrengthCompletionDTOs.swift`：
```swift
import Foundation

struct StrengthExerciseStatusDTO: Encodable, Equatable {
    let exerciseId: String?
    let seriesId: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case seriesId = "series_id"
        case status
    }
}

struct StrengthCompletionRequestDTO: Encodable, Equatable {
    let dayDate: String
    let strengthType: String
    let exercises: [StrengthExerciseStatusDTO]
    let overallRpe: Int
    let durationMinutes: Int?
    let weeklyPlanId: String?

    enum CodingKeys: String, CodingKey {
        case dayDate = "day_date"
        case strengthType = "strength_type"
        case exercises
        case overallRpe = "overall_rpe"
        case durationMinutes = "duration_minutes"
        case weeklyPlanId = "weekly_plan_id"
    }
}

struct ProgressUpdateDTO: Codable, Equatable {
    let seriesId: String
    let previousLevel: Int
    let newLevel: Int
    let reason: String

    enum CodingKeys: String, CodingKey {
        case seriesId = "series_id"
        case previousLevel = "previous_level"
        case newLevel = "new_level"
        case reason
    }
}

struct StrengthCompletionResponseDTO: Codable, Equatable {
    let progressUpdates: [ProgressUpdateDTO]

    enum CodingKeys: String, CodingKey {
        case progressUpdates = "progress_updates"
    }
}
```

- [ ] **Step 5: Mapper**

Create `StrengthCompletionMapper.swift`：
```swift
import Foundation

enum StrengthCompletionMapper {

    static func toRequestDTO(
        dayDate: String,
        strengthType: String,
        inputs: [StrengthExerciseInput],
        overallRpe: Int,
        durationMinutes: Int?,
        weeklyPlanId: String?
    ) -> StrengthCompletionRequestDTO {
        StrengthCompletionRequestDTO(
            dayDate: dayDate,
            strengthType: strengthType,
            exercises: inputs.map {
                StrengthExerciseStatusDTO(
                    exerciseId: $0.exerciseId,
                    seriesId: $0.seriesId,
                    status: $0.status.rawValue
                )
            },
            overallRpe: overallRpe,
            durationMinutes: durationMinutes,
            weeklyPlanId: weeklyPlanId
        )
    }

    static func toEntity(from dto: StrengthCompletionResponseDTO) -> StrengthCompletionResult {
        StrengthCompletionResult(
            progressUpdates: dto.progressUpdates.map { u in
                StrengthProgressUpdate(
                    seriesId: u.seriesId,
                    previousLevel: u.previousLevel,
                    newLevel: u.newLevel,
                    reason: reason(from: u.reason)
                )
            }
        )
    }

    private static func reason(from raw: String) -> StrengthProgressReason {
        switch raw {
        case "rpe_upgrade": return .upgrade
        case "rpe_downgrade": return .downgrade
        default: return .unknown
        }
    }
}
```

- [ ] **Step 6: build + 跑 test 確認 PASS**

Run: `xcodebuild test ... -only-testing:HavitalTests/StrengthCompletionTests`
Expected: 全部 PASS（含 Task 1 的 + 本 Task 3 個新測試）。

- [ ] **Step 7: Commit**
```bash
git add Havital/Features/TrainingPlanV2/Domain/Entities/StrengthCompletionModels.swift \
  Havital/Features/TrainingPlanV2/Data/DTOs/StrengthCompletionDTOs.swift \
  Havital/Features/TrainingPlanV2/Data/Mappers/StrengthCompletionMapper.swift \
  HavitalTests/StrengthCompletionTests.swift
git commit -m "feat(strength): completion request/response DTOs + domain + mapper

iOS Developer"
```

---

### Task 3: 窄協定 Repository + RemoteDataSource + DI 接線

**Files:**
- Create: `Havital/Features/TrainingPlanV2/Domain/Repositories/StrengthCompletionRepository.swift`
- Modify: `Havital/Features/TrainingPlanV2/Data/DataSources/TrainingPlanV2RemoteDataSource.swift`（impl + 其 protocol `TrainingPlanV2RemoteDataSourceProtocol`）
- Modify: `Havital/Features/TrainingPlanV2/Data/Repositories/TrainingPlanV2RepositoryImpl.swift`（conformance + DI 註冊）

> 本 Task 為三層接線（窄協定 + DataSource POST + Impl glue + DI）。glue 很薄；正確性由 Task 2（編碼/解碼）+ Task 5（ViewModel mock 窄協定）+ Task 10（真實 HTTP）覆蓋，本 Task 以 **build 通過** 為驗收，不另寫單元測試（避免為 large RemoteDataSource protocol 造 mock 的低價值負擔）。

- [ ] **Step 1: 窄協定**

Create `StrengthCompletionRepository.swift`：
```swift
import Foundation

/// 力量訓練完成回報（窄協定，便於 ViewModel 依賴與測試）。
/// 由 TrainingPlanV2RepositoryImpl conform。
protocol StrengthCompletionRepository {
    func completeStrengthSession(
        dayDate: String,
        strengthType: String,
        inputs: [StrengthExerciseInput],
        overallRpe: Int,
        durationMinutes: Int?,
        weeklyPlanId: String?
    ) async throws -> StrengthCompletionResult
}
```

- [ ] **Step 2: RemoteDataSource 加方法（protocol + impl）**

在 `TrainingPlanV2RemoteDataSource.swift` 的 `TrainingPlanV2RemoteDataSourceProtocol` 加簽名：
```swift
    func completeStrengthSession(_ request: StrengthCompletionRequestDTO) async throws -> StrengthCompletionResponseDTO
```
在 class impl 加方法（照既有 POST 範本 `createOverviewForRace` 的 `tracked { apiHelper.post }` 寫法）：
```swift
    func completeStrengthSession(_ request: StrengthCompletionRequestDTO) async throws -> StrengthCompletionResponseDTO {
        Logger.debug("[TrainingPlanV2RemoteDS] POST /v2/strength/complete date=\(request.dayDate) type=\(request.strengthType)")
        let response = try await tracked("TrainingPlanV2RemoteDataSource: completeStrengthSession") {
            try await apiHelper.post(
                StrengthCompletionResponseDTO.self,
                path: "/v2/strength/complete",
                body: request
            )
        }
        Logger.info("[TrainingPlanV2RemoteDS] strength complete ok: \(response.progressUpdates.count) updates")
        return response
    }
```

- [ ] **Step 3: RepositoryImpl conform 窄協定**

在 `TrainingPlanV2RepositoryImpl.swift` 末端（既有 DI extension 之前）加：
```swift
// MARK: - StrengthCompletionRepository
extension TrainingPlanV2RepositoryImpl: StrengthCompletionRepository {
    func completeStrengthSession(
        dayDate: String,
        strengthType: String,
        inputs: [StrengthExerciseInput],
        overallRpe: Int,
        durationMinutes: Int?,
        weeklyPlanId: String?
    ) async throws -> StrengthCompletionResult {
        do {
            let request = StrengthCompletionMapper.toRequestDTO(
                dayDate: dayDate,
                strengthType: strengthType,
                inputs: inputs,
                overallRpe: overallRpe,
                durationMinutes: durationMinutes,
                weeklyPlanId: weeklyPlanId
            )
            let dto = try await remoteDataSource.completeStrengthSession(request)
            return StrengthCompletionMapper.toEntity(from: dto)
        } catch {
            logErrorToCloud(module: "Strength", operation: "complete", error: error, context: ["date": dayDate])
            throw error.toDomainError()
        }
    }
}
```
> `remoteDataSource`、`logErrorToCloud`、`error.toDomainError()` 都是該 class 既有可用成員（見既有方法）。

- [ ] **Step 4: DI 註冊窄協定**

在 `registerTrainingPlanV2Module()` 內，`register(repository as TrainingPlanV2Repository, ...)` 後加一行（同一個 instance 也註冊為窄協定）：
```swift
        register(repository as StrengthCompletionRepository, forProtocol: StrengthCompletionRepository.self)
```

- [ ] **Step 5: build 確認通過**

Run build。Expected: 編譯成功（三層接線完整、DI 解析得到窄協定）。

- [ ] **Step 6: Commit**
```bash
git add Havital/Features/TrainingPlanV2/Domain/Repositories/StrengthCompletionRepository.swift \
  Havital/Features/TrainingPlanV2/Data/DataSources/TrainingPlanV2RemoteDataSource.swift \
  Havital/Features/TrainingPlanV2/Data/Repositories/TrainingPlanV2RepositoryImpl.swift
git commit -m "feat(strength): StrengthCompletionRepository + POST /v2/strength/complete wiring

iOS Developer"
```

---

### Task 4: 本地完成標記 StrengthCompletionStore

**Files:**
- Create: `Havital/Core/Storage/StrengthCompletionStore.swift`
- Test: `HavitalTests/StrengthCompletionTests.swift`（追加）

- [ ] **Step 1: 寫 failing test**

追加：
```swift
    func test_store_mark_and_read_roundtrip() {
        let defaults = UserDefaults(suiteName: "test.strength.\(UUID().uuidString)")!
        let store = UserDefaultsStrengthCompletionStore(defaults: defaults)
        XCTAssertFalse(store.isCompleted(dayDate: "2026-06-12", strengthType: "core_stability"))
        XCTAssertNil(store.completedRPE(dayDate: "2026-06-12", strengthType: "core_stability"))

        store.markCompleted(dayDate: "2026-06-12", strengthType: "core_stability", rpe: 4)

        XCTAssertTrue(store.isCompleted(dayDate: "2026-06-12", strengthType: "core_stability"))
        XCTAssertEqual(store.completedRPE(dayDate: "2026-06-12", strengthType: "core_stability"), 4)
        // 不同 type 不互相影響
        XCTAssertFalse(store.isCompleted(dayDate: "2026-06-12", strengthType: "glutes_hip"))
    }
```

- [ ] **Step 2: 跑 test 確認 FAIL**（型別未定義）

- [ ] **Step 3: 實作**

Create `StrengthCompletionStore.swift`：
```swift
import Foundation

/// 本地記錄「某天某力量類型已回報完成」（一次性防重送 + 顯示已完成態）。
protocol StrengthCompletionStore {
    func isCompleted(dayDate: String, strengthType: String) -> Bool
    func completedRPE(dayDate: String, strengthType: String) -> Int?
    func markCompleted(dayDate: String, strengthType: String, rpe: Int)
}

final class UserDefaultsStrengthCompletionStore: StrengthCompletionStore {
    static let shared = UserDefaultsStrengthCompletionStore()

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(_ dayDate: String, _ strengthType: String) -> String {
        "strength_completed.\(dayDate).\(strengthType)"
    }

    func isCompleted(dayDate: String, strengthType: String) -> Bool {
        defaults.object(forKey: key(dayDate, strengthType)) != nil
    }

    func completedRPE(dayDate: String, strengthType: String) -> Int? {
        defaults.object(forKey: key(dayDate, strengthType)) as? Int
    }

    func markCompleted(dayDate: String, strengthType: String, rpe: Int) {
        defaults.set(rpe, forKey: key(dayDate, strengthType))
    }
}
```

- [ ] **Step 4: 跑 test 確認 PASS**

Run: `xcodebuild test ... -only-testing:HavitalTests/StrengthCompletionTests`

- [ ] **Step 5: Commit**
```bash
git add Havital/Core/Storage/StrengthCompletionStore.swift HavitalTests/StrengthCompletionTests.swift
git commit -m "feat(strength): local StrengthCompletionStore for one-shot dedup

iOS Developer"
```

---

### Task 5: StrengthCompletionViewModel

**Files:**
- Create: `Havital/Features/TrainingPlanV2/Presentation/ViewModels/StrengthCompletionViewModel.swift`
- Create: `HavitalTests/Mocks/MockStrengthCompletionRepository.swift`
- Test: `HavitalTests/StrengthCompletionViewModelTests.swift`

- [ ] **Step 1: 寫 mock（窄協定，trivial）**

Create `HavitalTests/Mocks/MockStrengthCompletionRepository.swift`：
```swift
import Foundation
@testable import paceriz_dev

final class MockStrengthCompletionRepository: StrengthCompletionRepository {
    var capturedInputs: [StrengthExerciseInput]?
    var capturedRPE: Int?
    var capturedDayDate: String?
    var capturedStrengthType: String?
    var capturedWeeklyPlanId: String?
    var stubResult: StrengthCompletionResult = .init(progressUpdates: [])
    var stubError: Error?

    func completeStrengthSession(
        dayDate: String, strengthType: String, inputs: [StrengthExerciseInput],
        overallRpe: Int, durationMinutes: Int?, weeklyPlanId: String?
    ) async throws -> StrengthCompletionResult {
        capturedDayDate = dayDate
        capturedStrengthType = strengthType
        capturedInputs = inputs
        capturedRPE = overallRpe
        capturedWeeklyPlanId = weeklyPlanId
        if let e = stubError { throw e }
        return stubResult
    }
}

final class MockStrengthCompletionStore: StrengthCompletionStore {
    var completed: [String: Int] = [:]
    private func k(_ d: String, _ t: String) -> String { "\(d).\(t)" }
    func isCompleted(dayDate: String, strengthType: String) -> Bool { completed[k(dayDate, strengthType)] != nil }
    func completedRPE(dayDate: String, strengthType: String) -> Int? { completed[k(dayDate, strengthType)] }
    func markCompleted(dayDate: String, strengthType: String, rpe: Int) { completed[k(dayDate, strengthType)] = rpe }
}
```

- [ ] **Step 2: 寫 failing test（ViewModel 行為）**

Create `HavitalTests/StrengthCompletionViewModelTests.swift`：
```swift
import XCTest
@testable import paceriz_dev

@MainActor
final class StrengthCompletionViewModelTests: XCTestCase {

    private func makeActivity() -> StrengthActivity {
        StrengthActivity(
            strengthType: "core_stability",
            exercises: [
                Exercise(exerciseId: "plank", name: "棒式", sets: 3, reps: nil, durationSeconds: 45, weightKg: nil, restSeconds: nil, description: nil, seriesId: "plank_series"),
                Exercise(exerciseId: "dead_bug", name: "死蟲式", sets: 3, reps: "12", durationSeconds: nil, weightKg: nil, restSeconds: nil, description: nil, seriesId: "dead_bug_series")
            ],
            durationMinutes: 15,
            description: nil
        )
    }

    private func makeVM(repo: MockStrengthCompletionRepository, store: MockStrengthCompletionStore) -> StrengthCompletionViewModel {
        StrengthCompletionViewModel(
            activity: makeActivity(), dayDate: "2026-06-12", weeklyPlanId: "wp_1",
            repository: repo, store: store
        )
    }

    func test_default_all_completed_and_rpe_required() {
        let vm = makeVM(repo: .init(), store: .init())
        // 預設全部完成
        XCTAssertEqual(vm.status(for: "plank"), .completed)
        // RPE 未選 → 不能送
        XCTAssertFalse(vm.canSubmit)
        vm.selectedRPE = 4
        XCTAssertTrue(vm.canSubmit)
    }

    func test_toggle_skip_builds_correct_request() async {
        let repo = MockStrengthCompletionRepository()
        let vm = makeVM(repo: repo, store: .init())
        vm.selectedRPE = 4
        vm.toggleSkip(exerciseId: "dead_bug")   // dead_bug → skipped
        await vm.submit()

        let inputs = repo.capturedInputs ?? []
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(inputs.first { $0.exerciseId == "plank" }?.status, .completed)
        XCTAssertEqual(inputs.first { $0.exerciseId == "dead_bug" }?.status, .skipped)
        XCTAssertEqual(inputs.first { $0.exerciseId == "plank" }?.seriesId, "plank_series")
        XCTAssertEqual(repo.capturedRPE, 4)
        XCTAssertEqual(repo.capturedDayDate, "2026-06-12")
        XCTAssertEqual(repo.capturedWeeklyPlanId, "wp_1")
    }

    func test_submit_success_marks_completed_and_enters_feedback() async {
        let repo = MockStrengthCompletionRepository()
        repo.stubResult = .init(progressUpdates: [
            .init(seriesId: "plank_series", previousLevel: 1, newLevel: 2, reason: .upgrade)
        ])
        let store = MockStrengthCompletionStore()
        let vm = makeVM(repo: repo, store: store)
        vm.selectedRPE = 4
        await vm.submit()

        XCTAssertTrue(store.isCompleted(dayDate: "2026-06-12", strengthType: "core_stability"))
        guard case .feedback(let fb) = vm.phase else { return XCTFail("expected feedback") }
        XCTAssertEqual(fb.upgrades.count, 1)
        XCTAssertEqual(fb.upgrades[0].newLevel, 2)
    }

    func test_submit_empty_updates_is_silent_confirm() async {
        let repo = MockStrengthCompletionRepository()  // stubResult 預設 []
        let vm = makeVM(repo: repo, store: .init())
        vm.selectedRPE = 6
        await vm.submit()
        guard case .feedback(let fb) = vm.phase else { return XCTFail("expected feedback") }
        XCTAssertTrue(fb.upgrades.isEmpty)
        XCTAssertEqual(fb.rpe, 6)
    }

    func test_submit_failure_does_not_mark_and_sets_error() async {
        let repo = MockStrengthCompletionRepository()
        repo.stubError = DomainError.networkFailure("boom")
        let store = MockStrengthCompletionStore()
        let vm = makeVM(repo: repo, store: store)
        vm.selectedRPE = 4
        await vm.submit()

        XCTAssertFalse(store.isCompleted(dayDate: "2026-06-12", strengthType: "core_stability"))
        guard case .failed = vm.phase else { return XCTFail("expected failed") }
    }
```

- [ ] **Step 3: 跑 test 確認 FAIL**

- [ ] **Step 4: 實作 ViewModel**

Create `StrengthCompletionViewModel.swift`：
```swift
import Foundation
import SwiftUI

@MainActor
final class StrengthCompletionViewModel: ObservableObject {

    struct Feedback: Equatable {
        let rpe: Int
        let upgrades: [StrengthProgressUpdate]   // 含 upgrade/downgrade 的 series
    }

    enum Phase: Equatable {
        case form
        case submitting
        case feedback(Feedback)
        case failed(DomainError)
    }

    @Published private(set) var phase: Phase = .form
    @Published var selectedRPE: Int?
    @Published private(set) var statuses: [String: StrengthExerciseStatus] = [:]  // key = exerciseId (or fallback index key)

    let activity: StrengthActivity
    private let dayDate: String
    private let weeklyPlanId: String?
    private let repository: StrengthCompletionRepository
    private let store: StrengthCompletionStore

    init(
        activity: StrengthActivity,
        dayDate: String,
        weeklyPlanId: String?,
        repository: StrengthCompletionRepository,
        store: StrengthCompletionStore
    ) {
        self.activity = activity
        self.dayDate = dayDate
        self.weeklyPlanId = weeklyPlanId
        self.repository = repository
        self.store = store
        // 預設全部完成
        for (i, ex) in activity.exercises.enumerated() {
            statuses[Self.exKey(ex, i)] = .completed
        }
    }

    static func exKey(_ ex: Exercise, _ index: Int) -> String {
        ex.exerciseId ?? "idx_\(index)"
    }

    func status(for exerciseId: String) -> StrengthExerciseStatus {
        statuses[exerciseId] ?? .completed
    }

    func toggleSkip(exerciseId: String) {
        statuses[exerciseId] = (statuses[exerciseId] == .skipped) ? .completed : .skipped
    }

    var canSubmit: Bool {
        if case .submitting = phase { return false }
        return selectedRPE != nil
    }

    func submit() async {
        guard let rpe = selectedRPE else { return }
        phase = .submitting
        let inputs: [StrengthExerciseInput] = activity.exercises.enumerated().map { (i, ex) in
            StrengthExerciseInput(
                exerciseId: ex.exerciseId,
                seriesId: ex.seriesId,
                status: statuses[Self.exKey(ex, i)] ?? .completed
            )
        }
        do {
            let result = try await repository.completeStrengthSession(
                dayDate: dayDate,
                strengthType: activity.strengthType,
                inputs: inputs,
                overallRpe: rpe,
                durationMinutes: activity.durationMinutes,
                weeklyPlanId: weeklyPlanId
            )
            store.markCompleted(dayDate: dayDate, strengthType: activity.strengthType, rpe: rpe)
            let changed = result.progressUpdates.filter { $0.reason == .upgrade || $0.reason == .downgrade }
            phase = .feedback(Feedback(rpe: rpe, upgrades: changed))
        } catch {
            phase = .failed(error.toDomainError())
        }
    }
}
```

- [ ] **Step 5: 跑 test 確認 PASS**

Run: `xcodebuild test ... -only-testing:HavitalTests/StrengthCompletionViewModelTests`
Expected: 5 tests PASS。

- [ ] **Step 6: Commit**
```bash
git add Havital/Features/TrainingPlanV2/Presentation/ViewModels/StrengthCompletionViewModel.swift \
  HavitalTests/Mocks/MockStrengthCompletionRepository.swift \
  HavitalTests/StrengthCompletionViewModelTests.swift
git commit -m "feat(strength): StrengthCompletionViewModel (toggle/submit/feedback)

iOS Developer"
```

---

### Task 6: 共用 RPESelectorView

**Files:**
- Create: `Havital/Features/TrainingPlanV2/Presentation/Components/RPESelectorView.swift`

> 純 SwiftUI view（綁 `@Binding selectedRPE: Int?`），重用既有 `RecapPalette.rpe`。無單元測試（與 repo 慣例一致，view 不做 snapshot test），由 Task 10 Maestro/實機驗。

- [ ] **Step 1: 實作**

Create `RPESelectorView.swift`（pill + feedback，移植自 `WorkoutReflectionView` 的 rpePill/rpeFeedback，改為可重用、用字串 key `strength.completion.*`）：
```swift
import SwiftUI

/// 1-10 RPE 選擇器（pill 色階 + 文案）。可重用於力量完成回報。
struct RPESelectorView: View {
    @Binding var selectedRPE: Int?

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedRPE == nil
                     ? NSLocalizedString("strength.completion.rpe_prompt", comment: "這次整體感覺如何？")
                     : String(format: NSLocalizedString("strength.completion.rpe_selected", comment: "整體體感 %d/10"), selectedRPE!))
                    .font(AppFont.micro())
                    .foregroundColor(.primary)
                Spacer()
                if let rpe = selectedRPE {
                    Text(feedback(rpe))
                        .font(AppFont.micro())
                        .foregroundColor(RecapPalette.rpe(rpe))
                }
            }
            .padding(.horizontal, 2)

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { value in
                    pill(value)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func pill(_ value: Int) -> some View {
        let c = RecapPalette.rpe(value)
        let selected = selectedRPE == value
        let dim = selectedRPE != nil && !selected
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedRPE = value }
        } label: {
            Text("\(value)")
                .font(AppFont.micro().monospacedDigit())
                .foregroundColor(selected ? .white : c)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(selected ? c : c.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .scaleEffect(selected ? 1.08 : 1.0)
                .opacity(dim ? 0.55 : 1.0)
                .shadow(color: selected ? c.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func feedback(_ v: Int) -> String {
        switch v {
        case ...3: return NSLocalizedString("strength.completion.rpe_feedback_low", comment: "輕巧地完成 ✓")
        case 4...5: return NSLocalizedString("strength.completion.rpe_feedback_medium", comment: "節奏掌握得不錯 ✓")
        case 6...7: return NSLocalizedString("strength.completion.rpe_feedback_high", comment: "紮實的一次 ✓")
        default:    return NSLocalizedString("strength.completion.rpe_feedback_max", comment: "硬仗打完了 💪")
        }
    }
}
```

- [ ] **Step 2: build 確認通過**

Run build。Expected: 成功（`AppFont`、`RecapPalette` 為既有可用符號）。

- [ ] **Step 3: Commit**
```bash
git add Havital/Features/TrainingPlanV2/Presentation/Components/RPESelectorView.swift
git commit -m "feat(strength): reusable RPESelectorView (1-10 pills + feedback)

iOS Developer"
```

---

### Task 7: StrengthCompletionSheet（畫面本體）

**Files:**
- Create: `Havital/Features/TrainingPlanV2/Presentation/Views/StrengthCompletionSheet.swift`

> SwiftUI view；由 Task 10 Maestro/實機驗收。

- [ ] **Step 1: 實作**

Create `StrengthCompletionSheet.swift`：
```swift
import SwiftUI

struct StrengthCompletionSheet: View {
    @StateObject var viewModel: StrengthCompletionViewModel
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .feedback(let fb):
                    feedbackView(fb)
                default:
                    formView
                }
            }
            .navigationTitle(NSLocalizedString("strength.completion.title", comment: "完成回報"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", comment: "關閉")) { onClose() }
                }
            }
        }
    }

    // MARK: Form
    private var formView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(strengthTypeName(viewModel.activity.strengthType))
                        .font(AppFont.body().weight(.semibold))
                    Text(NSLocalizedString("strength.completion.instructions", comment: "逐項標記完成或略過，再評估整體感受"))
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.activity.exercises.enumerated()), id: \.offset) { (i, ex) in
                        exerciseRow(ex, key: StrengthCompletionViewModel.exKey(ex, i))
                    }

                    RPESelectorView(selectedRPE: $viewModel.selectedRPE)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            submitBar
        }
    }

    private func exerciseRow(_ ex: Exercise, key: String) -> some View {
        let skipped = viewModel.status(for: key) == .skipped
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(AppFont.body())
                    .strikethrough(skipped)
                    .foregroundColor(skipped ? .secondary : .primary)
                Text(planLine(ex)).font(AppFont.micro()).foregroundColor(.secondary)
            }
            Spacer()
            Button {
                viewModel.toggleSkip(exerciseId: key)
            } label: {
                Text(skipped
                     ? NSLocalizedString("strength.completion.skipped", comment: "略過")
                     : NSLocalizedString("strength.completion.completed", comment: "已完成"))
                    .font(AppFont.micro().weight(.semibold))
                    .foregroundColor(skipped ? .secondary : .white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(skipped ? Color(UIColor.tertiarySystemFill) : RecapPalette.rpe(3))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private func planLine(_ ex: Exercise) -> String {
        var parts: [String] = []
        if let s = ex.sets { parts.append("\(s) \(NSLocalizedString("training.sets_unit", comment: ""))") }
        if let d = ex.durationSeconds { parts.append("\(d) \(NSLocalizedString("training.seconds_unit", comment: ""))") }
        else if let r = ex.reps { parts.append("\(r) \(NSLocalizedString("training.reps_unit", comment: ""))") }
        return parts.joined(separator: " × ")
    }

    private var submitBar: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            HStack {
                if case .submitting = viewModel.phase { ProgressView().tint(.white) }
                Text(NSLocalizedString("strength.completion.submit", comment: "完成訓練"))
                    .font(AppFont.body().weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundColor(.white)
            .background(viewModel.canSubmit ? PacerizColor.blue : Color.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!viewModel.canSubmit)
        .padding(16)
    }

    // MARK: Feedback
    private func feedbackView(_ fb: StrengthCompletionViewModel.Feedback) -> some View {
        VStack(spacing: 16) {
            Spacer()
            if let up = fb.upgrades.first(where: { $0.reason == .upgrade }) {
                Text(NSLocalizedString("strength.completion.upgrade_title", comment: "做得輕鬆漂亮 💪"))
                    .font(AppFont.title())
                Text(String(format: NSLocalizedString("strength.completion.upgrade_detail", comment: "%@ 升級 L%d→L%d"),
                            seriesName(up.seriesId), up.previousLevel, up.newLevel))
                    .font(AppFont.body()).multilineTextAlignment(.center)
                Text(NSLocalizedString("strength.completion.upgrade_next", comment: "下次課表會幫你進階"))
                    .font(AppFont.micro()).foregroundColor(.secondary)
            } else if let down = fb.upgrades.first(where: { $0.reason == .downgrade }) {
                Text(NSLocalizedString("strength.completion.downgrade_title", comment: "這次偏吃力"))
                    .font(AppFont.title())
                Text(String(format: NSLocalizedString("strength.completion.downgrade_detail", comment: "%@ 調整為 L%d，下次回到適合的強度"),
                            seriesName(down.seriesId), down.newLevel))
                    .font(AppFont.body()).multilineTextAlignment(.center)
            } else {
                Text("✓").font(.system(size: 44)).foregroundColor(RecapPalette.rpe(3))
                Text(String(format: NSLocalizedString("strength.completion.done_rpe", comment: "已完成 · RPE %d"), fb.rpe))
                    .font(AppFont.body())
            }
            Spacer()
            Button(NSLocalizedString("common.done", comment: "完成")) { onClose() }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundColor(.white).background(PacerizColor.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(16)
        }
        .padding()
    }

    private func strengthTypeName(_ t: String) -> String {
        NSLocalizedString("training.strength_type.\(t)", comment: "")
    }
    private func seriesName(_ seriesId: String) -> String {
        let key = "strength.series.\(seriesId)"
        let v = NSLocalizedString(key, comment: "")
        return v == key ? NSLocalizedString("strength.series.generic", comment: "力量動作") : v
    }
}
```

> 若 `AppFont.title()` / `PacerizColor.blue` / `common.close` / `common.done` 的確切符號/key 名與既有不同，build 會抓出來；以既有實際符號為準（grep `AppFont.` / `PacerizColor.` / 既有 close/done key）。

- [ ] **Step 2: build 確認通過**

- [ ] **Step 3: Commit**
```bash
git add Havital/Features/TrainingPlanV2/Presentation/Views/StrengthCompletionSheet.swift
git commit -m "feat(strength): StrengthCompletionSheet UI (toggles + RPE + feedback)

iOS Developer"
```

---

### Task 8: i18n 字串（三語）

**Files:**
- Modify: `Havital/Resources/zh-Hant.lproj/Localizable.strings`
- Modify: `Havital/Resources/en.lproj/Localizable.strings`
- Modify: `Havital/Resources/ja.lproj/Localizable.strings`

- [ ] **Step 1: 加字串（zh-Hant）**

在 `zh-Hant.lproj/Localizable.strings` 末端加（series key 須涵蓋 `domains/strength/configs/progression_ladders.yaml` 全部 series_id；下列為已知集合，實作時以該 YAML 現況補齊）：
```
"strength.completion.title" = "完成回報";
"strength.completion.instructions" = "逐項標記完成或略過，再評估整體感受";
"strength.completion.completed" = "已完成";
"strength.completion.skipped" = "略過";
"strength.completion.submit" = "完成訓練";
"strength.completion.rpe_prompt" = "這次整體感覺如何？";
"strength.completion.rpe_selected" = "整體體感 %d/10";
"strength.completion.rpe_feedback_low" = "輕巧地完成 ✓";
"strength.completion.rpe_feedback_medium" = "節奏掌握得不錯 ✓";
"strength.completion.rpe_feedback_high" = "紮實的一次 ✓";
"strength.completion.rpe_feedback_max" = "硬仗打完了 💪";
"strength.completion.done_rpe" = "已完成 · RPE %d";
"strength.completion.upgrade_title" = "做得輕鬆漂亮 💪";
"strength.completion.upgrade_detail" = "%@ 升級 L%d→L%d";
"strength.completion.upgrade_next" = "下次課表會幫你進階";
"strength.completion.downgrade_title" = "這次偏吃力";
"strength.completion.downgrade_detail" = "%@ 調整為 L%d，下次回到適合的強度";
"strength.completion.entry_cta" = "完成力量訓練";
"strength.completion.locked" = "已完成 · RPE %d";
"strength.series.generic" = "力量動作";
"strength.series.plank_series" = "棒式系列";
"strength.series.dead_bug_series" = "死蟲系列";
"strength.series.bird_dog_series" = "鳥狗系列";
"strength.series.side_plank_series" = "側棒系列";
"strength.series.bridge_series" = "臀橋系列";
"strength.series.clamshell_series" = "蚌殼系列";
"strength.series.squat_series" = "深蹲系列";
```

- [ ] **Step 2: 加字串（en）**

`en.lproj/Localizable.strings`：
```
"strength.completion.title" = "Log Session";
"strength.completion.instructions" = "Mark each exercise done or skipped, then rate overall effort";
"strength.completion.completed" = "Done";
"strength.completion.skipped" = "Skipped";
"strength.completion.submit" = "Complete";
"strength.completion.rpe_prompt" = "How did it feel overall?";
"strength.completion.rpe_selected" = "Overall effort %d/10";
"strength.completion.rpe_feedback_low" = "Breezed through it ✓";
"strength.completion.rpe_feedback_medium" = "Nicely paced ✓";
"strength.completion.rpe_feedback_high" = "Solid effort ✓";
"strength.completion.rpe_feedback_max" = "Tough one — done 💪";
"strength.completion.done_rpe" = "Done · RPE %d";
"strength.completion.upgrade_title" = "Crushed it 💪";
"strength.completion.upgrade_detail" = "%@ leveled up L%d→L%d";
"strength.completion.upgrade_next" = "Your next plan steps up";
"strength.completion.downgrade_title" = "That was tough";
"strength.completion.downgrade_detail" = "%@ set to L%d — back to the right intensity next time";
"strength.completion.entry_cta" = "Log Strength Session";
"strength.completion.locked" = "Done · RPE %d";
"strength.series.generic" = "Strength";
"strength.series.plank_series" = "Plank series";
"strength.series.dead_bug_series" = "Dead bug series";
"strength.series.bird_dog_series" = "Bird dog series";
"strength.series.side_plank_series" = "Side plank series";
"strength.series.bridge_series" = "Glute bridge series";
"strength.series.clamshell_series" = "Clamshell series";
"strength.series.squat_series" = "Squat series";
```

- [ ] **Step 3: 加字串（ja）**

`ja.lproj/Localizable.strings`：
```
"strength.completion.title" = "記録する";
"strength.completion.instructions" = "各種目を完了/スキップで記録し、全体のきつさを評価してください";
"strength.completion.completed" = "完了";
"strength.completion.skipped" = "スキップ";
"strength.completion.submit" = "完了する";
"strength.completion.rpe_prompt" = "全体的にどうでしたか？";
"strength.completion.rpe_selected" = "全体のきつさ %d/10";
"strength.completion.rpe_feedback_low" = "余裕でこなせた ✓";
"strength.completion.rpe_feedback_medium" = "良いペース ✓";
"strength.completion.rpe_feedback_high" = "しっかりこなした ✓";
"strength.completion.rpe_feedback_max" = "やりきった 💪";
"strength.completion.done_rpe" = "完了 · RPE %d";
"strength.completion.upgrade_title" = "見事です 💪";
"strength.completion.upgrade_detail" = "%@ がレベルアップ L%d→L%d";
"strength.completion.upgrade_next" = "次回のプランが進化します";
"strength.completion.downgrade_title" = "今回はきつめ";
"strength.completion.downgrade_detail" = "%@ を L%d に調整、次回は適切な強度に戻します";
"strength.completion.entry_cta" = "筋トレを記録";
"strength.completion.locked" = "完了 · RPE %d";
"strength.series.generic" = "筋トレ";
"strength.series.plank_series" = "プランク系";
"strength.series.dead_bug_series" = "デッドバグ系";
"strength.series.bird_dog_series" = "バードドッグ系";
"strength.series.side_plank_series" = "サイドプランク系";
"strength.series.bridge_series" = "グルートブリッジ系";
"strength.series.clamshell_series" = "クラムシェル系";
"strength.series.squat_series" = "スクワット系";
```

- [ ] **Step 4: build 確認通過**（字串檔語法正確）

- [ ] **Step 5: Commit**
```bash
git add Havital/Resources/zh-Hant.lproj/Localizable.strings \
  Havital/Resources/en.lproj/Localizable.strings \
  Havital/Resources/ja.lproj/Localizable.strings
git commit -m "i18n(strength): completion + series-name strings (zh/en/ja)

iOS Developer"
```

---

### Task 9: 進入點 — PlannedSessionDetailView 接 CTA + sheet + 已完成鎖定

**Files:**
- Modify: `Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift`

> 在力量活動（primary `.strength` 或 supplementary 力量）下方加 CTA；未完成顯示「完成力量訓練」、已完成顯示鎖定態。`day_date` 由 `date` 格式化、`weeklyPlanId` 由 `planId`。

- [ ] **Step 1: 加 state + 取得力量活動 + day_date helper**

在 `PlannedSessionDetailView` 的 `@State` 區加：
```swift
@State private var strengthCompletionVM: StrengthCompletionViewModel?
@State private var completionRefresh = false   // 觸發已完成態重讀
private let completionStore: StrengthCompletionStore = UserDefaultsStrengthCompletionStore.shared
```
加 computed（取出本日的力量活動：primary 優先，否則 supplementary 第一個）：
```swift
private var strengthActivity: StrengthActivity? {
    if case .strength(let s)? = day.session?.primary { return s }
    return day.effectiveSupplementary.first   // 型別為 StrengthActivity；若實際型別不同，取其 StrengthActivity
}
private var dayDateString: String? {
    guard let date else { return nil }
    let f = DateFormatter()
    f.calendar = Calendar.current
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)   // YYYY-MM-DD，user-local（CLAUDE.md：日期字串為 local）
}
```
> `day.effectiveSupplementary` 元素型別若非 `StrengthActivity`，以實際型別取出其 `StrengthActivity`（grep `effectiveSupplementary` 定義確認）。

- [ ] **Step 2: 加 CTA（在 strength 動作清單 section 之後）**

在顯示 `ExercisesListView(exercises: strength.exercises)` 的那個 `VStack` 之後、`secondaryButtons` 之前，插入：
```swift
if let activity = strengthActivity, let dateStr = dayDateString {
    let _ = completionRefresh  // 讓 toggle 重算
    if completionStore.isCompleted(dayDate: dateStr, strengthType: activity.strengthType) {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundColor(RecapPalette.rpe(3))
            Text(String(format: NSLocalizedString("strength.completion.locked", comment: ""),
                        completionStore.completedRPE(dayDate: dateStr, strengthType: activity.strengthType) ?? 0))
                .font(AppFont.body())
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    } else {
        Button {
            strengthCompletionVM = StrengthCompletionViewModel(
                activity: activity,
                dayDate: dateStr,
                weeklyPlanId: planId,
                repository: DependencyContainer.shared.resolve() as StrengthCompletionRepository,
                store: completionStore
            )
        } label: {
            Text(NSLocalizedString("strength.completion.entry_cta", comment: ""))
                .font(AppFont.body().weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundColor(.white).background(PacerizColor.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: 接 sheet（在既有 `.sheet(isPresented: $showTrainingTypeInfo)` 附近，與其他 sheet 同層）**

```swift
.sheet(item: $strengthCompletionVM) { vm in
    StrengthCompletionSheet(viewModel: vm, onClose: {
        strengthCompletionVM = nil
        completionRefresh.toggle()   // 關閉後重算已完成態
    })
}
```
> `.sheet(item:)` 要求 item 為 `Identifiable`。讓 `StrengthCompletionViewModel` conform `Identifiable`（加 `let id = UUID()`）。回 Task 5 的 ViewModel 補一行 `let id = UUID()` 並 `: ObservableObject, Identifiable`。

- [ ] **Step 4: build 確認通過**

Run build。修正符號名差異（`day.session`/`primaryRunActivity`/`effectiveSupplementary`/`PacerizColor.blue`/`AppFont` 以實際為準）。

- [ ] **Step 5: Commit**
```bash
git add Havital/Features/TrainingPlanV2/Presentation/ViewModels/StrengthCompletionViewModel.swift \
  Havital/Features/TrainingPlanV2/Presentation/Views/PlannedSessionDetailView.swift
git commit -m "feat(strength): completion CTA + sheet entry + completed lock in day detail

iOS Developer"
```

---

### Task 10: Maestro flow + 實機驗證（交付閘）

**Files:**
- Create: `.maestro/flows/strength-completion.yaml`

- [ ] **Step 1: 寫 Maestro flow**

Create `.maestro/flows/strength-completion.yaml`（前置：app 已登入、語言 zh-TW、課表存在且某天有力量訓練；selector 文字以實際畫面為準微調）：
```yaml
appId: com.havital.paceriz
---
- launchApp
- tapOn: "訓練"          # 進週課表 tab（文字以實際為準）
# 進到含力量訓練的某天詳情（依實際課表點對應日）
- tapOn:
    text: "完成力量訓練"
- assertVisible: "完成回報"
- tapOn: "略過"          # 把第一個動作切略過（再點回完成亦可）
- tapOn: "4"             # 選 RPE 4
- tapOn: "完成訓練"
# 反饋態：升級慶祝(若後端已部署且有 series_id) 或 安靜確認
- assertVisible:
    text: "完成"
- tapOn: "完成"
# 回詳情：該天鎖定為已完成
- assertVisible:
    text: "已完成"
```

- [ ] **Step 2: 跑全測試子集確認綠**

Run:
```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:HavitalTests/StrengthCompletionTests \
  -only-testing:HavitalTests/StrengthCompletionViewModelTests
```
Expected: 全綠。

- [ ] **Step 3: 模擬器實機走查（四步 loop：build→install→terminate→launch→screenshot）**

用 simulator 跑：進力量訓練日 → 點「完成力量訓練」→ sheet → 略過一動作 → 選 RPE → 送出 → 看反饋 → 關閉 → 確認該天顯示「已完成」鎖定。截圖存證。
> 升級慶祝路徑需後端已部署 + 該帳號課表含 series_id（見頂部跨專案依賴）。若後端未部署，驗到「安靜確認 + 鎖定」即為本 iOS 範圍的最大可驗；升級慶祝在後端部署後另驗。

- [ ] **Step 4: Maestro flow 跑通**

Run: `maestro test .maestro/flows/strength-completion.yaml`（**不可** `--no-window`）。失敗先分類 app bug / script bug / 環境，再處理。

- [ ] **Step 5: Commit**
```bash
git add .maestro/flows/strength-completion.yaml
git commit -m "test(strength): maestro flow for completion screen + verified in simulator

iOS Developer"
```

---

## Self-Review

**1. Spec coverage（對照 spec 各段）：**
- 粒度 B（逐動作 completed/skipped + RPE，不送 actual_*）→ Task 5 ViewModel + Task 7 sheet + Task 2 test 斷言 `actual_sets` nil ✓
- B1 反饋（現有 API、series 本地名、通用下一步句）→ Task 5 feedback、Task 7 feedbackView、Task 8 series 名 ✓
- 進入點手動 CTA → sheet → Task 9 ✓
- 一次性 + 本地防重送 → Task 4 store + Task 5 markCompleted + Task 9 鎖定 ✓
- series_id 解碼（model 改動）→ Task 1 ✓
- API/Repository/DataSource/Mapper → Task 2/3 ✓
- i18n 三語 + series 名 → Task 8 ✓
- 測試（ViewModel/DTO/Store/Maestro/架構守門）→ Task 1/2/4/5/10 ✓
- 範圍外（不動後端、無 Watch、無 actual/備註/編輯/跨裝置）→ 計畫未納入 ✓

**2. Placeholder scan：** 無 TBD/TODO。少數「以實際符號為準」處（`effectiveSupplementary` 元素型別、`AppFont.title`/`PacerizColor.blue`/`common.close`、Maestro selector 文字、series_id 全集）皆為「以 codebase / YAML 現況校準」的明確指示，非邏輯空白；build/grep 會逼出正確值。

**3. Type consistency：**
- `Exercise.seriesId` / `ExerciseDTO.seriesId`（Task 1）→ Task 5/9 使用一致 ✓
- `StrengthExerciseInput`(exerciseId/seriesId/status)、`StrengthExerciseStatus`(.completed/.skipped)、`StrengthProgressUpdate`(seriesId/previousLevel/newLevel/reason)、`StrengthProgressReason`(.upgrade/.downgrade/.unknown)、`StrengthCompletionResult`(progressUpdates) — Task 2 定義，Task 3/5/7 一致引用 ✓
- `StrengthCompletionRepository.completeStrengthSession(dayDate:strengthType:inputs:overallRpe:durationMinutes:weeklyPlanId:)` — Task 3 定義、Task 5 ViewModel + mock + Task 9 resolve 一致 ✓
- `StrengthCompletionStore`(isCompleted/completedRPE/markCompleted) — Task 4 定義、Task 5/9 一致 ✓
- `StrengthCompletionViewModel`(activity/dayDate/weeklyPlanId/repository/store；phase/selectedRPE/statuses/canSubmit/toggleSkip/status(for:)/submit/exKey；Feedback(rpe,upgrades)) — Task 5 定義、Task 7/9 一致；Task 9 補 `Identifiable`(id) ✓
- `RPESelectorView(selectedRPE: Binding)` — Task 6 定義、Task 7 使用 ✓
- i18n key（`strength.completion.*` / `strength.series.*` / `training.sets_unit`/`seconds_unit`/`reps_unit`/`training.strength_type.*`）— Task 6/7/8/9 一致 ✓
