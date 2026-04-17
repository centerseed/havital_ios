//
//  V1RepositoryGuardDecoratorTests.swift
//  HavitalTests
//
//  A-4: Unit tests for V1RepositoryGuardDecorator
//  - V2 users hitting V1 endpoints → throws incorrectVersionRouting, wrapped NOT called
//  - V1 users → pass through
//  - Cold start race (unknown version → default v1) → pass through
//

import XCTest
@testable import paceriz_dev

final class V1RepositoryGuardDecoratorTests: XCTestCase {

    // MARK: - Properties

    private var mockRouter: MockTrainingVersionRouter!
    private var mockWrapped: MockTrainingPlanRepository!
    private var sut: V1RepositoryGuardDecorator!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockRouter = MockTrainingVersionRouter()
        mockWrapped = MockTrainingPlanRepository()
        sut = V1RepositoryGuardDecorator(wrapped: mockWrapped, versionRouter: mockRouter)
    }

    override func tearDown() {
        sut = nil
        mockWrapped = nil
        mockRouter = nil
        super.tearDown()
    }

    // MARK: - V2 user → blocked (AC-A4-02, AC-A4-03)

    func test_v2User_getOverview_throwsIncorrectVersionRouting_wrappedNotCalled() async {
        mockRouter.isV2Result = true

        do {
            _ = try await sut.getOverview()
            XCTFail("Expected throw, got success")
        } catch let error as DomainError {
            guard case .incorrectVersionRouting(let context) = error else {
                XCTFail("Expected .incorrectVersionRouting, got \(error)")
                return
            }
            XCTAssertEqual(context, "V1Guard.getOverview")
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }

        XCTAssertEqual(mockWrapped.getOverviewCallCount, 0,
                       "Wrapped repo must NOT be called when V2 user is blocked")
    }

    func test_v2User_createWeeklyPlan_throws_wrappedNotCalled() async {
        mockRouter.isV2Result = true

        do {
            _ = try await sut.createWeeklyPlan(week: 1, startFromStage: nil, isBeginner: false)
            XCTFail("Expected throw")
        } catch let error as DomainError {
            guard case .incorrectVersionRouting(let context) = error else {
                XCTFail("Expected .incorrectVersionRouting, got \(error)")
                return
            }
            XCTAssertEqual(context, "V1Guard.createWeeklyPlan")
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }

        XCTAssertEqual(mockWrapped.createWeeklyPlanCallCount, 0)
    }

    func test_v2User_getWeeklyPlan_throws() async {
        mockRouter.isV2Result = true
        do {
            _ = try await sut.getWeeklyPlan(planId: "abc")
            XCTFail("Expected throw")
        } catch let error as DomainError {
            guard case .incorrectVersionRouting = error else {
                XCTFail("Expected .incorrectVersionRouting, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }
        XCTAssertEqual(mockWrapped.getWeeklyPlanCallCount, 0)
    }

    // MARK: - V1 user → pass through (AC-A4-07)

    func test_v1User_getOverview_passesThrough() async throws {
        mockRouter.isV2Result = false
        mockWrapped.overviewToReturn = TrainingPlanTestFixtures.trainingOverview

        _ = try await sut.getOverview()

        XCTAssertEqual(mockWrapped.getOverviewCallCount, 1,
                       "Wrapped repo must be called for V1 user")
    }

    func test_v1User_createWeeklyPlan_passesThrough() async throws {
        mockRouter.isV2Result = false
        mockWrapped.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        _ = try await sut.createWeeklyPlan(week: 1, startFromStage: nil, isBeginner: false)

        XCTAssertEqual(mockWrapped.createWeeklyPlanCallCount, 1)
    }

    // MARK: - Cold start race (AC-A4-06)

    /// Router 若 UserProfile 尚未 bootstrap，`isV2User()` 會 default `v1` → 不攔。
    /// 此為可接受 race window；測試確認 decorator 不會在 unknown 情境下誤攔 V1 用戶。
    func test_coldStartRace_unknownVersion_defaultsV1_passesThrough() async throws {
        // Mock simulates the "user profile unreachable → default v1" behavior
        mockRouter.isV2Result = false  // router internally returns v1 on failure
        mockWrapped.overviewToReturn = TrainingPlanTestFixtures.trainingOverview

        _ = try await sut.getOverview()

        XCTAssertEqual(mockWrapped.getOverviewCallCount, 1,
                       "Cold start race → default v1 → must pass through (acceptable race window)")
    }

    // MARK: - Behaviour verification (replaces log spy — see handoff note)

    /// 我們無法直接攔截 `Logger.firebase` 的 call；改以「throws + wrapped 未被呼叫」間接證明
    /// guard 被觸發（也就是會去 log 的那條路徑）。這是 handoff 明文同意的替代策略。
    /// 覆蓋所有 guarded 方法，每個都驗證 context 字串格式 = "V1Guard.{methodName}"
    func test_v2User_allGuardedMethods_throwWithCorrectContext() async {
        mockRouter.isV2Result = true

        await assertThrowsIncorrectVersionRouting("V1Guard.refreshWeeklyPlan") {
            _ = try await self.sut.refreshWeeklyPlan(planId: "p")
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.modifyWeeklyPlan") {
            _ = try await self.sut.modifyWeeklyPlan(
                planId: "p",
                updatedPlan: TrainingPlanTestFixtures.weeklyPlan1
            )
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.refreshOverview") {
            _ = try await self.sut.refreshOverview()
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.createOverview") {
            _ = try await self.sut.createOverview(startFromStage: nil, isBeginner: false)
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.updateOverview") {
            _ = try await self.sut.updateOverview(overviewId: "o")
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.getPlanStatus") {
            _ = try await self.sut.getPlanStatus()
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.refreshPlanStatus") {
            _ = try await self.sut.refreshPlanStatus()
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.getModifications") {
            _ = try await self.sut.getModifications()
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.getModificationsDescription") {
            _ = try await self.sut.getModificationsDescription()
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.updateModifications") {
            _ = try await self.sut.updateModifications([])
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.clearModifications") {
            try await self.sut.clearModifications()
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.createWeeklySummary") {
            _ = try await self.sut.createWeeklySummary(weekNumber: 1, forceUpdate: false)
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.getWeeklySummaries") {
            _ = try await self.sut.getWeeklySummaries()
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.getWeeklySummary") {
            _ = try await self.sut.getWeeklySummary(weekNumber: 1)
        }
        await assertThrowsIncorrectVersionRouting("V1Guard.updateAdjustments") {
            _ = try await self.sut.updateAdjustments(summaryId: "s", items: [])
        }
    }

    // MARK: - Cache methods are NOT guarded (本地操作，不觸發 HTTP)

    func test_clearCache_v2User_passesThroughWithoutGuard() async {
        mockRouter.isV2Result = true
        await sut.clearCache()
        // clearCache/preloadData are local-only; decorator must not attempt to guard them.
        // We verify by ensuring no throw path is reached (compilation proves no try).
        // Call-count tracking not available in base mock — behavioural check: no exception.
    }

    func test_preloadData_v2User_passesThroughWithoutGuard() async {
        mockRouter.isV2Result = true
        await sut.preloadData()
    }

    // MARK: - Helpers

    private func assertThrowsIncorrectVersionRouting(
        _ expectedContext: String,
        _ action: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await action()
            XCTFail("Expected throw for context \(expectedContext)", file: file, line: line)
        } catch let error as DomainError {
            guard case .incorrectVersionRouting(let context) = error else {
                XCTFail("Expected .incorrectVersionRouting for \(expectedContext), got \(error)",
                        file: file, line: line)
                return
            }
            XCTAssertEqual(context, expectedContext, file: file, line: line)
        } catch {
            XCTFail("Expected DomainError, got \(error)", file: file, line: line)
        }
    }
}

// MARK: - DomainError coverage for incorrectVersionRouting (A-4 ships the case)

final class DomainErrorIncorrectVersionRoutingTests: XCTestCase {

    func test_incorrectVersionRouting_shouldShowErrorView_true() {
        let error = DomainError.incorrectVersionRouting(context: "ctx")
        XCTAssertTrue(error.shouldShowErrorView)
    }

    func test_incorrectVersionRouting_isRetryable_false() {
        let error = DomainError.incorrectVersionRouting(context: "ctx")
        XCTAssertFalse(error.isRetryable)
    }

    func test_incorrectVersionRouting_errorDescription_containsContext() {
        let error = DomainError.incorrectVersionRouting(context: "WeeklyPlanVM.loadWeeklyPlan")
        let desc = error.errorDescription ?? ""
        XCTAssertTrue(desc.contains("WeeklyPlanVM.loadWeeklyPlan"))
        XCTAssertTrue(desc.contains("版本不一致"))
    }

    func test_incorrectVersionRouting_userFriendlyMessage_localizedHint() {
        let error = DomainError.incorrectVersionRouting(context: "ctx")
        XCTAssertTrue(error.userFriendlyMessage.contains("重新啟動"))
    }
}

// MARK: - MockTrainingVersionRouter

/// Minimal mock of `TrainingVersionRouting` for decorator tests.
final class MockTrainingVersionRouter: TrainingVersionRouting {
    /// Canonical field: set `true` to simulate a V2 user, `false` for V1 (or cold-start fallback).
    var isV2Result: Bool = false

    private(set) var isV2UserCallCount = 0
    private(set) var isV1UserCallCount = 0
    private(set) var getTrainingVersionCallCount = 0

    func getTrainingVersion() async -> String {
        getTrainingVersionCallCount += 1
        return isV2Result ? "v2" : "v1"
    }

    func isV2User() async -> Bool {
        isV2UserCallCount += 1
        return isV2Result
    }

    func isV1User() async -> Bool {
        isV1UserCallCount += 1
        return !isV2Result
    }
}
