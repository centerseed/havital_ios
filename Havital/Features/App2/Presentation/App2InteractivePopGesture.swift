import SwiftUI
import UIKit

/// 隱藏 navigation bar 之後，把邊緣滑回手勢接回來——**只接掛上它的那一個導航堆疊**。
///
/// SwiftUI 的 `NavigationStack` 底層仍是 `UINavigationController`。一旦
/// `.toolbar(.hidden, for: .navigationBar)`，UIKit 會連 `interactivePopGestureRecognizer`
/// 一起停掉——2.0 的子頁每一頁都有自己的 App2 header，所以 bar 一定是隱藏的，
/// 結果就是「push 有了、手勢沒有」（2026-09-02 使用者實機回報）。
///
/// 用 `.background(App2InteractivePopGesture())` 掛在 `NavigationStack` 的內容上；
/// 探針 view controller 只沿著自己的 parent 鏈找到那一個 `UINavigationController`，
/// 其餘導航堆疊（首頁、課表、紀錄、詳情、onboarding）的 delegate 不受影響。
struct App2InteractivePopGesture: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        Probe(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        uiViewController.view.isUserInteractionEnabled = false
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var attached: UINavigationController?

        func attach(to navigationController: UINavigationController) {
            guard attached !== navigationController else { return }
            attached = navigationController
            navigationController.interactivePopGestureRecognizer?.delegate = self
        }

        /// 與系統預設一致：堆疊只剩根頁時不放行，免得在根頁上滑出空白轉場。
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (attached?.viewControllers.count ?? 0) > 1
        }
    }

    private final class Probe: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if let navigationController = parent?.navigationController ?? navigationController {
                coordinator.attach(to: navigationController)
            }
        }
    }
}
