import XCTest
@testable import paceriz_dev

/// 假 repo：只實作 getHistory 有意義，其餘走 protocol 情境最小實作。
/// 無外部服務，符合 mock 邊界（純測 ViewModel 分組/狀態）。
private final class FakeRizoRepo: RizoRepository {
    let items: [RizoHistoryItem]
    let error: Error?
    init(items: [RizoHistoryItem] = [], error: Error? = nil) {
        self.items = items; self.error = error
    }
    func sendJournalChat(workoutId: String, message: String,
                         presetSelections: [String], sessionId: String?) async throws -> RizoReply {
        throw RizoRepositoryError.dataSourceUnavailable
    }
    func sendChat(scenario: String, message: String, sessionId: String?) async throws -> RizoReply {
        throw RizoRepositoryError.dataSourceUnavailable
    }
    func getPresets(scenario: String) async throws -> [RizoPreset] { [] }
    func getHistory() async throws -> (
        items: [RizoHistoryItem],
        pendingPlanChanges: [String: PendingPlanChange]
    ) {
        if let error { throw error }
        return (items, [:])
    }
}

@MainActor
final class RizoHistoryViewModelTests: XCTestCase {

    func test_load_empty_setsEmpty() async {
        let vm = RizoHistoryViewModel(repository: FakeRizoRepo(items: []))
        await vm.load()
        XCTAssertTrue(vm.state.isEmpty)
    }

    func test_load_grouped_setsLoaded() async {
        let items = [
            RizoHistoryItem(sessionId: "s1", scenario: "journal",
                            userInput: "hi", rizoResponse: "yo",
                            ts: "2026-07-01T10:00:00+00:00")
        ]
        let vm = RizoHistoryViewModel(repository: FakeRizoRepo(items: items))
        await vm.load()
        XCTAssertEqual(vm.state.data?.count, 1)
        XCTAssertEqual(vm.state.data?.first?.scenario, "journal")
    }

    func test_load_error_setsError() async {
        let vm = RizoHistoryViewModel(
            repository: FakeRizoRepo(error: RizoRepositoryError.dataSourceUnavailable))
        await vm.load()
        XCTAssertTrue(vm.state.hasError)
    }
}
