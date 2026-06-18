import Foundation

/// 分享畫面（WorkoutRecapView）功能說明卡的顯示狀態。
/// 比照 WorkoutRecapStorage 的 enum + UserDefaults 靜態方法模式。
///
/// 觸發策略：第一次自動顯示；若使用者沒按「知道了」只滑掉，第二次再顯示一次；
/// 第 3 次起永不自動顯示。按下「知道了，不再顯示」則立即永久關閉。
/// UserDefaults 隨 app 更新保留、僅重新安裝才清空 → 天然符合「更新不再跳、重裝才重置」。
enum ShareCardTipStorage {
    private static let dismissedKey = "share_card_tip_dismissed"
    private static let autoShownCountKey = "share_card_tip_auto_shown_count"
    /// 最多自動顯示次數（含第一次）。達到後不再自動跳。
    private static let maxAutoShows = 2

    static func dismissedPermanently() -> Bool {
        UserDefaults.standard.bool(forKey: dismissedKey)
    }

    static func autoShownCount() -> Int {
        UserDefaults.standard.integer(forKey: autoShownCountKey)
    }

    /// 是否該在這次進入分享畫面時自動顯示說明卡。
    static func shouldShow() -> Bool {
        !dismissedPermanently() && autoShownCount() < maxAutoShows
    }

    /// 說明卡實際顯示時呼叫一次（不論之後是按按鈕或滑掉關閉）。
    static func markAutoShown() {
        UserDefaults.standard.set(autoShownCount() + 1, forKey: autoShownCountKey)
        Logger.debug("[ShareCardTip] auto shown count -> \(autoShownCount())")
    }

    /// 使用者按下「知道了，不再顯示」→ 永久關閉。
    static func markDismissedPermanently() {
        UserDefaults.standard.set(true, forKey: dismissedKey)
        Logger.debug("[ShareCardTip] dismissed permanently")
    }

    /// 測試 / 重測用：清掉所有狀態，回到初始可顯示。
    static func reset() {
        UserDefaults.standard.removeObject(forKey: dismissedKey)
        UserDefaults.standard.removeObject(forKey: autoShownCountKey)
    }
}
