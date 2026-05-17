import Foundation

enum AchievementChapter: String, CaseIterable, Equatable, Sendable {
    case start
    case build
    case adapt
    case prove
    case identity
    case unknown

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "start": self = .start
        case "build": self = .build
        case "adapt": self = .adapt
        case "prove": self = .prove
        case "identity": self = .identity
        default: self = .unknown
        }
    }

    var analyticsValue: String { rawValue }

    var localizedName: String {
        switch self {
        case .start: return L10n.Achievements.Chapter.start.localized
        case .build: return L10n.Achievements.Chapter.build.localized
        case .adapt: return L10n.Achievements.Chapter.adapt.localized
        case .prove: return L10n.Achievements.Chapter.prove.localized
        case .identity: return L10n.Achievements.Chapter.identity.localized
        case .unknown: return L10n.Achievements.Chapter.unknown.localized
        }
    }
}

enum AchievementBadgeStatus: String, Equatable, Sendable {
    case unlocked
    case inProgress = "in_progress"
    case locked
    case insufficientData = "insufficient_data"
    case unknown

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "unlocked": self = .unlocked
        case "in_progress": self = .inProgress
        case "locked": self = .locked
        case "insufficient_data": self = .insufficientData
        default: self = .unknown
        }
    }

    var localizedName: String {
        switch self {
        case .unlocked: return L10n.Achievements.Status.unlocked.localized
        case .inProgress: return L10n.Achievements.Status.inProgress.localized
        case .locked: return L10n.Achievements.Status.locked.localized
        case .insufficientData: return L10n.Achievements.Status.insufficientData.localized
        case .unknown: return L10n.Achievements.Status.unknown.localized
        }
    }
}

enum AchievementBackfillStatus: String, Equatable, Sendable {
    case notNeeded = "not_needed"
    case pending
    case completed
    case insufficientData = "insufficient_data"
    case unknown

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "not_needed": self = .notNeeded
        case "pending": self = .pending
        case "completed": self = .completed
        case "insufficient_data": self = .insufficientData
        default: self = .unknown
        }
    }
}

enum AchievementInsightConfidence: String, Equatable, Sendable {
    case high
    case medium
    case low
    case unknown

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "high": self = .high
        case "medium": self = .medium
        case "low": self = .low
        default: self = .unknown
        }
    }
}

enum AchievementShareableType: String, Equatable, Sendable {
    case badge
    case pb
    case weekComplete = "week_complete"
    case longRun = "long_run"
    case adjustment
    case insight
    case overview
    case unknown

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "badge": self = .badge
        case "pb": self = .pb
        case "week_complete": self = .weekComplete
        case "long_run": self = .longRun
        case "adjustment": self = .adjustment
        case "insight": self = .insight
        case "overview": self = .overview
        default: self = .unknown
        }
    }

    var analyticsValue: String { rawValue }
}

enum AchievementJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AchievementJSONValue])
    case object([String: AchievementJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AchievementJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AchievementJSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var displayString: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        case .bool(let value): return value ? "true" : "false"
        case .array, .object, .null: return ""
        }
    }
}

struct AchievementSummary: Equatable, Sendable {
    let generatedAt: String
    let catalogVersion: String
    let backfill: AchievementBackfill
    let storySummary: AchievementStorySummary
    let badgeGroups: [AchievementBadgeGroup]
    let pbOverview: AchievementPBOverview?
    let lifetimeStats: AchievementLifetimeStats
    let insights: [AchievementInsight]
    let recentShareables: [AchievementShareable]
    let unlockFeedbackQueue: [AchievementUnlockFeedback]
    let privacyPolicy: AchievementPrivacyPolicy

    var hasVisibleContent: Bool {
        storySummary.unlockedCount > 0
            || pbOverview?.records.isEmpty == false
            || lifetimeStats.hasAnyValue
            || !visibleInsights.isEmpty
            || !recentShareables.isEmpty
            || badgeGroups.contains { !$0.badges.isEmpty }
    }

    var visibleInsights: [AchievementInsight] {
        insights.filter { $0.confidence != .low }
    }
}

struct AchievementLifetimeStats: Equatable, Sendable {
    let totalRuns: Int
    let totalDistanceKm: Double
    let completedWeeks: Int
    let trainingWeeks: Int
    let longestRunKm: Double
    let firstWorkoutDate: String?

    static let empty = AchievementLifetimeStats(
        totalRuns: 0,
        totalDistanceKm: 0,
        completedWeeks: 0,
        trainingWeeks: 0,
        longestRunKm: 0,
        firstWorkoutDate: nil
    )

    var hasAnyValue: Bool {
        totalRuns > 0
            || totalDistanceKm > 0
            || completedWeeks > 0
            || trainingWeeks > 0
            || longestRunKm > 0
            || firstWorkoutDate != nil
    }
}

struct AchievementBackfill: Equatable, Sendable {
    let status: AchievementBackfillStatus
    let showBanner: Bool
    let bannerKey: String?
    let historicalUnlockCount: Int
    let acknowledgedAt: String?
}

struct AchievementStorySummary: Equatable, Sendable {
    let unlockedCount: Int
    let totalCount: Int
    let recentUnlock: AchievementBadgeSnapshot?
    let nextBadge: AchievementBadgeSnapshot?
    let emptyStateKey: String?
}

struct AchievementBadgeSnapshot: Equatable, Sendable {
    let badgeId: String
    let chapter: AchievementChapter
    let nameKey: String
    let storyKey: String?
    let status: AchievementBadgeStatus?
}

struct AchievementBadgeGroup: Identifiable, Equatable, Sendable {
    var id: AchievementChapter { chapter }
    let chapter: AchievementChapter
    let titleKey: String?
    let badges: [AchievementBadge]
}

struct AchievementBadge: Identifiable, Equatable, Sendable {
    var id: String { badgeId }
    let badgeId: String
    let chapter: AchievementChapter
    let nameKey: String
    let storyKey: String
    let status: AchievementBadgeStatus
    let progress: AchievementProgress?
    let unlockedAt: String?
    let unlockReasonKey: String?
    let sourceRef: AchievementSourceRef?
    let historicalBackfill: Bool
    let shareable: Bool
    let assetName: String?
}

struct AchievementProgress: Equatable, Sendable {
    let current: Double?
    let target: Double?
    let unitKey: String?
    let summaryKey: String?
    let summaryParams: [String: AchievementJSONValue]
}

struct AchievementSourceRef: Equatable, Sendable {
    let type: String
    let labelKey: String?
    let summaryKey: String?
    let summaryParams: [String: AchievementJSONValue]
}

struct AchievementPBOverview: Equatable, Sendable {
    let titleKey: String?
    let updatedAt: String?
    let records: [AchievementPBRecord]
}

struct AchievementPBRecord: Identifiable, Equatable, Sendable {
    var id: String { distance }
    let distance: String
    let displayDistance: String
    let time: String
    let achievedAt: String?
    let isRecent: Bool
}

struct AchievementInsight: Identifiable, Equatable, Sendable {
    var id: String { insightId }
    let insightId: String
    let type: String
    let displayKey: String
    let displayParams: [String: AchievementJSONValue]
    let evidence: [String: AchievementJSONValue]
    let confidence: AchievementInsightConfidence
    let shareable: Bool
}

struct AchievementShareable: Identifiable, Equatable, Sendable {
    var id: String { materialId }
    let materialId: String
    let materialType: AchievementShareableType
    let titleKey: String
    let summaryKey: String
    let summaryParams: [String: AchievementJSONValue]
    let publicFields: [AchievementPublicField]
    let defaultSensitiveFieldsEnabled: Bool
    let badgeId: String?
    let chapter: AchievementChapter?
}

struct AchievementPublicField: Identifiable, Equatable, Sendable {
    var id: String { key }
    let key: String
    let labelKey: String
    let value: String
}

struct AchievementUnlockFeedback: Identifiable, Equatable, Sendable {
    var id: String { feedbackId }
    let feedbackId: String
    let badgeId: String
    let chapter: AchievementChapter
    let nameKey: String
    let storyKey: String
}

struct AchievementPrivacyPolicy: Equatable, Sendable {
    let defaultExcludedFields: [String]
    let sensitiveFields: [String]
    let publicOnly: Bool
}

extension String {
    func achievementLocalized(params: [String: AchievementJSONValue]) -> String {
        guard !params.isEmpty else { return localized }
        let orderedArguments = params.keys.sorted().map { params[$0]?.displayString ?? "" }
        return String(format: NSLocalizedString(self, comment: ""), arguments: orderedArguments)
    }
}
