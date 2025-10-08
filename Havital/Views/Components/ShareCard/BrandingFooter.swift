import SwiftUI

/// 品牌標示 - 顯示 "Paceriz AI 訓練報告"
struct BrandingFooter: View {
    var textColor: Color = .white.opacity(0.7)

    var body: some View {
        Text(NSLocalizedString("share_card.branding", comment: "Branding text for share card"))
            .font(.system(size: 36, weight: .regular))
            .foregroundColor(textColor)
    }
}

#Preview {
    ZStack {
        Color.black
        BrandingFooter()
    }
}
