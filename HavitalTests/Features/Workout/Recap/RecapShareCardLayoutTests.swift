import XCTest
@testable import paceriz_dev

final class RecapShareCardLayoutTests: XCTestCase {
    func testDisplayTitle_nilWhenTitleOverlayHidden() {
        let state = ShareCardEditorState.default
        XCTAssertFalse(state.titleLayout.isVisible)
        let title = RecapShareCardLogic.displayTitle(
            editorState: state,
            customTitle: nil,
            defaultTitle: "Completed Interval Training"
        )
        XCTAssertNil(title)
    }

    func testDisplayTitle_showsDefaultWhenVisibleAndNoCustomTitle() {
        var state = ShareCardEditorState.default
        state.titleLayout.isVisible = true
        let title = RecapShareCardLogic.displayTitle(
            editorState: state,
            customTitle: nil,
            defaultTitle: "Completed Interval Training"
        )
        XCTAssertEqual(title, "Completed Interval Training")
    }
}
