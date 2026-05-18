import Foundation

struct AchievementSummaryResponse: Codable, Equatable {
    let generatedAt: String
    let catalogVersion: String
    let backfill: AchievementBackfillDTO
    let storySummary: AchievementStorySummaryDTO
    let badgeGroups: [AchievementBadgeGroupDTO]
    let achievementTracks: [AchievementTrackDTO]
    let pbOverview: AchievementPBOverviewDTO?
    let lifetimeStats: AchievementLifetimeStatsDTO?
    let insights: [AchievementInsightDTO]
    let recentShareables: [AchievementShareableDTO]
    let unlockFeedbackQueue: [AchievementUnlockFeedbackDTO]
    let privacyPolicy: AchievementPrivacyPolicyDTO

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case catalogVersion = "catalog_version"
        case backfill
        case storySummary = "story_summary"
        case badgeGroups = "badge_groups"
        case achievementTracks = "achievement_tracks"
        case pbOverview = "pb_overview"
        case lifetimeStats = "lifetime_stats"
        case insights
        case recentShareables = "recent_shareables"
        case unlockFeedbackQueue = "unlock_feedback_queue"
        case privacyPolicy = "privacy_policy"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(String.self, forKey: .generatedAt)
        catalogVersion = try container.decode(String.self, forKey: .catalogVersion)
        backfill = try container.decode(AchievementBackfillDTO.self, forKey: .backfill)
        storySummary = try container.decode(AchievementStorySummaryDTO.self, forKey: .storySummary)
        badgeGroups = try container.decode([AchievementBadgeGroupDTO].self, forKey: .badgeGroups)
        achievementTracks = try container.decodeIfPresent([AchievementTrackDTO].self, forKey: .achievementTracks) ?? []
        pbOverview = try container.decodeIfPresent(AchievementPBOverviewDTO.self, forKey: .pbOverview)
        lifetimeStats = try container.decodeIfPresent(AchievementLifetimeStatsDTO.self, forKey: .lifetimeStats)
        insights = try container.decodeIfPresent([AchievementInsightDTO].self, forKey: .insights) ?? []
        recentShareables = try container.decodeIfPresent([AchievementShareableDTO].self, forKey: .recentShareables) ?? []
        unlockFeedbackQueue = try container.decodeIfPresent([AchievementUnlockFeedbackDTO].self, forKey: .unlockFeedbackQueue) ?? []
        privacyPolicy = try container.decode(AchievementPrivacyPolicyDTO.self, forKey: .privacyPolicy)
    }
}

struct AchievementLifetimeStatsDTO: Codable, Equatable {
    let totalRuns: Int
    let totalDistanceKm: Double
    let completedWeeks: Int
    let trainingWeeks: Int
    let longestRunKm: Double
    let firstWorkoutDate: String?

    enum CodingKeys: String, CodingKey {
        case totalRuns = "total_runs"
        case totalDistanceKm = "total_distance_km"
        case completedWeeks = "completed_weeks"
        case trainingWeeks = "training_weeks"
        case longestRunKm = "longest_run_km"
        case firstWorkoutDate = "first_workout_date"
    }
}

struct AchievementBackfillDTO: Codable, Equatable {
    let status: String
    let showBanner: Bool
    let bannerKey: String?
    let historicalUnlockCount: Int
    let acknowledgedAt: String?

    enum CodingKeys: String, CodingKey {
        case status
        case showBanner = "show_banner"
        case bannerKey = "banner_key"
        case historicalUnlockCount = "historical_unlock_count"
        case acknowledgedAt = "acknowledged_at"
    }
}

struct AchievementStorySummaryDTO: Codable, Equatable {
    let unlockedCount: Int
    let totalCount: Int
    let recentUnlock: AchievementBadgeSnapshotDTO?
    let nextBadge: AchievementBadgeSnapshotDTO?
    let emptyStateKey: String?

    enum CodingKeys: String, CodingKey {
        case unlockedCount = "unlocked_count"
        case totalCount = "total_count"
        case recentUnlock = "recent_unlock"
        case nextBadge = "next_badge"
        case emptyStateKey = "empty_state_key"
    }
}

struct AchievementBadgeSnapshotDTO: Codable, Equatable {
    let badgeId: String
    let chapter: String
    let nameKey: String
    let storyKey: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case badgeId = "badge_id"
        case chapter
        case nameKey = "name_key"
        case storyKey = "story_key"
        case status
    }
}

struct AchievementBadgeGroupDTO: Codable, Equatable {
    let chapter: String
    let titleKey: String?
    let badges: [AchievementBadgeDTO]

    enum CodingKeys: String, CodingKey {
        case chapter
        case titleKey = "title_key"
        case badges
    }
}

struct AchievementTrackDTO: Codable, Equatable {
    let trackId: String
    let titleKey: String
    let storyKey: String
    let metricKey: String?
    let current: Double?
    let nextBadge: AchievementBadgeDTO?
    let badges: [AchievementBadgeDTO]

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case titleKey = "title_key"
        case storyKey = "story_key"
        case metricKey = "metric_key"
        case current
        case nextBadge = "next_badge"
        case badges
    }
}

struct AchievementBadgeDTO: Codable, Equatable {
    let badgeId: String
    let chapter: String
    let nameKey: String
    let storyKey: String
    let status: String
    let progress: AchievementProgressDTO?
    let unlockedAt: String?
    let unlockReasonKey: String?
    let sourceRef: AchievementSourceRefDTO?
    let historicalBackfill: Bool
    let shareable: Bool
    let assetName: String?

    enum CodingKeys: String, CodingKey {
        case badgeId = "badge_id"
        case chapter
        case nameKey = "name_key"
        case storyKey = "story_key"
        case status
        case progress
        case unlockedAt = "unlocked_at"
        case unlockReasonKey = "unlock_reason_key"
        case sourceRef = "source_ref"
        case historicalBackfill = "historical_backfill"
        case shareable
        case assetName = "asset_name"
    }
}

struct AchievementProgressDTO: Codable, Equatable {
    let current: Double?
    let target: Double?
    let unitKey: String?
    let summaryKey: String?
    let summaryParams: [String: AchievementJSONValue]

    enum CodingKeys: String, CodingKey {
        case current
        case target
        case unitKey = "unit_key"
        case summaryKey = "summary_key"
        case summaryParams = "summary_params"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        current = try container.decodeIfPresent(Double.self, forKey: .current)
        target = try container.decodeIfPresent(Double.self, forKey: .target)
        unitKey = try container.decodeIfPresent(String.self, forKey: .unitKey)
        summaryKey = try container.decodeIfPresent(String.self, forKey: .summaryKey)
        summaryParams = try container.decodeIfPresent([String: AchievementJSONValue].self, forKey: .summaryParams) ?? [:]
    }
}

struct AchievementSourceRefDTO: Codable, Equatable {
    let type: String
    let labelKey: String?
    let summaryKey: String?
    let summaryParams: [String: AchievementJSONValue]

    enum CodingKeys: String, CodingKey {
        case type
        case labelKey = "label_key"
        case summaryKey = "summary_key"
        case summaryParams = "summary_params"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        labelKey = try container.decodeIfPresent(String.self, forKey: .labelKey)
        summaryKey = try container.decodeIfPresent(String.self, forKey: .summaryKey)
        summaryParams = try container.decodeIfPresent([String: AchievementJSONValue].self, forKey: .summaryParams) ?? [:]
    }
}

struct AchievementPBOverviewDTO: Codable, Equatable {
    let titleKey: String?
    let updatedAt: String?
    let records: [AchievementPBRecordDTO]

    enum CodingKeys: String, CodingKey {
        case titleKey = "title_key"
        case updatedAt = "updated_at"
        case records
    }
}

struct AchievementPBRecordDTO: Codable, Equatable {
    let distance: String
    let displayDistance: String
    let time: String
    let achievedAt: String?
    let isRecent: Bool

    enum CodingKeys: String, CodingKey {
        case distance
        case distanceKey = "distance_key"
        case displayDistance = "display_distance"
        case time
        case completeTime = "complete_time"
        case pace
        case achievedAt = "achieved_at"
        case workoutDate = "workout_date"
        case isRecent = "is_recent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedDistance = try container.decodeIfPresent(String.self, forKey: .distance)
            ?? container.decodeStringOrNumberIfPresent(forKey: .distanceKey)
            ?? ""
        let decodedTime = try container.decodeIfPresent(String.self, forKey: .time)
        let decodedPace = try container.decodeIfPresent(String.self, forKey: .pace)
        let decodedAchievedAt = try container.decodeIfPresent(String.self, forKey: .achievedAt)
        distance = decodedDistance
        displayDistance = try container.decodeIfPresent(String.self, forKey: .displayDistance)
            ?? Self.displayDistance(from: decodedDistance)
        time = decodedTime
            ?? container.decodeStringOrNumberIfPresent(forKey: .completeTime).map(Self.displayTime(from:))
            ?? decodedPace
            ?? "-"
        achievedAt = decodedAchievedAt
            ?? container.decodeStringOrNumberIfPresent(forKey: .workoutDate)
        isRecent = try container.decodeIfPresent(Bool.self, forKey: .isRecent) ?? false
    }

    private static func displayDistance(from value: String) -> String {
        guard !value.isEmpty else { return "-" }
        if value == "21" || value == "21.0975" { return "Half" }
        if value == "42" || value == "42.195" { return "Full" }
        return value.uppercased().hasSuffix("K") ? value.uppercased() : "\(value)K"
    }

    private static func displayTime(from value: String) -> String {
        guard let seconds = Double(value) else { return value }
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(distance, forKey: .distance)
        try container.encode(displayDistance, forKey: .displayDistance)
        try container.encode(time, forKey: .time)
        try container.encodeIfPresent(achievedAt, forKey: .achievedAt)
        try container.encode(isRecent, forKey: .isRecent)
    }
}

struct AchievementInsightDTO: Codable, Equatable {
    let insightId: String
    let type: String
    let displayKey: String
    let displayParams: [String: AchievementJSONValue]
    let evidence: [String: AchievementJSONValue]
    let confidence: String
    let shareable: Bool

    enum CodingKeys: String, CodingKey {
        case insightId = "insight_id"
        case type
        case displayKey = "display_key"
        case displayParams = "display_params"
        case evidence
        case confidence
        case shareable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        insightId = try container.decode(String.self, forKey: .insightId)
        type = try container.decode(String.self, forKey: .type)
        displayKey = try container.decode(String.self, forKey: .displayKey)
        displayParams = try container.decodeIfPresent([String: AchievementJSONValue].self, forKey: .displayParams) ?? [:]
        evidence = try container.decodeIfPresent([String: AchievementJSONValue].self, forKey: .evidence) ?? [:]
        confidence = try container.decode(String.self, forKey: .confidence)
        shareable = try container.decodeIfPresent(Bool.self, forKey: .shareable) ?? false
    }
}

struct AchievementShareableDTO: Codable, Equatable {
    let materialId: String
    let materialType: String
    let titleKey: String
    let summaryKey: String
    let summaryParams: [String: AchievementJSONValue]
    let sourceRef: AchievementSourceRefDTO?
    let publicFields: [AchievementPublicFieldDTO]
    let defaultSensitiveFieldsEnabled: Bool
    let badgeId: String?
    let chapter: String?

    enum CodingKeys: String, CodingKey {
        case materialId = "material_id"
        case materialType = "material_type"
        case titleKey = "title_key"
        case summaryKey = "summary_key"
        case summaryParams = "summary_params"
        case sourceRef = "source_ref"
        case publicFields = "public_fields"
        case defaultSensitiveFieldsEnabled = "default_sensitive_fields_enabled"
        case badgeId = "badge_id"
        case chapter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        materialId = try container.decode(String.self, forKey: .materialId)
        materialType = try container.decode(String.self, forKey: .materialType)
        titleKey = try container.decode(String.self, forKey: .titleKey)
        summaryKey = try container.decode(String.self, forKey: .summaryKey)
        summaryParams = try container.decodeIfPresent([String: AchievementJSONValue].self, forKey: .summaryParams) ?? [:]
        sourceRef = try container.decodeIfPresent(AchievementSourceRefDTO.self, forKey: .sourceRef)
        publicFields = try container.decodeIfPresent([AchievementPublicFieldDTO].self, forKey: .publicFields) ?? []
        defaultSensitiveFieldsEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultSensitiveFieldsEnabled) ?? false
        badgeId = try container.decodeIfPresent(String.self, forKey: .badgeId)
        chapter = try container.decodeIfPresent(String.self, forKey: .chapter)
    }
}

struct AchievementPublicFieldDTO: Codable, Equatable {
    let key: String
    let labelKey: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case key
        case labelKey = "label_key"
        case value
    }
}

struct AchievementUnlockFeedbackDTO: Codable, Equatable {
    let feedbackId: String
    let badgeId: String?
    let chapter: String?
    let nameKey: String?
    let storyKey: String?
    let type: String?
    let count: Int?

    enum CodingKeys: String, CodingKey {
        case feedbackId = "feedback_id"
        case badgeId = "badge_id"
        case chapter
        case nameKey = "name_key"
        case storyKey = "story_key"
        case type
        case count
    }
}

struct AchievementPrivacyPolicyDTO: Codable, Equatable {
    let defaultExcludedFields: [String]
    let sensitiveFields: [String]
    let publicOnly: Bool
    let defaultSensitiveFieldsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case defaultExcludedFields = "default_excluded_fields"
        case excludedFields = "excluded_fields"
        case sensitiveFields = "sensitive_fields"
        case publicOnly = "public_only"
        case defaultSensitiveFieldsEnabled = "default_sensitive_fields_enabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedExcludedFields = try container.decodeIfPresent([String].self, forKey: .excludedFields)
        let decodedDefaultExcludedFields = try container.decodeIfPresent([String].self, forKey: .defaultExcludedFields)
        let decodedPublicOnly = try container.decodeIfPresent(Bool.self, forKey: .publicOnly)
        defaultExcludedFields = decodedExcludedFields ?? decodedDefaultExcludedFields ?? []
        sensitiveFields = try container.decodeIfPresent([String].self, forKey: .sensitiveFields) ?? []
        defaultSensitiveFieldsEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultSensitiveFieldsEnabled) ?? false
        publicOnly = decodedPublicOnly ?? !defaultSensitiveFieldsEnabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultExcludedFields, forKey: .defaultExcludedFields)
        try container.encode(sensitiveFields, forKey: .sensitiveFields)
        try container.encode(publicOnly, forKey: .publicOnly)
        try container.encode(defaultSensitiveFieldsEnabled, forKey: .defaultSensitiveFieldsEnabled)
    }
}

private extension KeyedDecodingContainer {
    func decodeStringOrNumberIfPresent(forKey key: Key) -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            if doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(doubleValue))
            }
            return String(doubleValue)
        }
        return nil
    }
}
