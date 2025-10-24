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
        await executeTask(id: TaskID("generate_share_card")) { [weak self] in
            guard let self = self else { return }

            await MainActor.run { self.isGenerating = true }

            do {
                // 照片分析
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

                // 構建分享卡數據
                let data = WorkoutShareCardData(
                    workout: workout,
                    workoutDetail: workoutDetail,
                    userPhoto: userPhoto,
                    layoutMode: layout,
                    colorScheme: colorScheme
                )

                await MainActor.run {
                    self.cardData = data
                    self.isGenerating = false
                    self.error = nil
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

        // 使用 UIHostingController 將 SwiftUI View 轉換為 UIImage
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
        // 創建 UIHostingController
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black  // 使用黑色背景防止白色留白

        // 強制佈局
        controller.view.layoutIfNeeded()

        // 渲染為圖片
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

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
