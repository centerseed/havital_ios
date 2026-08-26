import SwiftUI

// MARK: - App2WorkoutDetailView
/// 2.0 訓練詳情（**已完成的一筆跑步紀錄**）—— 設計 **frame-15**／dc.html
/// 「訓練詳情 · 總覽」，兩張 sheet 是 frame-16「納入計算」與 frame-17「編輯與工具」。
///
/// **這是殼，不是第二套實作。** ViewModel 直接用 1.4 的
/// `WorkoutDetailViewModelV2`（`GET /v2/workouts/{id}` ＋ `WorkoutRepository`），
/// 里程校正與時間裁剪也是 1.4 既有的 `TreadmillCorrectionView`／`TrimEditorView`。
/// 這一頁不新增任何寫入路徑。
///
/// 與 `App2SessionDetailView` 不同：那一頁是**課表上還沒跑的一天**。
struct App2WorkoutDetailView: View {

    @StateObject private var viewModel: WorkoutDetailViewModelV2
    @ObservedObject private var unitManager = UnitManager.shared
    /// 只為區間 chip 的 fallback（`hr_zone_distribution` 缺席時用 avgHR 對用戶心率
    /// 區間推落點，設計 frame-02f）讀 profile 的 `max_hr`／`relaxing_hr`——這一頁
    /// 不新增第二份 profile 讀寫路徑，用的是既有 `UserProfileFeatureViewModel`。
    @StateObject private var profileViewModel = UserProfileFeatureViewModel()
    let onClose: () -> Void
    /// 刪除成功時通知呼叫端刷新清單（刪掉的那一筆不能還留在紀錄頁上）。
    var onDeleted: (() -> Void)?

    /// frame-16／frame-17 兩張二層面板。
    ///
    /// **它們是同層的 overlay，不是 `.sheet`。** 這一頁本身是被
    /// `fullScreenCover` 推出來的，從裡面再 present 的 `.sheet` 內容
    /// **完全不會進 accessibility tree**（2026-08-25 maestro 實測：
    /// `maestro hierarchy` 只看得到底下那一頁，sheet 的每一顆鈕都不在）。
    /// 畫成同一層的 overlay 之後視覺一樣是底部面板，但點得到、測得到。
    @State private var activePanel: Panel?
    /// 里程校正／時間裁剪走 `.sheet` —— 它們是 1.4 既有的 view，
    /// 不為了這一頁改它們的呈現方式。代價是同一個 a11y 限制（見上），
    /// 這兩張的 UI 測試要用座標點。
    @State private var activeSheet: Sheet?
    @State private var isUpdatingVDOT = false
    @State private var isReuploading = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var resultMessage: String?
    /// Rizo 教練分析預設截斷（設計 frame-02f 的「展開完整分析 ∨」）。
    @State private var isCoachAnalysisExpanded = false

    enum Panel: String, Identifiable {
        case vdotInclusion
        case tools
        var id: String { rawValue }
    }

    enum Sheet: String, Identifiable {
        case treadmillCorrection
        case trim
        var id: String { rawValue }
    }

    init(workout: WorkoutV2, onClose: @escaping () -> Void, onDeleted: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModelV2(workout: workout))
        self.onClose = onClose
        self.onDeleted = onDeleted
    }

    private var projection: App2WorkoutDetailProjection {
        App2WorkoutDetailProjection.make(
            workout: viewModel.workout,
            detail: viewModel.workoutDetail,
            personalBestLabel: personalBestLabel,
            unitSystem: unitManager.currentUnitSystem,
            maxHR: profileViewModel.userData?.maxHr,
            restingHR: profileViewModel.userData?.relaxingHr
        )
    }

    /// 破 PB 徽章文字。PB 判定沿用 VM 已經算好的
    /// `personalBestUpdatesForWorkout`，這裡不重算，只挑距離最大的那一筆來顯示。
    private var personalBestLabel: String? {
        guard let best = viewModel.personalBestUpdatesForWorkout
            .max(by: { $0.distancePriority < $1.distancePriority }) else { return nil }
        return String(
            format: L10n.App2.WorkoutDetail.newPersonalBest.localized,
            "\(best.distance)K"
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            page
            if let activePanel {
                // 面板後面的遮罩：點一下關閉（設計 frame-16／17 的暗底）。
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { self.activePanel = nil }
                    .transition(.opacity)
                panel(activePanel)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeOut(duration: 0.22), value: activePanel)
    }

    @ViewBuilder
    private func panel(_ panel: Panel) -> some View {
        switch panel {
        case .vdotInclusion: vdotInclusionPanel
        case .tools:         toolsPanel
        }
    }

    private var page: some View {
        VStack(spacing: 0) {
            App2PageHeader(
                title: L10n.App2.WorkoutDetail.title.localized,
                titleSize: 19,
                onBack: onClose,
                backIdentifier: "App2_WorkoutDetailBack",
                titleIdentifier: "App2_WorkoutDetailView"
            ) { EmptyView() }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 6)

            ScrollView {
                VStack(spacing: 14) {
                    let projection = projection
                    heroCard(projection)
                    metricsGrid(projection)
                    if projection.coachAnalysis != nil
                        || projection.plannedSummary != nil
                        || projection.actualSummary != nil {
                        coachCard(projection)
                    }
                    if !projection.advancedMetrics.isEmpty {
                        section(NSLocalizedString("workout.detail.advanced_metrics", comment: "進階指標")) {
                            advancedGrid(projection)
                        }
                    }
                    if let notes = projection.trainingNotes {
                        section(NSLocalizedString("workout.detail.training_notes_title", comment: "訓練心得")) {
                            notesCard(notes)
                        }
                    }
                    if hasTrend {
                        section(L10n.App2.WorkoutDetail.trendSection.localized) { trendCard }
                    }
                    section(L10n.App2.WorkoutDetail.recordSection.localized) {
                        recordActions(projection)
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.vertical, 14)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .task { await viewModel.loadWorkoutDetail() }
        .task { await profileViewModel.loadUserProfile() }
        .refreshable { await viewModel.refreshWorkoutDetail() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .treadmillCorrection:
                TreadmillCorrectionView(
                    currentCorrection: viewModel.workoutDetail?.correction,
                    isAlreadyCorrected: viewModel.workoutDetail?.isTreadmillCorrected == true,
                    onApply: { distance, incline, notes in
                        await Task {
                            await viewModel.applyTreadmillCorrection(
                                actualDistanceM: distance,
                                avgInclinePercent: incline,
                                notes: notes
                            )
                        }.tracked(from: "App2WorkoutDetailView: applyTreadmillCorrection").value
                    }
                )
            case .trim:
                TrimEditorView(
                    totalDurationS: Double(viewModel.workoutDetail?.basicMetrics?.totalDurationS ?? 0),
                    baseOffsetS: viewModel.workoutDetail?.appliedTrim?.keepStartS ?? 0,
                    isAlreadyTrimmed: viewModel.workoutDetail?.isTrimmed == true,
                    distanceSamples: trimDistanceSamples(),
                    onApply: { startS, endS in
                        await Task {
                            await viewModel.applyTrim(keepStartS: startS, keepEndS: endS)
                        }.tracked(from: "App2WorkoutDetailView: applyTrim").value
                    }
                )
            }
        }
        .alert(
            NSLocalizedString("workout.detail.delete_confirm_title", comment: "刪除運動紀錄"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(NSLocalizedString("common.cancel", comment: "取消"), role: .cancel) { }
            Button(NSLocalizedString("common.delete", comment: "刪除"), role: .destructive) {
                Task { await deleteWorkout() }
            }
        } message: {
            Text(NSLocalizedString("workout.detail.delete_confirm_message", comment: ""))
        }
        .alert(
            NSLocalizedString("workout.detail.reupload_result", comment: ""),
            isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    // MARK: - Hero（設計 frame-02f：課型色淡底描邊 ＋ icon 圓章 ＋ chip 列）

    /// hero 與 icon 圓章的主色＝課型色。對不出課型（`training_type` 缺席或不在
    /// 已知集合）就退成中性藍，不猜一個課型。
    private func accent(_ projection: App2WorkoutDetailProjection) -> Color {
        projection.dayType?.app2StripColor ?? App2Theme.accentBlue
    }

    private func heroCard(_ projection: App2WorkoutDetailProjection) -> some View {
        let accent = accent(projection)
        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.app2Darkened],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: projection.dayType?.app2SymbolName ?? "figure.run")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: accent.opacity(0.6), radius: 8, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(projection.title)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        // **只有這一趟真的破 PB 才畫**（判定來自成就系統的
                        // `personalBestUpdatesForWorkout`，不是這裡推的）。
                        if let pb = projection.personalBestLabel {
                            App2Pill(
                                text: pb,
                                foreground: .white,
                                background: App2Theme.accentOrangeBright
                            )
                            .accessibilityIdentifier("App2_WorkoutDetailPB")
                        }
                        Spacer(minLength: 0)
                    }
                    Text(projection.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSubtle)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                App2Chip(
                    text: projection.providerLabel,
                    foreground: App2Theme.inkSecondary,
                    background: App2Theme.shadowInk.opacity(0.05)
                )
                // 區間 chip 由實際均心對用戶心率區間分布推得（`hr_zone_distribution`
                // 佔比最大的那一段）。算不出來就沒有這顆 chip。
                if let zone = projection.dominantZoneLabel {
                    App2Chip(
                        text: zone,
                        foreground: accent.app2Darkened,
                        background: accent.opacity(0.13)
                    )
                    .accessibilityIdentifier("App2_WorkoutDetailZoneChip")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(App2Theme.heroPadding)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: accent.opacity(0.13), location: 0),
                            .init(color: accent.opacity(0.02), location: 0.6),
                            .init(color: .white, location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.28), radius: 12, x: 0, y: 8)
        .accessibilityIdentifier("App2_WorkoutDetailHero")
    }

    // MARK: - 指標磚（設計 frame-02f：2 欄、各自獨立的白底圓角磚）

    private func metricsGrid(_ projection: App2WorkoutDetailProjection) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(projection.metrics) { metric in
                metricCell(metric, valueSize: 22)
                    .app2CardSurface(cornerRadius: 16)
                    .accessibilityIdentifier("App2_WorkoutMetric_\(metric.key)")
            }
        }
        .accessibilityIdentifier("App2_WorkoutDetailMetrics")
    }

    /// **這一格不畫自己的底。** 底由呼叫端用 `app2CardSurface` 給——格子自己再蓋一層
    /// 方形白底的話，會直接把圓角覆蓋掉（2026-08-26 使用者指出「進階指標沒有圓角」
    /// 就是這個原因）。
    private func metricCell(_ metric: App2WorkoutDetailProjection.Metric, valueSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metric.label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(metric.value)
                    .font(.app2Mono(valueSize))
                    .foregroundStyle(color(for: metric.tone))
                if let unit = metric.unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func color(for tone: App2WorkoutDetailProjection.Metric.Tone) -> Color {
        switch tone {
        case .neutral:   return App2Theme.inkPrimary
        case .pace:      return App2Theme.accentBlueDeep
        case .heartRate: return App2Theme.appleHealthRed
        }
    }

    // MARK: - Rizo 教練分析（課表 vs 實際）

    private func coachCard(_ projection: App2WorkoutDetailProjection) -> some View {
        App2AccentCard(strength: 0.11, padding: 16, spacing: 13) {
            HStack(spacing: 9) {
                App2Avatar(initial: "R", size: 26, showsRing: false)
                Text(L10n.App2.WorkoutDetail.coachSection.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 0)
                // 設計 frame-02f 右上有一顆判定 chip（「符合課表」）。
                // **後端沒有這個欄位**：`AISummary` 只有 `analysis` 一個 String，
                // `DailyPlanSummary` 也沒有達成度／判定欄（2026-08-26 查過整份
                // `WorkoutV2Models.swift`）。自己用課表 vs 實際去推一個判定就是
                // 在 app 端發明一則教練判斷 —— 依既有裁決，缺欄位就不畫空 chip。
            }

            if projection.plannedSummary != nil || projection.actualSummary != nil {
                HStack(spacing: 10) {
                    if let planned = projection.plannedSummary {
                        comparisonBox(
                            label: L10n.App2.WorkoutDetail.planned.localized,
                            value: planned,
                            valueColor: App2Theme.inkSecondary
                        )
                    }
                    if let actual = projection.actualSummary {
                        comparisonBox(
                            label: L10n.App2.WorkoutDetail.actual.localized,
                            value: actual,
                            valueColor: App2Theme.inkPrimary
                        )
                    }
                }
            }

            if let analysis = projection.coachAnalysis {
                Text(analysis)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .lineSpacing(4)
                    .lineLimit(isCoachAnalysisExpanded ? nil : Self.coachAnalysisCollapsedLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("App2_WorkoutDetailCoachAnalysis")

                // 「展開完整分析 ∨」。**沒有截斷就沒有這一列** —— 三行以內的分析
                // 掛一顆展開鈕是個假動作。
                if analysis.count > Self.coachAnalysisCollapseThreshold {
                    HStack(spacing: 5) {
                        Text(
                            (isCoachAnalysisExpanded
                                ? L10n.App2.WorkoutDetail.collapseAnalysis
                                : L10n.App2.WorkoutDetail.expandAnalysis).localized
                        )
                        .font(.system(size: 13, weight: .heavy))
                        Image(systemName: isCoachAnalysisExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isCoachAnalysisExpanded.toggle()
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_WorkoutDetailCoachExpand")
                }
            }
        }
        .accessibilityIdentifier("App2_WorkoutDetailCoach")
    }

    /// 收合時顯示幾行（設計 frame-02f 是 2–3 行）。
    private static let coachAnalysisCollapsedLines = 3
    /// 超過這個字數才可能被截斷 —— 低於就不畫展開鈕。
    private static let coachAnalysisCollapseThreshold = 60

    private func comparisonBox(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(App2Theme.inkMuted)
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // 設計 frame-02f：藍淡底卡上的兩張小卡是**白底**，不是灰的卡中卡。
        .app2InsetSurface(cornerRadius: 13, fill: App2Theme.cardBackground)
    }

    // MARK: - 進階指標（設計 frame-02e：白底大圓角卡）

    private func advancedGrid(_ projection: App2WorkoutDetailProjection) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(projection.advancedMetrics) { metric in
                metricCell(metric, valueSize: 21)
                    .app2CardSurface(cornerRadius: 16)
                    .accessibilityIdentifier("App2_WorkoutAdvancedMetric_\(metric.key)")
            }
        }
    }

    private func notesCard(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(App2Theme.accentBlue)
                .frame(width: 3)
            Text(notes)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(App2Theme.inkSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .app2CardSurface(cornerRadius: 16)
        .accessibilityIdentifier("App2_WorkoutDetailNotes")
    }

    // MARK: - 趨勢圖

    private var hasTrend: Bool {
        viewModel.heartRates.count >= 2 || viewModel.paces.count >= 2
    }

    private var trendCard: some View {
        App2Card(padding: 15, spacing: 14) {
            if viewModel.heartRates.count >= 2 {
                trendBlock(
                    title: L10n.App2.WorkoutDetail.trendHeartRate.localized,
                    dot: App2Theme.appleHealthRed,
                    caption: viewModel.maxHeartRateString,
                    points: viewModel.heartRates.map(\.value),
                    tint: App2Theme.appleHealthRed,
                    isInverted: false
                )
            }
            if viewModel.paces.count >= 2 {
                trendBlock(
                    title: L10n.App2.WorkoutDetail.trendPace.localized,
                    dot: App2Theme.accentBlue,
                    caption: nil,
                    points: viewModel.paces.map(\.value),
                    tint: App2Theme.accentBlue,
                    // 配速小＝快，不反轉的話「變快」會畫成往下掉。
                    isInverted: true
                )
            }
        }
        .accessibilityIdentifier("App2_WorkoutDetailTrend")
    }

    private func trendBlock(
        title: String,
        dot: Color,
        caption: String?,
        points: [Double],
        tint: Color,
        isInverted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle().fill(dot).frame(width: 9, height: 9)
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 6)
                if let caption {
                    Text(caption)
                        .font(.app2Mono(11, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
            }
            App2Sparkline(points: points, tint: tint, isInverted: isInverted)
        }
    }

    // MARK: - 這筆紀錄（兩列 → 兩張 sheet）

    private func recordActions(_ projection: App2WorkoutDetailProjection) -> some View {
        App2GroupedList {
            App2SettingsRow(
                systemImage: "bolt.fill",
                iconTint: App2Theme.accentOrange,
                iconBackground: App2Theme.accentOrange.opacity(0.12),
                title: L10n.App2.WorkoutDetail.vdotRow.localized,
                value: projection.vdotInclusion.rowValueLabel
            )
            .contentShape(Rectangle())
            .onTapGesture { activePanel = .vdotInclusion }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_WorkoutVDOTRow")

            App2SettingsRow(
                systemImage: "wrench.and.screwdriver",
                iconTint: App2Theme.inkSubtle,
                iconBackground: App2Theme.shadowInk.opacity(0.06),
                title: L10n.App2.WorkoutDetail.toolsRow.localized,
                value: "",
                showsDivider: false
            )
            .contentShape(Rectangle())
            .onTapGesture { activePanel = .tools }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_WorkoutToolsRow")
        }
    }

    // MARK: - 納入 VDOT 計算 sheet（設計 frame-16）

    private var vdotInclusionPanel: some View {
        let current = projection.vdotInclusion
        return App2ActionPanel(
            title: L10n.App2.WorkoutDetail.vdotRow.localized,
            subtitle: L10n.App2.WorkoutDetail.vdotSubtitle.localized,
            onDone: { activePanel = nil },
            identifier: "App2_VDOTInclusionPanel"
        ) {
            App2GroupedList {
                vdotOption(
                    .automatic,
                    title: L10n.App2.WorkoutDetail.vdotAutomatic.localized,
                    detail: L10n.App2.WorkoutDetail.vdotAutomaticDesc.localized,
                    current: current,
                    showsDivider: true
                )
                vdotOption(
                    .included,
                    title: L10n.App2.WorkoutDetail.vdotIncluded.localized,
                    detail: L10n.App2.WorkoutDetail.vdotIncludedDesc.localized,
                    current: current,
                    showsDivider: true
                )
                vdotOption(
                    .excluded(reason: nil),
                    title: L10n.App2.WorkoutDetail.vdotExcluded.localized,
                    detail: L10n.App2.WorkoutDetail.vdotExcludedDesc.localized,
                    current: current,
                    showsDivider: false
                )
            }
        }
    }

    private func vdotOption(
        _ option: App2WorkoutDetailProjection.VDOTInclusion,
        title: String,
        detail: String,
        current: App2WorkoutDetailProjection.VDOTInclusion,
        showsDivider: Bool
    ) -> some View {
        let isSelected = option.isSameChoice(as: current)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.app2RowTitle)
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(detail)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isUpdatingVDOT {
                    ProgressView().frame(width: 20, height: 20)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? App2Theme.accentBlue : App2Theme.chevron)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture { Task { await applyVDOT(option) } }

            if showsDivider {
                Rectangle().fill(App2Theme.insetBorder).frame(height: 1).padding(.leading, 15)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_VDOTOption_\(optionKey(option))")
    }

    private func optionKey(_ option: App2WorkoutDetailProjection.VDOTInclusion) -> String {
        switch option {
        case .automatic: return "automatic"
        case .included:  return "included"
        case .excluded:  return "excluded"
        }
    }

    private func applyVDOT(_ option: App2WorkoutDetailProjection.VDOTInclusion) async {
        guard !isUpdatingVDOT else { return }
        isUpdatingVDOT = true
        // 唯一的 VDOT override 寫入路徑（1.4 既有），不另開一條。
        _ = await Task {
            await viewModel.updateVDOTOverride(option.request)
        }.tracked(from: "App2WorkoutDetailView: updateVDOTOverride").value
        isUpdatingVDOT = false
        activePanel = nil
    }

    // MARK: - 編輯與工具 sheet（設計 frame-17）

    private var toolsPanel: some View {
        App2ActionPanel(
            title: L10n.App2.WorkoutDetail.toolsRow.localized,
            subtitle: nil,
            onDone: { activePanel = nil },
            identifier: "App2_WorkoutToolsPanel"
        ) {
            App2GroupedList {
                toolRow(
                    systemImage: "ruler",
                    title: NSLocalizedString("workout.detail.treadmill_correction_title", comment: "里程校正"),
                    detail: L10n.App2.WorkoutDetail.toolMileageSub.localized,
                    identifier: "App2_ToolMileage",
                    isEnabled: isTreadmillRun,
                    isDestructive: false
                ) { present(.treadmillCorrection) }

                toolRow(
                    systemImage: "scissors",
                    title: NSLocalizedString("workout.detail.trim_title", comment: "時間裁剪"),
                    detail: L10n.App2.WorkoutDetail.toolTrimSub.localized,
                    identifier: "App2_ToolTrim",
                    isEnabled: isTrimmable,
                    isDestructive: false
                ) { present(.trim) }

                toolRow(
                    systemImage: "arrow.clockwise",
                    title: NSLocalizedString("workout.detail.reupload", comment: "重新上傳"),
                    detail: L10n.App2.WorkoutDetail.toolReuploadSub.localized,
                    identifier: "App2_ToolReupload",
                    isEnabled: !isReuploading,
                    isDestructive: false
                ) { Task { await reupload() } }

                toolRow(
                    systemImage: "trash",
                    title: NSLocalizedString("workout.detail.delete_workout", comment: "刪除紀錄"),
                    detail: L10n.App2.WorkoutDetail.toolDeleteSub.localized,
                    identifier: "App2_ToolDelete",
                    isEnabled: !isDeleting,
                    isDestructive: true,
                    showsDivider: false
                ) {
                    activePanel = nil
                    showDeleteConfirmation = true
                }
            }
        }
    }

    /// 選了里程校正／時間裁剪：先收掉工具面板，再推 1.4 的編輯器。
    private func present(_ sheet: Sheet) {
        activePanel = nil
        activeSheet = sheet
    }

    private func toolRow(
        systemImage: String,
        title: String,
        detail: String,
        identifier: String,
        isEnabled: Bool,
        isDestructive: Bool,
        showsDivider: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDestructive
                          ? App2Theme.accentRed.opacity(0.12)
                          : App2Theme.accentBlue.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isDestructive ? App2Theme.accentRed : App2Theme.accentBlueDeep)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.app2RowTitle)
                        .foregroundStyle(isDestructive ? App2Theme.accentRed : App2Theme.inkPrimary)
                    Text(detail)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(App2Theme.chevron)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
            .onTapGesture { if isEnabled { action() } }

            if showsDivider {
                Rectangle().fill(App2Theme.insetBorder).frame(height: 1).padding(.leading, 59)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 工具的可用條件（與 1.4 同一組判斷，不放寬）

    private var isTreadmillRun: Bool {
        let type = (viewModel.workoutDetail?.activityType ?? viewModel.workout.activityType).lowercased()
        return type.contains("treadmill") || type.contains("indoor_running")
    }

    private var isTrimmable: Bool {
        guard let detail = viewModel.workoutDetail else { return false }
        guard detail.isTrimmableActivity else { return false }
        return (detail.basicMetrics?.totalDurationS ?? 0) >= 120
    }

    /// 裁剪編輯器把手旁的里程縮圖：`顯示時間軸 → 累積距離`，兩軸都 rebase 到 0。
    /// 距離缺失或長度對不上就回空陣列——編輯器會退成純時間軸，不要餵半截資料進去。
    private func trimDistanceSamples() -> [TrimDistanceSample] {
        guard let series = viewModel.workoutDetail?.timeSeries,
              let times = series.timestampsS,
              let distances = series.distancesM,
              times.count == distances.count,
              !times.isEmpty else { return [] }

        var pairs: [(Double, Double)] = []
        for index in times.indices {
            if let time = times[index], let distance = distances[index] {
                pairs.append((Double(time), distance))
            }
        }
        guard let t0 = pairs.first?.0, let d0 = pairs.first?.1 else { return [] }
        return pairs.map { TrimDistanceSample(t: $0.0 - t0, d: max(0, $0.1 - d0)) }
    }

    // MARK: - 動作

    private func reupload() async {
        guard !isReuploading else { return }
        isReuploading = true
        let success = await Task {
            await viewModel.reuploadWorkout()
        }.tracked(from: "App2WorkoutDetailView: reuploadWorkout").value
        isReuploading = false
        activePanel = nil
        resultMessage = success
            ? NSLocalizedString("workout.reupload_success", comment: "")
            : NSLocalizedString("workout.reupload_failed", comment: "")
    }

    private func deleteWorkout() async {
        guard !isDeleting else { return }
        isDeleting = true
        let success = await Task {
            await viewModel.deleteWorkout()
        }.tracked(from: "App2WorkoutDetailView: deleteWorkout").value
        isDeleting = false
        if success {
            onDeleted?()
            onClose()
        } else {
            resultMessage = NSLocalizedString("workout.detail.delete_failed", comment: "")
        }
    }

    // MARK: - 區塊小標

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            App2SectionCaption(text: title)
            content()
        }
    }
}

// MARK: - App2ActionPanel
/// frame-16／frame-17 兩張底部面板共用的外框：抓握條 ＋ 標題列（右側「完成」）
/// ＋ 選填副標 ＋ 內容。兩張的差別只有內容，外框不寫兩次。
///
/// 是 overlay 不是 `.sheet` —— 理由見 `App2WorkoutDetailView.activePanel`。
struct App2ActionPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let onDone: () -> Void
    let identifier: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(App2Theme.chevron)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)

            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    // 標記掛標題這顆葉節點。掛在最外層容器會被 SwiftUI 蓋到每個子
                    // 節點上，sheet 裡的每顆鈕就都叫同一個名字（`App2PageHeader`
                    // 同一個坑，2026-08-25 maestro 實測）。
                    .accessibilityIdentifier(identifier)
                Spacer(minLength: 8)
                Text(NSLocalizedString("common.done", comment: "完成"))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlue)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDone)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("\(identifier)_Done")
            }
            .padding(.horizontal, App2Theme.pagePadding)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .padding(.horizontal, App2Theme.pagePadding)
                    .padding(.top, 6)
            }

            ScrollView {
                content()
                    .padding(.horizontal, App2Theme.pagePadding)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .frame(maxHeight: 420)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.bottom, 24)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 26,
                style: .continuous
            )
            .fill(App2Theme.pageTop)
            .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: App2Theme.shadowInk.opacity(0.25), radius: 24, x: 0, y: -8)
    }
}
