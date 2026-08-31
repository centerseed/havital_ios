import XCTest
@testable import paceriz_dev

/// 英制（mi）切換後**里程**要跟著換算（T-0366）。
///
/// 修這一票之前：配速大多已接 `UnitManager`，里程卻十幾處寫死 `km`。症狀有兩種：
///
/// 1. **同一行兩種單位** —— 日卡「課表」那一行是 `8.0 km · 11:00/mi`
///    （距離公制、配速英制）。
/// 2. **同一個量兩個單位** —— 紀錄列的配速 VM 給 `8:51/mi`，View 卻先
///    `replacingOccurrences(of: "/km")`（英制剪不中）再貼一個 `/km`，
///    畫面上是 `8:51/mi/km`。
///
/// **為什麼要一個新檔**：既有的 imperial 覆蓋分散在各畫面自己的投影測試裡
/// （`App2WorkoutDetailProjectionTests` 的距離磚與配速磚、
/// `App2SessionDetailProjectionTests` 的配速帶），**沒有一份擁有跨畫面的
/// 「單位制」這條行為**，成就進度與賽距標籤更是誰都沒管。那幾支仍留在原地
/// （本檔不重測它們），這裡只放它們沒有的：`UnitSystem` 這個共同來源本身、
/// 日卡課表行、紀錄列的形狀、成就進度、賽距 fallback。
///
/// 係數只有一份（`UnitSystem.convertedDistance` ×0.621371 /
/// `convertedPaceSeconds` ×1.60934）；下面每個期望值都由它算得出來。
@MainActor
final class App2ImperialDistanceTests: XCTestCase {

    // MARK: - Helpers

    private func day(_ json: String) throws -> DayDetail {
        TrainingSessionMapper.toEntity(
            from: try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        )
    }

    /// 單段輕鬆跑：8.0 km @ `6:50`／km。
    /// 英制：`8.0 × 0.621371 = 4.97` → `5.0 mi`；`410 × 1.60934 = 659.8` → 660 秒 ＝ `11:00`／mi。
    private let easyRunDay = """
    { "day_index": 2, "day_target": "輕鬆跑", "reason": "有氧維持", "distance_km": 8.0,
      "primary": { "run_type": "easy", "distance_km": 8.0, "pace": "6:50",
                   "duration_minutes": 55, "target_intensity": "low",
                   "description": "輕鬆跑" } }
    """

    /// 間歇：4 × 400m，組間 200m。主課段總量 ＝ 1.6 + 3×0.2 ＝ 2.2 km。
    /// 英制 ＝ `2.2 × 0.621371 = 1.367` → `1.4 mi`。
    private let intervalOnlyDay = """
    { "day_index": 3, "day_target": "間歇", "reason": "速耐力", "distance_km": 5.2,
      "warmup": { "distance_km": 2.0, "pace": "7:00" },
      "cooldown": { "distance_km": 1.0, "pace": "7:00" },
      "primary": { "run_type": "interval", "distance_km": 2.2, "target_intensity": "high",
        "interval": { "repeats": 4,
                      "work_distance_m": 400, "work_pace": "4:50",
                      "recovery_distance_m": 200, "recovery_pace": "7:30" } } }
    """

    // MARK: - 換算的唯一來源

    func test_unitSystem_convertedDistance_imperialIsMiles() {
        XCTAssertEqual(UnitSystem.metric.convertedDistance(10), 10, accuracy: 0.0001)
        XCTAssertEqual(UnitSystem.imperial.convertedDistance(10), 6.21371, accuracy: 0.0001)
    }

    func test_unitSystem_formatDistance_carriesTheMatchingSuffix() {
        XCTAssertEqual(UnitSystem.metric.formatDistance(12.05), "12.1 km")
        XCTAssertEqual(UnitSystem.imperial.formatDistance(12.05), "7.5 mi")
    }

    /// 缺陷 5 的形狀：**值本身不得帶單位**，單位由 `paceSuffix`／`distanceSuffix` 給。
    /// 值與單位分兩個 `Text` 畫的版面（紀錄列）就是靠這條才不必做字串剪貼。
    func test_unitSystem_paceValue_carriesNoUnitSoViewCannotDoubleAppend() {
        XCTAssertEqual(UnitSystem.imperial.paceValue(secondsPerKm: 330), "8:51")
        XCTAssertFalse(UnitSystem.imperial.paceValue(secondsPerKm: 330).contains("/"))
        let composed = UnitSystem.imperial.paceValue(secondsPerKm: 330)
            + UnitSystem.imperial.paceSuffix
        XCTAssertEqual(composed, "8:51/mi")
        XCTAssertEqual(composed.filter { $0 == "/" }.count, 1, "英制配速不得變成 `8:51/mi/km`")
        XCTAssertEqual(UnitSystem.imperial.formatPace(secondsPerKm: 330), composed)
    }

    /// 後端給的是每公里 `mm:ss` 字串；解析不出來就原樣回傳，不猜也不硬接單位。
    func test_unitSystem_formatPaceString_parsesBackendPerKmString() {
        XCTAssertEqual(UnitSystem.metric.formatPaceString("6:50"), "6:50/km")
        XCTAssertEqual(UnitSystem.imperial.formatPaceString("6:50"), "11:00/mi")
        XCTAssertEqual(UnitSystem.imperial.formatPaceString("6:50/km"), "6:50/km")
        XCTAssertEqual(UnitSystem.imperial.formatPaceString(nil), "--:--/mi")
    }

    // MARK: - 切換當下要重投影（外審 B07／E03）

    /// **`@Published` 救不了已經組好的字串**。課表日卡的「課表」行、詳情頁的配速帶、
    /// 目標卡的賽距都是投影時就格式化好存進 model 的，View 再怎麼觀察 `UnitManager`
    /// 也只是把同一份舊字重畫一次。所以切換要發 `unitSystemChanged`，VM 收到才重投影。
    ///
    /// **值沒真的變就不發**：登入時同步偏好會寫一次同樣的值，不該白白觸發一輪重投影。
    func test_unitManagerPublishesUnitSystemChanged_onlyOnRealChange() async {
        let manager = UnitManager.shared
        let original = manager.currentUnitSystem
        defer { manager.currentUnitSystem = original }

        let identifier = "App2ImperialDistanceTests.unitChange"
        var received = 0
        CacheEventBus.shared.subscribe(forIdentifier: identifier) { reason in
            if case .unitSystemChanged = reason { received += 1 }
        }
        defer { CacheEventBus.shared.unsubscribe(forIdentifier: identifier) }

        // `publish` 的訂閱者通知走 `Task { @MainActor }`，要讓它跑完才看得到。
        func settle() async {
            for _ in 0..<50 {
                await Task.yield()
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
        }

        manager.currentUnitSystem = original == .metric ? .imperial : .metric
        await settle()
        XCTAssertEqual(received, 1)

        // 同一個值再寫一次 —— 不得再發一次。
        let current = manager.currentUnitSystem
        manager.currentUnitSystem = current
        await settle()
        XCTAssertEqual(received, 1, "值沒變不得觸發重投影")
    }

    /// 這個事件**不清任何快取**：資料沒變，變的是要用哪個單位畫。
    func test_unitSystemChanged_doesNotInvalidateCaches() {
        final class Probe: Cacheable {
            let cacheIdentifier = "App2ImperialDistanceTests.probe"
            private(set) var cleared = false
            func clearCache() { cleared = true }
            func getCacheSize() -> Int { 0 }
            func isExpired() -> Bool { false }
        }
        let probe = Probe()
        CacheEventBus.shared.register(probe)
        CacheEventBus.shared.invalidateCache(for: .unitSystemChanged)
        XCTAssertFalse(probe.cleared, "單位切換不得順手清掉別人的快取")
    }

    // MARK: - 缺陷 1／2：日卡「課表」那一行（Home ＋ Plan 共用）

    func test_contentLine_imperial_distanceAndPaceUseTheSameUnit() throws {
        let primary = try day(easyRunDay).session?.primary
        XCTAssertEqual(
            App2PlanViewModel.contentLine(primary, totalDistanceKm: 8.0, unitSystem: .metric),
            "8.0 km · 6:50/km"
        )
        // 修前這一行是 `8.0 km · 11:00/mi` —— 距離寫死公制、配速已換算。
        XCTAssertEqual(
            App2PlanViewModel.contentLine(primary, totalDistanceKm: 8.0, unitSystem: .imperial),
            "5.0 mi · 11:00/mi"
        )
    }

    func test_intervalContentLine_imperial_convertsMainSetDistance() throws {
        let primary = try day(intervalOnlyDay).session?.primary
        XCTAssertEqual(
            App2PlanViewModel.contentLine(primary, unitSystem: .metric)?.hasPrefix("2.2 km"),
            true
        )
        XCTAssertEqual(
            App2PlanViewModel.contentLine(primary, unitSystem: .imperial)?.hasPrefix("1.4 mi"),
            true
        )
    }

    // MARK: - 缺陷 4／5：訓練紀錄頁

    /// 紀錄列帶的是**原始量**，不是已格式化的字串 —— 缺陷 5 的結構性防線：
    /// View 手上沒有帶單位的字串，剪不掉也貼不重。
    func test_workoutRow_carriesRawValues_notPreformattedStrings() {
        let rows = App2StubFixtures.records.recentWorkouts
        XCTAssertFalse(rows.isEmpty)
        for row in rows {
            XCTAssertGreaterThan(row.distanceKm, 0)
            XCTAssertNotNil(row.paceSecondsPerKm)
        }
        guard let first = rows.first, let seconds = first.paceSecondsPerKm else {
            return XCTFail("樣本資料要帶得出距離與配速")
        }
        // View 就是這樣組的：值 ＋ 單位各一個 `Text`，兩者同一個 `UnitSystem`。
        XCTAssertEqual(
            App2RecordsView.grouped(UnitSystem.imperial.convertedDistance(first.distanceKm)),
            App2RecordsView.grouped(first.distanceKm * 0.621371)
        )
        XCTAssertEqual(UnitSystem.imperial.distanceSuffix, "mi")
        let paceCell = UnitSystem.imperial.paceValue(secondsPerKm: seconds)
            + UnitSystem.imperial.paceSuffix
        XCTAssertEqual(paceCell.filter { $0 == "/" }.count, 1)
    }

    /// 分組小計（`record.group.total_distance_format` 的 `%@`）。
    func test_recordsGroupSubtotal_imperial() {
        XCTAssertEqual(UnitSystem.metric.formatDistance(42.3), "42.3 km")
        XCTAssertEqual(UnitSystem.imperial.formatDistance(42.3), "26.3 mi")
    }

    func test_monthComparison_imperial_convertsTheDelta() {
        XCTAssertEqual(App2RecordsView.monthComparison(18.0, unit: .metric)?.contains("+18"), true)
        // 18 km ＝ 11.18 mi → `+11.2`。
        XCTAssertEqual(App2RecordsView.monthComparison(18.0, unit: .imperial)?.contains("+11.2"), true)
        XCTAssertNil(App2RecordsView.monthComparison(nil, unit: .imperial))
    }

    // MARK: - 缺陷 6：成就目標進度

    /// 後端 `unit_key` 只有 `…unit.km` 是距離
    /// （`domains/achievements/badge_projector.py:869-875` 只產出 km／week／count）；
    /// 週數與次數不是量，不得換算。
    func test_achievementProgress_convertsOnlyDistanceUnitKey() {
        let distance = App2AchievementsView.convertProgress(
            current: 1_141.5, target: 2_400,
            unitKey: "achievements.progress.unit.km", unitSystem: .imperial
        )
        XCTAssertEqual(distance.current, 1_141.5 * 0.621371, accuracy: 0.001)
        XCTAssertEqual(distance.target, 2_400 * 0.621371, accuracy: 0.001)
        XCTAssertEqual(distance.unitKey, "achievements.progress.unit.mi")

        let weeks = App2AchievementsView.convertProgress(
            current: 6, target: 12,
            unitKey: "achievements.progress.unit.week", unitSystem: .imperial
        )
        XCTAssertEqual(weeks.current, 6)
        XCTAssertEqual(weeks.target, 12)
        XCTAssertEqual(weeks.unitKey, "achievements.progress.unit.week")

        let counts = App2AchievementsView.convertProgress(
            current: 3, target: 10,
            unitKey: "achievements.progress.unit.count", unitSystem: .imperial
        )
        XCTAssertEqual(counts.current, 3)
        XCTAssertEqual(counts.unitKey, "achievements.progress.unit.count")

        // 公制一律原樣通過；沒有 `unit_key` 的也是。
        let metric = App2AchievementsView.convertProgress(
            current: 1_141.5, target: 2_400,
            unitKey: "achievements.progress.unit.km", unitSystem: .metric
        )
        XCTAssertEqual(metric.current, 1_141.5)
        XCTAssertEqual(metric.unitKey, "achievements.progress.unit.km")
        XCTAssertNil(
            App2AchievementsView.convertProgress(
                current: 1, target: 2, unitKey: nil, unitSystem: .imperial
            ).unitKey
        )
    }

    /// 英制的單位字三語都要有，否則畫面上會露出 key 或空字串。
    func test_achievementImperialUnitKey_isLocalizedInAllThreeLanguages() {
        for lang in ["zh-Hant", "en", "ja"] {
            guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
                  let bundle = Bundle(path: path) else {
                return XCTFail("\(lang).lproj 不在 bundle 裡")
            }
            let value = bundle.localizedString(
                forKey: "achievements.progress.unit.mi", value: nil, table: nil
            )
            XCTAssertNotEqual(value, "achievements.progress.unit.mi", "\(lang) 缺英里單位字")
            XCTAssertFalse(value.isEmpty)
        }
    }

    // MARK: - 缺陷 8：賽距標籤

    /// **標準賽距是名字不是量**：全馬在英制仍然是「全馬」，不變成 `26.2 mi`。
    func test_distanceLabel_standardRacesAreNamesNotQuantities() {
        XCTAssertEqual(
            App2OnboardingFormat.distanceLabel(km: 42.195, unitSystem: .imperial),
            App2OnboardingFormat.distanceLabel(km: 42.195, unitSystem: .metric)
        )
        XCTAssertEqual(
            App2OnboardingFormat.distanceLabel(km: 21.0975, unitSystem: .imperial),
            App2OnboardingFormat.distanceLabel(km: 21.0975, unitSystem: .metric)
        )
    }

    func test_distanceLabel_nonStandardDistanceFollowsUnitSystem() {
        XCTAssertEqual(App2OnboardingFormat.distanceLabel(km: 12, unitSystem: .metric), "12 km")
        // 12 × 0.621371 ＝ 7.456 → `7.5 mi`（不是 `%g` 的 `7.45645 mi`）。
        XCTAssertEqual(App2OnboardingFormat.distanceLabel(km: 12, unitSystem: .imperial), "7.5 mi")
    }
}
