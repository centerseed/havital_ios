import Foundation

// MARK: - API 調用來源追蹤系統 (優雅版本)
// Note: APICallTracker actor 定義在 APICallTracker.swift 中

// MARK: - 方案 1：全局函數 (最簡潔) ✨

/// 為 async 函數設置 API 調用來源
///
/// 使用範例：
/// ```swift
/// await tracked("TrainingPlanView") {
///     viewModel.loadData()
/// }
/// ```
@discardableResult
func tracked<T>(_ source: String, _ operation: () async throws -> T) async rethrows -> T {
    try await APICallTracker.$currentSource.withValue(source) {
        try await operation()
    }
}

/// 為 async 函數設置 API 調用來源（無返回值版本）
func tracked(_ source: String, _ operation: () async throws -> Void) async rethrows {
    try await APICallTracker.$currentSource.withValue(source) {
        try await operation()
    }
}

// MARK: - 方案 2：TrackedTask 函數已移到最後區塊（方案 6）

// MARK: - 方案 3：Property Wrapper (最 Swift 風格)

/// API 調用來源追蹤的 Property Wrapper
///
/// 使用範例：
/// ```swift
/// @Tracked(source: "TrainingPlanView")
/// var loadData: () async -> Void = {
///     await viewModel.loadData()
/// }
/// ```
@propertyWrapper
struct Tracked<Value> {
    private let source: String
    private let operation: () async throws -> Value

    init(source: String, wrappedValue: @escaping () async throws -> Value) {
        self.source = source
        self.operation = wrappedValue
    }

    var wrappedValue: () async throws -> Value {
        return {
            try await APICallTracker.$currentSource.withValue(self.source) {
                try await self.operation()
            }
        }
    }
}

// MARK: - 方案 4：Protocol Extension (最靈活)

/// 可追蹤 API 來源的協議
protocol APISourceTrackable {
    var apiSource: String { get }
}

extension APISourceTrackable {
    /// 在當前來源上下文中執行操作
    ///
    /// 使用範例：
    /// ```swift
    /// struct TrainingPlanView: View, APISourceTrackable {
    ///     var apiSource: String { "TrainingPlanView" }
    ///
    ///     func loadData() async {
    ///         await withTracking {
    ///             viewModel.loadData()
    ///         }
    ///     }
    /// }
    /// ```
    func withTracking<T>(_ operation: () async throws -> T) async rethrows -> T {
        try await APICallTracker.$currentSource.withValue(apiSource) {
            try await operation()
        }
    }
}

// MARK: - 方案 5：自定義運算符 (最簡潔但需謹慎使用)

infix operator ~>: MultiplicationPrecedence

/// API 來源追蹤運算符
///
/// 使用範例：
/// ```swift
/// await "TrainingPlanView" ~> viewModel.loadData()
/// ```
@discardableResult
func ~> <T>(source: String, operation: () async throws -> T) async rethrows -> T {
    try await APICallTracker.$currentSource.withValue(source) {
        try await operation()
    }
}

// MARK: - 推薦方式 6：直接使用 TrackedTask - 簡化版 (最推薦) ⭐⭐⭐

/// 創建一個帶 API 追蹤的 Task（簡化版本，無返回值）
///
/// 使用範例：
/// ```swift
/// TrackedTask("TrainingPlanView: loadData") {
///     await viewModel.loadData()
/// }
/// ```
@discardableResult
func TrackedTask(_ source: String, _ operation: @escaping () async -> Void) -> Task<Void, Never> {
    Task {
        await APICallTracker.$currentSource.withValue(source) {
            await operation()
        }
    }
}

/// 創建一個帶 API 追蹤的 Task（帶返回值版本）
///
/// 使用範例：
/// ```swift
/// let result = await TrackedTask("TrainingPlanView: fetchData") {
///     return await viewModel.fetchData()
/// }.value
/// ```
@discardableResult
func TrackedTask<T>(_ source: String, _ operation: @escaping () async throws -> T) -> Task<T, Error> {
    Task {
        try await APICallTracker.$currentSource.withValue(source) {
            try await operation()
        }
    }
}

// MARK: - 推薦使用方式總結

/*
 推薦使用順序（從最簡潔到最靈活）：

 1️⃣ 全局函數 tracked() - 最簡潔，適合大部分場景
    await tracked("TrainingPlanView") { viewModel.loadData() }

 2️⃣ 自定義運算符 ~> - 超級簡潔，但可能影響可讀性
    await "TrainingPlanView" ~> viewModel.loadData()

 3️⃣ Protocol Extension - 適合整個 View 都用同一來源
    struct MyView: View, APISourceTrackable {
        var apiSource: String { "MyView" }
        func load() async {
            await withTracking { viewModel.load() }
        }
    }

 4️⃣ Property Wrapper - 適合需要重複使用的場景
    @Tracked(source: "MyView")
    func loadData() async { await viewModel.load() }

 5️⃣ TrackedTask 函數 - 創建帶追蹤的 Task
    TrackedTask("TrainingPlanView: loadData") {
        await viewModel.loadData()
    }

 6️⃣ Task Extension (最推薦) - 鏈式調用，適合所有場景
    Task {
        await viewModel.loadData()
    }.tracked(from: "TrainingPlanView: loadData")
*/
