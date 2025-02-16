import Foundation
import HealthKit

class WorkoutService {
    static let shared = WorkoutService()
    private let networkService = NetworkService.shared
    
    private init() {}
    
    func postWorkoutDetails(workout: HKWorkout, heartRates: [DataPoint], paces: [DataPoint]) async throws {
        // Create workout data model
        print("Workout Start Date:", workout.startDate)
        print("Workout End Date:", workout.endDate)
        let workoutData = WorkoutData(
            id: workout.uuid.uuidString,
            name: workout.workoutActivityType.name,
            startDate: workout.startDate.timeIntervalSince1970,
            endDate: workout.endDate.timeIntervalSince1970,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            heartRates: heartRates.map { HeartRateData(time: $0.time.timeIntervalSince1970, value: $0.value) },
            paces: paces.map { PaceData(time: $0.time.timeIntervalSince1970, value: $0.value) }
        )
        
        let endpoint = try Endpoint(
            path: "/workout",
            method: .post,
            requiresAuth: true,
            body: workoutData
        )
        
        do {
            let _: EmptyResponse = try await networkService.request(endpoint)
            print("成功上傳運動數據")
        } catch {
            print("上傳運動數據失敗: \(error)")
            throw error
        }
    }
}

// Data models for API
struct WorkoutData: Codable {
    let id: String
    let name: String
    let startDate: TimeInterval
    let endDate: TimeInterval
    let duration: TimeInterval
    let distance: Double
    let heartRates: [HeartRateData]
    let paces: [PaceData]
}

struct HeartRateData: Codable {
    let time: TimeInterval
    let value: Double
}

struct PaceData: Codable {
    let time: TimeInterval
    let value: Double
}

struct EmptyResponse: Codable {}
