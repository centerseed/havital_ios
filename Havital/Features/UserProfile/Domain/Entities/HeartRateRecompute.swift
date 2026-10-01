import Foundation

// MARK: - 改心率後重算過去的跑力（SPEC-hr-zones §5.5／§5.8）

/// 使用者能選的重算範圍：從當地今天往前數、含今天的天數（後端只收這三個）。
enum HeartRateRecomputeDays: Int, CaseIterable, Equatable {
    case fourteen = 14
    case thirty = 30
    case sixty = 60
}

/// 重算範圍選單的一列：三個範圍，加上明確可見的「不重算」（只存心率、不開工作）。
enum HeartRateRecomputeChoice: Hashable {
    case days(HeartRateRecomputeDays)
    case skip
}

/// `PUT /user` 回應的 `heart_rate` 區塊。「有沒有變」只看後端，App 不自己比存前存後。
struct HeartRateChangeReport: Equatable {
    let changed: Bool
    let changedFields: [String]

    static let unchanged = HeartRateChangeReport(changed: false, changedFields: [])

    /// 沒有 `heart_rate` 區塊（舊後端、或這次沒動心率）＝沒變。
    static func parse(from rawData: Data) -> HeartRateChangeReport {
        guard
            let root = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
            let data = root["data"] as? [String: Any],
            let block = data["heart_rate"] as? [String: Any]
        else { return .unchanged }
        return HeartRateChangeReport(
            changed: (block["changed"] as? Bool) ?? false,
            changedFields: (block["changed_fields"] as? [String]) ?? []
        )
    }
}

/// 存下心率的結果：新區間＋後端說有沒有變。
struct HeartRateUpdateResult {
    let zones: [HeartRateZone]
    let changed: Bool
}

struct HeartRateRecomputeJob: Codable, Equatable {
    enum Status: String, Codable, Equatable {
        case queued
        case running
        case completed
        case failed
    }

    let jobId: String
    let status: Status
    let days: Int
    let total: Int
    let done: Int
    let recomputed: Int
    let skipped: Int
    let failed: Int
    let failedWorkoutIds: [String]
    let error: String?

    var isActive: Bool { status == .queued || status == .running }

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status, days, total, done, recomputed, skipped, failed, error
        case failedWorkoutIds = "failed_workout_ids"
    }

    init(jobId: String, status: Status, days: Int, total: Int, done: Int, recomputed: Int, skipped: Int, failed: Int, failedWorkoutIds: [String], error: String?) {
        self.jobId = jobId
        self.status = status
        self.days = days
        self.total = total
        self.done = done
        self.recomputed = recomputed
        self.skipped = skipped
        self.failed = failed
        self.failedWorkoutIds = failedWorkoutIds
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try c.decode(String.self, forKey: .jobId)
        status = try c.decode(Status.self, forKey: .status)
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        done = try c.decodeIfPresent(Int.self, forKey: .done) ?? 0
        recomputed = try c.decodeIfPresent(Int.self, forKey: .recomputed) ?? 0
        skipped = try c.decodeIfPresent(Int.self, forKey: .skipped) ?? 0
        failed = try c.decodeIfPresent(Int.self, forKey: .failed) ?? 0
        failedWorkoutIds = try c.decodeIfPresent([String].self, forKey: .failedWorkoutIds) ?? []
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// `POST /user/heart-rate/recompute` 的結果。訊息一律是後端依語言渲染好的字串。
enum HeartRateRecomputeOutcome: Equatable {
    case queued(job: HeartRateRecomputeJob, message: String?)
    case nothingToRecompute(message: String?)
    case alreadyRunning(job: HeartRateRecomputeJob, message: String?)
    case noHeartRateParameters(message: String?)
}

struct HeartRateRecomputeStatus: Equatable {
    let job: HeartRateRecomputeJob?
    let message: String?
}

/// 手錶最大心率與設定值長期偏差的提醒（僅 Garmin；`SPEC-hr-zones` §5.8）。
struct HeartRateWatchReminder: Codable, Equatable {
    let watchMaxHr: Int
    let profileMaxHr: Int
    let deviationPct: Double
    let since: String?
    let latestWorkoutDay: String?
    let watchRestingHr: Int?

    enum CodingKeys: String, CodingKey {
        case watchMaxHr = "watch_max_hr"
        case profileMaxHr = "profile_max_hr"
        case deviationPct = "deviation_pct"
        case since
        case latestWorkoutDay = "latest_workout_day"
        case watchRestingHr = "watch_resting_hr"
    }
}

/// 手錶自動更新最大心率之後，設定頁要寫的那一行（`SPEC-hr-zones` HZ-INV-18）。
/// `localDate` 是後端依使用者時區算好的 `YYYY-MM-DD`，App 不再換算。
struct HeartRateWatchAutoUpdate: Codable, Equatable {
    let localDate: String
    let maxHr: Int
    let previousMaxHr: Int?
    let deviationSince: String?

    enum CodingKeys: String, CodingKey {
        case localDate = "local_date"
        case maxHr = "max_hr"
        case previousMaxHr = "previous_max_hr"
        case deviationSince = "deviation_since"
    }
}

/// `GET /user/heart-rate/watch-check`：提醒（可能沒有）＋手錶自動更新說明（可能沒有）。
struct HeartRateWatchCheck: Equatable {
    let reminder: HeartRateWatchReminder?
    let autoUpdate: HeartRateWatchAutoUpdate?
}

/// 最大心率的來源（`SPEC-hr-zones` HZ-INV-02）。缺少或不認得的來源保持未記錄，不猜成系統預設。
enum HeartRateParameterSource: String, Codable, Equatable {
    case userSet = "user_set"
    case watch
    case observed
    case systemDefault = "system_default"
    case unrecorded

    init(raw: String?) {
        switch raw {
        case "user_set": self = .userSet
        case "watch": self = .watch
        case "observed": self = .observed
        case "system_default": self = .systemDefault
        default: self = .unrecorded
        }
    }

    var localizationKey: String {
        switch self {
        case .userSet: return "app2.hr_source.user_set"
        case .watch: return "app2.hr_source.watch"
        case .observed: return "app2.hr_source.observed"
        case .systemDefault: return "app2.hr_source.system_default"
        case .unrecorded: return "app2.hr_source.unrecorded"
        }
    }
}
