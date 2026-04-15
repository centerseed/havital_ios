//
//  InlineWarningBanner.swift
//  Havital
//
//  通用的 inline warning banner 組件
//  用於 onboarding 流程中顯示需要使用者注意的提示訊息
//

import SwiftUI

/// 通用 inline warning banner
///
/// 顯示帶有警告圖示的內嵌提示訊息，橘色系視覺風格。
///
/// Usage:
/// ```swift
/// InlineWarningBanner(
///     title: "時間較緊迫",
///     message: "距離賽事不足 4 週，系統會自動調整訓練計畫。"
/// )
/// ```
struct InlineWarningBanner: View {

    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.bodySmall())
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        InlineWarningBanner(
            title: "時間較緊迫",
            message: "距離賽事不足 4 週，系統會根據可用時間自動調整訓練計畫強度。"
        )
        InlineWarningBanner(
            title: "注意",
            message: "簡短的提示訊息。"
        )
    }
    .padding()
}
