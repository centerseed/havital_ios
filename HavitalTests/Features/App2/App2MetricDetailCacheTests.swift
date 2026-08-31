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

    private func insight(_ id: String) -> App2Insight {
        App2Insight(id: id, label: id, value: nil, direction: .unknown, verdict: nil)
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
}
