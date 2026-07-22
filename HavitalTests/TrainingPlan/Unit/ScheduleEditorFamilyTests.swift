import XCTest
@testable import paceriz_dev

/// T-0280：課表編輯器 DayType 覆蓋契約。
///
/// 修前：`norwegian_singles` / `steady_intervals` / `race` / `benchmark` 落 SimpleEditor，
/// 間歇／分段結構看不到，存檔可能洗掉 work/recovery/repeats 或 segments。
/// 修後：全部 DayType 必須有 `scheduleEditorFamily`（exhaustiveness 由編譯器守），
/// 且先前漏接型別映射到結構化家族。
final class ScheduleEditorFamilyTests: XCTestCase {

    // MARK: - Exhaustive mapping

    /// 每個 DayType 都能解析家族（CaseIterable + exhaustive switch 雙保險）。
    func testEveryDayTypeHasScheduleEditorFamily() {
        for type in DayType.allCases {
            // 存取本身即觸發 exhaustive switch；若有人加 case 卻沒補 family，編譯就失敗。
            let family = type.scheduleEditorFamily
            XCTAssertNotNil(family, "DayType.\(type.rawValue) must map to a family")
        }
    }

    // MARK: - Previously leaked types (P0 / P1)

    func testNorwegianSingles_isDistanceIntervalNotSimple() {
        XCTAssertEqual(DayType.norwegianSingles.scheduleEditorFamily, .intervalDistance)
        XCTAssertTrue(DayType.norwegianSingles.isComplexScheduleTraining)
    }

    func testSteadyIntervals_isCombinationNotSimple() {
        XCTAssertEqual(DayType.steadyIntervals.scheduleEditorFamily, .combination)
        XCTAssertTrue(DayType.steadyIntervals.isComplexScheduleTraining)
    }

    func testRaceAndBenchmark_areTempoFamily() {
        XCTAssertEqual(DayType.race.scheduleEditorFamily, .tempo)
        XCTAssertEqual(DayType.benchmark.scheduleEditorFamily, .tempo)
        XCTAssertFalse(DayType.race.isComplexScheduleTraining)
        XCTAssertFalse(DayType.benchmark.isComplexScheduleTraining)
    }

    // MARK: - Cross stays simple family

    func testCrossTrainingFamily_isCross() {
        for type: DayType in [.crossTraining, .yoga, .hiking, .cycling, .swimming, .elliptical, .rowing] {
            XCTAssertEqual(type.scheduleEditorFamily, .cross, type.rawValue)
            XCTAssertFalse(type.isComplexScheduleTraining, type.rawValue)
        }
    }

    // MARK: - Save path: norwegian singles keeps interval structure

    func testToMutableTrainingDay_norwegianSingles_preservesWorkRecoveryRepeats() {
        let original = MutableTrainingDay(
            dayIndex: "2",
            dayTarget: "Norwegian singles",
            trainingType: DayType.norwegianSingles.rawValue,
            trainingDetails: MutableTrainingDetails(
                description: "sub-threshold repeats",
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.4,
                    distanceM: 400,
                    timeMinutes: nil,
                    pace: "4:20",
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: nil,
                    distanceM: nil,
                    timeMinutes: nil,
                    timeSeconds: 60,
                    pace: nil,
                    heartRateRange: nil
                ),
                repeats: 8
            )
        )

        let state = TrainingDayEditState(from: original)
        XCTAssertEqual(state.type, .norwegianSingles)
        XCTAssertEqual(state.repeats, 8)
        XCTAssertEqual(state.workDistance, 0.4, accuracy: 0.0001)
        XCTAssertEqual(state.workPace, "4:20")
        XCTAssertTrue(state.isRestInPlace)

        let saved = state.toMutableTrainingDay(originalDay: original)
        XCTAssertEqual(saved.trainingType, DayType.norwegianSingles.rawValue)
        XCTAssertEqual(saved.trainingDetails?.repeats, 8)
        XCTAssertEqual(saved.trainingDetails?.work?.distanceKm, 0.4)
        XCTAssertEqual(saved.trainingDetails?.work?.pace, "4:20")
        XCTAssertNotNil(saved.trainingDetails?.recovery)
        // 原地休息應保留 timeSeconds、不該只剩 distanceKm
        XCTAssertEqual(saved.trainingDetails?.recovery?.timeSeconds, 60)
        XCTAssertNil(saved.trainingDetails?.recovery?.distanceKm)
    }

    func testToMutableTrainingDay_steadyIntervals_preservesSegments() {
        let original = MutableTrainingDay(
            dayIndex: "3",
            dayTarget: "Steady then intervals",
            trainingType: DayType.steadyIntervals.rawValue,
            trainingDetails: MutableTrainingDetails(
                description: "8k steady + 5x1k",
                totalDistanceKm: 13.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 8.0, pace: "5:00", description: "steady"),
                    MutableProgressionSegment(distanceKm: 5.0, pace: "4:20", description: "intervals")
                ]
            )
        )

        let state = TrainingDayEditState(from: original)
        XCTAssertEqual(state.type, .steadyIntervals)
        XCTAssertEqual(state.segments.count, 2)

        let saved = state.toMutableTrainingDay(originalDay: original)
        XCTAssertEqual(saved.trainingType, DayType.steadyIntervals.rawValue)
        XCTAssertEqual(saved.trainingDetails?.segments?.count, 2)
        XCTAssertEqual(saved.trainingDetails?.totalDistanceKm, state.totalSegmentDistance)
        XCTAssertEqual(saved.trainingDetails?.segments?.first?.distanceKm, 8.0)
        // 不得被 default 洗成只有 distanceKm 的簡單跑
        XCTAssertNil(saved.trainingDetails?.distanceKm)
    }

    func testToMutableTrainingDay_race_preservesPaceAndDistance() {
        let original = MutableTrainingDay(
            dayIndex: "6",
            dayTarget: "Race",
            trainingType: DayType.race.rawValue,
            trainingDetails: MutableTrainingDetails(
                description: "10k race",
                distanceKm: 10.0,
                pace: "4:30"
            )
        )

        let state = TrainingDayEditState(from: original)
        state.pace = "4:25"
        state.distance = 10.0

        let saved = state.toMutableTrainingDay(originalDay: original)
        XCTAssertEqual(saved.trainingDetails?.distanceKm, 10.0)
        XCTAssertEqual(saved.trainingDetails?.pace, "4:25")
    }
}
