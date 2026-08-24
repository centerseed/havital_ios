import SwiftUI
import Charts

// MARK: - App2WeeklyVolumeChart
/// 近 8 週跑量長條圖（§3.6 第 3 列）。
///
/// **為什麼不用既有的 `WeeklyVolumeChartView`**：那支住在 `Havital/Legacy/`，資料
/// 硬綁 `WeeklyVolumeManager.shared`，來源是每週 summary（`WeeklySummaryItem`）。
/// 設計文件 §3.6 指定的 producer 是 `GET /v2/workouts/stats` 的 `weekly_series`
/// （T-0304 落地，語意在 `SPEC-workout-processing` §4.5）。接不同的 producer，
/// 不是同一個問題的第二份答案。
struct App2WeeklyVolumeChart: View {
    let bars: [App2WeeklyBar]

    var body: some View {
        if bars.isEmpty {
            Text(L10n.App2.Common.noData.localized)
                .font(.app2Caption)
                .foregroundStyle(App2Theme.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart(bars) { bar in
                BarMark(
                    x: .value("week", bar.shortLabel),
                    y: .value("km", bar.distanceKm)
                )
                .foregroundStyle(bar.isCurrentWeek ? App2Theme.accentBlue : App2Theme.accentBlue.opacity(0.35))
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(App2Theme.inkTertiary.opacity(0.2))
                    AxisValueLabel().font(.system(size: 9))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.system(size: 9))
                }
            }
            .frame(height: 140)
            .accessibilityIdentifier("App2_WeeklyVolumeChart")
        }
    }
}

// MARK: - App2TrajectoryChart
/// §3.1a 軌跡圖：實際線（pace_vdot 歷史）＋ 預估線（完賽預估兩端錨定內插）。
///
/// 兩條線目前都由 ViewModel 餵樣本序列 —— `pace_vdot` 歷史序列沒有 HTTP 出口，
/// §7-16 的序列輸出也還沒落地。畫面上掛 `App2StubBadge` 明示。
struct App2TrajectoryChart: View {
    struct Point: Identifiable {
        let id = UUID()
        let week: Int
        let value: Double
        let isProjected: Bool
    }

    let points: [Point]
    let currentWeek: Int?

    var body: some View {
        Chart {
            ForEach(points.filter { !$0.isProjected }) { point in
                LineMark(
                    x: .value("week", point.week),
                    y: .value("value", point.value),
                    series: .value("series", "actual")
                )
                .foregroundStyle(App2Theme.accentBlue)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            ForEach(points.filter { $0.isProjected }) { point in
                LineMark(
                    x: .value("week", point.week),
                    y: .value("value", point.value),
                    series: .value("series", "projected")
                )
                .foregroundStyle(App2Theme.accentBlue.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
            }
            if let currentWeek {
                RuleMark(x: .value("week", currentWeek))
                    .foregroundStyle(App2Theme.inkTertiary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(App2Theme.inkTertiary.opacity(0.15))
                AxisValueLabel().font(.system(size: 9))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.system(size: 9))
            }
        }
        .frame(height: 120)
        .accessibilityIdentifier("App2_TrajectoryChart")
    }
}
