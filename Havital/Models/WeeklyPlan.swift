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

// MARK: - V3 中繼解碼 structs (private)
private struct V3RunActivity: Decodable {
    let run_type: String
    let distance_km: Double?
    let pace: String?
    let heart_rate_range: HeartRateRange?
    let segments: [V3RunSegment]?
    let interval: V3IntervalBlock?
    let description: String?
    let duration_minutes: Int?
}

private struct V3IntervalBlock: Decodable {
    let repeats: Int
    let work_distance_km: Double?
    let work_distance_m: Int?
    let work_duration_minutes: Int?
    let work_pace: String?
    let work_description: String?
    let recovery_distance_km: Double?
    let recovery_distance_m: Int?
    let recovery_duration_minutes: Int?
    let recovery_duration_seconds: Int?
    let recovery_pace: String?
    let recovery_description: String?
    let variant: String?
}

private struct V3RunSegment: Decodable {
    let distance_km: Double?
    let pace: String?
    let description: String?
    let heart_rate_range: HeartRateRange?
}

private struct V3StrengthActivity: Decodable {
    let strength_type: String?
    let exercises: [V3Exercise]?
    let duration_minutes: Int?
    let description: String?
}

private struct V3Exercise: Decodable {
    let exercise_id: String?
    let name: String?
    let sets: Int?
    let reps: Int?
    let duration_seconds: Int?
    let description: String?
}

private struct V3CrossActivity: Decodable {
    let cross_type: String?
    let duration_minutes: Int?
    let distance_km: Double?
    let description: String?
}

/// V3 warmup/cooldown 中繼解碼（snake_case JSON → RunSegmentV2）
private struct V3WarmupCooldown: Decodable {
    let distance_km: Double?
    let distance_m: Int?
    let duration_minutes: Int?
    let pace: String?
    let description: String?

    func toRunSegment() -> RunSegmentV2 {
        return RunSegmentV2(distanceKm: distance_km, distanceM: distance_m, distanceDisplay: nil, distanceUnit: nil, durationMinutes: duration_minutes, durationSeconds: nil, pace: pace, heartRateRange: nil, intensity: nil, description: description)
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

    init(dayIndex: String, dayTarget: String, reason: String?, tips: String?, trainingType: String, trainingDetails: TrainingDetails?) {
        self.dayIndex = dayIndex
        self.dayTarget = dayTarget
        self.reason = reason
        self.tips = tips
        self.trainingType = trainingType
        self.trainingDetails = trainingDetails
    }

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
        // V3 keys
        case category, primary, warmup, cooldown
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

        // V3 偵測：category 欄位存在 → V3 模式
        if let category = try container.decodeIfPresent(String.self, forKey: .category) {
            // 解碼 warmup/cooldown（V3 在 day 層級，snake_case）
            let v3Warmup = try container.decodeIfPresent(V3WarmupCooldown.self, forKey: .warmup)?.toRunSegment()
            let v3Cooldown = try container.decodeIfPresent(V3WarmupCooldown.self, forKey: .cooldown)?.toRunSegment()

            switch category {
            case "run":
                if let run = try container.decodeIfPresent(V3RunActivity.self, forKey: .primary) {
                    let mapped = TrainingDay.mapV3Run(run, warmup: v3Warmup, cooldown: v3Cooldown)
                    trainingType = mapped.type
                    trainingDetails = mapped.details
                } else {
                    // V3 format 但缺少 primary 欄位（v1 課表混用 v2 endpoint 產生的異常資料），退回 V2 解析
                    trainingType = (try? container.decode(String.self, forKey: .trainingType)) ?? "rest"
                    trainingDetails = try container.decodeIfPresent(TrainingDetails.self, forKey: .trainingDetails)
                }
            case "strength":
                let strength = try container.decodeIfPresent(V3StrengthActivity.self, forKey: .primary)
                trainingType = "strength"
                let exercises: [ExerciseV2]? = strength?.exercises?.compactMap { ex -> ExerciseV2? in
                    guard let name = ex.name else { return nil }
                    return ExerciseV2(exerciseId: ex.exercise_id, name: name, sets: ex.sets, reps: ex.reps != nil ? "\(ex.reps!)" : nil, durationSeconds: ex.duration_seconds, weightKg: nil, restSeconds: nil, description: ex.description ?? "")
                }
                trainingDetails = TrainingDetails(
                    description: strength?.description,
                    distanceKm: nil, totalDistanceKm: nil,
                    timeMinutes: strength?.duration_minutes != nil ? Double(strength!.duration_minutes!) : nil,
                    pace: nil, work: nil, recovery: nil, repeats: nil,
                    heartRateRange: nil, segments: nil,
                    warmup: nil, cooldown: nil,
                    exercises: exercises,
                    supplementary: nil
                )
            case "cross":
                let cross = try container.decodeIfPresent(V3CrossActivity.self, forKey: .primary)
                let crossType = cross?.cross_type ?? "cross_training"
                switch crossType {
                case "cycling": trainingType = "cycling"
                case "yoga": trainingType = "yoga"
                case "hiking": trainingType = "hiking"
                case "swimming": trainingType = "swimming"
                case "elliptical": trainingType = "elliptical"
                case "rowing": trainingType = "rowing"
                default: trainingType = "cross_training"
                }
                trainingDetails = TrainingDetails(
                    description: cross?.description,
                    distanceKm: cross?.distance_km, totalDistanceKm: nil,
                    timeMinutes: cross?.duration_minutes != nil ? Double(cross!.duration_minutes!) : nil,
                    pace: nil, work: nil, recovery: nil, repeats: nil,
                    heartRateRange: nil, segments: nil,
                    warmup: nil, cooldown: nil, exercises: nil, supplementary: nil
                )
            case "rest":
                trainingType = "rest"
                trainingDetails = nil
            default:
                trainingType = "rest"
                trainingDetails = nil
            }
        } else {
            // V2 模式（向下相容）
            trainingType = try container.decode(String.self, forKey: .trainingType)
            trainingDetails = try container.decodeIfPresent(TrainingDetails.self, forKey: .trainingDetails)
        }
    }

    /// V3 RunActivity → (trainingType, trainingDetails) 映射
    private static func mapV3Run(_ run: V3RunActivity, warmup: RunSegmentV2?, cooldown: RunSegmentV2?) -> (type: String, details: TrainingDetails?) {
        let runType = run.run_type

        // 判斷 trainingType
        let mappedType: String
        switch runType {
        case "interval":
            if let variant = run.interval?.variant {
                mappedType = variant  // variant 直接映射到舊 DayType rawValue
            } else {
                mappedType = "interval"
            }
        case "fartlek":
            mappedType = "fartlek"
        default:
            // easy, lsd, tempo, threshold, race_pace, progression, race 等直接對應
            mappedType = runType
        }

        // 間歇類型（interval/fartlek with interval block）
        if let iv = run.interval {
            let work = WorkoutSegment(
                description: iv.work_description,
                distanceKm: iv.work_distance_km,
                distanceM: iv.work_distance_m != nil ? Double(iv.work_distance_m!) : nil,
                timeMinutes: iv.work_duration_minutes != nil ? Double(iv.work_duration_minutes!) : nil,
                timeSeconds: nil,
                pace: iv.work_pace
            )
            let recovery = WorkoutSegment(
                description: iv.recovery_description,
                distanceKm: iv.recovery_distance_km,
                distanceM: iv.recovery_distance_m != nil ? Double(iv.recovery_distance_m!) : nil,
                timeMinutes: iv.recovery_duration_minutes != nil ? Double(iv.recovery_duration_minutes!) : nil,
                timeSeconds: iv.recovery_duration_seconds,
                pace: iv.recovery_pace
            )
            let details = TrainingDetails(
                description: run.description,
                distanceKm: run.distance_km, totalDistanceKm: nil,
                timeMinutes: nil, pace: nil,
                work: work, recovery: recovery, repeats: iv.repeats,
                heartRateRange: run.heart_rate_range, segments: nil,
                warmup: warmup, cooldown: cooldown, exercises: nil, supplementary: nil
            )
            return (mappedType, details)
        }

        // 分段類型（有 segments）
        if let segs = run.segments, !segs.isEmpty {
            let progressionSegments = segs.map { seg in
                ProgressionSegment(
                    distanceKm: seg.distance_km,
                    pace: seg.pace,
                    description: seg.description,
                    heartRateRange: seg.heart_rate_range
                )
            }
            let totalDist = segs.compactMap { $0.distance_km }.reduce(0, +)
            let details = TrainingDetails(
                description: run.description,
                distanceKm: nil, totalDistanceKm: totalDist > 0 ? totalDist : run.distance_km,
                timeMinutes: nil, pace: nil,
                work: nil, recovery: nil, repeats: nil,
                heartRateRange: run.heart_rate_range, segments: progressionSegments,
                warmup: warmup, cooldown: cooldown, exercises: nil, supplementary: nil
            )
            return (mappedType, details)
        }

        // 簡單跑步類型
        let details = TrainingDetails(
            description: run.description,
            distanceKm: run.distance_km, totalDistanceKm: nil,
            timeMinutes: run.duration_minutes != nil ? Double(run.duration_minutes!) : nil,
            pace: run.pace,
            work: nil, recovery: nil, repeats: nil,
            heartRateRange: run.heart_rate_range, segments: nil,
            warmup: warmup, cooldown: cooldown, exercises: nil, supplementary: nil
        )
        return (mappedType, details)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(dayIndex, forKey: .dayIndex)
        try container.encode(dayTarget, forKey: .dayTarget)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encodeIfPresent(tips, forKey: .tips)
        try container.encode(trainingType, forKey: .trainingType)

        // 只在有 trainingDetails 且不是休息日時才編碼 training_details
        if let trainingDetails = trainingDetails, trainingType != "rest" {
            try container.encode(trainingDetails, forKey: .trainingDetails)
        }
        // 對於休息日或 trainingDetails 為 nil 的情況，完全不包含 training_details 字段
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
                        durationMinutes: nil, durationSeconds: nil,
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
            // 間歇訓練類型（包含新增的大步跑、山坡重複跑、巡航間歇、短間歇、長間歇、挪威4x4、亞索800）
            case .interval, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .yasso800:
                var items: [WeeklyTrainingItem] = []
                // work 和 repeats 是必須的，recovery 可選（nil 表示原地休息）
                if let work = details.work, let repeats = details.repeats {
                    // 優先使用 distanceKm，如果為 nil 則使用 distanceM 轉換
                    let workDistance: Double? = {
                        if let km = work.distanceKm {
                            return km
                        } else if let m = work.distanceM {
                            return m / 1000.0  // 米轉公里
                        }
                        return nil
                    }()

                    // 根據類型獲取本地化名稱
                    let intervalTypeName: String = {
                        switch type {
                        case .strides: return L10n.Training.TrainingType.strides.localized
                        case .hillRepeats: return L10n.Training.TrainingType.hillRepeats.localized
                        case .cruiseIntervals: return L10n.Training.TrainingType.cruiseIntervals.localized
                        case .shortInterval: return L10n.Training.TrainingType.shortInterval.localized
                        case .longInterval: return L10n.Training.TrainingType.longInterval.localized
                        case .norwegian4x4: return L10n.Training.TrainingType.norwegian4x4.localized
                        case .yasso800: return L10n.Training.TrainingType.yasso800.localized
                        default: return L10n.Training.TrainingType.interval.localized
                        }
                    }()

                    let workItem = WeeklyTrainingItem(
                        name: intervalTypeName,
                        runDetails: work.description ?? "",
                        durationMinutes: nil, durationSeconds: nil,
                        goals: TrainingGoals(pace: work.pace, distanceKm: workDistance, heartRateRange: nil, heartRate: nil, times: repeats)
                    )
                    items.append(workItem)

                    // recovery 為 nil 時表示原地休息，建立一個空的恢復段
                    // 優先使用 timeSeconds，沒有則用 timeMinutes * 60 轉換成秒數
                    let recoveryDurationSeconds: Int? = {
                        if let seconds = details.recovery?.timeSeconds {
                            Logger.debug("[WeeklyPlan] 恢復段計算: 使用 timeSeconds = \(seconds)")
                            return seconds
                        } else if let minutes = details.recovery?.timeMinutes {
                            let calculated = Int(round(minutes * 60))
                            Logger.debug("[WeeklyPlan] 恢復段計算: 使用 timeMinutes = \(minutes) 轉換為 \(calculated)秒")
                            return calculated
                        }
                        Logger.debug("[WeeklyPlan] 恢復段計算: 無時間數據（timeSeconds=\(details.recovery?.timeSeconds ?? -1), timeMinutes=\(details.recovery?.timeMinutes ?? -1)）")
                        return nil
                    }()
                    let recoveryPace = details.recovery?.pace

                    // 優先使用 distanceKm，如果為 nil 則使用 distanceM 轉換
                    let recoveryDistance: Double? = {
                        if let km = details.recovery?.distanceKm {
                            return km
                        } else if let m = details.recovery?.distanceM {
                            return m / 1000.0  // 米轉公里
                        }
                        return nil
                    }()

                    // 優先找不為 0 的來算，如果兩個都不為 0 就都保留不處理
                    let recoveryDurationMinutes: Double? = {
                        if let seconds = details.recovery?.timeSeconds, seconds > 0 {
                            return Double(seconds) / 60.0
                        } else {
                            return details.recovery?.timeMinutes
                        }
                    }()

                    let recoveryItem = WeeklyTrainingItem(
                        name: L10n.Training.TrainingType.recovery.localized,
                        runDetails: details.recovery?.description ?? "",
                        durationMinutes: recoveryDurationMinutes,
                        durationSeconds: recoveryDurationSeconds,        // 精確秒數用於主畫面顯示
                        goals: TrainingGoals(pace: recoveryPace, distanceKm: recoveryDistance, heartRateRange: nil, heartRate: nil, times: repeats)
                    )
                    items.append(recoveryItem)
                    return items
                }
            // 節奏/閾值類型（包含新增的比賽配速跑）
            case .tempo, .threshold, .racePace:
                if let distance = details.distanceKm {
                    let description = details.description ?? ""
                    let typeName: String = {
                        switch type {
                        case .tempo: return L10n.Training.TrainingType.tempo.localized
                        case .threshold: return L10n.Training.TrainingType.threshold.localized
                        case .racePace: return L10n.Training.TrainingType.racePace.localized
                        default: return L10n.Training.TrainingType.tempo.localized
                        }
                    }()
                    let item = WeeklyTrainingItem(
                        name: typeName,
                        runDetails: description,
                        durationMinutes: nil, durationSeconds: nil,
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
                        durationMinutes: nil, durationSeconds: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: totalDistance, heartRateRange: nil, heartRate: nil, times: nil)
                    )
                    return [item]
                }
            // 組合訓練類型（包含新增的法特雷克、快結尾長跑）
            case .combination, .fartlek, .fastFinish:
                if let _ = details.segments, let totalDistance = details.totalDistanceKm {
                    let description = details.description ?? ""
                    let typeName: String = {
                        switch type {
                        case .fartlek: return L10n.Training.TrainingType.fartlek.localized
                        case .fastFinish: return L10n.Training.TrainingType.fastFinish.localized
                        default: return L10n.Training.TrainingType.combination.localized
                        }
                    }()
                    let item = WeeklyTrainingItem(
                        name: typeName,
                        runDetails: description,
                        durationMinutes: nil, durationSeconds: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: totalDistance, heartRateRange: nil, heartRate: nil, times: nil)
                    )
                    return [item]
                }
            case .race:
                let description = details.description ?? ""
                let item = WeeklyTrainingItem(
                        name: L10n.Training.TrainingType.race.localized,
                        runDetails: description,
                        durationMinutes: nil, durationSeconds: nil,
                        goals: TrainingGoals(pace: nil, distanceKm: nil, heartRateRange: nil, heartRate: nil, times: nil)
                    )
                    return [item]
            case .crossTraining, .hiking, .strength, .yoga, .cycling, .swimming, .elliptical, .rowing:
                let description = details.description ?? ""
                let activityName: String = {
                    switch type {
                    case .crossTraining: return L10n.Training.TrainingType.crossTraining.localized
                    case .hiking: return L10n.Training.TrainingType.hiking.localized
                    case .strength: return L10n.Training.TrainingType.strength.localized
                    case .yoga: return L10n.Training.TrainingType.yoga.localized
                    case .cycling: return L10n.Training.TrainingType.cycling.localized
                    case .swimming: return L10n.ActivityType.swimming.localized
                    case .elliptical: return L10n.ActivityType.elliptical.localized
                    case .rowing: return L10n.ActivityType.rowing.localized
                    default: return L10n.Training.TrainingType.crossTraining.localized
                    }
                }()
                let item = WeeklyTrainingItem(
                        name: activityName,
                        runDetails: description,
                        durationMinutes: nil, durationSeconds: nil,
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

    // V2 新增欄位 - 所有設為可選以確保向下兼容
    let warmup: RunSegmentV2?           // 暖身段
    let cooldown: RunSegmentV2?         // 緩和段
    let exercises: [ExerciseV2]?        // 力量訓練動作清單
    let supplementary: [SupplementaryActivityV2]?  // 補充訓練

    /// 明確的 memberwise init（供 V3 解碼映射使用）
    init(description: String?, distanceKm: Double?, totalDistanceKm: Double?, timeMinutes: Double?, pace: String?, work: WorkoutSegment?, recovery: WorkoutSegment?, repeats: Int?, heartRateRange: HeartRateRange?, segments: [ProgressionSegment]?, warmup: RunSegmentV2? = nil, cooldown: RunSegmentV2? = nil, exercises: [ExerciseV2]? = nil, supplementary: [SupplementaryActivityV2]? = nil) {
        self.description = description
        self.distanceKm = distanceKm
        self.totalDistanceKm = totalDistanceKm
        self.timeMinutes = timeMinutes
        self.pace = pace
        self.work = work
        self.recovery = recovery
        self.repeats = repeats
        self.heartRateRange = heartRateRange
        self.segments = segments
        self.warmup = warmup
        self.cooldown = cooldown
        self.exercises = exercises
        self.supplementary = supplementary
    }

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
               lhs.segments == rhs.segments &&
               lhs.warmup == rhs.warmup &&
               lhs.cooldown == rhs.cooldown &&
               lhs.exercises == rhs.exercises &&
               lhs.supplementary == rhs.supplementary
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
        case warmup
        case cooldown
        case exercises
        case supplementary
    }

    /// 自定義編碼器 - 確保 nil 值被編碼為 null
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(description, forKey: .description)
        try container.encode(distanceKm, forKey: .distanceKm)
        try container.encode(totalDistanceKm, forKey: .totalDistanceKm)
        try container.encode(timeMinutes, forKey: .timeMinutes)
        try container.encode(pace, forKey: .pace)
        try container.encode(work, forKey: .work)
        try container.encode(recovery, forKey: .recovery)
        try container.encode(repeats, forKey: .repeats)
        try container.encode(heartRateRange, forKey: .heartRateRange)
        try container.encode(segments, forKey: .segments)
        try container.encodeIfPresent(warmup, forKey: .warmup)
        try container.encodeIfPresent(cooldown, forKey: .cooldown)
        try container.encodeIfPresent(exercises, forKey: .exercises)
        try container.encodeIfPresent(supplementary, forKey: .supplementary)
    }
}

struct WorkoutSegment: Codable, Equatable {
    let description: String?  // 改為可選，間歇恢復段可能沒有描述
    let distanceKm: Double?  // 改為可選，因為 API 可能返回 null
    let distanceM: Double?   // 添加米的距離欄位
    let timeMinutes: Double? // 分鐘（后端改成 int，會失去精度）
    let timeSeconds: Int?    // 精確秒數（optional，優先使用）
    let pace: String?
    let heartRateRange: HeartRateRange?  // 添加心率區間欄位

    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case distanceM = "distance_m"
        case timeMinutes = "time_minutes"
        case timeSeconds = "time_seconds"
        case pace
        case heartRateRange = "heart_rate_range"
    }

    /// 自定義初始化器
    init(
        description: String? = nil,
        distanceKm: Double? = nil,
        distanceM: Double? = nil,
        timeMinutes: Double? = nil,
        timeSeconds: Int? = nil,
        pace: String? = nil,
        heartRateRange: HeartRateRange? = nil
    ) {
        self.description = description
        self.distanceKm = distanceKm
        self.distanceM = distanceM
        self.timeMinutes = timeMinutes
        self.timeSeconds = timeSeconds
        self.pace = pace
        self.heartRateRange = heartRateRange
    }

    /// 自定義解碼器 - 確保 timeSeconds 被正確解析
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        description = try container.decodeIfPresent(String.self, forKey: .description)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        distanceM = try container.decodeIfPresent(Double.self, forKey: .distanceM)
        timeMinutes = try container.decodeIfPresent(Double.self, forKey: .timeMinutes)

        // 優先解析 timeSeconds（Int），如果失敗則嘗試用 Double 轉換
        if let seconds = try container.decodeIfPresent(Int.self, forKey: .timeSeconds) {
            timeSeconds = seconds
        } else if let secondsDouble = try container.decodeIfPresent(Double.self, forKey: .timeSeconds) {
            timeSeconds = Int(round(secondsDouble))
        } else {
            timeSeconds = nil
        }

        pace = try container.decodeIfPresent(String.self, forKey: .pace)
        heartRateRange = try container.decodeIfPresent(HeartRateRange.self, forKey: .heartRateRange)
    }

    /// 自定義編碼器 - 確保 nil 值被編碼為 null（而非省略）
    /// 這對於原地休息很重要：需要明確告訴後端刪除 pace 和 distanceKm
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // 明確編碼所有欄位，包括 nil 值
        try container.encode(description, forKey: .description)
        try container.encode(distanceKm, forKey: .distanceKm)
        try container.encode(distanceM, forKey: .distanceM)
        try container.encode(timeMinutes, forKey: .timeMinutes)
        try container.encode(timeSeconds, forKey: .timeSeconds)
        try container.encode(pace, forKey: .pace)
        try container.encode(heartRateRange, forKey: .heartRateRange)
    }
}

struct ProgressionSegment: Codable, Equatable {
    let distanceKm: Double?  // 改為可選，提高靈活性
    let pace: String?        // 改為可選，提高靈活性
    let description: String?
    let heartRateRange: HeartRateRange?  // 新增心率區間支援
    
    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case pace
        case description
        case heartRateRange = "heart_rate_range"
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
    case combination = "combination"

    // 新增間歇訓練類型
    case strides = "strides"                    // 大步跑
    case hillRepeats = "hill_repeats"           // 山坡重複跑
    case cruiseIntervals = "cruise_intervals"   // 巡航間歇
    case shortInterval = "short_interval"       // 短間歇
    case longInterval = "long_interval"         // 長間歇
    case norwegian4x4 = "norwegian_4x4"         // 挪威4x4訓練
    case yasso800 = "yasso_800"                 // 亞索800

    // 新增組合訓練類型
    case fartlek = "fartlek"                    // 法特雷克
    case fastFinish = "fast_finish"             // 快結尾長跑

    // 新增比賽配速訓練
    case racePace = "race_pace"                 // 比賽配速跑

    // V3 交叉訓練新增類型
    case swimming = "swimming"
    case elliptical = "elliptical"
    case rowing = "rowing"
}

struct WeeklyTrainingItem: Identifiable {
    var id = UUID()
    let name: String
    let runDetails: String
    let durationMinutes: Double?  // 向後兼容，用於一般訓練
    let durationSeconds: Int?     // 精確的秒數（間歇訓練恢復段使用）
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

// MARK: - V2 類型別名 (供 TrainingDetails 使用)

/// 從 V2 Domain 層引用的類型別名
/// 這些類型定義在 Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift
typealias RunSegmentV2 = RunSegment
typealias ExerciseV2 = Exercise
typealias SupplementaryActivityV2 = SupplementaryActivity
