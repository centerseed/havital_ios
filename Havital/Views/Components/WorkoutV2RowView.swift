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
    @ObservedObject private var unitManager = UnitManager.shared

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

    private var distanceValueString: String {
        guard let meters = workout.distanceMeters, meters > 0 else { return "-" }
        let km = meters / 1000.0
        let converted = unitManager.convertedDistance(km)
        return String(format: "%.1f", converted)
    }

    private var distanceUnitString: String {
        unitManager.currentUnitSystem.distanceSuffix
    }

    /// Pace value without suffix (e.g. "5:58"). Unit is rendered separately
    /// via `paceUnitString` so font weight/color can differ.
    private var paceValueString: String {
        guard let secondsPerKm = workout.displayPaceSecondsPerKm else { return "--:--" }
        let converted: Double
        switch unitManager.currentUnitSystem {
        case .metric: converted = secondsPerKm
        case .imperial: converted = secondsPerKm * 1.60934
        }
        let rounded = Int(converted.rounded())
        return String(format: "%d:%02d", rounded / 60, rounded % 60)
    }

    private var paceUnitString: String {
        unitManager.currentUnitSystem.paceSuffix  // "/km" or "/mi"
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
        HStack(spacing: 0) {
            // Left accent bar — type color (Android parity)
            Rectangle()
                .fill(typeColor)
                .frame(width: 5)

            ZStack(alignment: .topLeading) {
                // Subtle radial gradient corner accent
                RadialGradient(
                    gradient: Gradient(colors: [typeColor.opacity(0.10), Color.clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 80
                )
                .frame(width: 80, height: 80)
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    // Row 1: type chip + time label + VDOT pill
                    topRow

                    Spacer().frame(height: 10)

                    // Row 2: hero distance (left) + pace/time (right)
                    heroRow

                    Spacer().frame(height: 8)

                    // Row 3: footer chips (与课表匹配 + source attribution)
                    footerRow
                }
                .padding(.top, 12)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
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
                    .font(AppFont.chip())
                    .foregroundColor(typeColor)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(typeColor.opacity(0.12))
            .clipShape(Capsule())

            // Relative time
            Text(whenString)
                .font(AppFont.micro())
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
                .font(AppFont.micro())
                .foregroundColor(PacerizColor.orangeDeep.opacity(0.7))
                .kerning(0.6)
            Text(String(format: "%.1f", vdot))
                .font(AppFont.chip().monospacedDigit())
                .foregroundColor(PacerizColor.orangeDeep)
            if let delta = delta {
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(AppFont.micro())
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
                Text(distanceValueString)
                    .font(AppFont.numberLarge().monospacedDigit())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize()
                Text(distanceUnitString)
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .lineLimit(1)
            }

            Spacer()

            // Right: pace + time stacked
            HStack(alignment: .bottom, spacing: 16) {
                metricColumn(
                    value: paceValueString,
                    unit: paceUnitString,
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
                    .font(AppFont.numberMedium().monospacedDigit())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize()
                if let unit = unit {
                    Text(unit)
                        .font(AppFont.chip())
                        .foregroundColor(.secondary)
                }
            }
            Text(label)
                .font(AppFont.micro())
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
                        .font(AppFont.chip())
                        .foregroundColor(PacerizColor.greenDeep)
                    Text("與課表匹配")
                        .font(AppFont.micro())
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

        Group {
            if isStravaProvider {
                ConditionalStravaAttributionView(dataProvider: workout.provider, displayStyle: .compact)
            } else if isGarminProvider || isGarminDevice {
                GarminAttributionView(deviceModel: nil, displayStyle: .compact)
            } else {
                AppleHealthAttributionView(displayStyle: .compact)
            }
        }
        .scaleEffect(0.82, anchor: .trailing)
        .padding(.trailing, -4)  // compensate for shrink-induced gap
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
