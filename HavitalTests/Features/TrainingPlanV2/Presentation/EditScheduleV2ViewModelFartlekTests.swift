import XCTest
@testable import paceriz_dev

@MainActor
final class EditScheduleV2ViewModelFartlekTests: XCTestCase {

    /// T-0165 (64c9a47a): climate is plan-level `climate[7]`, keyed by DATE and recomputed by the
    /// backend on read. The edit payload therefore carries **no** climate at all — that is exactly
    /// what stops a moved workout from dragging its old day's temperature along with it, and it is
    /// why `shouldPreserveRunClimate` / `climatePaceValues` were deleted rather than fixed.
    ///
    /// This test used to assert the pre-T-0165 design (client re-attaches the destination day's
    /// `climate_meta`). That code is gone on purpose, so the assertion is now the contract itself:
    /// nothing climate-shaped may leave the editor.
    func test_reorderedRun_sendsNoClimate() throws {
        let sourceClimate = ClimateMeta(
            feelsLikeTempC: 32,
            heatPressureLevel: "high",
            paceAdjustmentPct: 10,
            reasonText: "source heat",
            longRunReductionPct: nil
        )
        let destinationClimate = ClimateMeta(
            feelsLikeTempC: 24,
            heatPressureLevel: "mild",
            paceAdjustmentPct: 2,
            reasonText: "destination heat",
            longRunReductionPct: nil
        )
        let sourceDay = makeRunDay(dayIndex: 2, target: "Easy", climateMeta: sourceClimate)
        let destinationDay = makeRunDay(dayIndex: 4, target: "Tempo", climateMeta: destinationClimate)
        let plan = makeWeeklyPlan(days: [sourceDay, destinationDay])
        let vm = EditScheduleV2ViewModel(weeklyPlan: plan, repository: MockTrainingPlanV2Repository())

        var movedDay = MutableTrainingDay(from: sourceDay)
        movedDay.dayIndex = "4"

        let dto = vm.debug_buildDayDetailDTO(from: movedDay)

        XCTAssertEqual(dto.dayIndex, 4)
        XCTAssertNil(dto.climateMeta, "T-0165: the edit payload must not carry climate")
        guard case .run(let run) = dto.primary else {
            return XCTFail("Expected run primary")
        }
        // In particular it must not carry the SOURCE day's heat ("high" / "source heat"), which
        // is the regression this test has always been about.
        XCTAssertNil(run.climateMeta, "T-0165: the edit payload must not carry climate")
        XCTAssertNil(run.climateAdjustedPace, "T-0165: no climate-adjusted pace leaves the editor")
    }

    func test_fartlekSegmentPaceChange_reflectedInDayDetailDTO() throws {
        let segments = [
            MutableProgressionSegment(distanceKm: 3.0, pace: "5:30", description: "Fast segment"),
            MutableProgressionSegment(distanceKm: 2.0, pace: "6:00", description: "Slow segment"),
        ]
        let details = MutableTrainingDetails(
            description: "Fartlek",
            totalDistanceKm: 5.0,
            segments: segments
        )
        var day = MutableTrainingDay(
            dayIndex: "3",
            dayTarget: "Fartlek",
            trainingType: DayType.fartlek.rawValue,
            trainingDetails: details
        )

        // 模擬使用者在 CombinationEditorV2 改第一段配速
        day.trainingDetails?.segments?[0].pace = "4:45"

        let mockRepo = MockTrainingPlanV2Repository()
        let plan = makeFartlekWeeklyPlan()
        let vm = EditScheduleV2ViewModel(weeklyPlan: plan, repository: mockRepo)

        let dto = vm.debug_buildDayDetailDTO(from: day)
        guard case .run(let run) = dto.primary else {
            return XCTFail("Expected run primary")
        }
        let segPaces = run.segments?.map(\.pace) ?? []
        XCTAssertTrue(segPaces.contains("4:45"), "Changed pace must appear in DTO segments: \(segPaces)")
    }

    func test_fartlekSegmentDescription_fallbackFromOriginalWhenMissing() throws {
        let originalSegments = [
            RunSegment(
                distanceKm: 3.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
                durationMinutes: nil, durationSeconds: nil,
                pace: "5:30", basePace: nil, climateAdjustedPace: nil, climateMeta: nil,
                heartRateRange: nil, intensity: nil, description: "Fast segment",
                kind: nil, repeats: nil, work: nil, recovery: nil
            ),
            RunSegment(
                distanceKm: 2.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
                durationMinutes: nil, durationSeconds: nil,
                pace: "6:00", basePace: nil, climateAdjustedPace: nil, climateMeta: nil,
                heartRateRange: nil, intensity: nil, description: "Slow segment",
                kind: nil, repeats: nil, work: nil, recovery: nil
            ),
        ]
        let runActivity = RunActivity(
            runType: "fartlek",
            distanceKm: 5.0,
            distanceDisplay: nil,
            distanceUnit: nil,
            paceUnit: nil,
            durationMinutes: nil,
            durationSeconds: nil,
            pace: nil,
            basePace: nil,
            climateAdjustedPace: nil,
            heartRateRange: nil,
            interval: nil,
            segments: originalSegments,
            description: "Fartlek",
            targetIntensity: nil,
            climateMeta: nil
        )
        let dayDetail = DayDetail(
            dayIndex: 3,
            dayTarget: "Fartlek",
            reason: "",
            tips: nil,
            category: .run,
            climateMeta: nil,
            session: TrainingSession(warmup: nil, primary: .run(runActivity), cooldown: nil, supplementary: nil),
            supplementary: nil
        )
        let plan = WeeklyPlanV2(
            planId: "plan_fartlek",
            weekOfTraining: 2,
            id: "plan_fartlek",
            purpose: "test",
            weekOfPlan: 2,
            totalWeeks: 12,
            totalDistance: 5,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: nil,
            mileageProgressionNote: nil,
            coachNote: nil,
            days: [dayDetail],
            intensityTotalMinutes: nil,
            currentVdot: 45,
            vdotSource: nil,
            createdAt: nil,
            updatedAt: nil,
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )

        var day = MutableTrainingDay(from: dayDetail)
        day.trainingDetails?.segments?[0].pace = "4:45"
        day.trainingDetails?.segments?[0].description = nil

        let vm = EditScheduleV2ViewModel(weeklyPlan: plan, repository: MockTrainingPlanV2Repository())
        let dto = vm.debug_buildDayDetailDTO(from: day)

        guard case .run(let run) = dto.primary else {
            return XCTFail("Expected run primary")
        }
        let descriptions = run.segments?.map(\.description) ?? []
        XCTAssertEqual(descriptions.first, "Fast segment", "Missing segment description should fall back to original")
    }

    private func makeFartlekWeeklyPlan() -> WeeklyPlanV2 {
        let segments = [
            RunSegment(
                distanceKm: 3.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
                durationMinutes: nil, durationSeconds: nil,
                pace: "5:30", basePace: nil, climateAdjustedPace: nil, climateMeta: nil,
                heartRateRange: nil, intensity: nil, description: "Fast segment",
                kind: nil, repeats: nil, work: nil, recovery: nil
            ),
            RunSegment(
                distanceKm: 2.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
                durationMinutes: nil, durationSeconds: nil,
                pace: "6:00", basePace: nil, climateAdjustedPace: nil, climateMeta: nil,
                heartRateRange: nil, intensity: nil, description: "Slow segment",
                kind: nil, repeats: nil, work: nil, recovery: nil
            ),
        ]
        let runActivity = RunActivity(
            runType: "fartlek",
            distanceKm: 5.0,
            distanceDisplay: nil,
            distanceUnit: nil,
            paceUnit: nil,
            durationMinutes: nil,
            durationSeconds: nil,
            pace: nil,
            basePace: nil,
            climateAdjustedPace: nil,
            heartRateRange: nil,
            interval: nil,
            segments: segments,
            description: "Fartlek",
            targetIntensity: nil,
            climateMeta: nil
        )
        let day = DayDetail(
            dayIndex: 3,
            dayTarget: "Fartlek",
            reason: "",
            tips: nil,
            category: .run,
            climateMeta: nil,
            session: TrainingSession(warmup: nil, primary: .run(runActivity), cooldown: nil, supplementary: nil),
            supplementary: nil
        )

        return WeeklyPlanV2(
            planId: "plan_fartlek",
            weekOfTraining: 2,
            id: "plan_fartlek",
            purpose: "test",
            weekOfPlan: 2,
            totalWeeks: 12,
            totalDistance: 5,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: nil,
            mileageProgressionNote: nil,
            coachNote: nil,
            days: [day],
            intensityTotalMinutes: nil,
            currentVdot: 45,
            vdotSource: nil,
            createdAt: nil,
            updatedAt: nil,
            trainingLoadAnalysis: nil,
            personalizedRecommendations: nil,
            realTimeAdjustments: nil,
            apiVersion: "2.0"
        )
    }

    private func makeRunDay(dayIndex: Int, target: String, climateMeta: ClimateMeta) -> DayDetail {
        let runActivity = RunActivity(
            runType: "easy",
            distanceKm: 5.0,
            distanceDisplay: nil,
            distanceUnit: nil,
            paceUnit: nil,
            durationMinutes: nil,
            durationSeconds: nil,
            pace: "5:30",
            basePace: "5:30",
            climateAdjustedPace: "6:03",
            heartRateRange: nil,
            interval: nil,
            segments: nil,
            description: target,
            targetIntensity: nil,
            climateMeta: climateMeta
        )
        return DayDetail(
            dayIndex: dayIndex,
            dayTarget: target,
            reason: "",
            tips: nil,
            category: .run,
            climateMeta: climateMeta,
            session: TrainingSession(warmup: nil, primary: .run(runActivity), cooldown: nil, supplementary: nil),
            supplementary: nil
        )
    }

    private func makeWeeklyPlan(days: [DayDetail]) -> WeeklyPlanV2 {
        WeeklyPlanV2(
            planId: "plan_reorder",
            weekOfTraining: 2,
            id: "plan_reorder",
            purpose: "test",
            weekOfPlan: 2,
            totalWeeks: 12,
            totalDistance: 10,
            totalDistanceDisplay: nil,
            totalDistanceUnit: nil,
            totalDistanceReason: nil,
            designReason: nil,
            mileageProgressionNote: nil,
            coachNote: nil,
            days: days,
            intensityTotalMinutes: nil,
            currentVdot: 45,
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
