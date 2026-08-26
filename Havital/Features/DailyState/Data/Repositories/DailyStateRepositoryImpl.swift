import Foundation

// MARK: - DailyStateRepositoryImpl
/// Data Layer — 持有 RemoteDataSource，協調 API 呼叫 + DTO→Entity 映射。
/// ⚠️ Repository 為被動資料存取，不碰 CacheEventBus（事件流屬於 ViewModel/Service 層）。
final class DailyStateRepositoryImpl: DailyStateRepository {

    private let remoteDataSource: DailyStateRemoteDataSourceProtocol
    /// 顯示層快照的落點。**存 DTO 不存 entity** —— 落地格式是 Data 層的事，
    /// domain entity 不因為要落地而綁上序列化。
    private let snapshots: any App2SnapshotStoring

    init(
        remoteDataSource: DailyStateRemoteDataSourceProtocol = DailyStateRemoteDataSource(),
        snapshots: (any App2SnapshotStoring)? = nil
    ) {
        self.remoteDataSource = remoteDataSource
        self.snapshots = snapshots ?? App2FileSnapshotStore.shared
        Logger.debug("[DailyStateRepositoryImpl] 初始化完成")
    }

    func fetchTodayState() async throws -> DailyStateCard {
        let dto = try await remoteDataSource.fetchTodayState()
        snapshots.save(dto, for: .stateToday)
        return StateCardMapper.toEntity(from: dto)
    }

    func cachedTodayState() -> DailyStateCard? {
        snapshots.load(StateCardDTO.self, for: .stateToday)
            .map { StateCardMapper.toEntity(from: $0.value) }
    }

    func applyBenchmark(_ calibration: SameDayBenchmarkCalibration) async throws -> Int? {
        let request = BenchmarkApplyRequestDTO(
            workoutId: calibration.workoutId,
            workoutDate: calibration.workoutDate,
            benchmarkDistanceM: calibration.benchmarkDistanceM,
            benchmarkDurationS: calibration.benchmarkDurationS,
            overviewId: calibration.overviewId
        )
        let result = try await remoteDataSource.applyBenchmark(request)
        return result.finishPrediction?.estimatedRaceTimeSeconds
    }

    func scheduleNextBenchmark(_ calibration: SameDayBenchmarkCalibration, weeksAhead: Int) async throws -> Int? {
        let request = BenchmarkScheduleRequestDTO(
            overviewId: calibration.overviewId,
            currentWeek: calibration.weekOfTraining,
            weeksAhead: weeksAhead
        )
        let result = try await remoteDataSource.scheduleNextBenchmark(request)
        return result.scheduledWeek
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {
    /// 註冊 DailyState 模組依賴。
    /// RepositoryImpl 註冊為 singleton（對應 DailyStateRepository protocol）。
    func registerDailyStateModule() {
        let remoteDS = DailyStateRemoteDataSource()
        let repository = DailyStateRepositoryImpl(remoteDataSource: remoteDS)
        register(repository as DailyStateRepository, forProtocol: DailyStateRepository.self)

        Logger.debug("[DI] DailyState module dependencies registered")
    }
}
