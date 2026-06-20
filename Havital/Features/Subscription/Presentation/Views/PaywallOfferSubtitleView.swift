import SwiftUI

/// 卡片副標：依 package 的實際 offerDisplay 渲染（試用 / 折扣 / 無）。
/// onDark = true 用於年費卡（深色漸層底），false 用於月費卡（淺底）。
struct PaywallOfferSubtitleView: View {
    let display: PaywallCardOfferDisplay
    let onDark: Bool

    var body: some View {
        switch display {
        case .freeTrial(let days):
            Text(String(format: NSLocalizedString("paywall.premium.plan.trial_format", comment: ""), String(days)))
                .font(AppFont.caption())
                .foregroundColor(onDark ? .white.opacity(0.85) : .secondary)
        case .discount(let struck, let offerPrice, _): // third value (durationDays) not shown in subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(struck)
                    .font(AppFont.caption())
                    .strikethrough(true, color: onDark ? .white.opacity(0.72) : .secondary)
                    .foregroundColor(onDark ? .white.opacity(0.72) : .secondary)
                HStack(spacing: 6) {
                    Text(offerPrice)
                        .font(AppFont.systemScaled(size: 15, weight: .bold))
                        .foregroundColor(onDark ? .white : .primary)
                    Text(NSLocalizedString("paywall.offer.limited_time_badge", comment: ""))
                        .font(AppFont.caption2()).fontWeight(.bold).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange).clipShape(Capsule())
                }
            }
        case .none:
            Text(NSLocalizedString("paywall.premium.plan.no_trial_format", comment: ""))
                .font(AppFont.caption())
                .foregroundColor(onDark ? .white.opacity(0.85) : .secondary)
        }
    }
}
