import Foundation

/// Backend DTO for the push response (snake_case + CodingKeys, Data layer).
struct GarminPushResponseDTO: Codable {
    let garminWorkoutId: Int?
    let scheduledDate: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case garminWorkoutId = "garmin_workout_id"
        case scheduledDate = "scheduled_date"
        case status
    }
}

final class GarminPushRepositoryImpl: GarminPushRepository {
    private let apiHelper: APICallHelper

    init(httpClient: HTTPClient = DefaultHTTPClient.shared,
         parser: APIParser = DefaultAPIParser.shared) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "GarminPushRepository"
        )
    }

    func pushWorkout(dayIndex: Int, date: String) async throws {
        Logger.firebase("[garmin-push] repo POST day=\(dayIndex) date=\(date)",
                        level: .info, labels: ["feature": "garmin_push"])
        _ = try await apiHelper.post(
            GarminPushResponseDTO.self,
            path: "/v2/integrations/garmin/push-workout",
            bodyDict: ["day_index": dayIndex, "date": date]
        )
    }

    func removeWorkout(dayIndex: Int) async throws {
        Logger.firebase("[garmin-push] repo DELETE day=\(dayIndex)",
                        level: .info, labels: ["feature": "garmin_push"])
        let body = try JSONSerialization.data(withJSONObject: ["day_index": dayIndex])
        try await apiHelper.callNoResponse(
            path: "/v2/integrations/garmin/push-workout",
            method: .DELETE,
            body: body
        )
    }
}

// MARK: - DI registration
extension DependencyContainer {
    /// Registers the Garmin push module. Called from registerTrainingPlanV2Dependencies().
    func registerGarminPushModule() {
        register(GarminPushRepositoryImpl() as GarminPushRepository,
                 forProtocol: GarminPushRepository.self)
        Logger.trace("[DI] GarminPush module registered")
    }
}
