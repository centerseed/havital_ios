import SwiftUI

/// 品牌標示 - 顯示 "由 Paceriz 智慧生成 #Paceriz"
struct BrandingFooter: View {
    var textColor: Color = .white.opacity(0.7)

    var body: some View {
        Text("由 Paceriz 智慧生成 #Paceriz")
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(textColor)
    }
}

#Preview {
    ZStack {
        Color.black
        BrandingFooter()
    }
}
