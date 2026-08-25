import SwiftUI

// MARK: - App2PlanOverviewView
/// 2.0 訓練計畫總覽 —— 設計 **frame-20「訓練計劃」**。
///
/// 版面與設計一致：返回／標題／「調整」→ 深藍目標賽事 hero（現況→目標、計畫進度）
/// → 階段期程 → 訓練節奏 → 管理計畫 → 底部「跟 Rizo 討論計畫」。
///
/// **兩處與設計不同，都是「不擺死鈕」的取捨**：
/// - 訓練節奏三列是**唯讀**（沒有 chevron）。設計畫了 chevron，但週跑量／訓練日的
///   編輯入口在設定頁的訓練設定，這裡再開一條就是第二份寫入路徑。
/// - 管理計畫少了設計的「更換訓練方法」一列 —— app 端沒有更換方法論的寫入路徑，
///   放上去會是一顆按不動的列。票面已記為剩餘差異。
struct App2PlanOverviewView: View {

    let onClose: () -> Void
    @ObservedObject var viewModel: App2PlanOverviewViewModel

    /// 賽事管理（設計 frame-12）—— 由「調整」與「管理計畫 · 賽事管理」進入。
    @State private var isShowingRaces = false
    /// 重設目標走 2.0 的 onboarding（與設定頁同一條路徑，不另寫一份）。
    @State private var isShowingGoalSetup = false
    /// 「跟 Rizo 討論計畫」開既有的對話元件。
    @State private var isShowingRizoChat = false
    @State private var rizoChatViewModel: StateRizoChatViewModel?

    var body: some View {
        VStack(spacing: 0) {
            App2PageHeader(
                title: L10n.App2.PlanOverview.title.localized,
                titleSize: 19,
                onBack: onClose,
                backIdentifier: "App2_PlanOverviewClose",
                titleIdentifier: "App2_PlanOverviewView"
            ) {
                // 設計 frame-20 右上角的「調整」。目的地是賽事管理（frame-12）——
                // 週跑量／訓練日的編輯在設定頁，這裡不開第二條寫入路徑。
                Text(L10n.App2.PlanOverview.adjust.localized)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    .contentShape(Rectangle())
                    .onTapGesture { isShowingRaces = true }
                    // 併成單一葉節點 —— 不併的話 a11y tree 上只看得到那一顆 Text，
                    // identifier 掛不上去（2026-08-25 maestro 實測找不到這顆）。
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(L10n.App2.PlanOverview.adjust.localized)
                    .accessibilityIdentifier("App2_PlanOverviewAdjust")
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let sourced = viewModel.overview {
                        heroCard(sourced.value)
                        stagesSection(sourced.value)
                        rhythmSection(sourced.value.rhythm)
                        manageSection
                        autoAdjustNote
                    } else if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.bottom, 20)
            }

            rizoCta
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.forceRefresh() }
        .fullScreenCover(isPresented: $isShowingRaces) {
            App2RaceManagementView(onClose: {
                isShowingRaces = false
                // 改過賽事之後，這一頁的目標賽事與週數要重取。
                Task { await viewModel.forceRefresh() }
            })
        }
        .fullScreenCover(isPresented: $isShowingGoalSetup) {
            App2OnboardingContainerView(isReonboarding: true) {
                isShowingGoalSetup = false
                Task { await viewModel.forceRefresh() }
            }
        }
        .sheet(isPresented: $isShowingRizoChat) {
            if let rizoChatViewModel {
                NavigationView {
                    ScrollView {
                        RizoChatView(viewModel: rizoChatViewModel)
                            .padding(16)
                    }
                    .background(App2Theme.pageGradient.ignoresSafeArea())
                }
            }
        }
    }

    // MARK: - 目標賽事 hero（設計 frame-20 上半的深藍卡）

    @ViewBuilder
    private func heroCard(_ overview: App2PlanOverview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.App2.PlanOverview.goalSection.localized)
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer(minLength: 4)
                if let distance = overview.distanceLabel {
                    App2Pill(
                        text: distance,
                        foreground: App2Theme.accentBlueDark,
                        background: .white
                    )
                }
            }

            // 沒有主要賽事就明說沒有 —— 不拿設計稿的示範賽事充數。
            Text(overview.raceName ?? L10n.App2.PlanOverview.noPlanTitle.localized)
                .font(.system(size: 30, weight: .black))
                .tracking(0.3)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            if let subtitle = heroSubtitle(overview) {
                Text(subtitle)
                    .font(.app2Mono(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 5)
            } else {
                Text(L10n.App2.PlanOverview.noPlanBody.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }

            if overview.raceName != nil {
                comparisonRow(overview).padding(.top, 18)
            }

            if let progress = overview.progress,
               let currentWeek = overview.currentWeek,
               let totalWeeks = overview.totalWeeks {
                progressRow(
                    progress: progress,
                    currentWeek: currentWeek,
                    totalWeeks: totalWeeks,
                    stageName: overview.currentStageName
                )
                .padding(.top, 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 22, leading: 20, bottom: 22, trailing: 20))
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(App2Theme.heroDarkGradient)
        )
        .shadow(color: App2Theme.shadowHeroColor, radius: 20, x: 0, y: 18)
        .accessibilityIdentifier("App2_PlanOverviewHero")
    }

    /// `2026-12-06 · 還有 17 週`。日期與週數各自缺席時就只出現有的那一半。
    private func heroSubtitle(_ overview: App2PlanOverview) -> String? {
        var parts: [String] = []
        if let date = overview.raceDateLabel { parts.append(date) }
        if let weeks = overview.weeksUntilRace {
            parts.append(String(format: L10n.App2.PlanOverview.weeksUntilRace.localized, weeks))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 「現在的你 → 目標」。
    private func comparisonRow(_ overview: App2PlanOverview) -> some View {
        HStack(alignment: .center, spacing: 12) {
            heroBox(
                title: L10n.App2.PlanOverview.currentYou.localized,
                value: overview.currentEstimatedFinish,
                // 沒有完賽預估時整格說「尚未有完賽預估」，不印一個假的時間。
                emptyText: L10n.App2.PlanOverview.noEstimate.localized,
                caption: overview.currentWeeklyKm.map {
                    String(
                        format: L10n.App2.PlanOverview.weeklyVolume.localized,
                        App2NumberFormat.grouped($0, maximumFractionDigits: 0)
                    )
                },
                highlighted: false
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white.opacity(0.65))

            heroBox(
                title: L10n.App2.PlanOverview.target.localized,
                value: overview.targetTime,
                emptyText: "—",
                caption: overview.distanceLabel,
                highlighted: true
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func heroBox(
        title: String,
        value: String?,
        emptyText: String,
        caption: String?,
        highlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(highlighted ? .white : .white.opacity(0.7))
            if let value {
                Text(value)
                    .font(.app2Mono(20))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(emptyText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let caption {
                Text(caption)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(highlighted ? 0.75 : 0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(highlighted
                      ? AnyShapeStyle(LinearGradient(
                          colors: [
                            App2Theme.accentBlueLight.opacity(0.4),
                            App2Theme.accentBlueLight.opacity(0.14)
                          ],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                      ))
                      : AnyShapeStyle(Color.white.opacity(0.1)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(highlighted ? 0.28 : 0.16), lineWidth: 1)
        )
    }

    private func progressRow(
        progress: Double,
        currentWeek: Int,
        totalWeeks: Int,
        stageName: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L10n.App2.PlanOverview.progressLabel.localized)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                if let stageName {
                    Text("· \(stageName)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color(hex: "#9FCCFF"))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(String(
                    format: L10n.App2.PlanOverview.weekOfTotal.localized,
                    currentWeek,
                    totalWeeks
                ))
                .font(.app2Mono(13))
                .foregroundStyle(.white)
            }

            // 深色卡上的軌道要比 `App2ProgressBar` 的預設淺灰亮，否則整條看不見。
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                App2ProgressBar(
                    progress: progress,
                    height: 9,
                    fill: LinearGradient(
                        colors: [Color(hex: "#9FCCFF"), .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .frame(height: 9)
        }
        .accessibilityIdentifier("App2_PlanOverviewProgress")
    }

    // MARK: - 階段期程（設計 frame-20「四個階段」）

    @ViewBuilder
    private func stagesSection(_ overview: App2PlanOverview) -> some View {
        if !overview.stages.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(
                    format: L10n.App2.PlanOverview.stagesSection.localized,
                    overview.stages.count
                ))
                .font(.system(size: 14, weight: .black))
                .tracking(0.3)
                .foregroundStyle(App2Theme.inkPrimary)
                .padding(.leading, 2)

                Text(L10n.App2.PlanOverview.stagesSubtitle.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(EdgeInsets(top: 3, leading: 2, bottom: 12, trailing: 2))

                ForEach(Array(overview.stages.enumerated()), id: \.element.id) { index, stage in
                    stageCard(stage)
                    if index < overview.stages.count - 1 {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(hex: "#C2CCD8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                    }
                }
            }
            .padding(.top, 18)
            .accessibilityIdentifier("App2_PlanOverviewStages")
        } else if viewModel.stagesUnbound {
            App2InlineNotice(text: L10n.App2.PlanOverview.stagesUnavailable.localized)
                .padding(.top, 18)
                .accessibilityIdentifier("App2_PlanOverviewStagesUnbound")
        }
    }

    private func stageCard(_ stage: App2PlanStage) -> some View {
        let isActive = stage.state == .active
        return HStack(alignment: .top, spacing: 13) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isActive ? Color(hex: "#5AA9F0") : Color(hex: "#C8D3DF"))
                .frame(width: 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(stage.name)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(isActive ? App2Theme.inkPrimary : App2Theme.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    stateBadge(stage.state)
                    Spacer(minLength: 4)
                    Text(stage.weekRangeLabel)
                        .font(.app2Mono(11))
                        .foregroundStyle(App2Theme.inkTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(App2Theme.shadowInk.opacity(0.05)))
                }

                if let focus = stage.focus {
                    Text(focus)
                        .font(.system(size: 14, weight: isActive ? .heavy : .bold))
                        .foregroundStyle(isActive ? Color(hex: "#5AA9F0") : App2Theme.inkTertiary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }

                if isActive, let elapsed = stage.weeksElapsed {
                    HStack(spacing: 9) {
                        App2ProgressBar(
                            progress: Double(elapsed) / Double(stage.weekCount),
                            height: 6,
                            fill: LinearGradient(
                                colors: [App2Theme.accentBlue, App2Theme.accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        Text(String(
                            format: L10n.App2.PlanOverview.stageProgress.localized,
                            elapsed,
                            stage.weekCount
                        ))
                        .font(.app2Mono(12))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                        .fixedSize()
                    }
                    .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16))
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive
                      ? AnyShapeStyle(App2Theme.accentCardGradient(strength: 0.10))
                      : AnyShapeStyle(App2Theme.cardBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isActive ? App2Theme.accentBlue : App2Theme.cardBorder,
                    lineWidth: isActive ? 2 : 1
                )
        )
        .shadow(color: App2Theme.shadowTightColor, radius: 1, x: 0, y: 1)
    }

    @ViewBuilder
    private func stateBadge(_ state: App2PlanStage.State) -> some View {
        switch state {
        case .active:
            badge(L10n.App2.PlanOverview.stageActive.localized, .white, App2Theme.accentBlue)
        case .done:
            badge(
                L10n.App2.PlanOverview.stageDone.localized,
                App2Theme.accentGreen,
                App2Theme.accentGreen.opacity(0.12)
            )
        case .upcoming:
            badge(
                L10n.App2.PlanOverview.stageUpcoming.localized,
                App2Theme.inkMuted,
                App2Theme.shadowInk.opacity(0.05)
            )
        }
    }

    private func badge(_ text: String, _ foreground: Color, _ background: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(Capsule().fill(background))
            .fixedSize()
    }

    // MARK: - 訓練節奏（唯讀，見檔頭）

    @ViewBuilder
    private func rhythmSection(_ rhythm: App2PlanRhythm) -> some View {
        if !rhythm.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                App2SectionCaption(text: L10n.App2.PlanOverview.rhythmSection.localized)

                App2GroupedList {
                    let rows = rhythmRows(rhythm)
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        App2ReadOnlyRow(
                            systemImage: row.icon,
                            title: row.title,
                            value: row.value,
                            showsDivider: index < rows.count - 1
                        )
                    }
                }
            }
            .padding(.top, 20)
            .accessibilityIdentifier("App2_PlanOverviewRhythm")
        }
    }

    private func rhythmRows(_ rhythm: App2PlanRhythm) -> [(icon: String, title: String, value: String)] {
        var rows: [(String, String, String)] = []
        if let days = rhythm.runDaysPerWeek {
            rows.append((
                "calendar",
                L10n.App2.PlanOverview.runDays.localized,
                String(format: L10n.App2.PlanOverview.runDaysValue.localized, days)
            ))
        }
        if let longRun = rhythm.longRunDayLabel {
            rows.append(("chart.line.uptrend.xyaxis", L10n.App2.PlanOverview.longRunDay.localized, longRun))
        }
        if let methodology = rhythm.methodologyName {
            rows.append(("star.fill", L10n.App2.PlanOverview.methodology.localized, methodology))
        }
        return rows
    }

    // MARK: - 管理計畫

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            App2SectionCaption(text: L10n.App2.PlanOverview.manageSection.localized)

            App2GroupedList {
                App2SettingsRow(
                    systemImage: "flag.checkered",
                    title: L10n.App2.PlanOverview.manageRaces.localized,
                    value: L10n.App2.PlanOverview.manageRacesSub.localized
                )
                .contentShape(Rectangle())
                .onTapGesture { isShowingRaces = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_PlanOverviewManageRaces")

                App2SettingsRow(
                    systemImage: "arrow.counterclockwise",
                    iconTint: App2Theme.accentOrange,
                    iconBackground: App2Theme.accentOrange.opacity(0.12),
                    title: L10n.App2.PlanOverview.resetGoal.localized,
                    value: L10n.App2.PlanOverview.resetGoalSub.localized,
                    showsDivider: false
                )
                .contentShape(Rectangle())
                .onTapGesture { isShowingGoalSetup = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_PlanOverviewResetGoal")
            }
        }
        .padding(.top, 20)
    }

    private var autoAdjustNote: some View {
        App2InlineNotice(text: L10n.App2.PlanOverview.autoAdjustNote.localized)
            .padding(.top, 14)
    }

    // MARK: - 跟 Rizo 討論計畫

    private var rizoCta: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 15, weight: .bold))
            Text(L10n.App2.PlanOverview.rizoCta.localized)
                .font(.system(size: 16, weight: .heavy))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(App2Theme.accentBlue)
        )
        .shadow(color: App2Theme.accentBlue.opacity(0.55), radius: 10, x: 0, y: 8)
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.top, 11)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: openRizoChat)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L10n.App2.PlanOverview.rizoCta.localized)
        .accessibilityIdentifier("App2_PlanOverviewRizoCta")
    }

    /// 開既有的 Rizo 對話（不另寫 2.0 版）。
    ///
    /// 情境用 **`plan_adjustment`** —— 這一頁談的是計畫，不是今天的身體狀況。
    /// 值取自後端的白名單 `domains/coach/rizo_outcome.py: ALLOWED_SCENARIOS`，
    /// 不自己造一個字串（造出來的會被後端當未知情境）。
    private func openRizoChat() {
        let viewModelToUse = rizoChatViewModel ?? StateRizoChatViewModel(scenario: "plan_adjustment")
        rizoChatViewModel = viewModelToUse
        isShowingRizoChat = true
        Task { await viewModelToUse.startOpening() }
    }
}

// MARK: - App2ReadOnlyRow
/// 分組清單裡的唯讀列：與 `App2SettingsRow` 同一個版型，但沒有 chevron。
///
/// 這個型別存在的理由只有一條 —— **沒有目的地的列不得長得像可以點**。
struct App2ReadOnlyRow: View {
    let systemImage: String
    var iconTint: Color = App2Theme.accentBlueDeep
    var iconBackground: Color = App2Theme.accentBlue.opacity(0.1)
    let title: String
    let value: String
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(iconTint)
                    }
                Text(title)
                    .font(.app2RowTitle)
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(App2Theme.inkSubtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)

            if showsDivider {
                Rectangle()
                    .fill(App2Theme.insetBorder)
                    .frame(height: 1)
                    .padding(.leading, 59)
            }
        }
    }
}
