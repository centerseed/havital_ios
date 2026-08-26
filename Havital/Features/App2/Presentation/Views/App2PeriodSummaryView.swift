import SwiftUI

// MARK: - App2PeriodSummaryView
/// 整期總結 —— 設計 **frame-00g2（a）故事版**（主版式）／
/// **frame-00g（c）數字版**（降級態）。
///
/// **哪一版由資料決定，不由開關決定**：`viewModel.story` 有值就是故事版，
/// nil 就是數字版並在 header 掛「敘事未生成 · 以數據呈現」chip。敘事端點
/// （`SPEC-plan-period-summary.md`，status=Draft）還沒落地，所以 production
/// 走的一律是後者 —— 故事版的版面先照稿做好，等端點來就自然接上。
///
/// 兩版共用底部的數字區（統計磚 → 每週跑量 → 能力變化）：frame-00g2 的裁決是
/// 「數字磚與每週跑量柱狀圖**沉到故事之後**」，不是換一組別的數字。
struct App2PeriodSummaryView: View {

    @StateObject private var viewModel: App2PeriodSummaryViewModel
    let onClose: () -> Void

    /// 首頁算好的那一張結束態卡。故事版的完賽數字卡在敘事沒帶 `finish` 時要靠它降級
    /// （2026-08-27 裁決：**不得整塊省略**），「這 N 週的故事」的 N 也從它取。
    private let card: App2PlanEndCard

    init(
        card: App2PlanEndCard,
        onClose: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: App2PeriodSummaryViewModel(card: card))
        self.card = card
        self.onClose = onClose
    }

    /// 整期週數。**「這 N 週的故事」的 N 是計畫週數，不是章節數** ——
    /// 章節是敘事挑出來的幾個節點（規格 §5.2：3–6 章），拿它當週數會寫成
    /// 「這 4 週的故事」而 hero 上明明寫著 22 週。
    private var totalWeeks: Int? { card.totalWeeks }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.top, 6)

            ScrollView {
                VStack(spacing: 14) {
                    if let story = viewModel.story {
                        storyHero(story)
                        storyChapters(story)
                    } else if let summary = viewModel.summary?.value {
                        numericHero(summary)
                    }

                    if let summary = viewModel.summary?.value {
                        statGrid(summary)
                        weeklyChart(summary)
                        capabilityBlock(summary)
                    } else if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.forceRefresh() }
    }

    // MARK: - Header

    private var header: some View {
        App2PageHeader(
            title: L10n.App2.PlanEnd.summaryTitle.localized,
            titleSize: 19,
            onBack: onClose,
            backIdentifier: "App2_PeriodSummaryBack",
            titleIdentifier: "App2_PeriodSummaryView"
        ) {
            // 降級 chip 只在真的降級時出現。故事版在時不掛 —— 那顆 chip 講的是
            // 「這一頁本來該有敘事」，敘事在了就沒有話要講。
            if viewModel.story == nil, viewModel.summary != nil {
                App2Chip(
                    text: L10n.App2.PlanEnd.degradedChip.localized,
                    foreground: App2Theme.stubTint,
                    background: App2Theme.stubBackground
                )
                .accessibilityIdentifier("App2_PeriodSummaryDegradedChip")
            }
        }
    }

    // MARK: - 數字版 hero（frame-00g（c））

    /// 深藍 hero。
    ///
    /// **實際完賽成績沒有 producer**（無賽事成績綁定），所以大字位置放的是
    /// 「當時預估」而不是成績，差值那一格整個不畫（`showsFinishDelta` 恆 false）。
    /// maintenance 變體不提賽事成績 —— 大字整組不出現，只留三磚。
    @ViewBuilder
    private func numericHero(_ summary: App2PeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                // 同上：標記掛在葉節點，不掛最外層容器。
                App2Pill(
                    text: heroChipText(kind: summary.kind, raceName: summary.raceName),
                    foreground: .white,
                    background: Color.white.opacity(0.16),
                    border: Color.white.opacity(0.28)
                )
                .accessibilityIdentifier("App2_PeriodSummaryHero")
                Spacer(minLength: 4)
                if let weeks = summary.totalWeeks {
                    App2Pill(
                        text: String(format: L10n.WeekSelector.weekNumber.localized, weeks),
                        foreground: .white,
                        background: Color.white.opacity(0.16),
                        border: Color.white.opacity(0.28)
                    )
                }
            }

            // 與故事版走**同一條降級階梯**（`degradedFinish`）：成績 → 當時預估 →
            // 目標，一路退到最後一個講得出來的量，只有全都沒有時才整塊不畫。
            if let degraded = Self.degradedFinish(card) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(degraded.label)
                        .font(.app2FieldLabel)
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(degraded.value)
                            .font(.app2Mono(38))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if let target = degraded.target {
                            Text(target)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                    }
                    // 差值只在「目標 ＋ 實際成績」都在時才成立。實際成績缺席時
                    // 不拿預估去減目標 —— 那個差值講的不是同一件事。
                    if summary.showsFinishDelta, let delta = summary.targetTime {
                        Text(String(format: L10n.App2.PlanEnd.deltaTargetFormat.localized, delta))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    if let note = degraded.note {
                        Text(note)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier("App2_PeriodSummaryFinish")
            }

            HStack(spacing: 8) {
                heroTile(
                    label: L10n.App2.PlanEnd.statTotalDistance.localized,
                    value: summary.totalDistanceKm.map { App2NumberFormat.grouped($0) }
                )
                heroTile(
                    label: "VDOT",
                    value: summary.vdotDelta.map { App2MetricDetailProjection.signedLabel($0) }
                )
                heroTile(
                    label: L10n.App2.WeeklyReview.completionRate.localized,
                    value: summary.completionRate.map { "\(Int($0.rounded()))%" }
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(summary.kind.heroGradient)
        )
        .shadow(color: summary.kind.heroShadow, radius: 22, x: 0, y: 14)
    }

    /// hero 上的一格小磚（深底上的白字）。值缺席畫「–」，不畫 0。
    private func heroTile(label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value ?? App2MetricDetailProjection.placeholder)
                .font(.app2Mono(19))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
    }

    // MARK: - 故事版（frame-00g2（a））

    /// 滿版深藍 hero：大標一句 ＋ 副句 ＋（可缺席的）完賽數字卡。
    private func storyHero(_ story: App2PeriodStory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.App2.PlanEnd.narrativeChip.localized)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(App2Theme.accentGreen.opacity(0.8)))

            // 標記掛在大標這顆葉節點上 —— 掛在最外層容器時 SwiftUI 會把 identifier
            // 蓋到**每一個子節點**，卡內的完賽數字卡在 a11y tree 上就也叫
            // `App2_PeriodStoryHero`，抓不到（2026-08-27 maestro 實測；
            // 同 `App2_PlanEndCard` 與 `App2_TrainingStatusCard` 的既有坑）。
            Text(story.heroLine)
                .font(.system(size: 27, weight: .black))
                .lineSpacing(4)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("App2_PeriodStoryHero")

            if let subline = story.heroSubline {
                Text(subline)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 完賽數字卡。**賽果 backend 未上線期間不得整塊省略**（2026-08-27 裁決）：
            // 敘事沒帶 `finish` 時退成與首頁 hero 同一組降級形（目標＋當時預估）。
            // 兩者都給不出值時才整塊不畫 —— 那時連降級形都沒有東西可講。
            if let finish = story.finish {
                finishCard(
                    value: finish.time,
                    label: nil,
                    delta: finish.deltaLabel,
                    target: finish.targetLabel,
                    note: L10n.App2.PlanEnd.finishSource.localized
                )
            } else if let degraded = Self.degradedFinish(card) {
                finishCard(
                    value: degraded.value,
                    label: degraded.label,
                    // 沒有實際成績就沒有差值可講（不拿預估去減目標）。
                    delta: nil,
                    target: degraded.target,
                    note: degraded.note
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(card.kind.heroGradient)
        )
        .shadow(color: card.kind.heroShadow, radius: 22, x: 0, y: 14)
    }

    /// 完賽數字卡的降級階梯（2026-08-27 裁決：**不得整塊省略**）。
    ///
    /// 有什麼講什麼，一路退到最後一個講得出來的量：
    ///
    /// | 有的量 | 大字 | 標籤 | 底下那句 |
    /// |---|---|---|---|
    /// | 實際完賽成績 | 成績 | 實際完賽 | 取自賽事日紀錄 |
    /// | 只有當時預估 | 預估 | 當時預估 | 「這是賽事日當天推算的，不是實際成績」 |
    /// | 只有目標 | 目標 | 目標 | —（目標就是目標，沒有話要補） |
    /// | 什麼都沒有 | nil ＝ 整塊不畫（連降級形都沒有東西可講） |
    ///
    /// **只有最後一格才准整塊不畫。** 之前的版本在「只剩目標」時就整塊收掉了，
    /// 那正是裁決要擋的情形。
    static func degradedFinish(
        _ card: App2PlanEndCard
    ) -> (value: String, label: String, target: String?, note: String?)? {
        // maintenance 不提賽事成績 —— 一格都不畫。
        guard card.kind == .race else { return nil }

        let targetLine = card.targetTime.map {
            String(format: L10n.App2.PlanEnd.targetTimeFormat.localized, $0)
        }

        if let actual = card.actualFinish {
            return (
                actual,
                L10n.App2.PlanEnd.actualFinish.localized,
                targetLine,
                L10n.App2.PlanEnd.finishSource.localized
            )
        }
        if let estimate = card.estimatedFinish {
            return (
                estimate,
                L10n.App2.PlanEnd.estimateThen.localized,
                targetLine,
                L10n.App2.PlanEnd.estimateNote.localized
            )
        }
        if let target = card.targetTime {
            return (target, L10n.App2.Home.goalTarget.localized, nil, nil)
        }
        return nil
    }

    /// 故事版 hero 下方的完賽數字卡。**成績態與降級態同一個版式**，
    /// 差別只在大字是什麼、有沒有差值、底下那一句說什麼。
    private func finishCard(
        value: String,
        label: String?,
        delta: String?,
        target: String?,
        note: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let label {
                Text(label)
                    .font(.app2FieldLabel)
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            Text(value)
                .font(.app2Mono(34))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 10) {
                if let delta {
                    Text(delta)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.88))
                }
                if let target {
                    Text(target)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.66))
                }
            }
            if let note {
                Text(note)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .accessibilityIdentifier("App2_PeriodStoryFinish")
    }

    /// 「這 N 週的故事」—— 章節時間軸。
    private func storyChapters(_ story: App2PeriodStory) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 3) {
                // 週數推不出來時只寫「這段旅程的故事」那一句副標，不印一個空的 N。
                if let totalWeeks {
                    Text(String(
                        format: L10n.App2.PlanEnd.storySectionFormat.localized,
                        totalWeeks
                    ))
                    .font(.app2CardTitle)
                    .foregroundStyle(App2Theme.inkPrimary)
                }
                Text(L10n.App2.PlanEnd.storySectionSub.localized)
                    .font(.app2Caption)
                    .foregroundStyle(App2Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(story.chapters) { chapter in
                chapterCard(chapter)
            }
        }
        .accessibilityIdentifier("App2_PeriodStoryChapters")
    }

    private func chapterCard(_ chapter: App2PeriodStory.Chapter) -> some View {
        App2Card(padding: 15, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(App2Theme.accentBlue.opacity(0.28))
                    .frame(width: 8, height: 8)
                Text(chapter.weekLabel)
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.inkMuted)
                Spacer(minLength: 4)
            }

            Text(chapter.title)
                .font(.system(size: 18, weight: .black))
                .lineSpacing(3)
                .foregroundStyle(App2Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 心得引用卡（琥珀底）。**原話逐字**，不改寫（規格 §5.2）。
            if let quote = chapter.quote {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.App2.PlanEnd.quoteLabel.localized)
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundStyle(App2Theme.stubTint)

                    Text(verbatim: "「\(quote.text)」")
                        .font(.system(size: 14, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let session = quote.sessionSummary {
                        Text(session)
                            .font(.app2Mono(12, weight: .semibold))
                            .foregroundStyle(App2Theme.inkFaint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(App2Theme.stubBackground)
                )
            }

            if let line = chapter.rizoLine {
                HStack(alignment: .top, spacing: 9) {
                    App2Avatar(initial: "R", size: 28, showsRing: false)
                    Text(line)
                        .font(.system(size: 13, weight: .medium))
                        .lineSpacing(3)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 統計磚 2×2（訓練次數 / 總時間 / 最長單次 / 峰值週）

    private func statGrid(_ summary: App2PeriodSummary) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(
                    label: L10n.App2.PlanEnd.statSessions.localized,
                    value: summary.sessionCount.map(String.init),
                    suffix: nil
                )
                statTile(
                    label: L10n.App2.PlanEnd.statTotalTime.localized,
                    value: summary.totalDurationSeconds.map { "\($0 / 3600)" },
                    suffix: summary.totalDurationSeconds == nil ? nil : "h"
                )
            }
            HStack(spacing: 10) {
                statTile(
                    label: L10n.App2.PlanEnd.statLongest.localized,
                    value: summary.longestRunKm.map {
                        App2NumberFormat.grouped($0, maximumFractionDigits: 1)
                    },
                    suffix: summary.longestRunKm == nil ? nil : "km"
                )
                statTile(
                    label: L10n.App2.PlanEnd.statPeakWeek.localized,
                    value: summary.peakWeekKm.map { App2NumberFormat.grouped($0) },
                    suffix: summary.peakWeekKm == nil ? nil : "km",
                    valueColor: App2Theme.accentBlueDeep
                )
            }
        }
        .accessibilityIdentifier("App2_PeriodSummaryStats")
    }

    private func statTile(
        label: String,
        value: String?,
        suffix: String?,
        valueColor: Color = App2Theme.inkPrimary
    ) -> some View {
        App2Card(padding: 14, spacing: 2) {
            App2FieldColumn(
                label: label,
                value: value ?? App2MetricDetailProjection.placeholder,
                valueColor: valueColor,
                valueSize: 24,
                suffix: suffix,
                fillsWidth: true
            )
        }
    }

    // MARK: - 每週跑量柱狀圖

    /// 峰值週高亮 ＋ 底行「峰值週 N km」「累積 N km」。
    ///
    /// **高亮的是峰值週，不是「本週」** —— 計畫已經走完，這段裡沒有進行中的一週。
    /// `App2WeeklyVolumeChart` 用 `isCurrentWeek` 決定哪一根柱上主色，所以這裡把
    /// 那個旗標重新綁到「峰值」上：同一支圖、同一組柱子語意，只是這一頁的
    /// 「值得看的那一根」是峰值。
    @ViewBuilder
    private func weeklyChart(_ summary: App2PeriodSummary) -> some View {
        if !summary.bars.isEmpty {
            App2Card(padding: 15, spacing: 11) {
                Text(String(
                    format: L10n.App2.PlanEnd.weeklyChartTitleFormat.localized,
                    summary.bars.count
                ))
                .font(.app2CardTitle)
                .foregroundStyle(App2Theme.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

                App2WeeklyVolumeChart(
                    bars: Self.highlightPeak(summary.bars, peakKm: summary.peakWeekKm),
                    barHeight: 96,
                    showsValueLabels: summary.bars.count <= 10
                )

                HStack {
                    if let peak = summary.peakWeekKm {
                        Text(String(
                            format: L10n.App2.PlanEnd.peakWeekFormat.localized,
                            App2MetricDetailProjection.kmLabel(peak)
                        ))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                    }
                    Spacer(minLength: 8)
                    if let total = summary.totalDistanceKm {
                        Text(String(
                            format: L10n.App2.PlanEnd.cumulativeFormat.localized,
                            App2MetricDetailProjection.kmLabel(total)
                        ))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                    }
                }
            }
            .accessibilityIdentifier("App2_PeriodSummaryWeeklyChart")
        }
    }

    /// 把「本週」旗標改綁到峰值那一根。第一根達到峰值的柱才亮 —— 兩週同量時
    /// 亮兩根會讓「峰值」讀起來像兩個值。
    static func highlightPeak(_ bars: [App2WeeklyBar], peakKm: Double?) -> [App2WeeklyBar] {
        guard let peakKm else { return bars.map { $0.app2Highlighted(false) } }
        var highlighted = false
        return bars.map { bar in
            guard !highlighted, bar.distanceKm == peakKm else { return bar.app2Highlighted(false) }
            highlighted = true
            return bar.app2Highlighted(true)
        }
    }

    // MARK: - 能力變化 · VDOT

    /// 起點 → 終點 ＋ 整期曲線。**序列不到兩點就整塊不畫**（一個點畫不出「變化」）。
    @ViewBuilder
    private func capabilityBlock(_ summary: App2PeriodSummary) -> some View {
        if summary.vdotSeries.count >= 2 {
            App2Card(padding: 15, spacing: 11) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L10n.App2.PlanEnd.capabilityTitle.localized)
                        .font(.app2CardTitle)
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 6)
                    if let start = summary.vdotStart, let end = summary.vdotEnd {
                        Text(verbatim: String(format: "%.1f → %.1f", start, end))
                            .font(.app2Mono(14))
                            .foregroundStyle(App2Theme.inkSecondary)
                    }
                    if let delta = summary.vdotDelta {
                        Text(App2MetricDetailProjection.signedLabel(delta))
                            .font(.app2Mono(14))
                            .foregroundStyle(delta >= 0
                                             ? App2Theme.accentGreen
                                             : App2Theme.accentOrangeBright)
                    }
                }

                App2MetricLineChart(
                    series: [
                        App2MetricLineChart.Series(
                            id: "vdot",
                            points: summary.vdotSeries,
                            tint: App2Theme.accentBlue
                        )
                    ],
                    xLabels: Self.xLabels(summary.vdotSeries),
                    height: 118
                )
            }
            .accessibilityIdentifier("App2_PeriodSummaryCapability")
        }
    }

    /// 三顆刻度：最舊／中間／最新。序列本身帶當地日期字串，不再過時區換算。
    static func xLabels(_ series: [App2MetricPoint]) -> [String] {
        guard series.count >= 2 else { return [] }
        let picked = [series[0], series[series.count / 2], series[series.count - 1]]
        return picked.map { App2DateLabel.short(isoDate: $0.date) }
    }

    // MARK: - 文案

    /// hero chip：race＝「賽名 · 備賽完成」，maintenance＝「訓練期完成」。
    private func heroChipText(kind: App2PlanEndKind, raceName: String?) -> String {
        switch kind {
        case .race:
            let chip = L10n.App2.PlanEnd.chipRace.localized
            guard let raceName, !raceName.isEmpty else { return chip }
            return "\(raceName) · \(chip)"
        case .maintenance:
            return L10n.App2.PlanEnd.chipMaintenance.localized
        }
    }

}

// MARK: - App2PlanEndTabCard
/// 課表 tab 的結束態（設計 **frame-00g2（c）**）。
///
/// 「✓ 計畫完成」深藍卡（N/N 週、週量迷你柱、次數／完成率／峰值）＋ Rizo 一句話
/// ＋「設定新目標」CTA ＋「看整期總結」入口。
///
/// **數字與整期總結頁同源**：這一支持有的是同一個 `App2PeriodSummaryViewModel`，
/// 取的是 `App2PeriodSummary.strip`（同一份投影的子集）——兩個畫面上的
/// 「完成率 91%」不可能長得不一樣。
///
/// **「瀏覽這期的歷史課表」那一列沒有做**：換週要一條「取指定週課表」的出口，
/// 而 2.0 現在沒有（課表頁的週次切換器就是因此停用的）。做成點下去沒反應的死列
/// 不如不畫（同 `App2HomeView.crossTrainingRow` 的先例）；缺口回報在票面。
struct App2PlanEndTabCard: View {

    @StateObject private var viewModel: App2PeriodSummaryViewModel
    private let card: App2PlanEndCard
    let onOpenSummary: () -> Void
    let onSetNewGoal: () -> Void

    init(
        card: App2PlanEndCard,
        onOpenSummary: @escaping () -> Void,
        onSetNewGoal: @escaping () -> Void
    ) {
        self.card = card
        _viewModel = StateObject(wrappedValue: App2PeriodSummaryViewModel(card: card))
        self.onOpenSummary = onOpenSummary
        self.onSetNewGoal = onSetNewGoal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.App2.PlanEnd.planTabSubtitle.localized)
                .font(.app2Body)
                .foregroundStyle(App2Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("App2_PlanEndTabSubtitle")

            completeCard
            rizoNote

            ctaButton
            App2GroupedList {
                App2SettingsRow(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: L10n.App2.PlanEnd.summaryEntry.localized,
                    value: "",
                    showsDivider: false
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenSummary)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_PlanEndTabSummaryEntry")
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    // MARK: - 「✓ 計畫完成」卡

    private var completeCard: some View {
        let strip = viewModel.summary?.value.strip
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                    Text(L10n.App2.PlanEnd.planCompleteChip.localized)
                        .font(.system(size: 13, weight: .heavy))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.16)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))

                Spacer(minLength: 4)

                if let weeks = card.totalWeeks {
                    App2Pill(
                        text: String(
                            format: L10n.App2.PlanEnd.weeksProgressFormat.localized, weeks, weeks
                        ),
                        foreground: .white,
                        background: Color.white.opacity(0.16),
                        border: Color.white.opacity(0.28)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if let name = card.raceName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(card.kind == .race
                     ? L10n.App2.PlanEnd.planCompleteRace.localized
                     : L10n.App2.PlanEnd.planCompleteMaintenance.localized)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 週量迷你柱。載入中或整期一根柱都沒有時整塊不畫（不畫空圖）。
            if let bars = strip?.bars, !bars.isEmpty {
                App2WeeklyVolumeChart(
                    bars: App2PeriodSummaryView.highlightPeak(bars, peakKm: strip?.peakWeekKm),
                    barHeight: 26,
                    currentWeekTint: .white,
                    showsValueLabels: false
                )
                .accessibilityIdentifier("App2_PlanEndTabBars")
            }

            if let line = strip.flatMap(App2PlanEndProjection.stripStatsLine) {
                Text(line)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("App2_PlanEndTabStats")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(card.kind.heroGradient)
        )
        .shadow(color: card.kind.heroShadow, radius: 20, x: 0, y: 12)
        .accessibilityIdentifier("App2_PlanEndTabCard")
    }

    /// Rizo 一句話。**設計稿的靜態教練建議**，不是 payload 欄位
    /// （同 `App2NoteBox` 那條長距離補給提示的先例）——沒有端點在生成這一句，
    /// 所以它是文案不是資料。
    private var rizoNote: some View {
        HStack(alignment: .top, spacing: 10) {
            App2Avatar(initial: "R", size: 32, showsRing: false)
            Text(L10n.App2.PlanEnd.rizoLine.localized)
                .font(.system(size: 14, weight: .medium))
                .lineSpacing(3)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .app2CardSurface()
        .accessibilityIdentifier("App2_PlanEndTabRizo")
    }

    private var ctaButton: some View {
        HStack(spacing: 7) {
            Image(systemName: "star")
                .font(.system(size: 14, weight: .black))
            Text(L10n.App2.PlanEnd.ctaNewGoal.localized)
                .font(.system(size: 16, weight: .black))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(App2Theme.accentBlue)
        )
        .shadow(color: App2Theme.shadowAccentColor, radius: 12, x: 0, y: 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSetNewGoal)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_PlanEndTabNewGoal")
    }
}

// MARK: - App2WeeklyBar + 高亮

extension App2WeeklyBar {
    /// `App2WeeklyVolumeChart` 用 `isCurrentWeek` 決定哪一根柱上主色。整期總結頁
    /// 要亮的是**峰值週**（這段裡沒有進行中的一週），所以在投影層換旗標，
    /// 而不是在圖表元件裡加第二個「要亮哪一根」的參數。
    func app2Highlighted(_ isHighlighted: Bool) -> App2WeeklyBar {
        App2WeeklyBar(
            weekStart: weekStart,
            distanceKm: distanceKm,
            isCurrentWeek: isHighlighted,
            shortLabel: shortLabel
        )
    }
}
