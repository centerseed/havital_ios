import XCTest
@testable import paceriz_dev

// MARK: - MethodologyCoordinatorTests

@MainActor
final class MethodologyCoordinatorTests: XCTestCase {

    // MARK: - Properties

    private var mockRepository: MockTrainingPlanV2Repository!

    // MARK: - Helpers

    private func makeCoordinator(
        overviewId: String? = "overview-1",
        targetType: String? = "race_run",
        onMethodologyChanged: @escaping (PlanOverviewV2) async -> Void = { _ in },
        onPaywallNeeded: @escaping () -> Void = {},
        onNetworkError: @escaping (Error) -> Void = { _ in }
    ) -> MethodologyCoordinator {
        MethodologyCoordinator(
            repository: mockRepository,
            currentTargetType: { targetType },
            currentOverviewId: { overviewId },
            onMethodologyChanged: onMethodologyChanged,
            onPaywallNeeded: onPaywallNeeded,
            onNetworkError: onNetworkError
        )
    }

    private func makeOverview(id: String = "overview-1") -> PlanOverviewV2 {
        PlanOverviewV2(
            id: id,
            targetId: "target-1",
            targetType: "race_run",
            targetDescription: nil,
            methodologyId: "paceriz",
            totalWeeks: 16,
            startFromStage: "base",
            raceDate: nil,
            distanceKm: 42.195,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: nil,
            targetTime: nil,
            isMainRace: nil,
            targetName: "Marathon",
            methodologyOverview: nil,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: nil,
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }

    private func makeMethodology(id: String = "polarized") -> MethodologyV2 {
        MethodologyV2(
            id: id,
            name: "Polarized Training",
            description: "80/20 easy to hard",
            targetTypes: ["race_run"],
            phases: ["base", "build", "peak"],
            crossTrainingEnabled: false
        )
    }

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanV2Repository()
    }

    override func tearDown() {
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_loadMethodologies_success() async {
        // Arrange
        let methodology = makeMethodology()
        mockRepository.methodologiesToReturn = [methodology]
        let coordinator = makeCoordinator()

        // Act
        await coordinator.loadMethodologies()

        // Assert
        XCTAssertEqual(coordinator.availableMethodologies.count, 1)
        XCTAssertEqual(coordinator.availableMethodologies.first?.id, "polarized")
        XCTAssertEqual(mockRepository.getMethodologiesCallCount, 1)
    }

    func test_changeMethodology_success_calls_onMethodologyChanged() async {
        // Arrange
        let updatedOverview = makeOverview(id: "overview-1")
        mockRepository.overviewToReturn = updatedOverview

        let expectation = expectation(description: "onMethodologyChanged is called")
        var receivedOverview: PlanOverviewV2?

        let coordinator = makeCoordinator(
            onMethodologyChanged: { overview in
                receivedOverview = overview
                expectation.fulfill()
            }
        )

        // Act
        await coordinator.changeMethodology(methodologyId: "polarized")

        // Assert
        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(receivedOverview?.id, "overview-1")
        XCTAssertEqual(mockRepository.updateOverviewCallCount, 1)
        XCTAssertEqual(mockRepository.lastUpdatedOverviewMethodologyId, "polarized")
    }

    func test_changeMethodology_subscriptionRequired_calls_onPaywallNeeded() async {
        // Arrange
        mockRepository.errorToThrow = DomainError.subscriptionRequired

        let expectation = expectation(description: "onPaywallNeeded is called")
        let coordinator = makeCoordinator(
            onPaywallNeeded: { expectation.fulfill() }
        )

        // Act
        await coordinator.changeMethodology(methodologyId: "polarized")

        // Assert
        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(mockRepository.updateOverviewCallCount, 1)
    }
}
