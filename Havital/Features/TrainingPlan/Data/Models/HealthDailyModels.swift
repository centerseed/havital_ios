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

        init(
            atl: Double?, ctl: Double?, fitness: Double?, tsb: Double?,
            updatedAt: Int?, workoutTrigger: Bool?, totalTss: Double?, createdAt: String?
        ) {
            self.atl = atl
            self.ctl = ctl
            self.fitness = fitness
            self.tsb = tsb
            self.updatedAt = updatedAt
            self.workoutTrigger = workoutTrigger
            self.totalTss = totalTss
            self.createdAt = createdAt
        }

        /// `updated_at` 同樣可能是浮點秒（見 `HealthRecord.decodeLenientInt` 的註解）。
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            atl = try container.decodeIfPresent(Double.self, forKey: .atl)
            ctl = try container.decodeIfPresent(Double.self, forKey: .ctl)
            fitness = try container.decodeIfPresent(Double.self, forKey: .fitness)
            tsb = try container.decodeIfPresent(Double.self, forKey: .tsb)
            updatedAt = try container.decodeIfPresent(Double.self, forKey: .updatedAt)
                .map { Int($0.rounded()) }
            workoutTrigger = try container.decodeIfPresent(Bool.self, forKey: .workoutTrigger)
            totalTss = try container.decodeIfPresent(Double.self, forKey: .totalTss)
            createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        }
    }

    /// **後端的整數欄位會以浮點交出來**（dev 實查 2026-08-26：
    /// `"resting_heart_rate": 51.0`）。`decodeIfPresent(Int.self)` 對 `51.0` 這種
    /// 剛好整除的值還過得去，但只要出現 `51.5`（RHR 是聚合出來的平均，遲早會有小數）
    /// 就會 throw —— 而這是**整包 `health_daily` 的解碼**，一筆炸掉整條序列都沒了，
    /// HRV／RHR 圖與訓練負荷卡會一起變成錯誤態。
    /// Android 已經在同一個端點上踩到這件事（2026-08-26 回報），所以這裡也不靠
    /// 「剛好整除」活著：先當數字讀，再四捨五入成 Int。
    private static func decodeLenientInt<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> Int? {
        if let value = try container.decodeIfPresent(Double.self, forKey: key) {
            return Int(value.rounded())
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        date = try container.decode(String.self, forKey: .date)
        dailyCalories = try Self.decodeLenientInt(container, forKey: .dailyCalories)
        hrvLastNightAvg = try container.decodeIfPresent(Double.self, forKey: .hrvLastNightAvg)
        restingHeartRate = try Self.decodeLenientInt(container, forKey: .restingHeartRate)

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
            updatedAt = try Self.decodeLenientInt(dynamicContainer, forKey: DynamicCodingKeys(stringValue: "updatedAt")!)
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
