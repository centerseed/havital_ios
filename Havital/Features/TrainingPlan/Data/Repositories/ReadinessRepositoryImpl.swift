import Foundation

final class ReadinessRepositoryImpl: ReadinessRepository {
    private let service: TrainingReadinessService

    init(service: TrainingReadinessService = .shared) {
        self.service = service
    }

    func getTodayReadiness() async throws -> TrainingReadinessResponse {
        try await service.getTodayReadiness(forceCalculate: false)
    }
}

// MARK: - Dependency Injection
extension DependencyContainer {

    /// 註冊 Readiness 模組依賴
    /// 包含 ReadinessRepository 的註冊
    func registerReadinessModule() {
        let repository = ReadinessRepositoryImpl()
        register(repository as ReadinessRepository, forProtocol: ReadinessRepository.self)

        Logger.debug("[DI] Readiness module dependencies registered")
    }
}
