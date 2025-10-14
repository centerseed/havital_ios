import SwiftUI

/// Trend Chart View - Displays trend line for Training Readiness metrics
/// Shows a sparkline-style chart with color based on trend direction
struct TrendChartView: View {
    let trendData: TrendData?
    let color: Color

    // Chart dimensions (height only, width is flexible)
    private let chartHeight: CGFloat = 60

    var body: some View {
        if let data = trendData, data.isValid {
            // Valid trend data - draw chart with filled area
            GeometryReader { geometry in
                ZStack {
                    // Filled area under the curve
                    Path { path in
                        drawFilledArea(in: &path, data: data, size: geometry.size)
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                trendColor(for: data).opacity(0.3),
                                trendColor(for: data).opacity(0.05)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Smooth curve line
                    Path { path in
                        drawSmoothCurve(in: &path, data: data, size: geometry.size)
                    }
                    .stroke(trendColor(for: data), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: chartHeight)
        } else {
            // No data or invalid - show placeholder
            placeholderView
        }
    }

    // MARK: - Trend Line Drawing

    /// Calculate normalized points for the data
    private func calculatePoints(data: TrendData, size: CGSize) -> [CGPoint] {
        let values = data.values
        guard values.count >= 2 else { return [] }

        // Calculate min/max for scaling
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let valueRange = maxValue - minValue

        // Prevent division by zero
        guard valueRange > 0 else {
            let y = size.height / 2
            return values.enumerated().map { index, _ in
                let x = CGFloat(index) * (size.width / CGFloat(values.count - 1))
                return CGPoint(x: x, y: y)
            }
        }

        // Calculate points with 20% padding on top and bottom
        let padding: CGFloat = 0.2
        let effectiveHeight = size.height * (1 - 2 * padding)
        let topPadding = size.height * padding

        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalizedValue = (value - minValue) / valueRange
            let y = topPadding + (1 - normalizedValue) * effectiveHeight
            return CGPoint(x: x, y: y)
        }
    }

    /// Draw smooth curve using quadratic bezier curves
    private func drawSmoothCurve(in path: inout Path, data: TrendData, size: CGSize) {
        let points = calculatePoints(data: data, size: size)
        guard points.count >= 2 else { return }

        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
        } else {
            for i in 0..<points.count - 1 {
                let current = points[i]
                let next = points[i + 1]

                // Calculate control point for smooth curve
                let midX = (current.x + next.x) / 2
                let midY = (current.y + next.y) / 2

                if i == 0 {
                    path.addQuadCurve(to: midPoint(p1: current, p2: next), control: current)
                }

                path.addQuadCurve(to: next, control: midPoint(p1: current, p2: next))
            }
        }
    }

    /// Draw filled area under the curve
    private func drawFilledArea(in path: inout Path, data: TrendData, size: CGSize) {
        let points = calculatePoints(data: data, size: size)
        guard points.count >= 2 else { return }

        path.move(to: CGPoint(x: points[0].x, y: size.height))
        path.addLine(to: points[0])

        // Draw the curve
        if points.count == 2 {
            path.addLine(to: points[1])
        } else {
            for i in 0..<points.count - 1 {
                let current = points[i]
                let next = points[i + 1]

                if i == 0 {
                    path.addQuadCurve(to: midPoint(p1: current, p2: next), control: current)
                }

                path.addQuadCurve(to: next, control: midPoint(p1: current, p2: next))
            }
        }

        // Close the path at bottom
        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
        path.closeSubpath()
    }

    /// Calculate midpoint between two points
    private func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }

    // MARK: - Colors

    /// Get color based on metric color (always use the metric's color)
    private func trendColor(for data: TrendData) -> Color {
        return color  // Always use the metric's own color
    }

    // MARK: - Placeholder View

    /// Placeholder when no data available
    private var placeholderView: some View {
        ZStack {
            // Gray horizontal line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 2)
                .padding(.horizontal, 10)
        }
        .frame(height: chartHeight)
    }
}

// MARK: - Preview
// Note: Color(hex:) extension is defined in Theme/AppTheme.swift

#if DEBUG
struct TrendChartView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Upward trend
            TrendChartView(
                trendData: TrendData(
                    values: [70, 72, 75, 78, 82, 85, 88],
                    dates: ["10-01", "10-03", "10-05", "10-07", "10-09", "10-11", "10-13"],
                    direction: "up"
                ),
                color: .blue
            )
            .border(Color.gray)

            // Downward trend
            TrendChartView(
                trendData: TrendData(
                    values: [85, 83, 80, 78, 75, 73, 70],
                    dates: ["10-01", "10-03", "10-05", "10-07", "10-09", "10-11", "10-13"],
                    direction: "down"
                ),
                color: .blue
            )
            .border(Color.gray)

            // Stable trend
            TrendChartView(
                trendData: TrendData(
                    values: [80, 81, 79, 80, 82, 79, 80],
                    dates: ["10-01", "10-03", "10-05", "10-07", "10-09", "10-11", "10-13"],
                    direction: "stable"
                ),
                color: .blue
            )
            .border(Color.gray)

            // No data (placeholder)
            TrendChartView(
                trendData: nil,
                color: .blue
            )
            .border(Color.gray)
        }
        .padding()
    }
}
#endif
