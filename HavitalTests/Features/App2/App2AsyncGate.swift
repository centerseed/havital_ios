import Foundation

/// 把「網路那一步」停在測試指定的時點，用來斷言在它回來之前畫面上已經有／還沒有東西。
/// 原本是 `App2PlanOverviewProjectionTests` 裡的 `private actor`；第二個檔案要用時
/// 搬出來共用，不複製第二份（AGENTS.md 鐵則 0）。
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var entryWatchers: [CheckedContinuation<Void, Never>] = []
    private var didEnter = false

    func wait() async {
        noteEntry()
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    /// 等「有人真的走到閘門」——不用 sleep 猜時序。
    func waitUntilEntered() async {
        if didEnter { return }
        await withCheckedContinuation { entryWatchers.append($0) }
    }

    private func noteEntry() {
        didEnter = true
        let watchers = entryWatchers
        entryWatchers.removeAll()
        watchers.forEach { $0.resume() }
    }
}
