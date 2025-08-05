//
//  TrainingPlanViewModelTests.swift
//  HavitalTests
//

import XCTest
@testable import Havital

@MainActor
final class TrainingPlanViewModelTests: XCTestCase {
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func makeOverview() -> TrainingPlanOverview {
        return TrainingPlanOverview(
            id: "overview1",
            mainRaceId: "race1",
            targetEvaluate: "",
            totalWeeks: 3,
            trainingHighlight: "",
            trainingPlanName: "",
            trainingStageDescription: [],
            createdAt: "2025-03-05T00:00:00Z"
        )
    }

    // 測試在第一週且有計畫時，不顯示任何提示
    func testFirstWeekReady_noPrompts() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-09T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        vm.selectedWeek = 1
        let plan = WeeklyPlan(id: "", purpose: "", weekOfPlan: 1, totalWeeks: 3, totalDistance: 0.0, designReason: nil, days: [])
        vm.planStatus = .ready(plan)
        vm.updatePromptViews()
        XCTAssertFalse(vm.showNewWeekPrompt)
        XCTAssertFalse(vm.noWeeklyPlanAvailable)
        XCTAssertFalse(vm.showFinalWeekPrompt)
    }

    // 測試在第二週開始且尚未生成週計畫時，顯示產生新週提示
    func testSecondWeekStart_showNewWeekPrompt() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-11T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        let cw = vm.calculateCurrentTrainingWeek()!
        vm.selectedWeek = cw
        vm.planStatus = .noPlan
        vm.updatePromptViews()
        XCTAssertTrue(vm.showNewWeekPrompt)
        XCTAssertFalse(vm.noWeeklyPlanAvailable)
    }

    // 測試選擇早於當前週且尚未生成計畫時，顯示週計畫缺失提示
    func testSelectPreviousMissingWeek_noWeeklyPlanAvailable() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-18T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        // cw == 3
        vm.selectedWeek = 2
        vm.planStatus = .noPlan
        vm.updatePromptViews()
        XCTAssertFalse(vm.showNewWeekPrompt)
        XCTAssertTrue(vm.noWeeklyPlanAvailable)
    }

    // 測試計畫完成後，選擇最後一週時顯示最終週提示
    func testAfterPlanCompletion_showFinalWeekPrompt() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-24T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        // cw == 4, totalWeeks == 3 -> completed
        vm.selectedWeek = 3
        vm.planStatus = .completed
        vm.updatePromptViews()
        XCTAssertTrue(vm.showFinalWeekPrompt)
    }

    // MARK: - 其他提示顯示邏輯測試
    // 測試在 .ready 狀態且選擇週非當前週時，不顯示任何提示
    func testReadyNonCurrentWeek_noPrompts() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-12T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        let plan = WeeklyPlan(id: "", purpose: "", weekOfPlan: 2, totalWeeks: 3, totalDistance: 0.0, designReason: nil, days: [])
        vm.planStatus = .ready(plan)
        vm.selectedWeek = 3
        vm.updatePromptViews()
        XCTAssertFalse(vm.showNewWeekPrompt)
        XCTAssertFalse(vm.noWeeklyPlanAvailable)
        XCTAssertFalse(vm.showFinalWeekPrompt)
    }

    // 測試 .completed 狀態且選擇週小於總週數時，不顯示任何提示
    func testCompletedBeforeFinalWeek_noPrompts() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-25T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        vm.planStatus = .completed
        vm.selectedWeek = 2
        vm.updatePromptViews()
        XCTAssertFalse(vm.showNewWeekPrompt)
        XCTAssertFalse(vm.noWeeklyPlanAvailable)
        XCTAssertFalse(vm.showFinalWeekPrompt)
    }

    // 測試在錯誤狀態時，不顯示任何提示
    func testErrorState_noPrompts() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-15T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        vm.planStatus = .error(NSError(domain: "", code: -1, userInfo: nil))
        vm.selectedWeek = 2
        vm.updatePromptViews()
        XCTAssertFalse(vm.showNewWeekPrompt)
        XCTAssertFalse(vm.noWeeklyPlanAvailable)
        XCTAssertFalse(vm.showFinalWeekPrompt)
    }

    // 測試在載入中時，不應顯示任何提示
    func testIsNewWeekPromptNeeded_whileLoading_isFalse() {
        let vm = TrainingPlanViewModel()
        vm.now = { self.isoFormatter.date(from: "2025-03-11T12:00:00Z")! }
        vm.trainingOverview = makeOverview()
        let cw = vm.calculateCurrentTrainingWeek()!
        vm.selectedWeek = cw
        // 模擬正在載入的狀態
        vm.planStatus = .loading
        // 即使課表為 nil 且在當前週，也不該顯示提示
        vm.weeklyPlan = nil
        XCTAssertFalse(vm.isNewWeekPromptNeeded, "當 planStatus 為 loading 時，isNewWeekPromptNeeded 應為 false")
    }
}
