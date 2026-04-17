import SwiftUI

// MARK: - 共用載入視圖
/// 顯示載入狀態
struct SharedLoadingView: View {

    // MARK: - Properties
    var message: String?
    var showProgressView: Bool = true

    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            if showProgressView {
                ProgressView()
                    .scaleEffect(1.2)
            }

            if let message = message {
                Text(message)
                    .font(AppFont.body())
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Convenience Initializers
extension SharedLoadingView {

    /// 預設載入視圖
    static var `default`: SharedLoadingView {
        SharedLoadingView(message: NSLocalizedString("common.loading", comment: "Loading..."))
    }

    /// 無文字載入視圖
    static var minimal: SharedLoadingView {
        SharedLoadingView()
    }
}

// MARK: - Preview
#if DEBUG
struct SharedLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SharedLoadingView.default
                .previewDisplayName("Default")

            SharedLoadingView.minimal
                .previewDisplayName("Minimal")

            SharedLoadingView(message: "Fetching training plan...")
                .previewDisplayName("Custom Message")
        }
    }
}
#endif
