import SwiftUI

/// 單次訓練的強度區間佔比（心率／配速的水平長條）。
///
/// 1.4 `WorkoutDetailViewV2` 與 2.0 `App2WorkoutDetailView` **共用這一份**，資料也是同一條：
/// `GET /v2/workouts/{id}` 的 `advanced_metrics.hr_zone_distribution`／`pace_zone_distribution`。
/// 樣式參數的預設值＝1.4 現狀；2.0 傳入自己的字型、區間色與卡面（同 `GaitAnalysisChartView`
/// 的處置）。
///
/// 兩組都缺席時整塊不出現（回 `EmptyView`），由呼叫端決定要不要另外畫空狀態。
struct ZoneDistributionChartView: View {
    let hrZones: V2ZoneDistribution?
    let paceZones: V2ZoneDistribution?

    // App2 復用時對齊宿主頁字型／卡面（預設維持 1.4 現狀）
    var titleFont: Font = AppFont.headline().weight(.semibold)
    var titleColor: Color = .primary
    var drawsContainer: Bool = true
    var labelFont: Font = AppFont.bodySmall()
    var labelColor: Color = .primary
    var valueFont: Font = AppFont.caption().weight(.medium)
    var valueColor: Color = .primary
    var trackColor: Color = Color.gray.opacity(0.2)
    var palette: Palette = .standard
    var barHeight: CGFloat = 8

    @State private var selectedTab: ZoneTab = .heartRate
    @State private var showHRZoneInfo = false

    /// 六個區間的顏色，由低到高。順序就是 Z1…Z6，與心率區間設定頁那張表同一個編號。
    struct Palette {
        let recovery: Color
        let aerobic: Color
        let marathon: Color
        let threshold: Color
        let anaerobic: Color
        let interval: Color

        static let standard = Palette(
            recovery: .green,
            aerobic: .blue,
            marathon: .yellow,
            threshold: .orange,
            anaerobic: .purple,
            interval: .red
        )
    }

    enum ZoneTab: CaseIterable {
        case heartRate, pace

        var title: String {
            switch self {
            case .heartRate: return L10n.Training.heartRateZone.localized
            case .pace: return L10n.Training.paceZone.localized
            }
        }
    }

    private var hasBoth: Bool { hrZones != nil && paceZones != nil }

    /// 只有一組時就顯示那一組，不讓 picker 停在空的那一頁。
    private var effectiveTab: ZoneTab {
        if hasBoth { return selectedTab }
        return hrZones != nil ? .heartRate : .pace
    }

    private var title: String {
        if hasBoth { return L10n.WorkoutDetail.zoneDistribution.localized }
        return effectiveTab == .heartRate
            ? L10n.WorkoutDetail.heartRateZones.localized
            : L10n.WorkoutDetail.paceZones.localized
    }

    var body: some View {
        if hrZones == nil && paceZones == nil {
            EmptyView()
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(titleColor)

                Spacer()

                // ⓘ 只在看心率時出現——它開的是心率區間說明。
                if effectiveTab == .heartRate {
                    Button(action: { showHRZoneInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .accessibilityIdentifier("WorkoutZoneDistributionInfo")
                }
            }

            if hasBoth {
                Picker(L10n.WorkoutDetail.zoneType.localized, selection: $selectedTab) {
                    ForEach(ZoneTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            VStack(spacing: 8) {
                ForEach(rows(for: effectiveTab), id: \.title) { row in
                    ZoneBarRow(
                        title: row.title,
                        percentage: row.percentage,
                        color: row.color,
                        labelFont: labelFont,
                        labelColor: labelColor,
                        valueFont: valueFont,
                        valueColor: valueColor,
                        trackColor: trackColor,
                        barHeight: barHeight
                    )
                }
            }
        }
        .padding(drawsContainer ? 16 : 0)
        .background(drawsContainer ? Color(.secondarySystemGroupedBackground) : Color.clear)
        .cornerRadius(drawsContainer ? 12 : 0)
        .shadow(color: drawsContainer ? Color.black.opacity(0.1) : .clear, radius: 1, x: 0, y: 1)
        .sheet(isPresented: $showHRZoneInfo) {
            NavigationStack {
                HeartRateZoneInfoView()
            }
        }
    }

    private struct Row {
        let title: String
        let percentage: Double
        let color: Color
    }

    /// 沒有值的區間不佔一列（1.4 既有行為）。
    private func rows(for tab: ZoneTab) -> [Row] {
        guard let zones = tab == .heartRate ? hrZones : paceZones else { return [] }
        let isHeartRate = tab == .heartRate
        let specs: [(Double?, String, Color)] = [
            (zones.recovery,
             isHeartRate ? L10n.WorkoutDetail.recoveryZone.localized : L10n.WorkoutDetail.recoveryPace.localized,
             palette.recovery),
            (zones.easy,
             isHeartRate ? L10n.WorkoutDetail.aerobicZone.localized : L10n.WorkoutDetail.easyPace.localized,
             palette.aerobic),
            (zones.marathon,
             isHeartRate ? L10n.WorkoutDetail.marathonZone.localized : L10n.WorkoutDetail.marathonPace.localized,
             palette.marathon),
            (zones.threshold,
             isHeartRate ? L10n.WorkoutDetail.thresholdZone.localized : L10n.WorkoutDetail.thresholdPace.localized,
             palette.threshold),
            (zones.anaerobic,
             isHeartRate ? L10n.WorkoutDetail.anaerobicZone.localized : L10n.WorkoutDetail.anaerobicPace.localized,
             palette.anaerobic),
            (zones.interval,
             isHeartRate ? L10n.WorkoutDetail.intervalZone.localized : L10n.WorkoutDetail.intervalPace.localized,
             palette.interval),
        ]
        return specs.compactMap { value, title, color in
            guard let value else { return nil }
            return Row(title: title, percentage: value, color: color)
        }
    }
}

// MARK: - ZoneBarRow

struct ZoneBarRow: View {
    let title: String
    let percentage: Double
    let color: Color
    var labelFont: Font = AppFont.bodySmall()
    var labelColor: Color = .primary
    var valueFont: Font = AppFont.caption().weight(.medium)
    var valueColor: Color = .primary
    var trackColor: Color = Color.gray.opacity(0.2)
    var barHeight: CGFloat = 8

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(labelFont)
                .foregroundColor(labelColor)
                .frame(minWidth: 60, maxWidth: 120, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                        .frame(height: barHeight)

                    Capsule()
                        .fill(color)
                        .frame(
                            width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(percentage / 100.0))),
                            height: barHeight
                        )
                }
            }
            .frame(height: barHeight)

            Text(String(format: "%.1f%%", percentage))
                .font(valueFont)
                .foregroundColor(valueColor)
                .frame(width: 50, alignment: .trailing)
        }
    }
}
