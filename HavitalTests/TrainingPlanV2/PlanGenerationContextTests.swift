import XCTest
@testable import paceriz_dev

final class PlanGenerationContextTests: XCTestCase {

    func test_stageIdToLocalizedKey_base() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("base"), L10n.Training.Stage.base)
    }

    func test_stageIdToLocalizedKey_build() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("build"), L10n.Training.Stage.build)
    }

    func test_stageIdToLocalizedKey_peak() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("peak"), L10n.Training.Stage.peak)
    }

    func test_stageIdToLocalizedKey_taper() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("taper"), L10n.Training.Stage.taper)
    }

    func test_stageIdToLocalizedKey_conversion() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("conversion"), L10n.Training.Stage.conversion)
    }

    func test_stageIdToLocalizedKey_caseInsensitive() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("BASE"), L10n.Training.Stage.base)
    }

    func test_stageIdToLocalizedKey_unknown() {
        XCTAssertEqual(PlanGenerationContext.stageIdToLocalizationKey("something_else"), L10n.Training.Stage.unknown)
    }

    func test_phaseInfo_returnsNilWhenNoStagesMatch() {
        XCTAssertNil(PlanGenerationContext.phaseInfo(from: [], targetWeek: 3))
    }

    func test_phaseInfo_returnsNilWhenWeekOutOfRange() {
        let stage = makeStage(stageId: "base", stageName: "基礎期", weekStart: 1, weekEnd: 4)
        XCTAssertNil(PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 5))
    }

    func test_phaseInfo_returnsCorrectPhaseWeekOffset() {
        let stage = makeStage(stageId: "base", stageName: "基礎期", weekStart: 1, weekEnd: 4)
        let info = PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 2)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.localizedKey, L10n.Training.Stage.base)
        XCTAssertEqual(info?.phaseWeek, 2)
        XCTAssertEqual(info?.phaseTotalWeeks, 4)
    }

    func test_phaseInfo_weekOnStartBoundary() {
        let stage = makeStage(stageId: "peak", stageName: "巔峰期", weekStart: 10, weekEnd: 12)
        let info = PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 10)
        XCTAssertEqual(info?.phaseWeek, 1)
        XCTAssertEqual(info?.phaseTotalWeeks, 3)
    }

    func test_phaseInfo_weekOnEndBoundary() {
        let stage = makeStage(stageId: "peak", stageName: "巔峰期", weekStart: 10, weekEnd: 12)
        let info = PlanGenerationContext.phaseInfo(from: [stage], targetWeek: 12)
        XCTAssertEqual(info?.phaseWeek, 3)
    }
}

// MARK: - Helpers

private func makeStage(stageId: String, stageName: String, weekStart: Int, weekEnd: Int) -> TrainingStageV2 {
    TrainingStageV2(
        stageId: stageId,
        stageName: stageName,
        stageDescription: "",
        weekStart: weekStart,
        weekEnd: weekEnd,
        trainingFocus: "",
        targetWeeklyKmRange: TargetWeeklyKmRangeV2(low: 0, high: 0),
        targetWeeklyKmRangeDisplay: nil,
        intensityRatio: nil,
        keyWorkouts: nil
    )
}
