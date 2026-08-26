import Foundation

// MARK: - App2PeriodSummaryViewModel
/// 整期總結的載入器（設計 **frame-00g（c）** 數字版 ／ **frame-00g2（a）** 故事版）。
///
/// **故事版是主版式，數字版是降級態**（2026-08-26 裁決）。但敘事端點還沒有落地
/// （`SPEC-plan-period-summary.md` status=Draft），所以 production 路徑的 `story`
/// 恆為 nil → 一律走數字版並在 header 掛「敘事未生成 · 以數據呈現」chip。
/// **不對 production 假造敘事**：故事版只在 DEBUG 用 fixture 預覽
/// （`Features/App2/Debug/App2PlanEndDevView.swift`）。
///
/// 四條端點都是活的（`DESIGN-app2-weekly-review-and-plan-end-inventory.md` §B.3）：
/// `GET /v2/workouts/stats`（週序列）、逐週 `GET /v2/summary/weekly`、
/// `GET /v2/workouts`（時長／最長單次）、`GET /v2/workouts/vdots`（能力曲線）。
/// **任一條掛掉只是少那幾格**（畫「–」），不是整頁失敗 —— 每一格都是獨立的量。
///
/// 課表 tab 的結束態卡用的是同一份投影的子集（`App2PeriodSummary.strip`），
/// 所以兩個畫面上的「完成率 91%」一定是同一個字。
@MainActor
final class App2PeriodSummaryViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var summary: App2Sourced<App2PeriodSummary>?
    /// LLM 敘事。**production 恆為 nil**（端點未落地）→ 畫面走數字版。
    @Published private(set) var story: App2PeriodStory?
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    /// 首頁／課表頁已經算好的那一張結束態卡。**這一支不自己再判一次結束態** ——
    /// `training_completed` 的偵測只有 `App2PlanEndProjection.card` 一個入口。
    private let card: App2PlanEndCard

    private let planRepository: TrainingPlanV2Repository
    private let workoutDataSource: WorkoutStatsDataSourceProtocol
    private let vdotDataSource: VDOTDataSourceProtocol

    /// 逐週回顧要打幾週。`total_weeks` 缺席時的保底 —— 計畫再短也不會是 0 週。
    private static let fallbackWeeks = 12
    /// 為了算總時間與最長單次而取回的紀錄筆數。整期最多 6 堂 × 30 週仍在範圍內。
    private static let workoutPageSize = 200

    init(
        card: App2PlanEndCard,
        planRepository: TrainingPlanV2Repository? = nil,
        workoutDataSource: WorkoutStatsDataSourceProtocol? = nil,
        vdotDataSource: VDOTDataSourceProtocol? = nil
    ) {
        self.card = card
        if let planRepository {
            self.planRepository = planRepository
        } else {
            let container = DependencyContainer.shared
            if !container.isRegistered(TrainingPlanV2Repository.self) {
                container.registerTrainingPlanV2Module()
            }
            self.planRepository = container.resolve() as TrainingPlanV2Repository
        }
        self.workoutDataSource = workoutDataSource ?? WorkoutRemoteDataSource()
        self.vdotDataSource = vdotDataSource ?? VDOTService.shared
    }

    deinit {
        cancelAllTasks()
    }

    var weeks: Int { max(card.totalWeeks ?? Self.fallbackWeeks, 1) }

    func revalidate() async {
        isLoading = !hasLoaded
        defer {
            isLoading = false
            hasLoaded = true
            lastLoadedAt = Date()
        }

        // 四條各自可缺席：`try?` 是刻意的 —— 少一條端點只是少那幾格，
        // 不該讓整頁變空白。
        async let statsTask = try? workoutDataSource.fetchWorkoutStats(days: 30, weeks: weeks)
        async let workoutsTask = try? workoutDataSource.fetchRecentWorkouts(pageSize: Self.workoutPageSize)
        async let vdotsTask = try? vdotDataSource.getVDOTs(limit: vdotLimit)
        let reviews = await weeklySummaries()

        let stats = await statsTask
        let workouts = await workoutsTask
        let vdots = await vdotsTask

        // 這一輪整批落空（換頁／下拉刷新被 SwiftUI 收掉時每一條 in-flight 請求都會
        // 回 -999，`AGENTS.md` 陷阱 2）→ 保留畫面上的舊資料，不把真資料換成一整頁的「–」。
        if stats == nil, workouts == nil, vdots == nil, reviews.isEmpty, summary != nil { return }

        summary = App2Sourced(
            App2PlanEndProjection.summary(
                card: card,
                weeklySeries: stats?.data.weeklySeries ?? [],
                weeklySummaries: reviews,
                workouts: workouts ?? [],
                vdots: vdots?.vdots ?? []
            ),
            origin: .live(
                endpoint: "GET /v2/workouts/stats + GET /v2/summary/weekly"
                    + " + GET /v2/workouts + GET /v2/workouts/vdots"
            )
        )

        #if DEBUG
        // 故事版預覽（DEBUG-only fixture）。production 這一行不存在，`story` 恆 nil。
        //
        // fixture 的週數在**這裡**才決定 —— `weeks` 是這一頁真實的 `total_weeks`，
        // hero 句與章節標籤於是跟同屏的「N 週」講同一個數（2026-08-27 補修）。
        story = App2DevSettings.shared.planEndStoryPreview
            ? App2PlanEndStoryFixture.make(weeks: weeks)
            : nil
        #endif
    }

    /// VDOT 序列要涵蓋整期。一週 7 天，多抓一點以免起點落在窗外。
    private var vdotLimit: Int { min(max(weeks * 7 + 14, 60), 730) }

    /// 逐週回顧 —— **`GET /v2/summary/weekly` 只給單週**，整期就是逐週打
    /// （§B.3 已記：「✅ 活（逐週打）」）。
    ///
    /// 沒生成回顧的那幾週會 404，**那不是錯誤**：把它們從分母裡拿掉就好
    /// （`App2PlanEndProjection.completionRate` 的分母是讀得到的週）。
    private func weeklySummaries() async -> [WeeklySummaryV2] {
        let repository = planRepository
        let total = weeks
        return await withTaskGroup(of: WeeklySummaryV2?.self) { group in
            for week in 1...total {
                group.addTask { try? await repository.getWeeklySummary(weekOfPlan: week) }
            }
            var rows: [WeeklySummaryV2] = []
            for await row in group {
                if let row { rows.append(row) }
            }
            // 週次順序是身分（畫面上不列出來，但加總與平均要穩定可重現）。
            return rows.sorted { $0.weekOfTraining < $1.weekOfTraining }
        }
    }

    #if DEBUG
    /// 測試／預覽用：直接填入結果，不打網路（沿用 repo 既有的 `applyForTesting` 慣例）。
    func applyForTesting(summary: App2Sourced<App2PeriodSummary>?, story: App2PeriodStory? = nil) {
        self.summary = summary
        self.story = story
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif
}
