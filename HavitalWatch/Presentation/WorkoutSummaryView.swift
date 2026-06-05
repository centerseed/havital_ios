import SwiftUI

struct WorkoutSummaryView: View {
    let meters: Double
    let seconds: Int
    let averageHeartRate: Double
    let recentSpeedMps: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            metric("總距離", WatchFormatting.distance(meters), color: .green)
            metric("總時間", WatchFormatting.time(seconds), color: .green)
            metric("均速", averagePace, color: .cyan)
            metric("均心率", "\(Int(averageHeartRate))", color: .red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(Color.black)
        .foregroundStyle(.white)
    }

    private var averagePace: String {
        guard meters > 1, seconds > 0 else {
            return WatchFormatting.pace(WatchFormatting.paceSecondsPerKm(speedMps: recentSpeedMps))
        }
        return WatchFormatting.pace(Int(Double(seconds) / (meters / 1000)))
    }

    private func metric(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
    }
}
