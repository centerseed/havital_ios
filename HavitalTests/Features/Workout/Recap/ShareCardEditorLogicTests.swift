import XCTest
@testable import paceriz_dev

final class ShareCardEditorLogicTests: XCTestCase {
    func testToggleTitleVisibility_setsDefaultPosition() {
        var state = ShareCardEditorState.default
        ShareCardEditorLogic.setVisible(true, kind: .title, state: &state)
        XCTAssertTrue(state.titleLayout.isVisible)
        XCTAssertEqual(state.titleLayout.centerX, 0.50, accuracy: 0.001)
        XCTAssertEqual(state.titleLayout.centerY, 0.25, accuracy: 0.001)
    }

    func testDragOverlay_clampsNormalizedCenter() {
        var state = ShareCardEditorState.default
        ShareCardEditorLogic.dragOverlay(
            kind: .paceChart,
            translation: CGSize(width: 9999, height: -9999),
            cardSize: CGSize(width: 360, height: 450),
            state: &state
        )
        XCTAssertEqual(state.paceChartLayout.centerX, 0.95, accuracy: 0.001)
        XCTAssertEqual(state.paceChartLayout.centerY, 0.05, accuracy: 0.001)
    }

    func testAdjustRouteScale_clampsWithinBounds() {
        var state = ShareCardEditorState.default
        ShareCardEditorLogic.adjustRouteScale(delta: 10, state: &state)
        XCTAssertEqual(state.routeScale, ShareCardLayoutMath.maxRouteScale, accuracy: 0.001)

        ShareCardEditorLogic.adjustRouteScale(delta: -10, state: &state)
        XCTAssertEqual(state.routeScale, ShareCardLayoutMath.minRouteScale, accuracy: 0.001)
    }

    func testSetRouteColor_updatesState() {
        var state = ShareCardEditorState.default
        ShareCardEditorLogic.setRouteColor(.gold, state: &state)
        XCTAssertEqual(state.routeColor, .gold)
    }
}
