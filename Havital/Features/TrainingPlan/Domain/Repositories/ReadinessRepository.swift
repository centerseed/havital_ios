import Foundation

protocol ReadinessRepository {
    func getTodayReadiness() async throws -> TrainingReadinessResponse
}
