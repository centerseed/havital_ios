import Foundation
import SwiftUI

// MARK: - WeeklySummary ViewModel
/// 負責週回顧的生成、顯示和調整確認流程
/// 職責：週回顧 CRUD、調整項目管理
@MainActor
final class WeeklySummaryViewModel: ObservableObject, @preconcurrency TaskManageable {

    // MARK: - Published State

    /// 週回顧狀態
    @Published var summaryState: ViewState<WeeklyTrainingSummary> = .empty

    /// 週回顧列表狀態（歷史記錄）
    @Published var summariesState: ViewState<[WeeklySummaryItem]> = .empty

    /// 是否正在生成週回顧
    @Published var isGenerating: Bool = false

    /// 是否顯示週回顧 sheet
    @Published var showSummarySheet: Bool = false

    /// 是否顯示調整確認 sheet
    @Published var showAdjustmentConfirmation: Bool = false

    /// 待確認的調整項目
    @Published var pendingAdjustments: [AdjustmentItem] = []

    /// 待確認的 summary ID
    @Published var pendingSummaryId: String?

    /// 待確認的目標週數
    @Published var pendingTargetWeek: Int?

    /// 週回顧錯誤
    @Published var summaryError: Error?

    /// 付費牆觸發（nil 表示未觸發）
    @Published var paywallTrigger: PaywallTrigger?

    // MARK: - Dependencies

    private let repository: TrainingPlanRepository

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Computed Properties

    /// 當前週回顧（如有）
    var currentSummary: WeeklyTrainingSummary? {
        return summaryState.data
    }

    /// 是否正在載入
    var isLoading: Bool {
        return summaryState.isLoading || summariesState.isLoading
    }

    // MARK: - Initialization

    init(repository: TrainingPlanRepository) {
        self.repository = repository
        setupEventSubscriptions()
    }

    /// 便利初始化器（使用 DI Container）
    convenience init() {
        if !DependencyContainer.shared.isRegistered(TrainingPlanRepository.self) {
            DependencyContainer.shared.registerTrainingPlanModule()
        }
        self.init(repository: DependencyContainer.shared.resolve())
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Event Subscriptions

    /// 設定事件訂閱
    private func setupEventSubscriptions() {
        // ✅ Clean Architecture: 訂閱用戶登出事件
        CacheEventBus.shared.subscribe(for: "userLogout") { [weak self] in
            guard let self = self else { return }

            Logger.debug("[WeeklySummaryVM] 收到 userLogout 事件，清除緩存")

            // 清除 Repository 緩存
            await self.repository.clearCache()

            // 重置狀態
            await MainActor.run {
                self.summaryState = .empty
                self.summariesState = .empty
                self.isGenerating = false
                self.showSummarySheet = false
                self.showAdjustmentConfirmation = false
                self.pendingAdjustments = []
                self.pendingSummaryId = nil
                self.pendingTargetWeek = nil
                self.summaryError = nil
            }

            Logger.debug("[WeeklySummaryVM] ✅ 用戶登出後狀態已重置")
        }
    }

    // MARK: - Public Methods - Summary CRUD

    /// 載入已存在的週回顧（用於查看歷史週回顧）
    func loadWeeklySummary(weekNumber: Int) async {
        Logger.debug("[WeeklySummaryVM] 📤 開始載入週回顧 - weekNumber: \(weekNumber)")

        summaryState = .loading
        summaryError = nil

        do {
            // 調用 Repository 獲取已存在的週回顧
            Logger.debug("[WeeklySummaryVM] 🔄 調用 repository.getWeeklySummary...")
            let summary = try await repository.getWeeklySummary(weekNumber: weekNumber)

            Logger.debug("[WeeklySummaryVM] 📥 收到週回顧 - id: \(summary.id)")
            summaryState = .loaded(summary)

            // ✅ 顯示週回顧 sheet
            showSummarySheet = true
            Logger.debug("[WeeklySummaryVM] ✅ 設置 showSummarySheet = true")

            Logger.debug("[WeeklySummaryVM] ✅ 載入完成 - week \(weekNumber)")
        } catch {
            let domainError = error.toDomainError()

            // 取消錯誤不更新 UI
            if case .cancellation = domainError {
                Logger.debug("[WeeklySummaryVM] ⚠️ Task cancelled")
                return
            }

            summaryState = .error(domainError)
            summaryError = error
            Logger.error("[WeeklySummaryVM] ❌ 載入失敗: \(error.localizedDescription)")
        }
    }

    /// 創建週回顧（可選指定週數）
    func createWeeklySummary(weekNumber: Int? = nil) async {
        Logger.debug("[WeeklySummaryVM] Creating summary for week \(weekNumber ?? -1)")

        summaryState = .loading
        summaryError = nil
        isGenerating = true

        do {
            // 調用 Repository 創建週回顧
            let summary = try await repository.createWeeklySummary(weekNumber: weekNumber, forceUpdate: false)

            summaryState = .loaded(summary)

            // ✅ 修復：一律先顯示週回顧，讓用戶看到本週的訓練分析
            showSummarySheet = true

            // 檢查並保存調整項目（如果有的話）
            if let adjustments = summary.nextWeekAdjustments.items, !adjustments.isEmpty {
                pendingAdjustments = adjustments
                pendingSummaryId = summary.id
                pendingTargetWeek = weekNumber.map { $0 + 1 } // 下一週
                Logger.debug("[WeeklySummaryVM] \(adjustments.count) adjustments pending, will show after user views summary")
            } else {
                Logger.debug("[WeeklySummaryVM] No adjustments, showing summary only")
            }

            isGenerating = false
        } catch {
            let domainError = error.toDomainError()
            switch domainError {
            case .cancellation:
                Logger.debug("[WeeklySummaryVM] Task cancelled")
                isGenerating = false
                return
            case .subscriptionRequired:
                self.paywallTrigger = .apiGated
                isGenerating = false
                return
            default:
                break
            }

            summaryState = .error(domainError)
            summaryError = error
            isGenerating = false
            Logger.error("[WeeklySummaryVM] Failed to create summary: \(error.localizedDescription)")
        }
    }

    /// 重試創建週回顧（強制更新模式）
    func retryCreateWeeklySummary() async {
        Logger.debug("[WeeklySummaryVM] Retrying summary creation (force update)")

        summaryState = .loading
        summaryError = nil
        isGenerating = true

        do {
            let summary = try await repository.createWeeklySummary(weekNumber: nil, forceUpdate: true)
            summaryState = .loaded(summary)

            if let adjustments = summary.nextWeekAdjustments.items, !adjustments.isEmpty {
                pendingAdjustments = adjustments
                pendingSummaryId = summary.id
                showAdjustmentConfirmation = true
            } else {
                showSummarySheet = true
            }

            isGenerating = false
        } catch {
            let domainError = error.toDomainError()
            switch domainError {
            case .cancellation:
                isGenerating = false
                return
            case .subscriptionRequired:
                self.paywallTrigger = .apiGated
                isGenerating = false
                return
            default:
                break
            }

            summaryState = .error(domainError)
            summaryError = error
            isGenerating = false
        }
    }

    /// 載入所有週回顧（歷史記錄）
    func loadWeeklySummaries() async {
        summariesState = .loading

        do {
            let summaries = try await repository.getWeeklySummaries()
            summariesState = summaries.isEmpty ? .empty : .loaded(summaries)
            Logger.debug("[WeeklySummaryVM] Loaded \(summaries.count) summaries")
        } catch {
            let domainError = error.toDomainError()
            if case .cancellation = domainError { return }
            summariesState = .error(domainError)
        }
    }

    /// 清除當前週回顧
    func clearSummary() {
        summaryState = .empty
        summaryError = nil
        showSummarySheet = false
        Logger.debug("[WeeklySummaryVM] Summary cleared")
    }

    // MARK: - Adjustment Confirmation

    /// 確認調整並產生下週課表
    func confirmAdjustments(_ selectedItems: [AdjustmentItem]) async {
        guard let summaryId = pendingSummaryId,
              let targetWeek = pendingTargetWeek else {
            Logger.error("[WeeklySummaryVM] Missing summary ID or target week")
            return
        }

        Logger.debug("[WeeklySummaryVM] Confirming \(selectedItems.count) adjustments for week \(targetWeek)")

        do {
            // 更新調整項目
            let updatedItems = try await repository.updateAdjustments(
                summaryId: summaryId,
                items: selectedItems
            )

            Logger.debug("[WeeklySummaryVM] Adjustments updated: \(updatedItems.count)")

            // 關閉調整確認 sheet
            showAdjustmentConfirmation = false

            // 顯示週回顧
            showSummarySheet = true

            // 清除待確認狀態
            clearPendingAdjustments()

        } catch {
            Logger.error("[WeeklySummaryVM] Failed to confirm adjustments: \(error.localizedDescription)")
            summaryError = error
        }
    }

    /// 取消調整確認
    func cancelAdjustmentConfirmation() {
        Logger.debug("[WeeklySummaryVM] Adjustment confirmation cancelled")
        showAdjustmentConfirmation = false
        clearPendingAdjustments()
    }

    /// 清除待確認的調整
    private func clearPendingAdjustments() {
        pendingAdjustments = []
        pendingSummaryId = nil
        pendingTargetWeek = nil
    }

    // MARK: - Helper Methods

    /// 獲取上週日期範圍字串
    func getLastWeekRangeString() -> String {
        let calendar = Calendar.current
        let today = Date()

        // 計算上週一
        guard let lastMonday = calendar.date(byAdding: .weekOfYear, value: -1, to: today),
              let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday) else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        return " (\(formatter.string(from: lastMonday)) - \(formatter.string(from: lastSunday)))"
    }

    /// 獲取最近兩週日期範圍字串
    func getLastTwoWeeksRange() -> String {
        let calendar = Calendar.current
        let today = Date()

        // 計算兩週前的週一
        guard let twoWeeksAgoMonday = calendar.date(byAdding: .weekOfYear, value: -2, to: today),
              let lastSunday = calendar.date(byAdding: .weekOfYear, value: -1, to: today),
              let actualLastSunday = calendar.date(byAdding: .day, value: 6, to: lastSunday) else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        return "(\(formatter.string(from: twoWeeksAgoMonday)) - \(formatter.string(from: actualLastSunday)))"
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 WeeklySummaryViewModel 工廠
    @MainActor
    static func makeWeeklySummaryViewModel() -> WeeklySummaryViewModel {
        return WeeklySummaryViewModel()
    }
}
