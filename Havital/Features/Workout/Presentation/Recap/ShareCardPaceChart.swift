import CoreGraphics
import SwiftUI

enum ShareCardPaceChartMath {
    private static let chartWidthFraction: CGFloat = 0.55
    /// 高度也以「卡片寬度」為基準，不是高度 —— 否則 9:16 的卡變高 42%，圖表跟著拉高，
    /// 同一段配速在 9:16 裡看起來就比 4:5 陡，等於同一次跑步講出兩種故事。
    ///
    /// 0.15 是從舊值換算來的：4:5 時 h = 1.25w，舊的 0.12 × h = 0.15 × w。
    /// 所以 4:5 的圖表尺寸一像素不變，只有 9:16 不再被拉長。
    private static let chartHeightFractionOfWidth: CGFloat = 0.15
    static let linePadding: CGFloat = 6

    static func chartSize(cardSize: CGSize) -> CGSize {
        CGSize(
            width: cardSize.width * chartWidthFraction,
            height: cardSize.width * chartHeightFractionOfWidth
        )
    }

    static func paceYCoordinate(
        paceSecondsPerKm: Double,
        minPace: Double,
        maxPace: Double,
        in rect: CGRect
    ) -> CGFloat {
        guard maxPace > minPace else { return rect.midY }
        let fraction = (paceSecondsPerKm - minPace) / (maxPace - minPace)
        // Faster pace (smaller s/km) plots higher on the card.
        return rect.minY + (CGFloat(fraction) * rect.height)
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

    private var chartSize: CGSize {
        ShareCardPaceChartMath.chartSize(cardSize: cardSize)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.45))

            Canvas { context, size in
                let rect = CGRect(
                    x: ShareCardPaceChartMath.linePadding,
                    y: ShareCardPaceChartMath.linePadding,
                    width: max(0, size.width - ShareCardPaceChartMath.linePadding * 2),
                    height: max(0, size.height - ShareCardPaceChartMath.linePadding * 2)
                )
                let path = ShareCardPaceChartMath.paceLinePath(samples: samples, in: rect)
                context.stroke(
                    path,
                    with: .color(RecapPalette.brand),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: chartSize.width, height: chartSize.height)
    }
}
