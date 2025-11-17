import Foundation

// MARK: - Watch 同步數據模型

/// Watch 同步的週課表數據
struct WatchWeeklyPlan: Codable, Equatable {
    let id: String
    let weekOfPlan: Int
    let totalWeeks: Int
    let totalDistance: Double
    let days: [WatchTrainingDay]

    init(from weeklyPlan: WeeklyPlan) {
        self.id = weeklyPlan.id
        self.weekOfPlan = weeklyPlan.weekOfPlan
        self.totalWeeks = weeklyPlan.totalWeeks
        self.totalDistance = weeklyPlan.totalDistance
        self.days = weeklyPlan.days.map { WatchTrainingDay(from: $0) }
    }
}

/// Watch 端的每日訓練數據
struct WatchTrainingDay: Codable, Identifiable, Equatable {
    let id: String
    let dayIndex: String
    let dayTarget: String
    let trainingType: String
    let trainingDetails: WatchTrainingDetails?

    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayIndex) ?? Date()
    }

    var type: DayType {
        DayType(rawValue: trainingType) ?? .rest
    }

    var isTrainingDay: Bool {
        type != .rest
    }

    init(from trainingDay: TrainingDay) {
        self.id = trainingDay.id
        self.dayIndex = trainingDay.dayIndex
        self.dayTarget = trainingDay.dayTarget
        self.trainingType = trainingDay.trainingType
        self.trainingDetails = trainingDay.trainingDetails.map { WatchTrainingDetails(from: $0) }
    }
}

/// Watch 端的訓練詳情
struct WatchTrainingDetails: Codable, Equatable {
    let description: String?
    let distanceKm: Double?
    let totalDistanceKm: Double?
    let timeMinutes: Double?
    let pace: String?
    let work: WatchWorkoutSegment?
    let recovery: WatchWorkoutSegment?
    let repeats: Int?
    let heartRateRange: WatchHeartRateRange?
    let segments: [WatchProgressionSegment]?

    init(from details: TrainingDetails) {
        self.description = details.description
        self.distanceKm = details.distanceKm
        self.totalDistanceKm = details.totalDistanceKm
        self.timeMinutes = details.timeMinutes
        self.pace = details.pace
        self.work = details.work.map { WatchWorkoutSegment(from: $0) }
        self.recovery = details.recovery.map { WatchWorkoutSegment(from: $0) }
        self.repeats = details.repeats
        self.heartRateRange = details.heartRateRange.map { WatchHeartRateRange(from: $0) }
        self.segments = details.segments?.map { WatchProgressionSegment(from: $0) }
    }
}

/// Watch 端的間歇段數據
struct WatchWorkoutSegment: Codable, Equatable {
    let description: String?
    let distanceKm: Double?
    let distanceM: Double?
    let timeMinutes: Double?
    let pace: String?
    let heartRateRange: WatchHeartRateRange?

    init(from segment: WorkoutSegment) {
        self.description = segment.description
        self.distanceKm = segment.distanceKm
        self.distanceM = segment.distanceM
        self.timeMinutes = segment.timeMinutes
        self.pace = segment.pace
        self.heartRateRange = segment.heartRateRange.map { WatchHeartRateRange(from: $0) }
    }
}

/// Watch 端的心率範圍
struct WatchHeartRateRange: Codable, Equatable {
    let min: Int?
    let max: Int?

    var isValid: Bool {
        min != nil && max != nil
    }

    var displayText: String? {
        guard let minVal = min, let maxVal = max else { return nil }
        return "\(minVal)-\(maxVal) bpm"
    }

    init(from range: HeartRateRange) {
        self.min = range.min
        self.max = range.max
    }
}

/// Watch 端的分段數據（組合跑/漸進跑）
struct WatchProgressionSegment: Codable, Equatable {
    let distanceKm: Double?
    let pace: String?
    let description: String?
    let heartRateRange: WatchHeartRateRange?

    init(from segment: ProgressionSegment) {
        self.distanceKm = segment.distanceKm
        self.pace = segment.pace
        self.description = segment.description
        self.heartRateRange = segment.heartRateRange.map { WatchHeartRateRange(from: $0) }
    }
}

// MARK: - 用戶配置數據

/// Watch 端的用戶配置
struct WatchUserProfile: Codable, Equatable {
    let maxHR: Int
    let restingHR: Int
    let vdot: Double
    let heartRateZones: [WatchHeartRateZone]

    init(maxHR: Int, restingHR: Int, vdot: Double, zones: [HeartRateZonesManager.HeartRateZone]) {
        self.maxHR = maxHR
        self.restingHR = restingHR
        self.vdot = vdot
        self.heartRateZones = zones.map { WatchHeartRateZone(from: $0) }
    }
}

/// Watch 端的心率區間
struct WatchHeartRateZone: Codable, Equatable {
    let zone: Int
    let name: String
    let minHR: Int
    let maxHR: Int
    let description: String

    init(from zone: HeartRateZonesManager.HeartRateZone) {
        self.zone = zone.zone
        self.name = zone.name
        self.minHR = Int(zone.range.lowerBound)
        self.maxHR = Int(zone.range.upperBound)
        self.description = zone.description
    }
}

// MARK: - 同步消息

/// WatchConnectivity 消息類型
enum WatchSyncMessageType: String, Codable {
    case weeklyPlan = "weekly_plan"
    case userProfile = "user_profile"
    case syncRequest = "sync_request"
    case syncComplete = "sync_complete"
}

/// WatchConnectivity 消息包裝
struct WatchSyncMessage: Codable {
    let type: WatchSyncMessageType
    let data: Data
    let timestamp: Date

    init(type: WatchSyncMessageType, data: Data) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

/// 完整的同步數據包
struct WatchSyncData: Codable {
    let weeklyPlan: WatchWeeklyPlan?
    let userProfile: WatchUserProfile
    let lastSyncTime: Date

    init(weeklyPlan: WatchWeeklyPlan?, userProfile: WatchUserProfile) {
        self.weeklyPlan = weeklyPlan
        self.userProfile = userProfile
        self.lastSyncTime = Date()
    }
}
