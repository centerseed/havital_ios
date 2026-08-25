import SwiftUI

// MARK: - App2RecordsView
/// 2.0 紀錄頁 —— 設計 **frame-10「紀錄」**（語意／端點見
/// `DESIGN-app2-decision-chain-api.md` §3.6）。
///
/// 版面：標題「訓練紀錄」→ hero 藍卡（近 30 天／今年累積雙欄 ＋ 近 8 週趨勢柱）
/// → 每筆紀錄白卡（左緣課型色、課型徽章 ＋ VDOT 徽章、距離／配速／時間三欄大 mono 數字）。
struct App2RecordsView: View {

    @ObservedObject var viewModel: App2RecordsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                App2PageHeader(title: L10n.App2.Records.title.localized) {
                    EmptyView()
                }
                .padding(.bottom, 14)

                if let sourced = viewModel.records {
                    heroCard(sourced).padding(.bottom, 20)
                    HStack {
                        Text(L10n.App2.Records.listSection.localized)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Spacer()
                        App2StubBadge(origin: sourced.origin)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 10)
                    .accessibilityIdentifier("App2_RecordsListCard")

                    ForEach(sourced.value.recentWorkouts) { row in
                        workoutCard(row).padding(.bottom, 11)
                    }
                } else if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text(L10n.App2.Common.noData.localized)
                        .font(.app2Body)
                        .foregroundStyle(App2Theme.inkTertiary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, App2Theme.tabBarClearance)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_RecordsView")
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.forceRefresh() }
    }

    // MARK: - hero（雙欄總量 ＋ 近 8 週趨勢）

    private func heroCard(_ sourced: App2Sourced<App2Records>) -> some View {
        let records = sourced.value
        return App2AccentCard(strength: 0.14, padding: 18, spacing: 0) {
            HStack {
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }
            .frame(height: sourced.origin.isStub ? nil : 0)

            HStack(alignment: .top, spacing: 14) {
                totalsColumn(
                    title: L10n.App2.Records.monthSection.localized,
                    titleColor: App2Theme.accentBlueDeep,
                    value: Self.grouped(records.monthDistanceKm),
                    unit: "km",
                    footnote: Self.monthComparison(records.monthDeltaKm)
                        ?? String(format: L10n.App2.Records.runsCount.localized, records.monthWorkouts),
                    footnoteColor: records.monthDeltaKm.map(Self.deltaColor)
                )
                Rectangle()
                    .fill(App2Theme.shadowInk.opacity(0.1))
                    .frame(width: 1)
                totalsColumn(
                    title: L10n.App2.Records.ytdSection.localized,
                    titleColor: App2Theme.inkMuted,
                    value: records.ytdDistanceKm.map { Self.grouped($0) } ?? "—",
                    unit: "km",
                    footnote: records.ytdWorkouts.map {
                        String(format: L10n.App2.Records.runsCount.localized, $0)
                    } ?? "—"
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.App2.Records.trendTitle.localized)
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(App2Theme.inkSecondary)
                    Spacer()
                    Text(L10n.App2.Records.trendUnit.localized)
                        .font(.app2Mono(11, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                App2WeeklyVolumeChart(bars: records.weeklySeries)
            }
            .padding(.top, 16)
            .accessibilityIdentifier("App2_RecordsWeeklyCard")
        }
        .accessibilityIdentifier("App2_RecordsTotalsCard")
    }

    private func totalsColumn(
        title: String,
        titleColor: Color,
        value: String,
        unit: String,
        footnote: String,
        footnoteColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .tracking(1)
                .foregroundStyle(titleColor)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.app2Mono(30))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(verbatim: " \(unit)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 6)
            Text(footnote)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(footnoteColor ?? App2Theme.inkTertiary)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 每筆紀錄卡

    private func workoutCard(_ row: App2WorkoutRow) -> some View {
        let type = row.dayType
        return App2LeftStripCard(
            strip: type?.app2StripColor ?? App2Theme.accentBlue,
            padding: EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15)
        ) {
            HStack {
                if let tag = row.tag {
                    App2Chip(
                        text: tag,
                        foreground: type?.app2ChipForeground ?? App2Theme.accentBlueDeep,
                        background: type?.app2ChipBackground ?? App2Theme.accentBlue.opacity(0.12)
                    )
                }
                Text(row.dateLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Spacer(minLength: 6)
                if let vdot = row.vdot {
                    App2Chip(
                        text: "VDOT \(vdot)",
                        foreground: App2Theme.accentOrangeText,
                        background: App2Theme.accentOrange.opacity(0.09),
                        monospaced: true
                    )
                }
            }

            HStack(alignment: .bottom, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(row.distance.replacingOccurrences(of: " km", with: ""))
                        .font(.app2Mono(28))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(verbatim: "km")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                if let pace = row.pace {
                    metricColumn(
                        value: pace.replacingOccurrences(of: "/km", with: ""),
                        suffix: "/km",
                        caption: L10n.App2.Records.pace.localized
                    )
                }
                metricColumn(
                    value: row.duration,
                    suffix: nil,
                    caption: L10n.App2.Records.time.localized
                )
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .accessibilityIdentifier("App2_RecordRow")
    }

    private func metricColumn(value: String, suffix: String?, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.app2Mono(20))
                    .foregroundStyle(App2Theme.inkPrimary)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }
            Text(caption)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)
        }
    }

    /// 設計 hero 左欄的「↑ 較上月 +18」。上月資料不齊時 VM 給 nil，這一列就不出現。
    private static func monthComparison(_ deltaKm: Double?) -> String? {
        guard let deltaKm else { return nil }
        let rounded = Int(deltaKm.rounded())
        let arrow = rounded > 0 ? "↑" : (rounded < 0 ? "↓" : "→")
        let signed = rounded > 0 ? "+\(rounded)" : String(rounded)
        return "\(arrow) " + String(format: L10n.App2.Records.vsLastMonth.localized, signed)
    }

    private static func deltaColor(_ deltaKm: Double) -> Color {
        let rounded = Int(deltaKm.rounded())
        if rounded > 0 { return App2Theme.accentGreen }
        if rounded < 0 { return App2Theme.accentOrangeText }
        return App2Theme.inkTertiary
    }

    /// `1,284` 這種千分位（設計 hero 的今年累積）。
    private static func grouped(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: km)) ?? String(format: "%.0f", km)
    }
}
