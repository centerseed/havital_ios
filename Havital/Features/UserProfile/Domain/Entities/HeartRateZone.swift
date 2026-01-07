//
//  HeartRateZone.swift
//  Havital
//
//  Heart Rate Zone Entity
//  Domain Layer - Pure business model for heart rate training zones
//

import Foundation

// MARK: - Heart Rate Zone
/// Heart rate training zone entity
/// Domain Layer - Pure business model calculated using Heart Rate Reserve (HRR) method
struct HeartRateZone: Codable, Equatable, Identifiable {
    let id: Int
    let zone: Int
    let name: String
    let range: ClosedRange<Double>
    let description: String
    let benefit: String

    init(zone: Int, name: String, range: ClosedRange<Double>, description: String, benefit: String = "") {
        self.id = zone
        self.zone = zone
        self.name = name
        self.range = range
        self.description = description
        self.benefit = benefit
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case zone, name, description, benefit
        case lowerBound, upperBound
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.zone = try container.decode(Int.self, forKey: .zone)
        self.id = zone
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.benefit = try container.decodeIfPresent(String.self, forKey: .benefit) ?? ""

        let lower = try container.decode(Double.self, forKey: .lowerBound)
        let upper = try container.decode(Double.self, forKey: .upperBound)
        self.range = lower...upper
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(zone, forKey: .zone)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(benefit, forKey: .benefit)
        try container.encode(range.lowerBound, forKey: .lowerBound)
        try container.encode(range.upperBound, forKey: .upperBound)
    }

    // MARK: - Equatable

    static func == (lhs: HeartRateZone, rhs: HeartRateZone) -> Bool {
        return lhs.zone == rhs.zone &&
               lhs.name == rhs.name &&
               lhs.range == rhs.range &&
               lhs.description == rhs.description &&
               lhs.benefit == rhs.benefit
    }
}

// MARK: - Zone Percentages
/// Heart Rate Reserve (HRR) percentage ranges for each zone
/// Based on Karvonen formula: Target HR = ((MaxHR - RestingHR) × %Intensity) + RestingHR
extension HeartRateZone {
    struct Percentages {
        // Zone 1: Easy / Recovery
        static let easyLow: Double = 0.59
        static let easyHigh: Double = 0.74

        // Zone 2: Aerobic / Marathon pace
        static let aerobicLow: Double = 0.74
        static let aerobicHigh: Double = 0.84

        // Zone 3: Threshold / Tempo
        static let thresholdLow: Double = 0.84
        static let thresholdHigh: Double = 0.88

        // Zone 4: VO2Max / Interval
        static let vo2maxLow: Double = 0.88
        static let vo2maxHigh: Double = 0.95

        // Zone 5: Maximum / Speed
        static let maxLow: Double = 0.95
        static let maxHigh: Double = 1.0
    }
}

// MARK: - Heart Rate Zone Calculator
/// Utility to calculate heart rate zones from max and resting heart rate
extension HeartRateZone {

    /// Calculate all 5 heart rate zones using HRR method
    /// - Parameters:
    ///   - maxHR: Maximum heart rate
    ///   - restingHR: Resting heart rate
    /// - Returns: Array of 5 heart rate zones
    static func calculateZones(maxHR: Int, restingHR: Int) -> [HeartRateZone] {
        let hrr = Double(maxHR - restingHR)

        return [
            HeartRateZone(
                zone: 1,
                name: NSLocalizedString("hr_zone.easy", comment: "Easy"),
                range: calculateRange(hrr: hrr, resting: restingHR, low: Percentages.easyLow, high: Percentages.easyHigh),
                description: NSLocalizedString("hr_zone.easy.description", comment: "Recovery and warmup"),
                benefit: NSLocalizedString("hr_zone.easy.benefit", comment: "Active recovery")
            ),
            HeartRateZone(
                zone: 2,
                name: NSLocalizedString("hr_zone.aerobic", comment: "Aerobic"),
                range: calculateRange(hrr: hrr, resting: restingHR, low: Percentages.aerobicLow, high: Percentages.aerobicHigh),
                description: NSLocalizedString("hr_zone.aerobic.description", comment: "Endurance base"),
                benefit: NSLocalizedString("hr_zone.aerobic.benefit", comment: "Improve aerobic capacity")
            ),
            HeartRateZone(
                zone: 3,
                name: NSLocalizedString("hr_zone.threshold", comment: "Threshold"),
                range: calculateRange(hrr: hrr, resting: restingHR, low: Percentages.thresholdLow, high: Percentages.thresholdHigh),
                description: NSLocalizedString("hr_zone.threshold.description", comment: "Tempo pace"),
                benefit: NSLocalizedString("hr_zone.threshold.benefit", comment: "Increase lactate threshold")
            ),
            HeartRateZone(
                zone: 4,
                name: NSLocalizedString("hr_zone.vo2max", comment: "VO2Max"),
                range: calculateRange(hrr: hrr, resting: restingHR, low: Percentages.vo2maxLow, high: Percentages.vo2maxHigh),
                description: NSLocalizedString("hr_zone.vo2max.description", comment: "Interval training"),
                benefit: NSLocalizedString("hr_zone.vo2max.benefit", comment: "Improve VO2Max")
            ),
            HeartRateZone(
                zone: 5,
                name: NSLocalizedString("hr_zone.max", comment: "Maximum"),
                range: calculateRange(hrr: hrr, resting: restingHR, low: Percentages.maxLow, high: Percentages.maxHigh),
                description: NSLocalizedString("hr_zone.max.description", comment: "Speed work"),
                benefit: NSLocalizedString("hr_zone.max.benefit", comment: "Maximum effort")
            )
        ]
    }

    /// Calculate zone range from HRR percentage
    private static func calculateRange(hrr: Double, resting: Int, low: Double, high: Double) -> ClosedRange<Double> {
        let lowHR = hrr * low + Double(resting)
        let highHR = hrr * high + Double(resting)
        return lowHR...highHR
    }

    /// Get zone for a specific heart rate value
    /// - Parameters:
    ///   - heartRate: Heart rate to check
    ///   - zones: Available zones
    /// - Returns: Zone number (1-5)
    static func zoneFor(heartRate: Double, in zones: [HeartRateZone]) -> Int {
        for zone in zones {
            if zone.range.contains(heartRate) {
                return zone.zone
            }
        }

        // Heart rate above maximum zone
        if heartRate > (zones.last?.range.upperBound ?? 0) {
            return zones.last?.zone ?? 5
        }

        // Heart rate below minimum zone
        return zones.first?.zone ?? 1
    }

    /// Default zones using typical values (maxHR: 180, restingHR: 60)
    static var defaultZones: [HeartRateZone] {
        calculateZones(maxHR: 180, restingHR: 60)
    }
}
