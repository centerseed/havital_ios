import Foundation

final class TrainingPlanService {
    static let shared = TrainingPlanService()
    
    // MARK: - New Architecture Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser
    
    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }
    
    // MARK: - Unified API Call Method
    
    /// 統一的 API 調用方法
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }
    
    /// 無回應數據的 API 調用
    private func makeAPICallNoResponse(
        path: String,
        method: HTTPMethod = .DELETE,
        body: Data? = nil
    ) async throws {
        do {
            _ = try await httpClient.request(path: path, method: method, body: body)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }
    
    func postTrainingPlanOverview() async throws -> TrainingPlanOverview {
        return try await makeAPICall(TrainingPlanOverview.self,
            path: "/plan/race_run/overview", method: .POST)
    }
    
    func updateTrainingPlanOverview(overviewId: String) async throws -> TrainingPlanOverview {
        return try await makeAPICall(TrainingPlanOverview.self,
            path: "/plan/race_run/overview/\(overviewId)", method: .PUT)
    }
    
    // MARK: - Modifications APIs
    /// 取得修改描述
    func getModificationsDescription() async throws -> String {
        return try await makeAPICall(String.self, path: "/plan/modifications/description")
    }
    
    /// 取得所有修改項目
    func getModifications() async throws -> [Modification] {
        return try await makeAPICall([Modification].self, path: "/plan/modifications")
    }
    
    /// 新增單筆修改
    func createModification(_ newMod: NewModification) async throws -> Modification {
        let body = try JSONEncoder().encode(newMod)
        return try await makeAPICall(Modification.self,
            path: "/plan/modifications", method: .POST, body: body)
    }
    
    /// 更新多筆修改
    func updateModifications(_ mods: [Modification]) async throws -> [Modification] {
        let payload = ModificationsUpdateRequest(modifications: mods)
        let data = try JSONEncoder().encode(payload)
        return try await makeAPICall([Modification].self,
            path: "/plan/modifications", method: .PUT, body: data)
    }
    
    /// 清除所有修改
    func clearModifications() async throws {
        try await makeAPICallNoResponse(path: "/plan/modifications", method: .DELETE)
    }
    
    func getTrainingPlanOverview() async throws -> TrainingPlanOverview {
        return try await makeAPICall(TrainingPlanOverview.self, path: "/plan/race_run/overview")
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
            return try await makeAPICall(WeeklyPlan.self, path: "/plan/race_run/weekly/\(planId)")
        } catch let httpError as HTTPError {
            // 檢查是否為 HTTP 404 錯誤（資源不存在）
            if case .notFound(_) = httpError {
                throw WeeklyPlanError.notFound
            } else {
                throw httpError
            }
        } catch let error as NSError where error.code == 404 {
            // 舊架構相容性：也檢查 NSError 404
            throw WeeklyPlanError.notFound
        } catch {
            // 其他錯誤（如網路不穩定、超時等）保持原樣
            throw error
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
        return try await makeAPICall(WeeklyPlan.self,
            path: "/plan/race_run/weekly/v2", method: .POST, body: bodyData)
    }
}
