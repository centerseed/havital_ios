//
//  UserStatistics.swift
//  Havital
//
//  User Statistics Entity
//  Domain Layer - Business model for user aggregated statistics
//

import Foundation

// MARK: - User Statistics
/// User aggregated statistics entity
/// Domain Layer - Pure business model
struct UserStatistics: Codable {
    let totalWorkouts: Int
    let totalDistance: Double
    let averageWeeklyDistance: Double
    let heartRateZoneCount: Int
    let targetCount: Int
    let lastActivityDate: Date?
    let accountCreatedDate: Date?

    init(userData: User, targets: [Target] = []) {
        // Calculate statistics from user data
        self.totalWorkouts = 0 // Requires workout data source
        self.totalDistance = Double(userData.currentWeekDistance ?? 0)
        self.averageWeeklyDistance = Double(userData.currentWeekDistance ?? 0)
        self.heartRateZoneCount = 5 // Fixed 5 zones
        self.targetCount = targets.count
        self.lastActivityDate = nil // Requires workout records
        self.accountCreatedDate = nil // Requires user profile
    }

    /// Default empty statistics
    static var empty: UserStatistics {
        return UserStatistics(
            totalWorkouts: 0,
            totalDistance: 0,
            averageWeeklyDistance: 0,
            heartRateZoneCount: 5,
            targetCount: 0,
            lastActivityDate: nil,
            accountCreatedDate: nil
        )
    }

    private init(
        totalWorkouts: Int,
        totalDistance: Double,
        averageWeeklyDistance: Double,
        heartRateZoneCount: Int,
        targetCount: Int,
        lastActivityDate: Date?,
        accountCreatedDate: Date?
    ) {
        self.totalWorkouts = totalWorkouts
        self.totalDistance = totalDistance
        self.averageWeeklyDistance = averageWeeklyDistance
        self.heartRateZoneCount = heartRateZoneCount
        self.targetCount = targetCount
        self.lastActivityDate = lastActivityDate
        self.accountCreatedDate = accountCreatedDate
    }
}
