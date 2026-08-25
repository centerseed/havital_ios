import XCTest
@testable import paceriz_dev

/// 紀錄頁：月量／月比投影 ＋ SWR 載入語意（`App2Revalidating`）。
///
/// SWR 用 `App2RecordsViewModel` 當代表（它的依賴只有一個兩方法的 protocol，
/// 是四個 2.0 ViewModel 裡最能單獨立起來的一個）。鎖住的是：
/// 首載會打、60 秒內不重打、超過門檻重打、下拉刷新無視門檻、重驗失敗保留舊資料。
@MainActor
final class App2RecordsViewModelTests: XCTestCase {

    // MARK: - Fake

    private final class FakeStatsSource: WorkoutStatsDataSourceProtocol {
        var statsJSON = """
        { "data": { "total_workouts": 3, "total_distance_km": 30.0,
                    "provider_distribution": {}, "activity_type_distribution": {},
                    "period_days": 30,
                    "weekly_series": [ { "week_start": "2026-08-17", "week_end": "2026-08-23",
                                         "distance_km": 12.5, "is_current_week": false } ],
                    "year_to_date": { "year": 2026, "start_date": "2026-01-01",
                                      "through_date": "2026-08-25",
                                      "distance_km": 530.0, "workout_count": 61 } } }
        """
        var workouts: [WorkoutV2] = []
        var statsError: Error?
        private(set) var statsCallCount = 0

        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            statsCallCount += 1
            if let statsError { throw statsError }
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(statsJSON.utf8))
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] {
            workouts
        }
    }

    // MARK: - Helpers

    /// 這個月的第 n 天中午（避免測試在月初／月底跨月飄動）。
    private func dayOfThisMonth(_ day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? Date()
    }

    private func run(id: String, at date: Date, km: Double, type: String = "running") -> WorkoutV2 {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return WorkoutV2(
            id: id, provider: "garmin", activityType: type,
            startTimeUtc: formatter.string(from: date), endTimeUtc: nil,
            durationSeconds: 3000, distanceMeters: km * 1000,
            distanceDisplay: nil, distanceUnit: nil, deviceName: nil,
            basicMetrics: nil, advancedMetrics: nil, createdAt: nil,
            schemaVersion: nil, storagePath: nil, dailyPlanSummary: nil,
            aiSummary: nil, shareCardContent: nil
        )
    }

    // MARK: - 月量與月比

    func test_monthlyTotals_emptyHistory_isZeroWithNoDelta() {
        let totals = App2RecordsViewModel.monthlyTotals([])
        XCTAssertEqual(totals.distanceKm, 0)
        XCTAssertEqual(totals.workouts, 0)
        // 一筆都沒有 ＝ 已經看完全部 → 上月也是 0，差為 0（不是「不知道」）。
        XCTAssertEqual(totals.deltaKm, 0)
    }

    func test_monthlyTotals_sumsThisMonthAndComparesToLastMonth() throws {
        let calendar = Calendar.current
        let thisMonth = dayOfThisMonth(1)
        let lastMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: thisMonth))

        let totals = App2RecordsViewModel.monthlyTotals([
            run(id: "a", at: thisMonth, km: 10),
            run(id: "b", at: thisMonth, km: 8),
            run(id: "c", at: lastMonth, km: 12)
        ])
        XCTAssertEqual(totals.distanceKm, 18, accuracy: 0.001)
        XCTAssertEqual(totals.workouts, 2)
        XCTAssertEqual(try XCTUnwrap(totals.deltaKm), 6, accuracy: 0.001)
    }

    /// 非跑步的活動不計入跑量。
    func test_monthlyTotals_ignoresNonRunActivities() {
        let totals = App2RecordsViewModel.monthlyTotals([
            run(id: "a", at: dayOfThisMonth(2), km: 10),
            run(id: "b", at: dayOfThisMonth(3), km: 30, type: "cycling")
        ])
        XCTAssertEqual(totals.distanceKm, 10, accuracy: 0.001)
        XCTAssertEqual(totals.workouts, 1)
    }

    /// 沒有 `start_time_utc` 的紀錄直接略過，不 crash、不算進任何一個月。
    func test_monthlyTotals_skipsWorkoutsWithoutStartTime() {
        let broken = WorkoutV2(
            id: "x", provider: "garmin", activityType: "running",
            startTimeUtc: nil, endTimeUtc: nil, durationSeconds: 100,
            distanceMeters: 99_000, distanceDisplay: nil, distanceUnit: nil,
            deviceName: nil, basicMetrics: nil, advancedMetrics: nil,
            createdAt: nil, schemaVersion: nil, storagePath: nil,
            dailyPlanSummary: nil, aiSummary: nil, shareCardContent: nil
        )
        let totals = App2RecordsViewModel.monthlyTotals([broken])
        XCTAssertEqual(totals.distanceKm, 0)
        XCTAssertEqual(totals.workouts, 0)
    }

    // MARK: - 分組／小計／篩選（設計 frame-10 的 recTabs 與 g.group/g.count/g.sum）

    /// 固定一個週三中午當「現在」，讓分組邊界不隨執行日飄動。
    private var fixedNow: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 26      // 週三
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date()
    }

    private func item(
        id: String,
        daysBeforeNow: Int,
        km: Double?,
        type: DayType? = nil
    ) -> App2RecordItem {
        let date = Calendar.current.date(byAdding: .day, value: -daysBeforeNow, to: fixedNow)
        return App2RecordItem(
            row: App2WorkoutRow(
                id: id,
                dateLabel: "8/\(26 - daysBeforeNow)",
                tag: type?.localizedName,
                dayType: type,
                distance: km.map { String(format: "%.1f km", $0) } ?? "—",
                pace: nil,
                duration: "30:00",
                vdot: nil
            ),
            date: date,
            distanceKm: km,
            whenLabel: "—",
            // 分組／小計不看原始紀錄，這裡不需要它。
            workout: nil
        )
    }

    func test_groups_splitsTodayYesterdayThisWeekAndLastWeek() {
        let groups = App2RecordsViewModel.groups(
            [
                item(id: "today", daysBeforeNow: 0, km: 5),
                item(id: "yesterday", daysBeforeNow: 1, km: 6),
                item(id: "earlier", daysBeforeNow: 2, km: 7),   // 週一，仍在本週
                item(id: "lastweek", daysBeforeNow: 8, km: 8)
            ],
            now: fixedNow
        )

        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(groups[0].items.map(\.id), ["today"])
        XCTAssertEqual(groups[1].items.map(\.id), ["yesterday"])
        XCTAssertEqual(groups[2].items.map(\.id), ["earlier"])
        XCTAssertEqual(groups[3].items.map(\.id), ["lastweek"])
        XCTAssertEqual(groups[0].title, L10n.Record.Group.today.localized)
        XCTAssertEqual(groups[1].title, L10n.Record.Group.yesterday.localized)
        XCTAssertEqual(groups[2].title, L10n.Record.Group.earlierThisWeek.localized)
        XCTAssertEqual(groups[3].title, L10n.Record.Group.lastWeek.localized)
    }

    /// 更早的紀錄按月分桶：同一個月一定落在同一組（月初當 key，已正規化）。
    func test_groups_bucketsOlderRecordsByMonth() {
        let groups = App2RecordsViewModel.groups(
            [
                item(id: "jun-a", daysBeforeNow: 70, km: 5),
                item(id: "jun-b", daysBeforeNow: 80, km: 5),
                item(id: "jul", daysBeforeNow: 45, km: 5)
            ],
            now: fixedNow
        )

        XCTAssertEqual(groups.count, 2, "6 月兩筆要合成同一組")
        XCTAssertEqual(groups[0].items.map(\.id), ["jul"])          // 新的在前
        XCTAssertEqual(groups[1].items.map(\.id), ["jun-a", "jun-b"])
    }

    func test_groups_subtotalSumsDistanceAndCount() {
        let groups = App2RecordsViewModel.groups(
            [
                item(id: "a", daysBeforeNow: 0, km: 5.5),
                item(id: "b", daysBeforeNow: 0, km: 4.5)
            ],
            now: fixedNow
        )

        let today = groups.first
        XCTAssertEqual(today?.count, 2)
        XCTAssertEqual(today?.totalKm ?? 0, 10, accuracy: 0.001)
    }

    /// 沒有距離的紀錄（樣本）不計入小計，也不讓小計變成 0 以外的假數字。
    func test_groups_subtotalIgnoresUnknownDistance() {
        let groups = App2RecordsViewModel.groups(
            [item(id: "a", daysBeforeNow: 0, km: nil)],
            now: fixedNow
        )
        XCTAssertEqual(groups.first?.count, 1)
        XCTAssertEqual(groups.first?.totalKm ?? -1, 0, accuracy: 0.001)
    }

    /// chip 只列出資料裡真的存在的課型 —— 沒有間歇就沒有間歇 chip。
    func test_filters_onlyIncludeTypesPresentInData() {
        let filters = App2RecordsViewModel.filters(for: [
            item(id: "a", daysBeforeNow: 0, km: 5, type: .easy),
            item(id: "b", daysBeforeNow: 1, km: 5, type: .longRun)
        ])

        XCTAssertEqual(filters.first?.id, "all")
        let labels = filters.map(\.label)
        XCTAssertTrue(labels.contains(DayType.easy.localizedName))
        XCTAssertTrue(labels.contains(DayType.longRun.localizedName))
        XCTAssertFalse(labels.contains(DayType.interval.localizedName), "資料裡沒有間歇就不該出現 chip")
    }

    /// 同顯示名的多個 raw value（`easy` / `easy_run`）合成一顆 chip，不重複兩顆。
    func test_filters_mergesTypesSharingTheSameLabel() {
        let filters = App2RecordsViewModel.filters(for: [
            item(id: "a", daysBeforeNow: 0, km: 5, type: .easy),
            item(id: "b", daysBeforeNow: 1, km: 5, type: .easyRun),
            item(id: "c", daysBeforeNow: 2, km: 5, type: .interval)
        ])

        XCTAssertEqual(filters.count, 3, "全部 ＋ 輕鬆跑 ＋ 間歇")
        let easyFilter = filters.first { $0.label == DayType.easy.localizedName }
        XCTAssertEqual(easyFilter?.types, [.easy, .easyRun])
    }

    /// 只有一種課型時整列 chip 沒有作用 → 不出現。
    func test_filters_singleTypeProducesNoChips() {
        let filters = App2RecordsViewModel.filters(for: [
            item(id: "a", daysBeforeNow: 0, km: 5, type: .easy)
        ])
        XCTAssertTrue(filters.isEmpty)
    }

    func test_filtered_keepsOnlySelectedTypes() throws {
        let items = [
            item(id: "easy", daysBeforeNow: 0, km: 5, type: .easy),
            item(id: "easyRun", daysBeforeNow: 1, km: 5, type: .easyRun),
            item(id: "interval", daysBeforeNow: 2, km: 5, type: .interval),
            item(id: "untyped", daysBeforeNow: 3, km: 5, type: nil)
        ]
        let filters = App2RecordsViewModel.filters(for: items)
        let easyFilter = try XCTUnwrap(filters.first { $0.label == DayType.easy.localizedName })

        XCTAssertEqual(
            App2RecordsViewModel.filtered(items, by: easyFilter).map(\.id),
            ["easy", "easyRun"]
        )
        // 「全部」不過濾，沒有課型的那一筆仍在。
        XCTAssertEqual(App2RecordsViewModel.filtered(items, by: App2RecordFilter.all).count, 4)
        XCTAssertEqual(App2RecordsViewModel.filtered(items, by: nil).count, 4)
    }

    // MARK: - 相對日期（設計 r.when）

    /// 今天的紀錄顯示「今天 HH:mm」，幾天前的顯示「N 天前」—— 兩者不同、且只有
    /// 今天那一筆帶時間。走既有的 `DateFormatterHelper`，不另做一份格式。
    func test_load_usesRelativeWhenLabels() async throws {
        let source = FakeStatsSource()
        source.workouts = [
            run(id: "today", at: Date().addingTimeInterval(-3600), km: 5),
            run(id: "old", at: Date().addingTimeInterval(-3 * 86_400), km: 5)
        ]
        let vm = App2RecordsViewModel(workoutDataSource: source)

        await vm.loadIfNeeded()

        XCTAssertEqual(vm.items.count, 2)
        let todayLabel = try XCTUnwrap(vm.items.first { $0.id == "today" }?.whenLabel)
        let oldLabel = try XCTUnwrap(vm.items.first { $0.id == "old" }?.whenLabel)
        XCTAssertNotEqual(todayLabel, oldLabel)
        XCTAssertTrue(todayLabel.contains(":"), "今天那一筆要帶時間：\(todayLabel)")
        XCTAssertFalse(oldLabel.contains(":"), "「N 天前」不帶時間：\(oldLabel)")
    }

    // MARK: - 載入與 SWR

    func test_load_mapsStatsAndMonthlyTotals() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "a", at: dayOfThisMonth(4), km: 7)]
        let vm = App2RecordsViewModel(workoutDataSource: source)

        await vm.loadIfNeeded()

        let records = try XCTUnwrap(vm.records)
        XCTAssertEqual(records.value.ytdDistanceKm, 530)
        XCTAssertEqual(records.value.ytdWorkouts, 61)
        XCTAssertEqual(records.value.weeklySeries.count, 1)
        XCTAssertEqual(records.value.weeklySeries.first?.shortLabel, "8/17")
        XCTAssertEqual(records.value.monthDistanceKm, 7, accuracy: 0.001)
        XCTAssertFalse(records.origin.isStub)
        XCTAssertTrue(vm.hasLoaded)
        XCTAssertFalse(vm.isLoading)
    }

    func test_loadIfNeeded_withinStaleWindow_doesNotRefetch() async {
        let source = FakeStatsSource()
        let vm = App2RecordsViewModel(workoutDataSource: source)

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()
        await vm.loadIfNeeded()

        XCTAssertEqual(source.statsCallCount, 1)
    }

    func test_loadIfNeeded_pastStaleWindow_refetches() async {
        let source = FakeStatsSource()
        let vm = App2RecordsViewModel(workoutDataSource: source)

        await vm.loadIfNeeded()
        // 門檻是參數，不用真的等 60 秒。
        await vm.loadIfNeeded(staleAfter: -1)

        XCTAssertEqual(source.statsCallCount, 2)
    }

    func test_forceRefresh_ignoresStaleWindow() async {
        let source = FakeStatsSource()
        let vm = App2RecordsViewModel(workoutDataSource: source)

        await vm.loadIfNeeded()
        await vm.forceRefresh()

        XCTAssertEqual(source.statsCallCount, 2)
        XCTAssertFalse(vm.isLoading)
    }

    /// 重驗失敗保留舊資料 —— 不清畫面、也不換成樣本。
    func test_revalidateFailure_keepsPreviousData() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "a", at: dayOfThisMonth(4), km: 7)]
        let vm = App2RecordsViewModel(workoutDataSource: source)
        await vm.loadIfNeeded()
        let before = try XCTUnwrap(vm.records?.value)

        source.statsError = URLError(.timedOut)
        await vm.forceRefresh()

        XCTAssertEqual(vm.records?.value, before)
        XCTAssertFalse(vm.records?.origin.isStub ?? true)
    }

    /// **取消不是失敗。** 下拉刷新時 SwiftUI 收掉 refresh task，in-flight 請求
    /// 全部回 `-999`；當成失敗會把畫面上的真資料換成樣本
    /// （2026-08-25 在模擬器上實際看到：下拉一次，指標列從 live 變成「樣本 offline」）。
    func test_cancellationDuringRevalidate_keepsLiveData() async throws {
        let source = FakeStatsSource()
        source.workouts = [run(id: "a", at: dayOfThisMonth(4), km: 7)]
        let vm = App2RecordsViewModel(workoutDataSource: source)
        await vm.loadIfNeeded()
        let before = try XCTUnwrap(vm.records?.value)

        source.statsError = URLError(.cancelled)
        await vm.forceRefresh()

        XCTAssertEqual(vm.records?.value, before)
        XCTAssertFalse(vm.records?.origin.isStub ?? true, "取消後不得退樣本")
    }

    /// 首載被取消 → 保持沒有資料，也不假裝有（不退樣本）。
    func test_cancellationOnFirstLoad_doesNotFallBackToStub() async {
        let source = FakeStatsSource()
        source.statsError = URLError(.cancelled)
        let vm = App2RecordsViewModel(workoutDataSource: source)

        await vm.loadIfNeeded()

        XCTAssertNil(vm.records)
        XCTAssertFalse(vm.isLoading)
    }

    /// 從沒載成功過就失敗 → 退樣本並掛徽章。
    func test_firstLoadFailure_fallsBackToStub() async {
        let source = FakeStatsSource()
        source.statsError = URLError(.notConnectedToInternet)
        let vm = App2RecordsViewModel(workoutDataSource: source)

        await vm.loadIfNeeded()

        XCTAssertTrue(vm.records?.origin.isStub ?? false)
        XCTAssertFalse(vm.isLoading)
    }
}
