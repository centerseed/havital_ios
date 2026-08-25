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
            headline: headline, narrative: narrative, trackPosition: 0.5,
            currentWeek: currentWeek, totalWeeks: totalWeeks
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
        App2TodaySession(dayLabel: "週二 · 8/25", title: title, intensityLabel: intensity, summary: summary)
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

    private func planDay(_ index: Int, type: DayType, planned: String?, isToday: Bool = false) -> App2PlanDay {
        App2PlanDay(
            id: index, weekdayLabel: "D\(index)", tag: type.localizedName, dayType: type,
            summary: "s", planned: planned, actual: nil, temp: nil, isToday: isToday
        )
    }

    // MARK: - 今日課表卡 ／ 訓練狀況卡（優先）

    func test_home_fullState_renders() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            goalCard: App2Sourced(goal(), origin: live),
            trainingStatus: App2Sourced(status(), origin: live),
            insights: App2Sourced(insights(count: 5), origin: stub),
            todaySession: App2Sourced(session(), origin: live)
        )
        render(App2HomeView(viewModel: vm), name: "home-full")
    }

    /// 全空：沒有目標賽事、沒有今日課、沒有狀態卡、沒有指標。
    func test_home_emptyState_renders() {
        let vm = App2HomeViewModel()
        vm.applyForTesting()
        render(App2HomeView(viewModel: vm), name: "home-empty")
    }

    /// 休息日：課型有字、強度與內容行都沒有。
    func test_home_restDaySession_renders() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            trainingStatus: App2Sourced(status(), origin: live),
            insights: App2Sourced(insights(count: 5), origin: stub),
            todaySession: App2Sourced(
                session(title: DayType.rest.localizedName, intensity: nil, summary: nil),
                origin: live
            )
        )
        render(App2HomeView(viewModel: vm), name: "home-rest-day")
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
            todaySession: App2Sourced(
                session(title: String(repeating: "長距離輕鬆跑", count: 4)),
                origin: live
            )
        )
        render(App2HomeView(viewModel: vm), name: "home-long-strings")
    }

    /// 只有部分指標（後端只算出兩列）。
    func test_home_partialInsights_render() {
        let vm = App2HomeViewModel()
        vm.applyForTesting(
            trainingStatus: App2Sourced(status(), origin: live),
            insights: App2Sourced(insights(count: 2), origin: live),
            todaySession: App2Sourced(session(), origin: live)
        )
        render(App2HomeView(viewModel: vm), name: "home-partial-insights")
    }

    // MARK: - 軌跡圖退化態

    /// 第 1 週：實際序列只有一個點。線畫不出來（兩點才成線），但「現在」的錨點
    /// 與預估虛線仍要出現，而且不 crash。
    func test_trajectoryChart_firstWeek_singleActualPoint_renders() {
        let points = App2StubFixtures.trajectoryPoints(currentWeek: 1, totalWeeks: 18)
        XCTAssertEqual(points.filter { !$0.isProjected }.count, 1)
        XCTAssertGreaterThan(points.filter(\.isProjected).count, 1)
        render(
            App2TrajectoryChart(points: points, currentWeek: 1).padding(),
            name: "trajectory-week-1", height: 140
        )
    }

    /// 最末週：實際段鋪滿整份課表。
    /// 樣本產生器把總週數夾成 `max(total, current + 1)`（避免分母為 0），
    /// 所以還會留一小段預估尾巴 —— 這是現況契約，鎖住它才看得出何時被改。
    func test_trajectoryChart_lastWeek_actualCoversWholePlan() {
        let points = App2StubFixtures.trajectoryPoints(currentWeek: 18, totalWeeks: 18)
        XCTAssertEqual(points.filter { !$0.isProjected }.count, 18)
        XCTAssertEqual(points.filter(\.isProjected).map(\.week), [18, 19])
        render(
            App2TrajectoryChart(points: points, currentWeek: 18).padding(),
            name: "trajectory-last-week", height: 140
        )
    }

    func test_trajectoryChart_emptySeries_renders() {
        render(
            App2TrajectoryChart(points: [], currentWeek: nil).padding(),
            name: "trajectory-empty", height: 140
        )
    }

    /// 值全部一樣（分母會退化成 0）→ 仍要畫得出來。
    func test_trajectoryChart_flatSeries_renders() {
        let points = (1...6).map {
            App2TrajectoryChart.Point(week: $0, value: 60, isProjected: $0 > 3)
        }
        render(
            App2TrajectoryChart(points: points, currentWeek: 3).padding(),
            name: "trajectory-flat", height: 140
        )
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
        render(App2PlanView(onOpenSettings: {}, avatarInitial: "P", viewModel: vm), name: "plan-all-rest")
    }

    func test_plan_completionZeroAndFull_render() {
        let days = (1...3).map { planDay($0, type: .easy, planned: "10.0 km", isToday: $0 == 1) }

        let zero = App2PlanViewModel()
        zero.applyForTesting(week: App2Sourced(planWeek(days: days, target: 30, completed: 0), origin: live))
        render(App2PlanView(onOpenSettings: {}, avatarInitial: "P", viewModel: zero), name: "plan-0-of-3")

        let full = App2PlanViewModel()
        full.applyForTesting(week: App2Sourced(planWeek(days: days, target: 30, completed: 30), origin: live))
        render(App2PlanView(onOpenSettings: {}, avatarInitial: "P", viewModel: full), name: "plan-3-of-3")
    }

    /// 本週課表尚未產生 → 空狀態，不是樣本。
    func test_plan_noWeek_rendersEmptyState() {
        let vm = App2PlanViewModel()
        vm.applyForTesting(week: nil)
        render(App2PlanView(onOpenSettings: {}, avatarInitial: "P", viewModel: vm), name: "plan-empty")
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
        render(App2PlanView(onOpenSettings: {}, avatarInitial: "P", viewModel: vm), name: "plan-last-week")
    }
}
