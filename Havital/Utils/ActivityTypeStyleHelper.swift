//
//  ActivityTypeStyleHelper.swift
//  Havital
//
//  Created by Clean Architecture Refactoring
//

import SwiftUI

/// Activity Type Style Helper
///
/// Core Layer utility for providing UI styling (colors and icons) for workout activity types.
/// This helper centralizes styling logic that was previously duplicated across views.
///
/// **Architecture Context**:
/// - Layer: Core (Utilities)
/// - Dependencies: SwiftUI (for Color)
/// - Used by: View Layer (TrainingCalendarView, etc.)
///
/// **Domain Coverage**:
/// - Handles actual workout activity types (running, cycling, swimming, etc.)
/// - Complements `TrainingItemStyle` which handles training plan item types (warmup, cooldown, intervals)
///
/// **Usage Example**:
/// ```swift
/// let color = ActivityTypeStyleHelper.color(for: "running") // .mint
/// let icon = ActivityTypeStyleHelper.icon(for: "cycling")   // "figure.outdoor.cycle"
/// ```
struct ActivityTypeStyleHelper {

    // MARK: - Icon Mapping

    /// Get SF Symbol icon name for a given activity type
    /// - Parameter activityType: Activity type string (case-insensitive)
    /// - Returns: SF Symbol name for the activity
    static func icon(for activityType: String) -> String {
        switch activityType.lowercased() {
        case "running", "run":
            return "figure.run"
        case "cycling", "cycle", "bike":
            return "figure.outdoor.cycle"
        case "strength", "weight", "gym", "strength_training":
            return "dumbbell.fill"
        case "swimming", "swim":
            return "figure.pool.swim"
        case "yoga":
            return "figure.mind.and.body"
        case "hiking", "hike":
            return "figure.hiking"
        case "walking", "walk":
            return "figure.walk"
        case "rowing", "row":
            return "figure.rower"
        case "elliptical":
            return "figure.elliptical"
        case "rest", "rest_day":
            return "bed.double.fill"
        default:
            return "figure.mixed.cardio"
        }
    }

    // MARK: - Color Mapping

    /// Get SwiftUI color for a given activity type
    /// - Parameter activityType: Activity type string (case-insensitive)
    /// - Returns: SwiftUI Color for the activity
    static func color(for activityType: String) -> Color {
        switch activityType.lowercased() {
        case "running", "run":
            return .mint
        case "cycling", "cycle", "bike":
            return .blue
        case "strength", "weight", "gym", "strength_training":
            return .purple
        case "swimming", "swim":
            return .cyan
        case "yoga":
            return .pink
        case "hiking", "hike":
            return .orange
        case "walking", "walk":
            return .green
        case "rowing", "row":
            return .teal
        case "elliptical":
            return .indigo
        case "rest", "rest_day":
            return .gray
        default:
            return .gray
        }
    }
}
