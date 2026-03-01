//
//  WeeklySummaryViewModelTests.swift
//  HavitalTests
//
//  Unit tests for WeeklySummaryViewModel
//

import XCTest
@testable import paceriz_dev

@MainActor
final class WeeklySummaryViewModelTests: XCTestCase {

    var viewModel: WeeklySummaryViewModel!
    var mockRepository: MockTrainingPlanRepository!

    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockTrainingPlanRepository()
        viewModel = WeeklySummaryViewModel(repository: mockRepository)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        try await super.tearDown()
    }

    // MARK: - createWeeklySummary Tests

    func testCreateWeeklySummary_Success() async throws {
        // Given
        let mockSummary = try TrainingPlanTestFixtures.createWeeklySummary(id: "summary_1")
        mockRepository.weeklySummaryToReturn = mockSummary

        // When
        await viewModel.createWeeklySummary(weekNumber: 3)

        // Then
        XCTAssertEqual(mockRepository.createWeeklySummaryCallCount, 1)
        XCTAssertEqual(mockRepository.createWeeklySummaryLastParams?.weekNumber, 3)
        XCTAssertEqual(mockRepository.createWeeklySummaryLastParams?.forceUpdate, false)

        // 驗證狀態
        XCTAssertEqual(viewModel.summaryState.data?.id, "summary_1")
        XCTAssertFalse(viewModel.isGenerating)
    }

    func testCreateWeeklySummary_WithAdjustments_ShowsSummaryFirst() async throws {
        // Given
        let adjustmentItems = [
            AdjustmentItem(content: "Reduce interval training", apply: true),
            AdjustmentItem(content: "Increase long run", apply: false)
        ]
        let adjustments = NextWeekAdjustments(
            status: "needs_adjustment",
            modifications: nil,
            adjustmentReason: "Fatigue detected",
            items: adjustmentItems
        )
        let mockSummary = try TrainingPlanTestFixtures.createWeeklySummary(
            id: "summary_2",
            adjustments: adjustments
        )
        mockRepository.weeklySummaryToReturn = mockSummary

        // When
        await viewModel.createWeeklySummary(weekNumber: 4)

        // Then: 新流程 - 先顯示週回顧，調整項目保存待用戶關閉後再顯示
        XCTAssertTrue(viewModel.showSummarySheet) // 先顯示週回顧
        XCTAssertEqual(viewModel.pendingAdjustments.count, 2) // 調整項目已保存
        XCTAssertEqual(viewModel.pendingSummaryId, "summary_2")
        // 注意：showAdjustmentConfirmation 會在用戶關閉週回顧後才設置為 true
    }

    func testCreateWeeklySummary_NoAdjustments_ShowsSummarySheet() async throws {
        // Given
        let mockSummary = try TrainingPlanTestFixtures.createWeeklySummary(id: "summary_3")
        mockRepository.weeklySummaryToReturn = mockSummary

        // When
        await viewModel.createWeeklySummary()

        // Then
        XCTAssertTrue(viewModel.showSummarySheet)
        XCTAssertFalse(viewModel.showAdjustmentConfirmation)
        XCTAssertTrue(viewModel.pendingAdjustments.isEmpty)
    }

    func testCreateWeeklySummary_Error() async throws {
        // Given
        let testError = TrainingPlanError.noPlan
        mockRepository.errorToThrow = testError

        // When
        await viewModel.createWeeklySummary()

        // Then
        XCTAssertEqual(mockRepository.createWeeklySummaryCallCount, 1)
        XCTAssertNotNil(viewModel.summaryError)
        XCTAssertTrue(viewModel.summaryState.hasError)
        XCTAssertFalse(viewModel.isGenerating)
    }

    // MARK: - retryCreateWeeklySummary Tests

    func testRetryCreateWeeklySummary_UsesForceUpdate() async throws {
        // Given
        let mockSummary = try TrainingPlanTestFixtures.createWeeklySummary(id: "summary_retry")
        mockRepository.weeklySummaryToReturn = mockSummary

        // When
        await viewModel.retryCreateWeeklySummary()

        // Then
        XCTAssertEqual(mockRepository.createWeeklySummaryCallCount, 1)
        XCTAssertEqual(mockRepository.createWeeklySummaryLastParams?.forceUpdate, true)
        XCTAssertNil(viewModel.summaryError)
    }

    // MARK: - loadWeeklySummaries Tests

    func testLoadWeeklySummaries_Success() async throws {
        // Given
        let mockSummaries = [
            WeeklySummaryItem(weekIndex: 1, weekStart: "2025/01/01", weekStartTimestamp: nil, distanceKm: 30.0, weekPlan: "Base building", weekSummary: "Good week", completionPercentage: 90.0),
            WeeklySummaryItem(weekIndex: 2, weekStart: "2025/01/08", weekStartTimestamp: nil, distanceKm: 35.0, weekPlan: "Interval training", weekSummary: "Tough week", completionPercentage: 85.0)
        ]
        mockRepository.weeklySummariesListToReturn = mockSummaries

        // When
        await viewModel.loadWeeklySummaries()

        // Then
        XCTAssertEqual(mockRepository.getWeeklySummariesCallCount, 1)
        XCTAssertEqual(viewModel.summariesState.data?.count, 2)
    }

    func testLoadWeeklySummaries_Empty() async throws {
        // Given
        mockRepository.weeklySummariesListToReturn = []

        // When
        await viewModel.loadWeeklySummaries()

        // Then
        XCTAssertTrue(viewModel.summariesState.isEmpty)
    }

    // MARK: - confirmAdjustments Tests

    func testConfirmAdjustments_Success() async throws {
        // Given
        let adjustmentItems = [
            AdjustmentItem(content: "Test adjustment", apply: true)
        ]
        viewModel.pendingSummaryId = "summary_123"
        viewModel.pendingTargetWeek = 5

        mockRepository.adjustmentItemsToReturn = adjustmentItems

        // When
        await viewModel.confirmAdjustments(adjustmentItems)

        // Then
        XCTAssertEqual(mockRepository.updateAdjustmentsCallCount, 1)
        XCTAssertEqual(mockRepository.updateAdjustmentsLastParams?.summaryId, "summary_123")
        XCTAssertEqual(mockRepository.updateAdjustmentsLastParams?.items.count, 1)

        // 驗證清理狀態
        XCTAssertFalse(viewModel.showAdjustmentConfirmation)
        XCTAssertTrue(viewModel.showSummarySheet)
        XCTAssertTrue(viewModel.pendingAdjustments.isEmpty)
        XCTAssertNil(viewModel.pendingSummaryId)
    }

    func testConfirmAdjustments_MissingData() async throws {
        // Given
        viewModel.pendingSummaryId = nil
        viewModel.pendingTargetWeek = nil

        // When
        await viewModel.confirmAdjustments([])

        // Then
        XCTAssertEqual(mockRepository.updateAdjustmentsCallCount, 0) // 不應調用 API
    }

    // MARK: - cancelAdjustmentConfirmation Tests

    func testCancelAdjustmentConfirmation() {
        // Given
        viewModel.showAdjustmentConfirmation = true
        viewModel.pendingAdjustments = [AdjustmentItem(content: "Test", apply: true)]
        viewModel.pendingSummaryId = "summary_123"
        viewModel.pendingTargetWeek = 5

        // When
        viewModel.cancelAdjustmentConfirmation()

        // Then
        XCTAssertFalse(viewModel.showAdjustmentConfirmation)
        XCTAssertTrue(viewModel.pendingAdjustments.isEmpty)
        XCTAssertNil(viewModel.pendingSummaryId)
        XCTAssertNil(viewModel.pendingTargetWeek)
    }

    // MARK: - clearSummary Tests

    func testClearSummary() async throws {
        // Given
        let mockSummary = try TrainingPlanTestFixtures.createWeeklySummary(id: "summary_clear")
        mockRepository.weeklySummaryToReturn = mockSummary
        await viewModel.createWeeklySummary()
        XCTAssertNotNil(viewModel.currentSummary)

        // When
        viewModel.clearSummary()

        // Then
        XCTAssertTrue(viewModel.summaryState.isEmpty)
        XCTAssertNil(viewModel.summaryError)
        XCTAssertFalse(viewModel.showSummarySheet)
    }

    // MARK: - Helper Methods Tests

    func testGetLastWeekRangeString() {
        // When
        let rangeString = viewModel.getLastWeekRangeString()

        // Then
        XCTAssertFalse(rangeString.isEmpty)
        XCTAssertTrue(rangeString.contains("("))
        XCTAssertTrue(rangeString.contains(")"))
    }
}
