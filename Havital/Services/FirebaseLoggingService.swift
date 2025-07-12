import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAnalytics
import UIKit

/// 基於 Firebase 的 Cloud Logging 服務
actor FirebaseLoggingService {
    static let shared = FirebaseLoggingService()
    private let db = Firestore.firestore()
    private init() {}
    
    /// 日誌等級
    enum LogLevel: String, CaseIterable, Codable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        init(from loggerLevel: LogLevel) {
            switch loggerLevel {
            case .debug: self = .debug
            case .info: self = .info
            case .warning: self = .warning
            case .error: self = .error
            case .critical: self = .critical
            }
        }
    }
    
    /// 日誌條目結構
    struct LogEntry: Codable {
        let id: String
        let timestamp: Date
        let level: String
        let message: String
        let sourceLocation: SourceLocation?
        let labels: [String: String]
        let jsonPayload: String?
        let userId: String?
        let deviceInfo: DeviceInfo
        
        struct SourceLocation: Codable {
            let file: String
            let line: Int
            let function: String
        }
        
        struct DeviceInfo: Codable {
            let deviceModel: String
            let osVersion: String
            let appVersion: String
            let buildNumber: String
            let bundleId: String
        }
        
        enum CodingKeys: String, CodingKey {
            case id, timestamp, level, message, sourceLocation, labels, userId, deviceInfo
            case jsonPayload
        }
        
        init(level: LogLevel,
             message: String,
             file: String = #file,
             line: Int = #line,
             function: String = #function,
             labels: [String: String] = [:],
             jsonPayload: [String: Any]? = nil,
             userId: String? = nil) {
            
            self.id = UUID().uuidString
            self.timestamp = Date()
            self.level = level.rawValue
            self.message = message
            self.sourceLocation = SourceLocation(
                file: URL(fileURLWithPath: file).lastPathComponent,
                line: line,
                function: function
            )
            self.labels = labels
            self.userId = userId
            
            // 處理 jsonPayload
            if let jsonPayload = jsonPayload {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: jsonPayload)
                    self.jsonPayload = String(data: jsonData, encoding: .utf8)
                } catch {
                    self.jsonPayload = nil
                }
            } else {
                self.jsonPayload = nil
            }
            
            // 設備資訊
            let device = UIDevice.current
            self.deviceInfo = DeviceInfo(
                deviceModel: device.model,
                osVersion: "\(device.systemName) \(device.systemVersion)",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
                bundleId: Bundle.main.bundleIdentifier ?? "Unknown"
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// 記錄日誌到 Firestore
    func log(level: LogLevel,
             message: String,
             labels: [String: String] = [:],
             jsonPayload: [String: Any]? = nil,
             file: String = #file,
             line: Int = #line,
             function: String = #function) async {
        
        // 獲取當前用戶ID
        let userId = AuthenticationService.shared.user?.uid
        
        let logEntry = LogEntry(
            level: level,
            message: message,
            file: file,
            line: line,
            function: function,
            labels: labels,
            jsonPayload: jsonPayload,
            userId: userId
        )
        
        // 暫時禁用 Cloud Logging 上傳，等後端端點準備好再啟用
        // do {
        //     try await sendLogToCloudLogging(logEntry)
        // } catch {
        //     Logger.error("Firebase Logging 上傳失敗: \(error.localizedDescription)", tag: "FirebaseLogging")
        // }
        
        // 記錄到 Firebase Analytics（用於事件追蹤）
        if level == .error || level == .critical {
            await logToAnalytics(logEntry)
        }
    }
    
    /// 便利方法：記錄資訊日誌
    func info(_ message: String,
              labels: [String: String] = [:],
              jsonPayload: [String: Any]? = nil,
              file: String = #file,
              line: Int = #line,
              function: String = #function) async {
        await log(level: .info, message: message, labels: labels, jsonPayload: jsonPayload, file: file, line: line, function: function)
    }
    
    /// 便利方法：記錄警告日誌
    func warning(_ message: String,
                 labels: [String: String] = [:],
                 jsonPayload: [String: Any]? = nil,
                 file: String = #file,
                 line: Int = #line,
                 function: String = #function) async {
        await log(level: .warning, message: message, labels: labels, jsonPayload: jsonPayload, file: file, line: line, function: function)
    }
    
    /// 便利方法：記錄錯誤日誌
    func error(_ message: String,
               labels: [String: String] = [:],
               jsonPayload: [String: Any]? = nil,
               file: String = #file,
               line: Int = #line,
               function: String = #function) async {
        await log(level: .error, message: message, labels: labels, jsonPayload: jsonPayload, file: file, line: line, function: function)
    }
    
    /// 便利方法：記錄關鍵錯誤日誌
    func critical(_ message: String,
                  labels: [String: String] = [:],
                  jsonPayload: [String: Any]? = nil,
                  file: String = #file,
                  line: Int = #line,
                  function: String = #function) async {
        await log(level: .critical, message: message, labels: labels, jsonPayload: jsonPayload, file: file, line: line, function: function)
    }
    
    /// 記錄特定事件（用於業務邏輯追蹤）
    func logEvent(_ eventName: String,
                  parameters: [String: Any]? = nil,
                  labels: [String: String] = [:],
                  file: String = #file,
                  line: Int = #line,
                  function: String = #function) async {
        
        var eventPayload: [String: Any] = [
            "eventName": eventName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let parameters = parameters {
            eventPayload["parameters"] = parameters
        }
        
        await log(
            level: .info,
            message: "Event: \(eventName)",
            labels: labels,
            jsonPayload: eventPayload,
            file: file,
            line: line,
            function: function
        )
        
        // 同時記錄到 Firebase Analytics
        await logEventToAnalytics(eventName, parameters: parameters)
    }
    
    // MARK: - Private Methods
    
    private func sendLogToCloudLogging(_ logEntry: LogEntry) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(logEntry)

        // 假設後端提供 /internal/cloud-logging 端點接收 JSON
        let path = "/internal/cloud-logging"
        _ = try await APIClient.shared.request(EmptyResponse.self,
                                              path: path,
                                              method: "POST",
                                              body: bodyData)
    }
    
    private func logToAnalytics(_ logEntry: LogEntry) async {
        let parameters: [String: Any] = [
            "error_message": logEntry.message,
            "error_level": logEntry.level,
            "file": logEntry.sourceLocation?.file ?? "unknown",
            "line": logEntry.sourceLocation?.line ?? 0,
            "function": logEntry.sourceLocation?.function ?? "unknown"
        ]
        
        Analytics.logEvent("app_error", parameters: parameters)
    }
    
    private func logEventToAnalytics(_ eventName: String, parameters: [String: Any]?) async {
        Analytics.logEvent(eventName, parameters: parameters)
    }
}

// MARK: - Logger Extension
extension Logger {
    /// 上傳日誌到 Firebase Cloud Logging
    static func firebase(_ message: @autoclosure () -> String,
                         level: LogLevel = .info,
                         labels: [String: String] = [:],
                         jsonPayload: [String: Any]? = nil,
                         file: String = #file,
                         line: Int = #line,
                         function: String = #function) {
        
        // 先獲取消息字符串，避免在Task中捕獲@autoclosure
        let messageString = message()
        
        // 先在本機記錄
        log(messageString, level: level, tag: "FirebaseLogging", file: file)
        
        // 異步上傳到 Firebase
        Task {
            let firebaseLevel: FirebaseLoggingService.LogLevel
            switch level {
            case .debug:
                firebaseLevel = .debug
            case .info:
                firebaseLevel = .info
            case .warn:
                firebaseLevel = .warning
            case .error:
                firebaseLevel = .error
            }
            
            await FirebaseLoggingService.shared.log(
                level: firebaseLevel,
                message: messageString,
                labels: labels,
                jsonPayload: jsonPayload,
                file: file,
                line: line,
                function: function
            )
        }
    }
    
    /// 記錄事件到 Firebase
    static func firebaseEvent(_ eventName: String,
                             parameters: [String: Any]? = nil,
                             labels: [String: String] = [:],
                             file: String = #file,
                             line: Int = #line,
                             function: String = #function) {
        
        Task {
            await FirebaseLoggingService.shared.logEvent(
                eventName,
                parameters: parameters,
                labels: labels,
                file: file,
                line: line,
                function: function
            )
        }
    }
} 