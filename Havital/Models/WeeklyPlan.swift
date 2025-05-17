import Foundation

struct WeeklyPlan: Codable {
    let id: String
    let purpose: String
    let weekOfPlan: Int
    let totalWeeks: Int
    let totalDistance: Double
    let designReason: [String]?
    let days: [TrainingDay]
    private let createdAtString: String?  // 原始字串，用於解碼
    
    // 計算屬性，將字串轉換為 Date 類型
    var createdAt: Date? {
        guard let dateString = createdAtString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 嘗試不帶小數秒解析
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case purpose
        case weekOfPlan = "week_of_plan"
        case totalWeeks = "total_weeks"
        case totalDistance = "total_distance_km"
        case designReason = "design_reason"
        case days
        case createdAtString = "created_at"  // 對應 API 回傳欄位名稱
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // First, check if we're parsing the nested data structure
        if let dataContainer = try? decoder.container(keyedBy: DataCodingKeys.self),
           let nestedContainer = try? dataContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .data) {
            // Parse from nested data structure
            id = try nestedContainer.decode(String.self, forKey: .id)
            purpose = try nestedContainer.decode(String.self, forKey: .purpose)
            weekOfPlan = try nestedContainer.decode(Int.self, forKey: .weekOfPlan)
            totalWeeks = try nestedContainer.decode(Int.self, forKey: .totalWeeks)
            totalDistance = try nestedContainer.decodeIfPresent(Double.self, forKey: .totalDistance) ?? 0.0
            designReason = try nestedContainer.decodeIfPresent([String].self, forKey: .designReason)
            days = try nestedContainer.decode([TrainingDay].self, forKey: .days)
            createdAtString = try nestedContainer.decodeIfPresent(String.self, forKey: .createdAtString)
        } else {
            // Parse directly from root container
            id = try container.decode(String.self, forKey: .id)
            purpose = try container.decode(String.self, forKey: .purpose)
            weekOfPlan = try container.decode(Int.self, forKey: .weekOfPlan)
            totalWeeks = try container.decode(Int.self, forKey: .totalWeeks)
            totalDistance = try container.decodeIfPresent(Double.self, forKey: .totalDistance) ?? 0.0
            designReason = try container.decodeIfPresent([String].self, forKey: .designReason)
            days = try container.decode([TrainingDay].self, forKey: .days)
            createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAtString)
        }
    }
    
    // For handling the outer "data" wrapper if present
    enum DataCodingKeys: String, CodingKey {
        case data
    }
}

extension WeeklyPlan {
    init(id: String, purpose: String, weekOfPlan: Int, totalWeeks: Int, totalDistance: Double, designReason: [String]?, days: [TrainingDay]) {
        self.id = id
        self.purpose = purpose
        self.weekOfPlan = weekOfPlan
        self.totalWeeks = totalWeeks
        self.totalDistance = totalDistance
        self.designReason = designReason
        self.days = days
        self.createdAtString = nil
    }
}

struct TrainingDay: Codable, Identifiable {
    var id: String { dayIndex }
    let dayIndex: String
    let dayTarget: String
    let reason: String?
    let tips: String?
    let trainingType: String
    let trainingDetails: TrainingDetails?
    
    enum CodingKeys: String, CodingKey {
        case dayIndex = "day_index"
        case dayTarget = "day_target"
        case reason
        case tips
        case trainingType = "training_type"
        case trainingDetails = "training_details"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 支援 String 或 Int 格式的 day_index
        if let idx = try? container.decode(String.self, forKey: .dayIndex) {
            dayIndex = idx
        } else if let idxInt = try? container.decode(Int.self, forKey: .dayIndex) {
            dayIndex = String(idxInt)
        } else {
            throw DecodingError.typeMismatch(String.self,
              DecodingError.Context(codingPath: [CodingKeys.dayIndex],
                debugDescription: "day_index 必須為 String 或 Int"))
        }
        dayTarget = try container.decode(String.self, forKey: .dayTarget)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        tips = try container.decodeIfPresent(String.self, forKey: .tips)
        trainingType = try container.decode(String.self, forKey: .trainingType)
        trainingDetails = try container.decodeIfPresent(TrainingDetails.self, forKey: .trainingDetails)
    }
    
    var type: DayType {
        return DayType(rawValue: trainingType) ?? .rest
    }
    
    var isTrainingDay: Bool {
        return type != .rest
    }
    
    // 將 dayIndex(String) 轉為 Int 用於 UI 判斷
    var dayIndexInt: Int {
        return Int(dayIndex) ?? 0
    }
    
    var trainingItems: [WeeklyTrainingItem]? {
        if let details = trainingDetails {
            switch type {
            case .easyRun, .easy, .rest, .longRun, .recovery_run:
                if let description = details.description, let distance = details.distanceKm {
                    let item = WeeklyTrainingItem(
                        name: type == .rest ? "休息" :
                              type == .longRun ? "長距離跑" :
                              type == .lsd ? "長慢跑" :
                              "輕鬆跑",
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(
                            pace: details.pace,
                            distanceKm: distance,
                            heartRateRange: details.heartRateRange,
                            heartRate: nil,
                            times: nil
                        )
                    )
                    return [item]
                }
            case .interval:
                var items: [WeeklyTrainingItem] = []
                if let work = details.work, let recovery = details.recovery, let repeats = details.repeats {
                    let workItem = WeeklyTrainingItem(
                        name: "間歇跑",
                        runDetails: work.description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: work.pace, distanceKm: work.distanceKm, heartRateRange: nil, heartRate: nil, times: repeats)
                    )
                    items.append(workItem)
                    
                    let recoveryItem = WeeklyTrainingItem(
                        name: "恢復跑",
                        runDetails: recovery.description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: recovery.pace, distanceKm: recovery.distanceKm, heartRateRange: nil, heartRate: nil, times: repeats)
                    )
                    items.append(recoveryItem)
                    return items
                }
            case .tempo:
                if let description = details.description,
                   let distance = details.distanceKm,
                   let pace = details.pace {
                    let item = WeeklyTrainingItem(
                        name: "節奏跑",
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(
                            pace: pace,
                            distanceKm: distance,
                            heartRateRange: nil,
                            heartRate: nil,
                            times: nil
                        )
                    )
                    return [item]
                }
            case .progression:
                if let segments = details.segments, let totalDistance = details.totalDistanceKm, let description = details.description {
                    let item = WeeklyTrainingItem(
                        name: "漸速跑",
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: totalDistance, heartRateRange: nil, heartRate: nil, times: nil)
                    )
                    return [item]
                }
            case .race:
                if let description = details.description {
                    let item = WeeklyTrainingItem(
                        name: "比賽",
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: nil, heartRateRange: nil, heartRate: nil, times: nil)
                    )
                    return [item]
                }
            default:
                break
            }
        }
        return nil
    }
}

struct HeartRateRange: Codable {
    let min: Int
    let max: Int
    
    enum CodingKeys: String, CodingKey {
        case min
        case max
    }
}

struct TrainingDetails: Codable {
    let description: String?
    let distanceKm: Double?
    let totalDistanceKm: Double?
    let pace: String?
    let work: WorkoutSegment?
    let recovery: WorkoutSegment?
    let repeats: Int?
    let heartRateRange: HeartRateRange?
    let segments: [ProgressionSegment]?
    
    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case totalDistanceKm = "total_distance_km"
        case pace
        case work
        case recovery
        case repeats
        case heartRateRange = "heart_rate_range"
        case segments
    }
}

struct WorkoutSegment: Codable {
    let description: String
    let distanceKm: Double
    let pace: String?  // Optional to handle missing pace
    
    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case pace
    }
}

struct ProgressionSegment: Codable {
    let distanceKm: Double
    let pace: String
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case pace
        case description
    }
}

enum DayType: String, Codable {
    case easyRun = "easy_run"
    case easy = "easy"
    case interval = "interval"
    case tempo = "tempo"
    case longRun = "long_run"
    case lsd = "lsd"
    case progression = "progression"
    case race = "race"
    case rest = "rest"
    case recovery_run = "recovery_run"
    case crossTraining = "cross_training"
    case threshold = "threshold"
    case hiking = "hiking"
    case strength = "strength"
    case yoga = "yoga"
    case cycling = "cycling"
    
}

struct WeeklyTrainingItem: Identifiable {
    var id = UUID()
    let name: String
    let runDetails: String
    let durationMinutes: Int?
    let goals: TrainingGoals
}

struct TrainingGoals {
    let pace: String?
    let distanceKm: Double?
    let heartRateRange: HeartRateRange?
    let heartRate: String? // 保留原本欄位，兼容舊資料
    let times: Int?
    
    init(pace: String?, distanceKm: Double?, heartRateRange: HeartRateRange?, heartRate: String?, times: Int?) {
        self.pace = pace
        self.distanceKm = distanceKm
        self.heartRateRange = heartRateRange
        self.heartRate = heartRate
        self.times = times
    }
}
