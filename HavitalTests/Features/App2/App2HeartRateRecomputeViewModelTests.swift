import XCTest
@testable import paceriz_dev

/// AC-HR-07~13：改心率後的重算提示、進度、重試、自動更新開關、手錶偏差提醒。
@MainActor
final class App2HeartRateRecomputeViewModelTests: XCTestCase {

    private final class FakeRepo: HeartRateRecomputeRepository {
        var startOutcome: Result<HeartRateRecomputeOutcome, Error> = .success(.nothingToRecompute(message: "none"))
        var statuses: [HeartRateRecomputeStatus] = []
        var reminder: HeartRateWatchReminder?
        var autoUpdate: HeartRateWatchAutoUpdate?
        private(set) var dismissCalls = 0
        var dismissError: Error?
        var reminderError: Error?
        private(set) var startedDays: [HeartRateRecomputeDays] = []
        private(set) var statusCalls = 0
        var statusError: Error?

        func startRecompute(days: HeartRateRecomputeDays) async throws -> HeartRateRecomputeOutcome {
            startedDays.append(days)
            return try startOutcome.get()
        }

        func latestStatus() async throws -> HeartRateRecomputeStatus {
            statusCalls += 1
            if let statusError { throw statusError }
            if statuses.isEmpty { return HeartRateRecomputeStatus(job: nil, message: nil) }
            return statuses.count > 1 ? statuses.removeFirst() : statuses[0]
        }

        func watchCheck() async throws -> HeartRateWatchCheck {
            if let reminderError { throw reminderError }
            return HeartRateWatchCheck(reminder: reminder, autoUpdate: autoUpdate)
        }

        func dismissWatchReminder() async throws {
            dismissCalls += 1
            if let dismissError { throw dismissError }
        }
    }

    private func job(_ status: HeartRateRecomputeJob.Status, done: Int = 0, total: Int = 10, recomputed: Int = 0, skipped: Int = 0, failed: Int = 0) -> HeartRateRecomputeJob {
        HeartRateRecomputeJob(jobId: "j1", status: status, days: 14, total: total, done: done, recomputed: recomputed, skipped: skipped, failed: failed, failedWorkoutIds: [], error: nil)
    }

    private func makeVM(
        _ repo: FakeRepo,
        autoUpdate: Bool = false,
        updater: @escaping ([String: Any]) async -> Bool = { _ in true },
        updateWatchMaxHR: ((Int) async -> Bool?)? = nil,
        completed: @escaping () -> Void = {}
    ) -> App2HeartRateRecomputeViewModel {
        App2HeartRateRecomputeViewModel(
            repository: repo,
            autoUpdateMaxHR: autoUpdate,
            updateProfile: updater,
            updateWatchMaxHR: updateWatchMaxHR,
            onFinished: completed,
            pollSleep: { }
        )
    }

    // MARK: - 什麼時候問

    func test_promptOnlyWhenBackendSaysChanged() {
        let vm = makeVM(FakeRepo())
        vm.offerAfterSave(changed: false)
        XCTAssertFalse(vm.isPromptPresented)
        vm.offerAfterSave(changed: true)
        XCTAssertTrue(vm.isPromptPresented)
    }

    func test_unchangedBackendSaveDoesNotPresentPrompt() {
        let vm = makeVM(FakeRepo())
        XCTAssertFalse(vm.applyBackendSaveResult(false))
        XCTAssertFalse(vm.isPromptPresented)
    }

    func test_choosingNoRecomputeStartsNothing() async {
        let repo = FakeRepo()
        let vm = makeVM(repo)
        vm.offerAfterSave(changed: true)
        await vm.choose(nil)
        XCTAssertFalse(vm.isPromptPresented)
        XCTAssertTrue(repo.startedDays.isEmpty)
    }

    func test_promptListsTheThreeRangesThenAVisibleSkipChoice() {
        XCTAssertEqual(
            App2HeartRateRecomputeViewModel.promptChoices,
            [.days(.fourteen), .days(.thirty), .days(.sixty), .skip]
        )
    }

    func test_choosingTheSkipChoiceSavesOnlyAndStartsNothing() async {
        let repo = FakeRepo()
        let vm = makeVM(repo)
        vm.offerAfterSave(changed: true)
        await vm.choose(.skip)
        XCTAssertFalse(vm.isPromptPresented)
        XCTAssertTrue(repo.startedDays.isEmpty)
        XCTAssertEqual(vm.phase, .idle)
    }

    func test_choosingARangeChoiceStartsThatRange() async {
        let repo = FakeRepo()
        let vm = makeVM(repo)
        vm.offerAfterSave(changed: true)
        await vm.choose(.days(.thirty))
        XCTAssertEqual(repo.startedDays, [.thirty])
    }

    // MARK: - 進度與結果

    func test_queuedJobIsPolledToCompletionAndDownstreamCachesAreToldOnce() async {
        let repo = FakeRepo()
        repo.startOutcome = .success(.queued(job: job(.queued), message: "queued"))
        repo.statuses = [
            HeartRateRecomputeStatus(job: job(.running, done: 4), message: "4/10"),
            HeartRateRecomputeStatus(job: job(.completed, done: 10, recomputed: 7, skipped: 3), message: "done 7/3/0")
        ]
        var finished = 0
        let vm = makeVM(repo, completed: { finished += 1 })
        await vm.choose(.fourteen)
        XCTAssertEqual(repo.startedDays, [.fourteen])
        guard case .job(let finalJob, let message) = vm.phase else { return XCTFail("phase \(vm.phase)") }
        XCTAssertEqual(finalJob.status, .completed)
        XCTAssertEqual(finalJob.recomputed, 7)
        XCTAssertEqual(message, "done 7/3/0")
        XCTAssertEqual(finished, 1)
        XCTAssertFalse(vm.isActive)
    }

    func test_failedJobIsShownAsFailedAndCanBeRetried() async {
        let repo = FakeRepo()
        repo.startOutcome = .success(.queued(job: job(.queued), message: nil))
        repo.statuses = [HeartRateRecomputeStatus(job: job(.failed, done: 2), message: "failed")]
        var finished = 0
        let vm = makeVM(repo, completed: { finished += 1 })
        await vm.choose(.thirty)
        guard case .job(let failedJob, _) = vm.phase else { return XCTFail() }
        XCTAssertEqual(failedJob.status, .failed)
        XCTAssertTrue(vm.canStart)
        XCTAssertEqual(finished, 0, "失敗不當成功：不通知下游刷新")
        repo.statuses = [HeartRateRecomputeStatus(job: job(.completed, done: 10, recomputed: 10), message: "ok")]
        await vm.choose(.thirty)
        XCTAssertEqual(repo.startedDays, [.thirty, .thirty])
        XCTAssertEqual(finished, 1)
    }

    func test_nothingToRecomputeShowsTheBackendMessageAndDoesNotPoll() async {
        let repo = FakeRepo()
        repo.startOutcome = .success(.nothingToRecompute(message: "這段時間沒有可重算的課"))
        let vm = makeVM(repo)
        await vm.choose(.fourteen)
        XCTAssertEqual(vm.phase, .notice("這段時間沒有可重算的課"))
        XCTAssertEqual(repo.statusCalls, 0)
    }

    func test_alreadyRunningAdoptsTheRunningJobInsteadOfOpeningASecond() async {
        let repo = FakeRepo()
        repo.startOutcome = .success(.alreadyRunning(job: job(.running, done: 2), message: "busy"))
        repo.statuses = [HeartRateRecomputeStatus(job: job(.completed, done: 10, recomputed: 10), message: "ok")]
        let vm = makeVM(repo)
        await vm.choose(.sixty)
        guard case .job(let j, _) = vm.phase else { return XCTFail() }
        XCTAssertEqual(j.status, .completed)
        XCTAssertEqual(repo.startedDays.count, 1)
    }

    func test_startFailureIsReportedNotFaked() async {
        let repo = FakeRepo()
        repo.startOutcome = .failure(HTTPError.serverError(503, "down"))
        let vm = makeVM(repo)
        await vm.choose(.fourteen)
        guard case .failed = vm.phase else { return XCTFail("phase \(vm.phase)") }
        XCTAssertTrue(vm.canStart)
    }

    func test_homeReminderUpdateUsesBackendChangedAndOffersRecompute() async {
        let repo = FakeRepo()
        var sentMaxHR: Int?
        let vm = makeVM(repo, updateWatchMaxHR: { maxHR in
            sentMaxHR = maxHR
            return true
        })

        await vm.applyWatchMaxHR(180)

        XCTAssertEqual(sentMaxHR, 180)
        XCTAssertTrue(vm.isPromptPresented)
    }

    func test_homeReminderUpdateUsesTheProfilePUTAndBackendChanged() async {
        let profileRepository = MockUserProfileRepository()
        profileRepository.heartRateChangedToReturn = true

        let changed = await App2HeartRateRecomputeViewModel.updateWatchMaxHR(
            using: profileRepository,
            maxHR: 180
        )

        XCTAssertEqual(profileRepository.getUserProfileCallCount, 1)
        XCTAssertEqual(profileRepository.updateHeartRateZonesCallCount, 1)
        XCTAssertTrue(changed == true)
    }

    func test_homeReminderUpdateWithUnchangedBackendDoesNotPresentPrompt() async {
        let vm = makeVM(FakeRepo(), updateWatchMaxHR: { _ in false })

        await vm.applyWatchMaxHR(180)

        XCTAssertFalse(vm.isPromptPresented)
        XCTAssertNil(vm.errorMessage)
    }

    func test_homeReminderUpdateFailureLeavesAnObservableError() async {
        var attempts = 0
        let vm = makeVM(FakeRepo(), updateWatchMaxHR: { _ in
            attempts += 1
            return attempts == 1 ? nil : true
        })

        await vm.applyWatchMaxHR(180)

        XCTAssertFalse(vm.isPromptPresented)
        XCTAssertEqual(vm.errorMessage, NSLocalizedString("error.unknown", comment: ""))
        await vm.retryLastError()
        XCTAssertEqual(attempts, 2)
        XCTAssertTrue(vm.isPromptPresented)
        XCTAssertNil(vm.errorMessage)
    }

    func test_backendSaveResultChangedOffersPromptForProfileSavePath() {
        let vm = makeVM(FakeRepo())

        XCTAssertTrue(vm.applyBackendSaveResult(true))
        XCTAssertTrue(vm.isPromptPresented)
    }

    func test_pollFailureStopsPollingAndIsReported() async {
        let repo = FakeRepo()
        repo.startOutcome = .success(.queued(job: job(.queued), message: "queued"))
        repo.statusError = HTTPError.timeout
        let vm = makeVM(repo)

        await vm.choose(.fourteen)

        guard case .failed = vm.phase else { return XCTFail("phase \(vm.phase)") }
        XCTAssertTrue(vm.canStart)
        XCTAssertEqual(repo.statusCalls, 1)
    }

    func test_noHeartRateParametersIsANotice() async {
        let repo = FakeRepo()
        repo.startOutcome = .success(.noHeartRateParameters(message: "set hr"))
        let vm = makeVM(repo)
        await vm.choose(.fourteen)
        XCTAssertEqual(vm.phase, .notice("set hr"))
    }

    // MARK: - 進頁時接上進行中的工作

    func test_refreshAdoptsAnActiveJobButIgnoresOldFinishedOnes() async {
        let repo = FakeRepo()
        repo.statuses = [HeartRateRecomputeStatus(job: job(.completed, done: 10, recomputed: 10), message: "old")]
        let vm = makeVM(repo)
        await vm.refresh()
        XCTAssertEqual(vm.phase, .idle)

        repo.statuses = [
            HeartRateRecomputeStatus(job: job(.running, done: 3), message: "3/10"),
            HeartRateRecomputeStatus(job: job(.completed, done: 10, recomputed: 10), message: "ok")
        ]
        await vm.refresh()
        guard case .job(let j, _) = vm.phase else { return XCTFail() }
        XCTAssertEqual(j.status, .completed)
    }

    func test_cannotStartWhileAJobIsActive() async {
        let repo = FakeRepo()
        repo.statuses = [HeartRateRecomputeStatus(job: job(.running, done: 3), message: "3/10")]
        let vm = makeVM(repo)
        vm.adopt(job: job(.running, done: 3), message: nil)
        XCTAssertFalse(vm.canStart)
        await vm.choose(.thirty)
        XCTAssertTrue(repo.startedDays.isEmpty)
    }

    // MARK: - 手錶偏差提醒

    func test_reminderIsLoadedWhenBackendHasOne() async {
        let repo = FakeRepo()
        repo.reminder = HeartRateWatchReminder(watchMaxHr: 180, profileMaxHr: 197, deviationPct: 8.6, since: "2026-09-01", latestWorkoutDay: "2026-09-17", watchRestingHr: 50)
        let vm = makeVM(repo)
        await vm.loadWatchCheck()
        XCTAssertEqual(vm.reminder?.watchMaxHr, 180)
    }

    func test_reminderFailureShowsNothing() async {
        let repo = FakeRepo()
        repo.reminderError = HTTPError.timeout
        let vm = makeVM(repo)
        await vm.loadWatchCheck()
        XCTAssertNil(vm.reminder)
    }

    func test_autoUpdateNoteIsLoadedAndKeptApartFromTheReminder() async {
        let repo = FakeRepo()
        repo.autoUpdate = HeartRateWatchAutoUpdate(localDate: "2026-09-20", maxHr: 193, previousMaxHr: 197, deviationSince: "2026-09-01")
        let vm = makeVM(repo)
        await vm.loadWatchCheck()
        XCTAssertEqual(vm.autoUpdate?.maxHr, 193)
        XCTAssertNil(vm.reminder)
    }

    func test_dismissHidesTheReminderAtOnceAndTellsTheBackend() async {
        let repo = FakeRepo()
        repo.reminder = HeartRateWatchReminder(watchMaxHr: 180, profileMaxHr: 197, deviationPct: 8.6, since: "2026-09-01", latestWorkoutDay: "2026-09-17", watchRestingHr: 50)
        let vm = makeVM(repo)
        await vm.loadWatchCheck()
        await vm.dismissReminder()
        XCTAssertNil(vm.reminder)
        XCTAssertEqual(repo.dismissCalls, 1)
    }

    func test_dismissFailureKeepsTheReminderSoItComesBackHonestly() async {
        let repo = FakeRepo()
        repo.dismissError = HTTPError.timeout
        repo.reminder = HeartRateWatchReminder(watchMaxHr: 180, profileMaxHr: 197, deviationPct: 8.6, since: "2026-09-01", latestWorkoutDay: "2026-09-17", watchRestingHr: 50)
        let vm = makeVM(repo)
        await vm.loadWatchCheck()
        await vm.dismissReminder()
        XCTAssertNotNil(vm.reminder)
    }

    // MARK: - 自動更新開關

    func test_toggleWritesTheProfileFieldAndKeepsTheNewValue() async {
        var sent: [[String: Any]] = []
        let vm = makeVM(FakeRepo(), updater: { sent.append($0); return true })
        await vm.setAutoUpdate(true)
        XCTAssertTrue(vm.autoUpdateMaxHR)
        XCTAssertEqual(sent.first?["auto_update_max_hr"] as? Bool, true)
    }

    func test_toggleRollsBackAndReportsWhenTheSaveFails() async {
        let vm = makeVM(FakeRepo(), autoUpdate: true, updater: { _ in false })
        await vm.setAutoUpdate(false)
        XCTAssertTrue(vm.autoUpdateMaxHR)
        XCTAssertNotNil(vm.errorMessage)
    }
}
