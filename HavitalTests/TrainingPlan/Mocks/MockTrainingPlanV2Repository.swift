import Foundation
import Combine
@testable import paceriz_dev

/// Mock implementation of TrainingPlanV2Repository for testing
final class MockTrainingPlanV2Repository: TrainingPlanV2Repository {

    // MARK: - AC-PAYWALL-37: overview publisher (no-op for unit tests)

    var overviewDidUpdate: AnyPublisher<PlanOverviewV2, Never> {
        Empty().eraseToAnyPublisher()
    }

    // MARK: - Call Tracking

    var getPlanStatusCallCount = 0
    var getTargetTypesCallCount = 0
    var getMethodologiesCallCount = 0
    var createOverviewForRaceCallCount = 0
    var createOverviewForNonRaceCallCount = 0
    var getOverviewCallCount = 0
    var refreshOverviewCallCount = 0
    var updateOverviewCallCount = 0
    var generateWeeklyPlanCallCount = 0
    var getWeeklyPlanCallCount = 0
    var fetchWeeklyPlanCallCount = 0
    var updateWeeklyPlanCallCount = 0
    var refreshWeeklyPlanCallCount = 0
    var deleteWeeklyPlanCallCount = 0
    var generateWeeklySummaryCallCount = 0
    var getWeeklySummaryCallCount = 0
    var refreshWeeklySummaryCallCount = 0
    var deleteWeeklySummaryCallCount = 0
    var applyAdjustmentItemsCallCount = 0
    var lastAppliedIndices: [Int] = []
    var lastApplyAdjustmentItemsWeekOfPlan: Int?
    var getWeeklyPreviewCallCount = 0
    var refreshWeeklyPreviewCallCount = 0
    var clearCacheCallCount = 0
    var clearOverviewCacheCallCount = 0
    var lastRequestedWeeklyPlanWeekOfTraining: Int?
    var lastRefreshedWeeklyPlanWeekOfTraining: Int?
    var lastCreateOverviewForRaceTargetId: String?
    var lastCreateOverviewForRaceStartFromStage: String?
    var lastCreateOverviewForRaceMethodologyId: String?
    var lastUpdatedOverviewId: String?
    var lastUpdatedOverviewStartFromStage: String?
    var lastUpdatedOverviewMethodologyId: String?
    var lastUpdateWeeklyPlanRequest: UpdateWeeklyPlanRequest?

    // MARK: - Return Values

    var weeklyPreviewToReturn: WeeklyPreviewV2?
    var planStatusToReturn: PlanStatusV2Response?
    var targetTypesToReturn: [TargetTypeV2] = []
    var methodologiesToReturn: [MethodologyV2] = []
    var overviewToReturn: PlanOverviewV2?
    var refreshOverviewResults: [PlanOverviewV2] = []
    var weeklyPlanV2ToReturn: WeeklyPlanV2?
    var weeklySummaryV2ToReturn: WeeklySummaryV2?
    var errorToThrow: Error?
    /// 只讓 getWeeklySummary 丟錯（T-0362：回顧 404、但 plan status 正常回來——
    /// 那正是「週一打開本週回顧」的真實組合。全域的 `errorToThrow` 會連
    /// `getPlanStatus` 一起丟，判準就永遠落在 status 為 nil 的 fail-open 分支上）。
    var weeklySummaryErrorToThrow: Error?
    /// 只讓 fetchWeeklyPlan 丟錯（部分取消情境：plan status 成功、週課表被收掉）。
    var fetchWeeklyPlanErrorToThrow: Error?
    /// 只讓 refreshOverview 丟錯（部分取消情境：plan status 成功、overview 被收掉）。
    var refreshOverviewErrorToThrow: Error?
    var generateWeeklyPlanErrors: [Error] = []
    var applyAdjustmentItemsError: Error?

    /// 在對應方法回傳**之前**執行——讓測試可以觀察「請求還在飛」的那一刻的 UI 狀態
    /// （例：生成中要顯示動畫，T-0341）。沒有它就只驗得到請求結束後的終態。
    var onGenerateWeeklySummary: (() async -> Void)?
    var onGetWeeklySummary: (() async -> Void)?
    /// 同上，給 `getWeeklyPlan`——課表頁切週要驗「抓取還在飛的時候畫面已經換週了」（T-0374）。
    var onGetWeeklyPlan: (() async -> Void)?

    /// 本機週課表快取（T-0374：切週的預畫走的就是它）。
    /// nil ＝ 沿用既有行為（任何一週都回 `weeklyPlanV2ToReturn`），既有測試不受影響。
    var cachedWeeklyPlansByWeek: [Int: WeeklyPlanV2]?

    // MARK: - 整期預抓（T-0378）

    /// `getWeeklyPlan` 每一週各自回哪一份（預抓要驗「第 N 週落的是第 N 週的課表」）。
    /// nil ＝ 沿用既有行為（都回 `weeklyPlanV2ToReturn`）。表裡沒有的週丟 `weeklyPlanNotFound`
    /// ——那正是後端 404（那一週從沒生成過課表）。
    var weeklyPlansByWeekToReturn: [Int: WeeklyPlanV2]?

    /// 抓回來就寫進 `cachedWeeklyPlansByWeek`（真 repository 的 write-through 行為，
    /// `TrainingPlanV2RepositoryImpl.fetchAndCacheWeeklyPlan`）。
    /// 預設 false —— 既有測試自己擺快取，不受影響。
    var simulatesWriteThroughCache = false

    /// 這一週後端沒有課表（404）。
    var weeklyPlanNotFoundWeeks: Set<Int> = []

    /// 預抓實際問了哪幾週（順序保留，可看併發交錯）。
    var requestedWeeklyPlanWeeks: [Int] = []

    // MARK: - Reset

    func reset() {
        getPlanStatusCallCount = 0
        getTargetTypesCallCount = 0
        getMethodologiesCallCount = 0
        createOverviewForRaceCallCount = 0
        createOverviewForNonRaceCallCount = 0
        getOverviewCallCount = 0
        refreshOverviewCallCount = 0
        updateOverviewCallCount = 0
        generateWeeklyPlanCallCount = 0
        getWeeklyPlanCallCount = 0
        fetchWeeklyPlanCallCount = 0
        updateWeeklyPlanCallCount = 0
        refreshWeeklyPlanCallCount = 0
        deleteWeeklyPlanCallCount = 0
        generateWeeklySummaryCallCount = 0
        onGenerateWeeklySummary = nil
        onGetWeeklySummary = nil
        getWeeklySummaryCallCount = 0
        refreshWeeklySummaryCallCount = 0
        deleteWeeklySummaryCallCount = 0
        applyAdjustmentItemsCallCount = 0
        lastAppliedIndices = []
        lastApplyAdjustmentItemsWeekOfPlan = nil
        getWeeklyPreviewCallCount = 0
        refreshWeeklyPreviewCallCount = 0
        clearCacheCallCount = 0
        clearOverviewCacheCallCount = 0
        lastRequestedWeeklyPlanWeekOfTraining = nil
        lastRefreshedWeeklyPlanWeekOfTraining = nil
        lastCreateOverviewForRaceTargetId = nil
        lastCreateOverviewForRaceStartFromStage = nil
        lastCreateOverviewForRaceMethodologyId = nil
        lastUpdatedOverviewId = nil
        lastUpdatedOverviewStartFromStage = nil
        lastUpdatedOverviewMethodologyId = nil
        lastUpdateWeeklyPlanRequest = nil
        errorToThrow = nil
        weeklySummaryErrorToThrow = nil
        refreshOverviewErrorToThrow = nil
        refreshOverviewResults = []
        generateWeeklyPlanErrors = []
        applyAdjustmentItemsError = nil
    }

    // MARK: - Protocol Methods

    func getPlanStatus(forceRefresh: Bool) async throws -> PlanStatusV2Response {
        getPlanStatusCallCount += 1
        // 卡住「網路」那一步，讓測試能斷言在它回來之前畫面上就已經有東西（T-0365）。
        if let gate = networkReadGate { await gate() }
        if let error = errorToThrow { throw error }
        guard let status = planStatusToReturn else {
            throw TrainingPlanV2Error.unknown("No mock plan status set")
        }
        return status
    }

    func getTargetTypes() async throws -> [TargetTypeV2] {
        getTargetTypesCallCount += 1
        if let error = errorToThrow { throw error }
        return targetTypesToReturn
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        getMethodologiesCallCount += 1
        if let error = errorToThrow { throw error }
        return methodologiesToReturn
    }

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        createOverviewForRaceCallCount += 1
        lastCreateOverviewForRaceTargetId = targetId
        lastCreateOverviewForRaceStartFromStage = startFromStage
        lastCreateOverviewForRaceMethodologyId = methodologyId
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewCreationFailed("No mock overview set")
        }
        return overview
    }

    func createOverviewForNonRace(targetType: String, trainingWeeks: Int, availableDays: Int?, methodologyId: String?, startFromStage: String?, intendedRaceDistanceKm: Int?) async throws -> PlanOverviewV2 {
        createOverviewForNonRaceCallCount += 1
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewCreationFailed("No mock overview set")
        }
        return overview
    }

    func getOverview() async throws -> PlanOverviewV2 {
        getOverviewCallCount += 1
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewNotFound
        }
        return overview
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        refreshOverviewCallCount += 1
        if let error = refreshOverviewErrorToThrow { throw error }
        if let error = errorToThrow { throw error }
        if !refreshOverviewResults.isEmpty {
            return refreshOverviewResults.removeFirst()
        }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewNotFound
        }
        return overview
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        updateOverviewCallCount += 1
        lastUpdatedOverviewId = overviewId
        lastUpdatedOverviewStartFromStage = startFromStage
        lastUpdatedOverviewMethodologyId = methodologyId
        if let error = errorToThrow { throw error }
        guard let overview = overviewToReturn else {
            throw TrainingPlanV2Error.overviewNotFound
        }
        return overview
    }

    func generateWeeklyPlan(weekOfTraining: Int, forceGenerate: Bool?, promptVersion: String?, methodology: String?) async throws -> WeeklyPlanV2 {
        generateWeeklyPlanCallCount += 1
        if !generateWeeklyPlanErrors.isEmpty {
            throw generateWeeklyPlanErrors.removeFirst()
        }
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanGenerationFailed(week: weekOfTraining, reason: "No mock plan set")
        }
        return plan
    }

    // @MainActor：整期預抓開三條 lane 併發呼叫這一支；mock 是普通 class，
    // 非隔離時三條 lane 同時 append/merge 會掉更新，預抓測試隨機缺週
    //（actor hop 由 async witness 合法承接，正式 repository 不受影響）。
    @MainActor
    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        getWeeklyPlanCallCount += 1
        lastRequestedWeeklyPlanWeekOfTraining = weekOfTraining
        requestedWeeklyPlanWeeks.append(weekOfTraining)
        if let onGetWeeklyPlan { await onGetWeeklyPlan() }
        if let error = errorToThrow { throw error }
        if weeklyPlanNotFoundWeeks.contains(weekOfTraining) {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: weekOfTraining)
        }
        let resolved: WeeklyPlanV2?
        if let weeklyPlansByWeekToReturn {
            resolved = weeklyPlansByWeekToReturn[weekOfTraining]
        } else {
            resolved = weeklyPlanV2ToReturn
        }
        guard let plan = resolved else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: weekOfTraining)
        }
        if simulatesWriteThroughCache {
            cachedWeeklyPlansByWeek = (cachedWeeklyPlansByWeek ?? [:]).merging([weekOfTraining: plan]) { _, new in new }
        }
        return plan
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        fetchWeeklyPlanCallCount += 1
        if let error = fetchWeeklyPlanErrorToThrow { throw error }
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: 0)
        }
        return plan
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        updateWeeklyPlanCallCount += 1
        lastUpdateWeeklyPlanRequest = updates
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: 0)
        }
        return plan
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        refreshWeeklyPlanCallCount += 1
        lastRefreshedWeeklyPlanWeekOfTraining = weekOfTraining
        if let error = errorToThrow { throw error }
        guard let plan = weeklyPlanV2ToReturn else {
            throw TrainingPlanV2Error.weeklyPlanNotFound(week: weekOfTraining)
        }
        return plan
    }

    func deleteWeeklyPlan(planId: String) async throws {
        deleteWeeklyPlanCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func getWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        getWeeklyPreviewCallCount += 1
        if let error = errorToThrow { throw error }
        guard let preview = weeklyPreviewToReturn else {
            throw TrainingPlanV2Error.unknown("No mock weekly preview set")
        }
        return preview
    }

    func refreshWeeklyPreview(overviewId: String) async throws -> WeeklyPreviewV2 {
        refreshWeeklyPreviewCallCount += 1
        if let error = errorToThrow { throw error }
        guard let preview = weeklyPreviewToReturn else {
            throw TrainingPlanV2Error.unknown("No mock weekly preview set")
        }
        return preview
    }

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        generateWeeklySummaryCallCount += 1
        await onGenerateWeeklySummary?()
        if let error = errorToThrow { throw error }
        guard let summary = weeklySummaryV2ToReturn else {
            throw TrainingPlanV2Error.weeklySummaryGenerationFailed(week: weekOfPlan, reason: "No mock summary set")
        }
        return summary
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        if let error = errorToThrow { throw error }
        return []
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        getWeeklySummaryCallCount += 1
        await onGetWeeklySummary?()
        if let error = weeklySummaryErrorToThrow ?? errorToThrow { throw error }
        guard let summary = weeklySummaryV2ToReturn else {
            // **正式 repository 在這一格是 404 → POST fallback**
            // （`TrainingPlanV2RepositoryImpl.fetchOrGenerateWeeklySummary`）。
            // mock 照抄那個形狀，否則「載入會不會偷偷生成」在測試裡永遠看不到。
            generateWeeklySummaryCallCount += 1
            await onGenerateWeeklySummary?()
            // 丟 `DomainError` 而不是 `TrainingPlanV2Error`：通用的
            // `Error.toDomainError()` 不認得後者，會折成 `.unknown`，
            // 於是「還沒產生」在 VM 那邊會被誤讀成錯誤（假紅）。
            throw DomainError.notFound("Weekly summary not found for week \(weekOfPlan)")
        }
        return summary
    }

    /// 唯讀版本（T-0362）：沒有就是 nil，**不碰生成計數**。
    func fetchWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2? {
        getWeeklySummaryCallCount += 1
        await onGetWeeklySummary?()
        if let error = weeklySummaryErrorToThrow ?? errorToThrow {
            if case .notFound = error.toDomainError() { return nil }
            throw error
        }
        return weeklySummaryV2ToReturn
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        refreshWeeklySummaryCallCount += 1
        if let error = errorToThrow { throw error }
        guard let summary = weeklySummaryV2ToReturn else {
            throw TrainingPlanV2Error.weeklySummaryNotFound(week: weekOfPlan)
        }
        return summary
    }

    func applyAdjustmentItems(weekOfPlan: Int, appliedIndices: [Int]) async throws {
        applyAdjustmentItemsCallCount += 1
        lastApplyAdjustmentItemsWeekOfPlan = weekOfPlan
        lastAppliedIndices = appliedIndices
        if let error = applyAdjustmentItemsError { throw error }
    }

    func deleteWeeklySummary(summaryId: String) async throws {
        deleteWeeklySummaryCallCount += 1
        if let error = errorToThrow { throw error }
    }

    /// When non-nil, getCachedPlanStatus() returns this instead of planStatusToReturn.
    /// Lets a test simulate a stale local cache that differs from the fresh API response.
    var cachedPlanStatusToReturn: PlanStatusV2Response?

    /// 這台裝置的本機快取是空的（冷啟第一次、或剛登入）。兩支 cache-only 出口回 nil。
    var simulatesEmptyLocalCache = false

    /// 讓測試把「網路」讀卡住（見 `getPlanStatus`）。
    var networkReadGate: (() async -> Void)?

    func getCachedPlanStatus() -> PlanStatusV2Response? {
        if simulatesEmptyLocalCache { return nil }
        return cachedPlanStatusToReturn ?? planStatusToReturn
    }

    func getCachedOverview() -> PlanOverviewV2? {
        if simulatesEmptyLocalCache { return nil }
        return overviewToReturn
    }

    func getCachedWeeklyPlan(week: Int) -> WeeklyPlanV2? {
        if let cachedWeeklyPlansByWeek { return cachedWeeklyPlansByWeek[week] }
        return weeklyPlanV2ToReturn
    }

    func clearCache() async {
        clearCacheCallCount += 1
    }

    func clearOverviewCache() async {
        clearOverviewCacheCallCount += 1
    }
    func clearWeeklyPlanCache(weekOfTraining: Int?) async {}
    func clearWeeklySummaryCache(weekOfPlan: Int?) async {}
    func preloadData() async {}
}
