import Combine
import Foundation

@MainActor
final class InterruptCoordinator: ObservableObject {
    static let shared = InterruptCoordinator()

    @Published private(set) var currentItem: InterruptItem?
    @Published private(set) var pendingItems: [InterruptItem] = []

    private struct QueueEntry {
        let item: InterruptItem
        let sequence: UInt64
    }

    private var queue: [QueueEntry] = []
    private var nextSequence: UInt64 = 0

    init() {}

    var hasPendingInterrupts: Bool {
        !pendingItems.isEmpty
    }

    func enqueue(_ item: InterruptItem) -> Bool {
        guard !contains(stableID: item.stableID) else { return false }

        nextSequence += 1
        queue.append(QueueEntry(item: item, sequence: nextSequence))
        refreshPendingItems()
        activateNextIfNeeded()
        return true
    }

    func dismissCurrent(reason: InterruptDismissReason = .dismissed) {
        guard let item = currentItem else { return }
        currentItem = nil
        item.onDismiss?(reason)
        activateNextIfNeeded()
    }

    func remove(
        stableID: String,
        reason: InterruptDismissReason = .cancelled
    ) {
        if currentItem?.stableID == stableID {
            dismissCurrent(reason: reason)
            return
        }

        queue.removeAll { $0.item.stableID == stableID }
        refreshPendingItems()
    }

    func removeAll(
        ofType type: InterruptType,
        reason: InterruptDismissReason = .cancelled
    ) {
        if currentItem?.type == type {
            dismissCurrent(reason: reason)
        }

        queue.removeAll { $0.item.type == type }
        refreshPendingItems()
    }

    func contains(stableID: String) -> Bool {
        currentItem?.stableID == stableID || queue.contains(where: { $0.item.stableID == stableID })
    }

    func contains(type: InterruptType) -> Bool {
        currentItem?.type == type || queue.contains(where: { $0.item.type == type })
    }

    func resetForTesting() {
        currentItem = nil
        queue.removeAll()
        pendingItems.removeAll()
        nextSequence = 0
    }

    private func activateNextIfNeeded() {
        guard currentItem == nil, !queue.isEmpty else { return }

        queue.sort { lhs, rhs in
            if lhs.item.priority != rhs.item.priority {
                return lhs.item.priority > rhs.item.priority
            }
            return lhs.sequence < rhs.sequence
        }

        let next = queue.removeFirst()
        refreshPendingItems()
        currentItem = next.item
        next.item.onPresented?()
    }

    private func refreshPendingItems() {
        pendingItems = queue
            .sorted { lhs, rhs in
                if lhs.item.priority != rhs.item.priority {
                    return lhs.item.priority > rhs.item.priority
                }
                return lhs.sequence < rhs.sequence
            }
            .map(\.item)
    }
}

