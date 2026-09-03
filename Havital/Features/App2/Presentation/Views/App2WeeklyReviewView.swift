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
    /// 開頁就停在「規劃下週」分頁（T-0405，2026-09-03 裁決）。課表頁的未產生態主鈕
    /// 走這一格：使用者按的是「產生課表」，落點該是那條清單，不是回顧。
    var startsOnPlanTab: Bool = false
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

    /// 開頁停在哪個分頁。預設回顧；課表頁的未產生態主鈕帶 `startsOnPlanTab: true`
    /// 直接落在規劃分頁（T-0405）。**規劃分頁被 `showsPlanTab` 收掉時
    /// `activeTab` 會把畫面拉回回顧**，所以這個初值不會把人送進不存在的分頁。
    @State private var tab: Tab

    /// 正在調整值的那一條（`sheet(item:)` 要 `Identifiable`，清單條目本來就是）。
    @State private var adjustingItem: DecisionChainChecklistItem?

    /// 週日流程按下「產生回顧」後、還沒確認「本週訓練是否皆已完成」的那一刻（T-0409）。
    @State private var showsCompletionConfirm = false

    /// 「規劃下週」底部的 Rizo 輸入區（8/28 盤點 F15，Android 早有）。
    ///
    /// **不造第二套對話**：走既有的 `StateRizoChatViewModel`（App2 首頁那兩個 Rizo
    /// 入口用的同一支）＋既有 Rizo API，scenario 與 Android
    /// `TrainingPlanV2ViewModel.submitUserNlEdit` 同樣是 `weekly_situation` ——
    /// 兩台把「我下週的狀況」送到後端的是同一條路。
    @StateObject private var discussViewModel =
        StateRizoChatViewModel(scenario: App2WeeklyReviewView.discussScenario)

    /// 下週規劃的 Rizo 情境 key（後端既有值，與 Android 同一個）。
    static let discussScenario = "weekly_situation"

    enum Tab: String, CaseIterable {
        case review
        case plan
    }

    // MARK: - 規劃分頁在不在（2026-09-01 使用者裁決）
    //
    // 使用者原話：「我看歷史的週回顧為什麼還會有下週規劃，到底在搞什麼東西啊」
    // ——「不該啊」（同日裁決）。歷史週的回顧夾著一個「規劃第 N+1 週」分頁是錯的
    // 時間軸：那一週早就過完了，它的建議套不到任何地方。
    //
    // 判準是**那個分頁規劃的那一週還沒過去**，不是「這一頁看的是不是本週」。
    // 兩者不同，而且差別會傷到人：平日流程回顧的是**上週**（`isCurrentWeek == false`），
    // 它的規劃分頁目標是**本週**——那正是 T-0341 補上的產生出口，拿掉會把訓練流程
    // 重新弄斷。所以條件寫成 `reviewWeek + 1 >= current_week`。

    /// 「規劃第 N+1 週」分頁在不在。
    ///
    /// - 歷史回看（裁決（q）的唯讀入口）一律不畫——那是使用者抱怨的那一格。
    /// - 目標週已經過去（`reviewWeek + 1 < current_week`）也不畫。
    /// - `planStatus` 讀不到時 fail-open（訓練流程核心一律 fail-open，
    ///   `LOCAL-DEVELOPMENT-HARNESS.md` §1.2 鐵則 7）：那時判不出週次，
    ///   收掉分頁會讓使用者連唯一的產生出口都沒有。
    nonisolated static func showsPlanTab(
        reviewWeek: Int,
        planStatus: PlanStatusV2Response?,
        isReadOnly: Bool
    ) -> Bool {
        guard !isReadOnly else { return false }
        guard let current = planStatus?.currentWeek else { return true }
        return reviewWeek + 1 >= current
    }

    private var showsPlanTab: Bool {
        Self.showsPlanTab(
            reviewWeek: weekOfPlan,
            planStatus: viewModel.planStatus,
            isReadOnly: isReadOnly
        )
    }

    /// 實際要畫哪一個分頁。規劃分頁收掉時 `tab` 的殘值不得把畫面帶進一個不存在的分頁。
    private var activeTab: Tab { showsPlanTab ? tab : .review }

    // MARK: - 沒有回顧內容時的規劃分頁（T-0405 外審 E03）
    //
    // 這一頁的內容區與主 CTA 原本整個掛在 `projection` 上——回顧載進來了才畫。
    // 平日流程沒事（回顧的是已完成的上一週），**第 1 週的使用者會死在這裡**：
    // `current_week == 1` 沒有上一週可回顧，課表頁的主鈕把他們送進第 0 週的回顧，
    // 而第 0 週不存在、也不在產生視窗內（`isGenerationWindowOpen` 平日要 `current ≥ 2`），
    // `projection` 永遠是 nil ⇒ 規劃分頁與產生 CTA 一個都不畫。T-0405 之前那顆鈕
    // 是他們唯一的產生出口，掛掉就是零出口。
    //
    // 判準只看**這一頁能不能產生**，與回顧有沒有內容無關——同 AC-TRAIN-HUB-10
    // 「無建議項不得成為零出口」的那條理由。

    /// 沒有回顧內容時，規劃分頁與它的主 CTA 仍要畫嗎。
    nonisolated static func showsPlanTabWithoutReview(
        hasProjection: Bool,
        showsPlanTab: Bool,
        nextWeekAction: App2WeeklyReviewViewModel.NextWeekAction
    ) -> Bool {
        guard !hasProjection, showsPlanTab else { return false }
        if case .generate = nextWeekAction { return true }
        return false
    }

    private var showsPlanTabWithoutReview: Bool {
        Self.showsPlanTabWithoutReview(
            hasProjection: viewModel.projection != nil,
            showsPlanTab: showsPlanTab,
            nextWeekAction: viewModel.nextWeekAction
        )
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
        startsOnPlanTab: Bool = false,
        onClose: @escaping () -> Void,
        onApplied: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: App2WeeklyReviewViewModel(
                weekOfPlan: weekOfPlan,
                isReadOnly: isReadOnly,
                isCurrentWeek: isCurrentWeek
            )
        )
        _tab = State(initialValue: startsOnPlanTab ? .plan : .review)
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

            // 只剩回顧一個分頁時整個切換器不出現——一顆按不出第二頁的分頁鈕
            // 比沒有更糟。
            if showsPlanTab {
                segmentedTabs
                    .padding(.horizontal, App2Theme.pagePadding)
                    .padding(.top, 12)
            }

            content

            // 主 CTA 只在規劃分頁出現 —— 回顧分頁沒有可套用／可產生的東西。
            // 形態由 `nextWeekAction` 決定（唯讀與「沒有出口」時整條不出現）。
            if activeTab == .plan, viewModel.projection != nil || showsPlanTabWithoutReview {
                planFooter
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
        // 產生課表失敗可重試（CTA 仍在，狀態沒有被改掉）。
        .alert(
            L10n.App2.WeeklyReview.generatePlanFailed.localized,
            isPresented: Binding(
                get: { viewModel.generateError != nil },
                set: { if !$0 { viewModel.generateError = nil } }
            ),
            presenting: viewModel.generateError
        ) { _ in
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
        } message: { message in
            Text(message)
        }
        // 清單上某一條沒送出去。那一條已經退回原狀（VM 做的），這裡只是說出來——
        // 靜默失敗會讓使用者以為勾到了，而後端根本沒收到。
        .alert(
            L10n.App2.WeeklyReview.stanceFailed.localized,
            isPresented: Binding(
                get: { viewModel.checklistError != nil },
                set: { if !$0 { viewModel.checklistError = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
        }
        // 「調整」的值走既有的單值輪盤 sheet（`App2ValueWheelSheet`，編輯課表同一支），
        // 不為這一頁另做一顆數字輸入。
        .sheet(item: $adjustingItem) { item in
            App2ValueWheelSheet(
                title: L10n.App2.WeeklyReview.adjustSheetTitle.localized,
                options: App2DecisionChainAdjustRange.options(for: item),
                label: { App2DecisionChainAdjustRange.label(for: item, value: $0) },
                unit: nil,
                initialValue: App2DecisionChainAdjustRange.initialValue(for: item)
            ) { value in
                Task {
                    await viewModel.answer(
                        item: item,
                        status: .adjusted,
                        // 整數條目要送回整數：後端收的是
                        // `StrictInt | StrictFloat | StrictStr`，型別換了下游就換了意思。
                        adjustedValue: DecisionChainValue.matchingKind(of: item.proposed, number: value)
                    )
                }
            }
            .presentationDetents([.height(360)])
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

    /// 內容區的捲動殼。**只有一份**——有回顧與沒回顧兩條分支畫的是同一個容器，
    /// 各寫一次遲早只改一邊。
    private func contentScroll<Body: View>(@ViewBuilder _ body: () -> Body) -> some View {
        ScrollView {
            VStack(spacing: 14) { body() }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let projection = viewModel.projection {
            contentScroll {
                switch activeTab {
                case .review: reviewTab(projection)
                case .plan:   planTab(projection)
                }
            }
        } else if activeTab == .plan, showsPlanTabWithoutReview {
            // 回顧沒有內容，但這一週產得出來——規劃分頁照畫（見上方 E03 的說明）。
            contentScroll { planTab(nil) }
        } else if Self.showsGeneratingAnimation(
            hasProjection: viewModel.projection != nil,
            isLoading: viewModel.isLoading
        ) {
            Spacer()
            App2GeneratingView(
                // 文案取 1.4 既有的那三則（三語都在 `training.loading.*`），不另立一份。
                messages: LoadingAnimationView.LoadingType.generateReview.messages,
                // identifier 由元件掛在文案那個 `Text` 上——掛在這裡的外層容器查不到。
                identifier: "App2_WeeklyReviewGenerating"
            )
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
    ///
    /// **產生視窗未開時也沒有鈕**（T-0362）：後端平日只准產上週回顧，週日才准產本週
    /// （`plan_generation_window.py:37`）。修復前這裡照樣畫一顆註定 400 的鈕，
    /// 按下去才改口說「還不能產生」。現在直接把「什麼時候才能產生」寫在空態上
    /// ——同一句既有的三語文案（`app2.weekly_review.generation_window_closed`），
    /// 不為這個態新開字串。
    private var generatePrompt: some View {
        let canGenerate = viewModel.canGenerateReview
        return VStack(spacing: 14) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(App2Theme.accentBlue)
            Text(Self.emptyStateBody(isReadOnly: isReadOnly, canGenerate: canGenerate))
                .font(.app2Body)
                .foregroundStyle(App2Theme.inkTertiary)
                .multilineTextAlignment(.center)
            if Self.showsGenerateButton(isReadOnly: isReadOnly, canGenerate: canGenerate) {
                primaryButton(
                    title: L10n.App2.WeeklyReview.generate.localized,
                    isBusy: viewModel.isLoading,
                    identifier: "App2_WeeklyReviewGenerate"
                ) {
                    if Self.needsCompletionConfirm(isCurrentWeek: isCurrentWeek, isReadOnly: isReadOnly) {
                        showsCompletionConfirm = true
                    } else {
                        Task { await viewModel.generate() }
                    }
                }
                .padding(.horizontal, App2Theme.pagePadding)
            }
            Spacer()
        }
        // 容器不宣告 `.contain` 的話，SwiftUI 會把容器的 identifier 蓋到每個子元素上，
        // 於是產生鈕自己的 `App2_WeeklyReviewGenerate` 一個都查不到（2026-09-03 實測，
        // 與規劃清單那三顆鈕同一個坑）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            Self.emptyStateIdentifier(isReadOnly: isReadOnly, canGenerate: canGenerate)
        )
        .alert(
            L10n.Training.confirmTrainingCompletedTitle.localized,
            isPresented: $showsCompletionConfirm
        ) {
            Button(L10n.Common.cancel.localized, role: .cancel) {}
            Button(L10n.Common.confirm.localized) {
                Task { await viewModel.generate() }
            }
        } message: {
            Text(L10n.Training.confirmTrainingCompletedMessage.localized)
        }
    }

    // MARK: - 週日產生本週回顧前先確認訓練都做完了（T-0409）
    //
    // 1.x 有這一步（`Views/Training/Components/GenerateNextWeekButton.swift:51`），
    // 2.0 的產生鈕直接呼 `generate()` 把它漏掉了。理由不是禮貌問句：週日產的是**還在進行中
    // 的這一週**，使用者可能今天的課還沒跑；回顧吃的是那一週的完整訓練資料，早一步產出來
    // 的分析會少掉最後一天。字串沿用 1.x 那一組（三語都在），不新開。
    //
    // **另一半在 VM 的 `autoGeneratesOnLoad`**（2026-09-03 模擬器實測發現）：週日開這一頁
    // 原本就會自己 `POST` 把回顧產掉，鈕連畫都沒畫出來過。只在鈕上掛確認框等於沒做。

    /// 按「產生回顧」要不要先確認。**只有目標週＝本週**（週日流程）才問。
    ///
    /// 平日流程回顧的是**上一週**（`isCurrentWeek == false`）——那一週已經過完，
    /// 沒有「還沒完成」可以確認，多跳一個 alert 只是多一次點擊。
    /// 唯讀歷史週本來就沒有產生鈕（`showsGenerateButton`），這裡一併寫死成 false，
    /// 免得將來有人給唯讀態接上別的產生入口時把這條判準繞過去。
    nonisolated static func needsCompletionConfirm(isCurrentWeek: Bool, isReadOnly: Bool) -> Bool {
        !isReadOnly && isCurrentWeek
    }

    // MARK: - 空態的三格（抽成具名判準才釘得住，同 `showsGeneratingAnimation`）
    //
    // 就地寫條件的話，「視窗未開時那顆鈕不見了」只有肉眼看得出來——這正是 T-0362
    // 修的那種缺陷（畫面獻上一顆註定失敗的鈕，沒有任何東西擋著）。

    /// 空態那句話。唯讀 →「這一週沒有產生過回顧」；視窗未開 →「要等這一週跑完」；
    /// 其餘 →「還沒產生」（配一顆產生鈕）。三句都是既有字串，沒有新開。
    static func emptyStateBody(isReadOnly: Bool, canGenerate: Bool) -> String {
        if isReadOnly { return L10n.App2.WeeklyReview.historyNotGeneratedBody.localized }
        return canGenerate
            ? L10n.App2.WeeklyReview.notGeneratedBody.localized
            : L10n.App2.WeeklyReview.generationWindowClosed.localized
    }

    /// 產生鈕在不在。唯讀不給（會產錯週）；視窗未開不給（必然 400）。
    static func showsGenerateButton(isReadOnly: Bool, canGenerate: Bool) -> Bool {
        !isReadOnly && canGenerate
    }

    /// 空態的 accessibility identifier —— Maestro flow 靠它分辨兩種空態。
    static func emptyStateIdentifier(isReadOnly: Bool, canGenerate: Bool) -> String {
        (isReadOnly || canGenerate)
            ? "App2_WeeklyReviewNotGenerated"
            : "App2_WeeklyReviewWindowClosed"
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
        // 回顧的最後一件事是「所以下週怎麼跑」——這裡不給出口，使用者就停在這裡。
        // 規劃分頁收掉時它也要跟著收：它唯一的作用是切到那一頁。
        if showsPlanTab {
            continueToPlanButton
                .padding(.top, 4)
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

    /// 規劃分頁。**兩條互斥的內容**（AC-TRAIN-HUB-12）：decision-chain 的逐條清單，
    /// 或 AC-TRAIN-HUB-10 的既有 apply-items 建議清單。**同一分頁不並列兩份**
    /// （`AGENTS.md` 鐵則 0），所以這裡是 switch 不是兩段疊加。
    @ViewBuilder
    private func planTab(_ projection: App2WeeklyReviewProjection?) -> some View {
        switch viewModel.decisionChain {
        case .running:
            // `run` 也是數十秒的 LLM——沿用 AC-TRAIN-HUB-11 的生成中形態，
            // 不在這一頁另立第二種等待視覺。
            App2GeneratingView(
                messages: LoadingAnimationView.LoadingType.generateReview.messages,
                identifier: "App2_WeeklyReviewPlanGenerating"
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .ready(let checklist, let card):
            decisionChainTab(checklist: checklist, card: card)
        case .idle, .unavailable:
            if let projection {
                legacyPlanTab(projection)
            } else {
                // 沒有回顧就沒有 apply-items 建議可列——這與「這一輪沒有建議」是同一個
                // 畫面，不是失敗態（AC-TRAIN-HUB-10：無建議項不得成為零出口）。
                noSuggestionsCard
            }
        }
        // 建議清單只讓使用者對後端提的項目按接受／略過；**說出自己下週的狀況**沒有出口
        // （8/28 盤點 F15：Android 這一頁底下一直有這一區，iOS 沒有）。
        //
        // **歷史週唯讀回看不畫這一區**（裁決（q），外審第七輪 A06／B02）：它的送出會打
        // `RizoRepository.streamChat`（`weekly_situation`），是一條寫入路徑。這一頁其他的
        // 寫入出口（產生、套用、採納）本來就各自擋了 `isReadOnly`，F15 是本批新加的，
        // 加的時候漏掉同一道閘。
        if Self.showsDiscussSection(isReadOnly: isReadOnly) {
            discussSection
        }
    }

    // MARK: - 規劃下週 · decision-chain 逐條清單（AC-TRAIN-HUB-12）

    @ViewBuilder
    private func decisionChainTab(
        checklist: DecisionChainChecklist,
        card: DecisionChainIntentCard?
    ) -> some View {
        if let card, card.hasContent {
            intentExplainCard(card)
        }
        if checklist.items.isEmpty {
            // 那一輪一顆旋鈕都沒轉：使用者沒有東西可勾，按「產生」就是答完
            // （設計 §4.1b 第 7 條）。**這不是失敗態**，不退回既有清單。
            App2Card(padding: 15, spacing: 6) {
                Text(L10n.App2.WeeklyReview.planningEmpty.localized)
                    .font(.app2Body)
                    .foregroundStyle(App2Theme.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("App2_WeeklyReviewPlanningEmpty")
        } else {
            section(
                String(
                    format: L10n.App2.WeeklyReview.planningSection.localized,
                    checklist.items.count
                )
            ) {
                VStack(spacing: 10) {
                    ForEach(checklist.items) { item in
                        checklistCard(item)
                    }
                }
            }
        }
    }

    /// 清單頂端的**唯讀說明**（設計 §4.1，2026-09-02 晚裁決）。
    /// **這張卡上沒有任何動作**——接受與否逐條做在清單上，意圖的 lifecycle 由清單推導。
    private func intentExplainCard(_ card: DecisionChainIntentCard) -> some View {
        App2AccentCard(strength: 0.11, padding: 16, spacing: 11) {
            HStack(spacing: 9) {
                App2Avatar(initial: "R", size: 26, showsRing: false)
                Text(L10n.App2.WeeklyReview.intentSection.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 6)
            }
            if let pursuing = card.expression.pursuing {
                Text(pursuing)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // `maintaining`／`abandoning` 是 null 就整列不畫（設計 §4.1 第 4 條）——
            // 不畫「這一段沒有放棄的項目」那種列。
            if let maintaining = card.expression.maintaining {
                labelledLine(L10n.App2.WeeklyReview.intentMaintaining.localized, maintaining)
            }
            if let abandoning = card.expression.abandoning {
                labelledLine(L10n.App2.WeeklyReview.intentAbandoning.localized, abandoning)
            }
            if let rationale = card.expression.rationale {
                labelledLine(L10n.App2.WeeklyReview.intentRationale.localized, rationale)
            }
            if !card.hypotheses.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.App2.WeeklyReview.intentHypotheses.localized)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(App2Theme.inkMuted)
                    ForEach(card.hypotheses) { hypothesis in
                        ForEach(
                            [hypothesis.interventionDescription, hypothesis.predictionDescription]
                                .compactMap { $0 },
                            id: \.self
                        ) { line in
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5, weight: .bold))
                                    .foregroundStyle(App2Theme.accentBlueDeep)
                                    .padding(.top, 6)
                                Text(line)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(App2Theme.inkSecondary)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 同清單一條：容器自己是一個元素，否則這張卡的每一行文字都叫
        // `App2_WeeklyReviewIntentCard`（實測 5 個）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("App2_WeeklyReviewIntentCard")
    }

    private func labelledLine(_ label: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(App2Theme.inkMuted)
            Text(body)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(App2Theme.inkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 清單上的一條。三個動作：接受／不要／調整。
    ///
    /// **「調整」只在數值型的條目出現**：`rest_ratio` 的 `1:1`、`recovery_kind` 的
    /// `jog` 沒有輪盤可以轉，畫一顆按下去無值可送的鈕是死路。
    private func checklistCard(_ item: DecisionChainChecklistItem) -> some View {
        let isPending = viewModel.pendingChecklistItemIds.contains(item.itemId)
        return App2LeftStripCard(
            strip: checklistStripColor(item.status),
            padding: EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15)
        ) {
            // `title`／`reason` 是後端翻好的人話（設計 §4.1b 第 2 條），app 不重組。
            Text(item.title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !item.reason.isEmpty {
                Text(item.reason)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                checklistChip(
                    title: L10n.App2.WeeklyReview.accept.localized,
                    isOn: item.status == .accepted,
                    tint: App2Theme.accentGreen,
                    identifier: "App2_WeeklyReviewChecklistAccept_\(item.field)"
                ) {
                    Task { await viewModel.answer(item: item, status: .accepted) }
                }
                checklistChip(
                    title: L10n.App2.WeeklyReview.decline.localized,
                    isOn: item.status == .declined,
                    tint: App2Theme.inkTertiary,
                    identifier: "App2_WeeklyReviewChecklistDecline_\(item.field)"
                ) {
                    Task { await viewModel.answer(item: item, status: .declined) }
                }
                if item.allowsAdjust {
                    checklistChip(
                        title: L10n.App2.WeeklyReview.adjust.localized,
                        isOn: item.status == .adjusted,
                        tint: App2Theme.accentBlue,
                        identifier: "App2_WeeklyReviewChecklistAdjust_\(item.field)"
                    ) {
                        adjustingItem = item
                    }
                }
                Spacer(minLength: 0)
                if isPending {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(.top, 4)
            // 唯讀回看不可表態（送出去是寫入路徑），忙碌時不接第二次點擊。
            .disabled(isReadOnly || isPending)
            .opacity((isReadOnly || isPending) ? 0.55 : 1)
        }
        // **容器自己是一個元素，子元素保留各自的 id。** 沒有這一行，SwiftUI 會把容器的
        // identifier 套到每一個子元素上（2026-09-03 實測：`maestro hierarchy` 8 個元素
        // 全叫 `App2_WeeklyReviewChecklistItem_…`，Accept／Decline／Adjust 三顆的 id
        // 一個都看不到），自動化按不到任何一顆按鈕。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            Self.checklistItemIdentifier(field: item.field, status: item.status)
        )
    }

    /// 清單一條的 accessibility identifier。**狀態寫進 id**，做法同
    /// `emptyStateIdentifier`：「按了接受之後那一條真的變了」在畫面上只有顏色差別，
    /// 走查看得到、自動化看不到——沒有東西擋著，回歸就只能靠肉眼。
    static func checklistItemIdentifier(
        field: String,
        status: DecisionChainChecklistItem.Status
    ) -> String {
        "App2_WeeklyReviewChecklistItem_\(field)_\(status.rawValue)"
    }

    private func checklistChip(
        title: String,
        isOn: Bool,
        tint: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        choiceChip(title: title, isOn: isOn, tint: tint)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
    }

    private func checklistStripColor(_ status: DecisionChainChecklistItem.Status) -> Color {
        switch status {
        case .accepted: return App2Theme.accentGreen
        case .adjusted: return App2Theme.accentBlue
        case .declined: return App2Theme.inkTertiary
        case .proposed: return App2Theme.accentOrangeBright
        }
    }

    // MARK: - 規劃下週 · 既有路徑（AC-TRAIN-HUB-10，decision-chain 讀不到時的 fail-open）

    @ViewBuilder
    private func legacyPlanTab(_ projection: App2WeeklyReviewProjection) -> some View {
        verdictCard(projection)
        if projection.suggestions.isEmpty {
            noSuggestionsCard
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

    private var noSuggestionsCard: some View {
        App2Card(padding: 15, spacing: 6) {
            Text(L10n.App2.WeeklyReview.noSuggestions.localized)
                .font(.app2Body)
                .foregroundStyle(App2Theme.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("App2_WeeklyReviewNoSuggestions")
    }

    /// 內容區要不要畫「正在生成」的動畫（AC-TRAIN-HUB-11）。
    ///
    /// **判準沿用 VM 既有的 `isLoading`，不另立第二套「生成中」狀態。** 這一頁的等待態
    /// 只有一種：`load()` 與 `generate()` 都是把 `isLoading` 翻真、直到 `projection`
    /// 出現為止（`App2WeeklyReviewViewModel.load` / `.generate`）。Android 的
    /// `SummaryUiState.Generating` 同樣同時涵蓋 GET 與 POST 兩條路——兩台對「在等後端給
    /// 這一週的回顧」是同一個狀態，不是兩個。
    ///
    /// 抽成具名判準而不是就地寫條件，是為了讓「生成中 → 動畫在」這條綁定可以被測試釘住。
    static func showsGeneratingAnimation(hasProjection: Bool, isLoading: Bool) -> Bool {
        !hasProjection && isLoading
    }

    /// 歷史週唯讀回看有沒有 F15 討論區。
    ///
    /// 抽成具名判準而不是就地寫 `!isReadOnly`，是因為這條規則被漏掉過一次：唯讀是
    /// 裁決（q）的產品承諾，而「有沒有漏掉某一個寫入出口」用眼睛看不出來，要有東西擋著。
    static func showsDiscussSection(isReadOnly: Bool) -> Bool { !isReadOnly }

    // MARK: - 和 Rizo 討論（frame-19 底部；8/28 盤點 F15）

    /// 下週規劃的自由輸入區。回覆就地顯示一則泡泡，不另開對話頁 ——
    /// 這裡要的是「補一句我的狀況」，不是一場對話。
    private var discussSection: some View {
        section(L10n.App2.WeeklyReview.discussSection.localized) {
            App2Card(padding: 15, spacing: 11) {
                if let reply = discussViewModel.messages.last(where: { $0.role == .coach })?.text,
                   !reply.isEmpty {
                    Text(reply)
                        .font(.system(size: 14, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(App2Theme.accentBlue.opacity(0.08))
                        )
                        .accessibilityIdentifier("App2_WeeklyReviewDiscussReply")
                }
                HStack(spacing: 9) {
                    TextField(
                        L10n.App2.WeeklyReview.discussHint.localized,
                        text: $discussViewModel.draft
                    )
                    .font(.app2Body)
                    .disabled(discussViewModel.isReplying)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(App2Theme.insetBackground))
                    .accessibilityIdentifier("App2_WeeklyReviewDiscussInput")

                    let canSend = !discussViewModel.draft
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !discussViewModel.isReplying
                    Circle()
                        .fill(canSend ? App2Theme.accentBlue : App2Theme.dotInactive)
                        .frame(width: 34, height: 34)
                        .overlay {
                            if discussViewModel.isReplying {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            guard canSend else { return }
                            let text = discussViewModel.draft
                            Task {
                                await discussViewModel.send(text)
                                // Rizo 記下的下週修正會以清單上新的一條回來
                                // （`source == rizo`，AC-TRAIN-HUB-12）——**回覆完就重讀**，
                                // 不要求使用者第二次確認，也不在這裡自己造那一條。
                                await viewModel.refreshChecklistAfterRizo()
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("App2_WeeklyReviewDiscussSend")
                }
            }
            // 同上：不加這一行，`DiscussInput`／`DiscussSend`／`DiscussReply` 的 id
            // 會被容器的 `App2_WeeklyReviewDiscuss` 蓋掉。
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("App2_WeeklyReviewDiscuss")
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

    /// 規劃分頁的主 CTA。**修復前這裡只有「套用」**，於是回顧走完沒有任何地方能
    /// 產生課表 —— 訓練流程在這一頁斷掉（P0）。
    ///
    /// 三態，由 `App2WeeklyReviewViewModel.nextWeekAction` 分流，不在 view 自己再判
    /// 一次：能產生就產生（順帶把採納項送出去）、不能產生就只留套用、兩者都不成立
    /// 時整條不出現（不畫一顆按下去必然失敗的鈕，同走查裁決（k）的精神）。
    @ViewBuilder
    private var planFooter: some View {
        switch viewModel.nextWeekAction {
        case .generate(let week):
            footerContainer {
                primaryButton(
                    title: generateTitle(week: week),
                    isBusy: viewModel.isGeneratingPlan || viewModel.isApplying,
                    identifier: "App2_WeeklyReviewGeneratePlan"
                ) {
                    Task {
                        // 產生成功＝這條流程走完了。停在回顧頁會讓人找不到新課表
                        //（2026-08-31 使用者回報），所以刷完資料就退回進來的那一頁。
                        if await viewModel.applyAndGenerate() {
                            onApplied?()
                            onClose()
                        }
                    }
                }
            }
        case .applyOnly:
            footerContainer {
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
        case .none:
            EmptyView()
        }
    }

    /// 產生鈕的文字。三句話對應三種語意（沿用 1.4 `generateButtonText` 的分法）：
    /// 沒有建議項可選、選了 N 項要一起套用、有建議項但一項都沒選。
    private func generateTitle(week: Int) -> String {
        if viewModel.isGeneratingPlan {
            return L10n.App2.WeeklyReview.generatingPlan.localized
        }
        // decision-chain 路徑的答案在清單上逐條落地，這顆鈕不再帶「套用 N 項」
        // ——它不送 apply-items，寫著套用幾項就是說謊。
        if viewModel.usesDecisionChain {
            return String(format: L10n.App2.WeeklyReview.generatePlan.localized, week)
        }
        let hasSuggestions = !(viewModel.projection?.suggestions.isEmpty ?? true)
        if !hasSuggestions {
            return String(format: L10n.App2.WeeklyReview.generatePlan.localized, week)
        }
        if viewModel.selectedCount > 0 {
            return String(
                format: L10n.App2.WeeklyReview.applyAndGeneratePlan.localized,
                viewModel.selectedCount,
                week
            )
        }
        return String(format: L10n.App2.WeeklyReview.generatePlanWithoutApplying.localized, week)
    }

    private func footerContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 11)
            .padding(.bottom, 24)
            .background(App2Theme.pageBottom.ignoresSafeArea(edges: .bottom))
    }

    /// 回顧分頁底部的前進入口（使用者實機回報：看完回顧沒有下一步）。
    ///
    /// 頂部的分段切換器是「切分頁」，不是「下一步」—— 使用者捲到回顧最底下時它已經
    /// 不在視野內。1.4 的同一頁一直有這顆（`v2.summary.continue_to_plan_button`），
    /// App2 漏接。**只切分頁，不是寫入路徑**，所以唯讀回看也給。
    private var continueToPlanButton: some View {
        HStack(spacing: 7) {
            Text(
                isCurrentWeek
                    ? L10n.App2.WeeklyReview.continueToPlan.localized
                    : String(format: L10n.App2.WeeklyReview.continueToPlanWeek.localized, weekOfPlan + 1)
            )
            .font(.system(size: 16, weight: .heavy))
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .black))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(App2Theme.accentBlue)
        )
        .shadow(color: App2Theme.accentBlue.opacity(0.6), radius: 11, x: 0, y: 10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { tab = .plan }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_WeeklyReviewContinueToPlan")
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
