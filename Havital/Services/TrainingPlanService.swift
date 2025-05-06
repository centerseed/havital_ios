import Foundation

final class TrainingPlanService {
    static let shared = TrainingPlanService()
    private init() {}
    
    func postTrainingPlanOverview() async throws -> TrainingPlanOverview {
        return try await APIClient.shared.request(TrainingPlanOverview.self,
            path: "/plan/race_run/overview", method: "POST")
    }
    
    func updateTrainingPlanOverview(overviewId: String) async throws -> TrainingPlanOverview {
        return try await APIClient.shared.request(TrainingPlanOverview.self,
            path: "/plan/race_run/overview/\(overviewId)", method: "PUT")
    }
    
    // MARK: - Modifications APIs
    func getModificationsDescription() async throws -> String {
        return try await APIClient.shared.request(String.self,
            path: "/plan/modifications/description")
    }
    
    func getModifications() async throws -> [Modification] {
        return try await APIClient.shared.request([Modification].self,
            path: "/plan/modifications")
    }
    
    func createModification(_ newMod: NewModification) async throws -> Modification {
        let body = try JSONEncoder().encode(newMod)
        return try await APIClient.shared.request(Modification.self,
            path: "/plan/modifications", method: "POST", body: body)
    }
    
    func updateModifications(_ mods: [Modification]) async throws -> [Modification] {
        let payload = ModificationsUpdateRequest(modifications: mods)
        let data = try JSONEncoder().encode(payload)
        return try await APIClient.shared.request([Modification].self,
            path: "/plan/modifications", method: "PUT", body: data)
    }
    
    func clearModifications() async throws {
        try await APIClient.shared.requestNoResponse(
            path: "/plan/modifications", method: "DELETE")
    }
    
    func getTrainingPlanOverview() async throws -> TrainingPlanOverview {
        return try await APIClient.shared.request(TrainingPlanOverview.self,
            path: "/plan/race_run/overview")
    }
    
    /*
    func getWeeklyPlan(caller: String = #function) async throws -> WeeklyPlan {
        return try await APIClient.shared.request(WeeklyPlan.self,
            path: "/plan/race_run/weekly")
    }*/
    
    /// 週計畫查詢錯誤
    enum WeeklyPlanError: Error {
        /// 指定週計畫不存在
        case notFound
    }
    
    func getWeeklyPlanById(planId: String) async throws -> WeeklyPlan {
        do {
            return try await APIClient.shared.request(WeeklyPlan.self,
                path: "/plan/race_run/weekly/\(planId)")
        } catch {
            // 找不到週計畫時統一視為 notFound
            throw WeeklyPlanError.notFound
        }
    }
    
    func createWeeklyPlan(targetWeek: Int? = nil) async throws -> WeeklyPlan {
        let bodyData: Data?
        if let week = targetWeek {
            bodyData = try JSONSerialization.data(
                withJSONObject: ["week_of_training": week])
        } else {
            bodyData = nil
        }
        return try await APIClient.shared.request(WeeklyPlan.self,
            path: "/plan/race_run/weekly", method: "POST", body: bodyData)
    }
}
