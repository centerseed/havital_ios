import Foundation

// MARK: - WorkoutRecapCoordinator
//
// 訓練完成 Recap 時刻的觸發中樞（底層流程，與視覺解耦）。
// 流程：app 前景/啟動 → 取最新訓練 → 若「未看過且有 AI 內容」→ 建 WorkoutRecapContent
//       → enqueue 進 InterruptCoordinator（全 App 級彈窗佇列，與 paywall / 提醒共用排程）。
// 看過後由 InterruptItem.onDismiss 標記已讀，確保每筆只彈一次。

@MainActor
final class WorkoutRecapCoordinator {
    static let shared = WorkoutRecapCoordinator()

    private let interruptCoordinator: InterruptCoordinator
    private var workoutRepository: WorkoutRepository {
        DependencyContainer.shared.resolve()
    }
    private var isChecking = false

    /// 只對「最近完成」的訓練彈 recap（避免重裝對舊訓練亂彈、也讓「等 AI」有期限）。
    private let recencyWindow: TimeInterval = 48 * 60 * 60

    init(interruptCoordinator: InterruptCoordinator = .shared) {
        self.interruptCoordinator = interruptCoordinator
        subscribeToWorkoutSync()
    }

    /// 運動同步進來時也檢查（不只靠開 app）。WorkoutRepository 背景刷新會發出此事件。
    private func subscribeToWorkoutSync() {
        CacheEventBus.shared.subscribe(for: "dataChanged.workouts") { [weak self] in
            await self?.checkForNewWorkoutRecap()
        }
    }

    /// app 前景/啟動 + 運動同步時呼叫：偵測「最近完成且未看過」的訓練 → enqueue recap。
    /// 不以 AI 當門檻（AI 後端非同步生成）；不提早標記已讀（已讀只在 recap 關閉時標記）。
    func checkForNewWorkoutRecap() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let latest: WorkoutV2?
        do {
            latest = try await workoutRepository.getWorkouts(limit: 1, offset: nil).first
        } catch {
            Logger.debug("[WorkoutRecap] fetch latest failed: \(error.localizedDescription)")
            return
        }

        guard let workout = latest else { return }
        guard !WorkoutRecapStorage.hasSeen(workout.id) else { return }
        // 只彈「剛完成」的訓練（48h 內）。
        guard Date().timeIntervalSince(workout.startDate) <= recencyWindow else { return }
        // 需有基本數據，避免空殼紀錄。
        guard (workout.distanceMeters ?? 0) > 0 else { return }

        let content = await buildContent(for: workout)
        enqueue(content)
    }

    /// 由 list workout 取 metrics + 補抓 detail 取 AI 分析 / RPE（list endpoint 通常不帶這些）。
    private func buildContent(for workout: WorkoutV2) async -> WorkoutRecapContent {
        let detail = try? await workoutRepository.getWorkoutDetail(id: workout.id)
        return WorkoutRecapContent.make(
            from: workout,
            isPremium: SubscriptionStateManager.shared.hasPremiumAccess,
            aiAnalysisOverride: detail?.aiSummary?.analysis,
            rpeOverride: detail?.advancedMetrics?.rpe
        )
    }

    private func enqueue(_ content: WorkoutRecapContent) {
        let didEnqueue = interruptCoordinator.enqueue(
            .workoutRecap(content) { _ in
                WorkoutRecapStorage.markSeen(content.id)
            }
        )
        if didEnqueue {
            Logger.debug("[WorkoutRecap] enqueued recap for \(content.id)")
        }
    }

    #if DEBUG
    /// 測試用：只建構最新一筆的 recap 內容（不 enqueue），供 debug 選單以本地 sheet 直接呈現。
    func debugLatestContent() async -> WorkoutRecapContent? {
        guard let workout = try? await workoutRepository.getWorkouts(limit: 1, offset: nil).first else {
            Logger.debug("[WorkoutRecap] debug: no workout available")
            return nil
        }
        return await buildContent(for: workout)
    }

    /// 測試用：取最新一筆，繞過已讀 + 內容門檻，直接 enqueue（驗證 view/interrupt 渲染）。
    func debugForceShowLatest() async {
        guard let workout = try? await workoutRepository.getWorkouts(limit: 1, offset: nil).first else {
            Logger.debug("[WorkoutRecap] debug: no workout available")
            return
        }
        WorkoutRecapStorage.clearSeen(workout.id)
        let content = await buildContent(for: workout)
        Logger.debug("[WorkoutRecap] debug: force enqueue \(workout.id) hasAI=\(content.hasAIAnalysis)")
        enqueue(content)
    }
    #endif
}
