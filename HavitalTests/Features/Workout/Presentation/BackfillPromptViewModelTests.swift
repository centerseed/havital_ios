import XCTest
@testable import paceriz_dev

final class BackfillPromptViewModelTests: XCTestCase {
    private let skippedKey = "onboarding_backfill_skipped"

    override func setUp() {
        super.setUp()
        OnboardingBackfillCoordinator.shared.resetBackfillState()
    }

    override func tearDown() {
        OnboardingBackfillCoordinator.shared.resetBackfillState()
        super.tearDown()
    }

    func testConfirmBackfillNavigatesToSyncWithoutMarkingSkipped() {
        let sut = BackfillPromptViewModel(dataSource: .garmin, targetDistance: 21.1)

        sut.confirmBackfill()

        XCTAssertTrue(sut.isNavigatingToSync)
        XCTAssertFalse(sut.isNavigatingToPersonalBest)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: skippedKey))
    }

    func testSkipBackfillMarksSkippedAndNavigatesToPersonalBest() {
        let sut = BackfillPromptViewModel(dataSource: .strava, targetDistance: 42.195)

        sut.skipBackfill()

        XCTAssertTrue(sut.isNavigatingToPersonalBest)
        XCTAssertFalse(sut.isNavigatingToSync)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: skippedKey))
    }

    func testDataSourceMetadataMatchesProvider() {
        let garmin = BackfillPromptViewModel(dataSource: .garmin, targetDistance: 10)
        XCTAssertEqual(garmin.dataSourceDisplayName, "Garmin Connect™")
        XCTAssertEqual(garmin.dataSourceIconName, "clock.arrow.circlepath")

        let strava = BackfillPromptViewModel(dataSource: .strava, targetDistance: 10)
        XCTAssertEqual(strava.dataSourceDisplayName, "Strava")
        XCTAssertEqual(strava.dataSourceIconName, "figure.run")

        let appleHealth = BackfillPromptViewModel(dataSource: .appleHealth, targetDistance: 10)
        XCTAssertEqual(appleHealth.dataSourceDisplayName, "Apple Health")
        XCTAssertEqual(appleHealth.dataSourceIconName, "heart.fill")
    }
}
