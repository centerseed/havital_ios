import SwiftUI

// MARK: - App2WeeklyVolumeChart
/// 近 8 週跑量長條圖（§3.6 第 3 列；設計 frame-10 的 hero 卡下半）。
///
/// **為什麼不用 Swift Charts**：設計的形狀是「每根柱子頭上壓一個數字、柱高 54pt、
/// 上圓角 4pt、無座標軸、無格線」。Swift Charts 的 `BarMark` 給不了柱頂標籤與
/// 這種零 chrome 的版面（`chartYAxis(.hidden)` 之後仍留 plot area 邊距），
/// 手繪反而少一層對抗。
///
/// **為什麼不用既有的 `WeeklyVolumeChartView`**：那支住在 `Havital/Legacy/`，資料
/// 硬綁 `WeeklyVolumeManager.shared`，來源是每週 summary（`WeeklySummaryItem`）。
/// 設計文件 §3.6 指定的 producer 是 `GET /v2/workouts/stats` 的 `weekly_series`
/// （T-0304 落地，語意在 `SPEC-workout-processing` §4.5）。接不同的 producer，
/// 不是同一個問題的第二份答案。
struct App2WeeklyVolumeChart: View {
    let bars: [App2WeeklyBar]

    private var peak: Double { max(bars.map(\.distanceKm).max() ?? 0, 1) }

    var body: some View {
        if bars.isEmpty {
            Text(L10n.App2.Common.noData.localized)
                .font(.app2Caption)
                .foregroundStyle(App2Theme.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: 70)
        } else {
            VStack(spacing: 5) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(bars) { bar in
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            Text(bar.distanceKm > 0 ? String(format: "%.0f", bar.distanceKm) : "0")
                                .font(.app2Mono(9))
                                .foregroundStyle(bar.isCurrentWeek
                                                 ? App2Theme.accentBlueDeep
                                                 : App2Theme.inkTertiary)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(bar.isCurrentWeek
                                      ? App2Theme.accentBlue
                                      : App2Theme.accentBlue.opacity(0.32))
                                // 最矮 3pt：全 0 的一週仍要看得到基線，不能整排消失。
                                .frame(height: max(3, 40 * bar.distanceKm / peak))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 54)

                HStack(spacing: 6) {
                    ForEach(bars) { bar in
                        Text(bar.shortLabel)
                            .font(.app2Mono(9, weight: .semibold))
                            .foregroundStyle(App2Theme.inkFaint)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityIdentifier("App2_WeeklyVolumeChart")
        }
    }
}

// MARK: - App2SessionStructureChart
/// 今日課表卡右側的「趟數 × N 趟」結構預覽（設計 frame-00 下半，與 frame-02
/// 「預計配速」同一視覺家族）。
///
/// **不是趨勢圖**：橫軸是這一堂課的段落順序，不是時間。橘柱＝衝刺／主課那幾趟，
/// 淺色矮柱＝熱身、恢復、緩和。柱數由 payload 的 `repeats` 決定，畫不出結構
/// （只有一根柱）時呼叫端就不給資料，這裡也不會出現。
struct App2SessionStructureChart: View {
    let bars: [App2SessionStructureBar]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(format: L10n.App2.Home.structureReps.localized, bars.filter(\.isWork).count))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(App2Theme.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(bars) { bar in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            bar.isWork
                                ? App2Theme.accentOrangeBright
                                : App2Theme.accentBlue.opacity(0.28)
                        )
                        .frame(height: max(3, 34 * bar.height))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 34, alignment: .bottom)
        }
        .accessibilityIdentifier("App2_SessionStructureChart")
    }
}

// MARK: - App2TrajectoryChart
/// §3.1a 軌跡圖：實際線（pace_vdot 歷史，實線）＋ 預估線（虛線）＋ 三色容差帶
/// ＋「現在」錨線。設計 frame-00 的訓練狀況卡中段。
///
/// 三色帶是**呈現層推導**：以預估曲線為中心 ± 固定容差畫出「正常軌道」（綠），
/// 上方是「超乎預期」（藍）、下方是「落後」（橘）。沒有資料缺口 —— 缺的是
/// 序列本身（§7-16 無 HTTP 出口，畫面上掛 `App2StubBadge`）。
///
/// 手繪而非 Swift Charts：設計要的是無軸、無格線、帶區域填色與端點錨的圖，
/// 圖表框架在這種「插畫式」小圖上只會多一層要壓掉的預設 chrome。
struct App2TrajectoryChart: View {
    struct Point: Identifiable {
        let id = UUID()
        let week: Int
        let value: Double
        let isProjected: Bool
    }

    let points: [Point]
    let currentWeek: Int?

    private var actual: [Point] { points.filter { !$0.isProjected } }
    private var projected: [Point] { points.filter { $0.isProjected } }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let xs = points.map { Double($0.week) }
            let ys = points.map(\.value)
            let minX = xs.min() ?? 0
            let maxX = max(xs.max() ?? 1, minX + 1)
            let minY = (ys.min() ?? 0) - 3
            let maxY = max((ys.max() ?? 1) + 3, minY + 1)

            // ViewBuilder 不收巢狀 func 宣告，所以兩個座標轉換用 closure 綁定。
            let px: (Double) -> CGFloat = { week in
                CGFloat((week - minX) / (maxX - minX)) * size.width
            }
            let py: (Double) -> CGFloat = { value in
                size.height - CGFloat((value - minY) / (maxY - minY)) * size.height
            }

            // 容差帶：預估曲線 ± 圖高的 12%。
            let band = size.height * 0.12
            let spine = points.map { CGPoint(x: px(Double($0.week)), y: py($0.value)) }

            ZStack(alignment: .topLeading) {
                if spine.count > 1 {
                    zone(spine, from: -size.height, to: -band)
                        .fill(App2Theme.trackAhead.opacity(0.10))
                    zone(spine, from: -band, to: band)
                        .fill(App2Theme.trackOnTrack.opacity(0.16))
                    zone(spine, from: band, to: size.height)
                        .fill(App2Theme.trackBehind.opacity(0.12))

                    // 實際線下方的漸層面積。
                    areaPath(actual.map { CGPoint(x: px(Double($0.week)), y: py($0.value)) },
                             bottom: size.height)
                        .fill(
                            LinearGradient(
                                colors: [App2Theme.accentBlue.opacity(0.26), App2Theme.accentBlue.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(projected.map { CGPoint(x: px(Double($0.week)), y: py($0.value)) })
                        .stroke(
                            App2Theme.accentBlue.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
                        )

                    linePath(actual.map { CGPoint(x: px(Double($0.week)), y: py($0.value)) })
                        .stroke(
                            App2Theme.accentBlueDeep,
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                        )
                }

                if let last = projected.last {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().strokeBorder(App2Theme.accentBlue.opacity(0.6), lineWidth: 2))
                        .frame(width: 9, height: 9)
                        .position(x: px(Double(last.week)), y: py(last.value))
                }

                if let now = actual.last {
                    Rectangle()
                        .fill(App2Theme.shadowInk.opacity(0.1))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .position(x: px(Double(now.week)), y: size.height / 2)
                    Circle()
                        .fill(App2Theme.accentBlueDeep)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                        .frame(width: 11, height: 11)
                        .position(x: px(Double(now.week)), y: py(now.value))
                    Text(L10n.App2.Home.chartNow.localized)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(App2Theme.accentBlueDeep)
                        .offset(x: px(Double(now.week)) + 5, y: 6)
                }
            }
        }
        .frame(height: 88)
        // 三色帶是「沿脊線上下平移一整個圖高」畫出來的，一定會溢出畫布 —— 要裁掉，
        // 否則會整片糊到卡片外面（2026-08-25 模擬器實跑看到的就是這個）。
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(App2Theme.insetBorder, lineWidth: 1)
        )
        .accessibilityIdentifier("App2_TrajectoryChart")
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for point in pts.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func areaPath(_ pts: [CGPoint], bottom: CGFloat) -> Path {
        var path = linePath(pts)
        guard let first = pts.first, let last = pts.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: bottom))
        path.addLine(to: CGPoint(x: first.x, y: bottom))
        path.closeSubpath()
        return path
    }

    /// 沿脊線平移出的一條帶（上緣 `from`、下緣 `to`，值是相對脊線的位移）。
    private func zone(_ spine: [CGPoint], from: CGFloat, to: CGFloat) -> Path {
        var path = Path()
        guard let first = spine.first else { return path }
        path.move(to: CGPoint(x: first.x, y: first.y + from))
        for point in spine.dropFirst() { path.addLine(to: CGPoint(x: point.x, y: point.y + from)) }
        for point in spine.reversed() { path.addLine(to: CGPoint(x: point.x, y: point.y + to)) }
        path.closeSubpath()
        return path
    }
}

// MARK: - App2TrajectoryLegend
/// 軌跡圖底下的圖例列：`— 實際`／`- - 預估` … `第 5 / 22 週`。
struct App2TrajectoryLegend: View {
    let currentWeek: Int?
    let totalWeeks: Int?

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Capsule().fill(App2Theme.accentBlueDeep).frame(width: 14, height: 2.5)
                Text(L10n.App2.Home.chartActual.localized)
            }
            HStack(spacing: 5) {
                Line().stroke(
                    App2Theme.accentBlue.opacity(0.6),
                    style: StrokeStyle(lineWidth: 2, dash: [3, 2])
                )
                .frame(width: 14, height: 2)
                Text(L10n.App2.Home.chartForecast.localized)
            }
            Spacer()
            if let currentWeek, let totalWeeks {
                Text(String(format: L10n.App2.Home.weekProgress.localized, currentWeek, totalWeeks))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.inkFaint)
            }
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(App2Theme.inkTertiary)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
