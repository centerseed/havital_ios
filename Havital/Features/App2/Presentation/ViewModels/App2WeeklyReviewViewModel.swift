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

    // MARK: - Dependencies

    private var coordinator: WeeklySummaryCoordinator!
    /// 這一頁看的是哪一週。由呼叫端（首頁 CTA）決定：平日是上週，週日是本週。
    private let weekOfPlan: Int

    init(weekOfPlan: Int, repository: TrainingPlanV2Repository? = nil) {
        self.weekOfPlan = weekOfPlan

        let container = DependencyContainer.shared
        if repository == nil, !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        let resolved: TrainingPlanV2Repository = repository ?? container.resolve()

        self.coordinator = WeeklySummaryCoordinator(
            repository: resolved,
            currentSelectedWeek: { [weak self] in self?.weekOfPlan ?? 1 },
            // 2.0 沒有那個全螢幕的載入動畫，載入態是這一頁自己的 `isLoading`。
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
        isLoading = false
    }

    /// 產生這一週的回顧（首頁 CTA 是「產生上週／本週回顧」時走這條）。
    func generate() async {
        isLoading = true
        errorMessage = nil
        needsGeneration = false
        await coordinator.generateWeeklySummary()
        applyState(afterGenerate: true)
        isLoading = false
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
