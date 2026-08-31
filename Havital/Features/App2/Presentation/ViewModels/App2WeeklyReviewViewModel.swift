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

    // MARK: - Dependencies

    private var coordinator: WeeklySummaryCoordinator!
    /// 這一頁看的是哪一週。由呼叫端（首頁 CTA）決定：平日是上週，週日是本週。
    private let weekOfPlan: Int
    /// 歷史週唯讀回看（走查裁決（q））。產生課表是寫入路徑，唯讀時一律不給出口。
    private let isReadOnly: Bool
    /// 「產生目標週課表」走的是既有出口 `POST /v2/plan/weekly`，與課表頁同一支
    /// repository —— 不另開資料路徑。
    private let planRepository: TrainingPlanV2Repository

    init(
        weekOfPlan: Int,
        isReadOnly: Bool = false,
        repository: TrainingPlanV2Repository? = nil
    ) {
        self.weekOfPlan = weekOfPlan
        self.isReadOnly = isReadOnly

        let container = DependencyContainer.shared
        if repository == nil, !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        let resolved: TrainingPlanV2Repository = repository ?? container.resolve()
        self.planRepository = resolved

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

    func load() async {
        isLoading = true
        errorMessage = nil
        await coordinator.loadWeeklySummary(weekOfPlan: weekOfPlan)
        applyState(afterGenerate: false)
        await refreshPlanStatus()
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
        if week >= 2,
           SubscriptionStateManager.shared.isEnforcementEnabled,
           !SubscriptionStateManager.shared.hasPremiumAccess {
            showsUpsell = true
            return false
        }

        isApplying = true
        let applied = await coordinator.applySelectedAdjustments(weekOfPlan: weekOfPlan)
        isApplying = false
        // 採納沒送成功就不要生成 —— 生出來的會是沒吃到使用者選擇的那一份。
        guard applied else { return false }

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
