import XCTest
@testable import paceriz_dev

// MARK: - Mocks（內嵌，避免新資料夾的 pbxproj 問題）

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

// MARK: - Tests

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
        XCTAssertEqual(vm.status(for: "plank"), .completed)
        XCTAssertFalse(vm.canSubmit)
        vm.selectedRPE = 4
        XCTAssertTrue(vm.canSubmit)
    }

    func test_toggle_skip_builds_correct_request() async {
        let repo = MockStrengthCompletionRepository()
        let vm = makeVM(repo: repo, store: .init())
        vm.selectedRPE = 4
        vm.toggleSkip(exerciseId: "dead_bug")
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
        let repo = MockStrengthCompletionRepository()
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

    func test_dismissError_returns_to_form() async {
        let repo = MockStrengthCompletionRepository()
        repo.stubError = DomainError.networkFailure("boom")
        let vm = makeVM(repo: repo, store: .init())
        vm.selectedRPE = 4
        await vm.submit()
        guard case .failed = vm.phase else { return XCTFail("expected failed") }
        vm.dismissError()
        guard case .form = vm.phase else { return XCTFail("expected form after dismiss") }
    }
}
