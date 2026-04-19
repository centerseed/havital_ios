import XCTest

final class PolarizedRenderUITests: MethodologyRenderUITestBase {
    @MainActor
    func testPolarizedBuildWeeklyFixtureRendersExpectedElements() throws {
        try assertWeeklyFixture(
            "polarized_42k_build_week",
            methodologyId: "polarized",
            phaseId: "build"
        )
    }
}
