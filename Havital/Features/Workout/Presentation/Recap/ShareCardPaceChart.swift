import CoreGraphics
import SwiftUI

enum ShareCardPaceChartMath {
    private static let chartWidthFraction: CGFloat = 0.55
    private static let chartHeightFraction: CGFloat = 0.12
    private static let linePadding: CGFloat = 6

    static func chartSize(cardSize: CGSize) -> CGSize {
        CGSize(
            width: cardSize.width * chartWidthFraction,
            height: cardSize.height * chartHeightFraction
        )
    }

    static func averagePaceSeconds(samples: [ShareCardPaceSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { $0 + $1.paceSecondsPerKm }
        return total / Double(samples.count)
    }

    static func paceYCoordinate(
        paceSecondsPerKm: Double,
        minPace: Double,
        maxPace: Double,
        in rect: CGRect
    ) -> CGFloat {
        guard maxPace > minPace else { return rect.midY }
        let fraction = (paceSecondsPerKm - minPace) / (maxPace - minPace)
        return rect.minY + (CGFloat(1.0 - fraction) * rect.height)
    }

    static func paceLinePoints(samples: [ShareCardPaceSample], in rect: CGRect) -> [CGPoint] {
        guard samples.count >= 2 else { return [] }

        let paces = samples.map(\.paceSecondsPerKm)
        let minPace = paces.min() ?? 0
        let maxPace = paces.max() ?? minPace
        let xStep = rect.width / CGFloat(samples.count - 1)

        return samples.enumerated().map { index, sample in
            CGPoint(
                x: rect.minX + (CGFloat(index) * xStep),
                y: paceYCoordinate(
                    paceSecondsPerKm: sample.paceSecondsPerKm,
                    minPace: minPace,
                    maxPace: maxPace,
                    in: rect
                )
            )
        }
    }

    static func paceLinePath(samples: [ShareCardPaceSample], in rect: CGRect) -> Path {
        var path = Path()
        guard samples.count >= 2 else { return path }

        let gaps = offsetGaps(samples: samples)
        let points = paceLinePoints(samples: samples, in: rect)

        for index in points.indices {
            if index == 0 || gaps[index] {
                path.move(to: points[index])
            } else {
                path.addLine(to: points[index])
            }
        }

        return path
    }

    private static func offsetGaps(samples: [ShareCardPaceSample]) -> [Bool] {
        guard samples.count > 1 else { return Array(repeating: false, count: samples.count) }

        let deltas = zip(samples, samples.dropFirst()).map { $1.offsetSeconds - $0.offsetSeconds }
        let sorted = deltas.sorted()
        let medianGap = sorted[sorted.count / 2]
        let breakThreshold = max(medianGap * 2, 1)

        var gaps = Array(repeating: false, count: samples.count)
        for index in 1..<samples.count {
            gaps[index] = (samples[index].offsetSeconds - samples[index - 1].offsetSeconds) > breakThreshold
        }
        return gaps
    }

}

struct ShareCardPaceChartView: View {
    let samples: [ShareCardPaceSample]
    let cardSize: CGSize

    @ObservedObject private var unitManager = UnitManager.shared

    private var chartSize: CGSize {
        ShareCardPaceChartMath.chartSize(cardSize: cardSize)
    }

    private var averagePaceText: String? {
        guard let average = ShareCardPaceChartMath.averagePaceSeconds(samples: samples) else { return nil }
        return unitManager.formatPace(secondsPerKm: average)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.45))

            Canvas { context, size in
                let rect = CGRect(
                    x: 6,
                    y: 6,
                    width: max(0, size.width - 12),
                    height: max(0, size.height - 12)
                )
                let path = ShareCardPaceChartMath.paceLinePath(samples: samples, in: rect)
                context.stroke(
                    path,
                    with: .color(RecapPalette.brand),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }

            if let averagePaceText {
                Text(averagePaceText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.trailing, 8)
            }
        }
        .frame(width: chartSize.width, height: chartSize.height)
    }
}
