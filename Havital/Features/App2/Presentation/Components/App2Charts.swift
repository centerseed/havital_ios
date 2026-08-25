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
/// **不是趨勢圖**：橫軸是這一堂課的段落順序，不是時間。寬度＝該段的量佔比，
/// 高度＝強度。綠色寬塊＝穩定段（塊上標配速），橘色細柱＝間歇的衝刺趟，
/// 淺色矮塊＝暖身／組間／緩和。
///
/// **只有橘柱算「趟」**；穩定段、暖身、緩和都不計趟（否則「6 × 200m」會寫成 7 趟）。
/// **它要讀起來是「圖」，不是「控制項」**（2026-08-25 用戶退件）：原本單段課畫成一條
/// 滿版圓角綠塊＋置中大字配速，看起來就是一顆按鈕。照 frame-02 的圖表語彙改成：
///
/// 1. 外層淺色繪圖容器（`#f7f9fc`＝設計 frame-02 plot 的底色、圓角 12、細邊、內距）；
/// 2. 色塊**底對齊容器基線往上長**，高度是容器的 55–65%（間歇的橘柱滿高），上方留空；
/// 3. 塊角 5pt、只圓上緣；寬度照段落比例 —— 單段課占滿容器內寬但仍留左右內距；
/// 4. 配速小字白色標在塊內靠上（11pt），不是置中大字；
/// 5. 容器下方一條分隔線 ＋ 段落標註列（色點 ＋ `輕鬆（穩定）` ＋ 右側 `4.0 km · 7:17/km`）。
struct App2SessionStructureChart: View {
    let bars: [App2SessionStructureBar]
    /// 有分段表的日子圖只佔 96pt 寬，標註列在那個寬度裡只會被截斷 ——
    /// 那些資訊本來就已經在旁邊的分段表裡，不重複第二次。
    var showsNotes: Bool = true

    /// 繪圖區高度（設計 frame-02 的 plot 是 132px；今日卡是縮小版）。
    private let plotHeight: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 沒有衝刺段的課（輕鬆跑／長跑）就不寫趟數。
            let reps = bars.filter { $0.kind == .interval }.count
            if reps > 0 {
                Text(String(format: L10n.App2.Home.structureReps.localized, reps))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(App2Theme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 6)
            }

            plot
            notes
        }
        .accessibilityIdentifier("App2_SessionStructureChart")
    }

    // MARK: - 繪圖區
    //
    // **色塊一律從容器底線往上長。** 之前用 `ZStack` 疊背景帶，帶子靠負 padding 撐出
    // 容器寬度，把 ZStack 的固有高度撐大，色塊於是變成垂直置中浮著（2026-08-25 第二次退件）。
    // 現在只有一層 `GeometryReader`：高度由它決定，`alignment: .bottomLeading` 保證貼底。
    //
    // 背景也不再鋪三條強度帶 —— 在 78pt 高的小圖上，紅／橘兩條加起來占六成，整塊看起來是粉的。
    // 設計 frame-02 的 plot 底色本體就是 `#f7f9fc`，帶子是 132pt 大圖才撐得住的細節。

    private var plot: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let totalWeight = max(bars.reduce(0) { $0 + $1.widthWeight }, 0.001)
            let usable = max(geo.size.width - spacing * CGFloat(max(bars.count - 1, 0)), 1)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(bars) { bar in
                    let width = usable * CGFloat(bar.widthWeight / totalWeight)
                    UnevenRoundedRectangle(
                        topLeadingRadius: 5, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 5,
                        style: .continuous
                    )
                    .fill(gradient(for: bar.kind))
                    .frame(width: width, height: max(4, geo.size.height * bar.height))
                    .overlay(alignment: .top) {
                        // 配速標在塊內、靠上（設計 frame-02 是 `top:7px`）。
                        // 窄塊放不下就不標 —— 不縮到看不清。
                        if let pace = bar.paceLabel, width >= 34 {
                            Text(pace)
                                .font(.app2Mono(11, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
                                .padding(.top, 5)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
        }
        .frame(height: plotHeight)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        // 底部不留內距：色塊坐在容器底線上（設計 frame-02 的 plot 是 `padding:10px 12px 0`）。
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "#0F172A").opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 段落標註列

    /// 一段一列，重複的名稱只出現一次（間歇的十根柱共用一列）。
    private var noteRows: [App2SessionStructureBar] {
        var seen = Set<String>()
        return bars.filter { bar in
            guard let label = bar.noteLabel else { return false }
            return seen.insert(label).inserted
        }
    }

    @ViewBuilder
    private var notes: some View {
        let rows = showsNotes ? noteRows : []
        if !rows.isEmpty {
            VStack(spacing: 4) {
                ForEach(rows) { row in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color(for: row.kind))
                            .frame(width: 9, height: 9)
                        Text(row.noteLabel ?? "")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(color(for: row.kind).app2Darkened)
                        Spacer(minLength: 8)
                        if let detail = row.noteDetail {
                            Text(detail)
                                .font(.app2Mono(12, weight: .semibold))
                                .foregroundStyle(App2Theme.inkSubtle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(hex: "#0F172A").opacity(0.06))
                    .frame(height: 1)
            }
            .padding(.top, 2)
        }
    }

    private func color(for kind: App2SessionStructureBar.Kind) -> Color {
        switch kind {
        case .steady:   return App2Theme.accentGreenBright
        case .interval: return App2Theme.accentOrangeBright
        case .support:  return Color(hex: "#CFD6DF")
        }
    }

    /// 設計的塊是 `linear-gradient(180deg, 淺, 深)`。
    private func gradient(for kind: App2SessionStructureBar.Kind) -> LinearGradient {
        switch kind {
        case .steady:
            return LinearGradient(colors: [Color(hex: "#5BE08A"), Color(hex: "#22C55E")],
                                  startPoint: .top, endPoint: .bottom)
        case .interval:
            return LinearGradient(colors: [Color(hex: "#FB7A3C"), Color(hex: "#E8500F")],
                                  startPoint: .top, endPoint: .bottom)
        case .support:
            return LinearGradient(colors: [Color(hex: "#CFD6DF"), Color(hex: "#CFD6DF")],
                                  startPoint: .top, endPoint: .bottom)
        }
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

// MARK: - App2Sparkline
/// 訓練詳情的心率／配速走勢（設計 frame-15「趨勢圖」的那兩張面積折線）。
///
/// 資料是 `WorkoutDetailViewModelV2` 已經降採樣好的 `[DataPoint]`（同一支 VM 餵
/// 1.4 的 Swift Charts 圖表），這裡不重新抽樣、不重新換算單位——只是把同一組值
/// 畫成設計稿那個尺寸的縮圖。折線圖只有一種，所以心率與配速共用這一支。
///
/// 配速要 `isInverted`：配速數字越小越快，直接畫會讓「變快」看起來像往下掉。
struct App2Sparkline: View {
    let points: [Double]
    let tint: Color
    /// true = 值越小畫越高（配速）。
    var isInverted: Bool = false
    var height: CGFloat = 72

    var body: some View {
        GeometryReader { geo in
            let normalized = Self.normalize(points, isInverted: isInverted)
            if normalized.count >= 2 {
                let line = Self.path(normalized, in: geo.size)
                ZStack {
                    Self.filled(normalized, in: geo.size)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.26), tint.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    line.stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(App2Theme.shadowInk.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    /// 把原始值壓到 0…1（0 = 圖底、1 = 圖頂）。全部一樣高時回中線，不要除以零。
    static func normalize(_ values: [Double], isInverted: Bool) -> [Double] {
        guard let min = values.min(), let max = values.max() else { return [] }
        let span = max - min
        guard span > 0 else { return values.map { _ in 0.5 } }
        return values.map { value in
            let ratio = (value - min) / span
            return isInverted ? 1 - ratio : ratio
        }
    }

    private static func points(_ normalized: [Double], in size: CGSize) -> [CGPoint] {
        let stepX = normalized.count > 1 ? size.width / CGFloat(normalized.count - 1) : 0
        // 上下各留 6pt，折線不要貼著邊框。
        let inset: CGFloat = 6
        let usable = max(1, size.height - inset * 2)
        return normalized.enumerated().map { index, value in
            CGPoint(x: CGFloat(index) * stepX, y: inset + usable * (1 - CGFloat(value)))
        }
    }

    private static func path(_ normalized: [Double], in size: CGSize) -> Path {
        var path = Path()
        let pts = points(normalized, in: size)
        guard let first = pts.first else { return path }
        path.move(to: first)
        for point in pts.dropFirst() { path.addLine(to: point) }
        return path
    }

    private static func filled(_ normalized: [Double], in size: CGSize) -> Path {
        var path = path(normalized, in: size)
        let pts = points(normalized, in: size)
        guard let first = pts.first, let last = pts.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}
