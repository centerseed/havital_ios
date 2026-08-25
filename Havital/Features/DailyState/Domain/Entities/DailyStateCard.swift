import Foundation

// MARK: - DailyStateCard
/// Domain Entity — 今日狀態卡片。camelCase，無 Codable（不耦合序列化格式）。
struct DailyStateCard: Equatable {
    enum Lens: String { case pre, post }

    let lens: Lens
    let source: String
    let headline: String
    let factType: String?
    let narrativeText: String?        // nil = 鎖/無
    let collapsedReason: String?      // T-0241 收合卡融合理由句;nil = 免費/護欄退 headline
    let chips: [String]               // 佐證(已格式化,可空)
    let causeChips: [String]          // 可能因素(質性)
    let mileageProgression: String?   // 跑量漸進行（免費可見）
    let actionLine: String?           // 「12K easy · 6:45」
    let rizoScenario: String?         // 交棒 scenario(本版僅記錄,不導航)
    let divergenceFlagText: String?
    let isPaid: Bool
    let isLocked: Bool
    let upsellReason: String?
    /// T-0142 指標跑當日即時校準(偵測到今天合格全力跑才有值)。
    let benchmarkCalibration: SameDayBenchmarkCalibration?
    /// 已評級的指標列。空陣列 = 端點沒帶(舊版後端),不是「全部尚未計算」。
    let insights: [DailyStateInsight]

    var hasChip: Bool { !chips.isEmpty }

    /// 收合卡第一眼主句:理由句在 → 取代 headline 位置(不同時顯示兩句);否則退 headline。
    var displayHeadline: String {
        if let reason = collapsedReason, !reason.isEmpty { return reason }
        return headline
    }
}

// MARK: - DailyStateInsight
/// Domain Entity — 已評級的指標列(`GET /v2/state/today` 的 `insights[]`)。
///
/// **評級與文案都在後端做完**:`label`／`verdict`／`change` 已在地化,`arrow`／`dot`
/// 是後端的判斷。app 端只做「有沒有值」的呈現分支,不自己推方向、不自己取名。
struct DailyStateInsight: Equatable {
    enum Arrow: String, Equatable { case up, down, flat, unknown }

    let key: String
    let label: String
    /// `64`／`23 km`;`nil` = 這一列還沒有值。
    let valueText: String?
    let arrow: Arrow
    let verdict: String?
    let change: String?
    let evidence: String?
    /// 後端對這一列的正負判定（`positive`／`neutral`／`unknown`）。
    ///
    /// **這是評級層的結論，app 端不自己推。** 2.0 首頁只展開最值得看的幾列
    /// （`App2HomeViewModel.highlightedInsights`），「哪一列算強項」用的就是這一欄，
    /// 不拿 `verdict` 的字面去比對詞表。
    var dot: String? = nil
    /// `graded`／`insufficient_data`／`not_computed`。
    let status: String?

    /// 後端明說「還沒算」。畫面要說出這件事,不是靜靜地灰掉。
    var isNotComputed: Bool { status == "not_computed" }
    /// 後端真的評出來了（`insufficient_data`／`not_computed` 都不算）。
    var isGraded: Bool { status == "graded" }
}

// MARK: - SameDayBenchmarkCalibration (T-0142)
/// 今日校準卡的 domain entity:渲染用 payload + apply 動作所需欄位。
struct SameDayBenchmarkCalibration: Equatable {
    let workoutId: String
    let workoutDate: String
    let benchmarkDistanceM: Double
    let benchmarkDurationS: Double
    let overviewId: String        // apply → confirm 寫 registry overview_id
    let weekOfTraining: Int       // schedule-next → 算目標週(current+2)
    let canScheduleNext: Bool
    /// 複用既有 BenchmarkCalibrationCard 的 payload(before/after 完賽時間 + VDOT)。
    let payload: BenchmarkCalibrationPayload
}
