import SwiftUI

struct PaceGuidance: Equatable {
    enum State: Equatable {
        case noTarget
        case waitingForPace
        case tooFast
        case onTarget
        case tooSlow
    }

    let state: State
    let pointerFraction: Double?

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
            return PaceGuidance(state: .noTarget, pointerFraction: nil)
        }

        guard let currentPaceSecPerKm, currentPaceSecPerKm > 0 else {
            return PaceGuidance(state: .waitingForPace, pointerFraction: nil)
        }

        let low = min(targetLowSecPerKm, targetHighSecPerKm)
        let high = max(targetLowSecPerKm, targetHighSecPerKm)
        let state: State
        if currentPaceSecPerKm < low {
            state = .tooFast
        } else if currentPaceSecPerKm > high {
            state = .tooSlow
        } else {
            state = .onTarget
        }

        let targetWidth = max(1, high - low)
        let visualPadding = max(20, targetWidth)
        let visualLow = Double(low - visualPadding)
        let visualHigh = Double(high + visualPadding)
        let rawFraction = (Double(currentPaceSecPerKm) - visualLow) / (visualHigh - visualLow)
        return PaceGuidance(
            state: state,
            pointerFraction: min(1, max(0, rawFraction))
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
        VStack(alignment: .leading, spacing: 4) {
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
                Spacer(minLength: 4)
                Text(WatchFormatting.pace(currentPaceSecPerKm))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if guidance.state != .noTarget {
                paceBar
                    .frame(height: 14)
            }
        }
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
                    .frame(width: 4, height: 14)
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                    .offset(x: min(max(0, pointerX - 2), max(0, width - 4)))
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var stateText: String {
        switch guidance.state {
        case .noTarget:
            return "配速"
        case .waitingForPace:
            return "等速度"
        case .tooFast:
            return "放慢"
        case .onTarget:
            return "穩住"
        case .tooSlow:
            return "加速"
        }
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
        "\(stateText)，目前配速 \(WatchFormatting.pace(currentPaceSecPerKm))"
    }
}
