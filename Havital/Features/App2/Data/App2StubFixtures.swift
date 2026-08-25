import Foundation

// MARK: - App2StubFixtures
/// Data Layer — 2.0 骨架的固定樣本資料載入器。
///
/// **這裡交出的每一筆都不是真資料。** 內容本體在
/// `Havital/Resources/App2Fixtures/app2_skeleton_stub.json`（沿用 repo 既有的
/// `Resources/*Fixtures/` 放法），Swift 這一層只負責 decode 與型別轉換。
///
/// **目標賽事卡與今日課表卡不在這裡。** 那兩張卡只渲染真資料：目標賽事來自
/// `/user/targets`、今日課表來自本週課表的今日項目；拿不到就顯示明說「還沒有」的空狀態，
/// 不拿設計稿的示範值（Hofu Marathon／2:34:00）假裝成用戶的資料。
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
        static let weekReview = "§4.2"
        static let trajectory = "§7-16"
        static let insightVerdict = "§7-2"
        static let levelBadge = "§7-1"
        static let raceCountdownPref = "§3.9a"
        /// 端點存在但本機取不到資料。
        static let offline = "offline"
    }

    // MARK: - Public accessors

    static var trainingStatus: App2TrainingStatus { payload.trainingStatus.domain }
    static var insights: [App2Insight] { payload.insights.map(\.domain) }
    static var planWeek: App2PlanWeek { payload.planWeek.domain }
    static var records: App2Records { payload.records.domain }
    static var settings: App2SettingsSnapshot { payload.settings.domain }

    /// §7-16 軌跡圖序列 —— 沒有 HTTP 出口，永遠是樣本。
    ///
    /// **不用線性內插**：兩端錨定的等差數列畫出來是一條直線，跟真實的體能軌跡
    /// 完全不像（2026-08-25 用戶在模擬器上直接點名）。設計 frame-00 畫的是
    /// 「前段爬升快、中段有起伏與小回落、接近現在時趨緩」的曲線，所以這裡手寫
    /// 一組正規化的成長剖面（0=起點、1=現在的水準），依實際週數重取樣。
    ///
    /// 預估段是緩彎而非直線：用 ease-out（`1-(1-p)^1.8`），一開始還有增益、
    /// 越接近比賽日越平 —— 與「訓練效果邊際遞減」的形狀一致。
    ///
    /// 端點落地後整段刪除。
    private static let growthProfile: [Double] = [
        0.00, 0.09, 0.17, 0.15, 0.26, 0.35,
        0.41, 0.38, 0.49, 0.58, 0.63, 0.61,
        0.70, 0.78, 0.83, 0.86
    ]

    static func trajectoryPoints(currentWeek: Int, totalWeeks: Int) -> [App2TrajectoryChart.Point] {
        let safeCurrent = max(currentWeek, 1)
        let safeTotal = max(totalWeeks, safeCurrent + 1)
        let startValue = 55.0
        let projectedEnd = 73.0
        let range = projectedEnd - startValue

        var points: [App2TrajectoryChart.Point] = []

        // 實際段：把成長剖面重取樣到 1...safeCurrent。
        for week in 1...safeCurrent {
            let position = safeCurrent > 1
                ? Double(week - 1) / Double(safeCurrent - 1)
                : 0
            points.append(
                .init(week: week, value: startValue + range * sample(position), isProjected: false)
            )
        }

        // 預估段：從「現在」的水準緩彎到比賽日的預估。
        guard safeCurrent < safeTotal else { return points }
        let current = points.last?.value ?? startValue
        for week in safeCurrent...safeTotal {
            let position = Double(week - safeCurrent) / Double(safeTotal - safeCurrent)
            let eased = 1 - pow(1 - position, 1.8)
            points.append(
                .init(
                    week: week,
                    value: current + (projectedEnd - current) * eased,
                    isProjected: true
                )
            )
        }
        return points
    }

    /// 在成長剖面上取值（`position` 0…1），兩個節點之間線性內插。
    private static func sample(_ position: Double) -> Double {
        let clamped = min(max(position, 0), 1)
        let scaled = clamped * Double(growthProfile.count - 1)
        let lower = Int(scaled.rounded(.down))
        let upper = min(lower + 1, growthProfile.count - 1)
        let fraction = scaled - Double(lower)
        return growthProfile[lower] + (growthProfile[upper] - growthProfile[lower]) * fraction
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
        let trainingStatus: TrainingStatusFixture
        let insights: [InsightFixture]
        let planWeek: PlanWeekFixture
        let records: RecordsFixture
        let settings: SettingsFixture

        static let empty = Payload(
            trainingStatus: .empty,
            insights: [],
            planWeek: .empty,
            records: .empty,
            settings: .empty
        )
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
        let dayType: String?

        var domain: App2PlanDay {
            App2PlanDay(
                id: id, weekdayLabel: weekdayLabel, tag: tag,
                dayType: dayType.flatMap { DayType(rawValue: $0) },
                summary: summary,
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
        let dayType: String?
        let distance: String
        let pace: String?
        let duration: String
        let vdot: String?

        var domain: App2WorkoutRow {
            App2WorkoutRow(
                id: id, dateLabel: dateLabel, tag: tag,
                dayType: dayType.flatMap { DayType(rawValue: $0) },
                distance: distance, pace: pace, duration: duration, vdot: vdot
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
