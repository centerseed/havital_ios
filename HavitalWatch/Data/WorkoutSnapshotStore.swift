import Foundation

final class WorkoutSnapshotStore {
    private let cache: SnapshotPersisting

    init(cache: SnapshotPersisting = LocalSnapshotCache()) {
        self.cache = cache
    }

    func save(_ dto: WatchPlanSnapshotDTO) {
        guard let data = try? JSONEncoder().encode(dto) else { return }
        cache.save(data)
    }

    func currentSnapshot() -> WatchPlanSnapshot? {
        guard
            let data = cache.load(),
            let dto = try? JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: data)
        else {
            return nil
        }

        return dto.toEntity()
    }
}
