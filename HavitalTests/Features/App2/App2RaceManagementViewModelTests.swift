import XCTest
@testable import paceriz_dev

@MainActor
final class App2RaceManagementViewModelTests: XCTestCase {
    func testPromotionRequiresExplicitConfirmationBeforeWriting() async {
        let repository = MockTargetRepository()
        repository.targetsToReturn = [target(id: "main", main: true), target(id: "support", main: false)]
        let viewModel = App2RaceManagementViewModel(targetRepository: repository)
        await viewModel.loadIfNeeded()

        viewModel.requestSetAsMainConfirmation("support")

        XCTAssertEqual(viewModel.pendingPromotionID, "support")
        XCTAssertEqual(repository.updateTargetCallCount, 0)
    }

    func testConfirmingPromotionWritesOnceAndClearsConfirmation() async {
        let repository = MockTargetRepository()
        repository.targetsToReturn = [target(id: "main", main: true), target(id: "support", main: false)]
        let viewModel = App2RaceManagementViewModel(targetRepository: repository)
        await viewModel.loadIfNeeded()
        viewModel.requestSetAsMainConfirmation("support")

        await viewModel.confirmPendingSetAsMain()

        XCTAssertEqual(repository.updateTargetCallCount, 1)
        XCTAssertNil(viewModel.pendingPromotionID)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertTrue(repository.lastUpdatedTarget?.isMainRace == true)
    }

    func testPromotionKeepsBackendAdvisoryForTheSuccessDialog() async {
        let repository = MockTargetRepository()
        repository.targetsToReturn = [target(id: "main", main: true), target(id: "support", main: false)]
        repository.mutationMessageToReturn = "Consider choosing a closer race first."
        let viewModel = App2RaceManagementViewModel(targetRepository: repository)
        await viewModel.loadIfNeeded()
        viewModel.requestSetAsMainConfirmation("support")

        await viewModel.confirmPendingSetAsMain()

        XCTAssertEqual(viewModel.successMessage, "Consider choosing a closer race first.")
        XCTAssertTrue(viewModel.didPromoteMainRace)
    }

    func testPromotionWithoutBackendAdvisoryLeavesSuccessMessageEmpty() async {
        let repository = MockTargetRepository()
        repository.targetsToReturn = [target(id: "main", main: true), target(id: "support", main: false)]
        let viewModel = App2RaceManagementViewModel(targetRepository: repository)
        await viewModel.loadIfNeeded()
        viewModel.requestSetAsMainConfirmation("support")

        await viewModel.confirmPendingSetAsMain()

        XCTAssertNil(viewModel.successMessage)
        XCTAssertTrue(viewModel.didPromoteMainRace)
    }

    private func target(id: String, main: Bool) -> Target {
        Target(
            id: id,
            type: "race_run",
            name: "Race \(id)",
            distanceKm: 42,
            targetTime: 14_400,
            targetPace: "5:41",
            raceDate: 1_800_000_000,
            isMainRace: main,
            trainingWeeks: 30,
            timezone: "Asia/Taipei"
        )
    }
}
