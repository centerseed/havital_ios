import SwiftUI

/// 分享卡編輯引導畫面
struct ShareCardTutorialOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // 半透明黑色背景
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 30) {
                // 標題
                VStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)

                    Text("分享卡編輯指南")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 50)

                Spacer()

                // 功能說明
                VStack(alignment: .leading, spacing: 24) {
                    TutorialItem(
                        icon: "text.bubble",
                        title: "點擊標題或AI簡評",
                        description: "可以編輯或刪除文字內容"
                    )

                    TutorialItem(
                        icon: "character.textbox",
                        title: "新增文字",
                        description: "添加自定義文字並自由移動位置"
                    )

                    TutorialItem(
                        icon: "rectangle.3.group",
                        title: "版型與尺寸",
                        description: "切換不同的佈局樣式和圖片尺寸"
                    )

                    TutorialItem(
                        icon: "photo",
                        title: "選擇照片",
                        description: "更換背景照片並調整位置"
                    )
                }
                .padding(.horizontal, 40)

                Spacer()

                // 關閉按鈕
                Button(action: onDismiss) {
                    Text("開始編輯")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

/// 引導項目元件
struct TutorialItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

#Preview {
    ShareCardTutorialOverlay(onDismiss: {})
}
