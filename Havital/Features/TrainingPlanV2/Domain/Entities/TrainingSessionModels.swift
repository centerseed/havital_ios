import Foundation

// MARK: - Training Session Models (V2.1+)
/// 新的訓練課程結構 - Domain Layer 業務實體
/// 根據 API 文件 TRAINING_V2_API_INTEGRATION_GUIDE.md

// MARK: - HeartRateRange

/// 心率區間
struct HeartRateRangeV2: Codable, Equatable {
    let min: Int?
    let max: Int?

    var isValid: Bool {
        return min != nil && max != nil
    }

    var displayText: String? {
        guard let minVal = min, let maxVal = max else { return nil }
        return "\(minVal)-\(maxVal)"
    }
}

// MARK: - RunSegment (暖身/緩和/分段)

/// 跑步分段 - 用於暖身、緩和或漸速跑的分段
struct RunSegment: Codable, Equatable {
    let distanceKm: Double?
    let distanceM: Int?
    let durationMinutes: Int?
    let durationSeconds: Int?
    let pace: String?
    let heartRateRange: HeartRateRangeV2?
    let intensity: String?
    let description: String?
}

// MARK: - IntervalBlock (間歇訓練)

/// 間歇訓練區塊
struct IntervalBlock: Codable, Equatable {
    let repeats: Int
    let workDistanceKm: Double?
    let workDistanceM: Int?
    let workDurationMinutes: Int?
    let workPace: String?
    let workDescription: String?
    let recoveryDistanceKm: Double?
    let recoveryDistanceM: Int?
    let recoveryDurationMinutes: Int?
    let recoveryPace: String?
    let recoveryDescription: String?
    let recoveryDurationSeconds: Int?
    let variant: String?
}

// MARK: - RunActivity (跑步活動)

/// 跑步活動
struct RunActivity: Codable, Equatable {
    let runType: String
    let distanceKm: Double?
    let durationMinutes: Int?
    let pace: String?
    let heartRateRange: HeartRateRangeV2?
    let interval: IntervalBlock?
    let segments: [RunSegment]?
    let description: String?
    let targetIntensity: String?
}

// MARK: - Exercise (單個動作)

/// 單個力量訓練動作
struct Exercise: Codable, Equatable {
    let name: String
    let sets: Int?
    let reps: String?
    let durationSeconds: Int?
    let weightKg: Double?
    let restSeconds: Int?
    let description: String?
}

// MARK: - StrengthActivity (力量訓練)

/// 力量訓練活動
struct StrengthActivity: Codable, Equatable {
    let strengthType: String
    let exercises: [Exercise]
    let durationMinutes: Int?
    let description: String?
}

// MARK: - CrossActivity (交叉訓練)

/// 交叉訓練活動
struct CrossActivity: Codable, Equatable {
    let crossType: String
    let durationMinutes: Int
    let distanceKm: Double?
    let intensity: String?
    let description: String?
}

// MARK: - Primary Activity (Union Type)

/// 主訓練活動 - 可以是跑步、力量或交叉訓練之一
/// Swift 使用 enum with associated values 來實現 Union Type
enum PrimaryActivity: Codable, Equatable {
    case run(RunActivity)
    case strength(StrengthActivity)
    case cross(CrossActivity)

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    private enum ActivityType: String, Codable {
        case run
        case strength
        case cross
    }

    init(from decoder: Decoder) throws {
        // 嘗試直接解碼為各種類型
        if let runActivity = try? RunActivity(from: decoder) {
            self = .run(runActivity)
            return
        }

        if let strengthActivity = try? StrengthActivity(from: decoder) {
            self = .strength(strengthActivity)
            return
        }

        if let crossActivity = try? CrossActivity(from: decoder) {
            self = .cross(crossActivity)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "無法解析 PrimaryActivity: 不符合任何已知類型"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .run(let activity):
            try activity.encode(to: encoder)
        case .strength(let activity):
            try activity.encode(to: encoder)
        case .cross(let activity):
            try activity.encode(to: encoder)
        }
    }
}

// MARK: - TrainingSession (訓練課程)

/// 訓練課程 - 包含暖身、主訓練、緩和、補充訓練
struct TrainingSession: Codable, Equatable {
    let warmup: RunSegment?
    let primary: PrimaryActivity
    let cooldown: RunSegment?
    let supplementary: [SupplementaryActivity]?
}

// MARK: - Supplementary Activity

/// 補充訓練 - 目前可以是力量訓練
/// 未來可能擴展其他類型
enum SupplementaryActivity: Codable, Equatable {
    case strength(StrengthActivity)
    case cross(CrossActivity)

    init(from decoder: Decoder) throws {
        if let strengthActivity = try? StrengthActivity(from: decoder) {
            self = .strength(strengthActivity)
            return
        }

        if let crossActivity = try? CrossActivity(from: decoder) {
            self = .cross(crossActivity)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "無法解析 SupplementaryActivity"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .strength(let activity):
            try activity.encode(to: encoder)
        case .cross(let activity):
            try activity.encode(to: encoder)
        }
    }
}

// MARK: - DayDetail (訓練日詳情)

/// 訓練日詳情 - V2.1+ 新結構,取代 TrainingDay
struct DayDetail: Codable, Identifiable, Equatable {
    let dayIndex: Int  // 1-7
    let dayTarget: String
    let reason: String
    let tips: String?
    let category: TrainingCategory?  // ✅ 改為可選，API 可能返回 null
    let session: TrainingSession?  // rest 日為 nil

    var id: Int { dayIndex }
}

// MARK: - TrainingCategory (訓練大類)

/// 訓練大類
enum TrainingCategory: String, Codable {
    case run
    case strength
    case cross
    case rest
}

// MARK: - V1 Compatibility Layer (兼容層)

/// DayDetail 的 V1 兼容層,使其可以在現有的 V1 UI 組件中使用
extension DayDetail {
    /// V1 兼容: dayIndexInt (V2 已經是 Int 類型,直接返回)
    var dayIndexInt: Int {
        return dayIndex
    }

    /// 主活動描述（直接取自 V2 session.primary）
    var primaryDescription: String? {
        guard let session = session else { return nil }
        switch session.primary {
        case .run(let a): return a.description
        case .strength(let a): return a.description
        case .cross(let a): return a.description
        }
    }

    /// V1 兼容: 從 category 和 session 推斷 DayType
    var type: DayType {
        // ✅ 處理 category 為 nil 或 .rest 的情況
        if category == nil || category == .rest {
            return .rest
        }

        // 從 session 的 primary activity 推斷具體訓練類型
        guard let session = session else {
            return .rest
        }

        switch session.primary {
        case .run(let runActivity):
            return inferRunType(from: runActivity)
        case .strength:
            return .strength
        case .cross(let crossActivity):
            return inferCrossType(from: crossActivity)
        }
    }

    /// V1 兼容: 將 TrainingSession 轉換為 TrainingDetails
    var trainingDetails: TrainingDetails? {
        guard let session = session else {
            return nil
        }

        return convertToTrainingDetails(from: session)
    }

    // MARK: - Private Helpers

    /// 從 RunActivity 推斷 DayType
    private func inferRunType(from activity: RunActivity) -> DayType {
        let runType = activity.runType.lowercased()

        // 直接映射的類型
        switch runType {
        case "easy", "easy_run":
            return .easy
        case "lsd", "long_slow_distance":
            return .lsd
        case "tempo":
            return .tempo
        case "threshold":
            return .threshold
        case "interval":
            // 後端會將 norwegian_4x4、yasso_800 等正規化為 "interval"，原始類型存於 interval.variant
            if let variant = activity.interval?.variant {
                switch variant.lowercased() {
                case "norwegian_4x4": return .norwegian4x4
                case "yasso_800": return .yasso800
                case "strides": return .strides
                case "hill_repeats": return .hillRepeats
                case "cruise_intervals": return .cruiseIntervals
                case "short_interval": return .shortInterval
                case "long_interval": return .longInterval
                default: break
                }
            }
            return .interval
        case "progression":
            return .progression
        case "race":
            return .race
        case "race_pace":
            return .racePace
        case "recovery", "recovery_run":
            return .recovery_run
        case "long_run":
            return .longRun

        // 間歇訓練子類型
        case "strides":
            return .strides
        case "hill_repeats":
            return .hillRepeats
        case "cruise_intervals":
            return .cruiseIntervals
        case "short_interval":
            return .shortInterval
        case "long_interval":
            return .longInterval
        case "norwegian_4x4":
            return .norwegian4x4
        case "yasso_800":
            return .yasso800

        // 組合訓練類型
        case "fartlek":
            return .fartlek
        case "fast_finish":
            return .fastFinish
        case "combination":
            return .combination

        default:
            // 默認根據是否有間歇或分段來判斷
            if activity.interval != nil {
                return .interval
            } else if activity.segments != nil {
                return .progression
            } else {
                return .easy
            }
        }
    }

    /// 從 CrossActivity 推斷 DayType
    private func inferCrossType(from activity: CrossActivity) -> DayType {
        let crossType = activity.crossType.lowercased()

        switch crossType {
        case "hiking":
            return .hiking
        case "yoga":
            return .yoga
        case "cycling":
            return .cycling
        default:
            return .crossTraining
        }
    }

    /// 將 TrainingSession 轉換為 TrainingDetails
    private func convertToTrainingDetails(from session: TrainingSession) -> TrainingDetails {
        // 先轉換主訓練
        var details: TrainingDetails
        switch session.primary {
        case .run(let runActivity):
            details = convertRunActivityToDetails(runActivity)
        case .strength(let strengthActivity):
            details = convertStrengthActivityToDetails(strengthActivity)
        case .cross(let crossActivity):
            details = convertCrossActivityToDetails(crossActivity)
        }

        // 合併 warmup/cooldown/supplementary (V2 新功能)
        details = TrainingDetails(
            description: details.description,
            distanceKm: details.distanceKm,
            totalDistanceKm: details.totalDistanceKm,
            timeMinutes: details.timeMinutes,
            pace: details.pace,
            work: details.work,
            recovery: details.recovery,
            repeats: details.repeats,
            heartRateRange: details.heartRateRange,
            segments: details.segments,
            warmup: session.warmup,
            cooldown: session.cooldown,
            exercises: details.exercises,
            supplementary: session.supplementary
        )

        return details
    }

    /// 將 RunActivity 轉換為 TrainingDetails
    private func convertRunActivityToDetails(_ activity: RunActivity) -> TrainingDetails {
        // 轉換心率區間
        let heartRateRange: HeartRateRange? = activity.heartRateRange.map {
            HeartRateRange(min: $0.min, max: $0.max)
        }

        // 如果有間歇訓練
        if let interval = activity.interval {
            let work = WorkoutSegment(
                description: interval.workDescription,
                distanceKm: interval.workDistanceKm,
                distanceM: interval.workDistanceM.map { Double($0) },
                timeMinutes: interval.workDurationMinutes.map { Double($0) },
                timeSeconds: nil,
                pace: interval.workPace,
                heartRateRange: nil
            )

            let recovery = WorkoutSegment(
                description: interval.recoveryDescription,
                distanceKm: interval.recoveryDistanceKm,
                distanceM: interval.recoveryDistanceM.map { Double($0) },
                timeMinutes: interval.recoveryDurationMinutes.map { Double($0) },
                timeSeconds: nil,
                pace: interval.recoveryPace,
                heartRateRange: nil
            )

            return TrainingDetails(
                description: activity.description,
                distanceKm: activity.distanceKm,
                totalDistanceKm: nil,
                timeMinutes: activity.durationMinutes.map { Double($0) },
                pace: activity.pace,
                work: work,
                recovery: recovery,
                repeats: interval.repeats,
                heartRateRange: heartRateRange,
                segments: nil,
                warmup: nil,
                cooldown: nil,
                exercises: nil,
                supplementary: nil
            )
        }

        // 如果有分段訓練
        if let segments = activity.segments {
            let progressionSegments = segments.map { segment in
                ProgressionSegment(
                    distanceKm: segment.distanceKm,
                    pace: segment.pace,
                    description: segment.description,
                    heartRateRange: segment.heartRateRange.map {
                        HeartRateRange(min: $0.min, max: $0.max)
                    }
                )
            }

            // 計算總距離
            let totalDistance = segments.reduce(0.0) { sum, segment in
                sum + (segment.distanceKm ?? (segment.distanceM.map { Double($0) / 1000.0 } ?? 0))
            }

            return TrainingDetails(
                description: activity.description,
                distanceKm: nil,
                totalDistanceKm: totalDistance > 0 ? totalDistance : activity.distanceKm,
                timeMinutes: activity.durationMinutes.map { Double($0) },
                pace: activity.pace,
                work: nil,
                recovery: nil,
                repeats: nil,
                heartRateRange: heartRateRange,
                segments: progressionSegments,
                warmup: nil,
                cooldown: nil,
                exercises: nil,
                supplementary: nil
            )
        }

        // 一般跑步訓練
        return TrainingDetails(
            description: activity.description,
            distanceKm: activity.distanceKm,
            totalDistanceKm: nil,
            timeMinutes: activity.durationMinutes.map { Double($0) },
            pace: activity.pace,
            work: nil,
            recovery: nil,
            repeats: nil,
            heartRateRange: heartRateRange,
            segments: nil,
            warmup: nil,
            cooldown: nil,
            exercises: nil,
            supplementary: nil
        )
    }

    /// 將 StrengthActivity 轉換為 TrainingDetails
    private func convertStrengthActivityToDetails(_ activity: StrengthActivity) -> TrainingDetails {
        return TrainingDetails(
            description: activity.description,
            distanceKm: nil,
            totalDistanceKm: nil,
            timeMinutes: activity.durationMinutes.map { Double($0) },
            pace: nil,
            work: nil,
            recovery: nil,
            repeats: nil,
            heartRateRange: nil,
            segments: nil,
            warmup: nil,
            cooldown: nil,
            exercises: activity.exercises,
            supplementary: nil
        )
    }

    /// 將 CrossActivity 轉換為 TrainingDetails
    private func convertCrossActivityToDetails(_ activity: CrossActivity) -> TrainingDetails {
        return TrainingDetails(
            description: activity.description,
            distanceKm: activity.distanceKm,
            totalDistanceKm: nil,
            timeMinutes: Double(activity.durationMinutes),
            pace: nil,
            work: nil,
            recovery: nil,
            repeats: nil,
            heartRateRange: nil,
            segments: nil,
            warmup: nil,
            cooldown: nil,
            exercises: nil,
            supplementary: nil
        )
    }
}
