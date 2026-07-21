import SwiftUI

/// 執行確認卡（spec §B）：週回顧「下週調整建議」內的 indigo hero 小卡。
/// 底層仍是 adjustment item — toggle 綁同一 binding，取消 → index 不送 → milestone declined。
struct BenchmarkExecuteCard: View {
    let payload: BenchmarkExecutePayload
    let index: Int
    var showsToggle: Bool = true
    @Binding var isSelected: Bool

    private var weekdayText: String {
        if let wd = payload.scheduledWeekday, (1...7).contains(wd) {
            let label = NSLocalizedString("benchmark.weekday.\(wd)", comment: "")
            return String(format: NSLocalizedString("benchmark.execute.schedule_weekday", comment: ""), label)
        }
        return NSLocalizedString("benchmark.execute.schedule_generic", comment: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: PacerizIcon.benchmark)
                Text(NSLocalizedString("benchmark.execute.chip", comment: ""))
                    .font(AppFont.micro()).tracking(0.04)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(PacerizColor.benchmark))

            Text(String(format: NSLocalizedString("benchmark.execute.title", comment: ""),
                        String(format: "%g", payload.distanceKm)))
                .font(AppFont.title3()).fontWeight(.bold).foregroundColor(.primary)

            Text(NSLocalizedString("benchmark.execute.coach", comment: ""))
                .font(AppFont.subheadline()).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(weekdayText)
                .font(AppFont.caption()).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if showsToggle {
                Divider()

                HStack {
                    Text(NSLocalizedString("benchmark.execute.toggle", comment: ""))
                        .font(AppFont.subheadline()).fontWeight(.medium)
                    Spacer()
                    Toggle("", isOn: $isSelected).labelsHidden()
                        .accessibilityIdentifier("v2.summary.benchmark_execute_toggle_\(index)")
                }
                Text(isSelected
                     ? NSLocalizedString("benchmark.execute.toggle_hint", comment: "")
                     : NSLocalizedString("benchmark.execute.skipped", comment: ""))
                    .font(AppFont.caption()).foregroundColor(.secondary)
            }
        }
        .padding(16)
        .adjustmentSelectionStyle(
            isSelected: isSelected,
            fill: PacerizColor.benchmark.opacity(0.06),
            accent: PacerizColor.benchmark,
            cornerRadius: PacerizRadius.card
        )
        .accessibilityIdentifier("v2.summary.benchmark_execute_card_\(index)")
    }
}

#Preview {
    VStack {
        BenchmarkExecuteCard(
            payload: BenchmarkExecutePayload(distanceKm: 5.0, scheduledWeekday: 6),
            index: 0, isSelected: .constant(true))
        BenchmarkExecuteCard(
            payload: BenchmarkExecutePayload(distanceKm: 3.0, scheduledWeekday: nil),
            index: 1, isSelected: .constant(false))
    }.padding()
}
