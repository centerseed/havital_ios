import Foundation

/// 心率设置调试辅助工具
/// 用于调试心率设置提醒功能
struct HeartRateDebugHelper {

    /// 打印当前所有心率相关的 UserDefaults 值
    static func printAllHeartRateSettings() {
        Logger.debug("[HeartRateDebug] ========== 心率設置完整狀態 ==========")

        let maxHR = UserDefaults.standard.integer(forKey: "max_heart_rate")
        let restingHR = UserDefaults.standard.integer(forKey: "resting_heart_rate")
        let doNotShow = UserDefaults.standard.bool(forKey: "do_not_show_heart_rate_prompt")

        Logger.debug("[HeartRateDebug] UserDefaults.max_heart_rate: \(maxHR)")
        Logger.debug("[HeartRateDebug] UserDefaults.resting_heart_rate: \(restingHR)")
        Logger.debug("[HeartRateDebug] UserDefaults.do_not_show_heart_rate_prompt: \(doNotShow)")

        if let timestamp = UserDefaults.standard.object(forKey: "heart_rate_prompt_next_remind_date") as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            Logger.debug("[HeartRateDebug] UserDefaults.heart_rate_prompt_next_remind_date: \(date)")
        } else {
            Logger.debug("[HeartRateDebug] UserDefaults.heart_rate_prompt_next_remind_date: nil")
        }

        let manager = UserPreferencesManager.shared
        Logger.debug("[HeartRateDebug] Manager.maxHeartRate: \(manager.maxHeartRate ?? 0)")
        Logger.debug("[HeartRateDebug] Manager.restingHeartRate: \(manager.restingHeartRate ?? 0)")
        Logger.debug("[HeartRateDebug] Manager.doNotShowHeartRatePrompt: \(manager.doNotShowHeartRatePrompt)")
        Logger.debug("[HeartRateDebug] Manager.heartRatePromptNextRemindDate: \(manager.heartRatePromptNextRemindDate?.description ?? "nil")")

        Logger.debug("[HeartRateDebug] ==========================================")
    }

    /// 强制清除所有心率设置（仅用于调试）
    static func forceClearAllHeartRateSettings() {
        Logger.debug("[HeartRateDebug] 🧹 開始清除所有心率設置...")

        UserDefaults.standard.removeObject(forKey: "max_heart_rate")
        UserDefaults.standard.removeObject(forKey: "resting_heart_rate")
        UserDefaults.standard.removeObject(forKey: "do_not_show_heart_rate_prompt")
        UserDefaults.standard.removeObject(forKey: "heart_rate_prompt_next_remind_date")
        UserDefaults.standard.removeObject(forKey: "heart_rate_zones")

        let manager = UserPreferencesManager.shared
        manager.maxHeartRate = nil
        manager.restingHeartRate = nil
        manager.doNotShowHeartRatePrompt = false
        manager.heartRatePromptNextRemindDate = nil
        manager.heartRateZones = nil

        Logger.debug("[HeartRateDebug] ✅ 所有心率設置已清除")
        printAllHeartRateSettings()
    }

    /// 模拟"明天再提醒"场景（设置为1分钟后过期）
    static func simulateRemindMeTomorrow() {
        Logger.debug("[HeartRateDebug] ⏰ 模擬「明天再提醒」（1分鐘後過期）")
        let oneMinuteLater = Date().addingTimeInterval(60)
        UserPreferencesManager.shared.heartRatePromptNextRemindDate = oneMinuteLater
        Logger.debug("[HeartRateDebug] ✅ 下次提醒時間設為：\(oneMinuteLater)")
    }
}
