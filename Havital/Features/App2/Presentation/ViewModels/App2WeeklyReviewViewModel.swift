import Foundation
import SwiftUI

// MARK: - App2WeeklyReviewViewModel
/// Presentation Layer — 2.0 週回顧（設計 frame-18／frame-19）。
///
/// **載入、產生、採納全部委派給 1.4 既有的 `WeeklySummaryCoordinator`**
/// （`GET/POST /v2/summary/weekly`、`POST /v2/summary/weekly/apply-items`）。
/// 這一層只做三件事：把 coordinator 的跨邊界 closure 接到自己的狀態、把
/// `WeeklySummaryV2` 交給 `App2WeeklyReviewProjection`、記住使用者的採納勾選。
///
/// **訂閱與 Rizo 額度的 gate 一定要接上。** 那些 closure 不是樣板：
/// `isEnforcementEnabled` ＋ `onWeeklyReviewInlineUpsellNeeded` 是 AC-PAYWALL-23 的
/// 週回顧付費閘門，`shouldBlockByRizoQuota` 是額度耗盡的攔截。接成 no-op 就是靜默
/// 繞過付費閘門。
@MainActor
final class App2WeeklyReviewViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var projection: App2WeeklyReviewProjection?
    @Published private(set) var isLoading = false
    @Published private(set) var isApplying = false
    /// 讀不到／產不出來時的訊息。nil ＝ 沒有錯誤。
    @Published private(set) var errorMessage: String?
    /// 這一週還沒有回顧 —— 畫面顯示「產生回顧」而不是空白。
    @Published private(set) var needsGeneration = false
    /// 週回顧被付費閘門擋下（AC-PAYWALL-23）。
    @Published var showsUpsell = false
    /// Rizo 額度耗盡。
    @Published var showsQuotaExceeded = false
    /// 採納成功後的提示。
    @Published var toast: String?

    /// 使用者目前的採納勾選（index → 要不要採納）。**index 是後端的
    /// `applied_indices`**，所以直接用 coordinator 的那一份，不另存一份。
    var selections: [Int: Bool] { coordinator.adjustmentSelections }

    // MARK: - 產生目標週課表（P0：「規劃下週」原本沒有這個出口）

    /// 最近一次讀到的 plan status —— 目標週能不能產生，判準全部從它推。
    @Published private(set) var planStatus: PlanStatusV2Response?
    /// 產生中（數十秒），擋住重複點擊。
    @Published private(set) var isGeneratingPlan = false
    /// 產生失敗的訊息（可重試）。
    @Published var generateError: String?

    // MARK: - 規劃下週的 decision-chain 清單（AC-TRAIN-HUB-12）

    /// 規劃分頁現在拿得出什麼。
    ///
    /// **`unavailable` 不是錯誤態**：它就是 AC-TRAIN-HUB-10 的既有分頁
    /// （apply-items 建議清單 → `POST /v2/plan/weekly`）。訓練流程核心一律 fail-open，
    /// decision-chain 讀不到不得擋住產生課表。
    enum DecisionChainState: Equatable {
        /// 還沒判（頁面剛開）。
        case idle
        /// `run` 在飛（真 LLM，數十秒）。
        case running
        /// 清單在手。`items` 可以是空陣列（那一輪一顆旋鈕都沒轉，設計 §4.1b 第 7 條）。
        case ready(DecisionChainChecklist, DecisionChainIntentCard?)
        /// 走既有路徑。
        case unavailable
    }

    @Published private(set) var decisionChain: DecisionChainState = .idle
    /// 這幾條的表態還在飛（擋重複點擊，也讓那一條畫得出忙碌態）。
    @Published private(set) var pendingChecklistItemIds: Set<String> = []
    /// 表態沒送出去的提示。
    @Published var checklistError: String?

    /// 這一頁走的是 decision-chain 清單嗎。**`applyAndGenerate()` 用它決定要不要送
    /// apply-items**——兩份清單不得並列，也不得兩條路都送（鐵則 0）。
    var usesDecisionChain: Bool {
        if case .ready = decisionChain { return true }
        return false
    }

    /// 只跑一次。`run` 是一次真 LLM，重新整理不該再燒一次。
    private var didStartDecisionChain = false

    /// `run → checklist → 說明卡` 那一條。**`load()` 刻意不等它**——不等才是「並行」。
    /// 留成 property 是為了讓測試等得到它（`internal`，`@testable` 可見）。
    private(set) var decisionChainTask: Task<Void, Never>?

    // MARK: - Dependencies

    private var coordinator: WeeklySummaryCoordinator!
    /// 這一頁看的是哪一週。由呼叫端（首頁 CTA）決定：平日是上週，週日是本週。
    private let weekOfPlan: Int
    /// 歷史週唯讀回看（走查裁決（q））。產生課表是寫入路徑，唯讀時一律不給出口。
    private let isReadOnly: Bool
    /// 「產生目標週課表」走的是既有出口 `POST /v2/plan/weekly`，與課表頁同一支
    /// repository —— 不另開資料路徑。
    private let planRepository: TrainingPlanV2Repository
    /// 下週規劃清單（AC-TRAIN-HUB-12）。同一顆 `TrainingPlanV2RepositoryImpl` 的窄協定，
    /// 不是第二條資料路徑。**解不到就是 nil**——那時規劃分頁走 AC-TRAIN-HUB-10 的
    /// 既有路徑（fail-open），不是壞掉。
    private let decisionChainRepository: DecisionChainWeekRepository?

    init(
        weekOfPlan: Int,
        isReadOnly: Bool = false,
        repository: TrainingPlanV2Repository? = nil,
        decisionChainRepository: DecisionChainWeekRepository? = nil
    ) {
        self.weekOfPlan = weekOfPlan
        self.isReadOnly = isReadOnly

        let container = DependencyContainer.shared
        if repository == nil, !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        let resolved: TrainingPlanV2Repository = repository ?? container.resolve()
        self.planRepository = resolved
        self.decisionChainRepository = decisionChainRepository ?? container.tryResolve()

        self.coordinator = WeeklySummaryCoordinator(
            repository: resolved,
            currentSelectedWeek: { [weak self] in self?.weekOfPlan ?? 1 },
            // 2.0 沒有那個**全螢幕**的載入動畫層，載入／生成態是這一頁自己的 `isLoading`
            // ——畫面上的生成動畫由 `App2WeeklyReviewView` 依它渲染（AC-TRAIN-HUB-11），
            // 所以這個 closure 仍然是 no-op，不是「2.0 沒有生成動畫」。
            setLoadingAnimation: { _ in },
            shouldBlockByRizoQuota: { await Self.isRizoQuotaExhausted() },
            // 這一頁不持有 plan status，重新整理由首頁在關閉時做。
            refreshPlanStatusResponse: { },
            shouldSuppressError: { domainError, context, onDataCorruption in
                Self.shouldSuppressError(domainError, context: context, onDataCorruption: onDataCorruption)
            },
            resolvePaywallTrigger: { Self.resolvePaywallTrigger() },
            onSuccessToast: { [weak self] message in self?.toast = message },
            onPaywallTriggered: { [weak self] _ in self?.showsUpsell = true },
            onRizoQuotaExceeded: { [weak self] in self?.showsQuotaExceeded = true },
            onNetworkError: { [weak self] error in
                // 一樣不把 server body 印到畫面上（見 `applyState`）。
                Logger.error("[App2WeeklyReviewVM] 網路錯誤: \(error.toDomainError().localizedDescription)")
                self?.errorMessage = L10n.App2.Common.loadFailed.localized
            },
            isEnforcementEnabled: { SubscriptionStateManager.shared.isEnforcementEnabled },
            onWeeklyReviewInlineUpsellNeeded: { [weak self] in self?.showsUpsell = true }
        )
    }

    // MARK: - 載入

    func loadIfNeeded() async {
        guard projection == nil, !isLoading else { return }
        await load()
    }

    /// **plan status 先拿，再載回顧。**
    ///
    /// 順序不能反（T-0362）：`getWeeklySummary` 的 404 fallback 會直接 `POST`
    /// （`TrainingPlanV2RepositoryImpl.fetchOrGenerateWeeklySummary`），所以
    /// 「這一週現在能不能產生」必須在**發出那個請求之前**就知道。先載回顧再問 status
    /// 的話，判準永遠晚一步——鈕是藏起來了，但請求早就送出去了。
    func load() async {
        isLoading = true
        errorMessage = nil
        await refreshPlanStatus()
        // decision-chain 的 `run` 也要跑數十秒的 LLM。**與週回顧生成並行**
        // （AC-TRAIN-HUB-12）——串起來等於讓使用者等兩次。這裡只起頭不等它，
        // 規劃分頁自己依 `decisionChain` 畫生成中／清單。
        startDecisionChainIfNeeded()
        // 視窗未開（或歷史週唯讀）＝這一輪只讀不寫：沒有回顧就是沒有，
        // 不在背後補一份，也不送註定 400 的請求。
        await coordinator.loadWeeklySummary(
            weekOfPlan: weekOfPlan,
            allowGenerate: canGenerateReview
        )
        applyState(afterGenerate: false)
        isLoading = false
    }

    // MARK: - 產生視窗（T-0362：週一進本週回顧，按「產生」被後端 400）
    //
    // `POST /v2/summary/weekly` 有一道**週次窗口閘門**
    // （`core/training_rules/plan_generation_window.py:37 allowed_week_for_kind`
    // ＋ `:58 decide_week_generation`）：平日只准產 `current_week − 1`，週日才准產
    // `current_week`。不符回 HTTP 400 `weekly_summary_generation_window_denied`。
    //
    // 課表頁 header 的回顧入口（走查裁決（q））帶的是**當前所選週**，進行中就是本週。
    // 所以週一點進來看到的是本週回顧的未產生態——修復前照樣獻上「產生週回顧」鈕，
    // 按下去必然 400，畫面才改口說「還不能產生」。使用者原話：
    // 「還不能產生週回顧，卻可以在右上角顯示週回顧，點進去還可以按產生，
    //   再說無法產生 -> 什麼鬼啊」（2026-08-31 實機）。
    //
    // **判準不看 device 星期**（設計 `DESIGN-app2-weekly-review-and-plan-end-inventory`
    // §A.5：client 不算週界）：週日與否走既有的
    // `App2HomeViewModel.isSundayInUserTimezone(_:)`——那是 §A.1 訂下的唯一咽喉點
    // （`metadata.user_timezone` ＋ `server_time`），不在這裡開第二份週日判定。

    /// 今天後端讓不讓產生第 `reviewWeek` 週的回顧。
    ///
    /// 逐格對上後端那支純函式（`allowed_week_for_kind(kind: "weekly_summary")`）：
    ///
    /// | 當天（使用者時區） | 允許的週次 |
    /// |---|---|
    /// | 平日、`current_week ≥ 2` | `current_week − 1` |
    /// | 平日、`current_week ≤ 1` | 無（後端算出 `allowed_week = 0`，而週次 0 client 打不出去） |
    /// | 週日 | `current_week`；catch-up 另放行 `current_week − 1` |
    ///
    /// **status 讀不到（nil）時回 true**。那時什麼都判不出來，擋掉按鈕會讓使用者
    /// 在一個沒有任何出口的畫面上卡死——訓練流程核心一律 fail-open
    /// （`LOCAL-DEVELOPMENT-HARNESS.md` §1.2 鐵則 7）。真的撞到 400 時仍有
    /// `generationWindowClosed` 那句話接住，不會退回修復前那種無訊息的失敗。
    nonisolated static func isGenerationWindowOpen(
        reviewWeek: Int,
        planStatus: PlanStatusV2Response?,
        isSunday: Bool
    ) -> Bool {
        guard let current = planStatus?.currentWeek else { return true }
        if isSunday {
            // 本週；catch-up 再放行上週（後端 `allowed_sunday_previous_week_summary_catch_up`）。
            return reviewWeek == current || (reviewWeek == current - 1 && reviewWeek >= 1)
        }
        return current >= 2 && reviewWeek == current - 1
    }

    /// 這一頁能不能按「產生回顧」。
    ///
    /// 唯讀回看永遠不能（那顆鈕產的是這一頁的 `weekOfPlan`，而歷史週不該被補寫）。
    var canGenerateReview: Bool {
        guard !isReadOnly else { return false }
        guard let planStatus else { return true }
        return Self.isGenerationWindowOpen(
            reviewWeek: weekOfPlan,
            planStatus: planStatus,
            // 不另開第二份週日判定（鐵則 0）：§A.1 的咽喉點就是這一支。
            isSunday: App2HomeViewModel.isSundayInUserTimezone(planStatus)
        )
    }

    /// 產生這一週的回顧（首頁 CTA 是「產生上週／本週回顧」時走這條）。
    func generate() async {
        // 判準住在 VM，不只住在畫面：視窗未開時那顆鈕根本不畫，這裡是最後一道
        // ——不送出一個註定 400 的 LLM 請求。
        guard canGenerateReview else {
            errorMessage = L10n.App2.WeeklyReview.generationWindowClosed.localized
            return
        }
        isLoading = true
        errorMessage = nil
        needsGeneration = false
        await coordinator.generateWeeklySummary()
        applyState(afterGenerate: true)
        // 回顧剛生成 ⇒ 後端的 `has_current_summary` 翻真、`next_action` 從
        // `create_summary` 變 `create_plan`。不重取的話「產生下週課表」的判準會
        // 讀到產生前那一份，CTA 停在上一個狀態。
        await refreshPlanStatus()
        isLoading = false
    }

    /// 目標週能不能產生課表，全部從 plan status 推 —— 這一頁不自己從日期算週次。
    ///
    /// 失敗不擋畫面：讀不到 status 只代表沒有產生入口（`nextWeekAction` 會退回
    /// 「只能套用」），回顧本身照常顯示。
    private func refreshPlanStatus() async {
        do {
            planStatus = try await planRepository.getPlanStatus(forceRefresh: true)
        } catch {
            guard !error.isCancellationError else { return }
            Logger.debug("[App2WeeklyReviewVM] plan status 取得失敗，暫無產生入口: \(error.toDomainError())")
        }
    }

    /// - Parameter afterGenerate: 這一輪是「按了產生」之後。按過了還說「還沒產生」
    ///   會讓使用者一直按同一顆鈕 —— 那時要講清楚是後端還不讓產（產生視窗未開）。
    private func applyState(afterGenerate: Bool) {
        switch coordinator.weeklySummary {
        case .loaded(let summary):
            projection = App2WeeklyReviewProjection.make(summary)
            needsGeneration = false
            errorMessage = nil
        case .empty:
            // **「還沒產生」不是「讀取失敗」。** 說錯這句話的代價是使用者以為壞了，
            // 而其實只是按鈕還沒按。
            projection = nil
            needsGeneration = true
        case .error(let error):
            projection = nil
            // **「這一週還沒有回顧」不是錯誤。** 後端對還沒產生的週回 404
            // （`Weekly summary not found`），也對「還不到能產生的時候」回 400
            // （`weekly_summary_generation_window_denied`）——兩個都是正常狀態，
            // 畫面該顯示「還沒產生」而不是紅字。
            if Self.meansNotGeneratedYet(error) {
                needsGeneration = !afterGenerate
                errorMessage = afterGenerate
                    ? L10n.App2.WeeklyReview.generationWindowClosed.localized
                    : nil
            } else {
                // **不要把 server body 直接印到畫面上。** `localizedDescription` 對
                // `serverError`／`badRequest` 帶的是後端原始 JSON，那對使用者是
                // 亂碼、對我們是資訊外洩。詳情進 log，畫面給在地化的一句話。
                Logger.error("[App2WeeklyReviewVM] 週回顧載入失敗: \(error.localizedDescription)")
                errorMessage = L10n.App2.Common.loadFailed.localized
            }
        case .loading:
            break
        }
    }

    // MARK: - 建議項採納（frame-19）

    func toggle(suggestionIndex index: Int) {
        coordinator.toggleAdjustment(at: index)
        objectWillChange.send()
    }

    var selectedCount: Int { coordinator.selectedCount }

    /// 「套用到下週課表」。走既有的 `POST /v2/summary/weekly/apply-items`。
    ///
    /// **全部取消勾選也要送。** 空的 `applied_indices` ＝ 撤銷既有採納；不送的話
    /// 上一次採納的休息週不會被清掉，下週還是會觸發（AC-WKADJ-04，規則在
    /// `WeeklySummaryCoordinator.applySelectedAdjustments`，這裡不重寫一份）。
    func applySelected() async -> Bool {
        guard !isApplying else { return false }
        isApplying = true
        let success = await coordinator.applySelectedAdjustments(weekOfPlan: weekOfPlan)
        isApplying = false
        if success {
            toast = L10n.App2.WeeklyReview.applied.localized
        }
        return success
    }

    // MARK: - 產生目標週課表（frame-19 的主 CTA）
    //
    // **修復前這一頁沒有產生入口。** 1.4 的同一頁主 CTA 是「產生下週課表」／
    // 「套用 %d 條建議並產生下週課表」（`WeeklySummaryV2View.generateButtonText`
    // → `WeeklyPlanGenerator.generateWeeklyPlanDirectly`）；App2 只接了 apply-items，
    // 於是使用者走完回顧後沒有任何地方能產生下週課表 —— 訓練流程在這裡斷掉。

    /// 這一頁的「下一步」是什麼。
    enum NextWeekAction: Equatable {
        /// 可以產生第 `week` 週課表（採納項一併送出）。
        case generate(week: Int)
        /// 只能採納建議，不能產生（產生視窗未開／目標週已有課表／歷史週）。
        case applyOnly
        /// 沒有出口（唯讀回看，或既無建議項也不能產生）。
        case none
    }

    /// 這一頁規劃分頁的目標週 ＝ 回顧週 + 1。
    ///
    /// 週日流程（回顧本週）目標是**下週**；平日流程（回顧上週）目標是**本週** ——
    /// 同一條式子涵蓋兩種，不為它們各開一條路徑。
    var targetWeek: Int { weekOfPlan + 1 }

    var nextWeekAction: NextWeekAction {
        Self.nextWeekAction(
            reviewWeek: weekOfPlan,
            planStatus: planStatus,
            hasSuggestions: !(projection?.suggestions.isEmpty ?? true),
            isReadOnly: isReadOnly
        )
    }

    /// 純函式判準，讓「什麼時候該出現產生鈕」可以被測試釘住。
    ///
    /// 判準全部來自後端事實（`domains/plan_week/service.py:1210` `build_plan_status`），
    /// 不自己另立一套：
    /// - 目標週 ＝ 本週（平日流程）：本週還沒課表、且 `next_action` 不是
    ///   `create_summary`（上週回顧還缺）也不是 `training_completed`。
    /// - 目標週 ＝ 下週（週日流程）：`next_week_info` 存在（後端只在使用者時區的
    ///   週日給它）、週次相符、且 `can_generate`（＝下週還沒課表）。
    ///
    /// `requires_current_week_summary` 不進判準：目標週＝下週蘊含 `reviewWeek ==
    /// current_week`，而這一頁畫得出 CTA 的前提就是**第 `reviewWeek` 週的回顧已經
    /// 載入在畫面上** —— 後端要的那份回顧正是使用者眼前這一份。plan status 是快取的，
    /// 會落後一輪；拿它去否決畫面上的既成事實就是把使用者鎖死（這正是本次 P0 的形狀）。
    nonisolated static func nextWeekAction(
        reviewWeek: Int,
        planStatus: PlanStatusV2Response?,
        hasSuggestions: Bool,
        isReadOnly: Bool
    ) -> NextWeekAction {
        // 歷史週唯讀回看沒有任何寫入出口（走查裁決（q））。
        guard !isReadOnly else { return .none }
        let fallback: NextWeekAction = hasSuggestions ? .applyOnly : .none
        guard let status = planStatus else { return fallback }

        let target = reviewWeek + 1
        if target == status.currentWeek {
            guard status.currentWeekPlanId == nil,
                  status.nextAction != "create_summary",
                  status.nextAction != "training_completed" else { return fallback }
            return .generate(week: target)
        }
        if target == status.currentWeek + 1 {
            guard let info = status.nextWeekInfo,
                  info.weekNumber == target,
                  info.canGenerate else { return fallback }
            return .generate(week: target)
        }
        return fallback
    }

    // MARK: - decision-chain：run → 清單 → 逐條表態（AC-TRAIN-HUB-12）

    /// 規劃分頁要跑的是哪一天的決策鏈：**使用者當地的今天**。
    ///
    /// 時區權威與週日判定同一個咽喉點（`metadata.user_timezone` ＋ `metadata.server_time`，
    /// `DESIGN-app2-weekly-review-and-plan-end-inventory` §A.1），**不看裝置時區**——
    /// dev 帳號的時區是 `Asia/Tokyo`，用裝置日期會算出前一天，`run` 與 `checklist`
    /// 就對不到同一份週 doc。時區名解不開才退回裝置日曆。
    nonisolated static func asOfInUserTimezone(
        _ status: PlanStatusV2Response?,
        deviceNow: Date = Date(),
        deviceCalendar: Calendar = .current
    ) -> String {
        if let calendar = App2WeekCalendar.calendar(inTimezone: status?.metadata?.userTimezone) {
            let instant = App2WeekCalendar.parseISO8601(status?.metadata?.serverTime) ?? deviceNow
            return App2WeekCalendar.isoDay(date: instant, calendar: calendar)
        }
        Logger.debug("[App2WeeklyReviewVM] plan status 缺 user_timezone，as_of 退回裝置日曆")
        return App2WeekCalendar.isoDay(date: deviceNow, calendar: deviceCalendar)
    }

    /// 這一週的產生被付費閘門擋著嗎（AC-PAYWALL-26）。
    ///
    /// 抽成具名判準是因為它有兩個消費點：CTA（擋生成）與 `run`（AC-TRAIN-HUB-12
    /// 明寫「擋生成的條件同樣擋 run」）。寫兩次遲早只改一邊。
    static func isBlockedByPaywall(week: Int) -> Bool {
        week >= 2
            && SubscriptionStateManager.shared.isEnforcementEnabled
            && !SubscriptionStateManager.shared.hasPremiumAccess
    }

    /// 規劃分頁的 decision-chain 起手。**只在 `.generate` 態跑**——歷史週、唯讀、
    /// `applyOnly`、`none` 都不是「要規劃下一週」，對它們發 `run` 是寫錯週的帳本。
    func startDecisionChainIfNeeded() {
        guard !didStartDecisionChain else { return }
        didStartDecisionChain = true

        guard let decisionChainRepository else {
            // 沒註冊（測試樁、UITest harness）＝這一頁走既有路徑，不是壞掉。
            decisionChain = .unavailable
            return
        }
        guard case .generate(let week) = nextWeekAction else {
            decisionChain = .unavailable
            return
        }
        // 付費閘門擋生成就同樣擋 `run`。**這裡只是不跑，不彈 upsell**——
        // 進頁就彈等於把付費牆提前到使用者還沒要求產生課表之前。
        guard !Self.isBlockedByPaywall(week: week) else {
            decisionChain = .unavailable
            return
        }

        let asOf = Self.asOfInUserTimezone(planStatus)
        decisionChain = .running
        decisionChainTask = Task { [weak self] in
            await self?.runDecisionChain(asOf: asOf, week: week, repository: decisionChainRepository)
        }
    }

    private func runDecisionChain(
        asOf: String,
        week: Int,
        repository: DecisionChainWeekRepository
    ) async {
        do {
            let run = try await repository.runDecisionChainWeek(asOf: asOf, weekOfTraining: week)
            // `generated` 與 `already_exists` 都是成功（AC-TRAIN-HUB-12）。
            Logger.debug("[App2WeeklyReviewVM] decision-chain run \(asOf) → \(run.status)")
        } catch {
            guard !error.isCancellationError else {
                decisionChain = .idle
                didStartDecisionChain = false
                return
            }
            Logger.debug("[App2WeeklyReviewVM] decision-chain run 失敗，走既有路徑: \(error.toDomainError())")
            decisionChain = .unavailable
            return
        }

        let checklist: DecisionChainChecklist?
        do {
            checklist = try await repository.fetchDecisionChainChecklist(asOf: asOf)
        } catch {
            guard !error.isCancellationError else {
                decisionChain = .idle
                didStartDecisionChain = false
                return
            }
            Logger.debug("[App2WeeklyReviewVM] 清單讀不到，走既有路徑: \(error.toDomainError())")
            decisionChain = .unavailable
            return
        }
        // 404（那一週沒 run 過）→ 沒有清單可畫 → 既有路徑。
        guard let checklist else {
            decisionChain = .unavailable
            return
        }

        // 說明區讀不到不影響清單：清單才是使用者要按的東西。
        let card = try? await repository.fetchDecisionChainIntentCard()
        decisionChain = .ready(checklist, card)
    }

    /// 對清單上的一條表態。**送出去之前先樂觀更新、失敗就把那一條退回原狀**——
    /// 後端寫入失敗時該條必須維持原狀，不得靜默當成 accepted（設計 §4.5a）。
    func answer(
        item: DecisionChainChecklistItem,
        status: DecisionChainChecklistItem.Status,
        adjustedValue: DecisionChainValue? = nil
    ) async {
        guard case .ready(let checklist, let card) = decisionChain,
              let decisionChainRepository else { return }
        guard !isReadOnly else { return }
        guard !pendingChecklistItemIds.contains(item.itemId) else { return }

        pendingChecklistItemIds.insert(item.itemId)
        checklistError = nil
        decisionChain = .ready(
            Self.replacing(checklist, with: item.with(status: status, adjustedValue: adjustedValue)),
            card
        )

        do {
            let updated = try await decisionChainRepository.recordDecisionChainChecklistStance(
                asOf: checklist.asOf,
                itemId: item.itemId,
                status: status,
                adjustedValue: adjustedValue
            )
            // **UI 以回應為準**，不以本地那一份樂觀值為準。
            if case .ready(let current, let currentCard) = decisionChain {
                decisionChain = .ready(Self.replacing(current, with: updated), currentCard)
            }
        } catch {
            if !error.isCancellationError {
                Logger.error("[App2WeeklyReviewVM] 清單表態失敗 \(item.itemId): \(error.toDomainError())")
                checklistError = L10n.App2.WeeklyReview.stanceFailed.localized
            }
            // 只退回這一條——整份回滾會把同時在飛的另一條也一起打掉。
            if case .ready(let current, let currentCard) = decisionChain {
                decisionChain = .ready(Self.replacing(current, with: item), currentCard)
            }
        }
        pendingChecklistItemIds.remove(item.itemId)
    }

    /// Rizo 回覆之後重讀清單（AC-TRAIN-HUB-12）。Rizo 記下的修正會以清單上新的一條
    /// 回來（`source == rizo`），使用者不再被要求第二次確認。
    func refreshChecklistAfterRizo() async {
        guard case .ready(let checklist, let card) = decisionChain,
              let decisionChainRepository else { return }
        guard let refreshed = try? await decisionChainRepository
            .fetchDecisionChainChecklist(asOf: checklist.asOf) else { return }
        decisionChain = .ready(refreshed, card)
    }

    /// 換掉清單上同一個 `item_id` 的那一條。找不到就原樣回傳（後端剛長出新的一條時
    /// 不要把它塞進來——那一份要靠重讀）。
    nonisolated static func replacing(
        _ checklist: DecisionChainChecklist,
        with item: DecisionChainChecklistItem
    ) -> DecisionChainChecklist {
        var updated = checklist
        guard let index = updated.items.firstIndex(where: { $0.itemId == item.itemId }) else {
            return checklist
        }
        updated.items[index] = item
        return updated
    }

    /// 主 CTA：先送採納項，再產生目標週課表。
    ///
    /// **順序不能反。** `apply-items` 決定的是下一次生成要吃哪些調整（休息週、跑量
    /// 調整等），生成完才送等於這一份課表沒吃到使用者的選擇。
    ///
    /// 沒有建議項時 `applySelectedAdjustments` 自己會 no-op 回 true
    /// （`WeeklySummaryCoordinator:139`），所以這裡不必分兩條路。
    func applyAndGenerate() async -> Bool {
        guard case .generate(let week) = nextWeekAction else { return false }
        guard !isGeneratingPlan, !isApplying else { return false }

        // 付費閘門與 1.4 `generateWeeklyPlanDirectly` 同一條判準（AC-PAYWALL-26）：
        // 第 2 週起未訂閱不得產生。接成 no-op 就是靜默繞過付費閘門。
        if Self.isBlockedByPaywall(week: week) {
            showsUpsell = true
            return false
        }

        // **decision-chain 路徑不呼 apply-items**（AC-TRAIN-HUB-12）：使用者的選擇
        // 已經逐條落在清單上，後端產生課表時只吃 `accepted`／`adjusted`。再送一次
        // apply-items 等於同一件事有兩份紀錄（鐵則 0），而且送的是這一頁根本沒畫的
        // 那一份建議清單的勾選狀態。
        if !usesDecisionChain {
            isApplying = true
            let applied = await coordinator.applySelectedAdjustments(weekOfPlan: weekOfPlan)
            isApplying = false
            // 採納沒送成功就不要生成 —— 生出來的會是沒吃到使用者選擇的那一份。
            guard applied else { return false }
        }

        isGeneratingPlan = true
        generateError = nil
        defer { isGeneratingPlan = false }

        do {
            _ = try await planRepository.generateWeeklyPlan(
                weekOfTraining: week,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )
        } catch {
            guard !error.isCancellationError else { return false }
            let domainError = error.toDomainError()
            Logger.error("[App2WeeklyReviewVM] 產生第 \(week) 週課表失敗: \(domainError)")
            switch domainError {
            case .subscriptionRequired, .trialExpired, .forbidden:
                showsUpsell = true
            case .rizoQuotaExceeded:
                showsQuotaExceeded = true
            default:
                generateError = L10n.App2.WeeklyReview.generatePlanFailedBody.localized
            }
            return false
        }

        toast = L10n.App2.WeeklyReview.planGenerated.localized
        // 課表換了 —— 首頁今日課表與課表頁吃同一份，用既有失效事件把它們叫醒
        // （同 `App2PlanViewModel.generateCurrentWeekPlan` 的處置，不新開通知路徑）。
        CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))
        await refreshPlanStatus()
        return true
    }

    /// 這個錯誤其實是「還沒產生」嗎？
    ///
    /// 判準是後端的**錯誤形狀**（404 / 產生視窗未開），不是對訊息做字串比對 ——
    /// 訊息會隨後端在地化與改版而變，比對它就是把 UI 綁在一句話上。
    nonisolated static func meansNotGeneratedYet(_ error: DomainError) -> Bool {
        switch error {
        case .notFound:
            return true
        case .badRequest(let body):
            // 產生視窗未開：後端給了穩定的機器可讀 `code`。
            return body.contains("weekly_summary_generation_window_denied")
        default:
            return false
        }
    }

    // MARK: - Gate（與 `TrainingPlanV2ViewModel` 同一組判斷，只讀 singleton）

    private static func isRizoQuotaExhausted() async -> Bool {
        if let usage = SubscriptionStateManager.shared.currentStatus?.rizoUsage, usage.isExhausted {
            return true
        }
        do {
            let repo: SubscriptionRepository = DependencyContainer.shared.resolve()
            let refreshed = try await repo.refreshStatus()
            if let usage = refreshed.rizoUsage, usage.isExhausted { return true }
        } catch {
            Logger.error("[App2WeeklyReviewVM] 訂閱狀態刷新失敗: \(error.localizedDescription)")
        }
        return false
    }

    private static func resolvePaywallTrigger() -> PaywallTrigger {
        guard let status = SubscriptionStateManager.shared.currentStatus else { return .apiGated }
        switch status.status {
        case .trial:     return .trialExpired
        case .cancelled: return .resubscribe
        default:         return .apiGated
        }
    }

    private static func shouldSuppressError(
        _ domainError: DomainError,
        context: String,
        onDataCorruption: (() -> Void)?
    ) -> Bool {
        if case .dataCorruption = domainError {
            onDataCorruption?()
            Logger.error("[App2WeeklyReviewVM] \(context) decode/schema mismatch")
            return true
        }
        if !domainError.shouldShowErrorView {
            Logger.debug("[App2WeeklyReviewVM] \(context) 被取消或訂閱攔截，忽略")
            return true
        }
        return false
    }
}

// MARK: - App2DecisionChainAdjustRange
/// 「調整」輪盤的可選值。
///
/// **這是暫定值，不是規格**（AC-TRAIN-HUB-12「未決」）：後端的清單條目只帶
/// `current`／`proposed`，不帶那顆旋鈕的合法範圍，這條路徑上也不驗值域
/// （`cloud/api_service/domains/decision_chain/checklist.py:62` `check_status_value`
/// 只驗「`adjusted` 有沒有帶值」）。正解是後端把值域放進條目。
///
/// 在那之前用一條**與欄位無關**的規則：從這一條自己的兩個數推。用欄位名列一張
/// 值域表等於在 app 這一層重寫一份旋鈕語意（設計 §4.1「app 不解讀旋鈕」），
/// 而且後端改了值域這裡不會知道。
enum App2DecisionChainAdjustRange {

    /// 輪盤最多幾格。再多就轉不到底了，改放大步進。
    static let maxOptionCount = 121

    /// - Returns: 可選值（遞增）。這一條不是數值型就回空陣列——呼叫端不該開輪盤。
    static func options(for item: DecisionChainChecklistItem) -> [Double] {
        guard let proposed = item.proposed?.numericValue else { return [] }
        // `current` 是 `null` 的條目（`interval_reps` 實測就是）沒有基準點，
        // 拿 0 當基準會推出「趟數 -14」這種選項，所以退回用 `proposed` 自己。
        let anchor = item.current?.numericValue ?? proposed
        let reach = max(1, abs(proposed - anchor), (abs(proposed) / 2).rounded())
        let low = min(anchor, proposed) - reach
        let high = max(anchor, proposed) + reach
        let step = max(1, ((high - low) / Double(maxOptionCount - 1)).rounded(.up))
        return stride(from: low, through: high, by: step).map { $0 }
    }

    /// 輪盤開起來時停在哪：已經調整過就停在調整後的值，否則停在後端提的值。
    static func initialValue(for item: DecisionChainChecklistItem) -> Double {
        item.adjustedValue?.numericValue ?? item.proposed?.numericValue ?? 0
    }

    /// 輪盤上一格怎麼寫。整數條目不寫小數點。
    static func label(for item: DecisionChainChecklistItem, value: Double) -> String {
        if case .int = item.proposed {
            return String(format: "%.0f", value)
        }
        return value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
