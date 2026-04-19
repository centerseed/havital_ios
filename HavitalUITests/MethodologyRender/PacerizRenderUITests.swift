import XCTest

final class PacerizRenderUITests: MethodologyRenderUITestBase {
    @MainActor
    func testPacerizOverviewFixtureRendersExpectedElements() throws {
        try assertOverviewFixture("race_run_paceriz")
    }

    @MainActor
    func testPacerizTargetInfoOverviewFixtureRendersExpectedElements() throws {
        try assertOverviewFixture("race_run_paceriz", tab: .targetInfo)
    }

    @MainActor
    func testPacerizBaseWeeklyFixtureRendersExpectedElements() throws {
        try assertWeeklyFixture(
            "paceriz_42k_base_week",
            methodologyId: "paceriz",
            phaseId: "base"
        )
    }

    @MainActor
    func testPacerizPeakWeeklyFixtureRendersExpectedElements() throws {
        try assertWeeklyFixture(
            "paceriz_42k_peak_week",
            methodologyId: "paceriz",
            phaseId: "peak"
        )
    }
}
