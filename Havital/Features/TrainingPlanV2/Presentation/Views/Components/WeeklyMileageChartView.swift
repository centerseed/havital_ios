import SwiftUI
import Charts

// MARK: - WeeklyMileageChartView
//
// 週跑量曲線圖 — 放在計畫總覽（TrainingOverviewV2View）階段路線圖下方。
//
// 資料來源：viewModel.loader.weeklyPreview（WeeklyPreviewV2 entity）
//
// 單位處理（重要）：
//   backend `convert_weekly_preview_to_imperial` 只轉 target_km → target_km_display，
//   long_run.max_km / safety_ceiling_km / race_threshold_km 一律仍是 km。
//   因此本 View 統一把「非 target」的公里值餵給 chartUnit.convertedDistance，
//   確保同一 y 軸只有一種單位。**係數本身住 `UnitSystem`**（T-0366），這裡不留第二份。
//
// Additive 契約：safetyCeilingKm / raceThresholdKm / longRunKm 都是 optional，
// 舊 response 解不到 → nil → 該線／該點不畫，圖其餘部分正常。

struct WeeklyMileageChartView: View {

    let preview: WeeklyPreviewV2

    // MARK: - Derived Data

    private var weeks: [WeekPreview] {
        preview.weeks.sorted { $0.week < $1.week }
    }

    /// 顯示單位（"km" / "mi"）；backend 公制時 distanceUnit 為 nil
    private var unitLabel: String {
        weeks.first?.distanceUnit ?? "km"
    }

    /// y 軸的單位制。**跟著 backend 給的 `distanceUnit` 走**（不是 app 設定）——
    /// `targetKmDisplay` 已經是那個單位換好的值，其餘欄位還是 km，兩者要對齊。
    private var chartUnit: UnitSystem {
        unitLabel == "mi" ? .imperial : .metric
    }

    /// 每週跑量（已是顯示單位）
    private func mileage(_ week: WeekPreview) -> Double {
        week.targetKmDisplay ?? week.targetKm
    }

    /// 長跑距離（km → 顯示單位）；nil 的週跳過
    private func longRun(_ week: WeekPreview) -> Double? {
        week.longRunKm.map(chartUnit.convertedDistance)
    }

    /// 是否有任何一週帶長跑距離（舊資料全缺 → 不畫線也不列圖例）
    private var hasLongRunSeries: Bool {
        weeks.contains { $0.longRunKm != nil }
    }

    private var raceThreshold: Double? {
        preview.raceThresholdKm.map(chartUnit.convertedDistance)
    }

    private var safetyCeiling: Double? {
        preview.safetyCeilingKm.map(chartUnit.convertedDistance)
    }

    /// 連續同 stageId 的週次合併成一個分期區段
    private var stageBands: [StageBand] {
        var result: [StageBand] = []
        for week in weeks {
            let x = Double(week.week)
            if let last = result.last, last.stageId == week.stageId {
                result[result.count - 1] = StageBand(
                    stageId: last.stageId,
                    start: last.start,
                    end: x + 0.5
                )
            } else {
                result.append(StageBand(stageId: week.stageId, start: x - 0.5, end: x + 0.5))
            }
        }
        return result
    }

    private var yUpperBound: Double {
        let series = weeks.map { mileage($0) } + weeks.compactMap { longRun($0) }
        let refs = [raceThreshold, safetyCeiling].compactMap { $0 }
        let peak = (series + refs).max() ?? 0
        return peak > 0 ? peak * 1.18 : 10
    }

    /// 週數多時（16~24 週）避免 x 軸標籤重疊
    private var xAxisStride: Int {
        max(1, Int((Double(weeks.count) / 8.0).rounded(.up)))
    }

    private var xAxisValues: [Double] {
        guard let first = weeks.first?.week, let last = weeks.last?.week else { return [] }
        var values = Array(stride(from: first, through: last, by: xAxisStride)).map(Double.init)
        if let lastValue = values.last, Double(last) - lastValue >= Double(xAxisStride) / 2 {
            values.append(Double(last))
        }
        return values
    }

    // MARK: - Body

    var body: some View {
        if weeks.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                header
                chart
                legend
            }
            .padding(14)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(PacerizRadius.card)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.MileageChart.title.localized)
                .font(AppFont.bodyStrong())

            Text(String(format: L10n.MileageChart.subtitle.localized, weeks.count, unitLabel))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            stageBandMarks
            referenceLineMarks
            mileageLineMarks
            longRunLineMarks
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...yUpperBound)
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let week = value.as(Double.self) {
                        Text("\(Int(week))")
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("\(Int(amount))")
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .chartXAxisLabel(alignment: .trailing) {
            Text(L10n.MileageChart.axisWeek.localized)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(height: 220)
    }

    // 分期底色 + 每段頂端階段名
    @ChartContentBuilder
    private var stageBandMarks: some ChartContent {
        ForEach(stageBands) { band in
            RectangleMark(
                xStart: .value(L10n.MileageChart.axisWeek.localized, band.start),
                xEnd: .value(L10n.MileageChart.axisWeek.localized, band.end)
            )
            .foregroundStyle(stageColor(for: band.stageId).opacity(0.10))
            .annotation(position: .overlay, alignment: .top) {
                // 只在區段夠寬時標階段名，避免窄段文字被截斷成「Ta…」
                if band.end - band.start >= 3 {
                    Text(stageName(for: band.stageId))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(stageColor(for: band.stageId))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
        }
    }

    // 參考線：兩條都是 optional，nil 就不畫
    @ChartContentBuilder
    private var referenceLineMarks: some ChartContent {
        if let threshold = raceThreshold {
            RuleMark(y: .value(L10n.MileageChart.legendRaceThreshold.localized, threshold))
                .foregroundStyle(PacerizColor.greenDeep)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading) {
                    referenceLabel(
                        text: L10n.MileageChart.legendRaceThreshold.localized,
                        value: threshold,
                        color: PacerizColor.greenDeep
                    )
                }
        }

        if let ceiling = safetyCeiling {
            RuleMark(y: .value(L10n.MileageChart.legendSafetyCeiling.localized, ceiling))
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                // leading 對齊：annotation 從繪圖區左緣往右展開，不會被右邊界切掉
                .annotation(position: .bottom, alignment: .leading) {
                    referenceLabel(
                        text: L10n.MileageChart.legendSafetyCeiling.localized,
                        value: ceiling,
                        color: .secondary
                    )
                }
        }
    }

    // 主線：每週跑量
    @ChartContentBuilder
    private var mileageLineMarks: some ChartContent {
        ForEach(weeks) { week in
            LineMark(
                x: .value(L10n.MileageChart.axisWeek.localized, Double(week.week)),
                y: .value(L10n.MileageChart.legendWeekly.localized, mileage(week)),
                series: .value("series", "weekly")
            )
            .foregroundStyle(PacerizColor.indigo)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
    }

    // 次線：長跑（nil 的週跳過）
    @ChartContentBuilder
    private var longRunLineMarks: some ChartContent {
        ForEach(weeks.filter { longRun($0) != nil }) { week in
            LineMark(
                x: .value(L10n.MileageChart.axisWeek.localized, Double(week.week)),
                y: .value(L10n.MileageChart.legendLongRun.localized, longRun(week) ?? 0),
                series: .value("series", "longRun")
            )
            .foregroundStyle(PacerizColor.orange)
            .lineStyle(StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
    }

    private func referenceLabel(text: String, value: Double, color: Color) -> some View {
        Text("\(text) \(formatted(value))")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color(UIColor.systemBackground).opacity(0.85), in: Capsule())
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                lineLegendItem(color: PacerizColor.indigo, label: L10n.MileageChart.legendWeekly.localized, dashed: false)
                // 沒有任何一週有長跑距離時（舊資料）不列長跑圖例
                if hasLongRunSeries {
                    lineLegendItem(color: PacerizColor.orange, label: L10n.MileageChart.legendLongRun.localized, dashed: false)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 14) {
                if raceThreshold != nil {
                    lineLegendItem(
                        color: PacerizColor.greenDeep,
                        label: L10n.MileageChart.legendRaceThreshold.localized,
                        dashed: true
                    )
                }
                if safetyCeiling != nil {
                    lineLegendItem(
                        color: .secondary,
                        label: L10n.MileageChart.legendSafetyCeiling.localized,
                        dashed: true
                    )
                }
                Spacer(minLength: 0)
            }

            // 各期色塊
            HStack(spacing: 10) {
                ForEach(uniqueStageIds, id: \.self) { stageId in
                    PRDotLegendItem(
                        dotColor: stageColor(for: stageId).opacity(0.45),
                        label: stageName(for: stageId)
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .font(AppFont.caption())
    }

    private func lineLegendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            // 實心線用單一線段；虛線用等寬短段拼出，避免 Capsule stroke 的破碎波浪外觀
            HStack(spacing: dashed ? 2 : 0) {
                ForEach(0..<(dashed ? 3 : 1), id: \.self) { _ in
                    Capsule()
                        .fill(color)
                        .frame(width: dashed ? 4 : 16, height: 2.5)
                }
            }
            .frame(width: 16, alignment: .leading)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    private var uniqueStageIds: [String] {
        var seen: Set<String> = []
        return stageBands.compactMap { seen.insert($0.stageId).inserted ? $0.stageId : nil }
    }

    // MARK: - Helpers

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    /// 與 PhaseRoadmapView.stageColor(for:) 相同的階段配色慣例
    private func stageColor(for stageId: String) -> Color {
        switch stageId {
        case "conversion": return .teal
        case "base":       return PacerizColor.blue
        case "build":      return PacerizColor.green
        case "peak":       return PacerizColor.orange
        case "taper":      return .purple
        default:           return PacerizColor.blue
        }
    }

    private func stageName(for stageId: String) -> String {
        let key = "stage.\(stageId)"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? stageId : localized
    }
}

// MARK: - StageBand

private struct StageBand: Identifiable {
    let stageId: String
    let start: Double
    let end: Double

    var id: String { "\(stageId)-\(start)" }
}

// MARK: - Previews

#if DEBUG

private func previewWeek(
    _ week: Int,
    _ stage: String,
    _ km: Double,
    longRunKm: Double?
) -> WeekPreview {
    WeekPreview(
        week: week,
        stageId: stage,
        targetKm: km,
        targetKmDisplay: nil,
        distanceUnit: nil,
        isRecovery: false,
        milestoneRef: nil,
        intensityRatio: nil,
        qualityOptions: [],
        longRun: longRunKm != nil ? "long_run" : nil,
        longRunKm: longRunKm
    )
}

private let previewWeeks: [WeekPreview] = {
    let stages: [(String, Int)] = [("base", 8), ("build", 6), ("peak", 4), ("taper", 2)]
    var result: [WeekPreview] = []
    var week = 1
    var km = 34.0
    for (stage, count) in stages {
        for _ in 0..<count {
            let isTaper = stage == "taper"
            result.append(previewWeek(week, stage, isTaper ? km * 0.65 : km, longRunKm: km * 0.34))
            week += 1
            km += isTaper ? 0 : 2.6
        }
    }
    return result
}()

// 新資料：兩條參考線都有
#Preview("With reference lines - light") {
    ScrollView {
        WeeklyMileageChartView(
            preview: WeeklyPreviewV2(
                id: "preview",
                methodologyId: "paceriz",
                weeks: previewWeeks,
                createdAt: nil,
                updatedAt: nil,
                safetyCeilingKm: 72,
                raceThresholdKm: 42.2
            )
        )
        .padding(16)
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("With reference lines - dark") {
    ScrollView {
        WeeklyMileageChartView(
            preview: WeeklyPreviewV2(
                id: "preview",
                methodologyId: "paceriz",
                weeks: previewWeeks,
                createdAt: nil,
                updatedAt: nil,
                safetyCeilingKm: 72,
                raceThresholdKm: 42.2
            )
        )
        .padding(16)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

// 舊資料：無 safety_ceiling_km / race_threshold_km（也無 long_run.max_km）
#Preview("Legacy - no reference lines") {
    ScrollView {
        WeeklyMileageChartView(
            preview: WeeklyPreviewV2(
                id: "preview-legacy",
                methodologyId: "paceriz",
                weeks: previewWeeks.map {
                    previewWeek($0.week, $0.stageId, $0.targetKm, longRunKm: nil)
                },
                createdAt: nil,
                updatedAt: nil,
                safetyCeilingKm: nil,
                raceThresholdKm: nil
            )
        )
        .padding(16)
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#endif
