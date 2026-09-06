//
//  App2HomeV1EntryTests.swift
//  HavitalTests
//
//  V1 帳號在 2.0 首頁的去向（T-0449 / P-002 D4 裁決，2026-09-06；
//  規格 `Docs/specs/SPEC-app-shell-routing-and-global-guardrails.md` AC-SHELL-08）：
//  今日課那格換成「用 2.0 重新設定目標」，而**其他失敗照舊說「暫時讀不到」**。
//
//  這裡鎖的是那條分界。走錯任何一邊都是用戶看得到的傷害：
//  - 該進新狀態卻落到 `.unavailable` → V1 用戶回到 T-0448 那個空白首頁（測試者按了 14 次沒反應）。
//  - 不該進卻進了 → V2 用戶網路一斷就被叫去重新設定一次目標。
//
//  既有測試沒有涵蓋這條：`App2HomeProjectionTests` 只測 payload → 欄位的投影，
//  `Core/ReonboardingVersionCheckTests` 測的是 `getTrainingVersion()` 的 cache 行為
//  （本票沒動那條路，只在它旁邊補了不退成 "v1" 的 `trainingVersionIfKnown()`）。
//

import XCTest
@testable import paceriz_dev

@MainActor
final class App2HomeV1EntryTests: XCTestCase {

    // MARK: - Helpers

    /// 後端 `/v2/plan/status` 的 404 body：`core/middleware/response_utils.py` 的
    /// `error_response()` 固定產 `{"success": false, "error": "<code>"}`。
    /// 這個 body 一路原樣進到 `DomainError.notFound`（`HTTPClient` → `toDomainError()`）。
    private func notFound(_ code: String) -> DomainError {
        .notFound("{\"success\": false, \"error\": \"\(code)\"}")
    }

    private func label(_ outcome: App2HomeViewModel.PlanStatusOutcome) -> String {
        switch outcome {
        case .loaded: return "loaded"
        case .failed: return "failed"
        case .needsV2Setup: return "needsV2Setup"
        case .cancelled: return "cancelled"
        }
    }

    // MARK: - 404 的 error code 分辨（讀 body 欄位，不比對訊息文字）

    func test_planStatusFailure_trainingPlanNotFound_isNeedsV2Setup() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: notFound("training_plan_not_found"), knownTrainingVersion: nil
        )
        XCTAssertEqual(label(outcome), "needsV2Setup")
    }

    func test_planStatusFailure_noActiveTrainingPlan_isNeedsV2Setup() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: notFound("no_active_training_plan"), knownTrainingVersion: nil
        )
        XCTAssertEqual(label(outcome), "needsV2Setup")
    }

    /// 同樣是 404 但不是這兩個 code —— `user_not_found` 是帳號本身的問題，
    /// 叫他重新設定目標不會好。
    func test_planStatusFailure_otherNotFoundCode_staysFailed() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: notFound("user_not_found"), knownTrainingVersion: nil
        )
        XCTAssertEqual(label(outcome), "failed")
    }

    /// 404 但 body 不是那個形狀（proxy 的 HTML 錯誤頁、空 body、FastAPI 的 detail）
    /// → 沒有 code 可讀，不得猜成 V1。
    func test_planStatusFailure_notFoundWithoutErrorField_staysFailed() {
        for body in ["", "Not Found", "<html>404</html>", "{\"detail\": \"nope\"}"] {
            let outcome = App2HomeViewModel.planStatusFailureOutcome(
                error: DomainError.notFound(body), knownTrainingVersion: nil
            )
            XCTAssertEqual(label(outcome), "failed", "body=\(body)")
        }
    }

    func test_planStatusFailure_serverError_staysFailed() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: DomainError.serverError(500, "boom"), knownTrainingVersion: nil
        )
        XCTAssertEqual(label(outcome), "failed")
    }

    func test_planStatusFailure_cancellation_staysCancelled() {
        XCTAssertEqual(
            label(App2HomeViewModel.planStatusFailureOutcome(
                error: URLError(.cancelled), knownTrainingVersion: nil
            )),
            "cancelled"
        )
        XCTAssertEqual(
            label(App2HomeViewModel.planStatusFailureOutcome(
                error: DomainError.cancellation, knownTrainingVersion: "v1"
            )),
            "cancelled",
            "取消優先於版本判斷——被收掉的那一輪不得改畫面"
        )
    }

    // MARK: - 第二個觸發源：profile 明說的版本

    /// 500 加上 profile 明說 v1 → 一樣進新狀態（兩個觸發源任一成立）。
    func test_planStatusFailure_profileSaysV1_isNeedsV2Setup() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: DomainError.serverError(500, "boom"), knownTrainingVersion: "v1"
        )
        XCTAssertEqual(label(outcome), "needsV2Setup")
    }

    /// **讀不到 profile 不算。** `TrainingVersionRouter.getTrainingVersion()` 讀不到會回 "v1"，
    /// 拿它當觸發源會把 V2 用戶的網路失敗說成要重設目標——所以這裡吃的是
    /// `trainingVersionIfKnown()` 的 nil。
    func test_planStatusFailure_versionUnknown_staysFailed() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: DomainError.networkFailure("offline"), knownTrainingVersion: nil
        )
        XCTAssertEqual(label(outcome), "failed")
    }

    func test_planStatusFailure_profileSaysV2_staysFailed() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: DomainError.serverError(503, "boom"), knownTrainingVersion: "v2"
        )
        XCTAssertEqual(label(outcome), "failed")
    }

    /// **profile 明說 v2 要壓過那兩個 404 code。** 後端的 `load_overview` 走 `strict=False`
    /// （`domains/plan_overview/repository.py` 的 `get_overview`），Firestore 讀取例外被吞成
    /// `None`，於是「讀取失敗」與「真的沒有 V2 計畫」回同一個 404 body。已經知道是 v2 的
    /// 帳號還進重設入口，就是把一次讀取失敗說成「你的計畫沒了」，而且
    /// `.needsV2Setup` 是無條件寫入，會蓋掉畫面上真的課表。
    func test_planStatusFailure_v1CodeButProfileSaysV2_staysFailed() {
        for code in ["training_plan_not_found", "no_active_training_plan"] {
            let outcome = App2HomeViewModel.planStatusFailureOutcome(
                error: notFound(code), knownTrainingVersion: "v2"
            )
            XCTAssertEqual(label(outcome), "failed", "code=\(code)")
        }
    }

    /// profile 讀不到時**仍然**認那兩個 code —— 那是使用者裁決的第一個觸發源，
    /// 收掉它等於 V1 用戶只要 profile 讀失敗就回到空白首頁。
    /// 誤判的代價由「不黏住」那條規則承擔（見 `test_homeVM_needsV2Setup_isClearedByALaterFailedRound`）。
    func test_planStatusFailure_v1CodeWithUnknownVersion_isNeedsV2Setup() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: notFound("training_plan_not_found"), knownTrainingVersion: nil
        )
        XCTAssertEqual(label(outcome), "needsV2Setup")
    }

    /// profile 明說非 v2 時，不是那兩個 code 的失敗也給重設入口（版本本身就足夠）。
    func test_planStatusFailure_profileSaysV1_withUnrelatedNotFound_isNeedsV2Setup() {
        let outcome = App2HomeViewModel.planStatusFailureOutcome(
            error: notFound("user_not_found"), knownTrainingVersion: "v1"
        )
        XCTAssertEqual(label(outcome), "needsV2Setup")
    }

    // MARK: - error code 的取法

    func test_notFoundErrorCode_readsBodyField_notMessageText() {
        XCTAssertEqual(
            App2HomeViewModel.notFoundErrorCode(
                from: HTTPError.notFound("{\"success\": false, \"error\": \"training_plan_not_found\"}")
            ),
            "training_plan_not_found"
        )
        XCTAssertNil(
            App2HomeViewModel.notFoundErrorCode(from: DomainError.serverError(500, "training_plan_not_found")),
            "500 的訊息裡有那個字不代表 404"
        )
        XCTAssertNil(App2HomeViewModel.notFoundErrorCode(from: DomainError.badRequest("{\"error\": \"x\"}")))
    }

    // MARK: - 型別上分得開

    func test_needsV2Setup_isNotUnavailableNorNotGenerated() {
        XCTAssertNotEqual(App2TodaySessionState.needsV2Setup, .unavailable)
        XCTAssertNotEqual(App2TodaySessionState.needsV2Setup, .notGenerated)
        XCTAssertNotEqual(App2TodaySessionState.needsV2Setup, .noSessionToday)
    }

    // MARK: - 佈線：view model 真的把它接到 todayState 上

    /// 版本可以在測試中途換掉（模擬 profile 一輪讀不到、下一輪讀得到）。
    private final class MutableStubVersionRouter: TrainingVersionRouting, @unchecked Sendable {
        var version: String?
        init(version: String?) { self.version = version }
        func getTrainingVersion() async -> String { version ?? "v1" }
        func trainingVersionIfKnown() async -> String? { version }
        func isV2User() async -> Bool { version == "v2" }
        func isV1User() async -> Bool { version != "v2" }
    }

    private final class StubVersionRouter: TrainingVersionRouting {
        let version: String?
        init(version: String?) { self.version = version }
        func getTrainingVersion() async -> String { version ?? "v1" }
        func trainingVersionIfKnown() async -> String? { version }
        func isV2User() async -> Bool { version == "v2" }
        func isV1User() async -> Bool { version != "v2" }
    }

    /// V1 帳號打 decision-chain／athlete-state 端點會拿 403 `training_version_unsupported`
    /// ——首頁照既有降級（樣本敘事帶 `App2StubBadge`），不彈錯誤。
    private final class ForbiddenDailyStateRepository: DailyStateRepository {
        func fetchTodayState() async throws -> DailyStateCard { throw DomainError.forbidden }
        func cachedTodayState() -> DailyStateCard? { nil }
        func applyBenchmark(_ calibration: SameDayBenchmarkCalibration) async throws -> Int? { nil }
        func scheduleNextBenchmark(
            _ calibration: SameDayBenchmarkCalibration, weeksAhead: Int
        ) async throws -> Int? { nil }
    }

    private final class EmptyStatsSource: WorkoutStatsDataSourceProtocol {
        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            let json = """
            { "data": { "total_workouts": 0, "total_distance_km": 0.0,
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30 } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }
        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }
        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }
    }

    private final class NoSnapshots: App2SnapshotStoring {
        func load<Value: Decodable>(_ type: Value.Type, for key: App2SnapshotKey) -> App2Snapshot<Value>? { nil }
        func save<Value: Encodable>(_ value: Value, for key: App2SnapshotKey) {}
        func invalidate(_ keys: Set<App2SnapshotKey>) {}
        func clearAll() {}
    }

    private func makeViewModel(planError: Error, version: String?) -> App2HomeViewModel {
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.errorToThrow = planError
        planRepo.simulatesEmptyLocalCache = true
        return App2HomeViewModel(
            dailyStateRepository: ForbiddenDailyStateRepository(),
            targetRepository: MockTargetRepository(),
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: EmptyStatsSource(),
            snapshots: NoSnapshots(),
            versionRouter: StubVersionRouter(version: version),
            garminStatusProvider: { throw DomainError.forbidden }
        )
    }

    /// V1 帳號的真實組合：`/v2/plan/status` 404 `training_plan_not_found`。
    func test_homeVM_v1Account404_showsReonboardingState() async {
        let vm = makeViewModel(planError: notFound("training_plan_not_found"), version: nil)

        await vm.revalidate()

        XCTAssertEqual(vm.todayState, .needsV2Setup)
    }

    /// V2 帳號的真網路失敗：仍然是「暫時讀不到」，不得被誤導成要重設目標。
    func test_homeVM_v2AccountServerError_staysUnavailable() async {
        let vm = makeViewModel(planError: DomainError.serverError(500, "boom"), version: "v2")

        await vm.revalidate()

        XCTAssertEqual(vm.todayState, .unavailable)
    }

    /// V2 帳號碰到那個 404（後端讀取失敗被吞成「沒有 overview」）：畫面照舊說讀不到，
    /// **不得**把它的課表卡換成重設入口。
    func test_homeVM_v2AccountGets404_staysUnavailable() async {
        let vm = makeViewModel(planError: notFound("training_plan_not_found"), version: "v2")

        await vm.revalidate()

        XCTAssertEqual(vm.todayState, .unavailable)
    }

    /// 誤判的重設入口不得黏住整個 session：下一輪判不出 V1（版本讀不到、失敗也不是那兩個
    /// code）時，卡片要退回「暫時讀不到」，不能繼續叫使用者重設目標。
    func test_homeVM_needsV2Setup_isClearedByALaterFailedRound() async {
        let planRepo = MockTrainingPlanV2Repository()
        planRepo.errorToThrow = notFound("training_plan_not_found")
        planRepo.simulatesEmptyLocalCache = true
        let router = MutableStubVersionRouter(version: nil)
        let vm = App2HomeViewModel(
            dailyStateRepository: ForbiddenDailyStateRepository(),
            targetRepository: MockTargetRepository(),
            planRepository: planRepo,
            readinessViewModel: nil,
            readinessService: nil,
            workoutDataSource: EmptyStatsSource(),
            snapshots: NoSnapshots(),
            versionRouter: router,
            garminStatusProvider: { throw DomainError.forbidden }
        )

        await vm.revalidate()
        XCTAssertEqual(vm.todayState, .needsV2Setup, "第一輪只有 404 code，仍給入口")

        // 下一輪：後端不再回那個 code，版本還是讀不到 → 判不出 V1。
        planRepo.errorToThrow = DomainError.serverError(500, "boom")
        await vm.revalidate()

        XCTAssertEqual(vm.todayState, .unavailable, "判不出 V1 的那一輪不得繼續掛著重設入口")
    }

    /// profile 明說 v1（連 plan status 都掛了）→ 一樣給重新設定入口。
    func test_homeVM_profileSaysV1_showsReonboardingState() async {
        let vm = makeViewModel(planError: DomainError.serverError(500, "boom"), version: "v1")

        await vm.revalidate()

        XCTAssertEqual(vm.todayState, .needsV2Setup)
    }
}
