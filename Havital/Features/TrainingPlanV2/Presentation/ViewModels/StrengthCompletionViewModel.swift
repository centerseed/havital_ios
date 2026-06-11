import Foundation
import SwiftUI

@MainActor
final class StrengthCompletionViewModel: ObservableObject, Identifiable, TaskManageable {

    let id = UUID()

    // MARK: - TaskManageable
    nonisolated let taskRegistry = TaskRegistry()

    struct Feedback: Equatable {
        let rpe: Int
        let upgrades: [StrengthProgressUpdate]
    }

    enum Phase: Equatable {
        case form
        case submitting
        case feedback(Feedback)
        case failed(DomainError)
    }

    @Published private(set) var phase: Phase = .form
    @Published var selectedRPE: Int?
    @Published private(set) var statuses: [String: StrengthExerciseStatus] = [:]

    let activity: StrengthActivity
    private let dayDate: String
    private let weeklyPlanId: String?
    private let repository: StrengthCompletionRepository
    private let store: StrengthCompletionStore

    init(
        activity: StrengthActivity,
        dayDate: String,
        weeklyPlanId: String?,
        repository: StrengthCompletionRepository,
        store: StrengthCompletionStore
    ) {
        self.activity = activity
        self.dayDate = dayDate
        self.weeklyPlanId = weeklyPlanId
        self.repository = repository
        self.store = store
        for (i, ex) in activity.exercises.enumerated() {
            statuses[Self.exKey(ex, i)] = .completed
        }
    }

    static func exKey(_ ex: Exercise, _ index: Int) -> String {
        ex.exerciseId ?? "idx_\(index)"
    }

    func status(for exerciseId: String) -> StrengthExerciseStatus {
        statuses[exerciseId] ?? .completed
    }

    func toggleSkip(exerciseId: String) {
        statuses[exerciseId] = (statuses[exerciseId] == .skipped) ? .completed : .skipped
    }

    var canSubmit: Bool {
        if case .submitting = phase { return false }
        return selectedRPE != nil
    }

    func dismissError() {
        if case .failed = phase { phase = .form }
    }

    func submit() async {
        guard let rpe = selectedRPE else { return }
        phase = .submitting
        let inputs: [StrengthExerciseInput] = activity.exercises.enumerated().map { (i, ex) in
            StrengthExerciseInput(
                exerciseId: ex.exerciseId,
                seriesId: ex.seriesId,
                status: statuses[Self.exKey(ex, i)] ?? .completed
            )
        }
        do {
            let result = try await repository.completeStrengthSession(
                dayDate: dayDate,
                strengthType: activity.strengthType,
                inputs: inputs,
                overallRpe: rpe,
                durationMinutes: activity.durationMinutes,
                weeklyPlanId: weeklyPlanId
            )
            store.markCompleted(dayDate: dayDate, strengthType: activity.strengthType, rpe: rpe)
            let changed = result.progressUpdates.filter { $0.reason == .upgrade || $0.reason == .downgrade }
            phase = .feedback(Feedback(rpe: rpe, upgrades: changed))
        } catch {
            phase = .failed(error.toDomainError())
        }
    }

    func startSubmit() {
        Task { [weak self] in
            await self?.executeTask(id: TaskID("submit")) { [weak self] in
                await self?.submit()
            }
        }
    }

    deinit {
        cancelAllTasks()
    }
}
