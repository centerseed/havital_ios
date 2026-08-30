import SwiftUI

// MARK: - App2WeeklyReviewTarget
/// `fullScreenCover(item:)` 要 `Identifiable`，而「第幾週」是個 `Int`。
/// 包一層而不是給 `Int` 加 `Identifiable` extension —— 那會汙染全 app 的 `Int`。
struct App2WeeklyReviewTarget: Identifiable, Equatable {
    let weekOfPlan: Int
    /// 歷史週的唯讀回看（2026-08-27 走查裁決（q））。見 `App2WeeklyReviewView.isReadOnly`。
    var isReadOnly: Bool = false
    /// 目標週是不是本週。非本週時分頁與套用鈕改用「第 N 週」措辭（dev QA D2：
    /// 對上週的回顧寫「回顧本週」）。預設 false——說錯週次比說錯「本週」輕。
    var isCurrentWeek: Bool = false
    var id: Int { weekOfPlan }
}

// MARK: - App2WeeklyReviewView
/// 2.0 週回顧 —— 設計 **frame-18「回顧本週」** / **frame-19「規劃下週」**
/// （dc.html 同名畫面）。兩個分頁共用同一份 `WeeklySummaryV2`，切分頁不重打端點。
///
/// **這是殼。** 載入／產生／採納全部走 `App2WeeklyReviewViewModel` →
/// 1.4 既有的 `WeeklySummaryCoordinator`，付費閘門與 Rizo 額度攔截原樣接上。
struct App2WeeklyReviewView: View {

    @StateObject private var viewModel: App2WeeklyReviewViewModel
    let onClose: () -> Void
    /// 套用建議後通知呼叫端刷新（下週課表換了，首頁的卡要跟著換）。
    var onApplied: (() -> Void)?
    /// 歷史週的唯讀回看（2026-08-27 走查裁決（q）：課表頁 header 的週回顧入口）。
    ///
    /// 唯讀時收掉兩個寫入動作：
    /// - 「產生回顧」——`generateWeeklySummary()` 產的是**當週**，對過去那一週按下去
    ///   會產錯週；那一週沒有回顧就是沒有，說清楚即可。
    /// - 「套用到下週課表」——過去那一週的建議套到下週是錯的時間軸。
    private let isReadOnly: Bool
    /// 看的是哪一週、它是不是本週——非本週時「回顧本週／規劃下週／套用到下週」
    /// 全是錯的相對詞（平日 CTA 開的是上週回顧），改用「第 N 週」措辭（dev QA D2）。
    private let weekOfPlan: Int
    private let isCurrentWeek: Bool

    @State private var tab: Tab = .review

    enum Tab: String, CaseIterable {
        case review
        case plan
    }

    private func tabTitle(_ item: Tab) -> String {
        switch item {
        case .review:
            return isCurrentWeek
                ? L10n.App2.WeeklyReview.tabReview.localized
                : String(format: L10n.App2.WeeklyReview.tabReviewWeek.localized, weekOfPlan)
        case .plan:
            return isCurrentWeek
                ? L10n.App2.WeeklyReview.tabPlan.localized
                : String(format: L10n.App2.WeeklyReview.tabPlanWeek.localized, weekOfPlan + 1)
        }
    }

    init(
        weekOfPlan: Int,
        isReadOnly: Bool = false,
        isCurrentWeek: Bool = false,
        onClose: @escaping () -> Void,
        onApplied: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: App2WeeklyReviewViewModel(weekOfPlan: weekOfPlan))
        self.weekOfPlan = weekOfPlan
        self.isReadOnly = isReadOnly
        self.isCurrentWeek = isCurrentWeek
        self.onClose = onClose
        self.onApplied = onApplied
    }

    var body: some View {
        VStack(spacing: 0) {
            App2PageHeader(
                title: L10n.App2.WeeklyReview.title.localized,
                titleSize: 19,
                onBack: onClose,
                backIdentifier: "App2_WeeklyReviewBack",
                titleIdentifier: "App2_WeeklyReviewView"
            ) { EmptyView() }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 6)

            segmentedTabs
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.top, 12)

            content

            // 「套用到下週課表」只在規劃分頁出現 —— 回顧分頁沒有可套用的東西。
            // 歷史週唯讀回看也沒有（裁決（q））。
            if !isReadOnly, tab == .plan, let projection = viewModel.projection,
               !projection.suggestions.isEmpty {
                applyFooter
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        // 套用成功的回饋。VM 一直有在發 `toast`，但這裡先前沒有渲染它 ——
        // 按下「套用」畫面毫無反應，只有 Firestore 知道成功了。
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                Text(toast)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(App2Theme.inkPrimary.opacity(0.92)))
                    .padding(.bottom, 96)
                    .transition(.opacity)
                    .accessibilityIdentifier("App2_WeeklyReviewToast")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toast)
        .onChange(of: viewModel.toast) { _, value in
            guard value != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                viewModel.toast = nil
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .alert(
            L10n.App2.WeeklyReview.quotaTitle.localized,
            isPresented: $viewModel.showsQuotaExceeded
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(L10n.App2.WeeklyReview.quotaBody.localized)
        }
        .alert(
            L10n.App2.WeeklyReview.upsellTitle.localized,
            isPresented: $viewModel.showsUpsell
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(L10n.App2.WeeklyReview.upsellBody.localized)
        }
    }

    // MARK: - 分頁切換器（設計的膠囊 segment）

    private var segmentedTabs: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.rawValue) { item in
                Text(tabTitle(item))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(tab == item ? App2Theme.inkPrimary : App2Theme.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if tab == item {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(App2Theme.cardBackground)
                                .shadow(color: App2Theme.shadowInk.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { tab = item }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_WeeklyReviewTab_\(item.rawValue)")
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(App2Theme.shadowInk.opacity(0.05))
        )
    }

    // MARK: - 內容

    @ViewBuilder
    private var content: some View {
        if let projection = viewModel.projection {
            ScrollView {
                VStack(spacing: 14) {
                    switch tab {
                    case .review: reviewTab(projection)
                    case .plan:   planTab(projection)
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.vertical, 14)
            }
        } else if viewModel.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.needsGeneration {
            generatePrompt
        } else {
            Spacer()
            VStack(spacing: 10) {
                Text(viewModel.errorMessage ?? L10n.App2.Common.loadFailed.localized)
                    .font(.app2Body)
                    .foregroundStyle(App2Theme.inkTertiary)
                    .multilineTextAlignment(.center)
                Text(L10n.App2.Common.retry.localized)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlue)
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await viewModel.load() } }
                    .accessibilityAddTraits(.isButton)
            }
            .padding(.horizontal, 40)
            .accessibilityIdentifier("App2_WeeklyReviewError")
            Spacer()
        }
    }

    /// 這一週還沒有回顧。**這不是錯誤畫面** —— 只是還沒按產生。
    ///
    /// 唯讀回看（歷史週）沒有產生鈕：那顆鈕產的是當週，對過去那一週按下去會產錯週。
    private var generatePrompt: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(App2Theme.accentBlue)
            Text(
                isReadOnly
                    ? L10n.App2.WeeklyReview.historyNotGeneratedBody.localized
                    : L10n.App2.WeeklyReview.notGeneratedBody.localized
            )
            .font(.app2Body)
            .foregroundStyle(App2Theme.inkTertiary)
            .multilineTextAlignment(.center)
            if !isReadOnly {
                primaryButton(
                    title: L10n.App2.WeeklyReview.generate.localized,
                    isBusy: viewModel.isLoading,
                    identifier: "App2_WeeklyReviewGenerate"
                ) {
                    Task { await viewModel.generate() }
                }
                .padding(.horizontal, App2Theme.pagePadding)
            }
            Spacer()
        }
        .accessibilityIdentifier("App2_WeeklyReviewNotGenerated")
    }

    // MARK: - 回顧本週（frame-18）

    @ViewBuilder
    private func reviewTab(_ projection: App2WeeklyReviewProjection) -> some View {
        storyCard(projection)
        if !projection.stats.isEmpty {
            section(L10n.App2.WeeklyReview.statsSection.localized) { statsGrid(projection.stats) }
        }
        if !projection.highlights.isEmpty || !projection.improvements.isEmpty {
            section(L10n.App2.WeeklyReview.highlightsSection.localized) {
                // 亮點與「要注意的」在**同一張卡**，但各自的圖示不同（8/28 盤點 D7）：
                // 一個是做到了什麼（橘星），一個是要注意什麼（藍上升箭頭，同 Android）。
                // 兩組都空才整段不出現。
                bulletCard(
                    projection.highlights.map {
                        (text: $0, symbol: "star.fill", tint: App2Theme.accentOrangeBright)
                    } + projection.improvements.map {
                        (text: $0, symbol: "arrow.up.right", tint: App2Theme.accentBlueDeep)
                    }
                )
                .accessibilityIdentifier("App2_WeeklyReviewHighlights")
            }
        }
        if !projection.observations.isEmpty {
            section(L10n.App2.WeeklyReview.observationsSection.localized) {
                bulletCard(
                    projection.observations.map {
                        (text: $0, symbol: "eye.fill", tint: App2Theme.accentBlueDeep)
                    }
                )
                .accessibilityIdentifier("App2_WeeklyReviewObservations")
            }
        }
        if !projection.analysisNotes.isEmpty {
            section(L10n.App2.WeeklyReview.analysisSection.localized) {
                App2Card(padding: 15, spacing: 14) {
                    ForEach(projection.analysisNotes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(App2Theme.inkMuted)
                            Text(note.body)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(App2Theme.inkSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .accessibilityIdentifier("App2_WeeklyReviewAnalysis")
            }
        }
    }

    private func storyCard(_ projection: App2WeeklyReviewProjection) -> some View {
        App2AccentCard(strength: 0.12, padding: App2Theme.heroPadding, spacing: 9) {
            Text(projection.weekKicker)
                .font(.system(size: 13, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(App2Theme.accentBlueDeep)
            if let body = projection.storyBody {
                Text(body)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("App2_WeeklyReviewStory")
    }

    private func statsGrid(_ stats: [App2WeeklyReviewProjection.Stat]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(stat.value)
                            .font(.app2Mono(22))
                            .foregroundStyle(App2Theme.inkPrimary)
                        if let unit = stat.unit {
                            Text(unit)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(App2Theme.inkMuted)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    // footnote 自成一行：跟數值擠同一行時（`planned 15.6 km`）
                    // 在兩欄格寬裡一定被截尾。
                    if let footnote = stat.footnote {
                        Text(footnote)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(App2Theme.inkTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .app2CardSurface(cornerRadius: 15)
                .accessibilityIdentifier("App2_WeeklyReviewStat_\(stat.key)")
            }
        }
    }

    /// 一張條列卡。**每一列自己帶圖示與顏色**（8/28 盤點 D7）：亮點與「要注意的」
    /// 在同一張卡上，但它們是相反的兩件事，共用一顆星號就分不出來。
    private func bulletCard(_ rows: [(text: String, symbol: String, tint: Color)]) -> some View {
        App2Card(padding: 15, spacing: 11) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(row.tint)
                        .padding(.top, 3)
                    Text(row.text)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 規劃下週（frame-19）

    @ViewBuilder
    private func planTab(_ projection: App2WeeklyReviewProjection) -> some View {
        verdictCard(projection)
        if projection.suggestions.isEmpty {
            App2Card(padding: 15, spacing: 6) {
                Text(L10n.App2.WeeklyReview.noSuggestions.localized)
                    .font(.app2Body)
                    .foregroundStyle(App2Theme.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("App2_WeeklyReviewNoSuggestions")
        } else {
            section(
                String(
                    format: L10n.App2.WeeklyReview.suggestionsSection.localized,
                    projection.suggestions.count
                )
            ) {
                VStack(spacing: 10) {
                    ForEach(projection.suggestions) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
            }
        }
    }

    private func verdictCard(_ projection: App2WeeklyReviewProjection) -> some View {
        App2AccentCard(strength: 0.11, padding: 16, spacing: 11) {
            HStack(spacing: 9) {
                App2Avatar(initial: "R", size: 26, showsRing: false)
                Text(L10n.App2.WeeklyReview.nextWeekTitle.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 6)
                if let phase = projection.phaseLabel {
                    App2Chip(
                        text: phase,
                        foreground: App2Theme.accentBlueDeep,
                        background: App2Theme.accentBlue.opacity(0.12)
                    )
                }
            }
            if let summary = projection.nextWeekSummary {
                Text(summary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("App2_WeeklyReviewVerdict")
    }

    /// 一則建議。**只有接受／略過兩態** —— 後端的 `apply-items` 就是二元的
    /// `applied_indices`，設計稿的「調整」需要 per-item 調整值，目前沒有那個出口。
    private func suggestionCard(_ suggestion: App2WeeklyReviewProjection.Suggestion) -> some View {
        let isSelected = viewModel.selections[suggestion.index] ?? suggestion.defaultApply
        return App2LeftStripCard(
            strip: priorityColor(suggestion.priority),
            padding: EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15)
        ) {
            Text(suggestion.content)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !suggestion.reason.isEmpty {
                Text(suggestion.reason)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !suggestion.impact.isEmpty {
                Text(suggestion.impact)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                choiceChip(
                    title: L10n.App2.WeeklyReview.accept.localized,
                    isOn: isSelected,
                    tint: App2Theme.accentGreen
                )
                choiceChip(
                    title: L10n.App2.WeeklyReview.skip.localized,
                    isOn: !isSelected,
                    tint: App2Theme.inkTertiary
                )
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .contentShape(Rectangle())
            // 唯讀回看不可切換：footer 已收掉，能切卻送不出去是死路（切了也只會被
            // 靜默丟棄）。
            .onTapGesture {
                guard !isReadOnly else { return }
                viewModel.toggle(suggestionIndex: suggestion.index)
            }
            .opacity(isReadOnly ? 0.55 : 1)
            .accessibilityAddTraits(.isButton)
        }
        .accessibilityIdentifier("App2_WeeklyReviewSuggestion_\(suggestion.index)")
    }

    private func choiceChip(title: String, isOn: Bool, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 13, weight: .heavy))
        }
        .foregroundStyle(isOn ? tint : App2Theme.chevron)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.chipCornerRadius, style: .continuous)
                .fill(isOn ? tint.opacity(0.12) : App2Theme.shadowInk.opacity(0.04))
        )
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high":   return App2Theme.accentRed
        case "medium": return App2Theme.accentOrangeBright
        default:       return App2Theme.accentBlue
        }
    }

    private var applyFooter: some View {
        VStack(spacing: 0) {
            primaryButton(
                title: isCurrentWeek
                    ? String(
                        format: L10n.App2.WeeklyReview.applyToNextWeek.localized,
                        viewModel.selectedCount
                    )
                    : String(
                        format: L10n.App2.WeeklyReview.applyToWeek.localized,
                        viewModel.selectedCount,
                        weekOfPlan + 1
                    ),
                isBusy: viewModel.isApplying,
                identifier: "App2_WeeklyReviewApply"
            ) {
                Task {
                    if await viewModel.applySelected() { onApplied?() }
                }
            }
        }
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.top, 11)
        .padding(.bottom, 24)
        .background(App2Theme.pageBottom.ignoresSafeArea(edges: .bottom))
    }

    private func primaryButton(
        title: String,
        isBusy: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 9) {
            if isBusy {
                ProgressView().tint(.white)
            }
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(App2Theme.accentBlue)
        )
        .shadow(color: App2Theme.accentBlue.opacity(0.6), radius: 11, x: 0, y: 10)
        .opacity(isBusy ? 0.7 : 1)
        .contentShape(Rectangle())
        .onTapGesture { if !isBusy { action() } }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            App2SectionCaption(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
