import Foundation

// MARK: - App2StubFixtures
/// Data Layer — 2.0 骨架的固定樣本資料載入器。
///
/// **這裡交出的每一筆都不是真資料。** 內容本體在
/// `Havital/Resources/App2Fixtures/app2_skeleton_stub.json`（沿用 repo 既有的
/// `Resources/*Fixtures/` 放法），Swift 這一層只負責 decode 與型別轉換。
///
/// 兩種用途：
///
/// 1. **後端根本沒有這條端點** —— 決策鏈專屬區塊（意圖確認卡 §4.1、週回顧裁決 §4.2、
///    軌跡圖序列 §7-16、指標評級文案 §7-2）。設計文件 §2 的結論：
///    「2.0 要顯示『這一段在追什麼』，backend 現在沒有任何端點交得出來」。
/// 2. **端點在但這台裝置拿不到**（未登入／dev 無資料）—— 骨架仍要能 render，
///    ViewModel 退到樣本並在畫面上掛 `App2StubBadge`。
///
/// 情況 1 的區塊在端點落地前永遠是樣本；情況 2 一旦拿到真資料就會被取代。
/// 兩者畫面上都掛徽章，差別只在 `pendingSection` 指到的段落。
enum App2StubFixtures {

    // MARK: - Pending section labels（指向設計文件段落，畫面上會顯示）

    enum Section {
        static let intent = "§4.1"
        static let weekReview = "§4.2"
        static let trajectory = "§7-16"
        static let insightVerdict = "§7-2"
        static let levelBadge = "§7-1"
        static let raceCountdownPref = "§3.9a"
        /// 端點存在但本機取不到資料。
        static let offline = "offline"
    }

    // MARK: - Public accessors

    static var goalCard: App2GoalCard { payload.goalCard.domain }
    static var trainingStatus: App2TrainingStatus { payload.trainingStatus.domain }
    static var insights: [App2Insight] { payload.insights.map(\.domain) }
    static var todaySession: App2TodaySession { payload.todaySession.domain }
    static var intentCard: App2IntentCard { payload.intentCard.domain }
    static var planWeek: App2PlanWeek { payload.planWeek.domain }
    static var records: App2Records { payload.records.domain }
    static var settings: App2SettingsSnapshot { payload.settings.domain }

    /// §7-16 軌跡圖序列 —— 沒有 HTTP 出口，永遠是樣本。
    /// 兩端錨定（現在的 pace_vdot → 比賽日的完賽預估）線性內插，實際線帶輕微起伏
    /// 讓「實際 vs 預估」在畫面上分得開。
    static func trajectoryPoints(currentWeek: Int, totalWeeks: Int) -> [App2TrajectoryChart.Point] {
        let safeCurrent = max(currentWeek, 1)
        let safeTotal = max(totalWeeks, safeCurrent + 1)
        let startValue = 55.0
        let projectedEnd = 73.0
        let span = Double(safeTotal - 1)

        var points: [App2TrajectoryChart.Point] = []
        for week in 1...safeCurrent {
            let progress = Double(week - 1) / span
            let wobble = sin(Double(week) * 0.9) * 0.8
            points.append(
                .init(
                    week: week,
                    value: startValue + (projectedEnd - startValue) * progress * 0.9 + wobble,
                    isProjected: false
                )
            )
        }
        for week in safeCurrent...safeTotal {
            let progress = Double(week - 1) / span
            points.append(
                .init(
                    week: week,
                    value: startValue + (projectedEnd - startValue) * progress,
                    isProjected: true
                )
            )
        }
        return points
    }

    // MARK: - Loading

    private static let payload: Payload = {
        guard let url = Bundle.main.url(forResource: "app2_skeleton_stub", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            Logger.debug("[App2StubFixtures] app2_skeleton_stub.json 缺失或無法解析,退到空樣本")
            return .empty
        }
        return decoded
    }()

    // MARK: - Wire shapes（與 JSON 一一對應）

    private struct Payload: Codable {
        let goalCard: GoalCardFixture
        let trainingStatus: TrainingStatusFixture
        let insights: [InsightFixture]
        let todaySession: TodaySessionFixture
        let intentCard: IntentCardFixture
        let planWeek: PlanWeekFixture
        let records: RecordsFixture
        let settings: SettingsFixture

        static let empty = Payload(
            goalCard: .empty,
            trainingStatus: .empty,
            insights: [],
            todaySession: .empty,
            intentCard: .empty,
            planWeek: .empty,
            records: .empty,
            settings: .empty
        )
    }

    private struct GoalCardFixture: Codable {
        let raceName: String
        let raceDate: String
        let distanceLabel: String
        let stageLabel: String?
        let targetTime: String?
        let estimatedFinish: String?
        let currentWeek: Int?
        let totalWeeks: Int?

        static let empty = GoalCardFixture(
            raceName: "—", raceDate: "—", distanceLabel: "—", stageLabel: nil,
            targetTime: nil, estimatedFinish: nil, currentWeek: nil, totalWeeks: nil
        )

        var domain: App2GoalCard {
            App2GoalCard(
                raceName: raceName, raceDate: raceDate, distanceLabel: distanceLabel,
                stageLabel: stageLabel, targetTime: targetTime, estimatedFinish: estimatedFinish,
                currentWeek: currentWeek, totalWeeks: totalWeeks
            )
        }
    }

    private struct TrainingStatusFixture: Codable {
        let headline: String
        let narrative: String?
        let trackPosition: Double
        let currentWeek: Int?
        let totalWeeks: Int?

        static let empty = TrainingStatusFixture(
            headline: "—", narrative: nil, trackPosition: 0.5, currentWeek: nil, totalWeeks: nil
        )

        var domain: App2TrainingStatus {
            App2TrainingStatus(
                headline: headline, narrative: narrative, trackPosition: trackPosition,
                currentWeek: currentWeek, totalWeeks: totalWeeks
            )
        }
    }

    private struct InsightFixture: Codable {
        let id: String
        let label: String
        let value: String?
        let direction: String
        let verdict: String?

        var domain: App2Insight {
            App2Insight(
                id: id,
                label: label,
                value: value,
                direction: App2Insight.Direction(rawValue: direction) ?? .unknown,
                verdict: verdict
            )
        }
    }

    private struct TodaySessionFixture: Codable {
        let dayLabel: String
        let title: String
        let intensityLabel: String?
        let summary: String?

        static let empty = TodaySessionFixture(dayLabel: "—", title: "—", intensityLabel: nil, summary: nil)

        var domain: App2TodaySession {
            App2TodaySession(dayLabel: dayLabel, title: title, intensityLabel: intensityLabel, summary: summary)
        }
    }

    private struct IntentCardFixture: Codable {
        let pursuing: String
        let maintaining: String
        let deferring: String

        static let empty = IntentCardFixture(pursuing: "—", maintaining: "—", deferring: "—")

        var domain: App2IntentCard {
            App2IntentCard(pursuing: pursuing, maintaining: maintaining, deferring: deferring)
        }
    }

    private struct PlanWeekFixture: Codable {
        let weekLabel: String
        let totalWeeks: Int?
        let targetDistanceKm: Double
        let completedDistanceKm: Double?
        let purpose: String
        let intensityLowMinutes: Int?
        let intensityMediumMinutes: Int?
        let intensityHighMinutes: Int?
        let days: [PlanDayFixture]

        static let empty = PlanWeekFixture(
            weekLabel: "—", totalWeeks: nil, targetDistanceKm: 0, completedDistanceKm: nil,
            purpose: "—", intensityLowMinutes: nil, intensityMediumMinutes: nil,
            intensityHighMinutes: nil, days: []
        )

        var domain: App2PlanWeek {
            App2PlanWeek(
                weekLabel: weekLabel, totalWeeks: totalWeeks, targetDistanceKm: targetDistanceKm,
                completedDistanceKm: completedDistanceKm, purpose: purpose,
                intensityLowMinutes: intensityLowMinutes,
                intensityMediumMinutes: intensityMediumMinutes,
                intensityHighMinutes: intensityHighMinutes,
                days: days.map(\.domain)
            )
        }
    }

    private struct PlanDayFixture: Codable {
        let id: Int
        let weekdayLabel: String
        let tag: String
        let summary: String
        let planned: String?
        let actual: String?
        let temp: String?
        let isToday: Bool

        var domain: App2PlanDay {
            App2PlanDay(
                id: id, weekdayLabel: weekdayLabel, tag: tag, summary: summary,
                planned: planned, actual: actual, temp: temp, isToday: isToday
            )
        }
    }

    private struct RecordsFixture: Codable {
        let windowDays: Int
        let windowDistanceKm: Double
        let windowWorkouts: Int
        let ytdYear: Int?
        let ytdDistanceKm: Double?
        let ytdWorkouts: Int?
        let weeklySeries: [WeeklyBarFixture]
        let recentWorkouts: [WorkoutRowFixture]

        static let empty = RecordsFixture(
            windowDays: 30, windowDistanceKm: 0, windowWorkouts: 0,
            ytdYear: nil, ytdDistanceKm: nil, ytdWorkouts: nil,
            weeklySeries: [], recentWorkouts: []
        )

        var domain: App2Records {
            App2Records(
                windowDays: windowDays, windowDistanceKm: windowDistanceKm,
                windowWorkouts: windowWorkouts, ytdYear: ytdYear,
                ytdDistanceKm: ytdDistanceKm, ytdWorkouts: ytdWorkouts,
                weeklySeries: weeklySeries.map(\.domain),
                recentWorkouts: recentWorkouts.map(\.domain)
            )
        }
    }

    private struct WeeklyBarFixture: Codable {
        let weekStart: String
        let distanceKm: Double
        let isCurrentWeek: Bool
        let shortLabel: String

        var domain: App2WeeklyBar {
            App2WeeklyBar(
                weekStart: weekStart, distanceKm: distanceKm,
                isCurrentWeek: isCurrentWeek, shortLabel: shortLabel
            )
        }
    }

    private struct WorkoutRowFixture: Codable {
        let id: String
        let dateLabel: String
        let tag: String?
        let distance: String
        let pace: String?
        let duration: String
        let vdot: String?

        var domain: App2WorkoutRow {
            App2WorkoutRow(
                id: id, dateLabel: dateLabel, tag: tag, distance: distance,
                pace: pace, duration: duration, vdot: vdot
            )
        }
    }

    private struct SettingsFixture: Codable {
        let accountEmail: String?
        let subscriptionLabel: String?
        let dataSources: [DataSourceFixture]
        let weeklyDistanceKm: Double?
        let trainingDays: [String]
        let raceCountdownDays: Int

        static let empty = SettingsFixture(
            accountEmail: nil, subscriptionLabel: nil, dataSources: [],
            weeklyDistanceKm: nil, trainingDays: [], raceCountdownDays: 30
        )

        var domain: App2SettingsSnapshot {
            App2SettingsSnapshot(
                accountEmail: accountEmail, subscriptionLabel: subscriptionLabel,
                dataSources: dataSources.map(\.domain), weeklyDistanceKm: weeklyDistanceKm,
                trainingDays: trainingDays, raceCountdownDays: raceCountdownDays
            )
        }
    }

    private struct DataSourceFixture: Codable {
        let name: String
        let statusLabel: String
        let isConnected: Bool

        var domain: App2DataSourceStatus {
            App2DataSourceStatus(name: name, statusLabel: statusLabel, isConnected: isConnected)
        }
    }
}
