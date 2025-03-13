import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

class TrainingPlanService {
    static let shared = TrainingPlanService()
    private let baseURL = "https://api-service-364865009192.asia-east1.run.app"
    private init() {}
    
    private func makeRequest(path: String, method: String = "POST") async throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = try? await AuthenticationService.shared.user?.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    func getTrainingPlanOverview() async throws -> TrainingPlanOverview {
        let request = try await makeRequest(path: "/plan/race_run/overview")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<TrainingPlanOverview>.self, from: data)
        TrainingPlanStorage.saveTrainingPlanOverview(apiResponse.data)
        return apiResponse.data
    }
    
    func getWeeklyPlan() async throws -> WeeklyPlan {
        let request = try await makeRequest(path: "/plan/race_run/weekly", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        
        // Debug: Print the JSON string to see its structure
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Received JSON: \(jsonString)")
        }
        
        do {
            let plan = try decoder.decode(WeeklyPlan.self, from: data)
            TrainingPlanStorage.saveWeeklyPlan(plan)
            return plan
        } catch {
            print("Decoding error: \(error)")
            throw error
        }
    }
    
    func createWeeklyPlan() async throws -> WeeklyPlan {
        let request = try await makeRequest(path: "/plan/race_run/weekly", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("錯誤回應內容: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        
        // Debug: Print the JSON string to see its structure
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Received JSON: \(jsonString)")
        }
        
        do {
            let plan = try decoder.decode(WeeklyPlan.self, from: data)
            TrainingPlanStorage.saveWeeklyPlan(plan)
            return plan
        } catch {
            print("Decoding error: \(error)")
            throw error
        }
    }
}
