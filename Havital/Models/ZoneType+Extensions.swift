import Foundation
import SwiftUI

/// 強度區間類型
enum ZoneType: String, Codable, CaseIterable {
    case anaerobic
    case easy
    case interval
    case marathon
    case recovery
    case threshold
}

extension ZoneType {
    /// 中文名稱
    var chineseName: String {
        switch self {
        case .anaerobic: return "無氧"
        case .easy: return "輕鬆"
        case .interval: return "間歇"
        case .marathon: return "馬拉松"
        case .recovery: return "恢復"
        case .threshold: return "閾值"
        }
    }

    /// 英文名稱（對應 rawValue）
    var englishName: String { rawValue }
}
