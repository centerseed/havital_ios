import Foundation

// MARK: - Mutable Training Models for Editing

/// 可編輯的週課表模型
struct MutableWeeklyPlan {
    var id: String
    var purpose: String
    var weekOfPlan: Int
    var totalWeeks: Int
    var days: [MutableTrainingDay]
    var totalDistanceReason: String?
    var designReason: [String]?
    var intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes?

    /// 從 WeeklyPlan 初始化
    init(from plan: WeeklyPlan) {
        self.id = plan.id
        self.purpose = plan.purpose
        self.weekOfPlan = plan.weekOfPlan
        self.totalWeeks = plan.totalWeeks
        self.days = plan.days.map { MutableTrainingDay(from: $0) }
        self.totalDistanceReason = plan.totalDistanceReason
        self.designReason = plan.designReason
        self.intensityTotalMinutes = plan.intensityTotalMinutes
    }

    /// 轉換回 WeeklyPlan
    func toWeeklyPlan() -> WeeklyPlan {
        return WeeklyPlan(
            id: id,
            purpose: purpose,
            weekOfPlan: weekOfPlan,
            totalWeeks: totalWeeks,
            totalDistance: totalDistance,
            totalDistanceReason: totalDistanceReason,
            designReason: designReason,
            days: days.map { $0.toTrainingDay() },
            intensityTotalMinutes: intensityTotalMinutes
        )
    }

    /// 計算總距離
    var totalDistance: Double {
        days.compactMap { $0.trainingDetails?.distanceKm ?? $0.trainingDetails?.totalDistanceKm }.reduce(0, +)
    }
}

/// 可編輯的訓練日模型
struct MutableTrainingDay: Identifiable, Equatable {
    var id: String { dayIndex }
    var dayIndex: String
    var dayTarget: String
    var reason: String?
    var tips: String?
    var trainingType: String
    var trainingDetails: MutableTrainingDetails?

    /// 從 TrainingDay 初始化
    init(from day: TrainingDay) {
        self.dayIndex = day.dayIndex
        self.dayTarget = day.dayTarget
        self.reason = day.reason
        self.tips = day.tips
        self.trainingType = day.trainingType
        self.trainingDetails = day.trainingDetails.map { MutableTrainingDetails(from: $0) }
    }

    /// 轉換回 TrainingDay
    func toTrainingDay() -> TrainingDay {
        return TrainingDay(
            dayIndex: dayIndex,
            dayTarget: dayTarget,
            reason: reason,
            tips: tips,
            trainingType: trainingType,
            trainingDetails: trainingDetails?.toTrainingDetails()
        )
    }

    /// 計算訓練類型
    var type: DayType {
        DayType(rawValue: trainingType) ?? .rest
    }

    /// dayIndex 轉為 Int
    var dayIndexInt: Int {
        Int(dayIndex) ?? 0
    }

    /// 是否為訓練日
    var isTrainingDay: Bool {
        type != .rest
    }

    static func == (lhs: MutableTrainingDay, rhs: MutableTrainingDay) -> Bool {
        return lhs.dayIndex == rhs.dayIndex &&
               lhs.dayTarget == rhs.dayTarget &&
               lhs.trainingType == rhs.trainingType &&
               lhs.trainingDetails == rhs.trainingDetails
    }
}

/// 可編輯的訓練詳情模型
struct MutableTrainingDetails: Equatable {
    var description: String?
    var distanceKm: Double?
    var totalDistanceKm: Double?
    var timeMinutes: Double?
    var pace: String?
    var work: MutableWorkoutSegment?
    var recovery: MutableWorkoutSegment?
    var repeats: Int?
    var heartRateRange: HeartRateRange?
    var segments: [MutableProgressionSegment]?

    /// 從 TrainingDetails 初始化
    init(from details: TrainingDetails) {
        self.description = details.description
        self.distanceKm = details.distanceKm
        self.totalDistanceKm = details.totalDistanceKm
        self.timeMinutes = details.timeMinutes
        self.pace = details.pace
        self.work = details.work.map { MutableWorkoutSegment(from: $0) }
        self.recovery = details.recovery.map { MutableWorkoutSegment(from: $0) }
        self.repeats = details.repeats
        self.heartRateRange = details.heartRateRange
        self.segments = details.segments?.map { MutableProgressionSegment(from: $0) }
    }

    /// 自定義初始化器（用於編輯器）
    init(
        description: String? = nil,
        distanceKm: Double? = nil,
        totalDistanceKm: Double? = nil,
        timeMinutes: Double? = nil,
        pace: String? = nil,
        work: MutableWorkoutSegment? = nil,
        recovery: MutableWorkoutSegment? = nil,
        repeats: Int? = nil,
        heartRateRange: HeartRateRange? = nil,
        segments: [MutableProgressionSegment]? = nil
    ) {
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
    }

    /// 轉換回 TrainingDetails
    func toTrainingDetails() -> TrainingDetails {
        return TrainingDetails(
            description: description,
            distanceKm: distanceKm,
            totalDistanceKm: totalDistanceKm,
            timeMinutes: timeMinutes,
            pace: pace,
            work: work?.toWorkoutSegment(),
            recovery: recovery?.toWorkoutSegment(),
            repeats: repeats,
            heartRateRange: heartRateRange,
            segments: segments?.map { $0.toProgressionSegment() }
        )
    }

    static func == (lhs: MutableTrainingDetails, rhs: MutableTrainingDetails) -> Bool {
        return lhs.description == rhs.description &&
               lhs.distanceKm == rhs.distanceKm &&
               lhs.totalDistanceKm == rhs.totalDistanceKm &&
               lhs.pace == rhs.pace &&
               lhs.work == rhs.work &&
               lhs.recovery == rhs.recovery &&
               lhs.repeats == rhs.repeats &&
               lhs.segments == rhs.segments
    }
}

/// 可編輯的分段模型（用於組合跑/漸進跑）
struct MutableProgressionSegment: Identifiable, Equatable {
    let id = UUID()
    var distanceKm: Double?
    var pace: String?
    var description: String?
    var heartRateRange: HeartRateRange?

    /// 從 ProgressionSegment 初始化
    init(from segment: ProgressionSegment) {
        self.distanceKm = segment.distanceKm
        self.pace = segment.pace
        self.description = segment.description
        self.heartRateRange = segment.heartRateRange
    }

    /// 預設初始化（新增分段時使用）
    init(distanceKm: Double? = 2.0, pace: String? = "5:30", description: String? = "新分段") {
        self.distanceKm = distanceKm
        self.pace = pace
        self.description = description
        self.heartRateRange = nil
    }

    /// 轉換回 ProgressionSegment
    func toProgressionSegment() -> ProgressionSegment {
        return ProgressionSegment(
            distanceKm: distanceKm,
            pace: pace,
            description: description,
            heartRateRange: heartRateRange
        )
    }

    static func == (lhs: MutableProgressionSegment, rhs: MutableProgressionSegment) -> Bool {
        return lhs.id == rhs.id &&
               lhs.distanceKm == rhs.distanceKm &&
               lhs.pace == rhs.pace &&
               lhs.description == rhs.description
    }
}

/// 可編輯的訓練段模型（用於間歇訓練）
struct MutableWorkoutSegment: Equatable {
    var description: String?
    var distanceKm: Double?
    var distanceM: Double?
    var timeMinutes: Double?
    var pace: String?
    var heartRateRange: HeartRateRange?

    /// 從 WorkoutSegment 初始化
    init(from segment: WorkoutSegment) {
        self.description = segment.description
        self.distanceKm = segment.distanceKm
        self.distanceM = segment.distanceM
        self.timeMinutes = segment.timeMinutes
        self.pace = segment.pace
        self.heartRateRange = segment.heartRateRange
    }

    /// 自定義初始化器（用於編輯器）
    init(
        description: String? = nil,
        distanceKm: Double? = nil,
        distanceM: Double? = nil,
        timeMinutes: Double? = nil,
        pace: String? = nil,
        heartRateRange: HeartRateRange? = nil
    ) {
        self.description = description
        self.distanceKm = distanceKm
        self.distanceM = distanceM
        self.timeMinutes = timeMinutes
        self.pace = pace
        self.heartRateRange = heartRateRange
    }

    /// 轉換回 WorkoutSegment
    func toWorkoutSegment() -> WorkoutSegment {
        return WorkoutSegment(
            description: description,
            distanceKm: distanceKm,
            distanceM: distanceM,
            timeMinutes: timeMinutes,
            pace: pace,
            heartRateRange: heartRateRange
        )
    }

    static func == (lhs: MutableWorkoutSegment, rhs: MutableWorkoutSegment) -> Bool {
        return lhs.description == rhs.description &&
               lhs.distanceKm == rhs.distanceKm &&
               lhs.distanceM == rhs.distanceM &&
               lhs.pace == rhs.pace
    }
}

// MARK: - Codable Support for Mutable Types

extension MutableTrainingDetails: Codable {
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
    }
}

extension MutableProgressionSegment: Codable {
    enum CodingKeys: String, CodingKey {
        // id 不参与编解码，每次转换都会重新生成
        case distanceKm = "distance_km"
        case pace
        case description
        case heartRateRange = "heart_rate_range"
    }
}

extension MutableWorkoutSegment: Codable {
    enum CodingKeys: String, CodingKey {
        case description
        case distanceKm = "distance_km"
        case distanceM = "distance_m"
        case timeMinutes = "time_minutes"
        case pace
        case heartRateRange = "heart_rate_range"
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
        try container.encode(pace, forKey: .pace)
        try container.encode(heartRateRange, forKey: .heartRateRange)
    }
}
