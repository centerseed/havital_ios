import Foundation

// MARK: - WeeklyPlanV2 Entity
/// 週課表 V2 - Domain Layer 業務實體
/// 用於 Weekly Plan V2 API 的統一響應格式
/// ✅ 符合 Codable 以支援本地緩存
struct WeeklyPlanV2: Codable, Equatable {

    // MARK: - 元數據

    /// 週課表 ID（格式: {overview_id}_{week_number}）
    let id: String

    /// 用戶 ID
    let uid: String

    // MARK: - 計畫關聯

    /// 關聯的訓練概覽 ID (PlanOverviewV2)
    let activeTrainingId: String

    /// 訓練週次 (1-indexed)
    let weekOfTraining: Int

    // MARK: - 雙維度欄位

    /// 目標類型（race_run, beginner, maintenance）
    let targetType: String

    /// 方法論 ID（paceriz, complete_10k, aerobic_endurance, speed_endurance）
    let methodologyId: String

    // MARK: - 課表數據

    /// 週課表詳細數據（LLM 生成的完整課表）
    /// 使用 PlanData 包裝以支援 Codable
    let plan: PlanData

    // MARK: - 時間戳

    /// 創建時間
    let createdAt: Date?

    /// 更新時間
    let updatedAt: Date?

    // MARK: - Computed Properties

    /// 是否為賽事目標
    var isRaceRunTarget: Bool {
        return targetType == "race_run"
    }

    /// 是否為初心者目標
    var isBeginnerTarget: Bool {
        return targetType == "beginner"
    }

    /// 是否為維持目標
    var isMaintenanceTarget: Bool {
        return targetType == "maintenance"
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case activeTrainingId = "active_training_id"
        case weekOfTraining = "week_of_training"
        case targetType = "target_type"
        case methodologyId = "methodology_id"
        case plan
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - PlanData
/// 週課表數據包裝器
/// 支援任意 JSON 結構的課表數據
struct PlanData: Codable, Equatable {

    /// 原始課表數據
    let rawData: [String: AnyCodableValue]

    // MARK: - Initialization

    init(rawData: [String: AnyCodableValue]) {
        self.rawData = rawData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodableValue].self)
        self.rawData = dict
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawData)
    }

    // MARK: - Convenience Methods

    /// 獲取指定鍵的字串值
    func string(forKey key: String) -> String? {
        return rawData[key]?.stringValue
    }

    /// 獲取指定鍵的整數值
    func int(forKey key: String) -> Int? {
        return rawData[key]?.intValue
    }

    /// 獲取指定鍵的雙精度值
    func double(forKey key: String) -> Double? {
        return rawData[key]?.doubleValue
    }

    /// 獲取指定鍵的布林值
    func bool(forKey key: String) -> Bool? {
        return rawData[key]?.boolValue
    }

    /// 獲取指定鍵的陣列值
    func array(forKey key: String) -> [AnyCodableValue]? {
        return rawData[key]?.arrayValue
    }

    /// 獲取指定鍵的字典值
    func dictionary(forKey key: String) -> [String: AnyCodableValue]? {
        return rawData[key]?.dictionaryValue
    }
}

// MARK: - AnyCodableValue
/// 支援任意 JSON 值類型的編解碼包裝器
enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodableValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "無法解碼 AnyCodableValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    // MARK: - Convenience Properties

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var arrayValue: [AnyCodableValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var dictionaryValue: [String: AnyCodableValue]? {
        if case .dictionary(let value) = self { return value }
        return nil
    }
}
