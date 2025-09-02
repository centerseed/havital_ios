import Foundation

struct WeeklyPlan: Codable, Equatable {
    let id: String
    let purpose: String
    let weekOfPlan: Int
    let totalWeeks: Int
    let totalDistance: Double
    let totalDistanceReason: String?  // 週跑量決定方式說明，選填以保持向後兼容
    let designReason: [String]?
    let days: [TrainingDay]
    let intensityTotalMinutes: IntensityTotalMinutes?
    private let createdAtString: String?  // 原始字串，用於解碼
    
    struct IntensityTotalMinutes: Codable, Equatable {
        let low: Double
        let medium: Double
        let high: Double
        
        var total: Double {
            return low + medium + high
        }
    }
    
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
        case totalDistanceReason = "total_distance_reason"
        case designReason = "design_reason"
        case days
        case intensityTotalMinutes = "intensity_total_minutes"
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
            totalDistanceReason = try nestedContainer.decodeIfPresent(String.self, forKey: .totalDistanceReason)
            intensityTotalMinutes = try nestedContainer.decodeIfPresent(IntensityTotalMinutes.self, forKey: .intensityTotalMinutes)
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
            totalDistanceReason = try container.decodeIfPresent(String.self, forKey: .totalDistanceReason)
            intensityTotalMinutes = try container.decodeIfPresent(IntensityTotalMinutes.self, forKey: .intensityTotalMinutes)
            designReason = try container.decodeIfPresent([String].self, forKey: .designReason)
            days = try container.decode([TrainingDay].self, forKey: .days)
            createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAtString)
        }
    }
    
    // For handling the outer "data" wrapper if present
    enum DataCodingKeys: String, CodingKey {
        case data
    }
    
    static func == (lhs: WeeklyPlan, rhs: WeeklyPlan) -> Bool {
        return lhs.id == rhs.id &&
               lhs.weekOfPlan == rhs.weekOfPlan &&
               lhs.totalWeeks == rhs.totalWeeks &&
               lhs.totalDistance == rhs.totalDistance &&
               lhs.totalDistanceReason == rhs.totalDistanceReason &&
               lhs.days == rhs.days &&
               lhs.intensityTotalMinutes == rhs.intensityTotalMinutes
    }
}

extension WeeklyPlan {
    init(id: String, purpose: String, weekOfPlan: Int, totalWeeks: Int, totalDistance: Double, totalDistanceReason: String? = nil, designReason: [String]?, days: [TrainingDay], intensityTotalMinutes: IntensityTotalMinutes? = nil) {
        self.id = id
        self.purpose = purpose
        self.weekOfPlan = weekOfPlan
        self.totalWeeks = totalWeeks
        self.totalDistance = totalDistance
        self.totalDistanceReason = totalDistanceReason
        self.designReason = designReason
        self.days = days
        self.intensityTotalMinutes = intensityTotalMinutes
        self.createdAtString = nil
    }
}

struct TrainingDay: Codable, Identifiable, Equatable {
    var id: String { dayIndex }
    let dayIndex: String
    let dayTarget: String
    let reason: String?
    let tips: String?
    let trainingType: String
    let trainingDetails: TrainingDetails?
    
    static func == (lhs: TrainingDay, rhs: TrainingDay) -> Bool {
        return lhs.dayIndex == rhs.dayIndex &&
               lhs.dayTarget == rhs.dayTarget &&
               lhs.reason == rhs.reason &&
               lhs.tips == rhs.tips &&
               lhs.trainingType == rhs.trainingType &&
               lhs.trainingDetails == rhs.trainingDetails
    }
    
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
            case .easyRun, .easy, .rest, .longRun, .recovery_run, .lsd:
                if let distance = details.distanceKm {
                    let description = details.description ?? ""
                    let item = WeeklyTrainingItem(
                        name: type == .rest ? L10n.Training.TrainingType.rest.localized :
                              type == .longRun ? L10n.Training.TrainingType.long.localized :
                              type == .lsd ? L10n.Training.TrainingType.lsd.localized :
                              L10n.Training.TrainingType.easy.localized,
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
                        name: L10n.Training.TrainingType.interval.localized,
                        runDetails: work.description ?? "",
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: work.pace, distanceKm: work.distanceKm, heartRateRange: nil, heartRate: nil, times: repeats)
                    )
                    items.append(workItem)
                    
                    let recoveryItem = WeeklyTrainingItem(
                        name: L10n.Training.TrainingType.recovery.localized,
                        runDetails: recovery.description ?? "",
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: recovery.pace, distanceKm: recovery.distanceKm, heartRateRange: nil, heartRate: nil, times: repeats)
                    )
                    items.append(recoveryItem)
                    return items
                }
            case .tempo, .threshold:
                if let distance = details.distanceKm {
                    let description = details.description ?? ""
                    let item = WeeklyTrainingItem(
                        name: type == .tempo ? L10n.Training.TrainingType.tempo.localized : L10n.Training.TrainingType.threshold.localized,
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(
                            pace: details.pace, // pace 可以是 nil
                            distanceKm: distance,
                            heartRateRange: details.heartRateRange,
                            heartRate: nil,
                            times: nil
                        )
                    )
                    return [item]
                }
            case .progression:
                if let _ = details.segments, let totalDistance = details.totalDistanceKm {
                    let description = details.description ?? ""
                    let item = WeeklyTrainingItem(
                        name: L10n.Training.TrainingType.progression.localized,
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: totalDistance, heartRateRange: nil, heartRate: nil, times: nil)
                    )
                    return [item]
                }
            case .race:
                let description = details.description ?? ""
                let item = WeeklyTrainingItem(
                        name: L10n.Training.TrainingType.race.localized,
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: nil, heartRateRange: nil, heartRate: nil, times: nil)
                    )
                    return [item]
            case .crossTraining, .hiking, .strength, .yoga, .cycling:
                let description = details.description ?? ""
                let activityName = type == .crossTraining ? L10n.Training.TrainingType.crossTraining.localized :
                                 type == .hiking ? L10n.Training.TrainingType.hiking.localized :
                                 type == .strength ? L10n.Training.TrainingType.strength.localized :
                                 type == .yoga ? L10n.Training.TrainingType.yoga.localized :
                                 L10n.Training.TrainingType.cycling.localized
                let item = WeeklyTrainingItem(
                        name: activityName,
                        runDetails: description,
                        durationMinutes: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: details.distanceKm, heartRateRange: details.heartRateRange, heartRate: nil, times: nil)
                    )
                    return [item]
            }
        }
        return nil
    }
}

struct HeartRateRange: Codable, Equatable {
    let min: Int?  // 改為可選，提高健壯性
    let max: Int?  // 改為可選，提高健壯性
    
    enum CodingKeys: String, CodingKey {
        case min
        case max
    }
    
    // 只有當 min 和 max 都存在時才是有效的心率區間
    var isValid: Bool {
        return min != nil && max != nil
    }
    
    // 格式化心率區間文字
    var displayText: String? {
        guard let minVal = min, let maxVal = max else { return nil }
        return "\(minVal)-\(maxVal)"
    }
}

struct TrainingDetails: Codable, Equatable {
    let description: String?  // 對於間歇訓練，頂層可能沒有 description
    let distanceKm: Double?  // 對於rest類型是可選的
    let totalDistanceKm: Double?  // 對於分段訓練使用
    let timeMinutes: Double?  // 對於rest類型可能沒有時間
    let pace: String?
    let work: WorkoutSegment?
    let recovery: WorkoutSegment?
    let repeats: Int?
    let heartRateRange: HeartRateRange?  // 對於一般訓練是必填的，但對於rest是可選的
    let segments: [ProgressionSegment]?
    
    static func == (lhs: TrainingDetails, rhs: TrainingDetails) -> Bool {
        return lhs.description == rhs.description &&
               lhs.distanceKm == rhs.distanceKm &&
               lhs.totalDistanceKm == rhs.totalDistanceKm &&
               lhs.timeMinutes == rhs.timeMinutes &&
               lhs.pace == rhs.pace &&
               lhs.work == rhs.work &&
               lhs.recovery == rhs.recovery &&
               lhs.repeats == rhs.repeats &&
               lhs.heartRateRange == rhs.heartRateRange &&
               lhs.segments == rhs.segments
    }
    
    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case totalDistanceKm = "total_distance_km"
        case timeMinutes = "time_minutes"
        case pace
        case work
        case recovery
        case repeats
        case heartRateRange = "heart_rate_range"
        case segments
    }
}

struct WorkoutSegment: Codable, Equatable {
    let description: String?  // 改為可選，間歇恢復段可能沒有描述
    let distanceKm: Double?  // 改為可選，因為 API 可能返回 null
    let distanceM: Double?   // 添加米的距離欄位
    let timeMinutes: Double? // 添加時間欄位
    let pace: String?
    let heartRateRange: HeartRateRange?  // 添加心率區間欄位
    
    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case distanceM = "distance_m"
        case timeMinutes = "time_minutes"
        case pace
        case heartRateRange = "heart_rate_range"
    }
}

struct ProgressionSegment: Codable, Equatable {
    let distanceKm: Double?  // 改為可選，提高靈活性
    let pace: String?        // 改為可選，提高靈活性
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
