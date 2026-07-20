import XCTest
@testable import paceriz_dev

@MainActor
final class EditScheduleV2ViewModelTests: XCTestCase {

    /// T-0239（havital_ios #10）：存檔成功後必須 publish `.dataChanged(.trainingPlanV2)`，
    /// 否則訂閱該事件的成就頁（PersonalAchievementsViewModel）等在改課表後不會刷新。
    func testSaveEdits_publishesTrainingPlanV2DataChanged() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeWeeklyPlan()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )

        let published = expectation(description: "publishes .dataChanged(.trainingPlanV2)")
        let subscriberId = "test-editv2-\(UUID().uuidString)"
        CacheEventBus.shared.subscribe(forIdentifier: subscriberId) { reason in
            if case .dataChanged(.trainingPlanV2) = reason {
                published.fulfill()
            }
        }
        defer { CacheEventBus.shared.unsubscribe(forIdentifier: subscriberId) }

        _ = try await viewModel.saveEdits()

        await fulfillment(of: [published], timeout: 2.0)
    }

    /// T-0165：編輯送出**不得攜帶任何 climate 欄位**。
    ///
    /// 舊契約是「編輯時把 climate_meta / climate_adjusted_pace 一起送回去，讓後端保留」。
    /// 那讓氣候變成課表的屬性 —— 搬動課表就會把 A 天的溫度帶到 B 天。
    /// 新契約：課表裡只有原始處方，氣候由後端讀取時依日期現算並投影。
    func testSaveEdits_neverSendsClimateFields() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeWeeklyPlan()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        XCTAssertNil(savedDay.climateMeta)

        guard case .run(let runActivity) = savedDay.primary else {
            return XCTFail("Expected run activity")
        }
        XCTAssertNil(runActivity.basePace)
        XCTAssertNil(runActivity.climateAdjustedPace)
        XCTAssertNil(runActivity.climateMeta)
        // 剝的是氣候，不是處方
        XCTAssertEqual(runActivity.pace, "5:40")
    }

    /// 改配速後仍不得送 climate；處方配速本身要如實送出。
    func testSaveEdits_paceChangeSendsPrescriptionWithoutClimate() async throws {
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
        XCTAssertNil(savedDay.climateMeta)

        guard case .run(let runActivity) = savedDay.primary else {
            return XCTFail("Expected run activity")
        }
        XCTAssertEqual(runActivity.pace, "5:20")
        XCTAssertNil(runActivity.basePace)
        XCTAssertNil(runActivity.climateAdjustedPace)
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
        // 保住的是後端 enrichment，不是氣候（T-0165）
        XCTAssertNil(savedDay.climateMeta)
        XCTAssertNil(runActivity.climateMeta)
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
        XCTAssertEqual(runActivity.pace, "5:20")
        XCTAssertNil(runActivity.basePace)
    }

    // MARK: - 互換日期（onMove）必須無損

    /// 回歸：純互換兩天（內容一個字都沒改）必須無損搬移。
    ///
    /// `buildDayDetailDTO` 的無損捷徑靠 `MutableTrainingDay(from: originalDay) == day`，
    /// 而 `==` 第一項就比 `dayIndex`。onMove 會重編 dayIndex，`originalDay` 卻是用
    /// 不變的 `originalDayIndex` 撈的 → 被移動過的天恆不相等 → 一律墜入有損重建路徑。
    /// 有損路徑對 segment 寫死 `kind/repeats/work/recovery = nil`，於是使用者只是把
    /// 週二週四對調，週四的 steadyIntervals 結構就被打平成一堆無型態的段落。
    func testSaveEdits_swappingTwoDaysPreservesSegmentStructureLosslessly() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeTwoDayPlanWithStructuredSecondDay()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )

        // 完全比照 EditScheduleViewV2.onMove：重排後把 dayIndex 重編為新位置
        viewModel.editingDays.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        for i in viewModel.editingDays.indices {
            viewModel.editingDays[i].dayIndex = "\(i + 1)"
        }

        _ = try await viewModel.saveEdits()

        let days = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days)
        XCTAssertEqual(days.count, 2)

        // 原本 day 2 的 steadyIntervals 現在應該落在 day 1，且結構完整
        let movedDay = try XCTUnwrap(days.first { $0.dayIndex == 1 })
        XCTAssertEqual(movedDay.dayTarget, "Steady intervals")
        guard case .run(let run) = movedDay.primary else {
            return XCTFail("Expected run activity at day 1 after swap")
        }
        let segment = try XCTUnwrap(run.segments?.first)
        XCTAssertEqual(segment.kind, "steady_intervals", "swap must not flatten segment kind")
        XCTAssertEqual(segment.repeats, 5, "swap must not drop repeats")
        XCTAssertEqual(segment.work?.distanceM, 1000, "swap must not drop work effort")
        XCTAssertEqual(segment.recovery?.durationSeconds, 90, "swap must not drop recovery effort")

        // 編輯器沒有模型化的顯示欄位同樣不該在純搬移時消失
        XCTAssertEqual(run.distanceDisplay, 8.0)
        XCTAssertEqual(run.distanceUnit, "km")
        XCTAssertEqual(run.paceUnit, "min_per_km")
        XCTAssertEqual(run.heartRateRange?.min, 150)
        XCTAssertEqual(run.targetIntensity, "threshold")

        // 另一天同樣無損，且落在 day 2
        let otherDay = try XCTUnwrap(days.first { $0.dayIndex == 2 })
        XCTAssertEqual(otherDay.dayTarget, "Easy")

        // 搬移仍不得攜帶氣候（T-0165）
        XCTAssertNil(movedDay.climateMeta)
        XCTAssertNil(run.climateMeta)
        XCTAssertNil(run.climateAdjustedPace)
        XCTAssertNil(run.basePace)
    }

    private func makeTwoDayPlanWithStructuredSecondDay() -> WeeklyPlanV2 {
        let base = makeWeeklyPlan()

        let steadySegment = RunSegment(
            distanceKm: 8,
            distanceM: nil,
            distanceDisplay: 8,
            distanceUnit: "km",
            durationMinutes: nil,
            durationSeconds: nil,
            pace: "4:30",
            basePace: nil,
            climateAdjustedPace: nil,
            climateMeta: nil,
            heartRateRange: HeartRateRangeV2(min: 150, max: 165),
            intensity: "threshold",
            description: "5 x 1000m",
            kind: "steady_intervals",
            repeats: 5,
            work: SegmentEffort(
                distanceKm: 1,
                distanceM: 1000,
                durationMinutes: nil,
                durationSeconds: nil,
                pace: "4:00",
                basePace: nil,
                paceZone: nil,
                targetHrr: nil,
                recoveryType: nil
            ),
            recovery: SegmentEffort(
                distanceKm: nil,
                distanceM: nil,
                durationMinutes: nil,
                durationSeconds: 90,
                pace: nil,
                basePace: nil,
                paceZone: nil,
                targetHrr: nil,
                recoveryType: "jog"
            )
        )

        let steadyRun = RunActivity(
            runType: "steady_intervals",
            distanceKm: 8,
            distanceDisplay: 8,
            distanceUnit: "km",
            paceUnit: "min_per_km",
            durationMinutes: nil,
            durationSeconds: nil,
            pace: "4:30",
            basePace: nil,
            climateAdjustedPace: nil,
            heartRateRange: HeartRateRangeV2(min: 150, max: 165),
            interval: nil,
            segments: [steadySegment],
            description: "Steady intervals",
            targetIntensity: "threshold",
            climateMeta: nil
        )

        let day2 = DayDetail(
            dayIndex: 2,
            dayTarget: "Steady intervals",
            reason: "Threshold development",
            tips: nil,
            category: .run,
            climateMeta: nil,
            session: TrainingSession(
                warmup: nil,
                primary: .run(steadyRun),
                cooldown: nil,
                supplementary: nil
            ),
            supplementary: nil
        )

        return WeeklyPlanV2(
            planId: base.planId,
            weekOfTraining: base.weekOfTraining,
            id: base.id,
            purpose: base.purpose,
            weekOfPlan: base.weekOfPlan,
            totalWeeks: base.totalWeeks,
            totalDistance: base.totalDistance,
            totalDistanceDisplay: base.totalDistanceDisplay,
            totalDistanceUnit: base.totalDistanceUnit,
            totalDistanceReason: base.totalDistanceReason,
            designReason: base.designReason,
            mileageProgressionNote: base.mileageProgressionNote,
            coachNote: base.coachNote,
            days: base.days + [day2],
            intensityTotalMinutes: base.intensityTotalMinutes,
            currentVdot: base.currentVdot,
            vdotSource: base.vdotSource,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
            trainingLoadAnalysis: base.trainingLoadAnalysis,
            personalizedRecommendations: base.personalizedRecommendations,
            realTimeAdjustments: base.realTimeAdjustments,
            apiVersion: base.apiVersion
        )
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
            mileageProgressionNote: nil,
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
