import SwiftUI

/// 「下週調整建議」卡片的選取態視覺。
///
/// 設計鐵律：**未選取 ≠ 不可用**。取消勾選只表示「這次不套用」，卡片內容仍然是
/// 有效資訊、Toggle 仍可互動。因此這裡不使用 `.grayscale` / 低 `.opacity`
/// （2026-07 用戶回報：整張卡反灰讓人誤以為功能 unavailable），
/// 改用「邊框粗細 + 底色濃淡」表達選取狀態，文字一律維持全對比可讀。
struct AdjustmentSelectionStyle: ViewModifier {
    let isSelected: Bool
    let fill: Color
    let accent: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
                    .opacity(isSelected ? 1.0 : 0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isSelected ? accent.opacity(0.55) : Color(UIColor.separator),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

extension View {
    func adjustmentSelectionStyle(
        isSelected: Bool,
        fill: Color = Color(UIColor.secondarySystemGroupedBackground),
        accent: Color = .blue,
        cornerRadius: CGFloat = 8
    ) -> some View {
        modifier(AdjustmentSelectionStyle(
            isSelected: isSelected, fill: fill, accent: accent, cornerRadius: cornerRadius))
    }
}

/// 選取狀態的文字標記（會套用 / 這次不套用）——把「灰掉」的語意改用文字講清楚。
struct AdjustmentSelectionLabel: View {
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.dashed")
                .font(AppFont.caption())
            Text(NSLocalizedString(
                isSelected ? "training.adjustment_will_apply" : "training.adjustment_not_applied",
                comment: "會套用 / 這次不套用"))
                .font(AppFont.caption())
        }
        .foregroundColor(isSelected ? .blue : .secondary)
    }
}
