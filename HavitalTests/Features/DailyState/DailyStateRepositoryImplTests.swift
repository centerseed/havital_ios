import XCTest
@testable import paceriz_dev

final class DailyStateRepositoryImplTests: XCTestCase {
    private final class FakeRemote: DailyStateRemoteDataSourceProtocol {
        var dto: StateCardDTO?
        var error: Error?
        func fetchTodayState() async throws -> StateCardDTO {
            if let error { throw error }
            return dto!
        }
    }

    func test_returns_mapped_entity() async throws {
        let remote = FakeRemote()
        remote.dto = StateCardDTO(lens: "post", source: "llm", headline: "H", factType: nil,
            narrativeText: "n", chips: ["c"], causeChips: [], action: nil, divergence: nil,
            access: .init(isPaid: true, locked: false, upsell: nil))
        let repo = DailyStateRepositoryImpl(remoteDataSource: remote)
        let card = try await repo.fetchTodayState()
        XCTAssertEqual(card.lens, .post)
        XCTAssertEqual(card.chips, ["c"])
    }
}
