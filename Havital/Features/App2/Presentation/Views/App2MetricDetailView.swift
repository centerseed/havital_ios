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
/// 那兩頁沒有自己的序列端點，整頁內容都是首頁那一列（見 `App2LevelDetailPage`）。
///
/// 五頁同構：top bar（返回＋標題＋右緣「指標詳情」）→ hero 卡 →（範圍 tabs）→
/// 圖 → 統計／診斷／解釋 → 頁尾來源行。
struct App2MetricDetailView: View {
    let kind: App2MetricDetailKind
    /// 首頁那一列。**大數字與判語就用它**，詳情頁不重新評級。
    let insight: App2Insight
    /// 一句敘事（訓練量用 `mileage_progression`，其餘用該列的 `evidence`）。
    let narrative: String?
    let onClose: () -> Void

    var body: some View {
        switch kind {
        case .weeklyVolume:
            App2VolumeDetailPage(insight: insight, narrative: narrative, onClose: onClose)
        case .capabilityBaseline:
            App2CapabilityDetailPage(insight: insight, narrative: narrative, onClose: onClose)
        case .recoveryIndex:
            App2RecoveryDetailPage(insight: insight, narrative: narrative, onClose: onClose)
        case .aerobicEndurance, .speedEndurance:
            App2LevelDetailPage(kind: kind, insight: insight, onClose: onClose)
        }
    }
}

// MARK: - App2MetricDetailScaffold
/// 六頁同構的外殼（§51-1）：34×34 返回鈕 ＋ 標題 ＋ 右緣「指標詳情」。
private struct App2MetricDetailScaffold<Content: View>: View {
    let title: String
    let identifier: String
    let onClose: () -> Void
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
                Text(L10n.App2.Metric.pageSuffix.localized)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(App2Theme.inkMuted)
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 14) {
                    content()
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.bottom, 28)
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
                            .fill(option == selected ? Color.white : Color.clear)
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

    init(insight: App2Insight, narrative: String?, onClose: @escaping () -> Void) {
        self.insight = insight
        self.narrative = narrative
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: App2VolumeDetailViewModel(
            insight: insight,
            narrative: narrative
        ))
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_weekly_volume",
            onClose: onClose
        ) {
            App2MetricHeroCard(
                hero: viewModel.detail?.value.hero
                    ?? App2VolumeDetailViewModel.hero(
                        insight: insight, narrative: narrative, targetKm: nil
                    ),
                symbolName: insight.symbolName,
                tint: App2Theme.accentOrange
            )

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
                        showsValueLabels: detail.bars.count <= 10
                    )
                    App2MetricStatRow(stats: detail.stats)
                }

                // §51-6／§51-7：**資料缺席時整塊隱藏**（dev 的 `tsb_metrics` 全 null）。
                if let load = detail.load {
                    loadCard(load)
                }
            } else if viewModel.isLoading {
                App2Card { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onDisappear { viewModel.cancelRangeReload() }
    }

    private func loadCard(_ load: App2LoadBlock) -> some View {
        App2Card(spacing: 12) {
            Text(L10n.App2.Metric.volumeLoadTitle.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)

            App2MetricLineChart(
                series: [
                    .init(id: "tsb", points: load.series, tint: App2Theme.accentBlueDeep)
                ],
                xLabels: Self.xLabels(load.series),
                baselineValue: 0,
                baselineLabel: L10n.App2.Metric.volumeTsbBaseline.localized,
                height: 118
            )

            App2MetricStatRow(stats: [
                App2MetricStat(
                    id: "ctl",
                    label: L10n.App2.Metric.volumeCtl.localized,
                    value: load.ctl.map { App2NumberFormat.grouped($0) }
                ),
                App2MetricStat(
                    id: "atl",
                    label: L10n.App2.Metric.volumeAtl.localized,
                    value: load.atl.map { App2NumberFormat.grouped($0) }
                ),
                App2MetricStat(
                    id: "tsb",
                    label: L10n.App2.Metric.volumeTsb.localized,
                    value: load.tsb.map { App2MetricDetailProjection.signedLabel($0, fractionDigits: 0) }
                )
            ])
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

// MARK: - §52 能力基準

private struct App2CapabilityDetailPage: View {
    let insight: App2Insight
    let narrative: String?
    let onClose: () -> Void

    @StateObject private var viewModel: App2CapabilityDetailViewModel

    init(insight: App2Insight, narrative: String?, onClose: @escaping () -> Void) {
        self.insight = insight
        self.narrative = narrative
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: App2CapabilityDetailViewModel(
            insight: insight,
            narrative: narrative
        ))
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_capability_baseline",
            onClose: onClose
        ) {
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
                                projectedLegend: L10n.App2.Metric.projectedLegend.localized
                            )
                        ],
                        xLabels: App2VolumeDetailPage.xLabels(detail.series),
                        markerDate: detail.anchorDate,
                        markerLabel: L10n.App2.Metric.capabilityAnchorMarker.localized,
                        height: 118
                    )
                }

                if !detail.diagnostics.isEmpty {
                    diagnosticsCard(detail.diagnostics)
                }
            } else if viewModel.isLoading {
                App2Card { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onDisappear { viewModel.cancelRangeReload() }
    }

    private func diagnosticsCard(_ rows: [App2MetricDiagnosticRow]) -> some View {
        App2Card(spacing: 0) {
            Text(L10n.App2.Metric.capabilityHowTitle.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .padding(.bottom, 8)

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle().fill(App2Theme.insetBorder).frame(height: 1)
                }
                HStack(spacing: 10) {
                    Text(row.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(App2Theme.inkSubtle)
                    Spacer(minLength: 6)
                    Text(row.value)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let detail = row.detail {
                        Text(detail)
                            .font(.app2Mono(11, weight: .semibold))
                            .foregroundStyle(App2Theme.inkFaint)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 9)
            }
        }
        .accessibilityIdentifier("App2_MetricDiagnostics")
    }
}

// MARK: - 相對能力兩格（有氧續航／速度耐力）

/// 有氧續航／速度耐力的詳情頁。
///
/// **整頁沒有網路呼叫**：0–100 相對能力量尺的逐週對照序列還沒有 producer
/// （SPEC-today-state §11-7），所以這一頁能講的全部在首頁那一列裡 ——
/// hero 用 `value_text`／`verdict`／`evidence`，加上一段固定的「這個指標量什麼」。
/// `insufficient_data` 時多一塊把限制句展開成「還差什麼」（2026-08-29 裁決）。
///
/// **不畫圖也不畫統計三欄**：那兩者需要序列，編一個出來就是把缺口偽裝成內容。
private struct App2LevelDetailPage: View {
    let kind: App2MetricDetailKind
    let insight: App2Insight
    let onClose: () -> Void

    /// 兩格各自的色（同其他頁的作法：色綁頁，不綁方向 —— 這兩格恆無方向，
    /// 用 `insight.tint` 會讓整頁變灰）。
    private var tint: Color {
        kind == .speedEndurance ? App2Theme.accentViolet : App2Theme.accentBlueDeep
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_\(kind.rawValue)",
            onClose: onClose
        ) {
            App2MetricHeroCard(
                hero: App2MetricDetailProjection.levelHero(insight: insight),
                symbolName: insight.symbolName,
                tint: tint
            )

            if let shortfall = App2MetricDetailProjection.levelShortfall(
                insight: insight, kind: kind
            ) {
                explanationCard(
                    title: L10n.App2.Metric.levelShortfallTitle.localized,
                    body: shortfall,
                    identifier: "App2_MetricLevelShortfall"
                )
            }

            explanationCard(
                title: L10n.App2.Metric.levelAboutTitle.localized,
                body: App2MetricDetailProjection.levelAbout(kind),
                identifier: "App2_MetricLevelAbout"
            )
        }
    }

    private func explanationCard(title: String, body: String, identifier: String) -> some View {
        App2Card(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(body)
                .font(.system(size: 13, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - §53 恢復

private struct App2RecoveryDetailPage: View {
    let insight: App2Insight
    let narrative: String?
    let onClose: () -> Void

    @StateObject private var viewModel: App2RecoveryDetailViewModel

    init(insight: App2Insight, narrative: String?, onClose: @escaping () -> Void) {
        self.insight = insight
        self.narrative = narrative
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: App2RecoveryDetailViewModel(
            insight: insight,
            narrative: narrative
        ))
    }

    var body: some View {
        App2MetricDetailScaffold(
            title: insight.label,
            identifier: "App2_MetricDetail_recovery_index",
            onClose: onClose
        ) {
            App2MetricHeroCard(
                hero: viewModel.detail?.value.hero
                    ?? App2RecoveryDetailViewModel.hero(insight: insight, narrative: narrative),
                symbolName: insight.symbolName,
                tint: App2Theme.accentGreenDot
            )

            if let detail = viewModel.detail?.value {
                App2Card(spacing: 12) {
                    Text(L10n.App2.Metric.recoveryChartTitle.localized)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)

                    App2MetricLineChart(
                        series: [
                            .init(
                                id: "hrv",
                                points: detail.hrv,
                                tint: App2Theme.accentGreenDot,
                                legend: L10n.App2.Metric.recoveryHrv.localized
                            ),
                            .init(
                                id: "rhr",
                                points: detail.restingHR,
                                tint: App2Theme.appleHealthRed,
                                legend: L10n.App2.Metric.recoveryRhr.localized
                            )
                        ],
                        xLabels: App2VolumeDetailPage.xLabels(detail.hrv),
                        height: 118
                    )

                    App2MetricStatRow(stats: detail.stats)
                }
            } else if viewModel.isLoading {
                App2Card { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }
}
