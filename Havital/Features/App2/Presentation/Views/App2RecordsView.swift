import SwiftUI

// MARK: - App2RecordsView
/// 2.0 紀錄頁（`DESIGN-app2-decision-chain-api.md` §3.6）。
struct App2RecordsView: View {

    @StateObject private var viewModel = App2RecordsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: App2Theme.sectionSpacing) {
                if let sourced = viewModel.records {
                    totalsCard(sourced)
                    weeklyCard(sourced)
                    listCard(sourced)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text(L10n.App2.Common.noData.localized)
                        .font(.app2Body)
                        .foregroundStyle(App2Theme.inkTertiary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.vertical, PacerizTokens.spacing.m)
        }
        .background(App2Theme.pageBackground.ignoresSafeArea())
        .accessibilityIdentifier("App2_RecordsView")
        .task { await viewModel.load() }
    }

    // MARK: - 近 30 天 ＋ 今年累積

    private func totalsCard(_ sourced: App2Sourced<App2Records>) -> some View {
        let records = sourced.value
        return App2Card {
            HStack {
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }
            HStack(alignment: .top, spacing: PacerizTokens.spacing.m) {
                totalsBlock(
                    title: L10n.App2.Records.windowSection.localized,
                    distanceKm: records.windowDistanceKm,
                    count: records.windowWorkouts,
                    tint: App2Theme.accentBlue
                )
                Divider().frame(height: 52)
                totalsBlock(
                    title: L10n.App2.Records.ytdSection.localized,
                    distanceKm: records.ytdDistanceKm,
                    count: records.ytdWorkouts,
                    tint: App2Theme.accentGreen
                )
            }
        }
        .accessibilityIdentifier("App2_RecordsTotalsCard")
    }

    private func totalsBlock(title: String, distanceKm: Double?, count: Int?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: PacerizTokens.spacing.xs) {
            App2SectionLabel(text: title, color: tint)
            HStack(spacing: PacerizTokens.spacing.m) {
                App2FieldColumn(
                    label: L10n.App2.Records.distance.localized,
                    value: distanceKm.map { String(format: "%.0f", $0) } ?? "—",
                    valueColor: App2Theme.inkPrimary,
                    valueSize: 24,
                    suffix: distanceKm == nil ? nil : "km"
                )
                App2FieldColumn(
                    label: L10n.App2.Records.workouts.localized,
                    value: count.map(String.init) ?? "—",
                    valueColor: App2Theme.inkPrimary,
                    valueSize: 24
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 近 8 週跑量

    private func weeklyCard(_ sourced: App2Sourced<App2Records>) -> some View {
        App2Card {
            HStack {
                App2SectionLabel(text: L10n.App2.Records.weeklySection.localized)
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }
            App2WeeklyVolumeChart(bars: sourced.value.weeklySeries)
        }
        .accessibilityIdentifier("App2_RecordsWeeklyCard")
    }

    // MARK: - 訓練紀錄清單

    private func listCard(_ sourced: App2Sourced<App2Records>) -> some View {
        App2Card {
            App2SectionLabel(
                text: L10n.App2.Records.listSection.localized,
                color: App2Theme.inkTertiary
            )
            VStack(spacing: PacerizTokens.spacing.s) {
                ForEach(sourced.value.recentWorkouts) { row in
                    workoutRow(row)
                }
            }
        }
        .accessibilityIdentifier("App2_RecordsListCard")
    }

    private func workoutRow(_ row: App2WorkoutRow) -> some View {
        HStack(spacing: PacerizTokens.spacing.m) {
            Text(row.dateLabel)
                .font(.app2Numeric(12, weight: .semibold))
                .foregroundStyle(App2Theme.inkTertiary)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let tag = row.tag {
                    Text(tag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(App2Theme.inkPrimary)
                }
                HStack(spacing: PacerizTokens.spacing.s) {
                    Text(row.distance)
                        .font(.app2Numeric(13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkPrimary)
                    if let pace = row.pace {
                        Text(pace)
                            .font(.app2Numeric(11))
                            .foregroundStyle(App2Theme.inkSecondary)
                    }
                    Text(row.duration)
                        .font(.app2Numeric(11))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }

            Spacer(minLength: PacerizTokens.spacing.s)

            if let vdot = row.vdot {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: "VDOT")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                    Text(vdot)
                        .font(.app2Numeric(14))
                        .foregroundStyle(App2Theme.accentBlue)
                }
            }
        }
        .padding(.vertical, PacerizTokens.spacing.s)
        .padding(.horizontal, PacerizTokens.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.insetCornerRadius, style: .continuous)
                .fill(App2Theme.insetBackground)
        )
    }
}
