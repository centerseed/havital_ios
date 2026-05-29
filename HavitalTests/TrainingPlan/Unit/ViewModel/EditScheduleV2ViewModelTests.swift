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
            heartRateRange: nil,
            interval: nil,
            segments: nil,
            description: "Easy run",
            targetIntensity: nil,
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
