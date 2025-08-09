import Foundation

// MARK: - Safe Number Property Wrapper

/// 安全的數字解析 Property Wrapper，處理 API 返回的不穩定數字類型
@propertyWrapper
struct SafeNumber<T: Numeric & Codable>: Codable {
    private let _value: T?
    
    var wrappedValue: T? {
        return _value
    }
    
    var projectedValue: T {
        return _value ?? T.zero
    }
    
    init(wrappedValue: T?) {
        self._value = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // 處理 null 值
        if container.decodeNil() {
            _value = nil
            return
        }
        
        // 嘗試多種數字解析策略
        _value = try SafeNumber.parseNumber(from: container)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(_value)
    }
    
    // MARK: - Private Methods
    
    private static func parseNumber(from container: SingleValueDecodingContainer) throws -> T? {
        // 策略 1: 直接解析目標類型
        if let directValue = try? container.decode(T.self) {
            return directValue
        }
        
        // 策略 2: 從 String 轉換
        if let stringValue = try? container.decode(String.self) {
            if let convertedValue = convertFromString(stringValue) {
                return convertedValue
            }
        }
        
        // 策略 3: 從其他數字類型轉換
        if T.self == Double.self || T.self == Float.self {
            // 浮點數轉換策略
            return try parseFloatingPoint(from: container)
        } else {
            // 整數轉換策略
            return try parseInteger(from: container)
        }
    }
    
    private static func convertFromString(_ stringValue: String) -> T? {
        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if T.self == Double.self {
            return Double(trimmed) as? T
        } else if T.self == Float.self {
            return Float(trimmed) as? T
        } else if T.self == Int.self {
            return Int(trimmed) as? T
        } else if T.self == Int64.self {
            return Int64(trimmed) as? T
        } else if T.self == Int32.self {
            return Int32(trimmed) as? T
        }
        
        return nil
    }
    
    private static func parseFloatingPoint(from container: SingleValueDecodingContainer) throws -> T? {
        // 嘗試從 Int 轉換為浮點數
        if let intValue = try? container.decode(Int.self) {
            if T.self == Double.self {
                return Double(intValue) as? T
            } else if T.self == Float.self {
                return Float(intValue) as? T
            }
        }
        
        // 嘗試從 Double 轉換
        if let doubleValue = try? container.decode(Double.self) {
            if T.self == Float.self {
                return Float(doubleValue) as? T
            }
            return doubleValue as? T
        }
        
        // 嘗試從 Decimal 轉換
        if let decimalValue = try? container.decode(Decimal.self) {
            if T.self == Double.self {
                return NSDecimalNumber(decimal: decimalValue).doubleValue as? T
            } else if T.self == Float.self {
                return NSDecimalNumber(decimal: decimalValue).floatValue as? T
            }
        }
        
        return nil
    }
    
    private static func parseInteger(from container: SingleValueDecodingContainer) throws -> T? {
        // 嘗試從 Double 轉換為整數
        if let doubleValue = try? container.decode(Double.self) {
            if T.self == Int.self {
                return Int(doubleValue) as? T
            } else if T.self == Int64.self {
                return Int64(doubleValue) as? T
            } else if T.self == Int32.self {
                return Int32(doubleValue) as? T
            }
        }
        
        // 嘗試從其他整數類型轉換
        if let int64Value = try? container.decode(Int64.self) {
            if T.self == Int.self {
                return Int(int64Value) as? T
            } else if T.self == Int32.self {
                return Int32(int64Value) as? T
            }
            return int64Value as? T
        }
        
        return nil
    }
}

// MARK: - Numeric Extension

extension Numeric {
    static var zero: Self {
        return 0 as! Self
    }
}

// MARK: - Convenient Type Aliases
// NOTE: These type aliases are commented out because WorkoutV2Models.swift 
// uses wrapper structs with the same names for backward compatibility

// typealias SafeDouble = SafeNumber<Double>
// typealias SafeFloat = SafeNumber<Float>
// typealias SafeInt = SafeNumber<Int>
// typealias SafeInt64 = SafeNumber<Int64>
// typealias SafeInt32 = SafeNumber<Int32>

// MARK: - Usage Examples & Migration Helper

/*
 使用範例:

 // 舊方式 (複雜)
 struct OldMetrics: Codable {
     private let _avgHeartRate: SafeInt?
     var avgHeartRate: Int? { _avgHeartRate?.value }
     
     enum CodingKeys: String, CodingKey {
         case _avgHeartRate = "avg_heart_rate"
     }
 }

 // 新方式 (簡潔)
 struct NewMetrics: Codable {
     @SafeNumber var avgHeartRate: Int?
     @SafeNumber var distance: Double?
     @SafeNumber var calories: Int?
     
     enum CodingKeys: String, CodingKey {
         case avgHeartRate = "avg_heart_rate"
         case distance
         case calories
     }
     
     // 獲取值的方式:
     // - 可選值: metrics.avgHeartRate (Int?)
     // - 默認值: metrics.$avgHeartRate (Int, 如果nil則為0)
 }
*/

// MARK: - Migration Utilities

struct SafeNumberMigration {
    /// 協助從舊的 SafeDouble/SafeInt 遷移到新的 @SafeNumber
    static func migrate<T: Numeric & Codable>(
        oldValue: T?,
        to newType: T.Type
    ) -> SafeNumber<T> {
        return SafeNumber(wrappedValue: oldValue)
    }
    
    /// 批量遷移數值數據
    static func migrateMetrics<T: Numeric & Codable>(
        _ values: [String: Any],
        expecting type: T.Type
    ) -> [String: SafeNumber<T>] {
        var result: [String: SafeNumber<T>] = [:]
        
        for (key, value) in values {
            if let numericValue = convertToNumeric(value, type: type) {
                result[key] = SafeNumber(wrappedValue: numericValue)
            } else {
                result[key] = SafeNumber(wrappedValue: nil)
            }
        }
        
        return result
    }
    
    private static func convertToNumeric<T: Numeric & Codable>(_ value: Any, type: T.Type) -> T? {
        if let directValue = value as? T {
            return directValue
        }
        
        if let stringValue = value as? String {
            if T.self == Double.self {
                return Double(stringValue) as? T
            } else if T.self == Int.self {
                return Int(stringValue) as? T
            }
        }
        
        if let doubleValue = value as? Double {
            if T.self == Int.self {
                return Int(doubleValue) as? T
            }
            return doubleValue as? T
        }
        
        if let intValue = value as? Int {
            if T.self == Double.self {
                return Double(intValue) as? T
            }
            return intValue as? T
        }
        
        return nil
    }
}

// MARK: - Debugging & Logging

extension SafeNumber {
    var debugDescription: String {
        if let value = _value {
            return "\(T.self)(\(value))"
        } else {
            return "\(T.self)(nil)"
        }
    }
    
    func logParsingInfo() {
        if let value = _value {
            Logger.debug("SafeNumber<\(T.self)> 成功解析: \(value)")
        } else {
            Logger.debug("SafeNumber<\(T.self)> 解析為 nil")
        }
    }
}