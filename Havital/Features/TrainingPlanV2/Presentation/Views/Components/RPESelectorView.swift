import SwiftUI

/// 1-10 RPE 選擇器（pill 色階 + 文案）。可重用於力量完成回報。
struct RPESelectorView: View {
    @Binding var selectedRPE: Int?

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedRPE == nil
                     ? NSLocalizedString("strength.completion.rpe_prompt", comment: "這次整體感覺如何？")
                     : String(format: NSLocalizedString("strength.completion.rpe_selected", comment: "整體體感 %d/10"), selectedRPE!))
                    .font(AppFont.micro())
                    .foregroundColor(.primary)
                Spacer()
                if let rpe = selectedRPE {
                    Text(feedback(rpe))
                        .font(AppFont.micro())
                        .foregroundColor(RecapPalette.rpe(rpe))
                }
            }
            .padding(.horizontal, 2)

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { value in
                    pill(value)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func pill(_ value: Int) -> some View {
        let c = RecapPalette.rpe(value)
        let selected = selectedRPE == value
        let dim = selectedRPE != nil && !selected
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedRPE = value }
        } label: {
            Text("\(value)")
                .font(AppFont.micro().monospacedDigit())
                .foregroundColor(selected ? .white : c)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(selected ? c : c.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .scaleEffect(selected ? 1.08 : 1.0)
                .opacity(dim ? 0.55 : 1.0)
                .shadow(color: selected ? c.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func feedback(_ v: Int) -> String {
        switch v {
        case ...3: return NSLocalizedString("strength.completion.rpe_feedback_low", comment: "輕巧地完成 ✓")
        case 4...5: return NSLocalizedString("strength.completion.rpe_feedback_medium", comment: "節奏掌握得不錯 ✓")
        case 6...7: return NSLocalizedString("strength.completion.rpe_feedback_high", comment: "紮實的一次 ✓")
        default:    return NSLocalizedString("strength.completion.rpe_feedback_max", comment: "硬仗打完了 💪")
        }
    }
}
