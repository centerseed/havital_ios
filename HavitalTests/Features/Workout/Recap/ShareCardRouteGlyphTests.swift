import CoreGraphics
import XCTest
@testable import paceriz_dev

final class ShareCardRouteGlyphTests: XCTestCase {
    func testNormalizedPoints_fitInsideSquareWithoutStretch() {
        let points = [
            ShareCardRoutePoint(latitude: 25.0, longitude: 121.50),
            ShareCardRoutePoint(latitude: 25.01, longitude: 121.52),
            ShareCardRoutePoint(latitude: 25.02, longitude: 121.48),
        ]
        let square = CGSize(width: 60, height: 60)
        let normalized = ShareCardRouteMath.normalizedPoints(
            points: points, inSquare: square, smoothingEnabled: false
        )
        XCTAssertEqual(normalized.count, 3)
        for p in normalized {
            XCTAssertGreaterThanOrEqual(p.x, 0)
            XCTAssertLessThanOrEqual(p.x, square.width)
            XCTAssertGreaterThanOrEqual(p.y, 0)
            XCTAssertLessThanOrEqual(p.y, square.height)
        }
        let xs = normalized.map(\.x)
        let ys = normalized.map(\.y)
        XCTAssertGreaterThan(xs.max()! - xs.min()!, 1)
        XCTAssertGreaterThan(ys.max()! - ys.min()!, 1)
    }

    func testShouldSmooth_trueWhenManyPoints() {
        XCTAssertTrue(ShareCardRouteMath.shouldSmooth(count: 300))
        XCTAssertFalse(ShareCardRouteMath.shouldSmooth(count: 20))
    }

    func testSquareSize_equalsCardWidthOverSix() {
        XCTAssertEqual(ShareCardRouteMath.squareSize(cardWidth: 300), 50, accuracy: 0.001)
    }
}
