import SwiftUI

// MARK: - App2PlanView
/// 2.0 課表頁 —— 設計 **frame-01「課表」**（語意／端點見
/// `DESIGN-app2-decision-chain-api.md` §3.3）。
///
/// 版面：標題「訓練課表」＋ 週次切換器 → 本週跑量藍卡
/// （大 mono 數字、完成百分比膠囊、三色強度分段條）→ 每日卡（左緣彩色邊、
/// 課型徽章＋體感溫度徽章、課表／實際兩行）。
///
/// **這一頁沒有設定入口**（2026-08-25 設計更新）。設定改由首頁右上角的「…」menu 進入。
/// header 右側是週次切換器 ＋ 一顆鉛筆鈕（2026-08-26 裁決）——它開的是**與首頁
/// 「…」menu 的「修改課表」同一個** `App2PlanEditGate`，不是第二條入口。
struct App2PlanView: View {

    @ObservedObject var viewModel: App2PlanViewModel

    /// 單位制切換要當場重畫（同 `App2WorkoutDetailView` 的接法）。
    @ObservedObject private var unitManager = UnitManager.shared
    /// 日卡點下去開的訓練詳情（設計 frame-02）。休息日不在 `dayDetails` 裡 → 點不開。
    @State private var detailSession: App2SessionDetail?
    /// 修改課表（與首頁「…」menu 同一個入口殼）。
    @State private var isShowingPlanEdit = false
    /// 結束態的兩個目的地。與首頁那兩個是同一頁、同一條既有流程，不是這一頁專屬的。
    @State private var isShowingPeriodSummary = false
    @State private var isShowingReonboarding = false
    /// 「先完成週回顧」開的那一頁（裁決（k））。**與首頁週回顧 CTA 同一條入口**
    /// （`App2HomeView` 的 `weeklyReviewWeek`），不是課表頁專屬的第二條路。
    @State private var weeklyReviewWeek: App2WeeklyReviewTarget?
    /// 「為什麼這樣安排」bottom sheet（AC-TRAIN-HUB-20）。內容一律現讀
    /// `viewModel.week`，不複製一份到 state —— 換週時 sheet 開著也不會顯示上一週的理由。
    @State private var isShowingRationale = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, 16)

                if viewModel.showsPlanEnd, let planEnd = viewModel.planEnd {
                    // 計畫走完（設計 frame-00g2（c））：**不再顯示第 N/M 週**。
                    // header 的週次切換器也跟著收掉（見 `header`）。
                    App2PlanEndTabCard(
                        card: planEnd,
                        onOpenSummary: { isShowingPeriodSummary = true },
                        onSetNewGoal: { isShowingReonboarding = true },
                        onBrowseHistory: viewModel.historyTotalWeeks == nil
                            ? nil
                            : { Task { await viewModel.enterHistoryMode() } }
                    )
                } else if viewModel.isHistoryMode {
                    // 歷史回看（裁決（e））：週次切換器回來了（見 `header`），
                    // 但要有一條路回到結束畫面 —— 否則按下去就出不來。
                    historyBackRow
                        .padding(.bottom, 14)
                    if let sourced = viewModel.week {
                        volumeCard(sourced)
                            .padding(.bottom, 14)
                        ForEach(sourced.value.days) { day in
                            dayCard(day).padding(.bottom, 11)
                        }
                    } else if viewModel.isHistoryWeekMissing {
                        historyEmptyCard
                    } else {
                        // 切到一週還沒看過的課表：週次標已經是目標週，內容用骨架佔位
                        // （T-0374 裁決「等資料的格子給輕量 placeholder，不上全頁 spinner」）。
                        weekSkeleton
                    }
                } else if let sourced = viewModel.week {
                    volumeCard(sourced)
                        .padding(.bottom, 14)
                    ForEach(sourced.value.days) { day in
                        dayCard(day).padding(.bottom, 11)
                    }
                } else if viewModel.loadState == .failed {
                    planLoadFailedCard
                } else if viewModel.isLoading || viewModel.loadState == .loading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // 首頁那句叫人「到課表頁產生」——在這一頁自己身上是繞圈，
                    // 用這頁自己的文案（dev QA D3），產生鈕就在下面。
                    App2Card(padding: 16, spacing: 8) {
                        Text(
                            viewModel.isPlanGenerated
                                ? L10n.App2.Common.noData.localized
                                : L10n.App2.Plan.noPlanBody.localized
                        )
                        .font(.app2Body)
                        .lineSpacing(2)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                        // 產生入口（2026-08-27 晚走查裁決（i））：裁決前首頁叫用戶
                        // 「到課表頁產生」，這一頁卻只有同一句話 —— 走不出去。
                        if !viewModel.isPlanGenerated {
                            generatePlanButton
                        }
                    }
                    // 容器的 identifier 會被 SwiftUI 套到每一個子元素上，主鈕自己的
                    // `App2_PlanGenerateWeek` 因此在 a11y 樹上一個都看不到
                    // （2026-09-03 實測 `maestro hierarchy`：整張卡只剩兩個
                    // `App2_PlanEmptyState`）。同 T-0383 對週回顧三個容器的處置。
                    .accessibilityElement(children: .contain)
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
        .fullScreenCover(item: $detailSession) { detail in
            App2SessionDetailView(detail: detail) { detailSession = nil }
        }
        .fullScreenCover(isPresented: $isShowingPlanEdit) {
            App2PlanEditGate(
                onClose: { isShowingPlanEdit = false },
                // 課表改了，這一頁的週跑量與日卡要跟著換。
                onSaved: { Task { await viewModel.forceRefresh() } }
            )
        }
        .fullScreenCover(isPresented: $isShowingPeriodSummary) {
            if let planEnd = viewModel.planEnd {
                App2PeriodSummaryView(
                    card: planEnd,
                    onClose: { isShowingPeriodSummary = false }
                )
            }
        }
        .fullScreenCover(item: $weeklyReviewWeek) { target in
            App2WeeklyReviewView(
                weekOfPlan: target.weekOfPlan,
                isReadOnly: target.isReadOnly,
                isCurrentWeek: target.isCurrentWeek,
                startsOnPlanTab: target.startsOnPlanTab,
                onClose: {
                    weeklyReviewWeek = nil
                    // 回顧做完（或清單走完產出課表）之後 `next_action` 與
                    // `current_week_plan_id` 都變了，這一頁的未產生態要跟著收——
                    // 所以關閉就重驗。
                    Task { await viewModel.forceRefresh() }
                },
                onApplied: { Task { await viewModel.forceRefresh() } },
                // 從這一頁產生的一樣要落在剛產生的那一週（AC-TRAIN-HUB-19）：
                // 這一頁的未產生態主鈕在週日開的是下一週，產完停在這週就是空的。
                onPlanGenerated: { week in
                    Task { await viewModel.showGeneratedWeek(week) }
                }
            )
        }
        .fullScreenCover(isPresented: $isShowingReonboarding) {
            App2OnboardingContainerView(
                isReonboarding: true,
                onFinished: {
                    isShowingReonboarding = false
                    // 重設完目標，這一頁要從結束態回到新計畫的第 1 週。
                    Task { await viewModel.forceRefresh() }
                },
                // 還沒提交就返回：只關掉，不重取（什麼都沒改）。
                onCancel: { isShowingReonboarding = false }
            )
        }
        .sheet(isPresented: $isShowingRationale) {
            if let rationale = viewModel.week?.value.rationale {
                App2PlanRationaleSheet(
                    rationale: rationale,
                    weekLabel: weekLabelText,
                    onClose: { isShowingRationale = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 未產生態主鈕（2026-08-27 晚走查裁決（i）／（k）→ 2026-09-03 裁決 T-0405）

    /// 未產生態的主鈕。**這一頁不產生課表**（2026-09-03 裁決）：兩個 `next_action`
    /// 都是開週回顧，差別只在停在哪個分頁——
    ///
    /// - `create_summary`：停在回顧分頁（裁決（k）的既有行為，「先完成週回顧」）。
    /// - `create_plan`：直接停在「規劃下週」分頁，走 run → 逐條清單 → 產生
    ///   （AC-TRAIN-HUB-12）。修復前這裡直接打 `POST /v2/plan/weekly`，
    ///   使用者在這條路上完全看不到、也答不了 L0 的調整。
    ///
    /// 所以按下去只是換頁，不再有 loading 態與失敗重試——那兩件事現在住在
    /// 週回顧頁的產生鈕（`App2WeeklyReviewViewModel.applyAndGenerate`）。
    private var generatePlanButton: some View {
        HStack(spacing: 8) {
            if viewModel.requiresWeeklyReviewBeforeGenerate {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 15, weight: .bold))
                Text(L10n.App2.Plan.completeReviewFirst.localized)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                Text(L10n.App2.Plan.generateWeek.localized)
            }
        }
        .font(.system(size: 16, weight: .heavy))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(App2Theme.accentBlue)
        )
        .padding(.top, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard case .weeklyReview(let reviewWeek, let startsOnPlanTab) =
                    viewModel.generateCTADestination else { return }
            weeklyReviewWeek = App2WeeklyReviewTarget(
                weekOfPlan: reviewWeek,
                isCurrentWeek: false,
                startsOnPlanTab: startsOnPlanTab
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            viewModel.requiresWeeklyReviewBeforeGenerate
                ? L10n.App2.Plan.completeReviewFirst.localized
                : L10n.App2.Plan.generateWeek.localized
        )
        .accessibilityIdentifier(
            viewModel.requiresWeeklyReviewBeforeGenerate
                ? "App2_PlanCompleteReviewFirst"
                : "App2_PlanGenerateWeek"
        )
    }

    // MARK: - Header（標題 ＋ 週次切換器）

    private var header: some View {
        App2PageHeader(
            title: L10n.App2.Plan.title.localized,
            centre: {
                // 週次切換器置中（2026-08-27 走查裁決（q））。
                // 結束卡在畫時整組不出現（設計 frame-00g2（c）的 header 只有標題＋副句）；
                // 歷史回看時回來 —— 那些週確實存在，只是不再是「本週」。
                if !viewModel.showsPlanEnd { weekStepper }
            },
            trailing: {
                // 鉛筆**不隨歷史模式回來** —— 結束態判準是 `allowsEditing`
                //（裁決（b）：結束了就一路唯讀）；進行中的歷史回看同樣唯讀
                //（編輯走的是當週端點，對過去週按下去只會改錯週）。
                if !viewModel.showsPlanEnd {
                    HStack(spacing: 5) {
                        weeklyReviewButton
                        if viewModel.allowsEditing && !viewModel.isHistoryMode { editButton }
                    }
                }
            }
        )
    }

    /// `‹ 第 7 週 / 12 ›`。看本週時左鍵＝進歷史回看（前一週）、右鍵停用；
    /// 歷史回看往後翻回到當週＝自動退回現行畫面。
    /// 資料走 `getWeeklyPlan(weekOfTraining:overviewId:)`。
    private var weekStepper: some View {
        HStack(spacing: 5) {
            weekStepButton(symbol: "chevron.left", enabled: viewModel.canGoPreviousHistoryWeek) {
                Task { await viewModel.goToHistoryWeek(offset: -1) }
            }
            .accessibilityIdentifier("App2_PlanWeekPrevious")
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(weekLabelText)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                if let total = shownTotalWeeks {
                    Text(verbatim: " / \(total)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
            }
            .frame(minWidth: 76)
            .accessibilityIdentifier("App2_PlanWeekLabel")
            weekStepButton(symbol: "chevron.right", enabled: viewModel.canGoNextHistoryWeek) {
                Task { await viewModel.goToHistoryWeek(offset: 1) }
            }
            .accessibilityIdentifier("App2_PlanWeekNext")
        }
    }

    // MARK: - 週回顧入口（2026-08-27 走查裁決（q））

    /// 鉛筆左邊那一顆：點進**當前所選那一週**的週回顧。
    ///
    /// 2026-09-01 覆寫裁決（q）：當週不畫這顆鈕。歷史週點進去直接顯示已存的
    /// V2 週回顧（唯讀、`GET /v2/summary/weekly`，不生成）。
    ///
    /// **不造第二條路**：開的是既有的 `App2WeeklyReviewView`（同首頁 CTA、同課表頁
    /// 未產生態 CTA 那一頁）。
    @ViewBuilder
    private var weeklyReviewButton: some View {
        if viewModel.showsHeaderWeeklyReview, let week = viewModel.selectedWeekOfPlan {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(App2Theme.cardBackground)
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(App2Theme.cardBorder, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    weeklyReviewWeek = App2WeeklyReviewTarget(
                        weekOfPlan: week,
                        isReadOnly: true,
                        isCurrentWeek: false
                    )
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.App2.Plan.openWeeklyReview.localized)
                .accessibilityIdentifier("App2_PlanWeeklyReviewButton")
        }
    }

    /// 週次標。那一週的課表 doc 缺席（歷史 404、本週還沒產生）時 `week` 是 nil，
    /// 但 plan status 知道現在第幾週——仍要標得出「第 N 週」，否則使用者不知道
    /// 自己停在哪一週（dev QA D1：新週一早上顯示成「—」）。
    private var weekLabelText: String {
        if let label = viewModel.week?.value.weekLabel { return label }
        if let week = viewModel.selectedWeekOfPlan {
            return String(format: L10n.WeekSelector.weekNumber.localized, week)
        }
        return "—"
    }

    private var shownTotalWeeks: Int? {
        viewModel.week?.value.totalWeeks ?? viewModel.historyTotalWeeks
    }

    // MARK: - 歷史回看（裁決（e））

    /// 返程列。**歷史模式唯一的導航出口**（tab 切走再回來會保留這個模式）。
    private var historyBackRow: some View {
        App2GroupedList {
            App2SettingsRow(
                systemImage: "arrow.uturn.backward",
                // 結束態＝回結束畫面；進行中＝回本週（8/27：進行中也能歷史回看）。
                title: viewModel.showsPlanEndAfterExit
                    ? L10n.App2.PlanEnd.historyBack.localized
                    : L10n.App2.PlanEnd.historyBackCurrentWeek.localized,
                value: "",
                showsDivider: false
            )
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.exitHistoryMode()
                // 進行中退出後 `week` 是空的，要重載本週；結束態不需要，但重驗無害。
                Task { await viewModel.revalidate() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_PlanEndHistoryBack")
        }
    }

    /// 該週沒生成過課表（404）。**不是錯誤**，所以講的是「這一週沒有課表」
    /// 而不是「讀取失敗」。
    private var historyEmptyCard: some View {
        App2Card(padding: 16, spacing: 8) {
            Text(L10n.App2.PlanEnd.historyWeekEmpty.localized)
                .font(.app2Body)
                .lineSpacing(2)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("App2_PlanEndHistoryEmpty")
    }

    private var planLoadFailedCard: some View {
        App2Card(spacing: 10) {
            Text(L10n.App2.Common.loadFailed.localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(App2Theme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(L10n.App2.Common.retry.localized) {
                Task { await viewModel.forceRefresh() }
            }
            .accessibilityIdentifier("App2_PlanLoadRetry")
        }
        .accessibilityIdentifier("App2_PlanLoadFailed")
    }

    /// 切到還沒看過的那一週時的等待態（T-0374）。
    ///
    /// 修前這裡是一顆 `ProgressView`——整個內容區被一顆轉圈取代，而週次標已經跳走，
    /// 所以按下箭頭之後畫面「什麼都沒有了」。骨架維持跑量卡 ＋ 七張日卡的版面，
    /// 換週看起來就是同一疊卡片在換內容。**不需要任何字串。**
    private var weekSkeleton: some View {
        VStack(spacing: 0) {
            App2AccentCard(padding: 16, spacing: 12) {
                skeletonBar(width: 96, height: 16)
                skeletonBar(width: 150, height: 30)
                skeletonBar(width: nil, height: 10)
            }
            .padding(.bottom, 14)

            ForEach(0..<7, id: \.self) { _ in
                App2Card(padding: 16, spacing: 10) {
                    skeletonBar(width: 110, height: 14)
                    skeletonBar(width: nil, height: 12)
                }
                .padding(.bottom, 11)
            }
        }
        .accessibilityIdentifier("App2_PlanWeekSkeleton")
        .accessibilityHidden(true)
    }

    private func skeletonBar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(App2Theme.inkMuted.opacity(0.12))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    /// 修改課表（設計裁決 2026-08-26：週次切換器同列右側的鉛筆 icon 鈕）。
    /// 只有真的有課表可改時才出現 —— 沒課表按下去只會開一頁「讀不到」。
    @ViewBuilder
    private var editButton: some View {
        if viewModel.week != nil {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(App2Theme.cardBackground)
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(App2Theme.shadowInk.opacity(0.08), lineWidth: 1)
                )
                .overlay {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                }
                .shadow(color: App2Theme.shadowInk.opacity(0.12), radius: 3, x: 0, y: 3)
                .padding(.leading, 3)
                .contentShape(Rectangle())
                .onTapGesture { isShowingPlanEdit = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(L10n.App2.Home.menuEditPlan.localized)
                .accessibilityIdentifier("App2_PlanEditEntry")
        }
    }

    private func weekStepButton(
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void = {}
    ) -> some View {
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
            .contentShape(Rectangle())
            .onTapGesture { if enabled { action() } }
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - 本週跑量（設計：藍卡 ＋ 大 mono 數字 ＋ 百分比膠囊 ＋ 三色分段條）

    private func volumeCard(_ sourced: App2Sourced<App2PlanWeek>) -> some View {
        let week = sourced.value
        let completed = week.completedDistanceKm ?? 0
        let ratio: Double = if let targetDistanceKm = week.targetDistanceKm, targetDistanceKm > 0 {
            min(completed / targetDistanceKm, 1)
        } else {
            0
        }
        // 比例是無因次的，換算只影響畫出來的數字。
        let unit = unitManager.currentUnitSystem

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
                    Text(week.completedDistanceKm
                        .map { App2NumberFormat.grouped(unit.convertedDistance($0), maximumFractionDigits: 1) } ?? "0")
                        .font(.app2Mono(28))
                        .foregroundStyle(App2Theme.inkPrimary)
                    if let targetDistanceKm = week.targetDistanceKm {
                        Text(verbatim: " / "
                             + App2NumberFormat.grouped(unit.convertedDistance(targetDistanceKm), maximumFractionDigits: 1)
                             + " " + unit.distanceSuffix)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(App2Theme.inkTertiary)
                    }
                }
                Spacer()
                if week.targetDistanceKm != nil {
                    Text(verbatim: "\(Int((ratio * 100).rounded()))%")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(App2Theme.accentBlue.opacity(0.1)))
                }
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

            if week.rationale != nil {
                rationaleEntry
            }
        }
        // 沒有 `.contain` 的話，容器的 identifier 會蓋到每一個子元素上，
        // 底下的 `App2_PlanRationaleEntry` 在 a11y 樹上一個都看不到
        // （同 `App2_PlanEmptyState` 那一段的實測，見上面 :97-101）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("App2_PlanSummaryCard")
    }

    /// 「為什麼這樣安排」入口（AC-TRAIN-HUB-20）。掛在週跑量卡底下，因為這一整張卡
    /// 講的就是這一週的量與強度，理由是它的註腳；掛在日卡上會變成七份重複入口。
    private var rationaleEntry: some View {
        Button {
            isShowingRationale = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(L10n.App2.Plan.rationaleEntry.localized)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(App2Theme.accentBlueDeep)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("App2_PlanRationaleEntry")
    }

    /// 設計是「已完成的量」按強度切三段，鋪在「週目標量」這條軌道上。
    /// 三段比例是**實跑**強度分鐘（與已完成量同一批 `/v2/workouts` 紀錄），
    /// 不是課表目標 `intensity_total_minutes`。
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
        // 點日卡進訓練詳情（設計 frame-02）。休息日沒有詳情版式 —— `dayDetails`
        // 裡本來就沒有那一天，所以點下去不會開一頁空卡。
        .contentShape(Rectangle())
        .onTapGesture {
            guard let detail = viewModel.dayDetails[day.id] else { return }
            detailSession = detail
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

// MARK: - App2PlanRationaleSheet
/// 「這週為什麼這樣排」bottom sheet（AC-TRAIN-HUB-20）。
///
/// 1.4 有同一組內容（`WeekTargetDetailViewV2`，push 進導覽堆疊），2.0 把課表頁整個重畫時
/// 沒有接回來——後端一直有給，只是沒有任何畫面讀它。這裡沿用 app2 的卡片語彙重畫，
/// 不重用 `WeekTargetDetailViewV2`：那支綁 `PacerizColor`／`AppFont` 與導覽列 toolbar，
/// 放進 app2 的 sheet 會是另一套視覺。
///
/// 四段的順序照 1.4：教練的話當開場，接著本週目標、跑量怎麼變、安排理由。
/// 句子一律原樣印出——它們是後端按使用者語言生成的敘事（`l5_response_builder.py:245-246`），
/// App 不改寫也不截斷。
struct App2PlanRationaleSheet: View {
    let rationale: App2PlanRationale
    let weekLabel: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.App2.Plan.rationaleTitle.localized)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(weekLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("App2_PlanRationaleClose")
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 20)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 12) {
                    if let coachNote = rationale.coachNote {
                        section(
                            icon: "quote.bubble.fill",
                            tint: App2Theme.accentBlueDeep,
                            title: L10n.App2.Plan.rationaleCoachNote.localized,
                            identifier: "App2_PlanRationaleCoachNote"
                        ) {
                            paragraph(coachNote)
                        }
                    }
                    if let purpose = rationale.purpose {
                        section(
                            icon: "target",
                            tint: App2Theme.accentGreen,
                            title: L10n.App2.Plan.rationalePurpose.localized,
                            identifier: "App2_PlanRationalePurpose"
                        ) {
                            paragraph(purpose)
                        }
                    }
                    if let progression = rationale.mileageProgressionNote {
                        section(
                            icon: "chart.line.uptrend.xyaxis",
                            tint: App2Theme.accentBlue,
                            title: L10n.App2.Plan.rationaleProgression.localized,
                            identifier: "App2_PlanRationaleProgression"
                        ) {
                            paragraph(progression)
                        }
                    }
                    if !rationale.designReasons.isEmpty {
                        section(
                            icon: "lightbulb.fill",
                            tint: App2Theme.accentOrangeText,
                            title: L10n.App2.Plan.rationaleDesignReason.localized,
                            identifier: "App2_PlanRationaleDesignReason"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(rationale.designReasons.enumerated()), id: \.offset) { index, reason in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(verbatim: "\(index + 1).")
                                            .font(.system(size: 15, weight: .heavy))
                                            .foregroundStyle(App2Theme.accentOrangeText)
                                        paragraph(reason)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.bottom, 28)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("App2_PlanRationaleSheet")
    }

    private func section<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        identifier: String,
        // `App2Card` 把 content 存成屬性 → 這裡必須是 escaping。
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        App2Card(padding: 14, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(tint)
            }
            content()
        }
        // 容器的 identifier 會被 SwiftUI 套到每個子元素上（同 `App2_PlanEmptyState` 的處置）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.app2Body)
            .lineSpacing(3)
            .foregroundStyle(App2Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
