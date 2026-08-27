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
/// **§51-4（指標詳情 · 訓練量）用的是同一支**，只是多帶目標線與更高的繪圖區：
/// 首頁／紀錄頁的迷你版與詳情頁的大圖是同一個 producer、同一組柱子語意，
/// 分成兩支就是同一件事的第二份答案。差異全部走參數：
/// `barHeight`（繪圖區高）、`targetKm`（橘色 dashed 目標線）、`currentWeekTint`
/// （§51 的本週柱是橘的，首頁是藍的）。
struct App2WeeklyVolumeChart: View {
    let bars: [App2WeeklyBar]
    /// 繪圖區高度（首頁迷你版 40，§51 大圖 118）。
    var barHeight: CGFloat = 40
    /// 目標週跑量。有值才畫 dashed 線與標籤；nil = 不畫（不編一條假目標）。
    var targetKm: Double?
    /// 本週那根柱的顏色。
    var currentWeekTint: Color = App2Theme.accentBlue
    /// 柱頂的數字。週數多的時候（近 26 週）擠不下，呼叫端關掉。
    var showsValueLabels: Bool = true

    /// 柱高的分母：把目標線也算進去，否則目標高於所有柱子時線會畫到圖外。
    private var peak: Double { max(max(bars.map(\.distanceKm).max() ?? 0, targetKm ?? 0), 1) }

    var body: some View {
        if bars.isEmpty {
            Text(L10n.App2.Common.noData.localized)
                .font(.app2Caption)
                .foregroundStyle(App2Theme.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: 70)
        } else {
            VStack(spacing: 5) {
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: bars.count > 10 ? 2 : 6) {
                        ForEach(bars) { bar in
                            VStack(spacing: 4) {
                                Spacer(minLength: 0)
                                if showsValueLabels {
                                    Text(bar.distanceKm > 0 ? String(format: "%.0f", bar.distanceKm) : "0")
                                        .font(.app2Mono(9))
                                        .foregroundStyle(bar.isCurrentWeek
                                                         ? currentWeekTint.app2Darkened
                                                         : App2Theme.inkTertiary)
                                }
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(bar.isCurrentWeek
                                          ? currentWeekTint
                                          : App2Theme.accentBlue.opacity(0.32))
                                    // 最矮 3pt：全 0 的一週仍要看得到基線，不能整排消失。
                                    .frame(height: max(3, barHeight * bar.distanceKm / peak))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: barHeight + 14)

                    targetLine
                }

                xLabelRow
            }
            .accessibilityIdentifier("App2_WeeklyVolumeChart")
        }
    }

    /// x 軸標籤列。
    ///
    /// **柱子多的時候不能一格一個標籤**：26 根柱時每格只有十幾 pt 寬，`8/24`
    /// 會被折成三行（2026-08-26 模擬器實測）。所以超過 10 根就改成「頭・中・尾
    /// 三顆 ＋ Spacer」，每顆各自 `fixedSize` 不換行。
    @ViewBuilder
    private var xLabelRow: some View {
        if bars.count > 10 {
            let picked = [bars[0], bars[bars.count / 2], bars[bars.count - 1]]
            HStack(spacing: 4) {
                ForEach(Array(picked.enumerated()), id: \.offset) { index, bar in
                    Text(bar.shortLabel)
                        .font(.app2Mono(9, weight: .semibold))
                        .foregroundStyle(App2Theme.inkFaint)
                        .fixedSize()
                    if index < picked.count - 1 { Spacer(minLength: 4) }
                }
            }
        } else {
            HStack(spacing: 6) {
                ForEach(bars) { bar in
                    Text(bar.shortLabel)
                        .font(.app2Mono(9, weight: .semibold))
                        .foregroundStyle(App2Theme.inkFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// §51-4 的橘色 dashed 目標線 ＋ 右緣「目標 N」。
    @ViewBuilder
    private var targetLine: some View {
        if let targetKm, targetKm > 0 {
            let ratio = min(targetKm / peak, 1)
            HStack(spacing: 6) {
                App2DashedLine()
                    .stroke(App2Theme.accentOrange.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
                    .frame(height: 1)
                Text(String(format: L10n.App2.Metric.volumeTargetLineFormat.localized,
                            App2NumberFormat.grouped(targetKm)))
                    .font(.app2Mono(9, weight: .bold))
                    .foregroundStyle(App2Theme.accentOrangeText)
                    .fixedSize()
            }
            .padding(.bottom, barHeight * ratio)
            .accessibilityIdentifier("App2_WeeklyVolumeTargetLine")
        }
    }
}

// MARK: - App2DashedLine
/// 一條水平線（`Divider` 畫不出虛線）。目標線、基準線共用。
struct App2DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - App2MetricLineChart
/// 指標第二層的折線圖（checklist §52-3 VDOT 歷史、§53-2 HRV × 靜息心率雙線、
/// §51-6 TSB）。
///
/// **為什麼不接 1.4 既有的三張圖**：
/// - `VDOTChartView`（`Havital/Views/Components/VDOTChartView.swift:5`）與
///   `HRVTrendChartView`（`Havital/Views/Health/HRVTrendChartView.swift:4`）都自己
///   `@StateObject` 持有 ViewModel、自己去抓資料——傳不進 App2 這邊已經取好的序列；
///   後者更是直接讀 `HealthKitManager.shared`（`HealthKit → UI`，`AGENTS.md` 明令禁止）。
/// - `WeeklyVolumeChartView` 綁 `WeeklyVolumeManager.shared`（同檔頂端已記）。
/// - 三張都是 Swift Charts ＋ 1.4 的座標軸 chrome；2.0 的圖是零 chrome 的手繪家族
///   （刻度是圖外的三顆小字，不是 `AxisMarks`）。
///
/// 一支支援 1–2 條線：一條就是 VDOT／TSB，兩條就是 HRV × RHR（各自正規化，
/// 所以左右兩組刻度可以是完全不同的量綱）。
struct App2MetricLineChart: View {
    struct Series: Identifiable {
        let id: String
        let points: [App2MetricPoint]
        let tint: Color
        /// 圖例上的字（`HRV`／`RHR`）。nil = 不進圖例（單線圖不需要）。
        var legend: String?
        /// 從第幾點開始是**未來預估**（`points` 的索引）。這一段畫虛線＋降透明度，
        /// 與已經發生的歷史分開（2026-08-27 晚走查裁決（f）：VDOT 序列含建計畫時
        /// 生成的未來每日預估，畫成實線等於宣稱那些天已經量到了）。
        /// nil ＝整條都是歷史。
        var projectedFromIndex: Int?
        /// 虛線段的圖例字（`預估`）。
        var projectedLegend: String?
    }

    let series: [Series]
    /// 圖上的 x 標籤（3 顆：最舊／中間／最新）。由呼叫端給，因為「今晨」「本週」
    /// 這種字是頁面語境，不是圖表的知識。
    var xLabels: [String] = []
    /// 垂直 dashed 標記的日期（§52-3 的錨定線）。序列裡沒有這一天就不畫。
    var markerDate: String?
    /// 標記旁的註記（`指標跑錨定`）。
    var markerLabel: String?
    /// 水平 dashed 基準線的值（§51-6 的「TSB 0」），用第一條線的量綱。
    var baselineValue: Double?
    var baselineLabel: String?
    var height: CGFloat = 132

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                yAxis(series.first)
                plot
                // 兩條線各有自己的量綱（HRV 是 ms、RHR 是 bpm），所以**右邊要有
                // 第二組刻度**——沒有它，紅線就是一條沒有單位的裝飾（設計 §53-2
                // 明寫「雙 y 軸刻度」）。
                if series.count > 1 {
                    yAxis(series[1], alignment: .leading, tint: series[1].tint)
                }
            }
            xAxis
            legendRow
        }
        .accessibilityIdentifier("App2_MetricLineChart")
    }

    // MARK: - 刻度

    /// 三顆刻度（最高／中間／最低）。每條線各有自己的量綱，所以刻度綁的是那條線。
    @ViewBuilder
    private func yAxis(
        _ line: Series?,
        alignment: HorizontalAlignment = .trailing,
        tint: Color? = nil
    ) -> some View {
        if let bounds = Self.bounds(line?.points ?? []) {
            VStack(alignment: alignment, spacing: 0) {
                tick(bounds.upper, tint: tint)
                Spacer(minLength: 0)
                tick((bounds.upper + bounds.lower) / 2, tint: tint)
                Spacer(minLength: 0)
                tick(bounds.lower, tint: tint)
            }
            .frame(height: height)
        }
    }

    private func tick(_ value: Double, tint: Color?) -> some View {
        Text(App2NumberFormat.grouped(value, maximumFractionDigits: 1))
            .font(.app2Mono(9, weight: .semibold))
            .foregroundStyle(tint ?? App2Theme.inkFaint)
    }

    // MARK: - 繪圖區

    private var plot: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // 基準線落在資料範圍外就不畫：畫在框外只會多一條看不到的線
                // 與一顆飄在圖旁的標籤。
                if let baselineValue,
                   let bounds = Self.bounds(series.first?.points ?? []),
                   baselineValue >= bounds.lower, baselineValue <= bounds.upper {
                    let y = Self.y(baselineValue, in: bounds, height: geo.size.height)
                    App2DashedLine()
                        .stroke(App2Theme.shadowInk.opacity(0.28),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: geo.size.width, height: 1)
                        .offset(y: y)
                    if let baselineLabel {
                        Text(baselineLabel)
                            .font(.app2Mono(9, weight: .semibold))
                            .foregroundStyle(App2Theme.inkFaint)
                            .offset(x: 2, y: y - 12)
                    }
                }

                marker(in: geo.size)

                ForEach(series) { line in
                    // 歷史段（實線）與預估段（虛線）共用**同一份 points 的座標系**：
                    // 各自用自己的陣列畫，x 間距與 y 上下界都會跑掉。
                    Self.path(line.points, in: geo.size, range: Self.historyRange(line))
                        .stroke(line.tint,
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    if let projectedRange = Self.projectedRange(line) {
                        Self.path(line.points, in: geo.size, range: projectedRange)
                            .stroke(line.tint.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round,
                                                       lineJoin: .round, dash: [5, 4]))
                    }
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(App2Theme.insetBorder, lineWidth: 1)
        )
    }

    /// §52-3 的錨定標記：一條垂直 dashed 線 ＋ 圖上註記。
    @ViewBuilder
    private func marker(in size: CGSize) -> some View {
        if let markerDate,
           let points = series.first?.points,
           let index = points.firstIndex(where: { $0.date >= markerDate }),
           points.count > 1 {
            let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
            Rectangle()
                .fill(App2Theme.accentViolet.opacity(0.55))
                .frame(width: 1, height: size.height)
                .offset(x: x)
            if let markerLabel {
                Text(markerLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(App2Theme.accentViolet)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(App2Theme.accentViolet.opacity(0.12))
                    )
                    .fixedSize()
                    .offset(x: max(0, min(x - 20, size.width - 70)), y: 0)
            }
        }
    }

    // MARK: - x 軸與圖例

    @ViewBuilder
    private var xAxis: some View {
        if !xLabels.isEmpty {
            HStack {
                ForEach(Array(xLabels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.app2Mono(9, weight: .semibold))
                        .foregroundStyle(App2Theme.inkFaint)
                    if index < xLabels.count - 1 { Spacer(minLength: 4) }
                }
            }
        }
    }

    @ViewBuilder
    private var legendRow: some View {
        let items = series.filter { $0.legend != nil }
        // 有虛線段就一定要有「預估」chip —— 一條沒有標示的虛線讀不出它是什麼。
        let projected = series.first { $0.projectedLegend != nil && Self.projectedRange($0) != nil }
        if !items.isEmpty || projected != nil {
            HStack(spacing: 10) {
                ForEach(items) { line in
                    HStack(spacing: 5) {
                        Circle().fill(line.tint).frame(width: 7, height: 7)
                        Text(line.legend ?? "")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(line.tint.app2Darkened)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(line.tint.opacity(0.12)))
                }
                if let projected {
                    HStack(spacing: 5) {
                        App2DashedLine()
                            .stroke(projected.tint.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            .frame(width: 14, height: 2)
                        Text(projected.projectedLegend ?? "")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(projected.tint.app2Darkened)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(projected.tint.opacity(0.10)))
                    .accessibilityIdentifier("App2_MetricChartProjectedLegend")
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 幾何（純函式）

    /// 一條線的上下界。全部一樣高時上下各撐 1，避免除以零把線畫到邊框上。
    static func bounds(_ points: [App2MetricPoint]) -> (lower: Double, upper: Double)? {
        guard let min = points.map(\.value).min(), let max = points.map(\.value).max() else { return nil }
        guard max > min else { return (min - 1, max + 1) }
        let padding = (max - min) * 0.12
        return (min - padding, max + padding)
    }

    static func y(_ value: Double, in bounds: (lower: Double, upper: Double), height: CGFloat) -> CGFloat {
        let span = bounds.upper - bounds.lower
        guard span > 0 else { return height / 2 }
        return height * CGFloat(1 - (value - bounds.lower) / span)
    }

    /// 畫 `points[range]`，但 **x 間距與 y 上下界都用整條 `points` 算** ——
    /// 這樣實線段與虛線段接得起來。
    static func path(_ points: [App2MetricPoint], in size: CGSize, range: ClosedRange<Int>? = nil) -> Path {
        var path = Path()
        guard points.count >= 2, let bounds = bounds(points) else { return path }
        let stepX = size.width / CGFloat(points.count - 1)
        let drawn = range ?? 0...(points.count - 1)
        guard drawn.lowerBound >= 0, drawn.upperBound < points.count,
              drawn.count >= 2 else { return path }
        for index in drawn {
            let position = CGPoint(x: CGFloat(index) * stepX,
                                   y: y(points[index].value, in: bounds, height: size.height))
            if index == drawn.lowerBound { path.move(to: position) } else { path.addLine(to: position) }
        }
        return path
    }

    /// 實線段的索引範圍（`projectedFromIndex` ＝ 第一個未來點）。
    /// 沒有預估段＝整條（回 nil，`path` 自己補整段）。
    static func historyRange(_ line: Series) -> ClosedRange<Int>? {
        guard let start = line.projectedFromIndex, start < line.points.count else { return nil }
        guard start >= 2 else { return 0...0 }   // 歷史不足兩點：畫不出線
        return 0...(start - 1)
    }

    /// 虛線段的索引範圍。**含交界那一點**，不然兩段之間會缺一節。
    static func projectedRange(_ line: Series) -> ClosedRange<Int>? {
        guard let start = line.projectedFromIndex,
              start >= 0, start < line.points.count,
              line.points.count - start >= 2 else { return nil }
        return max(0, start - 1)...(line.points.count - 1)
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
        case .warmup:   return App2Theme.accentGreenBright
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
        case .warmup:
            return LinearGradient(colors: [Color(hex: "#7BD79C"), Color(hex: "#63C98A")],
                                  startPoint: .top, endPoint: .bottom)
        case .support:
            return LinearGradient(colors: [Color(hex: "#CFD6DF"), Color(hex: "#CFD6DF")],
                                  startPoint: .top, endPoint: .bottom)
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

// MARK: - App2SessionPaceBandChart
/// 單段勻速課的「配速帶」（設計 **frame-02c**，2026-08-26 裁決）。
///
/// 一段課的長條圖只有一根柱 —— 圖裡沒有任何「變化」可看。配速帶改成把同一組數字
/// 講成「你要落在這個窗裡」：上緣虛線＝快邊界、下緣虛線＝慢邊界、中央課型色橫帶上
/// 一顆白字配速 pill。
struct App2SessionPaceBandChart: View {
    let band: App2SessionPaceBand
    /// 課型主色（帶與 legend 都用它）。
    let accent: Color

    private let plotHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            plot
            climateRow
            footerRow
            legend
        }
    }

    /// 溫度補償列（2026-08-27 走查裁決（n））。帶上的配速已經是補償後的值，
    /// 這一列講清楚「已含溫度補償」並把**原始處方配速**再標一次 ——
    /// 裁決要的是兩個值同時可見。沒有補償時整列不出現。
    ///
    /// 熱適應卡的完整說明（等級、體感溫度、建議時段）不受影響，仍在它自己那張卡。
    @ViewBuilder
    private var climateRow: some View {
        if let adjustment = band.climateAdjustmentLabel {
            HStack(spacing: 5) {
                Image(systemName: "thermometer.sun.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(App2Theme.accentOrangeText)
                Text(L10n.App2.Detail.paceBandClimate.localized)
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(App2Theme.accentOrangeText)
                Text(verbatim: "· \(adjustment)")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
                if let original = band.originalPaceLabel {
                    Text(verbatim: "· "
                         + NSLocalizedString("climate.original_pace_title", comment: "")
                         + " \(original)\(band.paceUnitLabel)")
                        .font(.app2Mono(11.5, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityIdentifier("App2_SessionPaceBandClimate")
        }
    }

    // MARK: - 圖區

    private var plot: some View {
        ZStack {
            VStack(spacing: 0) {
                boundary(label: band.fastLabel, suffixKey: L10n.App2.Detail.paceBandFast.localized)
                Spacer(minLength: 0)
                centreBand
                Spacer(minLength: 0)
                boundary(label: band.slowLabel, suffixKey: L10n.App2.Detail.paceBandSlow.localized)
            }
            .padding(.vertical, 10)
        }
        .frame(height: plotHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(App2Theme.insetBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
        )
        .accessibilityIdentifier("App2_SessionPaceBand")
    }

    /// 快／慢邊界：一條虛線 ＋ 左上角的 `6:35 · 快`。
    private func boundary(label: String, suffixKey: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(label) · \(suffixKey)")
                .font(.app2Mono(11, weight: .semibold))
                .foregroundStyle(App2Theme.inkFaint)
            Line()
                .stroke(
                    App2Theme.shadowInk.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 中央橫帶 ＋ 白字配速 pill。
    private var centreBand: some View {
        ZStack {
            Capsule()
                .fill(accent.opacity(0.28))
                .frame(height: 8)
            Text(band.paceLabel + " " + band.paceUnitLabel)
                .font(.app2Mono(14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(accent))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 圖下三欄

    private var footerRow: some View {
        HStack(spacing: 8) {
            Text(L10n.App2.Detail.paceBandStart.localized + " 0.0")
                .font(.app2Mono(11, weight: .semibold))
                .foregroundStyle(App2Theme.inkFaint)
            Spacer(minLength: 4)
            Text(L10n.App2.Detail.paceBandHold.localized + " · "
                 + String(format: L10n.App2.Detail.paceBandWindow.localized, band.windowLabel))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(accent.app2Darkened)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            if let end = band.endKmLabel {
                Text(L10n.App2.Detail.paceBandEnd.localized + " \(end) km")
                    .font(.app2Mono(11, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
            }
        }
        .accessibilityIdentifier("App2_SessionPaceBandFooter")
    }

    private var legend: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 9, height: 9)
            Text(band.legendLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(App2Theme.inkTertiary)
        }
    }

    /// 一條水平線（`Divider` 畫不出虛線）。
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
