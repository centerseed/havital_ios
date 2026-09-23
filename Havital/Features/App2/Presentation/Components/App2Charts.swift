import SwiftUI

struct App2ChartReadoutSelection: Equatable {
    let chartID: String
    let index: Int
}

struct App2ChartReadoutFrame: Equatable {
    let chartID: String
    let frame: CGRect
}

enum App2ChartReadoutDismissal {
    static func selection(
        afterTapAt location: CGPoint,
        current selection: App2ChartReadoutSelection?,
        chartFrames: [App2ChartReadoutFrame]
    ) -> App2ChartReadoutSelection? {
        guard let selection,
              let selectedChartFrame = chartFrames.first(where: { $0.chartID == selection.chartID }),
              selectedChartFrame.frame.contains(location) else {
            return nil
        }
        return selection
    }
}

private enum App2ChartReadoutSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<App2ChartReadoutSelection?> = .constant(nil)
}

extension EnvironmentValues {
    var app2ChartReadoutSelection: Binding<App2ChartReadoutSelection?> {
        get { self[App2ChartReadoutSelectionKey.self] }
        set { self[App2ChartReadoutSelectionKey.self] = newValue }
    }
}

enum App2ChartReadoutFramePreferenceKey: PreferenceKey {
    static let defaultValue: [App2ChartReadoutFrame] = []

    static func reduce(value: inout [App2ChartReadoutFrame], nextValue: () -> [App2ChartReadoutFrame]) {
        value.append(contentsOf: nextValue())
    }
}

enum App2ChartReadoutCoordinateSpace {
    static let name = "App2MetricDetailContent"
}

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
    /// 只在指標詳情頁開啟。紀錄頁與週回顧沿用預設關閉。
    var allowsReadout: Bool = false

    private let readoutID: String
    @Environment(\.app2ChartReadoutSelection) private var chartReadoutSelection
    @State private var gestureStarted = false
    @State private var gestureStartSelection: Int?
    @State private var gestureMoved = false
    @State private var plotRect: CGRect = .zero

    init(
        bars: [App2WeeklyBar],
        barHeight: CGFloat = 40,
        targetKm: Double? = nil,
        currentWeekTint: Color = App2Theme.accentBlue,
        showsValueLabels: Bool = true,
        allowsReadout: Bool = false,
        readoutID: String = "weekly-volume"
    ) {
        self.bars = bars
        self.barHeight = barHeight
        self.targetKm = targetKm
        self.currentWeekTint = currentWeekTint
        self.showsValueLabels = showsValueLabels
        self.allowsReadout = allowsReadout
        self.readoutID = readoutID
    }

    private var selectedIndex: Int? {
        guard let selection = chartReadoutSelection.wrappedValue,
              selection.chartID == readoutID else { return nil }
        return selection.index
    }

    private func setSelectedIndex(_ index: Int?) {
        if let index {
            chartReadoutSelection.wrappedValue = .init(chartID: readoutID, index: index)
        } else if chartReadoutSelection.wrappedValue?.chartID == readoutID {
            chartReadoutSelection.wrappedValue = nil
        }
    }

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
                if allowsReadout, let selectedIndex, bars.indices.contains(selectedIndex) {
                    let bar = bars[selectedIndex]
                    HStack(spacing: 6) {
                        Text(bar.shortLabel)
                        Text("\(App2NumberFormat.grouped(bar.distanceKm, maximumFractionDigits: 1)) km")
                            .fontWeight(.heavy)
                    }
                    .font(.app2Mono(10, weight: .semibold))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(App2Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(App2Theme.insetBorder, lineWidth: 1))
                    .accessibilityIdentifier("App2_WeeklyVolumeChartReadout")
                }

                barPlot
                xLabelRow
            }
            .coordinateSpace(name: "weeklyVolumeChart")
            .simultaneousGesture(
                SpatialTapGesture().onEnded { tap in
                    if selectedIndex != nil && !plotRect.contains(tap.location) {
                        setSelectedIndex(nil)
                    }
                }
            )
            .accessibilityIdentifier("App2_WeeklyVolumeChart")
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: App2ChartReadoutFramePreferenceKey.self,
                        value: allowsReadout
                            ? [App2ChartReadoutFrame(
                                chartID: readoutID,
                                frame: geo.frame(in: .named(App2ChartReadoutCoordinateSpace.name))
                            )]
                            : []
                    )
                }
            }
        }
    }

    private var barPlot: some View {
        GeometryReader { geo in
            let spacing: CGFloat = bars.count > 10 ? 2 : 6
            let usableWidth = max(0, geo.size.width - spacing * CGFloat(max(bars.count - 1, 0)))
            let slotWidth = bars.isEmpty ? 0 : usableWidth / CGFloat(bars.count)
            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: spacing) {
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

                if allowsReadout, let selectedIndex, bars.indices.contains(selectedIndex) {
                    let bar = bars[selectedIndex]
                    let x = slotWidth * (CGFloat(selectedIndex) + 0.5)
                        + spacing * CGFloat(selectedIndex)
                    let barTop = geo.size.height - max(3, barHeight * bar.distanceKm / peak)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    .stroke(App2Theme.accentBlueDeep.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    Circle()
                        .fill(currentWeekTint)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: barTop)
                }

                if allowsReadout {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(readoutGesture(slotWidth: slotWidth, spacing: spacing))
                }
            }
            .onAppear { plotRect = geo.frame(in: .named("weeklyVolumeChart")) }
            .onChange(of: geo.frame(in: .named("weeklyVolumeChart"))) { _, frame in
                plotRect = frame
            }
        }
        .frame(height: barHeight + 14)
    }

    static func nearestBarIndex(
        atX x: CGFloat,
        slotWidth: CGFloat,
        spacing: CGFloat,
        count: Int
    ) -> Int? {
        guard count > 0, slotWidth > 0 else { return nil }
        return (0..<count).min { lhs, rhs in
            let lhsCenter = slotWidth * (CGFloat(lhs) + 0.5) + spacing * CGFloat(lhs)
            let rhsCenter = slotWidth * (CGFloat(rhs) + 0.5) + spacing * CGFloat(rhs)
            return abs(lhsCenter - x) < abs(rhsCenter - x)
        }
    }

    private func readoutGesture(slotWidth: CGFloat, spacing: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard allowsReadout, let index = Self.nearestBarIndex(
                    atX: gesture.location.x,
                    slotWidth: slotWidth,
                    spacing: spacing,
                    count: bars.count
                ) else { return }
                if !gestureStarted {
                    gestureStarted = true
                    gestureStartSelection = selectedIndex
                }
                if abs(gesture.translation.width) > 6 || abs(gesture.translation.height) > 6 {
                    gestureMoved = true
                }
                setSelectedIndex(index)
            }
            .onEnded { gesture in
                guard let index = Self.nearestBarIndex(
                    atX: gesture.location.x,
                    slotWidth: slotWidth,
                    spacing: spacing,
                    count: bars.count
                ) else { return }
                if !gestureMoved && gestureStartSelection == index {
                    setSelectedIndex(nil)
                }
                gestureStarted = false
                gestureStartSelection = nil
                gestureMoved = false
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
        /// 讀數框標籤；未提供時使用圖例字或序列 id。
        var readoutLabel: String?
        /// 讀數框單位（例如 `ms`、`bpm`）。比率與指數不填。
        var unit: String?
    }

    /// 一段水平的淡色區帶（§51-6 的負荷比甜區）。**上下界由呼叫端給**——
    /// 它是後端逐列交付的量（依訓練期變），不是圖表的知識。
    struct Band {
        /// nil 代表延伸到目前圖表可見範圍的邊緣。
        let lower: Double?
        let upper: Double?
        /// 帶子右上角的小字（`甜區 0.8–1.3`）。nil = 只畫帶子。
        var label: String?
        var tint: Color
        /// 圖例上的帶子意義；ACWR 甜區只用圖內標籤。
        var legendLabel: String?

        init(
            lower: Double?,
            upper: Double?,
            label: String? = nil,
            tint: Color,
            legendLabel: String? = nil
        ) {
            self.lower = lower
            self.upper = upper
            self.label = label
            self.tint = tint
            self.legendLabel = legendLabel
        }
    }

    let series: [Series]
    /// 圖上的 x 標籤（3 顆：最舊／中間／最新）。由呼叫端給，因為「今晨」「本週」
    /// 這種字是頁面語境，不是圖表的知識。
    var xLabels: [String] = []
    /// 淡色區帶。有限邊界會把 y 範圍撐開；nil 邊界延伸到可見範圍邊緣。
    /// **它會把 y 上下界撐開到看得見自己**：
    /// 一個 ACWR 全在 1.4 以上的人，甜區若被裁掉，那張圖就只剩一條沒有參照的線。
    var bands: [Band] = []
    /// 垂直 dashed 標記的日期（§52-3 的錨定線）。序列裡沒有這一天就不畫。
    var markerDate: String?
    /// 標記旁的註記（`指標跑錨定`）。
    var markerLabel: String?
    /// 水平 dashed 基準線的值；圖表依這些值擴大範圍，保證參考線可見。
    var baselineValues: [Double] = []
    var height: CGFloat = 132
    /// 只有指標詳情頁啟用圖上讀數。
    var allowsReadout: Bool = false
    /// 渲染測試或已知錨點可指定初始選中索引；一般呼叫點保持 nil。
    var initiallySelectedIndex: Int? = nil
    /// TSB 色帶圖例；ACWR 不顯示 band legend。
    var showsBandLegend: Bool = false

    private let readoutID: String
    @Environment(\.app2ChartReadoutSelection) private var chartReadoutSelection
    @State private var gestureStarted = false
    @State private var gestureStartSelection: Int?
    @State private var gestureMoved = false
    @State private var plotRect: CGRect = .zero

    init(
        series: [Series],
        xLabels: [String] = [],
        bands: [Band] = [],
        markerDate: String? = nil,
        markerLabel: String? = nil,
        baselineValues: [Double] = [],
        showsBandLegend: Bool = false,
        allowsReadout: Bool = false,
        initiallySelectedIndex: Int? = nil,
        height: CGFloat = 132,
        readoutID: String = "metric-line"
    ) {
        self.series = series
        self.xLabels = xLabels
        self.bands = bands
        self.markerDate = markerDate
        self.markerLabel = markerLabel
        self.baselineValues = baselineValues
        self.height = height
        self.allowsReadout = allowsReadout
        self.initiallySelectedIndex = initiallySelectedIndex
        self.showsBandLegend = showsBandLegend
        self.readoutID = readoutID
    }

    private var selectedIndex: Int? {
        guard let selection = chartReadoutSelection.wrappedValue,
              selection.chartID == readoutID else { return nil }
        return selection.index
    }

    private func setSelectedIndex(_ index: Int?) {
        if let index {
            chartReadoutSelection.wrappedValue = .init(chartID: readoutID, index: index)
        } else if chartReadoutSelection.wrappedValue?.chartID == readoutID {
            chartReadoutSelection.wrappedValue = nil
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            if allowsReadout, let selectedIndex, readoutDate(at: selectedIndex) != nil {
                readout(for: selectedIndex)
            }
            HStack(alignment: .top, spacing: 8) {
                yAxis(series.first, overrideBounds: primaryBounds)
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
        .coordinateSpace(name: "metricChart")
        .simultaneousGesture(
            SpatialTapGesture().onEnded { tap in
                if selectedIndex != nil && !plotRect.contains(tap.location) {
                    setSelectedIndex(nil)
                }
            }
        )
        .accessibilityIdentifier("App2_MetricLineChart")
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: App2ChartReadoutFramePreferenceKey.self,
                    value: allowsReadout
                        ? [App2ChartReadoutFrame(
                            chartID: readoutID,
                            frame: geo.frame(in: .named(App2ChartReadoutCoordinateSpace.name))
                        )]
                        : []
                )
            }
        }
        .onAppear {
            if allowsReadout, chartReadoutSelection.wrappedValue == nil,
               let initiallySelectedIndex {
                setSelectedIndex(initiallySelectedIndex)
            }
        }
    }

    // MARK: - 刻度

    /// 三顆刻度（最高／中間／最低）。每條線各有自己的量綱，所以刻度綁的是那條線。
    /// 第一條線的上下界（含區帶）。其餘線各自算自己的，不吃區帶。
    private var primaryBounds: (lower: Double, upper: Double)? {
        Self.bounds(series.first?.points ?? [], including: bands, referenceValues: baselineValues)
    }

    @ViewBuilder
    private func yAxis(
        _ line: Series?,
        alignment: HorizontalAlignment = .trailing,
        tint: Color? = nil,
        overrideBounds: (lower: Double, upper: Double)? = nil
    ) -> some View {
        if let bounds = overrideBounds ?? Self.bounds(line?.points ?? []) {
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
                bandLayer(in: geo.size)

                if let bounds = primaryBounds {
                    ForEach(baselineValues, id: \.self) { value in
                        let y = Self.y(value, in: bounds, height: geo.size.height)
                        App2DashedLine()
                            .stroke(App2Theme.shadowInk.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: geo.size.width, height: 1)
                            .offset(y: y)
                    }
                }

                marker(in: geo.size)

                ForEach(series) { line in
                    // 歷史段（實線）與預估段（虛線）共用**同一份 points 的座標系**：
                    // 各自用自己的陣列畫，x 間距與 y 上下界都會跑掉。
                    let lineBounds = line.id == series.first?.id ? primaryBounds : nil
                    Self.path(line.points, in: geo.size, range: Self.historyRange(line),
                              bounds: lineBounds)
                        .stroke(line.tint,
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    if let projectedRange = Self.projectedRange(line) {
                        Self.path(line.points, in: geo.size, range: projectedRange,
                                  bounds: lineBounds)
                            .stroke(line.tint.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round,
                                                       lineJoin: .round, dash: [5, 4]))
                    }

                    pointMarks(for: line, in: geo.size, bounds: lineBounds)
                }

                selectionLayer(in: geo.size)

                if allowsReadout {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(readoutGesture(width: geo.size.width))
                }
            }
            .onAppear { plotRect = geo.frame(in: .named("metricChart")) }
            .onChange(of: geo.frame(in: .named("metricChart"))) { _, frame in
                plotRect = frame
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

    /// 淡色區帶（§51-6 的負荷比甜區）：一塊填色 ＋ 右上角一顆小字。
    ///
    /// 上下界永遠在 `primaryBounds` 之內（`bounds(_:including:)` 已把它撐進去），
    /// 所以這裡不必再裁 —— 裁掉的帶子就是一塊看不出邊界在哪的色塊。
    @ViewBuilder
    private func bandLayer(in size: CGSize) -> some View {
        if let bounds = primaryBounds {
            ZStack(alignment: .topTrailing) {
                ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                    let lower = max(bounds.lower, band.lower ?? bounds.lower)
                    let upper = min(bounds.upper, band.upper ?? bounds.upper)
                    if upper > lower {
                        let top = Self.y(upper, in: bounds, height: size.height)
                        let bottom = Self.y(lower, in: bounds, height: size.height)
                        Rectangle()
                            .fill(band.tint.opacity(0.10))
                            .frame(width: size.width, height: max(1, bottom - top))
                            .offset(y: top)
                    }
                }
                if let band = bands.first(where: { $0.label != nil }),
                   let label = band.label,
                   let upper = band.upper {
                    let top = Self.y(upper, in: bounds, height: size.height)
                    Text(label)
                        .font(.app2Mono(9, weight: .semibold))
                        .foregroundStyle(band.tint.app2Darkened)
                        .offset(x: -2, y: max(0, top - 11))
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .accessibilityIdentifier("App2_MetricChartBands")
        }
    }

    @ViewBuilder
    private func pointMarks(for line: Series, in size: CGSize, bounds overrideBounds: (lower: Double, upper: Double)?) -> some View {
        if let bounds = overrideBounds ?? Self.bounds(line.points) {
            ForEach(line.points.indices, id: \.self) { index in
                if let value = line.points[index].value {
                    Circle()
                        .fill(line.tint)
                        .frame(width: 4, height: 4)
                        .position(
                            x: Self.x(at: index, count: line.points.count, width: size.width),
                            y: Self.y(value, in: bounds, height: size.height)
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func selectionLayer(in size: CGSize) -> some View {
        if allowsReadout,
           let selectedIndex,
           let axis = series.first?.points,
           axis.indices.contains(selectedIndex) {
            let x = Self.x(at: selectedIndex, count: axis.count, width: size.width)
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            .stroke(App2Theme.accentBlueDeep.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            ForEach(series) { line in
                if line.points.indices.contains(selectedIndex),
                   let value = line.points[selectedIndex].value,
                   let bounds = line.id == series.first?.id ? primaryBounds : Self.bounds(line.points) {
                    Circle()
                        .fill(line.tint)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .position(
                            x: x,
                            y: Self.y(value, in: bounds, height: size.height)
                        )
                }
            }
        }
    }

    private func readout(for index: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let date = readoutDate(at: index) {
                Text(date)
                    .font(.app2Mono(10, weight: .bold))
                    .foregroundStyle(App2Theme.inkPrimary)
            }
            HStack(spacing: 10) {
                ForEach(Array(series.enumerated()), id: \.element.id) { entry in
                    let line = entry.element
                    let point = line.points.indices.contains(index) ? line.points[index] : nil
                    HStack(spacing: 4) {
                        Circle().fill(line.tint).frame(width: 6, height: 6)
                        Text(line.readoutLabel ?? line.id)
                            .foregroundStyle(App2Theme.inkSecondary)
                        if let value = point?.value {
                            Text(App2NumberFormat.grouped(value, maximumFractionDigits: 1)
                                 + (line.unit.map { " \($0)" } ?? ""))
                                .foregroundStyle(App2Theme.inkPrimary)
                        } else {
                            Text("—")
                                .foregroundStyle(App2Theme.inkTertiary)
                        }
                    }
                    .font(.app2Mono(10, weight: .semibold))
                }
            }
            if let projected = series.first(where: { line in
                line.points.indices.contains(index)
                    && line.points[index].value != nil
                    && line.projectedFromIndex.map { index >= $0 } == true
                    && line.projectedLegend != nil
            }), let label = projected.projectedLegend {
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(projected.tint.app2Darkened)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(projected.tint.opacity(0.12)))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(App2Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(App2Theme.insetBorder, lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("App2_MetricChartReadout")
    }

    private func readoutDate(at index: Int) -> String? {
        guard let points = series.first?.points, points.indices.contains(index) else { return nil }
        return points[index].date
    }

    private func readoutGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard allowsReadout,
                      let index = Self.nearestSelectableIndex(
                        atFraction: gesture.location.x / max(width, 1), series: series
                      ) else { return }
                if !gestureStarted {
                    gestureStarted = true
                    gestureStartSelection = selectedIndex
                }
                if abs(gesture.translation.width) > 6 || abs(gesture.translation.height) > 6 {
                    gestureMoved = true
                }
                setSelectedIndex(index)
            }
            .onEnded { gesture in
                guard let index = Self.nearestSelectableIndex(
                    atFraction: gesture.location.x / max(width, 1), series: series
                ) else { return }
                if !gestureMoved && gestureStartSelection == index {
                    setSelectedIndex(nil)
                }
                gestureStarted = false
                gestureStartSelection = nil
                gestureMoved = false
            }
    }

    static func nearestSelectableIndex(atFraction fraction: CGFloat, series: [Series]) -> Int? {
        guard let axis = series.first?.points, !axis.isEmpty else { return nil }
        let position = min(max(fraction, 0), 1) * CGFloat(max(axis.count - 1, 0))
        return axis.indices
            .filter { index in
                series.contains { line in
                    line.points.indices.contains(index) && line.points[index].value != nil
                }
            }
            .min { abs(CGFloat($0) - position) < abs(CGFloat($1) - position) }
    }

    private static func x(at index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return width * CGFloat(index) / CGFloat(count - 1)
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
        let bandItems = showsBandLegend ? bands.filter { $0.legendLabel != nil } : []
        if !items.isEmpty || projected != nil || !bandItems.isEmpty {
            HStack(spacing: 8) {
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
                ForEach(Array(bandItems.enumerated()), id: \.offset) { entry in
                    let band = entry.element
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(band.tint.opacity(0.3))
                            .frame(width: 9, height: 9)
                        Text(band.legendLabel ?? "")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(App2Theme.inkSecondary)
                    }
                    .accessibilityIdentifier("App2_MetricChartBandLegend_\(entry.offset)")
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 幾何（純函式）

    /// 一條線的上下界。全部一樣高時上下各撐 1，避免除以零把線畫到邊框上。
    ///
    /// 有限區帶端點與基準值會把座標範圍撐開，無限端由 bandLayer 裁到圖框邊緣。
    static func bounds(
        _ points: [App2MetricPoint],
        including bands: [Band] = [],
        referenceValues: [Double] = []
    ) -> (lower: Double, upper: Double)? {
        var values = points.compactMap(\.value)
        values.append(contentsOf: bands.flatMap { [$0.lower, $0.upper].compactMap { $0 } })
        values.append(contentsOf: referenceValues)
        guard let min = values.min(), let max = values.max() else { return nil }
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
    static func path(
        _ points: [App2MetricPoint],
        in size: CGSize,
        range: ClosedRange<Int>? = nil,
        bounds overrideBounds: (lower: Double, upper: Double)? = nil
    ) -> Path {
        var path = Path()
        guard points.count >= 2, let bounds = overrideBounds ?? bounds(points) else { return path }
        let stepX = size.width / CGFloat(points.count - 1)
        let drawn = range ?? 0...(points.count - 1)
        guard drawn.lowerBound >= 0, drawn.upperBound < points.count,
              drawn.count >= 2 else { return path }
        var isDrawing = false
        for index in drawn {
            guard let value = points[index].value else {
                isDrawing = false
                continue
            }
            let position = CGPoint(x: CGFloat(index) * stepX,
                                   y: y(value, in: bounds, height: size.height))
            if isDrawing { path.addLine(to: position) } else { path.move(to: position) }
            isDrawing = true
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
            // **趟數是處方的趟數，不是畫出來的柱數**：柱數上限 10（那一格只有幾十 pt 寬），
            // 用柱數會讓 11 趟的課在同一張圖上寫「趟數 × 10 趟」＋「11 × 200m · 4:25/km」
            // （2026-09-06 創辦人第 11 週實機截圖）。
            let reps = bars.prescribedIntervalReps
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
            // 色塊直接相連（2026-09-01 使用者裁決：「因為空間關係，不同配速的
            // 色塊之間的間隔直接拿掉」）。間隔為 0 時每一塊都拿得到完整的
            // `widthWeight` 比例寬，窄塊比較有機會標得下配速。
            let spacing: CGFloat = 0
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
                .strokeBorder(App2Theme.strokeFaint, lineWidth: 1)
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
                    .fill(App2Theme.insetBorder)
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
        case .support:  return App2Theme.chartSupport
        }
    }

    /// 設計的塊是 `linear-gradient(180deg, 淺, 深)`。
    private func gradient(for kind: App2SessionStructureBar.Kind) -> LinearGradient {
        switch kind {
        case .steady:
            return LinearGradient(colors: [App2Theme.chartGreenLight, App2Theme.accentGreenBright],
                                  startPoint: .top, endPoint: .bottom)
        case .interval:
            return LinearGradient(colors: [App2Theme.chartOrangeLight, App2Theme.chartOrangeDeep],
                                  startPoint: .top, endPoint: .bottom)
        case .warmup:
            return LinearGradient(colors: [App2Theme.chartGreenSoftFrom, App2Theme.chartGreenSoftTo],
                                  startPoint: .top, endPoint: .bottom)
        case .support:
            return LinearGradient(colors: [App2Theme.chartSupport, App2Theme.chartSupport],
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
    /// 給了就在圖左畫三顆刻度（上/中/下，原始量綱；手繪家族的「圖外小字」慣例）。
    var tickFormatter: ((Double) -> String)?
    /// true = 域取 p5–p95、域外值夾到邊界。GPS 雜訊的瞬間慢點（暫停、失訊）
    /// 走 min/max 會把真實配速帶壓成平線（T-0356）。
    var usesRobustBounds: Bool = false

    var body: some View {
        // 域一次 render 只算一次，刻度與折線共用：robust 會 sort，算兩次就排兩次（T-0356）。
        let bounds = Self.bounds(points, robust: usesRobustBounds)
        return HStack(alignment: .top, spacing: 8) {
            if let tickFormatter, let bounds {
                yTicks(bounds, formatter: tickFormatter)
            }
            plot(bounds)
        }
    }

    private func plot(_ bounds: (lower: Double, upper: Double)?) -> some View {
        GeometryReader { geo in
            if let bounds {
                let normalized = Self.normalize(points, isInverted: isInverted, bounds: bounds)
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

    /// 圖外三顆小字，值來自 `tickValues`。
    private func yTicks(_ bounds: (lower: Double, upper: Double), formatter: (Double) -> String) -> some View {
        let values = Self.tickValues(bounds, isInverted: isInverted)
        return VStack(alignment: .trailing, spacing: 0) {
            Text(formatter(values[0]))
            Spacer(minLength: 0)
            Text(formatter(values[1]))
            Spacer(minLength: 0)
            Text(formatter(values[2]))
        }
        .font(.app2Mono(9, weight: .semibold))
        .foregroundStyle(App2Theme.inkFaint)
        .frame(height: height)
    }

    /// 刻度值，由上而下三顆、貼原始量綱。inverted（配速）時上＝快（小值）、
    /// 下＝慢（大值），與折線的視覺方向一致。永遠回三個值。
    static func tickValues(_ bounds: (lower: Double, upper: Double), isInverted: Bool) -> [Double] {
        let mid = (bounds.lower + bounds.upper) / 2
        return isInverted
            ? [bounds.lower, mid, bounds.upper]
            : [bounds.upper, mid, bounds.lower]
    }

    /// robust＝p5–p95。**兩個明文退回 min/max 的情況**（T-0356 決策）：
    /// 樣本 <20 時取百分位沒有意義；p5 == p95（大量等值＋離群值）時域會塌成一點，
    /// 折線畫不出來。兩者都退回 min/max，域外值仍由 `normalize` 夾到邊界。
    static func bounds(_ values: [Double], robust: Bool) -> (lower: Double, upper: Double)? {
        guard let min = values.min(), let max = values.max() else { return nil }
        if robust, values.count >= 20 {
            let sorted = values.sorted()
            let lower = sorted[Int(Double(sorted.count - 1) * 0.05)]
            let upper = sorted[Int(Double(sorted.count - 1) * 0.95)]
            if upper > lower { return (lower, upper) }
        }
        return (min, max)
    }

    /// 把原始值壓到 0…1（0 = 圖底、1 = 圖頂），域外值夾到邊界。
    /// 全部一樣高時回中線，不要除以零。
    static func normalize(_ values: [Double], isInverted: Bool, bounds: (lower: Double, upper: Double)) -> [Double] {
        let span = bounds.upper - bounds.lower
        guard span > 0 else { return values.map { _ in 0.5 } }
        return values.map { value in
            let clamped = Swift.min(Swift.max(value, bounds.lower), bounds.upper)
            let ratio = (clamped - bounds.lower) / span
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

    /// 換算在**畫的時候**做，所以這一格切換單位當場就換
    /// —— 詳情頁是 `fullScreenCover` 的 item，重投影換不掉已經遞進去的那一份
    /// （T-0366 外審第四輪 E03）。
    @ObservedObject private var unitManager = UnitManager.shared

    private let plotHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            plot
            climateRow
            legend
        }
    }

    /// 溫度補償列（2026-08-27 走查改版）。帶上的配速一律是**原始處方配速**，
    /// 這一列只講「天氣熱，每公里可以慢多少秒」——整句由投影層算好交進來。
    /// 沒有補償時整列不出現。
    ///
    /// 熱適應卡的完整說明（等級、體感溫度、建議時段）不受影響，仍在它自己那張卡。
    @ViewBuilder
    private var climateRow: some View {
        if let allowance = band.climateAllowanceLabel(unitManager.currentUnitSystem) {
            HStack(spacing: 5) {
                Image(systemName: "thermometer.sun.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(App2Theme.accentOrangeText)
                Text(allowance)
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(App2Theme.accentOrangeText)
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
                boundary(label: band.fastLabel(unitManager.currentUnitSystem), suffixKey: L10n.App2.Detail.paceBandFast.localized)
                Spacer(minLength: 0)
                centreBand
                Spacer(minLength: 0)
                boundary(label: band.slowLabel(unitManager.currentUnitSystem), suffixKey: L10n.App2.Detail.paceBandSlow.localized)
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

    /// 中央色帶 ＋ 白字配速 pill。色帶上下撐滿快／慢邊界之間 ——
    /// 它代表整段可接受配速區間，不是裝飾細帶（2026-08-27 走查裁決（r））。
    private var centreBand: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.16))
            Text(band.paceLabel(unitManager.currentUnitSystem) + " " + band.paceUnitLabel(unitManager.currentUnitSystem))
                .font(.app2Mono(14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(accent))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 5)
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
