import SwiftUI

struct PaywallTrialTimelineView: View {

    /// 試用總天數（真相源 = offerDisplay.durationDays）。step 標籤由此動態計算，
    /// 後台改 intro offer 天數即自動跟著變，不需更新 app。
    let trialDays: Int

    private struct TimelineStep {
        let label: String
        let desc: String
    }

    /// 扣款前提醒的天數位置（沿用既有「扣款前 2 天提醒」慣例 = 試用天數 - 2）。
    private var reminderDay: Int { max(1, trialDays - 2) }

    private func dayLabel(_ day: Int) -> String {
        String(format: NSLocalizedString("paywall.premium.timeline.day_format", comment: "Day %d"), day)
    }

    private var steps: [TimelineStep] {
        [
            TimelineStep(
                label: NSLocalizedString("paywall.premium.timeline.step1.label", comment: ""),
                desc: NSLocalizedString("paywall.premium.timeline.step1.desc", comment: "")
            ),
            TimelineStep(
                label: dayLabel(reminderDay),
                desc: NSLocalizedString("paywall.premium.timeline.step2.desc", comment: "")
            ),
            TimelineStep(
                label: dayLabel(trialDays),
                desc: NSLocalizedString("paywall.premium.timeline.step3.desc", comment: "")
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                // Step row: dot + text side by side
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .padding(.top, 3)
                        .frame(width: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(steps[index].label)
                            .font(AppFont.systemScaled(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text(steps[index].desc)
                            .font(AppFont.caption2())
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Connector between steps — separate element, fixed height
                if index < steps.count - 1 {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.orange.opacity(0.35))
                            .frame(width: 2, height: 10)
                            .frame(width: 8)
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("Paywall_TrialTimeline")
    }
}
