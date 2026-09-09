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

    /// T-0640：關閉間歇跑的緩和跑時，day-level cooldown 必須以 JSON null 送出，
    /// 否則後端 merge 會把原本的緩和跑保留下來。
    func testSaveEdits_removingCooldownSendsExplicitNullAndPreservesInterval() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeIntervalPlanWithWarmupCooldown()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )
        viewModel.editingDays[0].cooldown = nil

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        XCTAssertNil(savedDay.cooldown)
        XCTAssertNotNil(savedDay.warmup)

        guard case .run(let runActivity) = savedDay.primary else {
            return XCTFail("Expected interval run activity")
        }
        XCTAssertEqual(runActivity.runType, "interval")
        XCTAssertEqual(runActivity.interval?.repeats, 6)
        XCTAssertEqual(runActivity.interval?.workDistanceM, 200)
        XCTAssertEqual(runActivity.interval?.recoveryDescription, "Rest 70 seconds")

        let payload = try jsonObject(savedDay)
        XCTAssertTrue(payload.keys.contains("cooldown"), "Removing cooldown must encode the key")
        XCTAssertTrue(payload["cooldown"] is NSNull, "Removing cooldown must encode JSON null")
    }

    /// Exercise the actual day editor, not a direct mutation of the week model.
    func testDayEditor_removingCooldownPreservesSecondsOnlyStaticRecovery() async throws {
        let repository = MockTrainingPlanV2Repository()
        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: makeIntervalPlanWithWarmupCooldown(), repository: repository
        )
        let originalDay = viewModel.editingDays[0]
        let editor = TrainingDayEditState(from: originalDay)
        XCTAssertTrue(editor.isRestInPlace)
        XCTAssertEqual(editor.recoveryTimeMinutes * 60, 70, accuracy: 0.001)
        editor.hasCooldown = false
        viewModel.editingDays[0] = editor.toMutableTrainingDay(originalDay: originalDay)
        _ = try await viewModel.saveEdits()
        let day = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        guard case .run(let run) = day.primary else { return XCTFail("Expected interval") }
        let interval = try XCTUnwrap(run.interval)
        XCTAssertNil(day.cooldown)
        XCTAssertNotNil(day.warmup)
        XCTAssertEqual(interval.repeats, 6)
        XCTAssertEqual(interval.workDistanceM, 200)
        XCTAssertEqual(interval.recoveryDurationSeconds, 70)
        XCTAssertNil(interval.recoveryDistanceKm)
        XCTAssertNil(interval.recoveryDistanceM)
        XCTAssertNil(interval.recoveryPace)
        let payload = try jsonObject(day)
        XCTAssertTrue(payload["cooldown"] is NSNull)
    }

    func testDayEditor_minutesOnlyStaticAndTimedJogKeepTheirRecoveryMode() {
        for (km, expectedStatic) in [(nil as Double?, true), (0.2, false)] {
            let viewModel = EditScheduleV2ViewModel(
                weeklyPlan: makeIntervalPlanWithWarmupCooldown(
                    recoverySeconds: nil, recoveryMinutes: 2, recoveryKm: km
                ), repository: MockTrainingPlanV2Repository()
            )
            let editor = TrainingDayEditState(from: viewModel.editingDays[0])
            XCTAssertEqual(editor.isRestInPlace, expectedStatic)
            XCTAssertEqual(editor.recoveryTimeMinutes, 2)
            if !expectedStatic { XCTAssertEqual(editor.recoveryDistance, 0.2) }
        }
    }

    func testSaveEdits_existingCooldownStillSendsSegment() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeIntervalPlanWithWarmupCooldown()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        XCTAssertNotNil(savedDay.cooldown)
        let payload = try jsonObject(savedDay)
        XCTAssertTrue(payload["cooldown"] is [String: Any])
    }

    func testSaveEdits_removingWarmupSendsExplicitNull() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeIntervalPlanWithWarmupCooldown()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )
        viewModel.editingDays[0].warmup = nil

        _ = try await viewModel.saveEdits()

        let savedDay = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days?.first)
        XCTAssertNil(savedDay.warmup)
        XCTAssertNotNil(savedDay.cooldown)
        let payload = try jsonObject(savedDay)
        XCTAssertTrue(payload.keys.contains("warmup"), "Removing warmup must encode the key")
        XCTAssertTrue(payload["warmup"] is NSNull, "Removing warmup must encode JSON null")
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

        // 原本 day 2 的 steadyIntervals 現在應該落在 day 1
        let movedDay = try XCTUnwrap(days.first { $0.dayIndex == 1 })
        XCTAssertEqual(movedDay.dayTarget, "Steady intervals")

        // 全欄位守恆：不逐欄位手列，直接 deep-diff 整份 DTO。
        try assertLosslessMove(submitted: movedDay, original: weeklyPlan.days[1])

        // 另一天同樣無損，且落在 day 2
        let otherDay = try XCTUnwrap(days.first { $0.dayIndex == 2 })
        XCTAssertEqual(otherDay.dayTarget, "Easy")
        try assertLosslessMove(submitted: otherDay, original: weeklyPlan.days[0])
    }

    /// 回歸（T-0149 / T-0245）：**編輯**一天的配速，不得破壞該天其餘任何欄位。
    ///
    /// 前一支測試守的是「純搬移」（無損路徑）。這支守的是真正被編輯過、
    /// 因而落入重建路徑的那條線 —— 六次 regression 全部發生在這裡。
    ///
    /// 修復前：重建路徑對 segment 寫死 `kind/repeats/work/recovery = nil`，
    /// 於是使用者只是把 fartlek 那天的配速從 4:30 改成 4:20，
    /// 「5×1000m 間歇」的段落結構就整個被打平成一段勻速跑。
    func testSaveEdits_editingPacePreservesEverythingElseOnStructuredDay() async throws {
        let repository = MockTrainingPlanV2Repository()
        let weeklyPlan = makeTwoDayPlanWithStructuredSecondDay()
        repository.weeklyPlanV2ToReturn = weeklyPlan

        let viewModel = EditScheduleV2ViewModel(
            weeklyPlan: weeklyPlan,
            repository: repository
        )

        // 只改配速，其他一律不動
        let structuredIndex = try XCTUnwrap(viewModel.editingDays.firstIndex { $0.dayIndexInt == 2 })
        viewModel.editingDays[structuredIndex].trainingDetails?.pace = "4:20"

        _ = try await viewModel.saveEdits()

        let days = try XCTUnwrap(repository.lastUpdateWeeklyPlanRequest?.days)
        let submitted = try XCTUnwrap(days.first { $0.dayIndex == 2 })

        // 段落結構必須完整存活，這是本 bug 的核心
        guard case .run(let run) = submitted.primary else {
            return XCTFail("Expected run activity")
        }
        let segment = try XCTUnwrap(run.segments?.first)
        XCTAssertEqual(segment.kind, "steady_intervals")
        XCTAssertEqual(segment.repeats, 5)
        XCTAssertEqual(segment.work?.distanceM, 1000)
        XCTAssertEqual(segment.recovery?.durationSeconds, 90)
        XCTAssertEqual(segment.recovery?.recoveryType, "jog")
        // 編輯器沒有模型化的欄位同樣不可被洗掉
        XCTAssertEqual(run.targetIntensity, "threshold")
        XCTAssertEqual(run.heartRateRange?.min, 150)
        XCTAssertEqual(run.paceUnit, "min_per_km")
        // 距離沒改，顯示單位偏好就不該被丟掉
        XCTAssertEqual(run.distanceDisplay, 8)
        XCTAssertEqual(run.distanceUnit, "km")

        // 全欄位守恆：只有 pace 這一個欄位可以不同。
        // 同樣刻意不手列欄位 —— 日後新增的欄位自動納入保護。
        try assertOnlyExpectedFieldsChanged(
            submitted: submitted,
            original: weeklyPlan.days[1],
            allowedDifferingPaths: ["primary.pace"]
        )
    }

    // MARK: - 全欄位守恆斷言（model 驅動，非手列欄位）

    /// 「純搬移」的契約：送出的 DTO 除了 `day_index` 與**刻意剝除的氣候欄位**之外，
    /// 必須與後端原本給的那天**逐欄位相同**。
    ///
    /// 這裡刻意不手列欄位。手列是這個 bug 反覆復發的根本形狀 ——
    /// `bd1e4d48` 只補 climate、後來 isTrail / SegmentKind / work / recovery 各自
    /// 又開新破口，因為每次都只斷言「這次想到的那幾個」。
    ///
    /// 改為把兩份 DTO 各自 encode 成 JSON 後整份 deep-diff：**日後 DayDetailDTO 新增
    /// 任何欄位都自動納入保護**，沒有人需要記得回來補測試。
    ///
    /// `allowedDifferingPaths` 是唯一的白名單，且必須是**刻意的契約**：
    /// - `day_index`：搬移的定義本身
    /// - climate 系列：T-0165，氣候綁日期不綁課表，一律不上網路
    private func assertLosslessMove(
        submitted: DayDetailDTO,
        original: DayDetail,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try assertOnlyExpectedFieldsChanged(
            submitted: submitted,
            original: original,
            allowedDifferingPaths: [],
            file: file,
            line: line
        )
    }

    /// 通用的全欄位守恆斷言：送出的 DTO 除了白名單路徑外，必須與原始那天逐欄位相同。
    ///
    /// `day_index` 與 climate 系列（T-0165）是所有情境共通的刻意契約，故內建於基礎白名單；
    /// 呼叫端只需補上該情境**額外**允許改變的欄位（例如「使用者改了配速」）。
    private func assertOnlyExpectedFieldsChanged(
        submitted: DayDetailDTO,
        original: DayDetail,
        allowedDifferingPaths: Set<String>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let baseAllowed: Set<String> = [
            "day_index",
            "climate_meta",
            "primary.climate_meta",
            "primary.base_pace",
            "primary.climate_adjusted_pace",
        ]
        let allowed = baseAllowed.union(allowedDifferingPaths)

        let expected = try jsonObject(TrainingSessionMapper.toDTO(from: original))
        let actual = try jsonObject(submitted)

        let diffs = deepDiff(expected, actual, path: "")
            .filter { diff in
                !allowed.contains { diff.hasPrefix($0) }
            }

        XCTAssertTrue(
            diffs.isEmpty,
            "saving must not change any field outside the allowlist. Unexpected differences:\n"
                + diffs.joined(separator: "\n"),
            file: file,
            line: line
        )
    }

    private func jsonObject(_ dto: DayDetailDTO) throws -> [String: Any] {
        let data = try JSONEncoder().encode(dto)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// 回傳所有值不同的 JSON 路徑。缺 key 視為 null，因此「欄位被靜默丟掉」會被抓到。
    private func deepDiff(_ lhs: Any, _ rhs: Any, path: String) -> [String] {
        if let l = lhs as? [String: Any], let r = rhs as? [String: Any] {
            return Set(l.keys).union(r.keys).sorted().flatMap { key -> [String] in
                deepDiff(
                    l[key] ?? NSNull(),
                    r[key] ?? NSNull(),
                    path: path.isEmpty ? key : "\(path).\(key)"
                )
            }
        }
        if let l = lhs as? [Any], let r = rhs as? [Any] {
            guard l.count == r.count else {
                return ["\(path): array count \(l.count) != \(r.count)"]
            }
            return zip(l, r).enumerated().flatMap { index, pair in
                deepDiff(pair.0, pair.1, path: "\(path)[\(index)]")
            }
        }
        if lhs is NSNull && rhs is NSNull { return [] }
        if let l = lhs as? NSObject, let r = rhs as? NSObject, l.isEqual(r) { return [] }
        return ["\(path): expected \(lhs), got \(rhs)"]
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

    private func makeIntervalPlanWithWarmupCooldown(recoverySeconds: Int? = 70, recoveryMinutes: Int? = nil, recoveryKm: Double? = nil) -> WeeklyPlanV2 {
        let base = makeWeeklyPlan()
        let segment = RunSegment(
            distanceKm: 1.29,
            distanceM: nil,
            distanceDisplay: 1.29,
            distanceUnit: "km",
            durationMinutes: nil,
            durationSeconds: nil,
            pace: "8:27",
            basePace: nil,
            climateAdjustedPace: nil,
            climateMeta: nil,
            heartRateRange: nil,
            intensity: "easy",
            description: "Easy segment",
            kind: "steady",
            repeats: nil,
            work: nil,
            recovery: nil
        )
        let interval = IntervalBlock(
            repeats: 6,
            workDistanceKm: 0.2,
            workDistanceM: 200,
            workDistanceDisplay: 0.2,
            workDistanceUnit: "km",
            workPaceUnit: "min_per_km",
            workDurationMinutes: nil,
            workPace: "5:50",
            workDescription: "Fast 200m",
            recoveryDistanceKm: recoveryKm,
            recoveryDistanceM: nil,
            recoveryDurationMinutes: recoveryMinutes,
            recoveryPace: recoveryKm == nil ? nil : "6:00",
            recoveryDescription: "Rest 70 seconds",
            recoveryDurationSeconds: recoverySeconds,
            variant: "paceriz_interval:base_200m"
        )
        let runActivity = RunActivity(
            runType: "interval",
            distanceKm: 1.2,
            distanceDisplay: 1.2,
            distanceUnit: "km",
            paceUnit: "min_per_km",
            durationMinutes: nil,
            durationSeconds: nil,
            pace: "6:08",
            basePace: nil,
            climateAdjustedPace: nil,
            heartRateRange: nil,
            interval: interval,
            segments: nil,
            description: "Interval",
            targetIntensity: "hard",
            climateMeta: nil
        )
        let day = DayDetail(
            dayIndex: 1,
            dayTarget: "Interval",
            reason: "Speed development",
            tips: nil,
            category: .run,
            climateMeta: nil,
            session: TrainingSession(
                warmup: segment,
                primary: .run(runActivity),
                cooldown: segment,
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
            days: [day],
            climate: base.climate,
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
