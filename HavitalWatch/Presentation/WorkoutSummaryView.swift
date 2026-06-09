import SwiftUI

struct WorkoutSummaryView: View {
    let meters: Double
    let seconds: Int
    let averageHeartRate: Double
    let recentSpeedMps: Double

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                completionHeader

                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        WatchMetric(label: String(localized: "watch.summary.distance"),
                                    value: WatchFormatting.distance(meters),
                                    valueColor: .white, valueSize: 26)
                        WatchMetric(label: String(localized: "watch.summary.time"),
                                    value: WatchFormatting.time(seconds),
                                    valueColor: .white, valueSize: 26)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        WatchMetric(label: String(localized: "watch.summary.pace"),
                                    value: averagePace,
                                    valueColor: WatchTheme.brand, valueSize: 26)
                        WatchMetric(label: String(localized: "watch.summary.hr"),
                                    value: "\(Int(averageHeartRate))",
                                    valueColor: WatchTheme.heartRate, valueSize: 26)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
        }
        .background(WatchTheme.ambientBackground)
        .foregroundStyle(.white)
    }

    private var completionHeader: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(WatchTheme.brand.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.brand)
            }
            Text(String(localized: "watch.summary.title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var averagePace: String {
        guard meters > 1, seconds > 0 else {
            return WatchFormatting.pace(WatchFormatting.paceSecondsPerKm(speedMps: recentSpeedMps))
        }
        return WatchFormatting.pace(Int(Double(seconds) / (meters / 1000)))
    }
}
