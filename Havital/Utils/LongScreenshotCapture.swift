import SwiftUI
import UIKit

// MARK: - Long Screenshot Capture Utility

extension UIView {
    func captureFullScrollContent() -> UIImage? {
        // 找到最頂層的 ScrollView
        guard let scrollView = findScrollView() else {
            // 如果沒有 ScrollView，直接截取當前 view
            return captureAsImage()
        }
        
        return scrollView.captureFullContent()
    }
    
    private func findScrollView() -> UIScrollView? {
        if let scrollView = self as? UIScrollView {
            return scrollView
        }
        
        for subview in subviews {
            if let scrollView = subview.findScrollView() {
                return scrollView
            }
        }
        
        return nil
    }
    
    func captureAsImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
}

extension UIScrollView {
    func captureFullContent() -> UIImage? {
        // 保存當前狀態
        let originalOffset = contentOffset
        let originalFrame = frame
        let originalBounds = bounds
        
        // 計算完整內容的尺寸
        let fullContentSize = contentSize
        guard fullContentSize.width > 0 && fullContentSize.height > 0 else {
            return captureAsImage()
        }
        
        // 創建完整內容的圖片
        let renderer = UIGraphicsImageRenderer(size: fullContentSize)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // 保存上下文狀態
            cgContext.saveGState()
            
            // 移動到內容的頂部
            contentOffset = CGPoint.zero
            
            // 調整 frame 來包含所有內容
            let tempFrame = CGRect(origin: bounds.origin, size: fullContentSize)
            bounds = tempFrame
            
            // 渲染整個內容
            layer.render(in: cgContext)
            
            // 恢復上下文狀態
            cgContext.restoreGState()
        }
        
        // 恢復原始狀態
        contentOffset = originalOffset
        frame = originalFrame
        bounds = originalBounds
        
        return image
    }
}

// MARK: - SwiftUI View Extensions for Screenshot

struct ScreenshotView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    @Binding var capturedImage: UIImage?
    @Binding var isCapturing: Bool
    
    func makeUIViewController(context: Context) -> ScreenshotViewController<Content> {
        return ScreenshotViewController(content: content)
    }
    
    func updateUIViewController(_ uiViewController: ScreenshotViewController<Content>, context: Context) {
        if isCapturing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.capturedImage = uiViewController.captureScreenshot()
                self.isCapturing = false
            }
        }
    }
}

class ScreenshotViewController<Content: View>: UIViewController {
    private let hostingController: UIHostingController<Content>
    
    init(content: Content) {
        self.hostingController = UIHostingController(rootView: content)
        super.init(nibName: nil, bundle: nil)
        setupHostingController()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupHostingController() {
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func captureScreenshot() -> UIImage? {
        view.layoutIfNeeded()
        return view.captureFullScrollContent()
    }
}

// MARK: - Main Screenshot Capture Function

struct LongScreenshotCapture {
    static func captureView<Content: View>(_ content: Content, completion: @escaping (UIImage?) -> Void) {
        // 使用臨時窗口來確保視圖正確渲染
        let window = UIWindow(frame: UIScreen.main.bounds)
        let hostingController = UIHostingController(rootView: content)
        
        // 優化窗口設置
        window.backgroundColor = UIColor.systemGray6 // 設置背景色
        window.layer.backgroundColor = UIColor.systemGray6.cgColor
        window.windowLevel = UIWindow.Level.normal
        
        // 設置 HostingController
        hostingController.view.backgroundColor = UIColor.systemGray6
        hostingController.view.isOpaque = true
        
        // 設置窗口
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        window.isHidden = false
        
        // 強制佈局並等待視圖完全渲染
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        // 優化的階段性渲染：縮短等待時間但保證品質
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // 第一階段：基礎佈局
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                // 第二階段：圖表渲染等待
                hostingController.view.setNeedsLayout()
                hostingController.view.layoutIfNeeded()
                
                // 暫時禁用動畫以確保穩定的截圖
                let animationsWereEnabled = UIView.areAnimationsEnabled
                UIView.setAnimationsEnabled(false)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // 第三階段：最終截圖
                    hostingController.view.setNeedsLayout()
                    hostingController.view.layoutIfNeeded()
                    
                    let image = captureScrollableContent(hostingController.view)
                    
                    // 恢復動畫設置
                    UIView.setAnimationsEnabled(animationsWereEnabled)
                    
                    // 清理窗口
                    window.isHidden = true
                    window.resignKey()
                    
                    // 品質驗證和重試機制
                    if let capturedImage = image, isScreenshotQualityAcceptable(capturedImage) {
                        completion(capturedImage)
                    } else {
                        print("LongScreenshot: 第一次截圖品質不佳，進行重試...")
                        // 重試機制：增加等待時間並重新渲染
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            // 強制重新佈局
                            hostingController.view.setNeedsLayout()
                            hostingController.view.layoutIfNeeded()
                            
                            let retryImage = captureScrollableContent(hostingController.view)
                            
                            // 即使重試後品質仍不理想，也返回結果
                            completion(retryImage ?? image)
                        }
                    }
                }
            }
        }
    }
    
    private static func captureScrollableContent(_ view: UIView) -> UIImage? {
        print("開始截圖，原始 view 尺寸: \(view.frame)")
        
        // 優先嘗試使用整個根視圖，這樣可以確保所有內容都被包含
        let shouldUseRootView = true // 暫時強制使用根視圖
        
        let targetView: UIView
        if shouldUseRootView {
            targetView = view
            print("使用根視圖進行截圖")
        } else {
            targetView = findScrollViewOrRoot(view)
            print("使用目標視圖: \(type(of: targetView)), 尺寸: \(targetView.frame)")
        }
        
        // 改進的內容大小計算 - 優先使用根視圖的方法
        let contentSize: CGSize
        
        if shouldUseRootView {
            // 對於根視圖，使用更精確的計算方法
            targetView.setNeedsLayout()
            targetView.layoutIfNeeded()
            
            // 更精確的內容大小計算，減少不必要的留白
            var actualContentBounds = CGRect.zero
            var maxWidth: CGFloat = UIScreen.main.bounds.width
            
            func calculateActualBounds(_ view: UIView, in coordinateSpace: UIView) {
                for subview in view.subviews {
                    if !subview.isHidden && subview.alpha > 0 {
                        // 轉換到根視圖的坐標系
                        let convertedFrame = coordinateSpace.convert(subview.frame, from: subview.superview ?? view)
                        
                        if actualContentBounds == .zero {
                            actualContentBounds = convertedFrame
                        } else {
                            actualContentBounds = actualContentBounds.union(convertedFrame)
                        }
                        
                        maxWidth = max(maxWidth, convertedFrame.maxX)
                        
                        // 遞歸處理子視圖
                        calculateActualBounds(subview, in: coordinateSpace)
                    }
                }
            }
            
            calculateActualBounds(targetView, in: targetView)
            
            // 如果沒有內容，使用預設尺寸
            if actualContentBounds == .zero {
                actualContentBounds = CGRect(x: 0, y: 0, width: maxWidth, height: 800)
            }
            
            // 添加小量內邊距，但不過多
            let padding: CGFloat = 20
            let finalHeight = actualContentBounds.height + (padding * 2)
            let finalWidth = max(actualContentBounds.width + (padding * 2), maxWidth)
            
            contentSize = CGSize(
                width: finalWidth,
                height: finalHeight
            )
            
            print("根視圖內容大小: \(contentSize)")
            
        } else if let scrollView = targetView as? UIScrollView {
            // ScrollView 的處理方式
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
            
            let actualContentSize = scrollView.contentSize
            var maxSubviewHeight: CGFloat = 0
            
            for subview in scrollView.subviews {
                let subviewBottom = subview.frame.origin.y + subview.frame.height
                maxSubviewHeight = max(maxSubviewHeight, subviewBottom)
            }
            
            let actualHeight = max(actualContentSize.height, maxSubviewHeight)
            
            contentSize = CGSize(
                width: max(actualContentSize.width, UIScreen.main.bounds.width),
                height: max(actualHeight, 1000)
            )
            
            print("找到 ScrollView，內容大小: \(contentSize)")
            
        } else {
            // 一般視圖的處理
            let maxSize = CGSize(
                width: UIScreen.main.bounds.width,
                height: UIView.layoutFittingExpandedSize.height
            )
            let calculatedSize = targetView.systemLayoutSizeFitting(
                maxSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            contentSize = CGSize(
                width: max(calculatedSize.width, UIScreen.main.bounds.width),
                height: max(calculatedSize.height, 800)
            )
            
            print("一般視圖內容大小: \(contentSize)")
        }
        
        // 最終尺寸
        let finalSize = contentSize
        
        // 創建圖像
        let renderer = UIGraphicsImageRenderer(size: finalSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 設置背景
            cgContext.setFillColor(UIColor.systemGray6.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: finalSize))
            
            // 根據是否使用根視圖來選擇渲染策略
            if shouldUseRootView {
                // 根視圖渲染：保護所有內容
                let originalFrame = targetView.frame
                
                // 設置為正確的尺寸
                targetView.frame = CGRect(origin: .zero, size: finalSize)
                
                // 递歸強制所有子視圖的佈局
                func forceLayoutRecursively(_ view: UIView) {
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    for subview in view.subviews {
                        forceLayoutRecursively(subview)
                    }
                }
                
                forceLayoutRecursively(targetView)
                
                // 直接渲染整個視圖樹
                targetView.layer.render(in: cgContext)
                
                // 恢復原始尺寸
                targetView.frame = originalFrame
                
            } else if let scrollView = targetView as? UIScrollView {
                // ScrollView 渲染策略
                let originalOffset = scrollView.contentOffset
                let originalBounds = scrollView.bounds
                
                scrollView.contentOffset = .zero
                scrollView.bounds = CGRect(origin: .zero, size: finalSize)
                
                // 強制佈局更新
                func forceLayoutRecursively(_ view: UIView) {
                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    for subview in view.subviews {
                        forceLayoutRecursively(subview)
                    }
                }
                forceLayoutRecursively(scrollView)
                
                scrollView.layer.render(in: cgContext)
                
                // 恢復原始設置
                scrollView.contentOffset = originalOffset
                scrollView.bounds = originalBounds
                
            } else {
                // 一般視圖渲染
                let originalFrame = targetView.frame
                targetView.frame = CGRect(origin: .zero, size: finalSize)
                
                targetView.setNeedsLayout()
                targetView.layoutIfNeeded()
                
                targetView.layer.render(in: cgContext)
                targetView.frame = originalFrame
            }
        }
    }
    
    private static func findScrollViewOrRoot(_ view: UIView) -> UIView {
        // 收集所有 ScrollView，選擇最大的那個（通常是主容器）
        var allScrollViews: [UIScrollView] = []
        
        func collectScrollViews(_ view: UIView) {
            if let scrollView = view as? UIScrollView {
                allScrollViews.append(scrollView)
            }
            for subview in view.subviews {
                collectScrollViews(subview)
            }
        }
        
        collectScrollViews(view)
        
        // 選擇最大的 ScrollView（通常是主容器）
        if let mainScrollView = allScrollViews.max(by: { $0.frame.height < $1.frame.height }) {
            print("找到 \(allScrollViews.count) 個 ScrollView，選擇最大的：\(mainScrollView.frame)")
            return mainScrollView
        }
        
        // 如果沒找到 ScrollView，返回根視圖
        print("未找到 ScrollView，使用根視圖")
        return view
    }
    
    private static func captureFullView(_ view: UIView) -> UIImage? {
        // 找到內容的實際大小
        let contentSize = calculateContentSize(view)
        
        // 確保有合理的尺寸
        guard contentSize.width > 0 && contentSize.height > 0 else {
            return view.captureAsImage()
        }
        
        // 創建高解析度的圖像
        let scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: contentSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 設置白色背景
            cgContext.setFillColor(UIColor.systemGray6.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: contentSize))
            
            // 渲染視圖內容
            view.layer.render(in: cgContext)
        }
    }
    
    private static func calculateContentSize(_ view: UIView) -> CGSize {
        // 強制計算實際內容大小
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let size = view.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        // 確保最小尺寸
        let minHeight: CGFloat = 800
        return CGSize(
            width: max(size.width, UIScreen.main.bounds.width),
            height: max(size.height, minHeight)
        )
    }
    
    // MARK: - 截圖品質驗證
    
    private static func isScreenshotQualityAcceptable(_ image: UIImage) -> Bool {
        let minWidth: CGFloat = 300
        let minHeight: CGFloat = 600
        let maxAspectRatio: CGFloat = 10.0 // 防止過於細長的截圖
        
        // 檢查基本尺寸
        guard image.size.width >= minWidth && image.size.height >= minHeight else {
            print("Screenshot 尺寸過小: \(image.size)")
            return false
        }
        
        // 檢查寬高比例
        let aspectRatio = image.size.height / image.size.width
        guard aspectRatio <= maxAspectRatio else {
            print("Screenshot 寬高比例異常: \(aspectRatio)")
            return false
        }
        
        // 檢查是否為空白圖片（簡單檢查）
        if isImageMostlyBlank(image) {
            print("Screenshot 似乎是空白的")
            return false
        }
        
        return true
    }
    
    private static func isImageMostlyBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        
        // 簡單檢查：取樣點檢查是否大部分都是相同的顏色
        let width = cgImage.width
        let height = cgImage.height
        
        // 如果圖片太小，直接返回 false
        if width < 100 || height < 100 { return false }
        
        // 取樣几個點檢查
        let samplePoints = [
            (width / 4, height / 4),
            (width / 2, height / 2),
            (width * 3 / 4, height * 3 / 4),
            (width / 4, height * 3 / 4),
            (width * 3 / 4, height / 4)
        ]
        
        // 簡化的檢查：如果高度過小可能是渲染問題
        return image.size.height < 200
    }
}