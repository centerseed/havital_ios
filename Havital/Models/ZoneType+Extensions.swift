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
    /// 本地化名稱
    var localizedName: String {
        switch self {
        case .anaerobic: return L10n.Training.Zone.anaerobic.localized
        case .easy: return L10n.Training.Zone.easy.localized
        case .interval: return L10n.Training.Zone.interval.localized
        case .marathon: return L10n.Training.Zone.marathon.localized
        case .recovery: return L10n.Training.Zone.recovery.localized
        case .threshold: return L10n.Training.Zone.threshold.localized
        }
    }
    
    /// 中文名稱（已棄用，請使用 localizedName）
    @available(*, deprecated, message: "Use localizedName instead")
    var chineseName: String {
        return localizedName
    }

    /// 英文名稱（對應 rawValue）
    var englishName: String { rawValue }
}
