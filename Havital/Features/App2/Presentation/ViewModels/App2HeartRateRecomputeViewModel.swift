import Foundation
import SwiftUI

// MARK: - App2HeartRateRecomputeViewModel
/// 改心率後重算過去的單堂跑力（`SPEC-hr-zones` §5.5）＋「自動更新最大心率」開關＋手錶偏差提醒（§5.7、§5.8）。
///
/// - 「有沒有變」只看後端 `PUT /user` 的 `heart_rate.changed`，這裡不比較存前存後的值。
/// - 存心率永遠先成功；重算是另一件事，失敗照實顯示，不影響已存下的值。
/// - 重算是後端背景工作：POST 回工作代號，這裡輪詢 GET 到結束（完成／失敗）；同一位使用者一次一個，
///   進行中不能再開（後端也會回 409，App 接上進行中的那一個）。
@MainActor
final class App2HeartRateRecomputeViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case starting
        /// 後端的一句話（沒有可重算的課、還沒設心率…）。
        case notice(String)
        case job(HeartRateRecomputeJob, message: String?)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published var isPromptPresented = false
    @Published private(set) var reminder: HeartRateWatchReminder?
    @Published private(set) var autoUpdate: HeartRateWatchAutoUpdate?
    @Published private(set) var autoUpdateMaxHR: Bool
    @Published var errorMessage: String?

    private let repository: HeartRateRecomputeRepository
    private let updateProfile: ([String: Any]) async -> Bool
    private let updateWatchMaxHR: ((Int) async -> Bool?)?
    private let onFinished: () -> Void
    private let pollSleep: () async -> Void

    init(
        repository: HeartRateRecomputeRepository,
        autoUpdateMaxHR: Bool,
        updateProfile: @escaping ([String: Any]) async -> Bool,
        updateWatchMaxHR: ((Int) async -> Bool?)? = nil,
        onFinished: @escaping () -> Void = App2HeartRateRecomputeViewModel.publishDownstreamRefresh,
        pollSleep: @escaping () async -> Void = { try? await Task.sleep(nanoseconds: 3_000_000_000) }
    ) {
        self.repository = repository
        self.autoUpdateMaxHR = autoUpdateMaxHR
        self.updateProfile = updateProfile
        self.updateWatchMaxHR = updateWatchMaxHR
        self.onFinished = onFinished
        self.pollSleep = pollSleep
    }

    /// 重算完成後，能力中心／配速表／完賽預估讀到新的能力值：走既有的快取失效事件
    /// （`CacheRegistrationCoordinator` 已把 `.workouts`、`.vdot` 接到指標詳情快取，首頁訂 `.workouts`）。
    nonisolated static func publishDownstreamRefresh() {
        Task { @MainActor in
            CacheEventBus.shared.publish(.dataChanged(.vdot))
            CacheEventBus.shared.publish(.dataChanged(.workouts))
        }
    }

    // MARK: - 狀態

    var isActive: Bool {
        if case .starting = phase { return true }
        if case .job(let job, _) = phase { return job.isActive }
        return false
    }

    var canStart: Bool { !isActive }

    // MARK: - 存完心率後問一次

    func offerAfterSave(changed: Bool) {
        guard changed else { return }
        isPromptPresented = true
    }

    /// 首頁提醒的「更新」直接沿用 profile repository 的 PUT；回傳值仍只採用後端
    /// `heart_rate.changed`，不由 App 自己比較數字。
    func applyWatchMaxHR(_ maxHR: Int) async {
        guard let updateWatchMaxHR else {
            errorMessage = NSLocalizedString("error.unknown", comment: "")
            return
        }
        guard let changed = await updateWatchMaxHR(maxHR) else {
            errorMessage = NSLocalizedString("error.unknown", comment: "")
            return
        }
        await loadWatchCheck()
        offerAfterSave(changed: changed)
    }

    /// 範圍選單的順序：14／30／60 天，最後是明確的「不重算」（iPhone 的 cancel 角色按鈕看不到）。
    static let promptChoices: [HeartRateRecomputeChoice] = [
        .days(.fourteen), .days(.thirty), .days(.sixty), .skip
    ]

    func choose(_ choice: HeartRateRecomputeChoice) async {
        switch choice {
        case .days(let days): await choose(days)
        case .skip: await choose(nil)
        }
    }

    /// 使用者在範圍選擇裡按了哪一個；`nil`＝不重算。
    func choose(_ days: HeartRateRecomputeDays?) async {
        isPromptPresented = false
        guard let days, canStart else { return }
        phase = .starting
        do {
            switch try await repository.startRecompute(days: days) {
            case .queued(let job, let message):
                phase = .job(job, message: message)
                await pollUntilFinished()
            case .alreadyRunning(let job, let message):
                phase = .job(job, message: message)
                await pollUntilFinished()
            case .nothingToRecompute(let message):
                phase = .notice(message ?? "")
            case .noHeartRateParameters(let message):
                phase = .notice(message ?? "")
            }
        } catch {
            if Task.isCancelled { phase = .idle; return }
            phase = .failed(NSLocalizedString("error.unknown", comment: ""))
        }
    }

    /// 進頁時接上進行中的工作；跑完很久的舊結果不再顯示。
    func refresh() async {
        guard let status = try? await repository.latestStatus(), let job = status.job, job.isActive else { return }
        phase = .job(job, message: status.message)
        await pollUntilFinished()
    }

    /// 測試與進頁接手用：直接採用一個已知的工作狀態。
    func adopt(job: HeartRateRecomputeJob, message: String?) {
        phase = .job(job, message: message)
    }

    private func pollUntilFinished() async {
        while case .job(let job, _) = phase, job.isActive {
            await pollSleep()
            if Task.isCancelled { return }
            do {
                let status = try await repository.latestStatus()
                guard let latest = status.job else {
                    phase = .failed(NSLocalizedString("error.unknown", comment: ""))
                    return
                }
                phase = .job(latest, message: status.message)
                if latest.status == .completed { onFinished() }
            } catch {
                if Task.isCancelled { return }
                phase = .failed(NSLocalizedString("error.unknown", comment: ""))
                return
            }
        }
    }

    // MARK: - 手錶偏差提醒

    func loadWatchCheck() async {
        let check = try? await repository.watchCheck()
        reminder = check?.reminder
        autoUpdate = check?.autoUpdate
    }

    /// 「先不用」：後端記下來才收起卡片；失敗就留著，不假裝已忽略。
    func dismissReminder() async {
        do {
            try await repository.dismissWatchReminder()
            reminder = nil
        } catch {
            errorMessage = NSLocalizedString("error.unknown", comment: "")
        }
    }

    // MARK: - 自動更新最大心率

    func setAutoUpdate(_ enabled: Bool) async {
        let previous = autoUpdateMaxHR
        autoUpdateMaxHR = enabled
        let ok = await updateProfile(["auto_update_max_hr": enabled])
        if !ok {
            autoUpdateMaxHR = previous
            errorMessage = NSLocalizedString("error.unknown", comment: "")
        }
    }
}
