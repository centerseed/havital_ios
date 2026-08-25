import SwiftUI

// MARK: - App2PlanView
/// 2.0 課表頁 —— 設計 **frame-01「課表」**（語意／端點見
/// `DESIGN-app2-decision-chain-api.md` §3.3）。
///
/// 版面：標題「訓練課表」＋ 週次切換器 → 本週跑量藍卡
/// （大 mono 數字、完成百分比膠囊、三色強度分段條）→ 每日卡（左緣彩色邊、
/// 課型徽章＋體感溫度徽章、課表／實際兩行）。
///
/// **這一頁沒有設定入口**（2026-08-25 設計更新：header 只剩標題＋週次切換器）。
/// 設定改由首頁右上角的 LV 徽章進入。
struct App2PlanView: View {

    @ObservedObject var viewModel: App2PlanViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, 16)

                if let sourced = viewModel.week {
                    volumeCard(sourced)
                        .padding(.bottom, 14)
                    ForEach(sourced.value.days) { day in
                        dayCard(day).padding(.bottom, 11)
                    }
                } else if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // 首頁與這一頁講同一句話：本週沒有課表就都說沒有。
                    App2Card(padding: 16, spacing: 8) {
                        Text(
                            viewModel.isPlanGenerated
                                ? L10n.App2.Common.noData.localized
                                : L10n.App2.Home.noPlanBody.localized
                        )
                        .font(.app2Body)
                        .lineSpacing(2)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("App2_PlanEmptyState")
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, App2Theme.tabBarClearance)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_PlanView")
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.forceRefresh() }
    }

    // MARK: - Header（標題 ＋ 週次切換器）

    private var header: some View {
        App2PageHeader(title: L10n.App2.Plan.title.localized) {
            HStack(spacing: 5) {
                // 週次切換目前只呈現當前週：`/v2/plan/status` 只給 current_week，
                // 換週要另一條「取指定週」的出口（票面剩餘差異）。
                weekStepButton(symbol: "chevron.left", enabled: false)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(viewModel.week?.value.weekLabel ?? "—")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    if let total = viewModel.week?.value.totalWeeks {
                        Text(verbatim: " / \(total)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                    }
                }
                .frame(minWidth: 76)
                weekStepButton(symbol: "chevron.right", enabled: false)
            }
        }
    }

    private func weekStepButton(symbol: String, enabled: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(App2Theme.cardBackground)
            .frame(width: 30, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(App2Theme.shadowInk.opacity(0.08), lineWidth: 1)
            )
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(enabled ? App2Theme.inkSecondary : App2Theme.chevron)
            }
            .shadow(color: App2Theme.shadowInk.opacity(0.12), radius: 3, x: 0, y: 3)
    }

    // MARK: - 本週跑量（設計：藍卡 ＋ 大 mono 數字 ＋ 百分比膠囊 ＋ 三色分段條）

    private func volumeCard(_ sourced: App2Sourced<App2PlanWeek>) -> some View {
        let week = sourced.value
        let completed = week.completedDistanceKm ?? 0
        let target = max(week.targetDistanceKm, 0.1)
        let ratio = min(completed / target, 1)

        return App2AccentCard(padding: 16, spacing: 0) {
            HStack {
                Text(L10n.App2.Plan.volumeTitle.localized)
                    .font(.system(size: 16, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.accentBlueDeep)
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(week.completedDistanceKm.map { App2NumberFormat.grouped($0, maximumFractionDigits: 1) } ?? "0")
                        .font(.app2Mono(28))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(verbatim: " / \(App2NumberFormat.grouped(week.targetDistanceKm, maximumFractionDigits: 1)) km")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                Spacer()
                Text(verbatim: "\(Int((ratio * 100).rounded()))%")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(App2Theme.accentBlue.opacity(0.1)))
            }
            .padding(.top, 3)

            intensityBar(week: week, ratio: ratio)
                .padding(.top, 11)

            HStack {
                intensityLegend(L10n.App2.Plan.intensityLow.localized, color: App2Theme.accentGreenBright)
                Spacer()
                intensityLegend(L10n.App2.Plan.intensityMedium.localized, color: App2Theme.accentOrangeSoft)
                Spacer()
                intensityLegend(L10n.App2.Plan.intensityHigh.localized, color: App2Theme.accentRed)
            }
            .padding(.top, 10)
        }
        .accessibilityIdentifier("App2_PlanSummaryCard")
    }

    /// 設計是「已完成的量」按強度切三段，鋪在「週目標量」這條軌道上。
    /// 強度比例用 `intensity_total_minutes`（週課表 payload 唯一的強度分布來源）。
    private func intensityBar(week: App2PlanWeek, ratio: Double) -> some View {
        let low = Double(week.intensityLowMinutes ?? 0)
        let medium = Double(week.intensityMediumMinutes ?? 0)
        let high = Double(week.intensityHighMinutes ?? 0)
        let minutes = low + medium + high
        // 沒有強度分布時整條算低強度，寧可少一個顏色也不要憑空分段。
        let shares: [(Double, LinearGradient)] = minutes > 0
            ? [
                (low / minutes, gradient(App2Theme.intensityLowGradient)),
                (medium / minutes, gradient(App2Theme.intensityMediumGradient)),
                (high / minutes, gradient(App2Theme.intensityHighGradient))
              ]
            : [(1, gradient(App2Theme.intensityLowGradient))]

        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(shares.enumerated()), id: \.offset) { _, share in
                    Rectangle()
                        .fill(share.1)
                        .frame(width: geo.size.width * ratio * share.0)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 10)
        .background(Capsule().fill(App2Theme.shadowInk.opacity(0.08)))
        .clipShape(Capsule())
    }

    private func gradient(_ stops: (from: Color, to: Color)) -> LinearGradient {
        LinearGradient(colors: [stops.from, stops.to], startPoint: .leading, endPoint: .trailing)
    }

    private func intensityLegend(_ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(App2Theme.inkSecondary)
        }
    }

    // MARK: - 每日卡（設計：白卡 ＋ 左緣 3px 課型色）

    private func dayCard(_ day: App2PlanDay) -> some View {
        let type = day.dayType ?? .rest
        return App2LeftStripCard(
            strip: type.app2StripColor,
            borderColor: day.isToday ? App2Theme.accentBlue.opacity(0.35) : App2Theme.cardBorder
        ) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(day.weekdayLabel)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(day.isToday ? App2Theme.accentBlueDeep : App2Theme.inkPrimary)
                    // 設計 frame-01 每卡標題是「週一 8/10」。
                    Text(day.dateLabel)
                        .font(.app2Mono(14, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                    if day.isToday {
                        App2Pill(text: L10n.App2.Plan.today.localized)
                    }
                }
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    App2Chip(
                        text: day.tag,
                        foreground: type.app2ChipForeground,
                        background: type.app2ChipBackground
                    )
                    if let temp = day.temp {
                        App2Chip(
                            text: temp,
                            foreground: App2Theme.accentOrangeText,
                            background: App2Theme.accentOrange.opacity(0.09),
                            monospaced: true
                        )
                    }
                }
            }

            // 設計 frame-01 的日卡：標題列（星期＋日期＋課型／溫度徽章）→ 課表／實際行
            // → 敘述行。休息日沒有課表行，敘述行就是那張卡唯一的內容（設計稿的
            // 「主動恢復日」那一行）。
            if let planned = day.planned {
                labelledValue(
                    label: L10n.App2.Home.planRow.localized,
                    labelColor: App2Theme.inkMuted,
                    value: planned,
                    valueColor: App2Theme.inkSecondary,
                    valueWeight: .semibold
                )
            }
            if let actual = day.actual {
                labelledValue(
                    label: L10n.App2.Home.actualRow.localized,
                    labelColor: App2Theme.accentGreen,
                    value: actual,
                    valueColor: App2Theme.inkPrimary,
                    valueWeight: .heavy
                )
            }
            if let description = day.description {
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(2)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("App2_PlanDayDescription_\(day.id)")
            }
        }
        .accessibilityIdentifier("App2_PlanDay_\(day.id)")
    }

    private func labelledValue(
        label: String,
        labelColor: Color,
        value: String,
        valueColor: Color,
        valueWeight: Font.Weight
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(labelColor)
            Text(value)
                .font(.app2Mono(14, weight: valueWeight))
                .foregroundStyle(valueColor)
        }
    }
}
