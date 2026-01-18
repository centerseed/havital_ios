import Foundation

// MARK: - 依賴注入容器
/// Service Locator 模式，取代 Singleton
/// 使用方式：let vm: WeeklyPlanViewModel = DependencyContainer.shared.resolve()
final class DependencyContainer {

    // MARK: - Singleton
    static let shared = DependencyContainer()

    // MARK: - Storage
    private var singletons: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private let lock = NSLock()

    // MARK: - Initialization
    private init() {
        registerCoreDependencies()
    }

    // MARK: - Registration

    /// 註冊單例（只創建一次）
    func register<T>(_ instance: T, for type: T.Type) {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: type)
        singletons[key] = instance
        Logger.debug("[DI] Registered singleton: \(key)")
    }

    /// 註冊工廠（每次 resolve 都創建新實例）
    func registerFactory<T>(for type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: type)
        factories[key] = factory
        Logger.debug("[DI] Registered factory: \(key)")
    }

    /// 註冊 Protocol 到實作的映射
    func register<P, T>(_ instance: T, forProtocol protocolType: P.Type) {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: protocolType)
        singletons[key] = instance
        Logger.debug("[DI] Registered protocol: \(key) -> \(String(describing: T.self))")
    }

    // MARK: - Resolution

    /// 解析依賴
    func resolve<T>() -> T {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: T.self)

        // 優先檢查工廠（ViewModel 等每次需要新實例）
        if let factory = factories[key] {
            guard let instance = factory() as? T else {
                fatalError("[DI] Factory returned wrong type for \(key)")
            }
            return instance
        }

        // 檢查單例
        guard let instance = singletons[key] as? T else {
            fatalError("[DI] No dependency registered for \(key)")
        }
        return instance
    }

    /// 嘗試解析（可能失敗）
    func tryResolve<T>() -> T? {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: T.self)

        if let factory = factories[key] {
            return factory() as? T
        }

        return singletons[key] as? T
    }

    /// 檢查是否已註冊
    func isRegistered<T>(_ type: T.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: type)
        return singletons[key] != nil || factories[key] != nil
    }

    // MARK: - Core Dependencies Registration

    private func registerCoreDependencies() {
        // 網路層
        register(DefaultHTTPClient.shared, forProtocol: HTTPClient.self)
        register(DefaultAPIParser.shared, forProtocol: APIParser.self)

        Logger.debug("[DI] Core dependencies registered")
    }

    // MARK: - Feature Registration (擴展點)

    /// 註冊 TrainingPlan 模組依賴（V1 版本）
    func registerTrainingPlanDependencies() {
        // V1 版本的 TrainingPlan 依賴註冊
        // 目前 V1 尚未遷移至 Clean Architecture，保留此方法以供未來遷移使用
        Logger.debug("[DI] TrainingPlan V1 module dependencies registered (placeholder)")
    }

    /// 註冊 TrainingPlanV2 模組依賴（V2 版本）
    /// 調用 TrainingPlanV2 模組的完整註冊流程
    func registerTrainingPlanV2Dependencies() {
        // 調用 TrainingPlanV2RepositoryImpl 擴展中定義的註冊方法
        // 包含 DataSources, Repositories 的註冊
        registerTrainingPlanV2Module()

        // 註冊 TrainingVersionRouter
        registerTrainingVersionRouter()

        Logger.debug("[DI] TrainingPlanV2 module dependencies registered")
    }

    /// 註冊 User 模組依賴
    /// 調用 UserProfile 模組的完整註冊流程
    func registerUserDependencies() {
        // 調用 UserProfileRepositoryImpl 擴展中定義的註冊方法
        // 包含 DataSources, Repositories, UseCases 的註冊
        registerUserProfileModule()

        // NOTE: ViewModel 不在此註冊工廠，因為 @MainActor 隔離要求
        // Views 應直接使用 @StateObject private var viewModel = UserProfileFeatureViewModel()
        // UserProfileFeatureViewModel 的 convenience init 會自動從 DI 解析所有依賴

        Logger.debug("[DI] User module dependencies registered")
    }

    /// 註冊 Target 模組依賴
    /// 調用 Target 模組的完整註冊流程
    func registerTargetDependencies() {
        // 調用 TargetRepositoryImpl 擴展中定義的註冊方法
        registerTargetModule()

        // NOTE: ViewModel 不在此註冊工廠，因為 @MainActor 隔離要求
        // Views 應直接使用 @StateObject private var viewModel = TargetFeatureViewModel()
        // TargetFeatureViewModel 的 convenience init 會自動從 DI 解析所有依賴

        Logger.debug("[DI] Target module dependencies registered")
    }

    /// 註冊 Auth 模組依賴
    /// 調用 Authentication 模組的完整註冊流程
    func registerAuthDependencies() {
        // 調用 AuthRepositoryImpl 擴展中定義的註冊方法
        // 包含 DataSources, Cache, Repositories 的註冊
        registerAuthenticationModule()

        // NOTE: ViewModel 不在此註冊工廠，因為 @MainActor 隔離要求
        // Views 應直接使用 @StateObject private var viewModel = LoginViewModel()
        // LoginViewModel 和 AuthCoordinatorViewModel 的 convenience init 會自動從 DI 解析所有依賴

        Logger.debug("[DI] Authentication module dependencies registered")
    }

    // MARK: - Testing Support

    /// 重置所有依賴（僅用於測試）
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        singletons.removeAll()
        factories.removeAll()
        registerCoreDependencies()

        Logger.debug("[DI] Container reset")
    }

    /// 替換依賴（用於測試注入 Mock）
    func replace<T>(_ instance: T, for type: T.Type) {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: type)
        singletons[key] = instance
        Logger.debug("[DI] Replaced: \(key)")
    }
}

// MARK: - 便利方法
extension DependencyContainer {

    /// 快速解析 HTTPClient
    var httpClient: HTTPClient {
        return resolve()
    }

    /// 快速解析 APIParser
    var apiParser: APIParser {
        return resolve()
    }
}

// MARK: - SwiftUI Environment Support
import SwiftUI

/// 用於 SwiftUI Environment 的 DI Key
private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

extension View {
    /// 注入 DependencyContainer 到環境
    func withDependencyContainer(_ container: DependencyContainer = .shared) -> some View {
        environment(\.dependencyContainer, container)
    }
}
