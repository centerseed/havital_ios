import XCTest

final class BeginnerMaintenanceRenderUITests: MethodologyRenderUITestBase {
    @MainActor
    func testBeginnerOverviewFixtureRendersExpectedElements() throws {
        try assertOverviewFixture("beginner_10k")
    }

    @MainActor
    func testComplete10KConversionWeeklyFixtureRendersExpectedElements() throws {
        try assertWeeklyFixture(
            "complete_10k_conversion_week",
            methodologyId: "complete_10k",
            phaseId: "conversion"
        )
    }

    @MainActor
    func testMaintenanceOverviewFixtureRendersExpectedElements() throws {
        try assertOverviewFixture("maintenance_aerobic")
    }
}
