import Foundation

// MARK: - AnyCodableValue
/// 通用可編碼值類型，用於處理 API 回傳的任意 JSON 結構
/// 適用於預留擴展欄位，如 trainingLoadAnalysis、personalizedRecommendations 等
enum AnyCodableValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let arrayValue = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayValue)
            return
        }

        if let dictionaryValue = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dictionaryValue)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "AnyCodableValue cannot decode value"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }

    // MARK: - Convenience Accessors

    /// 取得布林值（如果是布林類型）
    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// 取得整數值（如果是整數類型）
    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    /// 取得浮點數值（如果是數字類型）
    var doubleValue: Double? {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        default: return nil
        }
    }

    /// 取得字串值（如果是字串類型）
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// 取得陣列值（如果是陣列類型）
    var arrayValue: [AnyCodableValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// 取得字典值（如果是字典類型）
    var dictionaryValue: [String: AnyCodableValue]? {
        if case .dictionary(let value) = self { return value }
        return nil
    }

    /// 是否為 null
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}
