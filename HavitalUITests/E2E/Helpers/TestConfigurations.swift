//
//  TestConfigurations.swift
//  HavitalUITests
//
//  E2E test parameter configurations
//

import Foundation

struct OnboardingTestConfig {
    let name: String
    let goalType: String           // "race_run", "beginner", "maintenance"
    let methodology: String?       // "paceriz", "hansons", "polarized", "norwegian"
    let raceDistanceKm: Int?       // 5, 10, 21, 42
    let targetHours: Int?
    let targetMinutes: Int?
    let trainingWeeks: Int?        // Non-race targets
    let trainingDays: [Int]        // 1-7 (Mon-Sun)
    let longRunDay: Int            // 1-7

    /// Distance key used in picker (matches availableDistances keys)
    var distancePickerKey: String? {
        guard let km = raceDistanceKm else { return nil }
        switch km {
        case 5: return "5"
        case 10: return "10"
        case 21: return "21.0975"
        case 42: return "42.195"
        default: return "\(km)"
        }
    }
}

// MARK: - Test Matrix (12 cases)

enum TestMatrix {
    // Case 1: race_run + paceriz + 42k marathon 4h
    static let raceRunPacerizMarathon = OnboardingTestConfig(
        name: "RaceRun_Paceriz_Marathon_4h",
        goalType: "race_run",
        methodology: "paceriz",
        raceDistanceKm: 42,
        targetHours: 4,
        targetMinutes: 0,
        trainingWeeks: nil,
        trainingDays: [1, 3, 5, 6],
        longRunDay: 6
    )

    // Case 2: race_run + hansons + 21k half 1h50m
    static let raceRunHansonsHalf = OnboardingTestConfig(
        name: "RaceRun_Hansons_Half_1h50m",
        goalType: "race_run",
        methodology: "hansons",
        raceDistanceKm: 21,
        targetHours: 1,
        targetMinutes: 50,
        trainingWeeks: nil,
        trainingDays: [1, 2, 4, 5, 6],
        longRunDay: 6
    )

    // Case 3: race_run + polarized + 10k 50min
    static let raceRunPolarized10k = OnboardingTestConfig(
        name: "RaceRun_Polarized_10k_50m",
        goalType: "race_run",
        methodology: "polarized",
        raceDistanceKm: 10,
        targetHours: 0,
        targetMinutes: 50,
        trainingWeeks: nil,
        trainingDays: [2, 4, 7],
        longRunDay: 7
    )

    // Case 4: race_run + norwegian + 5k 25min
    static let raceRunNorwegian5k = OnboardingTestConfig(
        name: "RaceRun_Norwegian_5k_25m",
        goalType: "race_run",
        methodology: "norwegian",
        raceDistanceKm: 5,
        targetHours: 0,
        targetMinutes: 25,
        trainingWeeks: nil,
        trainingDays: [1, 3, 5, 6, 7],
        longRunDay: 7
    )

    // Case 5: beginner + default
    static let beginnerDefault = OnboardingTestConfig(
        name: "Beginner_Default",
        goalType: "beginner",
        methodology: nil,
        raceDistanceKm: nil,
        targetHours: nil,
        targetMinutes: nil,
        trainingWeeks: nil,  // Uses default recommended
        trainingDays: [2, 4, 6],
        longRunDay: 6
    )

    // Case 6: beginner + alternate + 12w
    static let beginnerAlternate12w = OnboardingTestConfig(
        name: "Beginner_Alternate_12w",
        goalType: "beginner",
        methodology: nil,  // Beginner may have single methodology
        raceDistanceKm: nil,
        targetHours: nil,
        targetMinutes: nil,
        trainingWeeks: 12,
        trainingDays: [1, 3, 5],
        longRunDay: 5
    )

    // Case 7: maintenance + paceriz + 12w
    static let maintenancePaceriz12w = OnboardingTestConfig(
        name: "Maintenance_Paceriz_12w",
        goalType: "maintenance",
        methodology: "paceriz",
        raceDistanceKm: nil,
        targetHours: nil,
        targetMinutes: nil,
        trainingWeeks: 12,
        trainingDays: [1, 2, 4, 5, 6],
        longRunDay: 6
    )

    // Case 8: maintenance + alternate + 16w
    static let maintenanceAlternate16w = OnboardingTestConfig(
        name: "Maintenance_Alternate_16w",
        goalType: "maintenance",
        methodology: nil,  // Use default
        raceDistanceKm: nil,
        targetHours: nil,
        targetMinutes: nil,
        trainingWeeks: 16,
        trainingDays: [3, 6, 7],
        longRunDay: 7
    )

    // Case 9: race_run + paceriz + 42k 3h30m + 7 days
    static let raceRunPacerizMarathon7days = OnboardingTestConfig(
        name: "RaceRun_Paceriz_Marathon_3h30_7days",
        goalType: "race_run",
        methodology: "paceriz",
        raceDistanceKm: 42,
        targetHours: 3,
        targetMinutes: 30,
        trainingWeeks: nil,
        trainingDays: [1, 2, 3, 4, 5, 6, 7],
        longRunDay: 6
    )

    // Case 10: maintenance + default + 4w (min)
    static let maintenanceDefault4w = OnboardingTestConfig(
        name: "Maintenance_Default_4w_Min",
        goalType: "maintenance",
        methodology: nil,
        raceDistanceKm: nil,
        targetHours: nil,
        targetMinutes: nil,
        trainingWeeks: 4,
        trainingDays: [1, 6],
        longRunDay: 6
    )

    // Case 11: race_run + paceriz + 21k 2h15m + 2 days
    static let raceRunPacerizHalf2days = OnboardingTestConfig(
        name: "RaceRun_Paceriz_Half_2h15_2days",
        goalType: "race_run",
        methodology: "paceriz",
        raceDistanceKm: 21,
        targetHours: 2,
        targetMinutes: 15,
        trainingWeeks: nil,
        trainingDays: [2, 4],
        longRunDay: 4
    )

    // Case 12: beginner + default + 24w (max) + 7 days
    static let beginnerDefault24w = OnboardingTestConfig(
        name: "Beginner_Default_24w_Max_7days",
        goalType: "beginner",
        methodology: nil,
        raceDistanceKm: nil,
        targetHours: nil,
        targetMinutes: nil,
        trainingWeeks: 24,
        trainingDays: [1, 2, 3, 4, 5, 6, 7],
        longRunDay: 7
    )

    static let allConfigs: [OnboardingTestConfig] = [
        raceRunPacerizMarathon,
        raceRunHansonsHalf,
        raceRunPolarized10k,
        raceRunNorwegian5k,
        beginnerDefault,
        beginnerAlternate12w,
        maintenancePaceriz12w,
        maintenanceAlternate16w,
        raceRunPacerizMarathon7days,
        maintenanceDefault4w,
        raceRunPacerizHalf2days,
        beginnerDefault24w,
    ]
}
