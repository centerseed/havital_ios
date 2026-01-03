import SwiftUI

// MARK: - ViewState 視圖包裝器
/// 根據 ViewState 自動顯示對應的視圖
/// 使用方式：
/// ```
/// ViewStateView(state: viewModel.state) { data in
///     ContentView(data: data)
/// }
/// ```
struct ViewStateView<T, Content: View>: View {

    // MARK: - Properties
    let state: ViewState<T>
    let content: (T) -> Content

    var loadingMessage: String?
    var emptyMessage: String = NSLocalizedString("common.no_data", comment: "No data available")
    var emptyIcon: String = "tray"
    var retryAction: (() -> Void)?

    // MARK: - Initialization
    init(
        state: ViewState<T>,
        loadingMessage: String? = nil,
        emptyMessage: String = NSLocalizedString("common.no_data", comment: "No data available"),
        emptyIcon: String = "tray",
        retryAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.state = state
        self.loadingMessage = loadingMessage
        self.emptyMessage = emptyMessage
        self.emptyIcon = emptyIcon
        self.retryAction = retryAction
        self.content = content
    }

    // MARK: - Body
    var body: some View {
        switch state {
        case .loading:
            SharedLoadingView(message: loadingMessage)

        case .loaded(let data):
            content(data)

        case .error(let error):
            SharedErrorView(error: error, retryAction: retryAction)

        case .empty:
            SharedEmptyStateView(
                message: emptyMessage,
                iconName: emptyIcon
            )
        }
    }
}

// MARK: - Modifiers
extension ViewStateView {

    /// 設置載入訊息
    func loadingMessage(_ message: String) -> ViewStateView {
        var view = self
        view.loadingMessage = message
        return view
    }

    /// 設置空狀態訊息
    func emptyMessage(_ message: String) -> ViewStateView {
        var view = self
        view.emptyMessage = message
        return view
    }

    /// 設置空狀態圖示
    func emptyIcon(_ icon: String) -> ViewStateView {
        var view = self
        view.emptyIcon = icon
        return view
    }

    /// 設置重試動作
    func onRetry(_ action: @escaping () -> Void) -> ViewStateView {
        var view = self
        view.retryAction = action
        return view
    }
}

// MARK: - View Extension for ViewState Handling
extension View {

    /// 根據 ViewState 顯示覆蓋層
    @ViewBuilder
    func overlay<T>(for state: ViewState<T>, retryAction: (() -> Void)? = nil) -> some View {
        switch state {
        case .loading:
            self.overlay(
                SharedLoadingView.default
                    .background(Color(.systemBackground).opacity(0.8))
            )

        case .error(let error):
            self.overlay(
                SharedErrorView(error: error, retryAction: retryAction)
                    .background(Color(.systemBackground))
            )

        case .empty:
            self.overlay(
                SharedEmptyStateView(
                    message: NSLocalizedString("common.no_data", comment: "No data available")
                )
                .background(Color(.systemBackground))
            )

        case .loaded:
            self
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ViewStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ViewStateView(state: ViewState<String>.loading) { data in
                Text(data)
            }
            .previewDisplayName("Loading")

            ViewStateView(state: ViewState<String>.loaded("Hello World")) { data in
                Text(data)
                    .font(.largeTitle)
            }
            .previewDisplayName("Loaded")

            ViewStateView(state: ViewState<String>.error(.noConnection)) { data in
                Text(data)
            }
            .onRetry { print("Retry") }
            .previewDisplayName("Error")

            ViewStateView(state: ViewState<String>.empty) { data in
                Text(data)
            }
            .emptyMessage("No items found")
            .previewDisplayName("Empty")
        }
    }
}
#endif
