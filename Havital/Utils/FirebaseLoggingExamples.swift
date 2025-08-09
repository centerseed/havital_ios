import Foundation

/// Firebase Logging 使用範例
/// 這個文件展示了如何在應用程式的不同部分使用 Firebase Logging
struct FirebaseLoggingExamples {
    
    // MARK: - 基本日誌記錄範例
    
    /// 記錄一般資訊
    static func logBasicInfo() {
        Logger.firebase("用戶已成功登入", level: .info)
    }
    
    /// 記錄警告
    static func logWarning() {
        Logger.firebase("網路連線不穩定", level: .warn)
    }
    
    /// 記錄錯誤
    static func logError() {
        Logger.firebase("API 請求失敗", level: .error)
    }
    
    // MARK: - 帶標籤的日誌記錄
    
    /// 記錄帶標籤的日誌
    static func logWithLabels() {
        Logger.firebase(
            "訓練計劃同步完成",
            level: .info,
            labels: [
                "module": "TrainingPlan",
                "action": "sync",
                "status": "success"
            ]
        )
    }
    
    // MARK: - 帶結構化資料的日誌記錄
    
    /// 記錄帶結構化資料的日誌
    static func logWithStructuredData() {
        let workoutData: [String: Any] = [
            "workoutId": "12345",
            "duration": 3600,
            "distance": 10.5,
            "calories": 750,
            "heartRate": [
                "average": 145,
                "max": 175
            ]
        ]
        
        Logger.firebase(
            "運動記錄已上傳",
            level: .info,
            jsonPayload: workoutData
        )
    }
    
    // MARK: - 事件記錄範例
    
    /// 記錄用戶行為事件
    static func logUserAction() {
        Logger.firebaseEvent(
            "user_completed_workout",
            parameters: [
                "workout_type": "running",
                "duration_minutes": 45,
                "distance_km": 5.2
            ]
        )
    }
    
    /// 記錄應用程式功能使用
    static func logFeatureUsage() {
        Logger.firebaseEvent(
            "feature_used",
            parameters: [
                "feature_name": "heart_rate_zones",
                "screen": "HealthView"
            ]
        )
    }
    
    // MARK: - 錯誤追蹤範例
    
    /// 記錄詳細的錯誤資訊
    static func logDetailedError(error: Error, context: String) {
        let errorData: [String: Any] = [
            "error_type": String(describing: type(of: error)),
            "error_message": error.localizedDescription,
            "context": context,
            "stack_trace": Thread.callStackSymbols
        ]
        
        Logger.firebase(
            "應用程式錯誤: \(error.localizedDescription)",
            level: .error,
            jsonPayload: errorData
        )
    }
    
    // MARK: - 性能監控範例
    
    /// 記錄性能指標
    static func logPerformanceMetrics(operation: String, duration: TimeInterval) {
        let performanceData: [String: Any] = [
            "operation": operation,
            "duration_seconds": duration,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        Logger.firebase(
            "性能指標: \(operation) 耗時 \(String(format: "%.3f", duration)) 秒",
            level: .info,
            jsonPayload: performanceData
        )
    }
    
    // MARK: - 業務邏輯追蹤範例
    
    /// 記錄訓練計劃相關事件
    static func logTrainingPlanEvent(action: String, planId: String? = nil) {
        var parameters: [String: Any] = ["action": action]
        if let planId = planId {
            parameters["plan_id"] = planId
        }
        
        Logger.firebaseEvent("training_plan_action", parameters: parameters)
    }
    
    /// 記錄健康數據同步事件
    static func logHealthDataSync(source: String, recordCount: Int, success: Bool) {
        let syncData: [String: Any] = [
            "data_source": source,
            "record_count": recordCount,
            "sync_success": success,
            "sync_timestamp": Date().timeIntervalSince1970
        ]
        
        Logger.firebase(
            "健康數據同步: \(source) - \(recordCount) 筆記錄",
            level: success ? .info : .error,
            jsonPayload: syncData
        )
    }
    
    // MARK: - 用戶行為分析範例
    
    /// 記錄用戶導航行為
    static func logNavigationEvent(from: String, to: String) {
        Logger.firebaseEvent(
            "navigation",
            parameters: [
                "from_screen": from,
                "to_screen": to,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    /// 記錄用戶設定變更
    static func logSettingChange(setting: String, oldValue: Any, newValue: Any) {
        let settingData: [String: Any] = [
            "setting_name": setting,
            "old_value": String(describing: oldValue),
            "new_value": String(describing: newValue)
        ]
        
        Logger.firebase(
            "用戶設定變更: \(setting)",
            level: .info,
            jsonPayload: settingData
        )
    }
}

// MARK: - 實際使用場景範例

/// 在現有服務中整合 Firebase Logging 的範例
extension FirebaseLoggingExamples {
    
    /// 在 AuthenticationService 中的使用範例
    static func authenticationLoggingExamples() {
        // 登入成功
        Logger.firebaseEvent("user_login_success", parameters: [
            "login_method": "google",
            "user_id": AuthenticationService.shared.user?.uid ?? "unknown"
        ])
        
        // 登入失敗
        Logger.firebase("用戶登入失敗", level: .error, labels: [
            "module": "Authentication",
            "method": "google"
        ])
    }
    
    /// 在 WorkoutService 中的使用範例
    static func workoutLoggingExamples() {
        // 運動數據上傳
        Logger.firebaseEvent("workout_upload", parameters: [
            "workout_count": 5,
            "upload_source": "healthkit"
        ])
        
        // 運動數據同步失敗
        Logger.firebase(
            "運動數據同步失敗",
            level: .error,
            jsonPayload: [
                "error_code": "NETWORK_TIMEOUT",
                "retry_count": 3
            ]
        )
    }
    
    /// 在 GarminManager 中的使用範例
    static func garminLoggingExamples() {
        // Garmin 連接成功
        Logger.firebaseEvent("garmin_connected", parameters: [
            "device_model": "Forerunner 945",
            "connection_method": "oauth"
        ])
        
        // Garmin 同步完成
        Logger.firebase(
            "Garmin 數據同步完成",
            level: .info,
            jsonPayload: [
                "sync_duration": 45.2,
                "activities_count": 12,
                "heart_rate_records": 1500
            ]
        )
    }
} 