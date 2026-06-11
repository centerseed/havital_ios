import Foundation

/// 本地記錄「某天某力量類型已回報完成」（一次性防重送 + 顯示已完成態）。
protocol StrengthCompletionStore {
    func isCompleted(dayDate: String, strengthType: String) -> Bool
    func completedRPE(dayDate: String, strengthType: String) -> Int?
    func markCompleted(dayDate: String, strengthType: String, rpe: Int)
}

final class UserDefaultsStrengthCompletionStore: StrengthCompletionStore {
    static let shared = UserDefaultsStrengthCompletionStore()

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(_ dayDate: String, _ strengthType: String) -> String {
        "strength_completed.\(dayDate).\(strengthType)"
    }

    func isCompleted(dayDate: String, strengthType: String) -> Bool {
        defaults.object(forKey: key(dayDate, strengthType)) != nil
    }

    func completedRPE(dayDate: String, strengthType: String) -> Int? {
        defaults.object(forKey: key(dayDate, strengthType)) as? Int
    }

    func markCompleted(dayDate: String, strengthType: String, rpe: Int) {
        defaults.set(rpe, forKey: key(dayDate, strengthType))
    }
}
