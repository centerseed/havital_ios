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
        static let insightVerdict = "§7-2"
        /// 端點存在但本機取不到資料。
        static let offline = "offline"
    }

    // MARK: - Public accessors

    static var trainingStatus: App2TrainingStatus { payload.trainingStatus.domain }
    static var insights: [App2Insight] { payload.insights.map(\.domain) }
    static var planWeek: App2PlanWeek { payload.planWeek.domain }
    static var records: App2Records { payload.records.domain }

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

        static let empty = Payload(
            trainingStatus: .empty,
            insights: [],
            planWeek: .empty,
            records: .empty
        )
    }

    /// **樣本不帶週數。**「第 N / M 週」是畫面上的真實斷言，只能來自
    /// `GET /v2/plan/status`；樣本只准填敘事句與軌道落點。
    /// 2026-08-25 用戶在同一屏看到目標卡「1 / 17」與狀況卡「6 / 18」，
    /// 就是因為 state/today 掛掉時整個卡連週數一起退成樣本。
    /// 欄位直接從 fixture 型別移除，這樣「把週數塞回樣本」會編不過，而不是靠註解約束。
    private struct TrainingStatusFixture: Codable {
        let headline: String
        let narrative: String?
        let trackPosition: Double

        static let empty = TrainingStatusFixture(
            headline: "—", narrative: nil, trackPosition: 0.5
        )

        var domain: App2TrainingStatus {
            App2TrainingStatus(
                headline: headline, narrative: narrative, trackPosition: trackPosition,
                currentWeek: nil, totalWeeks: nil
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
        let intensityLowMinutes: Int?
        let intensityMediumMinutes: Int?
        let intensityHighMinutes: Int?
        let days: [PlanDayFixture]

        static let empty = PlanWeekFixture(
            weekLabel: "—", totalWeeks: nil, targetDistanceKm: 0, completedDistanceKm: nil,
            intensityLowMinutes: nil, intensityMediumMinutes: nil,
            intensityHighMinutes: nil, days: []
        )

        var domain: App2PlanWeek {
            App2PlanWeek(
                weekLabel: weekLabel, totalWeeks: totalWeeks, targetDistanceKm: targetDistanceKm,
                completedDistanceKm: completedDistanceKm,
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
        let planned: String?
        let description: String?
        let actual: String?
        let temp: String?
        let isToday: Bool
        let dayType: String?

        var domain: App2PlanDay {
            App2PlanDay(
                id: id, weekdayLabel: weekdayLabel,
                dateLabel: App2PlanViewModel.dateLabel(
                    dayIndex: id, weekStart: App2PlanViewModel.currentWeekStart()
                ),
                tag: tag,
                dayType: dayType.flatMap { DayType(rawValue: $0) },
                planned: planned, description: description,
                actual: actual, temp: temp, isToday: isToday
            )
        }
    }

    private struct RecordsFixture: Codable {
        let monthDistanceKm: Double
        let monthWorkouts: Int
        let monthDeltaKm: Double?
        let ytdYear: Int?
        let ytdDistanceKm: Double?
        let ytdWorkouts: Int?
        let weeklySeries: [WeeklyBarFixture]
        let recentWorkouts: [WorkoutRowFixture]

        static let empty = RecordsFixture(
            monthDistanceKm: 0, monthWorkouts: 0, monthDeltaKm: nil,
            ytdYear: nil, ytdDistanceKm: nil, ytdWorkouts: nil,
            weeklySeries: [], recentWorkouts: []
        )

        var domain: App2Records {
            App2Records(
                monthDistanceKm: monthDistanceKm, monthWorkouts: monthWorkouts,
                monthDeltaKm: monthDeltaKm, ytdYear: ytdYear,
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

}
