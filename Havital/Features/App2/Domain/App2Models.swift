import Foundation

// MARK: - App2DataOrigin
/// Domain Layer — 這格畫面的資料是真的還是樣本。
///
/// 2.0 的畫面骨架同時含「端點已存在、直接接」與「決策鏈端點尚未落地、先擺樣本」
/// 兩種區塊（`DESIGN-app2-decision-chain-api.md` §2 的兩個結論）。把來源做成型別，
/// 是為了畫面上一眼看得出哪一塊還沒有後端 —— 不是註解，是可 render 的事實。
enum App2DataOrigin: Equatable {
    /// 真實端點。`endpoint` 是設計文件 §3 對照表裡那一條。
    case live(endpoint: String)

    /// 樣本資料。`pendingSection` 指向設計文件裡描述該缺口的段落。
    case stub(pendingSection: String)

    var isStub: Bool {
        if case .stub = self { return true }
        return false
    }

    /// 標籤上顯示的來源說明（給 stub 徽章用）。
    var pendingSectionLabel: String? {
        if case .stub(let section) = self { return section }
        return nil
    }
}

// MARK: - App2Sourced
/// 一筆值 ＋ 它的來源。畫面直接讀 `origin` 決定要不要掛 stub 徽章。
struct App2Sourced<Value> {
    let value: Value
    let origin: App2DataOrigin

    init(_ value: Value, origin: App2DataOrigin) {
        self.value = value
        self.origin = origin
    }
}

// MARK: - 首頁（§3.1／§3.1a）

/// 目標賽事卡（§3.1 第 2–4 列；race_run 變體）。
struct App2GoalCard: Equatable {
    let raceName: String
    /// 已格式化的當地日期字串（`2026-12-06`）。
    let raceDate: String
    /// 距離標籤（`全馬`／`半馬`…）。
    let distanceLabel: String
    /// 目前所在訓練階段（`基礎期`）。nil = overview 未帶。
    let stageLabel: String?
    /// `2:34:00`。nil = 目標未設成績。
    let targetTime: String?
    /// `2:41:30`，來自 readiness 的 `race_fitness.estimated_race_time`。
    let estimatedFinish: String?
    let currentWeek: Int?
    let totalWeeks: Int?
}

/// 訓練狀況卡（§3.1a）。
struct App2TrainingStatus: Equatable {
    /// `StateCard.headline`。
    let headline: String
    /// `StateCard.narrative_text`；免費用戶為 nil（§3.1 paywall 註記）。
    let narrative: String?
    /// 軌道條落點，0（落後）～1（超乎預期）。
    let trackPosition: Double
    let currentWeek: Int?
    let totalWeeks: Int?
}

/// 指標網格一格（§3.1a `insights[]`）。
///
/// **producer 是 `GET /v2/state/today` 的 `insights[]`**，不是
/// `GET /v2/athlete-state/metrics`。後者依規格只交 envelope、不評級也不渲染句子
/// （ME-INV-05），所以綁它的畫面永遠沒有 `verdict`／`arrow` ——2026-08-25 在 dev
/// 上實測到的「整排灰 icon ＋ 小點」就是這件事，設計文件 §3.1a 那一列的判定有誤。
/// `state/today` 交出來的是已評級、已在地化的列（`label`／`arrow`／`verdict`／
/// `change`／`dot`／`status`），app 端不再自己推導。
struct App2Insight: Identifiable, Equatable {
    let id: String
    /// 指標名（`能力基準`／`訓練量`）。後端已在地化。
    let label: String
    /// `64`／`23 km`；nil = 這一列還沒有值。
    let value: String?
    /// 方向箭頭（後端的 `arrow`）。
    let direction: Direction
    /// 評級文案（`上升`／`尚未計算`）。後端已在地化。
    let verdict: String?
    /// `23 vs 上週 0 km` 這種對照句；nil = 後端沒帶。
    let change: String?
    /// 後端明說 `not_computed` —— 畫面要說出「尚未計算」，不是靜靜地灰掉。
    let isNotComputed: Bool

    init(
        id: String,
        label: String,
        value: String?,
        direction: Direction,
        verdict: String?,
        change: String? = nil,
        isNotComputed: Bool = false
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.direction = direction
        self.verdict = verdict
        self.change = change
        self.isNotComputed = isNotComputed
    }

    enum Direction: String, Equatable {
        case up, down, flat, unknown
    }
}

extension App2Insight {
    /// 設計的指標膠囊是「每個指標一個 icon」（frame-00 那一排），icon 綁指標身分、
    /// 顏色綁方向。兩者分開，才不會在 `not_computed` 時整排變成同一顆灰點。
    var symbolName: String {
        switch id {
        case "capability_baseline": return "waveform.path.ecg"
        case "recovery_index":      return "arrow.triangle.2.circlepath"
        case "aerobic_endurance":   return "chart.bar.fill"
        case "speed_endurance":     return "bolt.fill"
        case "heat_sensitivity":    return "thermometer.medium"
        case "consistency":         return "calendar"
        case "weekly_volume":       return "figure.run"
        case "load_index":          return "gauge.with.dots.needle.50percent"
        case "threshold_endurance": return "speedometer"
        default:                    return "circle.fill"
        }
    }

    var arrowGlyph: String {
        switch direction {
        case .up:      return "↑"
        case .down:    return "↓"
        case .flat:    return "→"
        case .unknown: return "·"
        }
    }
}

/// 今日課表卡（§3.1 倒數第 3 列；設計 frame-00 下半）。
struct App2TodaySession: Equatable {
    /// `週五 · 8/14`
    let dayLabel: String
    /// `間歇訓練`
    let title: String
    /// `高強度`
    let intensityLabel: String?
    /// `12 km · 6:45/km`
    let summary: String?
    /// 分段表（熱身／衝刺／恢復／緩和）。payload 沒有 segments 就是空陣列，
    /// 畫面整段不出現 —— 不用 placeholder 補行。
    let segments: [App2SessionSegment]
    /// 右側「趟數 × N 趟」結構預覽的柱子。空 = 這堂課的結構畫不出來，不畫。
    let structureBars: [App2SessionStructureBar]
    /// `力量 · 3 個動作`。nil = 今天沒有 supplementary 肌力項目。
    let strengthLabel: String?
}

/// 今日課表卡的一行分段（設計 frame-00：左名稱、右值）。
struct App2SessionSegment: Identifiable, Equatable {
    /// 分段在課表裡的位置（穩定排序用）。
    let id: Int
    /// 已在地化的分段名（`熱身`／`衝刺`／`恢復`／`緩和`）。
    let name: String
    /// `400m @ 4:30`／`10 分鐘`。組不出來就不要有這一行（呼叫端已過濾）。
    let detail: String
    /// 這一段算不算「主課」——決定結構預覽的柱色。
    let isWork: Bool
}

/// 結構預覽的一根柱（設計 frame-02「預計配速」同一視覺家族）。
struct App2SessionStructureBar: Identifiable, Equatable {
    let id: Int
    /// 0…1 的相對高度。
    let height: Double
    let isWork: Bool
}

/// 今日課表卡的四種狀態。
///
/// **「本週課表尚未產生」是一個斷言，不是預設值。** 只有 `/v2/plan/status` 明說
/// `current_week_plan_id` 是 nil 才准講這句；讀取失敗、被取消、解析失敗一律走
/// `.unavailable`（畫面說「暫時讀不到」＋可重試）。2026-08-25 用戶在同一屏同時
/// 看到「本週課表尚未產生」與課表頁的一整週課，就是把失敗當成「沒有」的結果。
enum App2TodaySessionState: Equatable {
    /// 今天有課（或今天是休息日，由 `App2TodaySession.title` 表達）。
    case session(App2TodaySession)
    /// 後端明說本週還沒有課表。
    case notGenerated
    /// 本週課表在，但今天不在 `days` 裡。
    case noSessionToday
    /// 讀不到 —— 不得宣稱「尚未產生」。
    case unavailable
}

/// 週回顧 CTA 的狀態（設計 dc.html:5112 的 `reviewLabel`／`reviewSub`）。
///
/// 標籤依「今天是不是週日」切換目標週：週日＝本週、週一～六＝上週。
/// 目標週的回顧已存在時整張卡改成「查看回顧」。
enum App2WeekReviewState: Equatable {
    /// 目標週的回顧還沒產生。`isCurrentWeek` = 目標週是本週（週日）。
    case notGenerated(isCurrentWeek: Bool)
    /// 目標週的回顧已存在，帶著它的 id 供導頁。
    case available(summaryId: String, isCurrentWeek: Bool)
}

// MARK: - 課表（§3.3）

struct App2PlanWeek: Equatable {
    /// 已在地化的週次（`第 7 週`）。
    let weekLabel: String
    let totalWeeks: Int?
    /// 週目標量（km）。
    let targetDistanceKm: Double
    /// 已完成量（km），來自 `/v2/workouts`，不在週課表 payload 裡（§3.3 第 2 列）。
    let completedDistanceKm: Double?
    /// 強度分鐘分布 low/medium/high。
    let intensityLowMinutes: Int?
    let intensityMediumMinutes: Int?
    let intensityHighMinutes: Int?
    let days: [App2PlanDay]
}

struct App2PlanDay: Identifiable, Equatable {
    let id: Int
    /// `週一`
    let weekdayLabel: String
    /// 已在地化的課型標籤（`輕鬆跑`／`間歇跑`／`休息`），來自 `DayType.localizedName`。
    let tag: String
    /// 結構化課型。左緣色條與課型徽章的顏色由它決定 —— 不對顯示字串做詞表比對。
    /// `DayType` 是 repo 既有的課型分類（`Havital/Models/WeeklyPlan.swift`），
    /// 對應後端 `run_type` taxonomy（`domains/plan_week/generation/run_type_taxonomy.py`）。
    let dayType: DayType?
    /// 一行摘要。
    let summary: String
    /// 計畫值（`12 km`）。
    let planned: String?
    /// 實際值（`11.4 km`）；nil = 尚未執行。
    let actual: String?
    /// 體感溫度（§3.3 `d.temp`），來自週課表 doc 的 climate 投影。
    let temp: String?
    let isToday: Bool
}

// MARK: - 紀錄（§3.6）

struct App2Records: Equatable {
    /// 本月（裝置當地日曆月）跑量與次數 —— 設計 frame-10 的 hero 左欄。
    let monthDistanceKm: Double
    let monthWorkouts: Int
    /// 本月 − 上月（km）。上月不在已取回的紀錄範圍內時為 nil，該列就不顯示，
    /// 不把「沒取到」畫成「持平」。
    let monthDeltaKm: Double?
    /// 今年累積（`year_to_date`，T-0304 落地）。
    let ytdYear: Int?
    let ytdDistanceKm: Double?
    let ytdWorkouts: Int?
    /// 近 8 週序列（`weekly_series`，舊→新，含當週）。
    let weeklySeries: [App2WeeklyBar]
    let recentWorkouts: [App2WorkoutRow]
}

struct App2WeeklyBar: Identifiable, Equatable {
    var id: String { weekStart }
    let weekStart: String
    let distanceKm: Double
    let isCurrentWeek: Bool
    /// `8/18` 這種短標。
    let shortLabel: String
}

struct App2WorkoutRow: Identifiable, Equatable {
    let id: String
    /// `8/22`
    let dateLabel: String
    /// 已在地化的課型標籤，來自 row 的 `training_type`（§3.6 末列：後端已抬到頂層）。
    let tag: String?
    /// 結構化課型（同 `App2PlanDay.dayType`）：徽章與左緣色條的顏色由它決定。
    let dayType: DayType?
    /// `12.4 km`
    let distance: String
    /// `4:42/km`
    let pace: String?
    /// `58:21`
    let duration: String
    /// `dynamic_vdot`
    let vdot: String?
}

// MARK: - 設定（§3.9a）

struct App2SettingsSnapshot: Equatable {
    let accountEmail: String?
    /// 訂閱狀態顯示字（`試用中 · 剩 6 天`）。
    let subscriptionLabel: String?
    /// 資料來源連接狀態。
    let dataSources: [App2DataSourceStatus]
    /// 意圖週量旋鈕當前值（km）。
    let weeklyDistanceKm: Double?
    /// 訓練日偏好。
    let trainingDays: [String]
    /// 賽事倒數卡提前天數。§3.9a 註明現況無此偏好欄位 → 樣本。
    let raceCountdownDays: Int
}

struct App2DataSourceStatus: Identifiable, Equatable {
    var id: String { name }
    let name: String
    /// `已連結 · 同步中`／`未連結`
    let statusLabel: String
    let isConnected: Bool
}
