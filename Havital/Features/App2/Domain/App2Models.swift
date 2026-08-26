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
    /// 後端真的評出來了（`status == "graded"`）。
    let isGraded: Bool
    /// 後端判為正向（`dot == "positive"`）—— 首頁「最強項保底」用的就是這一欄。
    let isPositive: Bool

    init(
        id: String,
        label: String,
        value: String?,
        direction: Direction,
        verdict: String?,
        change: String? = nil,
        isNotComputed: Bool = false,
        isGraded: Bool = true,
        isPositive: Bool = false
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.direction = direction
        self.verdict = verdict
        self.change = change
        self.isNotComputed = isNotComputed
        self.isGraded = isGraded
        self.isPositive = isPositive
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

/// 今日課表卡（§3.1 倒數第 3 列；設計 dc.html「今日課表 · 輕鬆跑／節奏跑／長距離／
/// 休息日卡片」四版，＝`screens/frame-02b-noninterval.png` 上半）。
struct App2TodaySession: Equatable {
    /// `週五 · 8/14`
    let dayLabel: String
    /// `間歇訓練`
    let title: String
    /// `高強度`
    let intensityLabel: String?
    /// `12 km · 6:45/km`
    let summary: String?
    /// 分段列（熱身／節奏段／緩和；單段課只有一列「主課」）。
    /// 設計把它畫成一排帶色點的膠囊列，主課段帶課型色、暖身緩和是中性灰。
    /// payload 組不出任何一段就是空陣列，整段不出現 —— 不用 placeholder 補行。
    let segments: [App2SessionSegment]
    /// 配速結構示意。訓練詳情頁的「預計配速」圖用整份；**今日卡只有間歇課畫**
    /// （設計 dc.html「今日課表 · 間歇」右欄的趟數圖，見 `hasIntervalStructure`）。
    let structureBars: [App2SessionStructureBar]
    /// `力量 · 3 個動作`。nil = 今天沒有 supplementary 肌力項目。
    let strengthLabel: String?
    /// `day_index`（1 = 週一）。點進訓練詳情、推 Garmin 都要它。
    var dayIndex: Int = 0
    /// 結構化課型。休息日＝`.rest`（卡片改成月亮回充版式）。
    var dayType: DayType?
    /// 長距離課的補給建議框（設計 dc.html「今日課表 · 長距離卡片」）。
    /// **文案是設計稿的靜態教練建議，不是 payload 欄位**；只在真的是長距離課
    /// 且時長夠長時才出現，短課掛這句話沒有意義。
    var showsFuelingNote: Bool = false

    var isRest: Bool { dayType == .rest }

    /// 這一天有沒有衝刺趟 —— 今日卡右欄的趟數圖只有間歇課有
    /// （2026-08-26 裁決；8/25 版設計把柱狀圖從其餘三張今日卡上拿掉了）。
    var hasIntervalStructure: Bool { structureBars.contains { $0.kind == .interval } }
}

// MARK: - 訓練詳情（設計 frame-02／dc.html「課表詳細 · …」四版）

/// 訓練詳情頁的一整份投影。**全部來自本週課表 payload 的同一天**，
/// 詳情頁自己不打任何一條端點 —— 它是首頁／課表頁手上那份 `DayDetailDTO` 的第二個版面。
struct App2SessionDetail: Identifiable, Equatable {
    var id: Int { dayIndex }
    let dayIndex: Int
    /// `2026-08-25`（裝置當地日期）。推 Garmin 需要它；推不出來就不擺按鈕。
    let dateString: String?
    /// 頁首副標：`星期一 · 8/10`
    let dateTitle: String
    /// `輕鬆跑`
    let title: String
    let dayType: DayType?
    /// hero 上方的小字（設計是 `EASY RUN · Z2`）。
    /// 只有 payload 真的帶得出來才有 —— 配速區間（`pace_zone`）或強度（`target_intensity`）。
    /// 兩者都沒有就沒有這一行，**不把 `run_type` 識別字印上去**。
    let kicker: String?
    /// hero 三格：總距離 / 預計時間 / 配速變化段數。
    let distanceKm: Double?
    let durationLabel: String?
    /// 「訓練結構」header 的 `M 分鐘`。與 `durationLabel` 同一個值的另一種投影，
    /// 不另算一份。推不出來就 nil，header 只印段數。
    let durationMinutes: Int?
    let phaseCount: Int
    /// 「預計配速」示意圖。每種課型都畫得出來（2026-08-25 裁決）。
    let structureBars: [App2SessionStructureBar]
    /// 單段（勻速）課的配速帶（設計 frame-02c，2026-08-26 裁決）。
    /// 有值時「預計配速」畫配速帶而不是長條圖；多段課這裡是 `nil`。
    let paceBand: App2SessionPaceBand?
    /// 「本次訓練目標」——後端 `day_target`（已在地化）。
    let goalText: String?
    /// 目標卡下方的理由句 —— 後端 `reason`。
    let reasonText: String?
    /// 「訓練結構」逐段列。
    let segments: [App2SessionDetailSegment]
    /// 「熱適應」卡（`climate_meta`，真資料）。
    let climate: App2SessionClimate?
    /// 長距離補給建議框（同 `App2TodaySession.showsFuelingNote`，設計稿靜態文案）。
    let showsFuelingNote: Bool
    /// 跑步課才有「傳到 Garmin」（後端 push 只收 run workout）。
    let isRunSession: Bool
}

// MARK: - App2SessionPaceBand
/// 單段勻速課的「配速帶」（設計 **frame-02c**）。
///
/// 為什麼不是長條圖：一段課的長條圖只有一根柱，看不出任何「變化」，圖裡沒有資訊。
/// 配速帶把同一組數字換成「你要落在這個窗裡」——上緣是快邊界、下緣是慢邊界。
///
/// **邊界的來源**：後端 payload 目前沒有配速區間欄位（`primary` 只有 `pace`／
/// `base_pace`／`climate_adjusted_pace`，2026-08-26 dev 實測 `e1289e60f251_1`），
/// 所以邊界＝處方配速 ±15 秒、目標窗＝±10 秒。後端補上區間欄位後改讀那個欄位。
struct App2SessionPaceBand: Equatable {
    /// 帶上那顆白 pill 的處方配速（`6:50`）。
    let paceLabel: String
    /// 上緣虛線（`6:35`）。
    let fastLabel: String
    /// 下緣虛線（`7:05`）。
    let slowLabel: String
    /// 圖下中央那句的目標窗（`6:40-7:00`）。
    let windowLabel: String
    /// 圖下左（`0.0`）／右（`8.0`）。右邊推不出距離時是 `nil`，整個右欄不出現。
    let endKmLabel: String?
    /// legend chip 的名稱（`輕鬆（穩定）`）——與長條圖的標註列同一支字串。
    let legendLabel: String
}

/// 訓練詳情的「訓練結構」一列（設計：序號 ＋ 名稱 ＋ 量／配速 ＋ 一句說明）。
struct App2SessionDetailSegment: Identifiable, Equatable {
    let id: Int
    /// 1-based 序號（設計的圓形數字）。
    let index: Int
    /// `熱身`／`節奏段`／`緩和`
    let name: String
    /// `2.0 km · 6:50/km`
    let detail: String?
    /// `× 10`（間歇趟數）。
    let repeatsLabel: String?
    /// `組間休息：90 秒`／段落描述。
    let note: String?
    /// 主課段 —— 決定序號圓與底色是否上課型色。
    let isWork: Bool
}

/// 熱適應卡（`climate_meta`）。文案沿用既有的 `climate.*` 三語，不新增第二套。
struct App2SessionClimate: Equatable {
    /// `危險`
    let shortLevel: String
    /// `體感 41.2°C`；溫度缺席時 nil。
    let feelsLike: String?
    /// 後端 `reason_text`（已在地化）。
    let reason: String
    /// `heat_pressure_level` 正規化值，決定卡片顏色。
    let level: String
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

/// 結構預覽的一塊（設計 frame-02「預計配速」同一視覺家族）。
///
/// **每一種課型都畫得出來**：單段穩定課＝一整塊綠色（塊上標配速），有暖身／緩和
/// 就前後加淺色塊，間歇課是一排橘色細柱＋組間淺柱。寬度按該段的量佔比，
/// 高度按強度 —— 兩者都從 payload 的結構欄位來，沒有一段是編的。
struct App2SessionStructureBar: Identifiable, Equatable {
    enum Kind: Equatable {
        /// 組間恢復 —— 灰色矮塊，不計趟。
        case support
        /// 暖身／緩和 —— **綠色**矮塊（設計 dc.html「今日課表 · 間歇」的三色：
        /// 綠＝熱身緩和、橘＝衝刺、灰＝組間恢復）。不計趟。
        case warmup
        /// 穩定段（輕鬆跑／長跑／節奏跑的主課）—— 綠色寬塊。
        case steady
        /// 間歇的衝刺趟 —— 橘色細柱，只有它算「趟」。
        case interval
    }

    let id: Int
    let kind: Kind
    /// 0…1 的相對高度（強度）。
    let height: Double
    /// 相對寬度權重（該段的量佔比）。
    let widthWeight: Double
    /// 塊上標的配速（`7:55`）。細柱標不下，所以只有寬塊會有值。
    let paceLabel: String?
    /// 圖下方段落標註列的名稱（`輕鬆（穩定）`／`間歇`）。
    /// 只有主課段有值 —— 暖身／組間／緩和不進標註列（設計 frame-02 的圖例只列有意義的段）。
    var noteLabel: String? = nil
    /// 段落標註列右側的量（`4.0 km · 7:17/km`）。
    var noteDetail: String? = nil

    var isWork: Bool { kind == .steady || kind == .interval }
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
    case notGenerated(isCurrentWeek: Bool, targetWeek: Int)
    /// 目標週的回顧已存在，帶著它的 id 供導頁。
    case available(summaryId: String, isCurrentWeek: Bool, targetWeek: Int)

    /// 要看的是第幾週的回顧。**週日看本週、平日看上週**（`weekReviewState` 定的），
    /// 週回顧頁要拿它去打 `GET /v2/summary/weekly?week_of_plan=`。
    var targetWeek: Int {
        switch self {
        case .notGenerated(_, let week), .available(_, _, let week): return week
        }
    }
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
    /// `8/10` —— 週起點 ＋ `day_index` 現算（設計 frame-01 每卡標題是「週一 8/10」）。
    /// 後端週課表 payload 沒有 `week_start_date`，所以由裝置日曆推當週週一。
    let dateLabel: String
    /// 已在地化的課型標籤（`輕鬆跑`／`間歇跑`／`休息`），來自 `DayType.localizedName`。
    let tag: String
    /// 結構化課型。左緣色條與課型徽章的顏色由它決定 —— 不對顯示字串做詞表比對。
    /// `DayType` 是 repo 既有的課型分類（`Havital/Models/WeeklyPlan.swift`），
    /// 對應後端 `run_type` taxonomy（`domains/plan_week/generation/run_type_taxonomy.py`）。
    let dayType: DayType?
    /// 計畫值（`4.0 km · 7:17/km`）—— 量 ＋ 配速，與設計 frame-01 的「課表」行同一組內容。
    let planned: String?
    /// 當日課表敘述（後端 `day_target`：`輕鬆跑：保持舒適配速，專注於有氧建立 4 km`／
    /// 休息日的 `休息與恢復`）。設計 frame-01 的休息日只有這一行，有課日則在課表行下方。
    let description: String?
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

// MARK: - 訓練計畫總覽（設計 frame-20）

/// 訓練計畫總覽頁的一整份投影。
///
/// **週次／期別／賽事三者同源**：`GET /v2/plan/status` 取週次，並用它的
/// `current_week_plan_id` 前綴綁定 overview（`GET /v2/plan/overview` 拿回來先比對 id）。
/// 綁不上就沒有期程 —— 寧可少一段，也不要把別份計畫的階段畫成這一份的。
struct App2PlanOverview: Equatable {
    /// 目標賽事（來自 `GET /user/targets` 的主要賽事）。沒有主要賽事就整張 hero 換空狀態。
    let raceName: String?
    /// `2026-12-06`（賽事時區）。
    let raceDateLabel: String?
    /// `全馬`／`半馬`…
    let distanceLabel: String?
    /// `還有 N 週`。
    let weeksUntilRace: Int?
    /// 「現在的你」——`GET /plan/readiness/{date}` 的 `race_fitness.estimated_race_time`。
    /// 這個帳號還沒有這個量時是 nil，畫面說「尚未有預估」，不本機推一個。
    let currentEstimatedFinish: String?
    /// 「約 N km / 週」——近 4 週實際週跑量平均（`GET /summary/weekly/all`）。
    let currentWeeklyKm: Double?
    /// `2:34:00`。目標未設成績就是 nil。
    let targetTime: String?
    let currentWeek: Int?
    let totalWeeks: Int?
    /// 當前所在階段名（`建立耐力期`）。落不進任何一段就沒有。
    let currentStageName: String?
    let stages: [App2PlanStage]
    let rhythm: App2PlanRhythm

    /// 進度條落點（0…1）。週次不齊就沒有進度條。
    var progress: Double? {
        guard let currentWeek, let totalWeeks, totalWeeks > 0 else { return nil }
        return min(1, max(0, Double(currentWeek) / Double(totalWeeks)))
    }
}

/// 期程列表的一段（`training_stages[]`）。
struct App2PlanStage: Identifiable, Equatable {
    enum State: Equatable {
        case done, active, upcoming
    }

    let id: String
    /// `建立耐力`
    let name: String
    /// `先把週跑量穩到 45–50 km`——後端的 `training_focus`（已在地化）。
    let focus: String?
    let weekStart: Int
    let weekEnd: Int
    let state: State
    /// 進行中那一段走到第幾週（`5 / 6 週`）。其餘段為 nil。
    let weeksElapsed: Int?

    var weekCount: Int { max(1, weekEnd - weekStart + 1) }

    /// `W1–6`
    var weekRangeLabel: String {
        weekStart == weekEnd ? "W\(weekStart)" : "W\(weekStart)–\(weekEnd)"
    }
}

/// 訓練節奏（設計 frame-20 下半）。三格都是真值，缺就那一列不出現。
struct App2PlanRhythm: Equatable {
    /// 每週跑步天數 —— `prefer_week_days` 的長度。
    let runDaysPerWeek: Int?
    /// 長跑日 —— `prefer_week_days_longrun` 的第一天。
    let longRunDayLabel: String?
    /// 訓練方法顯示名 —— overview 的 `methodology_overview.name`（後端已在地化）。
    /// **不印 `methodology_id`**：那是識別字。
    let methodologyName: String?

    var isEmpty: Bool {
        runDaysPerWeek == nil && longRunDayLabel == nil && methodologyName == nil
    }
}

// MARK: - 賽事管理（設計 frame-12／13／14）

/// 賽事管理頁的一張賽事卡。主要賽事與支援賽事同一個型別，用 `isMain` 分。
struct App2RaceCard: Identifiable, Equatable {
    let id: String
    let name: String
    /// `2026-12-06`（賽事時區）。
    let dateLabel: String
    /// `全馬`／`半馬`…
    let distanceLabel: String
    /// 倒數天數。已過期的賽事為負數 —— 畫面只在 >= 0 時顯示倒數。
    let countdownDays: Int
    /// `2:34:00`；目標未設成績就是 nil。
    let goalTime: String?
    let isMain: Bool
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
