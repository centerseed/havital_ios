import Foundation

// MARK: - Rizo Repository Implementation
/// Rizo（AI 教練）Repository 實作。
/// Data Layer - 持有 RemoteDataSource，協調 API 呼叫。
/// ⚠️ Repository 為被動資料存取，不碰 CacheEventBus（事件流屬於 ViewModel/Service 層）。
final class RizoRepositoryImpl: RizoRepository {

    // MARK: - Singleton

    static let shared = RizoRepositoryImpl()

    // MARK: - Properties

    private let remoteDataSource: RizoRemoteDataSource

    // MARK: - Initialization

    init(remoteDataSource: RizoRemoteDataSource = RizoRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
        Logger.debug("[RizoRepositoryImpl] 初始化完成")
    }

    // MARK: - RizoRepository Protocol

    func sendJournalChat(
        workoutId: String,
        message: String,
        presetSelections: [String],
        sessionId: String?
    ) async throws -> RizoReply {
        // 訓練日記情境：scenario 固定 "journal"。首回合 sessionId 為 nil；
        // 澄清輪續談時傳入上一回合 RizoReply 回的 sessionId 維持脈絡。
        return try await remoteDataSource.sendChat(
            scenario: "journal",
            message: message,
            sessionId: sessionId,
            workoutId: workoutId,
            presetSelections: presetSelections
        )
    }

    func getPresets(scenario: String) async throws -> [RizoPreset] {
        return try await remoteDataSource.fetchPresets(scenario: scenario)
    }

    func getHistory() async throws -> [RizoHistoryItem] {
        return try await remoteDataSource.fetchHistory()
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {
    /// 註冊 Rizo 模組依賴。
    /// RepositoryImpl 註冊為 singleton（對應 RizoRepository protocol）。
    func registerRizoModule() {
        let remoteDS = RizoRemoteDataSource()
        let repository = RizoRepositoryImpl(remoteDataSource: remoteDS)
        register(repository as RizoRepository, forProtocol: RizoRepository.self)

        Logger.debug("[DI] Rizo module dependencies registered")
    }
}
