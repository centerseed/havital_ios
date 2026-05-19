import SwiftUI

// MARK: - WorkoutV2RowView (Redesigned — Paceriz Design System)
//
// Magazine-style card per training-log.jsx spec:
//   Top: type chip (dot + colored bg) + relative time + VDOT pill (orange)
//   Hero: large distance left, pace + time right (mono)
//   Radial gradient corner accent (top-left)
//   Footer: hairline + optional "與課表匹配" chip + source tag
//
// VDOT delta: requires at least two workouts in sorted list; passed in by caller.
// planMatched: derived from workout.dailyPlanSummary presence; no fake data.

struct WorkoutV2RowView: View {
    let workout: WorkoutV2
    let isUploaded: Bool
    let uploadTime: Date?
    /// Optional: pass true/false if caller can determine; nil = omit chip
    var planMatched: Bool? = nil
    /// Optional VDOT delta vs previous workout; positive = up, negative = down, nil = omit arrow
    var vdotDelta: Double? = nil

    @Environment(\.colorScheme) var colorScheme

    // MARK: - Derived values

    private var typeColor: Color {
        guard let trainingType = workout.trainingType else {
            return PacerizColor.green
        }
        return WorkoutV2RowView.colorForTrainingType(trainingType)
    }

    private var typeName: String {
        if let trainingType = workout.trainingType {
            return WorkoutV2RowView.displayNameForTrainingType(trainingType)
        }
        return workout.activityType.workoutTypeDisplayName()
    }

    private var distanceKmString: String {
        guard let meters = workout.distanceMeters, meters > 0 else { return "-" }
        return String(format: "%.1f", meters / 1000.0)
    }

    private var paceString: String {
        guard let secondsPerKm = workout.displayPaceSecondsPerKm else { return "--:--" }
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var durationString: String {
        let hours = Int(workout.duration) / 3600
        let minutes = Int(workout.duration) % 3600 / 60
        let seconds = Int(workout.duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private var whenString: String {
        workout.startDate.formattedRelativeForWorkoutCard
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Subtle radial gradient corner accent
            RadialGradient(
                gradient: Gradient(colors: [typeColor.opacity(0.12), Color.clear]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 80
            )
            .frame(width: 80, height: 80)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Row 1: type chip + time label + VDOT pill
                topRow

                Spacer().frame(height: 14)

                // Row 2: hero distance (left) + pace/time (right)
                heroRow

                Spacer().frame(height: 12)

                // Hairline separator
                Divider()
                    .background(Color.secondary.opacity(0.2))

                Spacer().frame(height: 10)

                // Row 3: footer chips
                footerRow
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .clipped()
    }

    // MARK: - Sub-views

    private var topRow: some View {
        HStack(alignment: .center, spacing: 6) {
            // Type chip: dot + name in colored 12% bg pill
            HStack(spacing: 5) {
                Circle()
                    .fill(typeColor)
                    .frame(width: 6, height: 6)
                Text(typeName)
                    .font(.system(size: 12.5, weight: .heavy))
                    .foregroundColor(typeColor)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(typeColor.opacity(0.12))
            .clipShape(Capsule())

            // Relative time
            Text(whenString)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            // VDOT pill (orange) — only if present
            if let vdot = workout.dynamicVdot {
                vdotPill(vdot: vdot, delta: vdotDelta)
            }
        }
    }

    private func vdotPill(vdot: Double, delta: Double?) -> some View {
        HStack(spacing: 4) {
            Text("VDOT")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(PacerizColor.orangeDeep.opacity(0.7))
                .kerning(0.6)
            Text(String(format: "%.1f", vdot))
                .font(.system(size: 13, weight: .heavy).monospacedDigit())
                .foregroundColor(PacerizColor.orangeDeep)
            if let delta = delta {
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(PacerizColor.orangeDeep)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(PacerizColor.orange.opacity(0.12))
        .cornerRadius(8)
    }

    private var heroRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left: large distance
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(distanceKmString)
                    .font(.system(size: 40, weight: .heavy).monospacedDigit())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize()
                Text("km")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                    .lineLimit(1)
            }

            Spacer()

            // Right: pace + time stacked
            HStack(alignment: .bottom, spacing: 18) {
                metricColumn(
                    value: paceString,
                    unit: "/km",
                    label: NSLocalizedString("common.pace", comment: "配速")
                )
                metricColumn(
                    value: durationString,
                    unit: nil,
                    label: NSLocalizedString("common.time", comment: "時間")
                )
            }
        }
    }

    private func metricColumn(value: String, unit: String?, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 19, weight: .heavy).monospacedDigit())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize()
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .kerning(0.4)
        }
    }

    private var footerRow: some View {
        HStack(spacing: 6) {
            // 與課表匹配 chip — only if planMatched == true
            if planMatched == true {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(PacerizColor.greenDeep)
                    Text("與課表匹配")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(PacerizColor.greenDeep)
                }
            }

            Spacer()

            // Source attribution badge — official brand assets per Garmin/Strava brand guidelines
            sourceAttributionView
        }
    }

    @ViewBuilder
    private var sourceAttributionView: some View {
        let provider = workout.provider.lowercased()
        let isStravaProvider = provider == "strava"
        let isGarminProvider = provider == "garmin"
        let isGarminDevice = (workout.deviceName?.lowercased().contains("garmin") ?? false) ||
                             (workout.deviceName?.lowercased().contains("forerunner") ?? false)

        if isStravaProvider {
            ConditionalStravaAttributionView(dataProvider: workout.provider, displayStyle: .compact)
        } else if isGarminProvider || isGarminDevice {
            GarminAttributionView(deviceModel: nil, displayStyle: .compact)
        } else {
            AppleHealthAttributionView(displayStyle: .compact)
        }
    }

    // MARK: - Static helpers

    static func colorForTrainingType(_ trainingType: String) -> Color {
        let t = trainingType.lowercased()
        if t.contains("easy") || t.contains("recovery") || t.contains("lsd") {
            return PacerizColor.green
        } else if t.contains("tempo") || t.contains("threshold") ||
                  t.contains("interval") || t.contains("fartlek") ||
                  t.contains("progression") || t.contains("combination") {
            return PacerizColor.orange
        } else if t.contains("long") {
            return PacerizColor.blue
        } else if t.contains("race") {
            return Color.red
        } else {
            return PacerizColor.green
        }
    }

    static func displayNameForTrainingType(_ trainingType: String) -> String {
        switch trainingType.lowercased() {
        case "easy_run", "easy": return "輕鬆跑"
        case "recovery_run", "recovery": return "恢復跑"
        case "long_run", "long", "lsd": return "長距離"
        case "tempo": return "節奏跑"
        case "threshold": return "閾值跑"
        case "interval": return "間歇"
        case "fartlek": return "法特雷克"
        case "combination": return "組合跑"
        case "hill_training", "hill": return "坡道訓練"
        case "race": return "比賽"
        case "rest": return "休息"
        default: return trainingType
        }
    }
}

#Preview {
    let workout = WorkoutV2(
        id: "preview-1",
        provider: "garmin",
        activityType: "running",
        startTimeUtc: ISO8601DateFormatter().string(from: Date()),
        endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(1792)),
        durationSeconds: 1792,
        distanceMeters: 4900,
        distanceDisplay: nil,
        distanceUnit: nil,
        deviceName: "Forerunner 965",
        basicMetrics: BasicMetrics(
            avgPaceSPerKm: 366
        ),
        advancedMetrics: AdvancedMetrics(
            dynamicVdot: 37.8,
            trainingType: "easy_run"
        ),
        createdAt: nil,
        schemaVersion: "1.0",
        storagePath: nil,
        dailyPlanSummary: nil,
        aiSummary: nil,
        shareCardContent: nil
    )

    return ScrollView {
        VStack(spacing: 10) {
            WorkoutV2RowView(workout: workout, isUploaded: true, uploadTime: Date(), planMatched: true, vdotDelta: 0.4)
            WorkoutV2RowView(workout: workout, isUploaded: true, uploadTime: Date(), planMatched: false, vdotDelta: nil)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
