import XCTest
@testable import paceriz_dev

/// T-0176：照片可 pinch 縮放後，夾制算法必須同時吃 scale。
///
/// 這組測試的存在理由：夾制原本在預覽（WorkoutRecapView）與匯出（RecapShareCard）各寫一份。
/// 只要有一邊沒納入 scale，使用者就會「預覽好好的、分享出去的圖偏掉」。現在兩邊共用
/// ShareCardPhotoMath，這裡把它的行為釘死。
final class ShareCardPhotoMathTests: XCTestCase {

    private let card = CGSize(width: 400, height: 500)   // 4:5

    // MARK: - 縮放範圍

    func test_clampScale_floorIsOne_becauseBelowOneWouldExposeBlankEdges() {
        // scaledToFill 在 1.0 已經剛好填滿；再縮小就露白。
        XCTAssertEqual(ShareCardPhotoMath.clampScale(0.5), 1.0)
        XCTAssertEqual(ShareCardPhotoMath.clampScale(0.999), 1.0)
    }

    func test_clampScale_ceilingIsFour() {
        XCTAssertEqual(ShareCardPhotoMath.clampScale(10.0), 4.0)
        XCTAssertEqual(ShareCardPhotoMath.clampScale(4.0), 4.0)
    }

    func test_clampScale_passesThroughInsideRange() {
        XCTAssertEqual(ShareCardPhotoMath.clampScale(2.5), 2.5, accuracy: 0.0001)
    }

    // MARK: - 填滿倍率

    func test_fillScale_picksTheLargerRatio_soTheCardIsFullyCovered() {
        // 寬照片（800×500）填 400×500 的卡：高度比 = 1.0、寬度比 = 0.5 → 取 1.0
        let wide = CGSize(width: 800, height: 500)
        XCTAssertEqual(ShareCardPhotoMath.fillScale(image: wide, card: card), 1.0, accuracy: 0.0001)

        // 窄照片（400×1000）：寬度比 = 1.0、高度比 = 0.5 → 取 1.0
        let tall = CGSize(width: 400, height: 1000)
        XCTAssertEqual(ShareCardPhotoMath.fillScale(image: tall, card: card), 1.0, accuracy: 0.0001)
    }

    // MARK: - 夾制

    func test_squarePhotoAtScaleOne_canOnlyPanVertically() {
        // 500×500 的照片填 400×500 → fill = 1.0 → 渲染 500×500。
        // 水平溢出 100 → ±50；垂直不溢出 → 只能夾 0。
        let square = CGSize(width: 500, height: 500)

        let clamped = ShareCardPhotoMath.clampOffset(
            CGSize(width: 999, height: 999),
            image: square, card: card, photoScale: 1.0
        )
        XCTAssertEqual(clamped.width, 50, accuracy: 0.0001)
        XCTAssertEqual(clamped.height, 0, accuracy: 0.0001, "no vertical overflow -> offset must clamp to 0, else the card shows blank edges")
    }

    func test_zoomingIn_widensThePanRange_onBothAxes() {
        let square = CGSize(width: 500, height: 500)

        // scale 2.0 → 渲染 1000×1000。水平溢出 600 → ±300；垂直溢出 500 → ±250。
        let clamped = ShareCardPhotoMath.clampOffset(
            CGSize(width: 9999, height: 9999),
            image: square, card: card, photoScale: 2.0
        )
        XCTAssertEqual(clamped.width, 300, accuracy: 0.0001)
        XCTAssertEqual(clamped.height, 250, accuracy: 0.0001,
                       "zooming in makes the photo overflow vertically -> panning up/down must unlock")
    }

    func test_zoomingBackOut_pullsAnOutOfBoundsOffsetBackIn() {
        let square = CGSize(width: 500, height: 500)

        // 先在 scale 2.0 推到邊界
        let atZoom = ShareCardPhotoMath.clampOffset(
            CGSize(width: 9999, height: 9999),
            image: square, card: card, photoScale: 2.0
        )
        XCTAssertEqual(atZoom.height, 250, accuracy: 0.0001)

        // 縮回 1.0：垂直不再溢出 → 舊 offset 必須被拉回 0，否則畫面露白
        let backOut = ShareCardPhotoMath.clampOffset(
            atZoom, image: square, card: card, photoScale: 1.0
        )
        XCTAssertEqual(backOut.width, 50, accuracy: 0.0001)
        XCTAssertEqual(backOut.height, 0, accuracy: 0.0001,
                       "zooming back out must pull the offset back in bounds, not leave it where the zoom put it")
    }

    func test_scaleBelowOne_isTreatedAsOne_notAsShrink() {
        let square = CGSize(width: 500, height: 500)
        let shrunk = ShareCardPhotoMath.clampOffset(
            CGSize(width: 999, height: 999),
            image: square, card: card, photoScale: 0.3
        )
        // 若 0.3 被當真，渲染只有 150×150、遠小於卡片 → 會露白。必須等同 scale 1.0。
        let atOne = ShareCardPhotoMath.clampOffset(
            CGSize(width: 999, height: 999),
            image: square, card: card, photoScale: 1.0
        )
        XCTAssertEqual(shrunk.width, atOne.width, accuracy: 0.0001)
        XCTAssertEqual(shrunk.height, atOne.height, accuracy: 0.0001)
    }

    func test_degeneratePhoto_doesNotCrashAndPinsToCenter() {
        let empty = CGSize(width: 0, height: 0)
        let clamped = ShareCardPhotoMath.clampOffset(
            CGSize(width: 100, height: 100),
            image: empty, card: card, photoScale: 2.0
        )
        XCTAssertEqual(clamped, .zero)
    }

    // MARK: - 9:16 換比例後仍不露白

    func test_switchingTo916_reclampsOffsetForTheTallerCard() {
        let square = CGSize(width: 500, height: 500)
        let card916 = CGSize(width: 400, height: 711)   // 400 / (9/16)

        // 4:5 時水平可移 ±50
        let at45 = ShareCardPhotoMath.clampOffset(
            CGSize(width: 50, height: 0),
            image: square, card: card, photoScale: 1.0
        )
        XCTAssertEqual(at45.width, 50, accuracy: 0.0001)

        // 換成 9:16：照片要填更高的卡 → fill 變大 → 水平溢出更多，50 仍在界內
        let at916 = ShareCardPhotoMath.clampOffset(
            at45, image: square, card: card916, photoScale: 1.0
        )
        let rendered = ShareCardPhotoMath.renderedSize(image: square, card: card916, photoScale: 1.0)
        XCTAssertGreaterThanOrEqual(rendered.width, card916.width, "photo must still cover the full width at 9:16")
        XCTAssertGreaterThanOrEqual(rendered.height, card916.height, "photo must still cover the full height at 9:16")
        XCTAssertLessThanOrEqual(abs(at916.width), (rendered.width - card916.width) / 2 + 0.001)
    }

    // MARK: - 比例模型

    func test_aspectExportSizes() {
        XCTAssertEqual(ShareCardAspect.portrait45.exportSize(width: 360),
                       CGSize(width: 360, height: 450))
        XCTAssertEqual(ShareCardAspect.story916.exportSize(width: 360),
                       CGSize(width: 360, height: 640))
    }

    func test_defaultAspectIsPortrait45_soExistingCardsAreUnchanged() {
        XCTAssertEqual(ShareCardAspect.allCases.first, .portrait45)
        XCTAssertEqual(ShareCardAspect.portrait45.ratio, 4.0 / 5.0, accuracy: 0.0001)
        XCTAssertEqual(ShareCardAspect.story916.ratio, 9.0 / 16.0, accuracy: 0.0001)
    }
}
