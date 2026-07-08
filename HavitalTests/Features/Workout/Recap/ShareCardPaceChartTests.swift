import CoreGraphics
import XCTest
@testable import paceriz_dev

final class ShareCardPaceChartTests: XCTestCase {
    func testChartSize_matchesCardFractions() {
        let cardSize = CGSize(width: 400, height: 500)
        let chartSize = ShareCardPaceChartMath.chartSize(cardSize: cardSize)
        XCTAssertEqual(chartSize.width, 220, accuracy: 0.001)
        XCTAssertEqual(chartSize.height, 60, accuracy: 0.001)
    }

    func testAveragePace_computesMeanOfSamples() {
        let samples = [
            ShareCardPaceSample(offsetSeconds: 0, paceSecondsPerKm: 300),
            ShareCardPaceSample(offsetSeconds: 60, paceSecondsPerKm: 360),
        ]
        XCTAssertEqual(ShareCardPaceChartMath.averagePaceSeconds(samples: samples)!, 330, accuracy: 0.001)
    }

    func testPaceYCoordinate_slowerPaceTowardTop() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        let fastY = ShareCardPaceChartMath.paceYCoordinate(
            paceSecondsPerKm: 300,
            minPace: 300,
            maxPace: 360,
            in: rect
        )
        let slowY = ShareCardPaceChartMath.paceYCoordinate(
            paceSecondsPerKm: 360,
            minPace: 300,
            maxPace: 360,
            in: rect
        )
        XCTAssertLessThan(slowY, fastY)
    }

    func testPaceLinePoints_usesAllSamplesWithoutDownsampling() {
        let samples = (0..<5).map {
            ShareCardPaceSample(offsetSeconds: $0 * 60, paceSecondsPerKm: 300 + Double($0 * 10))
        }
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        let points = ShareCardPaceChartMath.paceLinePoints(samples: samples, in: rect)
        XCTAssertEqual(points.count, 5)
    }
}
