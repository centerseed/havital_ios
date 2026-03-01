import SwiftUI

struct InfoButtonView: View {
    let iconName: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button {
            print("InfoButtonView: 點擊 \(title)")
            action()
        } label: {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(color)
                    .font(AppFont.body())
                Text(title)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppFont.caption())
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle()) // 防止按鈕事件傳遞
    }
}

#Preview {
    InfoButtonView(
        iconName: "target",
        title: "本週目標",
        color: .blue
    ) {
        print("Tapped")
    }
}
