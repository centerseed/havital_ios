import XCTest
@testable import paceriz_dev

@MainActor
final class EditScheduleV2ViewModelTests: XCTestCase {

    func testSaveEdits_preservesClimateMetaAndAdjustedPaceWhenRunUnchanged() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeWeeklyPlan()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        XCTAssertEqual(savedDay.climateMeta?.heatPressureLevel, "high")

        guard case .run(let runActivity) = savedDay.primary else {
            return XCTFail("Expected run activity")
        }
        XCTAssertEqual(runActivity.basePace, "5:40")
        XCTAssertEqual(runActivity.climateAdjustedPace, "6:02")
        XCTAssertEqual(runActivity.climateMeta?.paceAdjustmentPct, 6.5)
    }

    func testSaveEdits_recalculatesAdjustedPaceWhenPaceChanges() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeWeeklyPlan()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )
        viewModel.editingDays[0].trainingDetails?.pace = "5:20"

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        XCTAssertEqual(savedDay.climateMeta?.heatPressureLevel, "high")

        guard case .run(let runActivity) = savedDay.primary else {
            return XCTFail("Expected run activity")
        }
        XCTAssertEqual(runActivity.basePace, "5:20")
        XCTAssertEqual(runActivity.climateAdjustedPace, "5:41")
        XCTAssertEqual(runActivity.climateMeta?.paceAdjustmentPct, 6.5)
    }

    func testSaveEdits_clearsClimateMetaWhenRunChangedToStrength() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeWeeklyPlan()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )
        viewModel.editingDays[0].trainingType = DayType.strength.rawValue
        viewModel.editingDays[0].trainingDetails = nil
        viewModel.editingDays[0].strengthExercises = []
        viewModel.editingDays[0].strengthType = "general"

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        XCTAssertNil(savedDay.climateMeta)

        guard case .strength = savedDay.primary else {
            return XCTFail("Expected strength activity")
        }
    }

    /// 回歸：使用者沒動的天必須無損 round-trip，心率區間 / 目標強度不可被洗掉。
    /// 修復前 buildRunActivityDTO 對這兩個欄位寫死 nil，存檔後整週都會掉資訊。
    func testSaveEdits_preservesHeartRateRangeAndTargetIntensityWhenUnchanged() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeWeeklyPlan()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        guard case .run(let runActivity) = savedDay.primary else {
            return XCTFail("Expected run activity")
        }
        XCTAssertEqual(runActivity.heartRateRange?.min, 140)
        XCTAssertEqual(runActivity.heartRateRange?.max, 155)
        XCTAssertEqual(runActivity.targetIntensity, "easy")
        // 熱適應仍在
        XCTAssertEqual(savedDay.climateMeta?.heatPressureLevel, "high")
        XCTAssertEqual(runActivity.climateMeta?.paceAdjustmentPct, 6.5)
    }

    /// 回歸：只改配速（runType 不變）時，心率區間 / 目標強度應從原始 run 帶回，不可消失。
    func testSaveEdits_preservesHeartRateRangeAndTargetIntensityWhenOnlyPaceChanges() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeWeeklyPlan()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )
        viewModel.editingDays[0].trainingDetails?.pace = "5:20"

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        guard case .run(let runActivity) = savedDay.primary else {
            return XCTFail("Expected run activity")
        }
        XCTAssertEqual(runActivity.heartRateRange?.min, 140)
        XCTAssertEqual(runActivity.heartRateRange?.max, 155)
        XCTAssertEqual(runActivity.targetIntensity, "easy")
        XCTAssertEqual(runActivity.basePace, "5:20")
    }

    private func makeWeeklyPlan() -> WeeklyPlanV2 {
        let climateMeta = ClimateMeta(
            feelsLikeTempC: 33.6,
            heatPressureLevel: "high",
            paceAdjustmentPct: 6.5,
            reasonText: "High heat stress.",
            longRunReductionPct: nil
        )
        let runActivity = RunActivity(
            runType: "easy",
            distanceKm: 8,
            distanceDisplay: nil,
            distanceUnit: nil,
            paceUnit: nil,
            durationMinutes: nil,
            durationSeconds: nil,
            pace: "5:40",
            basePace: "5:40",
            climateAdjustedPace: "6:02",
            heartRateRange: HeartRateRangeV2(min: 140, max: 155),
            interval: nil,
            segments: nil,
            description: "Easy run",
            targetIntensity: "easy",
            climateMeta: climateMeta
        )
        let day = DayDetail(
            dayIndex: 1,
            dayTarget: "Easy",
            reason: "Base aerobic",
            tips: nil,
            category: .run,
            climateMeta: climateMeta,
            session: TrainingSession(
                warmup: nil,
                primary: .run(runActivity),
                cooldown: nil,
                supplementary: nil
            ),
            supplementary: nil
        )

        return WeeklyPlanV2(
            planId: "plan_1",
            weekOfTraining: 1,
            id: "plan_1",
            purpose: "test",
            weekOfPlan: 1,
            totalWeeks: 12,
            totalDistance: 8,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: nil,
            coachNote: nil,
            days: [day],
            intensityTotalMinutes: nil,
            currentVdot: nil,
            vdotSource: nil,
            createdAt: nil,
            updatedAt: nil,
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )
    }
}
