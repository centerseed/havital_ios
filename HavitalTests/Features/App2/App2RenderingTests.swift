import SwiftUI
import XCTest
@testable import paceriz_dev

/// 2.0 畫面在各種資料狀態下畫得出來、不 crash。
///
/// 走 repo 既有的 view 測試作法（`RizoHistoryResumeRenderingTests`）：
/// `UIHostingController` 實際跑一次 layout ＋ draw，畫面存成 XCTAttachment
/// 供人工複核。這裡不做像素斷言 —— 判準是「這個狀態渲染得出來」。
///
/// 重點狀態（**用戶截圖點名的退化態**）：第 1 週時實際序列只有一個點，
/// 實際線縮成一顆點、預估虛線佔滿全寬。
@MainActor
final class App2RenderingTests: XCTestCase {

    // MARK: - Render helper

    @discardableResult
    private func render<V: View>(_ view: V, name: String, height: CGFloat = 844) -> UIImage {
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: height)
        host.view.backgroundColor = .systemBackground
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: host.view.bounds.size)
        let image = renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0, name)
        let attachment = XCTAttachment(image: image)
        attachment.name = "t0306-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // 收尾要把畫面貼進票面時，用 `APP2_EVIDENCE_DIR=<path>` 跑這個 target，
        // 圖就會直接落在那個資料夾（不設就只有 xcresult 附件，行為不變）。
        if let dir = ProcessInfo.processInfo.environment["APP2_EVIDENCE_DIR"],
           let png = image.pngData() {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return image
    }

    // MARK: - Fixtures

    private func status(
        headline: String = "在軌道上，恢復再顧一下",
        narrative: String? = "你正在變強，但恢復落後了。",
        currentWeek: Int? = 5,
        totalWeeks: Int? = 22
    ) -> App2TrainingStatus {
        App2TrainingStatus(
            headline: headline, narrative: narrative, mileageProgression: nil,
            trackPosition: 0.5, currentWeek: currentWeek, totalWeeks: totalWeeks
        )
    }

    private func goal() -> App2GoalCard {
        App2GoalCard(
            raceName: "2026 台北馬拉松", raceDate: "2026-12-20", distanceLabel: "全馬",
            stageLabel: nil, targetTime: "4:00:00", estimatedFinish: nil,
            currentWeek: 1, totalWeeks: 17
        )
    }

    private func session(
        title: String = "長距離輕鬆跑",
        intensity: String? = "輕鬆",
        summary: String? = "9.0 km · 7:55/km"
    ) -> App2TodaySession {
        App2TodaySession(
            dayLabel: "週二 · 8/25", title: title, intensityLabel: intensity, summary: summary,
            segments: [], structureBars: [], strengthLabel: nil
        )
    }

    private func insights(count: Int) -> [App2Insight] {
        let ids = ["capability_baseline", "recovery_index", "aerobic_endurance",
                   "speed_endurance", "heat_sensitivity"]
        return ids.prefix(count).map {
            App2Insight(id: $0, label: $0, value: nil, direction: .unknown, verdict: nil)
        }
    }

    private let live = App2DataOrigin.live(endpoint: "test")
    private let stub = App2DataOrigin.stub(pendingSection: "§7-16")

    private func planWeek(
        days: [App2PlanDay],
        target: Double = 30,
        completed: Double? = 0,
        weekLabel: String = "第 1 週",
        totalWeeks: Int? = 18
    ) -> App2PlanWeek {
        App2PlanWeek(
            weekLabel: weekLabel, totalWeeks: totalWeeks, targetDistanceKm: target,
            completedDistanceKm: completed,
            intensityLowMinutes: nil, intensityMediumMinutes: nil, intensityHighMinutes: nil,
            days: days
        )
    }

    private func planDay(
        _ index: Int,
        type: DayType,
        planned: String?,
        description: String? = nil,
        isToday: Bool = false
    ) -> App2PlanDay {
        App2PlanDay(
            id: index, weekdayLabel: "D\(index)", dateLabel: "8/\(index)",
            tag: type.localizedName, dayType: type,
            planned: planned, description: description,
            actual: nil, temp: nil, isToday: isToday
        )
    }

    // MARK: - 今日課表卡 ／ 訓練狀況卡（優先）

    func test_home_fullState_renders() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            goalCard: App2Sourced(goal(), origin: live),
            trainingStatus: App2Sourced(status(), origin: live),
            insights: App2Sourced(insights(count: 5), origin: stub),
            todayState: .session(session())
        )
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()), name: "home-full")
    }

    /// 全空：沒有目標賽事、沒有今日課、沒有狀態卡、沒有指標。
    func test_home_emptyState_renders() {
        let vm = App2HomeViewModel()
        vm.applyForTesting()
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()), name: "home-empty")
    }

    /// 休息日：課型有字、強度與內容行都沒有。
    func test_home_restDaySession_renders() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            trainingStatus: App2Sourced(status(), origin: live),
            insights: App2Sourced(insights(count: 5), origin: stub),
            todayState: .session(
                session(title: DayType.rest.localizedName, intensity: nil, summary: nil)
            )
        )
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()), name: "home-rest-day")
    }

    /// 超長 headline（兩行以上）＋ 超長課型名：不得把卡片撐破或把字吃掉。
    func test_home_longStrings_render() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            goalCard: App2Sourced(goal(), origin: live),
            trainingStatus: App2Sourced(
                status(
                    headline: String(repeating: "這一週的訓練狀況相當複雜，", count: 6),
                    narrative: String(repeating: "敘事句也可能很長。", count: 10)
                ),
                origin: live
            ),
            insights: App2Sourced(insights(count: 5), origin: stub),
            todayState: .session(
                session(title: String(repeating: "長距離輕鬆跑", count: 4))
            )
        )
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()), name: "home-long-strings")
    }

    /// 只有部分指標（後端只算出兩列）。
    func test_home_partialInsights_render() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            trainingStatus: App2Sourced(status(), origin: live),
            insights: App2Sourced(insights(count: 2), origin: live),
            todayState: .session(session())
        )
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()), name: "home-partial-insights")
    }

    /// dev `a60e2c6cb83a_1` 的質課日（day_index 5）：熱身 ＋ 穩定段 ＋ 6×200m ＋ 恢復 ＋ 緩和。
    /// 用**真的 payload** 走 `todaySession(...)` 投影，驗證完整版今日課表卡
    /// （分段表 ＋ 右側「趟數 × N 趟」結構預覽）畫得出來。
    func test_home_qualityDaySession_rendersSegmentsAndStructure() throws {
        let json = """
        { "day_index": 5, "day_target": "組合訓練", "reason": "基礎期第一週",
          "warmup": { "distance_km": 1.0, "pace": "7:55" },
          "cooldown": { "distance_km": 1.0, "pace": "7:55" },
          "primary": { "run_type": "steady_intervals", "distance_km": 4.2,
            "target_intensity": "high",
            "segments": [
              { "kind": "steady", "distance_km": 3.0, "pace": "7:55" },
              { "kind": "interval", "repeats": 6,
                "work": { "distance_m": 200, "pace": "5:25" },
                "recovery": { "duration_seconds": 90 } } ] } }
        """
        let day = TrainingSessionMapper.toEntity(
            from: try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        )
        let session = try XCTUnwrap(
            App2HomeViewModel.todaySession(days: [day], todayIndex: 5, dayLabel: "星期五 · 8/29")
        )
        XCTAssertEqual(session.segments.count, 5)
        XCTAssertFalse(session.structureBars.isEmpty)

        let vm = App2HomeViewModel()
        vm.applyForTesting(
            goalCard: App2Sourced(goal(), origin: live),
            trainingStatus: App2Sourced(status(currentWeek: 1, totalWeeks: 17), origin: live),
            insights: App2Sourced(insights(count: 5), origin: live),
            todayState: .session(session),
            weekReview: .notGenerated(isCurrentWeek: false, targetWeek: 0),
            rizoOpeningLine: "今天安排休息日，請好好放鬆，本週訓練完成 0/3。"
        )
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()),
               name: "today-card-quality-day", height: 1400)
    }

    /// 單段輕鬆跑：卡片上有一列分段（「主課 9.0 km · 7:55/km」），
    /// 並且**仍然要有配速結構圖**（一整塊綠色穩定段，塊上標配速）交給訓練詳情頁。
    /// 2026-08-25 用戶裁決：結構圖不是間歇專屬。
    func test_home_singleSegmentSession_rendersPaceBlock() throws {
        let json = """
        { "day_index": 2, "day_target": "長距離輕鬆跑", "reason": "有氧基礎",
          "primary": { "run_type": "lsd", "distance_km": 9.0, "pace": "7:55",
            "target_intensity": "low" } }
        """
        let day = TrainingSessionMapper.toEntity(
            from: try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        )
        let session = try XCTUnwrap(
            App2HomeViewModel.todaySession(days: [day], todayIndex: 2, dayLabel: "週二 · 8/25")
        )
        XCTAssertEqual(session.segments.count, 1)
        XCTAssertEqual(session.segments.first?.detail, "9.0 km · 7:55/km")
        XCTAssertEqual(session.structureBars.count, 1)
        XCTAssertEqual(session.structureBars.first?.paceLabel, "7:55")

        let vm = App2HomeViewModel()
        vm.applyForTesting(
            goalCard: App2Sourced(goal(), origin: live),
            trainingStatus: App2Sourced(status(currentWeek: 1, totalWeeks: 17), origin: live),
            insights: App2Sourced(insights(count: 5), origin: live),
            todayState: .session(session),
            weekReview: .notGenerated(isCurrentWeek: false, targetWeek: 0),
            rizoOpeningLine: "今天長跑訓練請按照計畫進行。"
        )
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()),
               name: "today-card-easy-run", height: 1400)
    }

    func test_weeklyVolumeChart_emptyAndAllZero_render() {
        render(App2WeeklyVolumeChart(bars: []).padding(), name: "weekly-empty", height: 140)
        let zeros = (0..<8).map {
            App2WeeklyBar(
                weekStart: "2026-07-0\($0)", distanceKm: 0,
                isCurrentWeek: $0 == 7, shortLabel: "7/\($0 + 1)"
            )
        }
        render(App2WeeklyVolumeChart(bars: zeros).padding(), name: "weekly-all-zero", height: 140)
    }

    // MARK: - 課表頁

    func test_plan_allRestWeek_renders() {
        let vm = App2PlanViewModel()
        let days = (1...7).map { planDay($0, type: .rest, planned: nil, isToday: $0 == 3) }
        vm.applyForTesting(week: App2Sourced(planWeek(days: days, target: 0, completed: nil), origin: live))
        render(App2PlanView(viewModel: vm), name: "plan-all-rest")
    }

    func test_plan_completionZeroAndFull_render() {
        let days = (1...3).map { planDay($0, type: .easy, planned: "10.0 km", isToday: $0 == 1) }

        let zero = App2PlanViewModel()
        zero.applyForTesting(week: App2Sourced(planWeek(days: days, target: 30, completed: 0), origin: live))
        render(App2PlanView(viewModel: zero), name: "plan-0-of-3")

        let full = App2PlanViewModel()
        full.applyForTesting(week: App2Sourced(planWeek(days: days, target: 30, completed: 30), origin: live))
        render(App2PlanView(viewModel: full), name: "plan-3-of-3")
    }

    /// 本週課表尚未產生 → 空狀態，不是樣本。
    func test_plan_noWeek_rendersEmptyState() {
        let vm = App2PlanViewModel()
        vm.applyForTesting(week: nil)
        render(App2PlanView(viewModel: vm), name: "plan-empty")
    }

    // MARK: - 訓練計畫總覽（設計 frame-20）

    private func planOverview(
        raceName: String? = "松本マラソン 2026",
        estimate: String? = "4:12:30",
        weeklyKm: Double? = 32,
        stages: [App2PlanStage] = App2RenderingTests.sampleStages,
        milestones: [App2PlanMilestone] = App2RenderingTests.sampleMilestones,
        rhythm: App2PlanRhythm = App2PlanRhythm(
            runDaysPerWeek: 4, longRunDayLabel: "週日", methodologyName: "Paceriz 平衡訓練法"
        )
    ) -> App2PlanOverview {
        App2PlanOverview(
            raceName: raceName,
            raceDateLabel: raceName == nil ? nil : "2026-12-06",
            distanceLabel: raceName == nil ? nil : "全馬",
            weeksUntilRace: raceName == nil ? nil : 17,
            currentEstimatedFinish: estimate,
            currentWeeklyKm: weeklyKm,
            targetTime: raceName == nil ? nil : "4:00:00",
            currentWeek: raceName == nil ? nil : 5,
            totalWeeks: raceName == nil ? nil : 22,
            currentStageName: stages.first(where: { $0.state == .active })?.name,
            stages: stages,
            milestones: milestones,
            rhythm: rhythm
        )
    }

    private static let sampleMilestones: [App2PlanMilestone] = [
        App2PlanMilestone(week: 2, title: "5K 測試跑", description: "確認目前的體能基準", isKey: false),
        App2PlanMilestone(week: 6, title: "比賽週", description: "目標賽事", isKey: true)
    ]

    private static let sampleStages: [App2PlanStage] = [
        App2PlanStage(id: "s1", name: "建立耐力", focus: "先把週跑量穩到 45–50 km",
                      weekStart: 1, weekEnd: 6, state: .active, weeksElapsed: 5),
        App2PlanStage(id: "s2", name: "練出速耐力", focus: "加入節奏跑與閾值訓練",
                      weekStart: 7, weekEnd: 14, state: .upcoming, weeksElapsed: nil),
        App2PlanStage(id: "s3", name: "減量收尾", focus: "降量、養精神",
                      weekStart: 15, weekEnd: 22, state: .upcoming, weeksElapsed: nil)
    ]

    func test_planOverview_full_renders() {
        let vm = App2PlanOverviewViewModel()
        vm.applyForTesting(overview: App2Sourced(planOverview(), origin: live))
        render(App2PlanOverviewView(onClose: {}, viewModel: vm), name: "plan-overview-full")
    }

    /// 沒有主要賽事、沒有期程、沒有節奏偏好 —— 每一格都要能空著畫。
    func test_planOverview_empty_renders() {
        let vm = App2PlanOverviewViewModel()
        vm.applyForTesting(
            overview: App2Sourced(
                planOverview(
                    raceName: nil, estimate: nil, weeklyKm: nil, stages: [], milestones: [],
                    rhythm: App2PlanRhythm(
                        runDaysPerWeek: nil, longRunDayLabel: nil, methodologyName: nil
                    )
                ),
                origin: live
            )
        )
        render(App2PlanOverviewView(onClose: {}, viewModel: vm), name: "plan-overview-empty")
    }

    /// overview 與本週課表不同源：期程整段換成說明，不畫別份計畫的階段。
    func test_planOverview_stagesUnbound_renders() {
        let vm = App2PlanOverviewViewModel()
        vm.applyForTesting(
            overview: App2Sourced(planOverview(stages: []), origin: live),
            stagesUnbound: true
        )
        render(App2PlanOverviewView(onClose: {}, viewModel: vm), name: "plan-overview-unbound")
    }

    /// 長字串：賽名、階段名與 focus 都塞爆 390pt 寬時不得截掉別人或推爆版面。
    func test_planOverview_longStrings_render() {
        let long = String(repeating: "超長賽事名稱", count: 6)
        let vm = App2PlanOverviewViewModel()
        vm.applyForTesting(
            overview: App2Sourced(
                planOverview(
                    raceName: long,
                    stages: [
                        App2PlanStage(
                            id: "s1", name: String(repeating: "建立耐力", count: 4),
                            focus: String(repeating: "先把週跑量穩到 45–50 km，", count: 4),
                            weekStart: 1, weekEnd: 6, state: .active, weeksElapsed: 5
                        )
                    ],
                    rhythm: App2PlanRhythm(
                        runDaysPerWeek: 7,
                        longRunDayLabel: "週日",
                        methodologyName: String(repeating: "Paceriz 平衡訓練法", count: 3)
                    )
                ),
                origin: live
            )
        )
        render(App2PlanOverviewView(onClose: {}, viewModel: vm), name: "plan-overview-long")
    }

    // MARK: - 賽事管理（設計 frame-12／13／14）

    private func raceTarget(
        id: String,
        name: String,
        km: Int,
        days: Int,
        isMain: Bool,
        targetTime: Int = 14_400
    ) -> Target {
        Target(
            id: id, type: "race_run", name: name, distanceKm: km,
            targetTime: targetTime, targetPace: "5:41",
            raceDate: Int(Date().addingTimeInterval(Double(days) * 86_400).timeIntervalSince1970),
            isMainRace: isMain, trainingWeeks: 16, timezone: "Asia/Taipei", raceId: nil
        )
    }

    func test_raceManagement_mainAndSupports_render() {
        let vm = App2RaceManagementViewModel()
        vm.applyForTesting(targets: [
            raceTarget(id: "m", name: "Hofu Marathon", km: 42, days: 114, isMain: true),
            raceTarget(id: "s1", name: "秋季 10K 挑戰賽", km: 10, days: 37, isMain: false,
                       targetTime: 2_340),
            raceTarget(id: "s2", name: "台北半程馬拉松", km: 21, days: 72, isMain: false,
                       targetTime: 4_500)
        ])
        render(App2RaceManagementView(onClose: {}, viewModel: vm), name: "races-full")
    }

    /// 一場賽事都沒有：主要賽事是虛線 CTA，支援賽事是「尚無支援賽事」。
    func test_raceManagement_empty_renders() {
        let vm = App2RaceManagementViewModel()
        vm.applyForTesting(targets: [])
        render(App2RaceManagementView(onClose: {}, viewModel: vm), name: "races-empty")
    }

    /// 長賽名 ＋ 已過期的支援賽事（倒數是負的，畫面要說「已結束」）。
    func test_raceManagement_longNameAndPastRace_render() {
        let vm = App2RaceManagementViewModel()
        vm.applyForTesting(targets: [
            raceTarget(id: "m", name: String(repeating: "超長賽事名稱", count: 5),
                       km: 42, days: 200, isMain: true),
            raceTarget(id: "s1", name: "上週跑完的練習賽", km: 10, days: -5, isMain: false,
                       targetTime: 0)
        ])
        render(App2RaceManagementView(onClose: {}, viewModel: vm), name: "races-long")
    }

    func test_raceEditSheet_newAndEditing_render() {
        render(
            App2RaceEditSheet(
                form: App2RaceForm(),
                isSaving: false,
                onSave: { _ in }, onDelete: { _ in }, onClose: {}
            ),
            name: "race-form-new"
        )

        var editing = App2RaceForm()
        editing.targetId = "m"
        editing.name = "Hofu Marathon"
        editing.distanceKey = "42.195"
        editing.hours = 2
        editing.minutes = 34
        editing.makeMain = true
        editing.isCurrentMain = true
        render(
            App2RaceEditSheet(
                form: editing,
                isSaving: false,
                onSave: { _ in }, onDelete: { _ in }, onClose: {}
            ),
            name: "race-form-editing-main"
        )
    }

    func test_raceDatabase_resultsAndStates_render() {
        let events = ["東京マラソン", "大阪マラソン", "神戸マラソン"].enumerated().map { index, name in
            RaceEvent(
                raceId: "jp_\(index)", name: name, region: "jp",
                eventDate: Date().addingTimeInterval(Double(100 + index * 30) * 86_400),
                city: "東京", location: nil,
                distances: [RaceDistance(distanceKm: 42.195, name: "マラソン")],
                entryStatus: nil, isCurated: true, courseType: nil, tags: []
            )
        }

        let filled = App2RaceDatabaseViewModel()
        filled.applyForTesting(results: events)
        render(
            App2RaceDatabaseView(onPick: { _, _ in }, onClose: {}, viewModel: filled),
            name: "race-db-results"
        )

        let empty = App2RaceDatabaseViewModel()
        empty.applyForTesting(results: [])
        render(
            App2RaceDatabaseView(onPick: { _, _ in }, onClose: {}, viewModel: empty),
            name: "race-db-empty"
        )

        // 讀不到 ≠ 沒有符合的賽事。
        let broken = App2RaceDatabaseViewModel()
        broken.applyForTesting(results: [], isUnavailable: true)
        render(
            App2RaceDatabaseView(onPick: { _, _ in }, onClose: {}, viewModel: broken),
            name: "race-db-unavailable"
        )
    }

    /// 最末週：週次標籤與總週數相同，切換鍵仍是停用態。
    func test_plan_lastWeek_renders() {
        let vm = App2PlanViewModel()
        let days = (1...7).map { planDay($0, type: .easy, planned: "5.0 km") }
        vm.applyForTesting(
            week: App2Sourced(
                planWeek(days: days, target: 35, completed: 35, weekLabel: "第 18 週", totalWeeks: 18),
                origin: live
            )
        )
        render(App2PlanView(viewModel: vm), name: "plan-last-week")
    }

    // MARK: - 今日卡狀態 chip（T-0352 owner path）

    /// 走真實 owner 佈線：view 呼叫的是 `viewModel.todayPillState(isRest:)`，
    /// 完成訊號由 VM 從 `todayCompletedWorkout` 讀（與完成列同源）。
    /// VM 帶今天的完成紀錄 → chip 不顯示（完成資訊由完成列獨佔，
    /// 2026-08-31 使用者裁決）。
    func test_home_todayPill_hiddenWithCompletedRun_ownerPath() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            todayState: .session(session()),
            todayCompletedWorkout: completedRun()
        )
        XCTAssertNil(vm.todayPillState(isRest: false))
    }

    /// 對照組：同一條 owner 佈線、沒有完成紀錄 → 維持「今天還沒跑」。
    func test_home_todayPill_staysTodo_withoutCompletedRun() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(todayState: .session(session()))
        let pill = vm.todayPillState(isRest: false)
        XCTAssertEqual(pill?.showsCheck, false)
        XCTAssertEqual(pill?.textKey, L10n.App2.Home.todayTodo)
    }

    /// 休息日優先：即使今天有完成紀錄，休息日 chip 仍是「安排休息」。
    func test_home_todayPill_restDay_winsOverCompletedRun() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            todayState: .session(session(title: DayType.rest.localizedName, intensity: nil, summary: nil)),
            todayCompletedWorkout: completedRun()
        )
        let pill = vm.todayPillState(isRest: true)
        XCTAssertEqual(pill?.showsCheck, true)
        XCTAssertEqual(pill?.textKey, L10n.App2.Home.todayRest)
    }

    /// 完成態的整卡 render smoke（附件供人工複核）。
    func test_home_completedRun_renders() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            goalCard: App2Sourced(goal(), origin: live),
            trainingStatus: App2Sourced(status(), origin: live),
            insights: App2Sourced(insights(count: 3), origin: stub),
            todayState: .session(session()),
            todayCompletedWorkout: completedRun()
        )
        render(App2HomeView(onOpenSettings: {}, viewModel: vm, achievementsViewModel: PersonalAchievementsViewModel()), name: "home-completed-run")
    }

    /// 渲染層回歸（外審 E08/E11 的後繼）：畫出來的 chip 兩顯示態必須互異；
    /// done 態不再有 chip（owner-path 測試斷言 nil），視覺比對只剩 todo/rest。
    func test_home_todayPill_renderedStates_differ() {
        let doneVM = App2HomeViewModel()
        doneVM.applyForTesting(todayState: .session(session()), todayCompletedWorkout: completedRun())
        let todoVM = App2HomeViewModel()
        todoVM.applyForTesting(todayState: .session(session()))

        guard let todoPill = todoVM.todayPillState(isRest: false),
              let restPill = doneVM.todayPillState(isRest: true) else {
            XCTFail("todo 與 rest 態必須有 chip")
            return
        }
        let todo = render(App2TodayStatusPill(pill: todoPill), name: "pill-todo", height: 60)
        let rest = render(App2TodayStatusPill(pill: restPill), name: "pill-rest", height: 60)
        XCTAssertNotEqual(todo.pngData(), rest.pngData(), "還沒跑與休息是不同 chip")
    }

    private func completedRun() -> WorkoutV2 {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return WorkoutV2(
            id: "t0352-run", provider: "garmin", activityType: "running",
            startTimeUtc: formatter.string(from: Date()), endTimeUtc: nil,
            durationSeconds: 1800, distanceMeters: 5000,
            distanceDisplay: nil, distanceUnit: nil, deviceName: nil,
            basicMetrics: nil, advancedMetrics: nil, createdAt: nil,
            schemaVersion: nil, storagePath: nil, dailyPlanSummary: nil,
            aiSummary: nil, shareCardContent: nil
        )
    }

    // MARK: - 運動詳情趨勢圖（T-0356）

    /// 缺陷原型（2026-08-31 用戶截圖）：一根 GPS 慢點讓 min/max 域把配速壓成
    /// 平線。robust 域畫出來必須與 naive 域不同（趨勢重新可見）。
    func test_workoutTrend_paceOutlier_robustDomainChangesPicture() {
        var pace = (0..<100).map { 330.0 + 30 * sin(Double($0) / 8) }
        pace.append(1800)
        let robust = render(
            App2Sparkline(points: pace, tint: .blue, isInverted: true, usesRobustBounds: true),
            name: "trend-pace-robust", height: 72
        )
        let naive = render(
            App2Sparkline(points: pace, tint: .blue, isInverted: true, usesRobustBounds: false),
            name: "trend-pace-naive", height: 72
        )
        XCTAssertNotEqual(robust.pngData(), naive.pngData(), "robust 域必須改變配速圖的形狀")
    }

    /// 刻度必須真的畫出來：帶 tickFormatter 的圖與不帶的圖不同。
    /// formatter 用 trendCard 實際接的那一個（配速＝projection 的 formatPace）。
    func test_workoutTrend_ticksRendered() {
        let pace = (0..<40).map { 330.0 + Double($0 % 5) * 12 }
        let withTicks = render(
            App2Sparkline(points: pace, tint: .blue, isInverted: true,
                          tickFormatter: App2WorkoutDetailProjection.trendTickFormatter(
                              for: .pace, unitSystem: .metric
                          ),
                          usesRobustBounds: true),
            name: "trend-ticks-on", height: 72
        )
        let withoutTicks = render(
            App2Sparkline(points: pace, tint: .blue, isInverted: true, usesRobustBounds: true),
            name: "trend-ticks-off", height: 72
        )
        XCTAssertNotEqual(withTicks.pngData(), withoutTicks.pngData(), "刻度必須實際渲染")
    }

    /// percentile 退化（大量等值＋一根離群值）走 min/max fallback：
    /// 夾邊值仍畫在邊界，畫面不得塌成平線。
    func test_workoutTrend_degenerateDomain_stillDrawsOutlier() {
        let degenerate = Array(repeating: 360.0, count: 100) + [1800.0]
        let flat = Array(repeating: 360.0, count: 101)
        let withOutlier = render(
            App2Sparkline(points: degenerate, tint: .blue, isInverted: true, usesRobustBounds: true),
            name: "trend-degenerate-outlier", height: 72
        )
        let flatOnly = render(
            App2Sparkline(points: flat, tint: .blue, isInverted: true, usesRobustBounds: true),
            name: "trend-degenerate-flat", height: 72
        )
        XCTAssertNotEqual(withOutlier.pngData(), flatOnly.pngData(), "退化域下離群值仍要畫出來")
    }
}
