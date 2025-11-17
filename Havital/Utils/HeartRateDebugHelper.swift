import Foundation

/// 心率设置调试辅助工具
/// 用于调试心率设置提醒功能
struct HeartRateDebugHelper {

    /// 打印当前所有心率相关的 UserDefaults 值
    static func printAllHeartRateSettings() {
        Logger.debug("=== Heart Rate Settings Debug Info ===")

        let maxHR = UserDefaults.standard.integer(forKey: "max_heart_rate")
        let restingHR = UserDefaults.standard.integer(forKey: "resting_heart_rate")
        let doNotShow = UserDefaults.standard.bool(forKey: "do_not_show_heart_rate_prompt")

        Logger.debug("UserDefaults - max_heart_rate: \(maxHR)")
        Logger.debug("UserDefaults - resting_heart_rate: \(restingHR)")
        Logger.debug("UserDefaults - do_not_show_heart_rate_prompt: \(doNotShow)")

        if let timestamp = UserDefaults.standard.object(forKey: "heart_rate_prompt_next_remind_date") as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            Logger.debug("UserDefaults - heart_rate_prompt_next_remind_date: \(date)")
        } else {
            Logger.debug("UserDefaults - heart_rate_prompt_next_remind_date: nil")
        }

        let manager = UserPreferenceManager.shared
        Logger.debug("UserPreferenceManager - maxHeartRate: \(manager.maxHeartRate ?? 0)")
        Logger.debug("UserPreferenceManager - restingHeartRate: \(manager.restingHeartRate ?? 0)")
        Logger.debug("UserPreferenceManager - doNotShowHeartRatePrompt: \(manager.doNotShowHeartRatePrompt)")
        Logger.debug("UserPreferenceManager - heartRatePromptNextRemindDate: \(manager.heartRatePromptNextRemindDate?.description ?? "nil")")

        Logger.debug("=== End Debug Info ===")
    }

    /// 强制清除所有心率设置（仅用于调试）
    static func forceClearAllHeartRateSettings() {
        Logger.debug("🧹 Forcefully clearing all heart rate settings...")

        UserDefaults.standard.removeObject(forKey: "max_heart_rate")
        UserDefaults.standard.removeObject(forKey: "resting_heart_rate")
        UserDefaults.standard.removeObject(forKey: "do_not_show_heart_rate_prompt")
        UserDefaults.standard.removeObject(forKey: "heart_rate_prompt_next_remind_date")
        UserDefaults.standard.removeObject(forKey: "heart_rate_zones")

        let manager = UserPreferenceManager.shared
        manager.maxHeartRate = nil
        manager.restingHeartRate = nil
        manager.doNotShowHeartRatePrompt = false
        manager.heartRatePromptNextRemindDate = nil
        manager.heartRateZones = nil

        Logger.debug("✅ All heart rate settings cleared")
        printAllHeartRateSettings()
    }

    /// 模拟"明天再提醒"场景（设置为1分钟后过期）
    static func simulateRemindMeTomorrow() {
        Logger.debug("⏰ Simulating 'Remind Me Tomorrow' (expires in 1 minute)")
        let oneMinuteLater = Date().addingTimeInterval(60)
        UserPreferenceManager.shared.heartRatePromptNextRemindDate = oneMinuteLater
        Logger.debug("✅ Next remind date set to: \(oneMinuteLater)")
    }
}
