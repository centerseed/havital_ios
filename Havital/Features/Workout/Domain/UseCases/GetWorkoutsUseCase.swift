//
//  GetWorkoutsUseCase.swift
//  Havital
//
//  Get Workouts Use Case
//  Domain Layer - Business logic for fetching workout list
//

import Foundation

// MARK: - Get Workouts Use Case
/// 獲取訓練列表 Use Case
/// Domain Layer - 封裝載入訓練列表的業務邏輯
class GetWorkoutsUseCase {

    // MARK: - Dependencies

    private let repository: WorkoutRepository

    // MARK: - Initialization

    init(repository: WorkoutRepository) {
        self.repository = repository
    }

    // MARK: - Execute

    /// 執行用例：獲取訓練列表
    /// - Parameters:
    ///   - limit: 每頁數量（nil = 全部）
    ///   - offset: 偏移量（用於分頁）
    /// - Returns: 訓練列表
    /// - Throws: WorkoutError
    func execute(limit: Int?, offset: Int?) async throws -> [WorkoutV2] {
        Logger.debug("[GetWorkoutsUseCase] Execute - limit: \(String(describing: limit)), offset: \(String(describing: offset))")

        // 調用 Repository 獲取訓練列表（雙軌緩存策略已在 Repository 中實現）
        let workouts = try await repository.getWorkouts(limit: limit, offset: offset)

        Logger.debug("[GetWorkoutsUseCase] ✅ Fetched \(workouts.count) workouts")
        return workouts
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// 創建 GetWorkoutsUseCase
    func makeGetWorkoutsUseCase() -> GetWorkoutsUseCase {
        // 確保 Workout 模組已註冊
        if !isRegistered(WorkoutRepository.self) {
            registerWorkoutModule()
        }

        let repository: WorkoutRepository = resolve()
        return GetWorkoutsUseCase(repository: repository)
    }
}
