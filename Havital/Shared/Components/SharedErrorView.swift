import SwiftUI

// MARK: - 共用錯誤視圖
/// 統一處理 DomainError 的顯示
/// 注意：命名為 SharedErrorView 避免與現有 ErrorView 衝突，遷移完成後可重命名
struct SharedErrorView: View {

    // MARK: - Properties
    let error: DomainError
    let retryAction: (() -> Void)?
    var title: String?
    var showIcon: Bool = true

    // MARK: - Initialization
    init(
        error: DomainError,
        title: String? = nil,
        showIcon: Bool = true,
        retryAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.title = title
        self.showIcon = showIcon
        self.retryAction = retryAction
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            if showIcon {
                errorIcon
                    .padding(.top, 8)
            }

            VStack(spacing: 12) {
                // 標題
                Text(title ?? errorTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // 詳細說明
                Text(error.userFriendlyMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }

            // 重試按鈕（如果錯誤可重試）
            if let retryAction = retryAction, error.isRetryable {
                Button(action: retryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(NSLocalizedString("common.retry", comment: "Retry"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Subviews

    private var errorIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 48))
            .foregroundColor(iconColor)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch error {
        case .noConnection, .networkFailure, .timeout:
            return "wifi.exclamationmark"
        case .unauthorized:
            return "lock.circle"
        case .forbidden:
            return "hand.raised.circle"
        case .notFound:
            return "magnifyingglass"
        case .serverError:
            return "exclamationmark.icloud"
        case .validationFailure:
            return "exclamationmark.triangle"
        case .dataCorruption:
            return "doc.badge.ellipsis"
        default:
            return "exclamationmark.circle"
        }
    }

    private var iconColor: Color {
        switch error {
        case .noConnection, .networkFailure, .timeout:
            return .orange
        case .unauthorized, .forbidden:
            return .red
        case .serverError:
            return .red
        default:
            return .orange
        }
    }

    private var errorTitle: String {
        switch error {
        case .noConnection, .networkFailure, .timeout:
            return NSLocalizedString("error.title.network", comment: "Network Error")
        case .unauthorized:
            return NSLocalizedString("error.title.unauthorized", comment: "Session Expired")
        case .forbidden:
            return NSLocalizedString("error.title.forbidden", comment: "Access Denied")
        case .serverError:
            return NSLocalizedString("error.title.server", comment: "Server Error")
        case .notFound:
            return NSLocalizedString("error.title.not_found", comment: "Not Found")
        default:
            return NSLocalizedString("error.title.unknown", comment: "Error")
        }
    }
}

// MARK: - Convenience Initializers
extension SharedErrorView {

    /// 從任意 Error 創建
    init(
        error: Error,
        title: String? = nil,
        showIcon: Bool = true,
        retryAction: (() -> Void)? = nil
    ) {
        self.init(
            error: error.toDomainError(),
            title: title,
            showIcon: showIcon,
            retryAction: retryAction
        )
    }
}

// MARK: - Preview
#if DEBUG
struct SharedErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SharedErrorView(error: .noConnection) {
                print("Retry tapped")
            }
            .previewDisplayName("No Connection")

            SharedErrorView(error: .unauthorized)
                .previewDisplayName("Unauthorized")

            SharedErrorView(error: .serverError(500, "Internal Server Error")) {
                print("Retry tapped")
            }
            .previewDisplayName("Server Error")
        }
    }
}
#endif
