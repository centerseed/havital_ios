import XCTest
@testable import paceriz_dev

/// 指標詳情 session 快取（T-0357）：VM 隨 push 重建，快取命中必須立即出畫面
/// （不打網路、不出 spinner）；revalidate 成功回寫快取。
@MainActor
final class App2MetricDetailCacheTests: XCTestCase {

    // MARK: - Stubs

    /// 被叫到就記錄——快取命中路徑不得打網路。
    private final class CountingStatsSource: WorkoutStatsDataSourceProtocol {
        var statsCalls = 0

        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            statsCalls += 1
            return try Self.statsFixture()
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }

        static func statsFixture() throws -> WorkoutStatsResponse {
            let json = """
            { "data": { "total_workouts": 3, "total_distance_km": 21.0,
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30 } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }
    }

    private final class EmptyHealthSource: HealthDailyDataSourceProtocol {
        func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
            try Self.fixture()
        }

        static func fixture() throws -> HealthDailyResponse {
            try JSONDecoder().decode(
                HealthDailyResponse.self,
                from: Data(#"{ "health_data": [], "count": 0, "limit": 28 }"#.utf8)
            )
        }
    }

    private final class EmptyVdotSource: VDOTDataSourceProtocol {
        func getVDOTs(limit: Int) async throws -> VDOTResponse {
            try Self.fixture()
        }

        static func fixture() throws -> VDOTResponse {
            try JSONDecoder().decode(
                VDOTResponse.self,
                from: Data(#"{ "need_updated_hr_range": false, "vdots": [] }"#.utf8)
            )
        }
    }

    /// 可控時點的 stats 來源：每一發都掛在 continuation 上，測試自己決定誰先回。
    /// 回應帶指紋（`total_distance_km` ＝ 該發要的 `weeks`），才驗得出「哪一發的
    /// 回應落到哪一個 range key」。
    private final class GatedStatsSource: WorkoutStatsDataSourceProtocol {
        var requestedWeeks: [Int] = []
        var continuations: [CheckedContinuation<Void, Never>] = []
        private var released = 0

        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            let requested = weeks ?? 0
            // 帳本只在 MainActor 上動，測試（也在 MainActor）讀到的順序才是確定的。
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Task { @MainActor in
                    self.requestedWeeks.append(requested)
                    self.continuations.append(continuation)
                }
            }
            return try Self.fixture(totalDistanceKm: Double(requested))
        }

        func releaseNext() {
            guard released < continuations.count else { return }
            continuations[released].resume()
            released += 1
        }

        func releaseAll() {
            while released < continuations.count { releaseNext() }
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }

        static func fixture(totalDistanceKm: Double) throws -> WorkoutStatsResponse {
            let json = """
            { "data": { "total_workouts": 1, "total_distance_km": \(totalDistanceKm),
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30 } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }
    }

    /// 同上，能力基準版（指紋是 `limit`，只需驗落到哪一個 key）。
    private final class GatedVdotSource: VDOTDataSourceProtocol {
        var requestedLimits: [Int] = []
        var continuations: [CheckedContinuation<Void, Never>] = []
        private var released = 0

        func getVDOTs(limit: Int) async throws -> VDOTResponse {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Task { @MainActor in
                    self.requestedLimits.append(limit)
                    self.continuations.append(continuation)
                }
            }
            return try EmptyVdotSource.fixture()
        }

        func releaseNext() {
            guard released < continuations.count else { return }
            continuations[released].resume()
            released += 1
        }

        func releaseAll() {
            while released < continuations.count { releaseNext() }
        }
    }

    /// 同上，恢復版。
    private final class GatedHealthSource: HealthDailyDataSourceProtocol {
        var calls = 0
        var continuations: [CheckedContinuation<Void, Never>] = []
        private var released = 0

        func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Task { @MainActor in
                    self.calls += 1
                    self.continuations.append(continuation)
                }
            }
            return try EmptyHealthSource.fixture()
        }

        func releaseAll() {
            while released < continuations.count {
                continuations[released].resume()
                released += 1
            }
        }
    }

    private final class ThrowingStatsSource: WorkoutStatsDataSourceProtocol {
        let error: Error

        init(error: Error) { self.error = error }

        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            throw error
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }
    }

    private func insight(_ id: String) -> App2Insight {
        App2Insight(id: id, label: id, value: nil, direction: .unknown, verdict: nil)
    }

    /// 等一個條件成立（最多 5 秒）。不用 expectation：這裡等的是 in-flight 的
    /// 非同步輪，沒有可掛 fulfill 的回撥點。
    private static func waitUntil(
        timeout: TimeInterval = 5,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    // MARK: - 快取命中：init 立即出畫面、不打網路

    func test_volumeVM_cacheHit_paintsImmediately_withoutNetwork() throws {
        let cache = App2MetricDetailCache()
        cache.storeVolume(
            App2MetricDetailCache.VolumePayload(
                stats: try CountingStatsSource.statsFixture(),
                health: nil,
                targetKm: 30
            ),
            range: .weeks8,
            loadedAt: Date(timeIntervalSinceNow: -10)
        )
        let source = CountingStatsSource()

        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"),
            narrative: nil,
            workoutDataSource: source,
            healthDataSource: EmptyHealthSource(),
            profileRepository: nil,
            cache: cache
        )

        XCTAssertNotNil(vm.detail, "快取命中必須在 init 立即出畫面")
        XCTAssertFalse(vm.isLoading, "快取命中不得出全頁 spinner")
        XCTAssertTrue(vm.hasLoaded)
        XCTAssertEqual(source.statsCalls, 0, "init 的快取命中路徑不得打網路")
    }

    func test_capabilityVM_cacheHit_paintsImmediately() throws {
        let cache = App2MetricDetailCache()
        cache.storeCapability(try EmptyVdotSource.fixture(), range: .days60)

        let vm = App2CapabilityDetailViewModel(
            insight: insight("capability"),
            narrative: nil,
            vdotDataSource: EmptyVdotSource(),
            cache: cache
        )

        XCTAssertNotNil(vm.detail)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.hasLoaded)
    }

    func test_recoveryVM_cacheHit_paintsImmediately() throws {
        let cache = App2MetricDetailCache()
        cache.storeRecovery(try EmptyHealthSource.fixture())

        let vm = App2RecoveryDetailViewModel(
            insight: insight("recovery"),
            narrative: nil,
            healthDataSource: EmptyHealthSource(),
            cache: cache
        )

        XCTAssertNotNil(vm.detail)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.hasLoaded)
    }

    // MARK: - 快取未命中：行為不變（spinner → 資料），成功回寫

    func test_volumeVM_cacheMiss_revalidateStoresEntry() async throws {
        let cache = App2MetricDetailCache()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"),
            narrative: nil,
            workoutDataSource: CountingStatsSource(),
            healthDataSource: EmptyHealthSource(),
            profileRepository: nil,
            cache: cache
        )

        XCTAssertNil(vm.detail, "快取未命中時 init 不得憑空出資料")
        XCTAssertTrue(vm.isLoading)

        await vm.revalidate()

        XCTAssertNotNil(vm.detail)
        XCTAssertNotNil(cache.volume[.weeks8], "revalidate 成功必須回寫快取")
    }

    func test_capabilityVM_revalidate_storesEntryPerRange() async throws {
        let cache = App2MetricDetailCache()
        let vm = App2CapabilityDetailViewModel(
            insight: insight("capability"),
            narrative: nil,
            vdotDataSource: EmptyVdotSource(),
            cache: cache
        )

        await vm.revalidate()

        XCTAssertNotNil(cache.capability[.days60])
        XCTAssertNil(cache.capability[.months6], "不得寫錯 range key")
    }

    // MARK: - fresh / stale 邊界（外審 E02/E03）

    func test_volumeVM_cacheHit_withinStaleWindow_doesNotRefetch() async throws {
        let cache = App2MetricDetailCache()
        cache.storeVolume(
            App2MetricDetailCache.VolumePayload(
                stats: try CountingStatsSource.statsFixture(), health: nil, targetKm: nil
            ),
            range: .weeks8,
            // staleAfter 預設 60 秒，這一筆還新鮮。
            loadedAt: Date(timeIntervalSinceNow: -10)
        )
        let source = CountingStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: source, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )

        await vm.loadIfNeeded()

        XCTAssertEqual(source.statsCalls, 0, "快取仍新鮮時 loadIfNeeded 不得背景重抓")
        XCTAssertNotNil(vm.detail)
        XCTAssertFalse(vm.isLoading)
    }

    func test_volumeVM_cacheHit_pastStaleWindow_revalidatesWithoutSpinner() async throws {
        let cache = App2MetricDetailCache()
        let staleAt = Date(timeIntervalSinceNow: -120)
        cache.storeVolume(
            App2MetricDetailCache.VolumePayload(
                stats: try CountingStatsSource.statsFixture(), health: nil, targetKm: nil
            ),
            range: .weeks8,
            loadedAt: staleAt
        )
        let source = GatedStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: source, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )

        let load = Task { await vm.loadIfNeeded() }
        await Self.waitUntil { source.requestedWeeks.count >= 1 }
        XCTAssertEqual(source.requestedWeeks.first, 8, "過期必須背景重驗")
        // SWR：重驗在跑，畫面仍是舊資料、不進 loading 態。
        XCTAssertFalse(vm.isLoading, "背景重驗不得出全頁 spinner")
        XCTAssertNotNil(vm.detail)

        source.releaseAll()
        await load.value

        let refreshed = try XCTUnwrap(cache.volume[.weeks8])
        XCTAssertGreaterThan(refreshed.loadedAt, staleAt, "重驗成功要把快取的時間戳往前推")
    }

    // MARK: - 首載中切 range 的競態（外審 D04 回歸）

    func test_volumeVM_rangeSwitchDuringInitialLoad_discardsStaleResponse() async throws {
        let cache = App2MetricDetailCache()
        let source = GatedStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: source, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )

        // 首載那一輪（view 的 `.task { loadIfNeeded() }`）卡在 stats 回應上。
        let initialLoad = Task { await vm.revalidate() }
        await Self.waitUntil { source.requestedWeeks.count >= 1 }
        XCTAssertEqual(source.requestedWeeks, [8])

        // 首載還在飛的時候切 range：新一輪打 26 週。
        vm.select(range: .weeks26)
        await Self.waitUntil { source.requestedWeeks.count >= 2 }
        XCTAssertEqual(source.requestedWeeks, [8, 26])

        // 只放行舊 range 的回應——缺陷原型會拿它去寫「當下的 range」＝ .weeks26 的 key。
        source.releaseNext()
        await initialLoad.value

        XCTAssertNil(cache.volume[.weeks26], "舊 range 的回應不得寫進新 range 的 key")
        XCTAssertNil(cache.volume[.weeks8], "被取代的那一輪整輪作廢，自己的 key 也不寫")
        XCTAssertNil(vm.detail, "過時的一輪不得發布到畫面")
        XCTAssertFalse(vm.hasLoaded, "被取代的一輪不算載過")
        XCTAssertTrue(vm.isLoading, "舊輪收尾不得清掉現任輪的 spinner")

        // 現任輪回來才是真的。
        source.releaseAll()
        await vm.rangeReloadTask?.value

        XCTAssertEqual(
            cache.volume[.weeks26]?.payload.stats.data.totalDistanceKm, 26,
            "現任 range 的 key 存的必須是它自己那一發的回應"
        )
        XCTAssertNil(cache.volume[.weeks8])
        XCTAssertTrue(vm.hasLoaded)
        XCTAssertFalse(vm.isLoading)
    }

    func test_capabilityVM_rangeSwitchDuringInitialLoad_discardsStaleResponse() async throws {
        let cache = App2MetricDetailCache()
        let source = GatedVdotSource()
        let vm = App2CapabilityDetailViewModel(
            insight: insight("capability"), narrative: nil,
            vdotDataSource: source, cache: cache
        )

        let initialLoad = Task { await vm.revalidate() }
        await Self.waitUntil { source.requestedLimits.count >= 1 }
        XCTAssertEqual(source.requestedLimits, [App2MetricRange.days60.vdotLimit])

        vm.select(range: .months6)
        await Self.waitUntil { source.requestedLimits.count >= 2 }

        source.releaseNext()
        await initialLoad.value

        XCTAssertNil(cache.capability[.months6], "舊 range 的回應不得寫進新 range 的 key")
        XCTAssertNil(cache.capability[.days60])
        XCTAssertNil(vm.detail)

        source.releaseAll()
        await vm.rangeReloadTask?.value
        XCTAssertNotNil(cache.capability[.months6])
        XCTAssertNil(cache.capability[.days60])
    }

    func test_volumeVM_rangeSwitch_staleRoundCannotClearReplacementSpinner() async {
        // 切 range 之後、接手那一輪還在飛的期間，舊輪回來不得把 spinner 收掉
        // （外審第三輪 E03）。**機制的隔離驗證在下面的 teardown 那條**：`select`
        // 一定會排一個接手輪，兩者誰先跑到 MainActor 不是測試能定的，所以這裡驗的是
        // 可觀察的結果——舊輪收尾之後，畫面仍在等接手輪。
        let cache = App2MetricDetailCache()
        let source = GatedStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: source, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )

        let initialLoad = Task { await vm.revalidate() }
        await Self.waitUntil { source.requestedWeeks.count >= 1 }
        vm.select(range: .weeks26)
        await Self.waitUntil { source.requestedWeeks.count >= 2 }

        // 只放行舊輪；接手輪仍卡在 gate 上。
        source.releaseNext()
        await initialLoad.value

        XCTAssertTrue(vm.isLoading, "接手輪還在飛，舊輪收尾不得清掉 spinner")
        XCTAssertFalse(vm.hasLoaded)
        XCTAssertTrue(cache.volume.isEmpty)

        source.releaseAll()
        await vm.rangeReloadTask?.value
        XCTAssertFalse(vm.isLoading, "接手輪自己收尾")
    }

    func test_volumeVM_roundInvalidatedByTeardown_cannotClearCurrentSpinner() async {
        // 取消（onDisappear）到「有沒有新輪接手」之間的邊界：被作廢的那一輪回來時
        // 不得代替不存在的新輪收尾——否則畫面上的 spinner 會被清成一片空白
        // （2026-09-01 外審第二輪 D04）。
        let cache = App2MetricDetailCache()
        let source = GatedStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: source, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )

        let initialLoad = Task { await vm.revalidate() }
        await Self.waitUntil { source.requestedWeeks.count >= 1 }
        XCTAssertTrue(vm.isLoading)

        vm.cancelInFlightReload()
        source.releaseAll()
        await initialLoad.value

        XCTAssertTrue(vm.isLoading, "被作廢的輪不得清掉 loading 態")
        XCTAssertFalse(vm.hasLoaded)
        XCTAssertTrue(cache.volume.isEmpty, "被作廢的輪不得寫快取")
        XCTAssertNil(vm.detail)
    }

    // MARK: - 重驗失敗／取消不得污染快取（外審 E03）

    func test_volumeVM_revalidateFailure_storesNothing_butCountsAsLoaded() async {
        let cache = App2MetricDetailCache()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: ThrowingStatsSource(error: NSError(domain: "test", code: 1)),
            healthDataSource: EmptyHealthSource(), profileRepository: nil, cache: cache
        )

        await vm.revalidate()

        XCTAssertTrue(cache.volume.isEmpty, "真失敗不得寫快取")
        XCTAssertNil(vm.detail)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.hasLoaded, "真失敗算載過（下次進頁走 staleAfter，不是無限 spinner）")
    }

    func test_volumeVM_revalidateCancelled_storesNothing_andNotLoaded() async {
        let cache = App2MetricDetailCache()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: ThrowingStatsSource(error: CancellationError()),
            healthDataSource: EmptyHealthSource(), profileRepository: nil, cache: cache
        )

        await vm.revalidate()

        XCTAssertTrue(cache.volume.isEmpty, "取消的一輪不得寫快取")
        XCTAssertNil(vm.detail)
        XCTAssertFalse(vm.hasLoaded, "取消不算載過")
        XCTAssertNil(vm.lastLoadedAt)
    }

    // MARK: - 失效

    func test_cache_removeAll_clearsEverything() throws {
        let cache = App2MetricDetailCache()
        cache.storeVolume(
            App2MetricDetailCache.VolumePayload(
                stats: try CountingStatsSource.statsFixture(), health: nil, targetKm: nil
            ),
            range: .weeks8
        )
        cache.storeCapability(try EmptyVdotSource.fixture(), range: .days60)
        cache.storeRecovery(try EmptyHealthSource.fixture())

        cache.removeAll()

        XCTAssertTrue(cache.volume.isEmpty)
        XCTAssertTrue(cache.capability.isEmpty)
        XCTAssertNil(cache.recovery)
    }

    // MARK: - 失效 owner path：真的穿過 CacheRegistrationCoordinator ＋ CacheEventBus
    // （外審 E02：直接呼叫 removeAll() 證明不了佈線在不在）

    override func tearDown() async throws {
        // 下面兩條測試動的是 process-wide 的 `.shared`，收乾淨再走。
        App2MetricDetailCache.shared.removeAll()
        try await super.tearDown()
    }

    /// 把三格都塞滿，回傳 shared 快取。
    private func fillSharedCache() throws -> App2MetricDetailCache {
        let cache = App2MetricDetailCache.shared
        cache.storeVolume(
            App2MetricDetailCache.VolumePayload(
                stats: try CountingStatsSource.statsFixture(), health: nil, targetKm: nil
            ),
            range: .weeks8
        )
        cache.storeCapability(try EmptyVdotSource.fixture(), range: .days60)
        cache.storeRecovery(try EmptyHealthSource.fixture())
        return cache
    }

    /// 佈線端顯式重建：`resetForTesting()` 之後 `registerAll()` 會重掛訂閱，
    /// 不依賴 test host 先前的初始化順序或別條測試有沒有清過 bus。
    private func rewireCacheRegistrations() async {
        await CacheEventBus.shared.resetForTesting()
        CacheRegistrationCoordinator.resetForTesting()
        CacheRegistrationCoordinator.registerAll()
    }

    func test_workoutsDataChanged_throughBus_clearsCache_andNextEntryIsMiss() async throws {
        await rewireCacheRegistrations()
        let cache = try fillSharedCache()

        CacheEventBus.shared.publish(.dataChanged(.workouts))

        await Self.waitUntil { cache.volume.isEmpty && cache.capability.isEmpty && cache.recovery == nil }
        XCTAssertTrue(cache.volume.isEmpty, "workouts 變更必須經 coordinator 清掉指標詳情快取")
        XCTAssertTrue(cache.capability.isEmpty)
        XCTAssertNil(cache.recovery)

        // 失效之後下一次進頁＝ miss，真的重抓（不是只清了但畫面照舊）。
        let source = CountingStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: source, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )
        XCTAssertNil(vm.detail, "失效後新 VM 不得吃到舊快取")
        XCTAssertTrue(vm.isLoading)

        await vm.loadIfNeeded()
        XCTAssertEqual(source.statsCalls, 1, "失效後下一次進頁必須真的重抓")
        XCTAssertNotNil(cache.volume[.weeks8], "重抓成功回寫快取")
    }

    func test_busInvalidationDuringInflightRevalidate_doesNotRepopulateCache() async throws {
        // 事件清空**之前**起飛、清空**之後**才回來的那一輪：畫面照發（沒有新輪接手，
        // 丟掉就是空白），但**不得把清空前的事實寫回快取**——否則推播說資料變了、
        // 快取立刻長回舊的一份，還黏著給下一次進頁（2026-09-01 外審第二輪 D04）。
        await rewireCacheRegistrations()
        let cache = App2MetricDetailCache.shared
        let source = GatedStatsSource()
        let vm = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: source, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )

        let inflight = Task { await vm.revalidate() }
        await Self.waitUntil { source.requestedWeeks.count >= 1 }

        // 重驗還在飛的時候，推播／資料變更事件抵達並清空快取。
        let epochBefore = cache.invalidationEpoch
        CacheEventBus.shared.publish(.dataChanged(.workouts))
        await Self.waitUntil { cache.invalidationEpoch > epochBefore }

        source.releaseAll()
        await inflight.value

        XCTAssertTrue(cache.volume.isEmpty, "事件清空之後，過時的 in-flight 回應不得重新填回快取")
        XCTAssertNotNil(vm.detail, "畫面照發：這一輪沒有接手的新輪，丟掉只會是一片空白")

        // 快取留空 ⇒ 下一次進頁仍是 miss，會真的重抓。
        let next = CountingStatsSource()
        let nextVM = App2VolumeDetailViewModel(
            insight: insight("volume"), narrative: nil,
            workoutDataSource: next, healthDataSource: EmptyHealthSource(),
            profileRepository: nil, cache: cache
        )
        XCTAssertNil(nextVM.detail)
        await nextVM.loadIfNeeded()
        XCTAssertEqual(next.statsCalls, 1)
    }

    func test_capabilityVM_busInvalidationDuringInflightRevalidate_doesNotRepopulate() async throws {
        // 同 volume：能力基準這條路徑也走同一個失效世代（外審第三輪 E03）。
        await rewireCacheRegistrations()
        let cache = App2MetricDetailCache.shared
        let source = GatedVdotSource()
        let vm = App2CapabilityDetailViewModel(
            insight: insight("capability"), narrative: nil,
            vdotDataSource: source, cache: cache
        )

        let inflight = Task { await vm.revalidate() }
        await Self.waitUntil { source.requestedLimits.count >= 1 }

        let epochBefore = cache.invalidationEpoch
        CacheEventBus.shared.publish(.dataChanged(.workouts))
        await Self.waitUntil { cache.invalidationEpoch > epochBefore }

        source.releaseAll()
        await inflight.value

        XCTAssertTrue(cache.capability.isEmpty, "事件清空之後的 in-flight 回應不得重新填回快取")
        XCTAssertNotNil(vm.detail, "畫面照發")
    }

    func test_recoveryVM_busInvalidationDuringInflightRevalidate_doesNotRepopulate() async throws {
        // 同上：恢復頁沒有 range tabs，但失效世代這條線一樣要在（外審第三輪 E03）。
        await rewireCacheRegistrations()
        let cache = App2MetricDetailCache.shared
        let source = GatedHealthSource()
        let vm = App2RecoveryDetailViewModel(
            insight: insight("recovery"), narrative: nil,
            healthDataSource: source, cache: cache
        )

        let inflight = Task { await vm.revalidate() }
        await Self.waitUntil { source.calls >= 1 }

        let epochBefore = cache.invalidationEpoch
        CacheEventBus.shared.publish(.dataChanged(.workouts))
        await Self.waitUntil { cache.invalidationEpoch > epochBefore }

        source.releaseAll()
        await inflight.value

        XCTAssertNil(cache.recovery, "事件清空之後的 in-flight 回應不得重新填回快取")
        XCTAssertNotNil(vm.detail, "畫面照發")
    }

    func test_userDataChanged_throughBus_clearsCache() async throws {
        await rewireCacheRegistrations()
        let cache = try fillSharedCache()

        // 換帳號路徑（`.dataChanged(.user)`）：跨用戶的指標絕不能留在記憶體裡。
        CacheEventBus.shared.publish(.dataChanged(.user))

        await Self.waitUntil { cache.volume.isEmpty && cache.capability.isEmpty && cache.recovery == nil }
        XCTAssertTrue(cache.volume.isEmpty, "user 變更必須經 coordinator 清掉指標詳情快取")
        XCTAssertTrue(cache.capability.isEmpty)
        XCTAssertNil(cache.recovery)
    }
}
