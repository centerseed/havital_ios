import SwiftUI

// MARK: - PaywallTrialTimelineView
/// Horizontal 3-step trial timeline shown on the paywall when a Yearly card is focused
/// and the user is not currently in an Apple intro offer trial.
/// AC-PAYWALL-07: displayed above Features section when any Yearly card is focused.
struct PaywallTrialTimelineView: View {

    private struct TimelineStep {
        let label: String
        let desc: String
    }

    private var steps: [TimelineStep] {
        [
            TimelineStep(
                label: NSLocalizedString("paywall.premium.timeline.step1.label", comment: ""),
                desc: NSLocalizedString("paywall.premium.timeline.step1.desc", comment: "")
            ),
            TimelineStep(
                label: NSLocalizedString("paywall.premium.timeline.step2.label", comment: ""),
                desc: NSLocalizedString("paywall.premium.timeline.step2.desc", comment: "")
            ),
            TimelineStep(
                label: NSLocalizedString("paywall.premium.timeline.step3.label", comment: ""),
                desc: NSLocalizedString("paywall.premium.timeline.step3.desc", comment: "")
            )
        ]
    }

    var body: some View {
        VStack(spacing: 8) {
            // Connector row: dots with lines between them
            HStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(Color.orange.opacity(0.4))
                            .frame(height: 2)
                    }
                }
            }

            // Labels row
            HStack(alignment: .top, spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(steps[index].label)
                            .font(AppFont.systemScaled(size: 12, weight: .bold))
                            .foregroundColor(.orange)

                        Text(steps[index].desc)
                            .font(AppFont.caption2())
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("Paywall_TrialTimeline")
    }
}
