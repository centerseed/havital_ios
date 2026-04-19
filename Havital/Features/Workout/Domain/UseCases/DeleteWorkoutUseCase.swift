//
//  DeleteWorkoutUseCase.swift
//  Havital
//
//  Delete Workout Use Case
//  Domain Layer - Business logic for deleting workout
//

import Foundation

// MARK: - Delete Workout Use Case
/// 刪除訓練記錄 Use Case
/// Domain Layer - 封裝刪除訓練的業務邏輯（API 刪除 + 緩存清理）
class DeleteWorkoutUseCase {

    // MARK: - Dependencies

    private let repository: WorkoutRepository

    // MARK: - Initialization

    init(repository: WorkoutRepository) {
        self.repository = repository
    }

    // MARK: - Execute

    /// 執行用例：刪除訓練記錄
    /// - Parameter workoutId: 訓練 ID
    /// - Throws: WorkoutError
    func execute(workoutId: String) async throws {
        Logger.debug("[DeleteWorkoutUseCase] Deleting workout: \(workoutId)")

        // 1. 調用 Repository 刪除（API + 緩存）
        try await repository.deleteWorkout(id: workoutId)

        // 2. 清除相關緩存（確保下次載入最新數據）
        await repository.clearCache()

        // 3. 記錄日誌
        Logger.firebase(
            "訓練刪除成功",
            level: .info,
            labels: ["module": "DeleteWorkoutUseCase"],
            jsonPayload: ["workout_id": workoutId]
        )

        Logger.debug("[DeleteWorkoutUseCase] ✅ Workout deleted successfully")
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 DeleteWorkoutUseCase
    func makeDeleteWorkoutUseCase() -> DeleteWorkoutUseCase {
        // 確保 Workout 模組已註冊
        if !isRegistered(WorkoutRepository.self) {
            registerWorkoutModule()
        }

        let repository: WorkoutRepository = resolve()
        return DeleteWorkoutUseCase(repository: repository)
    }
}
