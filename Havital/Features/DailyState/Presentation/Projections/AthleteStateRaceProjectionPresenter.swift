import Foundation

/// Presentation helpers shared by surfaces that show an athlete-state race projection.
enum AthleteStateRaceProjectionPresenter {

    private struct NamedDistance {
        let channelKey: String
        let kilometers: Double
        let toleranceKm: Double
    }

    /// Client copy of backend `distance_type_for_km` in `core/policies/race_projection.py`.
    private static let namedDistances = [
        NamedDistance(channelKey: "5k", kilometers: 5.0, toleranceKm: 0.15),
        NamedDistance(channelKey: "10k", kilometers: 10.0, toleranceKm: 0.15),
        NamedDistance(channelKey: "half_marathon", kilometers: 21.0975, toleranceKm: 0.20),
        NamedDistance(channelKey: "full_marathon", kilometers: 42.195, toleranceKm: 0.30)
    ]

    static func channelKey(distanceKm: Double?) -> String? {
        guard let distanceKm else { return nil }
        return namedDistances.first {
            abs(distanceKm - $0.kilometers) <= $0.toleranceKm
        }?.channelKey
    }

    static func projectedSeconds(
        deliveryStatus: String?,
        envelope: AthleteStateMetricEnvelope?,
        distanceKm: Double?
    ) -> Int? {
        guard let key = channelKey(distanceKm: distanceKm) else { return nil }
        return projectedSeconds(deliveryStatus: deliveryStatus, envelope: envelope, channelKey: key)
    }

    static func projectedSeconds(
        deliveryStatus: String?,
        envelope: AthleteStateMetricEnvelope?,
        channelKey: String
    ) -> Int? {
        guard deliveryStatus == "active",
              let channels = envelope?.channels,
              let raw = channel(channelKey, in: channels)?.raw,
              raw.status == "computed"
        else { return nil }
        return raw.projectedSeconds
    }

    static func formattedTime(seconds: Int) -> String {
        String(format: "%d:%02d:%02d", seconds / 3_600, (seconds % 3_600) / 60, seconds % 60)
    }

    static func formattedTime(
        deliveryStatus: String?,
        envelope: AthleteStateMetricEnvelope?,
        distanceKm: Double?
    ) -> String? {
        guard let seconds = projectedSeconds(
            deliveryStatus: deliveryStatus,
            envelope: envelope,
            distanceKm: distanceKm
        ) else { return nil }
        return formattedTime(seconds: seconds)
    }

    static func formattedTime(item: AthleteStateRaceProjectionItem?, distanceKm: Double?) -> String? {
        formattedTime(
            deliveryStatus: item?.deliveryStatus,
            envelope: item?.envelope,
            distanceKm: distanceKm
        )
    }

    private static func channel(
        _ key: String,
        in channels: AthleteStateMetricEnvelope.Channels
    ) -> AthleteStateRaceProjectionChannel? {
        switch key {
        case "5k": return channels.fiveK
        case "10k": return channels.tenK
        case "half_marathon": return channels.halfMarathon
        case "full_marathon": return channels.fullMarathon
        default: return nil
        }
    }
}
