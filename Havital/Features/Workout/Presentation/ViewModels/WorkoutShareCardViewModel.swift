import SwiftUI
import Combine

/// 分享卡 ViewModel - 管理分享卡的生成與導出
class WorkoutShareCardViewModel: ObservableObject, TaskManageable {

    // MARK: - Published Properties

    @Published var cardData: WorkoutShareCardData?
    @Published var isGenerating = false
    @Published var error: String?
    @Published var selectedLayout: ShareCardLayoutMode = .auto

    // MARK: - Task Management

    let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private let photoAnalyzer = PhotoAnalyzer()

    // MARK: - Lifecycle

    init() {
        print("📱 [WorkoutShareCardViewModel] 初始化")
    }

    deinit {
        print("📱 [WorkoutShareCardViewModel] 釋放,取消所有任務")
        cancelAllTasks()
    }

    // MARK: - Public Methods

    /// 生成分享卡
    func generateShareCard(
        workout: WorkoutV2,
        workoutDetail: WorkoutV2Detail?,
        userPhoto: UIImage?
    ) async {
        // 立即設置載入狀態，確保 UI 即時更新
        await MainActor.run {
            self.isGenerating = true
            self.error = nil
        }

        await executeTask(id: TaskID("generate_share_card")) { [weak self] in
            guard let self = self else { return }

            do {
                // 照片分析（僅在有照片時執行）
                let photoAnalysis = userPhoto.map { self.photoAnalyzer.analyze($0) }

                // 版型選擇 (優先使用用戶選擇,否則使用分析結果)
                let layout: ShareCardLayoutMode
                if self.selectedLayout == .auto {
                    layout = photoAnalysis?.suggestedLayout ?? .bottom
                } else {
                    layout = self.selectedLayout
                }

                // 配色方案
                let colorScheme = photoAnalysis?.suggestedColorScheme ?? .default

                // 計算並緩存照片平均顏色（僅計算一次，優化性能）
                let cachedAverageColor = userPhoto?.averageColor

                // 構建分享卡數據
                var data = WorkoutShareCardData(
                    workout: workout,
                    workoutDetail: workoutDetail,
                    userPhoto: userPhoto,
                    layoutMode: layout,
                    colorScheme: colorScheme
                )
                data.cachedPhotoAverageColor = cachedAverageColor

                await MainActor.run {
                    self.cardData = data
                    self.isGenerating = false
                }

                print("✅ [WorkoutShareCardViewModel] 分享卡生成成功,版型: \(layout)")

            } catch {
                await MainActor.run {
                    self.error = "生成分享卡失敗: \(error.localizedDescription)"
                    self.isGenerating = false
                }

                print("❌ [WorkoutShareCardViewModel] 分享卡生成失敗: \(error.localizedDescription)")
            }
        }
    }

    /// 重新生成 (切換版型時使用)
    func regenerateWithLayout(_ layout: ShareCardLayoutMode) async {
        guard let existingData = cardData else {
            print("⚠️ [WorkoutShareCardViewModel] 無現有數據,無法重新生成")
            return
        }

        selectedLayout = layout
        await generateShareCard(
            workout: existingData.workout,
            workoutDetail: existingData.workoutDetail,
            userPhoto: existingData.userPhoto
        )
    }

    /// 導出為圖片
    func exportAsImage(size: ShareCardSize, view: AnyView) async -> UIImage? {
        print("📸 [WorkoutShareCardViewModel] 開始導出圖片,尺寸: \(size.aspectRatio)")

        // 使用標準渲染
        let image = await renderViewAsImage(view: view, size: size.cgSize)

        if let image = image {
            print("✅ [WorkoutShareCardViewModel] 圖片導出成功,尺寸: \(image.size)")
            return image
        } else {
            print("❌ [WorkoutShareCardViewModel] 圖片導出失敗")
            return nil
        }
    }

    // MARK: - Private Methods

    /// 將 SwiftUI View 渲染為 UIImage
    @MainActor
    private func renderViewAsImage(view: AnyView, size: CGSize) async -> UIImage? {
        // 創建 hosting controller
        let controller = UIHostingController(rootView: view)

        // 設置精確的大小
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        // 添加到一個容器視圖中，確保正確佈局
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        containerView.backgroundColor = .clear
        containerView.addSubview(controller.view)

        // 強制佈局
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // 等待一幀確保 SwiftUI 完全渲染
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒

        // 使用 UIGraphicsImageRenderer 渲染
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            containerView.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }

        // 清理
        controller.view.removeFromSuperview()

        return image
    }

    /// 清除當前數據
    func clearCardData() {
        cardData = nil
        error = nil
        selectedLayout = .auto
        print("🗑️ [WorkoutShareCardViewModel] 已清除分享卡數據")
    }
}
