import Foundation
import SwiftUI

/// BackfillPromptView 的 ViewModel
///
/// 職責：
/// - 管理提示畫面的狀態
/// - 協調與 OnboardingBackfillCoordinator 的互動
/// - 處理用戶的同意/跳過選擇
class BackfillPromptViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 資料來源類型
    let dataSource: DataSourceType

    /// 目標距離（用於後續導航）
    let targetDistance: Double

    /// 是否正在導航到同步畫面
    @Published var isNavigatingToSync = false

    /// 是否正在導航到 Personal Best 畫面
    @Published var isNavigatingToPersonalBest = false

    // MARK: - Private Properties

    private let coordinator = OnboardingBackfillCoordinator.shared

    // MARK: - Initialization

    init(dataSource: DataSourceType, targetDistance: Double) {
        self.dataSource = dataSource
        self.targetDistance = targetDistance

        Logger.debug("BackfillPromptViewModel: 初始化")
        Logger.debug("  - 資料來源: \(dataSource.rawValue)")
        Logger.debug("  - 目標距離: \(targetDistance) km")
    }

    // MARK: - Public Methods

    /// 用戶確認要進行 backfill
    func confirmBackfill() {
        Logger.debug("BackfillPromptViewModel: 用戶確認進行 backfill")

        Logger.firebase("用戶確認 Onboarding backfill", level: .info, labels: [
            "module": "BackfillPromptViewModel",
            "action": "confirmBackfill",
            "dataSource": dataSource.rawValue
        ])

        // 導航到同步畫面
        isNavigatingToSync = true
    }

    /// 用戶選擇跳過 backfill
    func skipBackfill() {
        Logger.debug("BackfillPromptViewModel: 用戶選擇跳過 backfill")

        Logger.firebase("用戶跳過 Onboarding backfill", level: .info, labels: [
            "module": "BackfillPromptViewModel",
            "action": "skipBackfill",
            "dataSource": dataSource.rawValue
        ])

        // 標記為用戶跳過
        coordinator.markSkippedByUser()

        // 直接導航到下一步（Personal Best）
        isNavigatingToPersonalBest = true
    }

    /// 獲取資料來源的顯示名稱
    var dataSourceDisplayName: String {
        switch dataSource {
        case .garmin:
            return "Garmin Connect™"
        case .strava:
            return "Strava"
        case .appleHealth:
            return "Apple Health"
        case .unbound:
            return ""
        }
    }

    /// 獲取資料來源的圖示名稱
    var dataSourceIconName: String {
        switch dataSource {
        case .garmin:
            return "clock.arrow.circlepath"
        case .strava:
            return "figure.run"
        case .appleHealth:
            return "heart.fill"
        case .unbound:
            return ""
        }
    }
}
