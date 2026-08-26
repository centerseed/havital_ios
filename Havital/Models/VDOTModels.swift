import Foundation

// VDOT Data Models
struct VDOTDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
    let weightVdot: Double?
}

struct VDOTResponse: Codable {
    let needUpdatedHrRange: Bool
    let vdots: [VDOTEntry]
    
    enum CodingKeys: String, CodingKey {
        case needUpdatedHrRange = "need_updated_hr_range"
        case vdots
    }
}

struct VDOTEntry: Codable {
    let datetime: TimeInterval
    let dynamicVdot: Double
    let paceVdot: Double?
    let liveVdot: Double?
    let weightVdot: Double?

    // MARK: - 診斷欄（`DESIGN-app2-fidelity-checklist.md` §52-4「這個值怎麼來的」）
    //
    // `GET /v2/workouts/vdots` 每一筆本來就帶這些欄位（dev 實查 2026-08-26：
    // `vdot_source`／`source`／`anchor_date`／`anchor_decision`／`confidence`／
    // `daily_count`／`evidence_through`）。app 端以前只讀分數，所以模型沒收。
    // **全部 optional**：舊版後端與舊快取沒有這些欄位時仍要解得開。
    /// `benchmark`／`personal_best`…（後端同時給 `vdot_source` 與 `source`，取前者）。
    let vdotSource: String?
    /// 錨定那一筆的日期（`YYYY-MM-DD`）。
    let anchorDate: String?
    /// 錨定決策（`weighted_16x` 等），畫面以 mono 原樣顯示。
    let anchorDecision: String?
    /// `high`／`medium`／`low`。
    let confidence: String?
    /// 進入這一天估計的證據天數（§52-4 的 `n = 9`）。
    let dailyCount: Int?
    /// 證據完整度 0…1（後端有給才畫，dev 目前未回傳）。
    let evidenceCompleteness: Double?

    var resolvedPaceVdot: Double { paceVdot ?? dynamicVdot }

    enum CodingKeys: String, CodingKey {
        case datetime
        case dynamicVdot = "dynamic_vdot"
        case paceVdot = "pace_vdot"
        case liveVdot = "live_vdot"
        case weightVdot = "weight_vdot"
        case vdotSource = "vdot_source"
        case source
        case anchorDate = "anchor_date"
        case anchorDecision = "anchor_decision"
        case confidence
        case dailyCount = "daily_count"
        case evidenceCompleteness = "evidence_completeness"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        datetime = try container.decode(TimeInterval.self, forKey: .datetime)
        dynamicVdot = try container.decode(Double.self, forKey: .dynamicVdot)
        paceVdot = try container.decodeIfPresent(Double.self, forKey: .paceVdot)
        liveVdot = try container.decodeIfPresent(Double.self, forKey: .liveVdot)
        weightVdot = try container.decodeIfPresent(Double.self, forKey: .weightVdot)
        vdotSource = try container.decodeIfPresent(String.self, forKey: .vdotSource)
            ?? container.decodeIfPresent(String.self, forKey: .source)
        anchorDate = try container.decodeIfPresent(String.self, forKey: .anchorDate)
        anchorDecision = try container.decodeIfPresent(String.self, forKey: .anchorDecision)
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence)
        // 後端的整數欄位會以浮點交出來（`health_daily.resting_heart_rate` 已經是
        // 這樣，2026-08-26 Android 先踩到）。整數欄一律先當數字讀再取整，
        // 不讓一個 `10.0` 把整包 vdots 的解碼弄掛。
        dailyCount = try container.decodeIfPresent(Double.self, forKey: .dailyCount)
            .map { Int($0.rounded()) }
        evidenceCompleteness = try container.decodeIfPresent(Double.self, forKey: .evidenceCompleteness)
    }

    /// `CodingKeys` 多了一個 decode-only 的 `source`（後端兩個欄位同義），
    /// 所以 encode 要自己寫 —— 合成版對不上的那一個 case 會讓型別不符合 `Encodable`。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(datetime, forKey: .datetime)
        try container.encode(dynamicVdot, forKey: .dynamicVdot)
        try container.encodeIfPresent(paceVdot, forKey: .paceVdot)
        try container.encodeIfPresent(liveVdot, forKey: .liveVdot)
        try container.encodeIfPresent(weightVdot, forKey: .weightVdot)
        try container.encodeIfPresent(vdotSource, forKey: .vdotSource)
        try container.encodeIfPresent(anchorDate, forKey: .anchorDate)
        try container.encodeIfPresent(anchorDecision, forKey: .anchorDecision)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(dailyCount, forKey: .dailyCount)
        try container.encodeIfPresent(evidenceCompleteness, forKey: .evidenceCompleteness)
    }

    init(
        datetime: TimeInterval,
        dynamicVdot: Double,
        paceVdot: Double? = nil,
        liveVdot: Double? = nil,
        weightVdot: Double? = nil,
        vdotSource: String? = nil,
        anchorDate: String? = nil,
        anchorDecision: String? = nil,
        confidence: String? = nil,
        dailyCount: Int? = nil,
        evidenceCompleteness: Double? = nil
    ) {
        self.datetime = datetime
        self.dynamicVdot = dynamicVdot
        self.paceVdot = paceVdot
        self.liveVdot = liveVdot
        self.weightVdot = weightVdot
        self.vdotSource = vdotSource
        self.anchorDate = anchorDate
        self.anchorDecision = anchorDecision
        self.confidence = confidence
        self.dailyCount = dailyCount
        self.evidenceCompleteness = evidenceCompleteness
    }
}
