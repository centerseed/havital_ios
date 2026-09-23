import Foundation

/// Wire DTO for the data payload of `GET /v2/athlete-state/metrics`.
struct AthleteStateMetricsResponse: Codable {
    let metrics: Metrics

    struct Metrics: Codable {
        let raceProjection: AthleteStateRaceProjectionItem?

        enum CodingKeys: String, CodingKey {
            case raceProjection = "race_projection"
        }
    }
}

/// A materialized `state.race_projection` row.
struct AthleteStateRaceProjectionItem: Codable {
    let itemId: String?
    let asOf: String?
    let estimatorVersion: String?
    let deliveryStatus: String?
    let envelope: AthleteStateMetricEnvelope?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case asOf = "as_of"
        case estimatorVersion = "estimator_version"
        case deliveryStatus = "delivery_status"
        case envelope
    }
}

/// Shared fields used by registered metric envelopes in the metrics and series endpoints.
struct AthleteStateMetricEnvelope: Codable {
    let index: Double?
    let levelIndex: Double?
    var channels: Channels? = nil

    enum CodingKeys: String, CodingKey {
        case index, channels
        case levelIndex = "level_index"
    }

    struct Channels: Codable {
        let acwr: Acwr?
        var fiveK: AthleteStateRaceProjectionChannel? = nil
        var tenK: AthleteStateRaceProjectionChannel? = nil
        var halfMarathon: AthleteStateRaceProjectionChannel? = nil
        var fullMarathon: AthleteStateRaceProjectionChannel? = nil

        enum CodingKeys: String, CodingKey {
            case acwr
            case fiveK = "5k"
            case tenK = "10k"
            case halfMarathon = "half_marathon"
            case fullMarathon = "full_marathon"
        }

        /// `load_index` channel, including backend-provided phase bounds.
        struct Acwr: Codable {
            let raw: Double?
            let available: Bool?
            let side: String?
            let sweetLow: Double?
            let sweetHigh: Double?

            enum CodingKeys: String, CodingKey {
                case raw, available, side
                case sweetLow = "sweet_low"
                case sweetHigh = "sweet_high"
            }
        }
    }
}

struct AthleteStateRaceProjectionChannel: Codable {
    let raw: Raw?

    struct Raw: Codable {
        let projectedSeconds: Int?
        let intervalSeconds: [Int]?
        let status: String?

        enum CodingKeys: String, CodingKey {
            case status
            case projectedSeconds = "projected_seconds"
            case intervalSeconds = "interval_seconds"
        }
    }
}
