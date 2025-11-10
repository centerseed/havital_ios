import Foundation

/// API 調用上下文追蹤器 - 用於記錄 API 調用的來源 View
/// ⚠️ 已廢棄：請使用 APICallTracker 代替
@available(*, deprecated, message: "請使用 APICallTracker 代替")
actor APICallContext {
    static let shared = APICallContext()
    private init() {}

    /// 當前調用來源 View (使用 TaskLocal 實現線程安全)
    /// ⚠️ 已廢棄：請使用 APICallTracker.$currentSource
    @TaskLocal static var currentSource: String?
}
