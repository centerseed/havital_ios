import Foundation

protocol SnapshotPersisting {
    func save(_ data: Data)
    func load() -> Data?
}

struct LocalSnapshotCache: SnapshotPersisting {
    private let key = "paceriz.watch.today_snapshot"
    private let defaults = UserDefaults.standard

    func save(_ data: Data) {
        defaults.set(data, forKey: key)
    }

    func load() -> Data? {
        defaults.data(forKey: key)
    }
}
