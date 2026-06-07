import SwiftUI

struct PaceGuidance: Equatable {
    enum State: Equatable {
        case noTarget
        case waitingForPace
        case tooFast
        case onTarget
        case tooSlow

        var displayText: String {
            switch self {
            case .noTarget:
                return String(localized: "watch.pace.noTarget")
            case .waitingForPace:
                return String(localized: "watch.pace.waitGPS")
            case .tooFast:
                return String(localized: "watch.pace.fast")
            case .onTarget:
                return String(localized: "watch.pace.onTarget")
            case .tooSlow:
                return String(localized: "watch.pace.slow")
            }
        }
    }

    let state: State
    let pointerFraction: Double?
    let deviationSeconds: Int?

    static func make(
        currentPaceSecPerKm: Int?,
        targetLowSecPerKm: Int?,
        targetHighSecPerKm: Int?
    ) -> PaceGuidance {
        guard
            let targetLowSecPerKm,
            let targetHighSecPerKm,
            targetLowSecPerKm > 0,
            targetHighSecPerKm > 0
        else {
            return PaceGuidance(state: .noTarget, pointerFraction: nil, deviationSeconds: nil)
        }

        guard let currentPaceSecPerKm, currentPaceSecPerKm > 0 else {
            return PaceGuidance(state: .waitingForPace, pointerFraction: nil, deviationSeconds: nil)
        }

        let low = min(targetLowSecPerKm, targetHighSecPerKm)
        let high = max(targetLowSecPerKm, targetHighSecPerKm)
        let state: State
        let deviationSeconds: Int?
        if currentPaceSecPerKm < low {
            state = .tooFast
            deviationSeconds = low - currentPaceSecPerKm
        } else if currentPaceSecPerKm > high {
            state = .tooSlow
            deviationSeconds = currentPaceSecPerKm - high
        } else {
            state = .onTarget
            deviationSeconds = nil
        }

        let targetWidth = max(1, high - low)
        let visualPadding = max(20, targetWidth)
        let visualLow = Double(low - visualPadding)
        let visualHigh = Double(high + visualPadding)
        let rawFraction = (Double(currentPaceSecPerKm) - visualLow) / (visualHigh - visualLow)
        return PaceGuidance(
            state: state,
            pointerFraction: min(1, max(0, rawFraction)),
            deviationSeconds: deviationSeconds
        )
    }
}

struct PaceGuidanceView: View {
    let currentPaceSecPerKm: Int?
    let targetLowSecPerKm: Int?
    let targetHighSecPerKm: Int?

    private var guidance: PaceGuidance {
        PaceGuidance.make(
            currentPaceSecPerKm: currentPaceSecPerKm,
            targetLowSecPerKm: targetLowSecPerKm,
            targetHighSecPerKm: targetHighSecPerKm
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                paceMetricColumn(
                    label: String(localized: "watch.pace.current"),
                    value: WatchFormatting.pace(currentPaceSecPerKm),
                    color: currentPaceColor,
                    alignment: .leading
                )

                Spacer(minLength: 4)

                if let targetText {
                    paceMetricColumn(
                        label: String(localized: "watch.pace.target"),
                        value: targetText,
                        color: .green,
                        alignment: .trailing
                    )
                }
            }

            HStack(spacing: 5) {
                Image(systemName: symbolName)
                    .font(.caption)
                    .foregroundStyle(stateColor)
                Text(stateText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(stateColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if guidance.pointerFraction != nil {
                paceBar
                    .frame(height: 12)
            }
        }
    }

    private func paceMetricColumn(
        label: String,
        value: String,
        color: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .layoutPriority(1)
    }

    private var paceBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let pointerX = width * (guidance.pointerFraction ?? 0.5)

            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Capsule().fill(Color.orange.opacity(0.78))
                    Capsule().fill(Color.green.opacity(0.88))
                    Capsule().fill(Color.red.opacity(0.8))
                }

                Capsule()
                    .fill(Color.white)
                    .frame(width: 4, height: 12)
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                    .offset(x: min(max(0, pointerX - 2), max(0, width - 4)))
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var stateText: String {
        if let deviationSeconds = guidance.deviationSeconds {
            return "\(guidance.state.displayText) \(paceDeltaText(deviationSeconds))/km"
        }
        return guidance.state.displayText
    }

    private var targetText: String? {
        guard
            let targetLowSecPerKm,
            let targetHighSecPerKm,
            targetLowSecPerKm > 0,
            targetHighSecPerKm > 0
        else {
            return nil
        }

        let low = min(targetLowSecPerKm, targetHighSecPerKm)
        let high = max(targetLowSecPerKm, targetHighSecPerKm)
        if low == high {
            return WatchFormatting.pace(low)
        }
        return "\(paceWithoutUnit(low))-\(WatchFormatting.pace(high))"
    }

    private func paceWithoutUnit(_ secondsPerKm: Int) -> String {
        String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }

    private func paceDeltaText(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var symbolName: String {
        switch guidance.state {
        case .noTarget:
            return "gauge.medium"
        case .waitingForPace:
            return "gauge"
        case .tooFast:
            return "arrow.down.circle.fill"
        case .onTarget:
            return "checkmark.circle.fill"
        case .tooSlow:
            return "arrow.up.circle.fill"
        }
    }

    private var currentPaceColor: Color {
        switch guidance.state {
        case .noTarget, .waitingForPace:
            return .white
        case .tooFast:
            return .orange
        case .onTarget:
            return .green
        case .tooSlow:
            return .red
        }
    }

    private var stateColor: Color {
        switch guidance.state {
        case .noTarget, .waitingForPace:
            return .cyan
        case .tooFast:
            return .orange
        case .onTarget:
            return .green
        case .tooSlow:
            return .red
        }
    }

    private var accessibilityText: String {
        if let targetText {
            return "\(stateText)，目標配速 \(targetText)，目前配速 \(WatchFormatting.pace(currentPaceSecPerKm))"
        }
        return "\(stateText)，目前配速 \(WatchFormatting.pace(currentPaceSecPerKm))"
    }
}
