import Foundation

// MARK: - API Parser Protocol

/// JSON 解析介面，依據指定的 Model 進行解析
protocol APIParser {
    /// 將 JSON 數據解析為指定類型
    /// - Parameters:
    ///   - type: 目標 Codable 類型
    ///   - data: JSON 原始數據
    /// - Returns: 解析後的對象
    func parse<T: Codable>(_ type: T.Type, from data: Data) throws -> T
}

// MARK: - Default API Parser

/// 預設的 API 解析器實現
struct DefaultAPIParser: APIParser {
    static let shared = DefaultAPIParser()
    
    private let decoder: JSONDecoder
    
    init() {
        self.decoder = JSONDecoder()
        configureDateDecoding()
    }
    
    func parse<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            // 主要解析邏輯
            return try decoder.decode(T.self, from: data)
            
        } catch let decodingError as DecodingError {
            // 詳細的解析錯誤處理
            let errorDetail = analyzeDecodingError(decodingError, for: type, data: data)
            Logger.error("JSON 解析失敗: \(errorDetail.description)")
            
            // 嘗試容錯處理
            if let fallbackResult = try? attemptFallbackParsing(type, from: data) {
                Logger.debug("使用容錯機制成功解析")
                return fallbackResult
            }
            
            throw ParseError.decodingFailed(errorDetail)
        }
    }
    
    // MARK: - Private Methods
    
    private func configureDateDecoding() {
        // 設置日期解析策略
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // 嘗試多種日期格式
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // 嘗試不含微秒的格式
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // 嘗試 RFC 2822 格式
            let rfc2822Formatter = DateFormatter()
            rfc2822Formatter.locale = Locale(identifier: "en_US_POSIX")
            rfc2822Formatter.timeZone = TimeZone(secondsFromGMT: 0)
            rfc2822Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            
            if let date = rfc2822Formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "無法解析日期字串: \(dateString)"
                )
            )
        }
    }
    
    private func analyzeDecodingError<T>(_ error: DecodingError, for type: T.Type, data: Data) -> ParseErrorDetail {
        let responsePreview = String(data: data.prefix(500), encoding: .utf8) ?? "無法預覽"
        
        switch error {
        case .keyNotFound(let key, let context):
            return ParseErrorDetail(
                type: .missingKey,
                description: "缺少必要欄位: \(key.stringValue)",
                missingField: key.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                expectedType: String(describing: type),
                responsePreview: responsePreview
            )
            
        case .valueNotFound(let valueType, let context):
            return ParseErrorDetail(
                type: .nullValue,
                description: "欄位值為 null，期望: \(valueType)",
                missingField: context.codingPath.last?.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                expectedType: String(describing: type),
                responsePreview: responsePreview
            )
            
        case .typeMismatch(let expectedType, let context):
            return ParseErrorDetail(
                type: .typeMismatch,
                description: "類型不匹配，期望: \(expectedType)",
                missingField: context.codingPath.last?.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                expectedType: String(describing: type),
                responsePreview: responsePreview
            )
            
        case .dataCorrupted(let context):
            return ParseErrorDetail(
                type: .dataCorrupted,
                description: "數據損壞或格式錯誤",
                missingField: context.codingPath.last?.stringValue,
                codingPath: context.codingPath.map { $0.stringValue }.joined(separator: "."),
                expectedType: String(describing: type),
                responsePreview: responsePreview
            )
            
        @unknown default:
            return ParseErrorDetail(
                type: .unknown,
                description: "未知解析錯誤",
                missingField: nil,
                codingPath: "",
                expectedType: String(describing: type),
                responsePreview: responsePreview
            )
        }
    }
    
    private func attemptFallbackParsing<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        // 嘗試解析包裝在 APIResponse 中的數據
        if extractWrappedType(type) != nil {
            let apiResponse = try decoder.decode(APIResponse<AnyDecodable>.self, from: data)
            let wrappedData = apiResponse.data
            let reEncodedData = try JSONEncoder().encode(wrappedData)
            return try decoder.decode(T.self, from: reEncodedData)
        }
        
        // 嘗試直接解析 data 欄位
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataField = jsonObject["data"] {
            let dataJSON = try JSONSerialization.data(withJSONObject: dataField)
            return try decoder.decode(T.self, from: dataJSON)
        }
        
        throw ParseError.fallbackFailed("所有容錯機制都失敗")
    }
    
    private func extractWrappedType<T>(_ type: T.Type) -> Any.Type? {
        // 檢查是否為簡單類型，需要包裝處理
        let typeString = String(describing: type)
        if typeString.contains("Response") {
            return nil
        }
        return type
    }
}

// MARK: - Parse Errors

enum ParseError: Error, LocalizedError {
    case decodingFailed(ParseErrorDetail)
    case fallbackFailed(String)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .decodingFailed(let detail):
            return "JSON 解析失敗: \(detail.description)"
        case .fallbackFailed(let message):
            return "容錯解析失敗: \(message)"
        case .invalidData(let message):
            return "無效數據: \(message)"
        }
    }
}

struct ParseErrorDetail {
    enum ErrorType {
        case missingKey
        case nullValue
        case typeMismatch
        case dataCorrupted
        case unknown
    }
    
    let type: ErrorType
    let description: String
    let missingField: String?
    let codingPath: String
    let expectedType: String
    let responsePreview: String
    
    var debugDescription: String {
        return """
        解析錯誤詳情:
        - 類型: \(type)
        - 描述: \(description)
        - 缺少欄位: \(missingField ?? "未知")
        - 編碼路徑: \(codingPath.isEmpty ? "根層級" : codingPath)
        - 期望類型: \(expectedType)
        - 回應預覽: \(responsePreview)
        """
    }
}

// MARK: - Helper Types

/// 用於解析任意 JSON 結構的輔助類型
struct AnyDecodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "無法解析的數據類型"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is ():
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyDecodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyDecodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "無法編碼的數據類型"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}