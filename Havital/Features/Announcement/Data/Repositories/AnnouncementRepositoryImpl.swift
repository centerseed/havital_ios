import Foundation

final class AnnouncementRepositoryImpl: AnnouncementRepository {

    // MARK: - Dependencies

    private let dataSource: AnnouncementRemoteDataSource

    // MARK: - Initialization

    init(dataSource: AnnouncementRemoteDataSource) {
        self.dataSource = dataSource
    }

    // MARK: - AnnouncementRepository

    func fetchAnnouncements() async throws -> [Announcement] {
        do {
            let dtos = try await dataSource.fetchAnnouncements()
            return dtos.compactMap { AnnouncementMapper.toDomain($0) }
        } catch {
            Logger.error("[AnnouncementRepository] fetchAnnouncements failed: \(error.localizedDescription)")
            throw AnnouncementError.fetchFailed(error.localizedDescription)
        }
    }

    func markSeen(id: String) async throws {
        do {
            try await dataSource.markSeen(id: id)
        } catch {
            Logger.error("[AnnouncementRepository] markSeen failed: \(error.localizedDescription)")
            throw AnnouncementError.markSeenFailed(error.localizedDescription)
        }
    }

    func markSeenBatch(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        do {
            try await dataSource.markSeenBatch(ids: ids)
        } catch {
            Logger.error("[AnnouncementRepository] markSeenBatch failed: \(error.localizedDescription)")
            throw AnnouncementError.markSeenFailed(error.localizedDescription)
        }
    }
}

// MARK: - DI Registration

extension DependencyContainer {
    func registerAnnouncementModule() {
        let dataSource = AnnouncementRemoteDataSource(
            httpClient: resolve(),
            parser: resolve()
        )
        let repo = AnnouncementRepositoryImpl(dataSource: dataSource)
        register(repo as AnnouncementRepository, forProtocol: AnnouncementRepository.self)
        Logger.debug("[DI] Announcement module registered")
    }
}
