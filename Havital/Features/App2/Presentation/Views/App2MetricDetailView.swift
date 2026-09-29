import SwiftUI

// MARK: - App2MetricDetailView
/// 指標第二層（checklist §51–53）。
///
/// **導航裁決（2026-08-26 晚）**：首頁指標列每一項點擊**直接進對應的詳情頁**；
/// §55／§56 的 sheet 快視圖暫不接入任何入口、不實作。入口的把關在
/// `App2MetricDetailKind.from(insight:)`。
///
/// **2026-08-29 創辦人裁決**：有氧續航／速度耐力只要不是 `not_computed` 就要能展開，
/// 資料不足也要在詳情頁解釋 —— 取代 2026-08-26 那條「沒有詳情稿的指標不可點」。
///
/// 五頁同構：top bar（返回＋標題）→ hero 卡 →（範圍 tabs）→
/// 圖 → 統計／診斷／解釋 → 頁尾來源行。
struct App2MetricDetailView: View {
    let kind: App2MetricDetailKind
    /// 首頁那一列。**大數字與判語就用它**，詳情頁不重新評級。
    let insight: App2Insight
    /// 一句敘事（訓練量用 `mileage_progression`，其餘用該列的 `evidence`）。
    let narrative: String?
    /// 四距離完賽預估（只有 §52 能力基準用得到）。首頁那一輪的 race_projection，
    /// 詳情頁不重新取（T-0376）。空陣列＝那一區不畫。
    var finishPredictions: [App2FinishPrediction] = []
    /// 卡片的使用者當地業務日。三頁 30 天序列窗的右端
    ///（有氧續航／速度耐力的 index 線，T-0617；訓練量的負荷比線，T-0618）。
    var asof: String? = nil
    let onClose: () -> Void

    var body: some View {
        switch kind {
        case .weeklyVolume:
            App2VolumeDetailPage(
                insight: insight, narrative: narrative, asof: asof, onClose: onClose
            )
        case .capabilityBaseline:
            App2CapabilityDetailPage(
                insight: insight,
                narrative: narrative,
                asof: asof,
                finishPredictions: finishPredictions,
                onClose: onClose
            )
        case .recoveryIndex:
            App2RecoveryDetailPage(insight: insight, narrative: narrative, asof: asof, onClose: onClose)
        case .aerobicEndurance, .speedEndurance:
            App2LevelDetailPage(kind: kind, insight: insight, asof: asof, onClose: onClose)
        }
    }
}

// MARK: - App2MetricDetailScaffold
/// 六頁同構的外殼（§51-1）：34×34 返回鈕 ＋ 標題（右緣不再放「指標詳情」，與標題重複）。
@MainActor
private func metricReadFailure(hasPreviousResult: Bool, retry: @escaping () -> Void) -> some View {
    App2Card(spacing: 10) {
        Text((hasPreviousResult
              ? L10n.App2.Metric.refreshFailedKeepingResult
              : L10n.App2.Metric.readFailed).localized)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(App2Theme.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        Button(L10n.Common.retry.localized, action: retry)
            .accessibilityIdentifier("App2_MetricReadRetry")
    }
    .accessibilityIdentifier("App2_MetricReadFailure")
}

private struct App2MetricDetailScaffold<Content: View>: View {
    let title: String
    let identifier: String
    let onClose: () -> Void
    let onRefresh: () async -> Void
    @State private var chartReadoutSelection: App2ChartReadoutSelection?
    @State private var chartFrames: [App2ChartReadoutFrame] = []
    // 頁尾原本有一行「資料來源 · workouts/stats」——那是**端點路徑**，不是產品文案
    // （8/28 盤點 D11）。它對使用者沒有任何意義，寫成人話也只會是「資料來自你的跑步紀錄」
    // 這種每一頁都成立的廢話，所以整行拿掉。四頁一致。
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            App2PageHeader(
                title: title,
                titleSize: 17,
                onBack: onClose,
                backIdentifier: "\(identifier)_Back",
                titleIdentifier: identifier
            ) {
                EmptyView()
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, 14)

            GeometryReader { scrollArea in
                ScrollView {
                    VStack(spacing: 14) {
                        content()
                    }
                    .padding(.horizontal, App2Theme.pagePadding)
                    .padding(.bottom, 28)
                    .frame(minHeight: scrollArea.size.height, alignment: .top)
                    .coordinateSpace(name: App2ChartReadoutCoordinateSpace.name)
                    .onPreferenceChange(App2ChartReadoutFramePreferenceKey.self) {
                        chartFrames = $0
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture().onEnded { tap in
                            chartReadoutSelection = App2ChartReadoutDismissal.selection(
                                afterTapAt: tap.location,
                                current: chartReadoutSelection,
                                chartFrames: chartFrames
                            )
                        }
                    )
                }
                .refreshable {
                    // SwiftUI can cancel its refresh task when the view updates. The VM
                    // owns the request lifetime; leaving the page still cancels its round.
                    let refresh = Task { await onRefresh() }
                    await refresh.value
                }
                .environment(\.app2ChartReadoutSelection, $chartReadoutSelection)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
    }
}

// MARK: - App2MetricHeroCard
/// §51-2／§52-1／§53-1 的 hero：icon ＋ 標題 ＋ 判語 chip ／ 大數字 ＋ 右側對照 ／ 敘事。
private struct App2MetricHeroCard: View {
    let hero: App2MetricHero
    let symbolName: String
    let tint: Color

    var body: some View {
        App2Card(padding: App2Theme.heroPadding, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
                Text(hero.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                if let verdict = hero.verdict {
                    // 後端沒給方向（`arrow` 是 null）時不補一顆「·」——
                    // 那顆點看起來像壞掉的字元，不像「沒有方向」。
                    Text(hero.direction == .unknown
                         ? verdict
                         : "\(verdict) \(hero.direction.arrowGlyph)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(tint.app2Darkened)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tint.opacity(0.16)))
                        .accessibilityIdentifier("App2_MetricVerdictChip")
                }
                Spacer(minLength: 4)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(hero.valueText ?? App2MetricDetailProjection.placeholder)
                    .font(.app2Mono(34, weight: .bold))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("App2_MetricHeroValue")
                Spacer(minLength: 6)
                // **標籤缺席＝這一頁沒有對照這回事**（相對能力兩格），整格不畫；
                // 有標籤但值缺席才是畫「–」（那是「有這個量、現在讀不到」）。
                if let compareLabel = hero.compareLabel {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(compareLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                        Text(hero.compareValue ?? App2MetricDetailProjection.placeholder)
                            .font(.app2Mono(14, weight: .bold))
                            .foregroundStyle(App2Theme.inkSubtle)
                    }
                }
            }

            if let trend = hero.trendText {
                Text(trend)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .accessibilityIdentifier("App2_MetricHeroTrend")
            }

            if let narrative = hero.narrative, !narrative.isEmpty {
                Text(narrative)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - App2MetricRangeTabs
/// §51-3／§52-2 的範圍 tabs：淺色槽 ＋ 選中片白底。
private struct App2MetricRangeTabs: View {
    let options: [App2MetricRange]
    let selected: App2MetricRange
    let onSelect: (App2MetricRange) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Text(option.label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(option == selected ? App2Theme.inkPrimary : App2Theme.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(option == selected ? App2Theme.cardBackground : Color.clear)
                            .shadow(color: option == selected
                                    ? App2Theme.shadowInk.opacity(0.08) : .clear,
                                    radius: 3, x: 0, y: 2)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(option) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_MetricRange_\(option.rawValue)")
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.shadowInk.opacity(0.05))
        )
    }
}

// MARK: - App2MetricStatRow
/// §51-5／§53-3 的統計三欄（上緣一條分隔線）。
private struct App2MetricStatRow: View {
    let stats: [App2MetricStat]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stat.value ?? App2MetricDetailProjection.placeholder)
                        .font(.app2Mono(16, weight: .bold))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 11)
        .overlay(alignment: .top) {
            Rectangle().fill(App2Theme.insetBorder).frame(height: 1)
        }
        .accessibilityIdentifier("App2_MetricStats")
    }
}

// MARK: - §51 訓練量

private struct App2VolumeDetailPage: View {
    let insight: App2Insight
    let narrative: String?
    let onClose: () -> Void

    @StateObject private var viewModel: App2VolumeDetailViewModel
    @State private var showsAcwrInfo = false

    init(insight: App2Insight, narrative: String?, asof: String?,
         onClose: @escaping () -> Void) {
        self.insight = insight
        self.narrative = narrative
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: App2VolumeDetailViewModel(
            insight: insight,
            narrative: narrative,
            asof: asof
        ))
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_weekly_volume",
            onClose: onClose,
            onRefresh: { await viewModel.forceRefresh() }
        ) {
            if viewModel.readFailed {
                metricReadFailure(hasPreviousResult: viewModel.detail != nil) {
                    Task { await viewModel.forceRefresh() }
                }
            }
            App2MetricHeroCard(
                hero: viewModel.detail?.value.hero
                    ?? App2VolumeDetailViewModel.hero(
                        insight: insight, narrative: narrative
                    ),
                symbolName: insight.symbolName,
                tint: App2Theme.accentOrange
            )

            // 統一版型（使用者 2026-09-29）：hero → 趨勢圖 → 這個指標量什麼 → 怎麼算出來的（收合）→ 專屬區塊。
            if let detail = viewModel.detail?.value {
                loadCard(acwr: detail.acwr)
            } else if viewModel.isLoading {
                App2Card { ProgressView().frame(maxWidth: .infinity) }
            }

            App2ExplanationCard(
                title: L10n.App2.Metric.levelAboutTitle.localized,
                text: App2MetricDetailProjection.aboutText(
                    .weeklyVolume,
                    thresholds: viewModel.detail?.value.acwr.map(App2MetricDetailProjection.acwrThresholds)
                        ?? (0.8, 1.3)
                ),
                identifier: "App2_MetricAbout"
            )
            if let how = App2MetricDetailProjection.howText(.weeklyVolume, insight: insight) {
                App2HowComputedCard(text: how)
            }

            // 專屬區塊：週跑量柱狀圖（切換 tabs 控制它）＋統計三欄。
            App2MetricRangeTabs(
                options: App2MetricRange.volume,
                selected: viewModel.range,
                onSelect: viewModel.select(range:)
            )

            if let detail = viewModel.detail?.value {
                App2Card(spacing: 12) {
                    App2WeeklyVolumeChart(
                        bars: detail.bars,
                        barHeight: 118,
                        targetKm: detail.targetKm,
                        // §51-4：本週那根是橘的（首頁的迷你版是藍的）。
                        currentWeekTint: App2Theme.accentOrange,
                        showsValueLabels: detail.bars.count <= 10,
                        allowsReadout: true,
                        readoutID: "weekly-volume",
                        readoutRevision: viewModel.range.rawValue
                    )
                    App2MetricStatRow(stats: detail.stats)
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onDisappear { viewModel.cancelInFlightReload() }
    }

    /// §51-6 近期負荷比圖（2026-09-29：只留這一張，畫法同 1.4 的 TSB 圖）。
    ///
    /// 三色背景帶偏輕／合適／過量，**門檻讀後端逐列交付的 `sweet_low`／`sweet_high`**
    /// （依訓練期變；缺才退 0.8／1.3，SPEC-today-state §5.1）；Y 軸只標兩條分界；
    /// 圖例附門檻；圖下一句「目前：合適」；點圖讀數框仍是當日負荷比數字。
    /// TSB 圖與 CTL／ATL 三欄已移除：TSB 與負荷比是同一組 CTL／ATL 的兩種讀法，
    /// 固定 −7 門檻對低 CTL 的人會誤判。
    @ViewBuilder
    private func loadCard(acwr: App2AcwrBlock?) -> some View {
        App2Card(spacing: 12) {
            HStack(spacing: 6) {
                Text(L10n.App2.Metric.volumeAcwrTitle.localized)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Button {
                    showsAcwrInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(App2Theme.inkMuted)
                }
                .accessibilityIdentifier("App2_MetricAcwrInfo")
                Spacer(minLength: 0)
            }
            .sheet(isPresented: $showsAcwrInfo) {
                App2AcwrInfoSheet(
                    thresholds: acwr.map(App2MetricDetailProjection.acwrThresholds) ?? (0.8, 1.3)
                )
            }

            Text(L10n.App2.Metric.volumeAcwrCaption.localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 兩點才畫得出線（`App2MetricLineChart.path` 與 `xLabels` 都要 >= 2）；
            // 一個點畫出來是一張沒有線的空圖（T-0617 同一條）。
            if let acwr, acwr.series.count >= 2 {
                let thresholds = App2MetricDetailProjection.acwrThresholds(acwr)
                App2MetricLineChart(
                    series: [
                        .init(
                            id: "acwr", points: acwr.series, tint: App2Theme.accentBlueDeep,
                            readoutLabel: L10n.App2.Metric.volumeAcwrTitle.localized
                        )
                    ],
                    xLabels: Self.xLabels(acwr.series),
                    bands: App2MetricDetailProjection.acwrBands(acwr),
                    baselineValues: [thresholds.low, thresholds.high],
                    yTickValues: App2MetricDetailProjection.acwrAxisTicks(acwr),
                    showsBandLegend: true,
                    allowsReadout: true,
                    height: 118,
                    readoutID: "volume-acwr",
                    readoutRevision: viewModel.range.rawValue
                )
                .accessibilityIdentifier("App2_MetricAcwrChart")

                if let zone = App2MetricDetailProjection.acwrCurrentZone(acwr) {
                    Text(zone)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("App2_MetricAcwrZone")
                }
            } else {
                Text(L10n.App2.Metric.volumeAcwrUnavailable.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("App2_MetricLoadCard")
    }

    /// 圖下三顆 x 標籤：最舊／中間／最新。
    static func xLabels(_ points: [App2MetricPoint]) -> [String] {
        guard points.count >= 2 else { return [] }
        return [points[0], points[points.count / 2], points[points.count - 1]]
            .map { App2DateLabel.short(isoDate: $0.date) }
    }
}

// MARK: - App2AcwrInfoSheet
/// 「近期負荷比」ⓘ 說明。呈現方式同 1.4 的 `TrainingLoadDetailExplanationView`
///（標題＋白話段落＋三段區間列），但內容是負荷比；1.4 那份是 CTL／TSB 的說明，不改它。
private struct App2AcwrInfoSheet: View {
    let thresholds: (low: Double, high: Double)
    @Environment(\.dismiss) private var dismiss

    private var low: String { App2NumberFormat.grouped(thresholds.low, maximumFractionDigits: 1) }
    private var high: String { App2NumberFormat.grouped(thresholds.high, maximumFractionDigits: 1) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.App2.Metric.volumeAcwrTitle.localized)
                        .font(.system(size: 24, weight: .heavy))
                    Text(L10n.App2.Metric.acwrInfoFormula.localized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Divider()
                    zoneRow(.blue, L10n.App2.Metric.acwrZoneLight.localized, "< \(low)",
                            L10n.App2.Metric.acwrInfoLight.localized)
                    zoneRow(.green, L10n.App2.Metric.acwrZoneOk.localized, "\(low)–\(high)",
                            L10n.App2.Metric.acwrInfoOk.localized)
                    zoneRow(.red, L10n.App2.Metric.acwrZoneHeavy.localized, "> \(high)",
                            L10n.App2.Metric.acwrInfoHeavy.localized)
                    Divider()
                    Text(String(format: L10n.App2.Metric.acwrInfoWarningFormat.localized, high))
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done.localized) { dismiss() }
                }
            }
        }
    }

    private func zoneRow(_ tint: Color, _ name: String, _ range: String, _ meaning: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(tint.opacity(0.6)).frame(width: 12, height: 12).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(name)  \(range)").font(.system(size: 16, weight: .heavy))
                Text(meaning).font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - §52 能力基準

private struct App2CapabilityDetailPage: View {
    let insight: App2Insight
    let narrative: String?
    /// athlete_state `race_projection` 的四距離完賽預估（T-0376）。獨立於 VDOT 序列的
    /// 載入狀態；每個 channel 依自己的 delivery/status 決定是否顯示。空陣列＝整區不畫。
    let finishPredictions: [App2FinishPrediction]
    let onClose: () -> Void

    @StateObject private var viewModel: App2CapabilityDetailViewModel

    init(
        insight: App2Insight,
        narrative: String?,
        asof: String?,
        finishPredictions: [App2FinishPrediction],
        onClose: @escaping () -> Void
    ) {
        self.insight = insight
        self.narrative = narrative
        self.finishPredictions = finishPredictions
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: App2CapabilityDetailViewModel(
            insight: insight,
            narrative: narrative,
            asof: asof
        ))
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_capability_baseline",
            onClose: onClose,
            onRefresh: { await viewModel.forceRefresh() }
        ) {
            if viewModel.readFailed {
                metricReadFailure(hasPreviousResult: viewModel.detail != nil) {
                    Task { await viewModel.forceRefresh() }
                }
            }
            App2MetricHeroCard(
                hero: viewModel.detail?.value.hero
                    ?? App2CapabilityDetailViewModel.hero(
                        insight: insight, narrative: narrative, current: nil, previous: nil
                    ),
                symbolName: insight.symbolName,
                tint: App2Theme.accentViolet
            )

            App2MetricRangeTabs(
                options: App2MetricRange.capability,
                selected: viewModel.range,
                onSelect: viewModel.select(range:)
            )

            if let detail = viewModel.detail?.value {
                App2Card(spacing: 12) {
                    // 標題右側曾經印後端欄位名 `pace_vdot`（2026-08-28 走查 D11）。
                    // 卡標題已經是「VDOT 歷史」，那一格既沒有新資訊，又把識別字
                    // 露給用戶 —— 同 2026-08-27 裁決（a）「附註不得對用戶露出
                    // 工程詞」的同一條線，整格拿掉。
                    Text(L10n.App2.Metric.capabilityChartTitle.localized)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    App2MetricLineChart(
                        series: [
                            // 未來每日預估段畫虛線＋「預估」chip（2026-08-27 晚走查裁決（f））。
                            .init(
                                id: "vdot",
                                points: detail.series,
                                tint: App2Theme.accentViolet,
                                projectedFromIndex: detail.projectedFromIndex,
                                projectedLegend: L10n.App2.Metric.projectedLegend.localized,
                                readoutLabel: "VDOT"
                            )
                        ],
                        xLabels: App2VolumeDetailPage.xLabels(detail.series),
                        markerDate: detail.anchorDate,
                        markerLabel: L10n.App2.Metric.capabilityAnchorMarker.localized,
                        allowsReadout: true,
                        height: 118,
                        readoutID: "capability-vdot",
                        readoutRevision: viewModel.range.rawValue
                    )
                }
            } else if viewModel.isLoading {
                App2Card { ProgressView().frame(maxWidth: .infinity) }
            }

            App2ExplanationCard(
                title: L10n.App2.Metric.levelAboutTitle.localized,
                text: App2MetricDetailProjection.aboutText(.capabilityBaseline, thresholds: (0.8, 1.3)),
                identifier: "App2_MetricAbout"
            )
            if let how = App2MetricDetailProjection.howText(.capabilityBaseline, insight: insight) {
                App2HowComputedCard(text: how)
            }

            // 專屬區塊放最後：完賽預估。**與趨勢圖的載入狀態無關** —— 它來自
            // 首頁那一輪的 race_projection，VDOT 序列取不到不該把它一起藏掉。
            if !finishPredictions.isEmpty {
                finishPredictionsCard
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onDisappear { viewModel.cancelInFlightReload() }
    }

    /// 四距離完賽預估（label 左、值右、細分隔線）。
    private var finishPredictionsCard: some View {
        App2Card(spacing: 0) {
            Text(L10n.App2.Metric.capabilityFinishTitle.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            ForEach(Array(finishPredictions.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle().fill(App2Theme.insetBorder).frame(height: 1)
                }
                HStack(spacing: 10) {
                    Text(row.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(App2Theme.inkSubtle)
                    Spacer(minLength: 6)
                    Text(row.time)
                        .font(.app2Mono(15, weight: .bold))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 9)
            }
        }
        .accessibilityIdentifier("App2_MetricFinishPredictions")
    }
}

// MARK: - 相對能力兩格（有氧續航／速度耐力）

/// 有氧續航／速度耐力的詳情頁。
///
/// hero 用首頁那一列的 `value_text`／`verdict`／`evidence`；其下三塊是 T-0617
/// 補的「憑什麼」：**分級尺**（後端 §5.1 的 35／65 兩個切點與使用者位置）、
/// **依據句**（後端的 `basis`，講這個判定拿什麼算的）、**近 30 天 index 線**
/// （`GET /v2/athlete-state/metrics/series`，只有這一頁打）。
/// `insufficient_data` 時再多一塊把限制句展開成「還差什麼」（2026-08-29 裁決）。
///
/// **線讀不到不擋頁**：那一塊畫一句佔位，其餘照常 —— 尺與依據句都不靠序列。
private struct App2LevelDetailPage: View {
    let kind: App2MetricDetailKind
    let insight: App2Insight
    let onClose: () -> Void

    @StateObject private var viewModel: App2LevelDetailViewModel

    init(kind: App2MetricDetailKind, insight: App2Insight, asof: String?,
         onClose: @escaping () -> Void) {
        self.kind = kind
        self.insight = insight
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: App2LevelDetailViewModel(
            itemKey: kind.rawValue, asof: asof
        ))
    }

    /// 兩格各自的色（同其他頁的作法：色綁頁，不綁方向）。
    private var tint: Color {
        kind == .speedEndurance ? App2Theme.accentViolet : App2Theme.accentBlueDeep
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_\(kind.rawValue)",
            onClose: onClose,
            onRefresh: { await viewModel.forceRefresh() }
        ) {
            if viewModel.readFailed {
                metricReadFailure(hasPreviousResult: viewModel.detail != nil) {
                    Task { await viewModel.forceRefresh() }
                }
            }
            App2MetricHeroCard(
                hero: App2MetricDetailProjection.levelHero(insight: insight, kind: kind),
                symbolName: insight.symbolName,
                tint: tint
            )

            // 統一版型：hero → 趨勢圖 → 這個指標量什麼 → 怎麼算出來的（收合）→ 專屬區塊。
            trendCard

            App2ExplanationCard(
                title: L10n.App2.Metric.levelAboutTitle.localized,
                text: App2MetricDetailProjection.aboutText(kind, thresholds: (0.8, 1.3)),
                identifier: "App2_MetricLevelAbout"
            )

            if let how = App2MetricDetailProjection.howText(kind, insight: insight) {
                App2HowComputedCard(text: how)
            }

            if let scale = App2MetricDetailProjection.levelScale(insight: insight) {
                App2Card(spacing: 12) {
                    Text(L10n.App2.Metric.levelScaleTitle.localized)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    App2LevelScaleBar(scale: scale, tint: tint)
                }
                .accessibilityIdentifier("App2_MetricLevelScale")
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onDisappear { viewModel.cancelInFlightReload() }
    }

    private var trendCard: some View {
        App2ScoreTrendCard(
            points: viewModel.detail?.value.series,
            isLoading: viewModel.isLoading,
            tint: tint,
            readoutLabel: insight.label,
            readoutID: "level-trend"
        )
    }
}

// MARK: - App2ExplanationCard／App2HowComputedCard
/// 「這個指標量什麼」等一段白話的卡。五頁共用。
private struct App2ExplanationCard: View {
    let title: String
    let text: String
    let identifier: String

    var body: some View {
        App2Card(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(identifier)
    }
}

/// 「怎麼算出來的」：**預設收合**，點標題展開。五頁共用。
private struct App2HowComputedCard: View {
    let text: String
    @State private var expanded = App2MetricDetailProjection.howCardStartsExpanded

    var body: some View {
        App2Card(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(L10n.App2.Metric.howTitle.localized)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("App2_MetricHowToggle")

            if expanded {
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("App2_MetricHowText")
            }
        }
        .accessibilityIdentifier("App2_MetricHow")
    }
}

// MARK: - App2ScoreTrendCard
/// 近 30 天逐日分數線：有氧續航、速度耐力、恢復三頁共用（都讀 `metrics/series`
/// 經 `App2LevelDetailViewModel`）。序列讀不到／不足兩點 → 一句佔位，不畫空圖。
private struct App2ScoreTrendCard: View {
    let points: [App2MetricPoint]?
    let isLoading: Bool
    let tint: Color
    let readoutLabel: String
    let readoutID: String

    var body: some View {
        App2Card(spacing: 12) {
            Text(L10n.App2.Metric.levelTrendTitle.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 兩點才畫得出線（`App2MetricLineChart.path` 與 `xLabels` 都要 >= 2）。
            // 一個點畫出來是一張沒有線也沒有 x 標籤的空圖 —— 那就是把缺口
            // 偽裝成內容，寧可講「還讀不到」。
            if let points, points.count >= 2 {
                App2MetricLineChart(
                    series: [.init(id: "level", points: points, tint: tint, readoutLabel: readoutLabel)],
                    xLabels: App2VolumeDetailPage.xLabels(points),
                    allowsReadout: true,
                    height: 118,
                    readoutID: readoutID
                )
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(L10n.App2.Metric.levelTrendUnavailable.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("App2_MetricLevelTrend")
    }
}

// MARK: - App2LevelScaleBar
/// 分級尺：三段（還在建立／一般／偏強）＋ 使用者位置（SPEC-today-state §4.5）。
///
/// 段的寬度就是 0–100 上的實際比例（35／30／35），**不平均分三份** —— 平均分
/// 會讓 24 分看起來落在第一段中間，那是另一個數字。
private struct App2LevelScaleBar: View {
    let scale: App2LevelScale
    let tint: Color

    private var segments: [(label: String, span: Double, color: Color)] {
        [
            (L10n.App2.Metric.levelScaleDeveloping.localized,
             scale.developingMax, App2Theme.accentOrange.opacity(0.28)),
            (L10n.App2.Metric.levelScaleModerate.localized,
             scale.strongMin - scale.developingMax, App2Theme.inkMuted.opacity(0.18)),
            (L10n.App2.Metric.levelScaleStrong.localized,
             100 - scale.strongMin, App2Theme.accentGreenDot.opacity(0.28))
        ]
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(segment.color)
                                .frame(width: max(0, width * segment.span / 100 - 2))
                        }
                    }
                    if let position = scale.position {
                        let clamped = min(max(position, 0), 100)
                        Capsule()
                            .fill(tint)
                            .frame(width: 3, height: 22)
                            .offset(x: width * clamped / 100 - 1.5)
                            .accessibilityIdentifier("App2_MetricLevelScaleMarker")
                    }
                }
                .frame(height: 22)
            }
            .frame(height: 22)

            // 段名的寬度跟著段走（35／30／35），不是三等分 —— 標籤跟色塊對不上的話，
            // 尺就是在指另一段。
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        Text(segment.label)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(width: max(0, geometry.size.width * segment.span / 100 - 2),
                                   alignment: .leading)
                    }
                }
            }
            .frame(height: 14)

            // 兩個切點的實際數字。段名是人話，數字是判準本身，兩者都要看得到。
            HStack {
                Text(App2NumberFormat.grouped(scale.developingMax))
                Spacer(minLength: 4)
                Text(App2NumberFormat.grouped(scale.strongMin))
            }
            .font(.app2Mono(11, weight: .semibold))
            .foregroundStyle(App2Theme.inkFaint)
        }
    }
}

// MARK: - §53 恢復

private struct App2RecoveryDetailPage: View {
    let insight: App2Insight
    let narrative: String?
    let onClose: () -> Void

    @StateObject private var viewModel: App2RecoveryDetailViewModel
    /// 近 30 天恢復分數線：沿用有氧續航／速度耐力那一支 VM（`recovery_index`），不另寫第二份讀法。
    @StateObject private var scoreTrend: App2LevelDetailViewModel

    init(insight: App2Insight, narrative: String?, asof: String?, onClose: @escaping () -> Void) {
        self.insight = insight
        self.narrative = narrative
        self.asof = asof
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: App2RecoveryDetailViewModel(
            insight: insight,
            narrative: narrative
        ))
        _scoreTrend = StateObject(wrappedValue: App2LevelDetailViewModel(
            itemKey: "recovery_index", asof: asof
        ))
    }

    private let asof: String?

    /// 恢復分數逐日柱狀圖卡。序列讀不到／一天都沒有 → 一句佔位，不畫空圖。
    private var scoreBarsCard: some View {
        let bars = App2MetricDetailProjection.recoveryBars(
            scoreTrend.detail?.value.series ?? [], asof: asof
        )
        return App2Card(spacing: 12) {
            Text(L10n.App2.Metric.recoveryScoreTitle.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if bars.contains(where: { $0.value != nil }) {
                App2RecoveryScoreBars(bars: bars)
            } else if scoreTrend.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(L10n.App2.Metric.levelTrendUnavailable.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("App2_MetricRecoveryScore")
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_recovery_index",
            onClose: onClose,
            onRefresh: {
                await viewModel.forceRefresh()
                await scoreTrend.forceRefresh()
            }
        ) {
            if viewModel.readFailed {
                metricReadFailure(hasPreviousResult: viewModel.detail != nil) {
                    Task { await viewModel.forceRefresh() }
                }
            }
            App2MetricHeroCard(
                hero: viewModel.detail?.value.hero
                    ?? App2RecoveryDetailViewModel.hero(insight: insight, narrative: narrative),
                symbolName: insight.symbolName,
                tint: App2Theme.accentGreenDot
            )

            // 恢復分數近 30 天逐日柱狀圖（使用者 2026-09-29 裁決；checklist §53-5）：
            // 柱色是那天的判語分帶，Y 軸固定 0–100。
            scoreBarsCard

            App2ExplanationCard(
                title: L10n.App2.Metric.levelAboutTitle.localized,
                text: App2MetricDetailProjection.aboutText(.recoveryIndex, thresholds: (0.8, 1.3)),
                identifier: "App2_MetricAbout"
            )
            if let how = App2MetricDetailProjection.howText(.recoveryIndex, insight: insight) {
                App2HowComputedCard(text: how)
            }

            // 專屬區塊：HRV 與靜息心率合併圖＋統計欄。
            if let detail = viewModel.detail?.value {
                App2Card(spacing: 12) {
                    Text(L10n.App2.Metric.recoveryChartTitle.localized)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)

                    // 兩條線量綱不同：左軸 HRV（ms）、右軸靜息心率（bpm），刻度各用自己那條線的顏色。
                    App2MetricLineChart(
                        series: [
                            .init(
                                id: "hrv",
                                points: detail.hrv,
                                tint: App2Theme.accentGreenDot,
                                legend: L10n.App2.Metric.recoveryHrvLegend.localized,
                                readoutLabel: L10n.App2.Metric.recoveryHrv.localized,
                                unit: "ms"
                            ),
                            .init(
                                id: "rhr",
                                points: detail.restingHR,
                                tint: App2Theme.appleHealthRed,
                                legend: L10n.App2.Metric.recoveryRhrLegend.localized,
                                readoutLabel: L10n.App2.Metric.recoveryRhr.localized,
                                unit: "bpm"
                            )
                        ],
                        xLabels: App2VolumeDetailPage.xLabels(detail.hrv),
                        allowsReadout: true,
                        height: 118,
                        readoutID: "recovery-chart"
                    )

                    App2MetricStatRow(stats: detail.stats)
                }
            } else if viewModel.isLoading {
                App2Card { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .task {
            async let detail: Void = viewModel.loadIfNeeded()
            async let trend: Void = scoreTrend.loadIfNeeded()
            _ = await (detail, trend)
        }
        .onDisappear {
            viewModel.cancelInFlightReload()
            scoreTrend.cancelInFlightReload()
        }
    }
}
