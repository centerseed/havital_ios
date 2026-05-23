import Foundation

/// 日誌等級
/// trace = 高頻、低訊號的操作細節（token 取得、DI 註冊、parser/cache 內部）；預設不輸出，
/// 需要時把 minLevel 調到 .trace 才看得到。debug 起才是預設會印的有意義事件。
public enum LogLevel: Int, Comparable {
    case trace = 0, debug, info, warn, error
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A simple logging utility that formats logs with file name, tag, and message.
public struct Logger {
    /// 當前最小輸出級別，依 build config 設定
    private static var minLevel: LogLevel {
        #if DEBUG
        return .debug
        #else
        return .warn
        #endif
    }

    /// Logs a message with optional tag and file information.
    /// - Parameters:
    ///   - tag: An optional tag for the log. Default is nil.
    ///   - message: The message to log.
    ///   - file: The file path from where the log is called. Default uses #file.
    public static func log(_ message: @autoclosure () -> String,
                           level: LogLevel = .debug,
                           tag: String? = nil,
                           file: String = #file) {
        // 濾除低於最小級別的日誌
        guard level >= minLevel else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
            .replacingOccurrences(of: ".swift", with: "")
        let msg = message()
        // 組合日誌輸出：檔案名、等級、tag
        var output = "[\(fileName)] [\(String(describing: level).uppercased())]"
        if let tag = tag, !tag.isEmpty {
            output += " [\(tag)]"
        }
        output += " \(msg)"
        print(output)
    }

    /// Convenience for trace level（高頻操作細節，預設不輸出）
    public static func trace(_ message: @autoclosure () -> String,
                             tag: String? = nil,
                             file: String = #file) {
        log(message(), level: .trace, tag: tag, file: file)
    }
    /// Convenience for debug level
    public static func debug(_ message: @autoclosure () -> String,
                              tag: String? = nil,
                              file: String = #file) {
        log(message(), level: .debug, tag: tag, file: file)
    }
    /// Convenience for info level
    public static func info(_ message: @autoclosure () -> String,
                             tag: String? = nil,
                             file: String = #file) {
        log(message(), level: .info, tag: tag, file: file)
    }
    /// Convenience for warn level
    public static func warn(_ message: @autoclosure () -> String,
                             tag: String? = nil,
                             file: String = #file) {
        log(message(), level: .warn, tag: tag, file: file)
    }
    /// Convenience for error level
    public static func error(_ message: @autoclosure () -> String,
                              tag: String? = nil,
                              file: String = #file) {
        log(message(), level: .error, tag: tag, file: file)
    }

}
