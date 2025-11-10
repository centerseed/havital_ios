import Foundation
import SwiftUI

// MARK: - API 調用追蹤器

/// 全局 API 調用追蹤器
actor APICallTracker {
    static let shared = APICallTracker()
    private init() {}

    /// 當前調用來源 (使用 TaskLocal 實現線程安全)
    @TaskLocal static var currentSource: String?

    /// 讀取當前調用來源，在 async 上下文中自動可用
    nonisolated static func getCurrentSource() -> String {
        return Self.currentSource ?? "Unknown"
    }

    /// 記錄 API 調用開始
    func logAPICallStart(source: String, method: String, path: String) {
        Logger.debug("🚀 [API Start] \(source) → \(method) \(path)")
    }

    /// 記錄 API 調用完成
    func logAPICallEnd(source: String, method: String, path: String, statusCode: Int, duration: TimeInterval) {
        let emoji = statusCode >= 200 && statusCode < 300 ? "✅" : "❌"
        Logger.debug("\(emoji) \(statusCode) | \(String(format: "%.2fs", duration))")
    }

    /// 記錄 API 調用錯誤
    func logAPICallError(source: String, method: String, path: String, error: Error) {
        Logger.error("💥 [API Error] \(source) → \(method) \(path) | \(error.localizedDescription)")
    }
}

// MARK: - Property Wrapper for View-level API Tracking

/// 用於 View 的 Property Wrapper，自動追蹤 API 調用來源
@propertyWrapper
struct TrackedAPI<T> {
    private let viewName: String
    private var operation: () async throws -> T

    init(viewName: String, operation: @escaping () async throws -> T) {
        self.viewName = viewName
        self.operation = operation
    }

    var wrappedValue: () async throws -> T {
        return {
            try await APICallTracker.$currentSource.withValue(self.viewName) {
                try await self.operation()
            }
        }
    }
}

// MARK: - View Extension for Easy API Tracking

extension View {
    /// 為整個 View 設置 API 調用來源
    ///
    /// 使用範例：
    /// ```swift
    /// var body: some View {
    ///     VStack { ... }
    ///         .trackAPISource("TrainingPlanView")
    /// }
    /// ```
    func trackAPISource(_ sourceName: String) -> some View {
        self.task {
            await APICallTracker.$currentSource.withValue(sourceName) {
                // TaskLocal 會自動傳播到所有子任務
            }
        }
    }

    /// 在特定操作中追蹤 API 來源
    ///
    /// 使用範例：
    /// ```swift
    /// Button("刷新") {
    ///     performWithAPITracking(source: "MyView") {
    ///         await viewModel.refresh()
    ///     }
    /// }
    /// ```
    func performWithAPITracking(source: String, operation: @escaping () async -> Void) {
        Task {
            await APICallTracker.$currentSource.withValue(source) {
                await operation()
            }
        }
    }
}

// MARK: - Helper Function for Manual Tracking

/// 在任何 async context 中手動追蹤 API 調用來源
///
/// 使用範例：
/// ```swift
/// await withAPITracking(source: "TrainingPlanView") {
///     await viewModel.loadData()
/// }
/// ```
func withAPITracking<T>(source: String, operation: () async throws -> T) async rethrows -> T {
    try await APICallTracker.$currentSource.withValue(source) {
        try await operation()
    }
}

/// 在任何 async context 中手動追蹤 API 調用來源（無返回值版本）
func withAPITracking(source: String, operation: () async throws -> Void) async rethrows {
    try await APICallTracker.$currentSource.withValue(source) {
        try await operation()
    }
}
