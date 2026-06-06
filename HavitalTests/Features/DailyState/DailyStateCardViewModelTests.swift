import XCTest
@testable import paceriz_dev

@MainActor
final class DailyStateCardViewModelTests: XCTestCase {
    private final class FakeRepo: DailyStateRepository {
        var card: DailyStateCard?
        var error: Error?
        func fetchTodayState() async throws -> DailyStateCard {
            if let error { throw error }; return card!
        }
    }
    private func card(locked: Bool) -> DailyStateCard {
        DailyStateCard(lens: .pre, source: "llm", headline: "H", factType: nil,
            narrativeText: locked ? nil : "n", chips: ["c"], causeChips: [],
            actionLine: "12K easy", rizoScenario: nil, divergenceFlagText: nil,
            isPaid: !locked, isLocked: locked, upsellReason: locked ? "unlock_full_read" : nil)
    }

    func test_load_success_sets_loaded() async {
        let repo = FakeRepo(); repo.card = card(locked: false)
        let vm = DailyStateCardViewModel(repository: repo)
        await vm.loadForTest()
        XCTAssertEqual(vm.state.data?.headline, "H")
    }

    func test_load_error_sets_error() async {
        let repo = FakeRepo(); repo.error = URLError(.badServerResponse)
        let vm = DailyStateCardViewModel(repository: repo)
        await vm.loadForTest()
        XCTAssertTrue(vm.state.hasError)
    }

    func test_cancelled_does_not_set_error() async {
        let repo = FakeRepo(); repo.error = URLError(.cancelled)
        let vm = DailyStateCardViewModel(repository: repo)
        await vm.loadForTest()
        XCTAssertFalse(vm.state.hasError)   // cancelled 過濾
    }
}
