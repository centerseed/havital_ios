import SwiftUI

// MARK: - App2PlanView
/// 2.0 課表頁（`DESIGN-app2-decision-chain-api.md` §3.3）。
struct App2PlanView: View {

    @StateObject private var viewModel = App2PlanViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: App2Theme.sectionSpacing) {
                if let sourced = viewModel.week {
                    summaryCard(sourced)
                    purposeCard(sourced)
                    daysCard(sourced)
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
        .accessibilityIdentifier("App2_PlanView")
        .task { await viewModel.load() }
    }

    // MARK: - 週摘要（週次／目標量／已完成／強度分布）

    private func summaryCard(_ sourced: App2Sourced<App2PlanWeek>) -> some View {
        let week = sourced.value
        return App2Card {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: week.weekLabel)
                    .font(.app2Numeric(30))
                    .foregroundStyle(App2Theme.inkPrimary)
                if let total = week.totalWeeks {
                    Text(verbatim: "/ \(total)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }

            HStack(spacing: PacerizTokens.spacing.s) {
                App2FieldColumn(
                    label: L10n.App2.Plan.weekVolume.localized,
                    value: String(format: "%.0f", week.targetDistanceKm),
                    valueColor: App2Theme.accentBlue,
                    suffix: "km"
                )
                App2FieldColumn(
                    label: L10n.App2.Plan.completed.localized,
                    value: week.completedDistanceKm.map { String(format: "%.0f", $0) } ?? "—",
                    valueColor: App2Theme.accentGreen,
                    suffix: week.completedDistanceKm == nil ? nil : "km"
                )
            }

            if let low = week.intensityLowMinutes,
               let medium = week.intensityMediumMinutes,
               let high = week.intensityHighMinutes {
                intensityBar(low: low, medium: medium, high: high)
            }
        }
        .accessibilityIdentifier("App2_PlanSummaryCard")
    }

    private func intensityBar(low: Int, medium: Int, high: Int) -> some View {
        let total = max(low + medium + high, 1)
        return VStack(alignment: .leading, spacing: PacerizTokens.spacing.xs) {
            App2SectionLabel(
                text: L10n.App2.Plan.intensitySection.localized,
                color: App2Theme.inkTertiary
            )
            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(width: geo.size.width * CGFloat(low) / CGFloat(total),
                            color: App2Theme.accentGreen.opacity(0.55))
                    segment(width: geo.size.width * CGFloat(medium) / CGFloat(total),
                            color: App2Theme.accentBlue.opacity(0.7))
                    segment(width: geo.size.width * CGFloat(high) / CGFloat(total),
                            color: App2Theme.accentOrange)
                }
            }
            .frame(height: 8)

            HStack(spacing: PacerizTokens.spacing.m) {
                legend(L10n.App2.Plan.intensityLow.localized, minutes: low,
                       color: App2Theme.accentGreen.opacity(0.55))
                legend(L10n.App2.Plan.intensityMedium.localized, minutes: medium,
                       color: App2Theme.accentBlue.opacity(0.7))
                legend(L10n.App2.Plan.intensityHigh.localized, minutes: high,
                       color: App2Theme.accentOrange)
                Spacer()
            }
        }
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(color).frame(width: max(0, width))
    }

    private func legend(_ label: String, minutes: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(verbatim: "\(label) \(minutes)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(App2Theme.inkTertiary)
        }
    }

    // MARK: - 本週目的

    private func purposeCard(_ sourced: App2Sourced<App2PlanWeek>) -> some View {
        App2Card {
            App2SectionLabel(text: L10n.App2.Plan.purpose.localized)
            Text(sourced.value.purpose)
                .font(.app2Body)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("App2_PlanPurposeCard")
    }

    // MARK: - 每日安排

    private func daysCard(_ sourced: App2Sourced<App2PlanWeek>) -> some View {
        App2Card {
            App2SectionLabel(
                text: L10n.App2.Plan.daysSection.localized,
                color: App2Theme.inkTertiary
            )
            VStack(spacing: PacerizTokens.spacing.s) {
                ForEach(sourced.value.days) { day in
                    dayRow(day)
                }
            }
        }
        .accessibilityIdentifier("App2_PlanDaysCard")
    }

    private func dayRow(_ day: App2PlanDay) -> some View {
        HStack(alignment: .top, spacing: PacerizTokens.spacing.m) {
            VStack(spacing: 2) {
                Text(day.weekdayLabel)
                    .font(.system(size: 12, weight: day.isToday ? .bold : .medium))
                    .foregroundStyle(day.isToday ? App2Theme.accentBlue : App2Theme.inkTertiary)
                if day.isToday {
                    Circle().fill(App2Theme.accentBlue).frame(width: 4, height: 4)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: PacerizTokens.spacing.xs) {
                    Text(day.tag)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkPrimary)
                    if let temp = day.temp {
                        Text(temp)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(App2Theme.accentOrange)
                    }
                }
                Text(day.summary)
                    .font(.app2Caption)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: PacerizTokens.spacing.s)

            VStack(alignment: .trailing, spacing: 2) {
                if let planned = day.planned {
                    Text(planned)
                        .font(.app2Numeric(13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkPrimary)
                }
                if let actual = day.actual {
                    Text(actual)
                        .font(.app2Numeric(11, weight: .medium))
                        .foregroundStyle(App2Theme.accentGreen)
                }
            }
        }
        .padding(.vertical, PacerizTokens.spacing.s)
        .padding(.horizontal, PacerizTokens.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.insetCornerRadius, style: .continuous)
                .fill(day.isToday ? App2Theme.goalCardBackground : App2Theme.insetBackground)
        )
    }
}
