import UIKit

/// 隱藏 navigation bar 之後把邊緣滑回手勢接回來。
///
/// SwiftUI 的 `NavigationStack` 底層仍是 `UINavigationController`。一旦
/// `.toolbar(.hidden, for: .navigationBar)`，UIKit 會連 `interactivePopGestureRecognizer`
/// 一起停掉——2.0 的子頁每一頁都有自己的 App2 header，所以 bar 一定是隱藏的，
/// 結果就是「push 有了、手勢沒有」（2026-09-02 使用者實機回報）。
///
/// 把 delegate 接回來並只在「堆疊裡不只一頁」時允許開始，行為與系統預設一致。
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    /// 頁內還有橫向捲動（圖表、chip 列）時不搶手勢：兩邊都能動。
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
