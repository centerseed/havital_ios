import SwiftUI

/// 校準成果卡（spec §C）：跑完指標跑那週回顧出現。before/after 差異是視覺主角。
/// 底層仍是 adjustment item — toggle 預設關（confirm gate），勾選 → apply-items 寫 registry。
struct BenchmarkCalibrationCard: View {
    let payload: BenchmarkCalibrationPayload
    let index: Int
    @Binding var isSelected: Bool

    private func mmss(_ s: Int) -> String { "\(s / 60):\(String(format: "%02d", s % 60))" }
    private func hms(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", sec))"
                     : "\(m):\(String(format: "%02d", sec))"
    }

    private var headline: String {
        String(format: NSLocalizedString("benchmark.calib.headline", comment: ""),
               payload.workoutDate ?? "",
               String(format: "%g", payload.distanceKm),
               hms(Int(payload.durationS)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: PacerizIcon.benchmark)
                Text(NSLocalizedString("benchmark.calib.chip", comment: "")).font(AppFont.micro())
            }
            .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(PacerizColor.benchmark))

            Text(headline).font(AppFont.subheadline()).fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)

            // before/after 主角區（缺 calibration_preview → 整塊不顯示，卡片降級為成績+VDOT）
            if let pb = payload.paceBeforeSPerKm, let pa = payload.paceAfterSPerKm {
                contrastRow(
                    label: NSLocalizedString("benchmark.calib.pace_label", comment: ""),
                    before: "\(mmss(pb))/km", after: "\(mmss(pa))/km",
                    delta: pb > pa ? String(format: NSLocalizedString("benchmark.calib.pace_delta", comment: ""), "\(pb - pa)") : nil)
            }
            if let rb = payload.raceTimeBeforeS, let ra = payload.raceTimeAfterS {
                contrastRow(
                    label: "\(NSLocalizedString("benchmark.calib.race_label", comment: ""))\(payload.raceDistanceLabel.map { " · \($0)" } ?? "")",
                    before: hms(rb), after: hms(ra), delta: nil)
            }
            if let vb = payload.vdotBefore, let va = payload.vdotAfter {
                Text("\(NSLocalizedString("benchmark.calib.vdot_label", comment: "")) \(String(format: "%.1f", vb)) → \(String(format: "%.1f", va))")
                    .font(AppFont.caption()).foregroundColor(.secondary)
            }

            Text(payload.shouldHedge
                 ? NSLocalizedString("benchmark.calib.hedge", comment: "")
                 : NSLocalizedString("benchmark.calib.lag_notice", comment: ""))
                .font(AppFont.caption()).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            HStack {
                Text(NSLocalizedString("benchmark.calib.toggle", comment: "")).font(AppFont.subheadline()).fontWeight(.medium)
                Spacer()
                Toggle("", isOn: $isSelected).labelsHidden()
                    .accessibilityIdentifier("v2.summary.benchmark_calib_toggle_\(index)")
            }
            Text(NSLocalizedString("benchmark.calib.toggle_hint", comment: ""))
                .font(AppFont.caption()).foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card)
                .stroke(PacerizColor.benchmark.opacity(0.5), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: PacerizRadius.card).fill(PacerizColor.benchmark.opacity(0.06))))
        .accessibilityIdentifier("v2.summary.benchmark_calib_card_\(index)")
    }

    private func contrastRow(label: String, before: String, after: String, delta: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFont.caption()).foregroundColor(.secondary)
            HStack(spacing: 8) {
                Text(before).font(AppFont.subheadline()).foregroundColor(.secondary).strikethrough()
                Image(systemName: "arrow.right").font(AppFont.caption()).foregroundColor(.secondary)
                Text(after).font(AppFont.headline()).fontWeight(.bold).foregroundColor(.primary)
                if let delta {
                    Text(delta).font(AppFont.caption()).foregroundColor(.green)
                }
            }
        }
    }
}

#Preview {
    BenchmarkCalibrationCard(
        payload: BenchmarkCalibrationPayload(
            workoutDate: "2026-06-18", distanceKm: 5.0, durationS: 1320, shouldHedge: false,
            paceBeforeSPerKm: 330, paceAfterSPerKm: 322, raceDistanceLabel: "半馬",
            raceTimeBeforeS: 6750, raceTimeAfterS: 6490, vdotBefore: 42.5, vdotAfter: 44.0),
        index: 0, isSelected: .constant(false)).padding()
}
