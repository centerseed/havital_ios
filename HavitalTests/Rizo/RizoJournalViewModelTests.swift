import Combine
import XCTest
@testable import paceriz_dev

/// RizoJournalViewModel 單元測試（S02 AC stub）。
///
/// 驗證「資料捕捉 / 回應兩步解耦」（AC-TJF-11 / 16 硬要求）與配額轉換提示。
///
/// Mock 邊界：MockRizoRepo / MockWorkoutRepoForJournal 為純測試替身
/// （無外部付費服務 / LLM；Rizo 後端在 dev 尚未部署，本批不連真後端）。
@MainActor
final class RizoJournalViewModelTests: XCTestCase {

    private var rizoRepo: MockRizoRepo!
    private var workoutRepo: MockWorkoutRepoForJournal!
    private var sut: RizoJournalViewModel!

    override func setUp() {
        super.setUp()
        rizoRepo = MockRizoRepo()
        workoutRepo = MockWorkoutRepoForJournal()
        sut = RizoJournalViewModel(
            workoutId: "wk-1",
            rizoRepository: rizoRepo,
            workoutRepository: workoutRepo
        )
    }

    override func tearDown() {
        sut = nil
        rizoRepo = nil
        workoutRepo = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func reply(
        text: String = "聽起來不錯，繼續保持！",
        allowed: Bool = true,
        canned: Bool = false,
        danger: String = "none"
    ) -> RizoReply {
        RizoReply(
            reply: text,
            sessionId: "sess-1",
            quota: RizoQuota(allowed: allowed, used: 1, limit: 3, remaining: allowed ? 2 : 0, resetsAt: nil, reserved: true),
            safety: RizoSafety(dangerClass: danger, canned: canned)
        )
    }

    /// 等 submit 內的 async Task 完成（兩個 await 邊界後 state 應已 settle）。
    private func waitForSubmit() async {
        // 讓 VM 內的 detached Task 跑完：多次 yield 直到 isSubmitting 落回 false。
        for _ in 0..<200 {
            if !sut.isSubmitting && (workoutRepo.updateCallCount > 0 || sut.captureError != nil) {
                // 再 yield 一輪確保 reply / quotaState 已套用
                await Task.yield()
                if !sut.isSubmitting { return }
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    // MARK: - AC-TJF-02：PATCH 成功 → isRecorded == true

    func testSubmitSuccess_setsRecorded() async {
        rizoRepo.replyToReturn = reply()
        sut.selectedPresetIDs = ["p1"]

        sut.submit(note: "今天很順")
        await waitForSubmit()

        XCTAssertTrue(sut.isRecorded, "資料捕捉成功應切已記錄")
        XCTAssertEqual(workoutRepo.updateCallCount, 1)
        XCTAssertEqual(workoutRepo.lastPresets, ["p1"])
        XCTAssertEqual(workoutRepo.lastNote, "今天很順")
        XCTAssertNotNil(sut.reply, "成功應顯示 Rizo 回應")
        XCTAssertNil(sut.captureError)
    }

    // MARK: - AC-TJF-11 / 16：chat 失敗 → isRecorded 仍 true（解耦）

    func testChatFailure_stillRecorded() async {
        workoutRepo.shouldThrow = false           // 資料捕捉成功
        rizoRepo.errorToThrow = TestError.boom     // 回應失敗
        sut.selectedPresetIDs = ["p1"]

        sut.submit(note: "")
        await waitForSubmit()

        XCTAssertTrue(sut.isRecorded, "回應失敗，資料捕捉仍成功 → 永遠已記錄")
        XCTAssertNil(sut.reply, "回應失敗不顯示 reply")
        XCTAssertNil(sut.captureError, "回應失敗不是捕捉錯誤")
        XCTAssertEqual(sut.quotaState, .none)
    }

    // MARK: - AC-TJF-05：送出失敗（資料捕捉失敗）→ isRecorded 仍 false，勾選不丟

    func testCaptureFailure_keepsSelectionAndShowsRetry() async {
        workoutRepo.shouldThrow = true             // 資料捕捉失敗
        sut.selectedPresetIDs = ["p1", "p2"]

        sut.submit(note: "保留我")
        await waitForSubmit()

        XCTAssertFalse(sut.isRecorded, "捕捉失敗不可切已記錄")
        XCTAssertNotNil(sut.captureError, "應顯示可重試錯誤")
        XCTAssertEqual(sut.selectedPresetIDs, ["p1", "p2"], "勾選不可丟")
        XCTAssertNil(sut.reply, "捕捉失敗不應呼叫 Rizo")
        XCTAssertEqual(rizoRepo.sendCallCount, 0, "STEP1 失敗不可進 STEP2")
    }

    // MARK: - AC-TJF-09b：quota.allowed=false 但有內容 → suggestionWithUpsell

    func testQuotaNotAllowedWithContent_showsSuggestionUpsell() async {
        rizoRepo.replyToReturn = reply(text: "建議你先恢復兩天。", allowed: false)
        sut.selectedPresetIDs = ["p1"]

        sut.submit(note: "")
        await waitForSubmit()

        XCTAssertTrue(sut.isRecorded)
        XCTAssertEqual(sut.quotaState, .suggestionWithUpsell)
        XCTAssertEqual(sut.reply?.reply, "建議你先恢復兩天。")
    }

    // MARK: - AC-TJF-17b：quota 滿、無新回應 → quotaExhausted

    func testQuotaExhaustedEmptyReply_showsQuotaUpsell() async {
        rizoRepo.replyToReturn = reply(text: "   ", allowed: false)
        sut.selectedPresetIDs = ["p1"]

        sut.submit(note: "")
        await waitForSubmit()

        XCTAssertTrue(sut.isRecorded)
        XCTAssertEqual(sut.quotaState, .quotaExhausted)
    }

    // MARK: - AC-TJF-17c：safety.canned=true → safetyCanned（罐頭安全訊息）

    func testSafetyCanned_showsCannedState() async {
        rizoRepo.replyToReturn = reply(
            text: "如果疼痛持續，請就醫。",
            allowed: false,
            canned: true,
            danger: "medical"
        )
        sut.selectedPresetIDs = ["danger1"]

        sut.submit(note: "")
        await waitForSubmit()

        XCTAssertTrue(sut.isRecorded)
        XCTAssertEqual(sut.quotaState, .safetyCanned)
        XCTAssertEqual(sut.reply?.reply, "如果疼痛持續，請就醫。")
    }

    // MARK: - AC-TJF-08：session 續傳

    func testSessionIdThreadedOnSecondTurn() async {
        rizoRepo.replyToReturn = reply()
        sut.selectedPresetIDs = ["p1"]
        sut.submit(note: "")
        await waitForSubmit()
        XCTAssertNil(rizoRepo.lastSessionId, "首回合 sessionId 為 nil")

        // 第二輪應帶上前一回合回的 sessionId。
        rizoRepo.replyToReturn = reply()
        sut.submit(note: "再聊一句")
        await waitForSubmit()
        XCTAssertEqual(rizoRepo.lastSessionId, "sess-1", "續談應沿用 sessionId")
    }

    // MARK: - AC-TJF-01：載入 4 類預設

    func testLoadPresets() async {
        rizoRepo.presetsToReturn = [
            RizoPreset(id: "a", category: "overall_status", dangerClass: "none", label: "整體不錯"),
            RizoPreset(id: "b", category: "body_discomfort", dangerClass: "medical", label: "膝蓋痛")
        ]
        sut.loadPresets()
        for _ in 0..<100 where sut.presets.isEmpty {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTAssertEqual(sut.presets.count, 2)
    }
}

// MARK: - Test Doubles

private enum TestError: Error { case boom }

private final class MockRizoRepo: RizoRepository {
    var replyToReturn: RizoReply?
    var presetsToReturn: [RizoPreset] = []
    var errorToThrow: Error?

    var sendCallCount = 0
    var lastSessionId: String?
    var lastPresetSelections: [String] = []

    func sendJournalChat(
        workoutId: String,
        message: String,
        presetSelections: [String],
        sessionId: String?
    ) async throws -> RizoReply {
        sendCallCount += 1
        lastSessionId = sessionId
        lastPresetSelections = presetSelections
        if let errorToThrow { throw errorToThrow }
        guard let replyToReturn else { throw TestError.boom }
        return replyToReturn
    }

    func getPresets(scenario: String) async throws -> [RizoPreset] {
        if let errorToThrow { throw errorToThrow }
        return presetsToReturn
    }

    func getHistory() async throws -> [RizoHistoryItem] { [] }
}

private final class MockWorkoutRepoForJournal: WorkoutRepository {
    var shouldThrow = false
    var updateCallCount = 0
    var lastPresets: [String] = []
    var lastNote: String?

    func updateSubjectiveInputs(id: String, presets: [String], note: String?) async throws {
        updateCallCount += 1
        lastPresets = presets
        lastNote = note
        if shouldThrow { throw TestError.boom }
    }

    // MARK: Unused protocol surface (本測試只用 updateSubjectiveInputs)
    var workoutsDidRefresh: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
    var workoutsPaginationDidUpdate: AnyPublisher<PaginationInfo, Never> { Empty().eraseToAnyPublisher() }
    var workoutsDidUpdateNotification: Notification.Name { .workoutsDidUpdate }
    func getCachedPagination() -> PaginationInfo? { nil }
    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] { [] }
    func getAllWorkouts() -> [WorkoutV2] { [] }
    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] { [] }
    func getAllWorkoutsAsync() async -> [WorkoutV2] { [] }
    func getLatestWorkout() async throws -> WorkoutV2? { nil }
    func ensureMonthLoaded(year: Int, month: Int) async {}
    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] { [] }
    func refreshWorkouts() async throws -> [WorkoutV2] { [] }
    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse {
        WorkoutListResponse(workouts: [], pagination: PaginationInfo(nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize))
    }
    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse {
        WorkoutListResponse(workouts: [], pagination: PaginationInfo(nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize))
    }
    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse {
        WorkoutListResponse(workouts: [], pagination: PaginationInfo(nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false, oldestId: nil, newestId: nil, totalItems: 0, pageSize: pageSize))
    }
    func getWorkout(id: String) async throws -> WorkoutV2 { throw TestError.boom }
    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail { throw TestError.boom }
    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail { throw TestError.boom }
    func clearWorkoutDetailCache(id: String) async {}
    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 { workout }
    func updateTrainingNotes(id: String, notes: String) async throws {}
    func deleteWorkout(id: String) async throws {}
    func invalidateRefreshCooldown() {}
    func clearCache() async {}
    func preloadData() async {}
}
