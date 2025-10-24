import SwiftUI

/// Radar Chart View - 雷達圖
struct RadarChartView: View {
    let metrics: [RadarMetric]
    let size: CGFloat

    struct RadarMetric {
        let label: String
        let value: Double  // 0-100
        let color: Color
    }

    var body: some View {
        ZStack {
            // Background grid
            radarGrid

            // Data polygon
            dataPolygon

            // Center dot
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 4, height: 4)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Radar Grid
    private var radarGrid: some View {
        ZStack {
            // Concentric circles (20%, 40%, 60%, 80%, 100%)
            ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                Path { path in
                    let radius = (size / 2) * scale
                    let center = CGPoint(x: size / 2, y: size / 2)
                    path.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }

            // Axis lines
            ForEach(0..<metrics.count, id: \.self) { index in
                Path { path in
                    let angle = angleForIndex(index)
                    let center = CGPoint(x: size / 2, y: size / 2)
                    let endPoint = pointOnCircle(center: center, radius: size / 2, angle: angle)
                    path.move(to: center)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
        }
    }

    // MARK: - Data Polygon
    private var dataPolygon: some View {
        ZStack {
            // Filled area
            Path { path in
                guard !metrics.isEmpty else { return }

                let center = CGPoint(x: size / 2, y: size / 2)
                let maxRadius = size / 2

                for (index, metric) in metrics.enumerated() {
                    let angle = angleForIndex(index)
                    let normalizedValue = min(max(metric.value / 100.0, 0), 1)
                    let radius = maxRadius * normalizedValue
                    let point = pointOnCircle(center: center, radius: radius, angle: angle)

                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                path.closeSubpath()
            }
            .fill(Color.blue.opacity(0.2))

            // Border line
            Path { path in
                guard !metrics.isEmpty else { return }

                let center = CGPoint(x: size / 2, y: size / 2)
                let maxRadius = size / 2

                for (index, metric) in metrics.enumerated() {
                    let angle = angleForIndex(index)
                    let normalizedValue = min(max(metric.value / 100.0, 0), 1)
                    let radius = maxRadius * normalizedValue
                    let point = pointOnCircle(center: center, radius: radius, angle: angle)

                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                path.closeSubpath()
            }
            .stroke(Color.blue, lineWidth: 2)

            // Data points
            ForEach(0..<metrics.count, id: \.self) { index in
                let metric = metrics[index]
                let angle = angleForIndex(index)
                let center = CGPoint(x: size / 2, y: size / 2)
                let normalizedValue = min(max(metric.value / 100.0, 0), 1)
                let radius = (size / 2) * normalizedValue
                let point = pointOnCircle(center: center, radius: radius, angle: angle)

                Circle()
                    .fill(metric.color)
                    .frame(width: 6, height: 6)
                    .position(point)
            }
        }
    }

    // MARK: - Helper Methods

    /// Calculate angle for metric index (starting from top, clockwise)
    private func angleForIndex(_ index: Int) -> Double {
        let totalMetrics = Double(metrics.count)
        let anglePerMetric = 360.0 / totalMetrics
        // Start from top (-90 degrees) and go clockwise
        return -90.0 + (anglePerMetric * Double(index))
    }

    /// Calculate point on circle given center, radius, and angle
    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let angleInRadians = angle * .pi / 180.0
        let x = center.x + radius * cos(angleInRadians)
        let y = center.y + radius * sin(angleInRadians)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview
#if DEBUG
struct RadarChartView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Example with 4 metrics
            RadarChartView(
                metrics: [
                    RadarChartView.RadarMetric(label: "速度", value: 88, color: .blue),
                    RadarChartView.RadarMetric(label: "耐力", value: 85, color: .green),
                    RadarChartView.RadarMetric(label: "比賽適能", value: 90, color: .purple),
                    RadarChartView.RadarMetric(label: "訓練負荷", value: 82, color: .orange)
                ],
                size: 120
            )
            .border(Color.gray)

            // Example with different values
            RadarChartView(
                metrics: [
                    RadarChartView.RadarMetric(label: "速度", value: 60, color: .blue),
                    RadarChartView.RadarMetric(label: "耐力", value: 95, color: .green),
                    RadarChartView.RadarMetric(label: "比賽適能", value: 70, color: .purple),
                    RadarChartView.RadarMetric(label: "訓練負荷", value: 85, color: .orange)
                ],
                size: 120
            )
            .border(Color.gray)
        }
        .padding()
    }
}
#endif
