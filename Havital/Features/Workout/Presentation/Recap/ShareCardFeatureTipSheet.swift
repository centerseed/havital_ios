import SwiftUI

// MARK: - ShareCardFeatureTipSheet
//
// 分享畫面首次進入時的功能說明卡（樣式 B：底部說明卡 + 半透明遮罩）。
// 純渲染：所有狀態與持久化由呼叫端（WorkoutRecapView）以 ShareCardTipStorage 處理。
//
//   onDismissTemporarily：點遮罩 / 下滑 → 本次關閉（不寫永久旗標）
//   onDismissPermanently：按「知道了，不再顯示」→ 永久關閉
//
struct ShareCardFeatureTipSheet: View {
    let onDismissTemporarily: () -> Void
    let onDismissPermanently: () -> Void

    private struct Feature: Identifiable {
        var id: String { systemImage }   // 圖示名稱即唯一鍵，免去 per-row UUID 配置
        let systemImage: String
        let textKey: String
    }

    private let features: [Feature] = [
        Feature(systemImage: "pencil", textKey: "workout.share.tip.feature_title"),
        Feature(systemImage: "photo", textKey: "workout.share.tip.feature_photo"),
        Feature(systemImage: "hand.draw", textKey: "workout.share.tip.feature_drag")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismissTemporarily() }

            card
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 抓握把手
            Capsule()
                .fill(Color(UIColor.tertiaryLabel))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text(NSLocalizedString("workout.share.tip.title", comment: "分享卡片功能提示標題"))
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(features) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(RecapPalette.brand)
                            .frame(width: 28, height: 28)
                            .background(RecapPalette.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(NSLocalizedString(feature.textKey, comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer(minLength: 0)
                    }
                }
            }

            Button {
                onDismissPermanently()
            } label: {
                Text(NSLocalizedString("workout.share.tip.dismiss", comment: "知道了，不再顯示"))
                    .font(AppFont.labelStrong())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RecapPalette.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(UIColor.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
}
