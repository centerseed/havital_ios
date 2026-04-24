import Foundation

struct HealthRecord: Codable, Equatable {
    let date: String
    let dailyCalories: Int?
    let hrvLastNightAvg: Double?
    let restingHeartRate: Int?
    let atl: Double?
    let ctl: Double?
    let fitness: Double?
    let tsb: Double?
    let updatedAt: Int?
    let workoutTrigger: Bool?
    let totalTss: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case date
        case dailyCalories = "daily_calories"
        case hrvLastNightAvg = "hrv_last_night_avg"
        case restingHeartRate = "resting_heart_rate"
        case tsbMetrics = "tsb_metrics"
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    private struct TSBMetrics: Codable {
        let atl: Double?
        let ctl: Double?
        let fitness: Double?
        let tsb: Double?
        let updatedAt: Int?
        let workoutTrigger: Bool?
        let totalTss: Double?
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case atl, ctl, fitness, tsb
            case updatedAt = "updated_at"
            case workoutTrigger = "workout_trigger"
            case totalTss = "total_tss"
            case createdAt = "created_at"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        date = try container.decode(String.self, forKey: .date)
        dailyCalories = try container.decodeIfPresent(Int.self, forKey: .dailyCalories)
        hrvLastNightAvg = try container.decodeIfPresent(Double.self, forKey: .hrvLastNightAvg)
        restingHeartRate = try container.decodeIfPresent(Int.self, forKey: .restingHeartRate)

        if let tsbMetrics = try container.decodeIfPresent(TSBMetrics.self, forKey: .tsbMetrics) {
            atl = tsbMetrics.atl
            ctl = tsbMetrics.ctl
            fitness = tsbMetrics.fitness
            tsb = tsbMetrics.tsb
            updatedAt = tsbMetrics.updatedAt
            workoutTrigger = tsbMetrics.workoutTrigger
            totalTss = tsbMetrics.totalTss
            createdAt = tsbMetrics.createdAt
        } else {
            let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)

            atl = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "atl")!)
            ctl = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "ctl")!)
            fitness = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "fitness")!)
            tsb = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "tsb")!)
            updatedAt = try dynamicContainer.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "updatedAt")!)
            workoutTrigger = try dynamicContainer.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys(stringValue: "workoutTrigger")!)
            totalTss = try dynamicContainer.decodeIfPresent(Double.self, forKey: DynamicCodingKeys(stringValue: "totalTss")!)
            createdAt = try dynamicContainer.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "createdAt")!)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(dailyCalories, forKey: .dailyCalories)
        try container.encodeIfPresent(hrvLastNightAvg, forKey: .hrvLastNightAvg)
        try container.encodeIfPresent(restingHeartRate, forKey: .restingHeartRate)

        if atl != nil || ctl != nil || fitness != nil || tsb != nil || updatedAt != nil || workoutTrigger != nil || totalTss != nil || createdAt != nil {
            let tsbMetrics = TSBMetrics(
                atl: atl,
                ctl: ctl,
                fitness: fitness,
                tsb: tsb,
                updatedAt: updatedAt,
                workoutTrigger: workoutTrigger,
                totalTss: totalTss,
                createdAt: createdAt
            )
            try container.encode(tsbMetrics, forKey: .tsbMetrics)
        }
    }

    init(
        date: String,
        dailyCalories: Int? = nil,
        hrvLastNightAvg: Double? = nil,
        restingHeartRate: Int? = nil,
        atl: Double? = nil,
        ctl: Double? = nil,
        fitness: Double? = nil,
        tsb: Double? = nil,
        updatedAt: Int? = nil,
        workoutTrigger: Bool? = nil,
        totalTss: Double? = nil,
        createdAt: String? = nil
    ) {
        self.date = date
        self.dailyCalories = dailyCalories
        self.hrvLastNightAvg = hrvLastNightAvg
        self.restingHeartRate = restingHeartRate
        self.atl = atl
        self.ctl = ctl
        self.fitness = fitness
        self.tsb = tsb
        self.updatedAt = updatedAt
        self.workoutTrigger = workoutTrigger
        self.totalTss = totalTss
        self.createdAt = createdAt
    }
}

struct HealthDailyResponse: Codable {
    let healthData: [HealthRecord]
    let count: Int
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case healthData = "health_data"
        case count, limit
    }
}
