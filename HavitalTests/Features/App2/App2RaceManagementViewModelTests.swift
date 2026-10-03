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

    func testPromotionRemainsBusyAndRejectsDuplicateWriteUntilResponse() async {
        let repository = MockTargetRepository()
        repository.targetsToReturn = [target(id: "main", main: true), target(id: "support", main: false)]
        repository.updateTargetDelayNanoseconds = 250_000_000
        let viewModel = App2RaceManagementViewModel(targetRepository: repository)
        await viewModel.loadIfNeeded()

        let mutation = Task { await viewModel.setAsMain("support") }
        while repository.updateTargetCallCount == 0 { await Task.yield() }
        XCTAssertTrue(viewModel.isSaving)

        await viewModel.setAsMain("support")
        XCTAssertEqual(repository.updateTargetCallCount, 1)

        await mutation.value
        XCTAssertFalse(viewModel.isSaving)
    }

    func testDismissingConfirmationDoesNotLeaveAConfirmableWrite() async {
        let repository = MockTargetRepository()
        repository.targetsToReturn = [target(id: "main", main: true), target(id: "support", main: false)]
        let viewModel = App2RaceManagementViewModel(targetRepository: repository)
        await viewModel.loadIfNeeded()
        viewModel.requestSetAsMainConfirmation("support")

        viewModel.cancelSetAsMainConfirmation()
        await viewModel.confirmPendingSetAsMain()

        XCTAssertNil(viewModel.pendingPromotionID)
        XCTAssertEqual(repository.updateTargetCallCount, 0)
    }

    func testConfirmedIDIsConsumedBeforeDialogDismissalCallback() async {
        let repository = MockTargetRepository()
        repository.targetsToReturn = [target(id: "main", main: true), target(id: "support", main: false)]
        let viewModel = App2RaceManagementViewModel(targetRepository: repository)
        await viewModel.loadIfNeeded()
        viewModel.requestSetAsMainConfirmation("support")

        let confirmedID = viewModel.takePendingSetAsMainConfirmation()
        viewModel.cancelSetAsMainConfirmation()

        XCTAssertEqual(confirmedID, "support")
        if let confirmedID { await viewModel.setAsMain(confirmedID) }
        XCTAssertEqual(repository.updateTargetCallCount, 1)
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
