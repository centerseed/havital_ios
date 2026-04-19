import Foundation

/// Pure calculation for weekly workout metrics — no I/O, no state, no side effects.
/// Input workouts + weekInfo → Output grouped workouts + aggregated metrics.
enum WeekMetricsCalculator {

    /// Single struct returning this week's metrics.
    struct WeekMetrics {
        let totalDistanceKm: Double
        let intensity: TrainingIntensityManager.IntensityMinutes
    }

    private static let activityTypes: Set<String> = ["running", "walking", "hiking", "cross_training"]

    /// Groups workouts by day index (1-7) for the given week.
    /// Only retains running/walking/hiking/cross_training within the week range.
    static func groupWorkoutsByDay(
        _ workouts: [WorkoutV2],
        weekInfo: WeekDateInfo,
        calendar: Calendar = .current
    ) -> [Int: [WorkoutV2]] {
        var grouped: [Int: [WorkoutV2]] = [:]

        for workout in workouts {
            guard activityTypes.contains(workout.activityType) else { continue }
            guard workout.startDate >= weekInfo.startDate && workout.startDate <= weekInfo.endDate else { continue }

            var dayIndex: Int?
            for (index, dateInWeek) in weekInfo.daysMap {
                if calendar.isDate(workout.startDate, inSameDayAs: dateInWeek) {
                    dayIndex = index
                    break
                }
            }

            guard let dayIndex else { continue }

            if grouped[dayIndex] == nil {
                grouped[dayIndex] = []
            }
            grouped[dayIndex]?.append(workout)
        }

        // Sort each day's workouts newest first.
        for (dayIndex, dayWorkouts) in grouped {
            grouped[dayIndex] = dayWorkouts.sorted { $0.endDate > $1.endDate }
        }

        return grouped
    }

    /// Aggregates distance and intensity across all workouts that fall within the week.
    static func metrics(
        for workouts: [WorkoutV2],
        weekInfo: WeekDateInfo
    ) -> WeekMetrics {
        let weekWorkouts = workouts.filter {
            $0.startDate >= weekInfo.startDate && $0.startDate <= weekInfo.endDate
        }

        let totalDistanceMeters = weekWorkouts.reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }
        let totalDistanceKm = totalDistanceMeters / 1000.0

        var totalLow: Double = 0.0
        var totalMedium: Double = 0.0
        var totalHigh: Double = 0.0

        for workout in weekWorkouts {
            if let intensityMinutes = workout.advancedMetrics?.intensityMinutes {
                totalLow += intensityMinutes.low ?? 0.0
                totalMedium += intensityMinutes.medium ?? 0.0
                totalHigh += intensityMinutes.high ?? 0.0
            }
        }

        let intensity = TrainingIntensityManager.IntensityMinutes(
            low: totalLow,
            medium: totalMedium,
            high: totalHigh
        )

        return WeekMetrics(totalDistanceKm: totalDistanceKm, intensity: intensity)
    }
}
