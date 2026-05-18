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
                        .font(AppFont.systemScaled(size: 50))
                        .foregroundColor(.white)

                    Text(L10n.ShareCard.tutorialTitle.localized)
                        .font(AppFont.systemScaled(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 50)

                Spacer()

                // 功能說明
                VStack(alignment: .leading, spacing: 24) {
                    TutorialItem(
                        icon: "text.bubble",
                        title: L10n.ShareCard.tutorialEditTitleTitle.localized,
                        description: L10n.ShareCard.tutorialEditTitleDescription.localized
                    )

                    TutorialItem(
                        icon: "character.textbox",
                        title: L10n.ShareCard.tutorialAddTextTitle.localized,
                        description: L10n.ShareCard.tutorialAddTextDescription.localized
                    )

                    TutorialItem(
                        icon: "rectangle.3.group",
                        title: L10n.ShareCard.tutorialLayoutSizeTitle.localized,
                        description: L10n.ShareCard.tutorialLayoutSizeDescription.localized
                    )

                    TutorialItem(
                        icon: "photo",
                        title: L10n.ShareCard.tutorialChoosePhotoTitle.localized,
                        description: L10n.ShareCard.tutorialChoosePhotoDescription.localized
                    )
                }
                .padding(.horizontal, 40)

                Spacer()

                // 關閉按鈕
                Button(action: onDismiss) {
                    Text(L10n.ShareCard.tutorialStartEditing.localized)
                        .font(AppFont.systemScaled(size: 18, weight: .semibold))
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
                .font(AppFont.dataSmall())
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.systemScaled(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(AppFont.systemScaled(size: 15))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

#Preview {
    ShareCardTutorialOverlay(onDismiss: {})
}
