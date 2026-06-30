import Foundation
import Combine

/// Drives the "Send to Garmin" button on the planned-session detail screen (T-0044).
/// @MainActor, depends on GarminPushRepository protocol. Not subscription-gated:
/// access is gated upstream at plan generation (no subscription → no plan to push).
/// Logs every step (start / success / error + which error code) so prod
/// issues are traceable from Cloud Logging + Firebase.
@MainActor
final class GarminPushViewModel: ObservableObject, TaskManageable {
    enum UIState: Equatable { case idle, working }

    let taskRegistry = TaskRegistry()

    @Published var uiState: UIState = .idle
    @Published var alertMessage: String?
    @Published var showAlert = false
    /// When true the alert offers a "connect Garmin" action (needs reauth).
    @Published var offerReconnect = false
    /// One-time hint after a successful push: tells the user the imported workout
    /// lives under a Running activity on the watch (otherwise they think it failed).
    /// Suppressed once the user taps "don't show again".
    @Published var showPushHint = false

    private let pushHintDismissedKey = "garminPushHintDismissed"
    private var pushHintDismissed: Bool {
        UserDefaults.standard.bool(forKey: pushHintDismissedKey)
    }
    /// User asked to stop seeing the hint — persist it and hide.
    func dismissPushHintForever() {
        UserDefaults.standard.set(true, forKey: pushHintDismissedKey)
        showPushHint = false
    }

    private let repository: GarminPushRepository
    private var task: Task<Void, Never>?

    init(repository: GarminPushRepository) {
        self.repository = repository
    }

    // MARK: - Actions

    func push(dayIndex: Int, date: String) {
        uiState = .working
        offerReconnect = false
        Logger.firebase("[garmin-push] start day=\(dayIndex) date=\(date)",
                        level: .info, labels: ["feature": "garmin_push", "action": "push"])
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.repository.pushWorkout(dayIndex: dayIndex, date: date)
                Logger.firebase("[garmin-push] success day=\(dayIndex)",
                                level: .info, labels: ["feature": "garmin_push", "action": "push"])
                // First successful pushes show the "find it under a Running activity"
                // hint; once dismissed forever, fall back to the plain confirmation.
                if self.pushHintDismissed {
                    self.finish(messageKey: "garmin.push.success")
                } else {
                    self.uiState = .idle
                    self.showPushHint = true
                }
            } catch is CancellationError {
                self.uiState = .idle
            } catch {
                self.handleError(error, action: "push")
            }
        }
    }

    func remove(dayIndex: Int) {
        uiState = .working
        offerReconnect = false
        Logger.firebase("[garmin-push] remove start day=\(dayIndex)",
                        level: .info, labels: ["feature": "garmin_push", "action": "remove"])
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.repository.removeWorkout(dayIndex: dayIndex)
                Logger.firebase("[garmin-push] remove success day=\(dayIndex)",
                                level: .info, labels: ["feature": "garmin_push", "action": "remove"])
                self.finish(messageKey: "garmin.push.removed")
            } catch is CancellationError {
                self.uiState = .idle
            } catch {
                self.handleError(error, action: "remove")
            }
        }
    }

    // MARK: - Helpers

    private func finish(messageKey: String) {
        uiState = .idle
        alertMessage = NSLocalizedString(messageKey, comment: "")
        showAlert = true
    }

    private func handleError(_ error: Error, action: String) {
        uiState = .idle
        let code = Self.garminErrorCode(from: error)
        // needs_garmin_reauth / not_a_run_workout are expected, user-recoverable
        // states (the user is guided to reconnect, or simply picked a non-run day),
        // not app failures — the backend already logs them at INFO. Report them at
        // .warn so they land in WARNING, not the prod ERROR stream where they'd
        // pollute logs and trip false health-check / alert-triage alarms. Genuine
        // failures (garmin_training_unavailable, unknown) stay at .error.
        let level: LogLevel = (code == "needs_garmin_reauth" || code == "not_a_run_workout") ? .warn : .error
        Logger.firebase("[garmin-push] \(action) failed code=\(code ?? "?") err=\(error.localizedDescription)",
                        level: level, labels: ["feature": "garmin_push", "action": action, "error_code": code ?? "unknown"])

        switch code {
        case "needs_garmin_reauth":
            alertMessage = NSLocalizedString("garmin.push.error.needs_garmin_reauth", comment: "")
            offerReconnect = true
            showAlert = true
        case "garmin_training_unavailable":
            alertMessage = NSLocalizedString("garmin.push.error.garmin_training_unavailable", comment: "")
            showAlert = true
        case "not_a_run_workout":
            alertMessage = NSLocalizedString("garmin.push.error.not_a_run_workout", comment: "")
            showAlert = true
        default:
            alertMessage = NSLocalizedString("garmin.push.error.generic", comment: "")
            showAlert = true
        }
    }

    /// Pulls the backend `error` code out of an HTTPError body.
    /// Body shapes: `{"detail":{"error":"...","message":"..."}}` (FastAPI HTTPException) or `{"error":"..."}`.
    static func garminErrorCode(from error: Error) -> String? {
        guard let http = error as? HTTPError else { return nil }
        let body: String
        switch http {
        case .httpError(_, let b), .badRequest(let b), .forbidden(let b), .serverError(_, let b):
            body = b
        default:
            return nil
        }
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = obj["detail"] as? [String: Any], let e = detail["error"] as? String {
            return e
        }
        return obj["error"] as? String
    }

    deinit {
        task?.cancel()
    }
}
