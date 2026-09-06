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
        func applyBenchmark(_ request: BenchmarkApplyRequestDTO) async throws -> BenchmarkApplyResultDTO {
            BenchmarkApplyResultDTO(confirmed: true, vdot: 39.0,
                                    finishPrediction: .init(estimatedRaceTimeSeconds: 17260))
        }
        func scheduleNextBenchmark(_ request: BenchmarkScheduleRequestDTO) async throws -> BenchmarkScheduleResultDTO {
            BenchmarkScheduleResultDTO(scheduled: true, scheduledWeek: 6)
        }
    }

    func test_returns_mapped_entity() async throws {
        let remote = FakeRemote()
        remote.dto = StateCardDTO(lens: "post", source: "llm", headline: "H", factType: nil,
            narrativeText: "n", collapsedReason: nil, chips: ["c"], causeChips: [], mileageProgression: nil,
            action: nil, divergence: nil,
            access: .init(isPaid: true, locked: false, upsell: nil),
            benchmarkCalibration: nil, insights: nil, asof: nil)
        let repo = DailyStateRepositoryImpl(remoteDataSource: remote)
        let card = try await repo.fetchTodayState()
        XCTAssertEqual(card.lens, .post)
        XCTAssertEqual(card.chips, ["c"])
    }
}
