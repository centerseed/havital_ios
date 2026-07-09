import CoreGraphics
import SwiftUI

enum ShareCardRouteMath {
    private static let metersPerDegreeLat = 110_540.0
    private static let metersPerDegreeLonAtEquator = 111_320.0

    static func shouldSmooth(count: Int) -> Bool {
        count > 100
    }

    static func squareSize(cardWidth: CGFloat, scale: CGFloat = 1.0) -> CGFloat {
        (cardWidth / 6) * ShareCardLayoutMath.clampRouteScale(scale)
    }

    static func normalizedPoints(
        points: [ShareCardRoutePoint],
        inSquare square: CGSize,
        smoothingEnabled: Bool
    ) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let centroidLat = points.map(\.latitude).reduce(0, +) / Double(points.count)
        let centroidLng = points.map(\.longitude).reduce(0, +) / Double(points.count)
        let latRad = centroidLat * .pi / 180.0
        let lonScale = metersPerDegreeLonAtEquator * cos(latRad)

        var projected: [(x: Double, y: Double)] = points.map { point in
            let x = (point.longitude - centroidLng) * lonScale
            let y = (point.latitude - centroidLat) * metersPerDegreeLat
            return (x, y)
        }

        if smoothingEnabled, shouldSmooth(count: points.count) {
            projected = movingAverage3(projected)
        }

        return fitToSquare(projected, square: square)
    }

    static func routePath(from normalized: [CGPoint]) -> Path {
        var path = Path()
        guard let first = normalized.first else { return path }
        path.move(to: first)
        for point in normalized.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private static func movingAverage3(_ points: [(x: Double, y: Double)]) -> [(x: Double, y: Double)] {
        guard points.count > 2 else { return points }
        var smoothed = points
        for index in 1..<(points.count - 1) {
            smoothed[index] = (
                (points[index - 1].x + points[index].x + points[index + 1].x) / 3.0,
                (points[index - 1].y + points[index].y + points[index + 1].y) / 3.0
            )
        }
        return smoothed
    }

    private static func fitToSquare(
        _ points: [(x: Double, y: Double)],
        square: CGSize
    ) -> [CGPoint] {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        let width = maxX - minX
        let height = maxY - minY

        let scale: CGFloat
        if width <= 0, height <= 0 {
            scale = 1
        } else if width <= 0 {
            scale = square.height / CGFloat(height)
        } else if height <= 0 {
            scale = square.width / CGFloat(width)
        } else {
            scale = min(square.width / CGFloat(width), square.height / CGFloat(height))
        }

        let centerX = (minX + maxX) / 2.0
        let centerY = (minY + maxY) / 2.0

        return points.map { point in
            CGPoint(
                x: square.width / 2 + (CGFloat(point.x - centerX) * scale),
                y: square.height / 2 - (CGFloat(point.y - centerY) * scale)
            )
        }
    }
}

struct ShareCardRouteGlyphView: View {
    let points: [ShareCardRoutePoint]
    let cardWidth: CGFloat
    var routeColor: ShareCardRouteColor = .brand
    var routeScale: CGFloat = 1.0

    private var square: CGSize {
        let side = ShareCardRouteMath.squareSize(cardWidth: cardWidth, scale: routeScale)
        return CGSize(width: side, height: side)
    }

    private var normalized: [CGPoint] {
        ShareCardRouteMath.normalizedPoints(
            points: points,
            inSquare: square,
            smoothingEnabled: ShareCardRouteMath.shouldSmooth(count: points.count)
        )
    }

    var body: some View {
        Canvas { context, size in
            guard normalized.count >= 2 else { return }

            let routePath = ShareCardRouteMath.routePath(from: normalized)
            context.stroke(
                routePath,
                with: .color(routeColor.strokeColor),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )

            if let start = normalized.first {
                let startRect = CGRect(
                    x: start.x - 3,
                    y: start.y - 3,
                    width: 6,
                    height: 6
                )
                context.fill(
                    Path(ellipseIn: startRect),
                    with: .color(routeColor.startMarkerColor)
                )
            }

            if let end = normalized.last {
                let endRect = CGRect(
                    x: end.x - 3,
                    y: end.y - 3,
                    width: 6,
                    height: 6
                )
                context.fill(
                    Path(ellipseIn: endRect),
                    with: .color(routeColor.endMarkerColor)
                )
            }
        }
        .frame(width: square.width, height: square.height)
    }
}
