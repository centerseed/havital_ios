import SwiftUI
import PhotosUI

/// 分享卡生成與編輯 Sheet
struct WorkoutShareCardSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutShareCardViewModel()

    let workout: WorkoutV2
    let workoutDetail: WorkoutV2Detail?

    // 狀態變量
    @State private var selectedPhoto: UIImage?
    @State private var showPhotoPicker = false
    @State private var selectedSize: ShareCardSize = .instagram11  // 預設 1:1 比例
    @State private var selectedLayoutMode: ShareCardLayoutMode = .bottom  // 預設底部版型
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var fullWorkout: WorkoutV2?  // 完整的 workout 數據（包含 shareCardContent）

    // 圖片變換狀態
    @State private var photoScale: CGFloat = 1.0
    @State private var photoOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    // 文字編輯狀態
    @State private var showTitleEditor = false
    @State private var showEncouragementEditor = false
    @State private var editingTitle: String = ""
    @State private var editingEncouragement: String = ""
    @State private var customTitle: String?
    @State private var customEncouragement: String?

    // 文字疊加層管理
    @State private var textOverlays: [TextOverlay] = []
    @State private var showTextOverlayEditor = false
    @State private var editingOverlayText: String = ""
    @State private var editingOverlayId: UUID?  // 正在編輯的疊加層 ID（nil 表示新增）
    @State private var selectedOverlayId: UUID?  // 選中的疊加層（用於刪除或編輯）

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 預覽區域
                if let cardData = viewModel.cardData {
                    ScrollView {
                        // 創建包含變換參數、自訂文案和文字疊加層的 cardData
                        let transformedData = WorkoutShareCardData(
                            workout: cardData.workout,
                            workoutDetail: cardData.workoutDetail,
                            userPhoto: cardData.userPhoto,
                            layoutMode: cardData.layoutMode,
                            colorScheme: cardData.colorScheme,
                            photoScale: photoScale,
                            photoOffset: photoOffset,
                            customAchievementTitle: customTitle,
                            customEncouragementText: customEncouragement,
                            textOverlays: textOverlays
                        )

                        VStack(spacing: 12) {
                            // 提示文字（僅在有照片時顯示）
                            if selectedPhoto != nil {
                                Text("雙指縮放、拖曳調整圖片位置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }

                            // 分享卡預覽
                            WorkoutShareCardView(data: transformedData, size: selectedSize)
                                .scaleEffect(previewScale)
                                .frame(width: previewWidth, height: previewHeight)
                                .cornerRadius(12)
                                .shadow(radius: 8)
                                .padding(.horizontal)

                            // 文字編輯按鈕
                            HStack(spacing: 12) {
                                Button(action: {
                                    editingTitle = customTitle ?? transformedData.achievementTitle
                                    showTitleEditor = true
                                }) {
                                    HStack {
                                        Image(systemName: "text.cursor")
                                            .font(.system(size: 14))
                                        Text("編輯標題")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .foregroundColor(.blue)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }

                                Button(action: {
                                    editingEncouragement = customEncouragement ?? transformedData.encouragementText
                                    showEncouragementEditor = true
                                }) {
                                    HStack {
                                        Image(systemName: "bubble.left")
                                            .font(.system(size: 14))
                                        Text("編輯鼓勵語")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .foregroundColor(.blue)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)

                            // 添加文字按鈕
                            Button(action: {
                                addNewTextOverlay()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                    Text("添加自由文字")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)

                            // 文字疊加層列表（如果有的話）
                            if !textOverlays.isEmpty {
                                VStack(spacing: 8) {
                                    Text("已添加的文字 (\(textOverlays.count))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    ForEach(textOverlays) { overlay in
                                        HStack {
                                            Text(overlay.text)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Button(action: {
                                                editTextOverlay(overlay)
                                            }) {
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.blue)
                                            }

                                            Button(action: {
                                                deleteTextOverlay(overlay.id)
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .gesture(
                            // 僅在有照片時啟用手勢
                            selectedPhoto != nil ?
                            MagnificationGesture()
                                .onChanged { value in
                                    photoScale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = photoScale
                                    // 限制縮放範圍 0.5x - 3x
                                    photoScale = min(max(photoScale, 0.5), 3.0)
                                    lastScale = photoScale
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            photoOffset = CGSize(
                                                width: lastOffset.width + value.translation.width / previewScale,
                                                height: lastOffset.height + value.translation.height / previewScale
                                            )
                                        }
                                        .onEnded { value in
                                            lastOffset = photoOffset
                                        }
                                )
                            : nil
                        )
                    }
                } else {
                    // 載入狀態 - 包含 isGenerating 和初始狀態
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在生成分享卡...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                }

                Divider()

                // 控制區域
                VStack(spacing: 16) {
                    // 照片選擇和重置按鈕
                    HStack(spacing: 12) {
                        // 照片選擇按鈕
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 18))
                                Text("選擇照片")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundColor(.blue)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // 重置圖片變換按鈕（僅在有照片時顯示）
                        if selectedPhoto != nil && (photoScale != 1.0 || photoOffset != .zero) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    photoScale = 1.0
                                    photoOffset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                }
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.orange)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }

                    // 布局選擇器
                    if viewModel.cardData != nil {
                        Menu {
                            Button(action: {
                                changeLayout(.bottom)
                            }) {
                                HStack {
                                    Text("底部版型")
                                    if selectedLayoutMode == .bottom {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button(action: {
                                changeLayout(.top)
                            }) {
                                HStack {
                                    Text("頂部版型")
                                    if selectedLayoutMode == .top {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button(action: {
                                changeLayout(.side)
                            }) {
                                HStack {
                                    Text("側邊版型")
                                    if selectedLayoutMode == .side {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Button(action: {
                                changeLayout(.auto)
                            }) {
                                HStack {
                                    Text("自動選擇")
                                    if selectedLayoutMode == .auto {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.3.group")
                                    .font(.system(size: 14))
                                Text(layoutDisplayName(selectedLayoutMode))
                                    .font(.system(size: 16, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundColor(.blue)
                        }
                    }

                    // 尺寸選擇（3 種比例）
                    if viewModel.cardData != nil {
                        Menu {
                            ForEach(ShareCardSize.allCases, id: \.aspectRatio) { size in
                                Button(action: {
                                    selectedSize = size
                                }) {
                                    HStack {
                                        Text(size.displayName)
                                        if selectedSize == size {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14))
                                Text(selectedSize.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundColor(.blue)
                        }
                    }

                    // 分享按鈕（藍色實心）
                    if viewModel.cardData != nil {
                        Button(action: {
                            Task {
                                await exportAndShare()
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18))
                                Text("分享")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isGenerating)
                    }
                }
                .padding()
            }
            .navigationTitle("生成分享卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 立即準備數據（同步，無延遲）
                prepareFullWorkoutData()

                // 異步生成分享卡
                Task {
                    await viewModel.generateShareCard(
                        workout: fullWorkout ?? workout,
                        workoutDetail: workoutDetail,
                        userPhoto: nil
                    )
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(selectedImage: $selectedPhoto)
            }
            .onChange(of: selectedPhoto) { oldPhoto, newPhoto in
                print("📱 [WorkoutShareCardSheetView] selectedPhoto 改變: \(oldPhoto == nil ? "nil" : "有圖片") -> \(newPhoto == nil ? "nil" : "有圖片")")

                if let photo = newPhoto {
                    print("✅ [WorkoutShareCardSheetView] 偵測到新照片，尺寸: \(photo.size)")

                    // 重置圖片變換狀態
                    photoScale = 1.0
                    photoOffset = .zero
                    lastScale = 1.0
                    lastOffset = .zero

                    Task {
                        print("🔄 [WorkoutShareCardSheetView] 開始重新生成分享卡（包含照片）")
                        await viewModel.generateShareCard(
                            workout: fullWorkout ?? workout,
                            workoutDetail: workoutDetail,
                            userPhoto: photo
                        )
                    }
                } else {
                    print("⚠️ [WorkoutShareCardSheetView] selectedPhoto 變為 nil")
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = generatedImage {
                    ActivityViewController(activityItems: [image])
                }
            }
            .alert("編輯成就標題", isPresented: $showTitleEditor) {
                TextField("輸入標題（最多50字）", text: $editingTitle)
                    .lineLimit(2)
                Button("確定") {
                    if editingTitle.count <= 50 {
                        customTitle = editingTitle.isEmpty ? nil : editingTitle
                    }
                }
                Button("重置") {
                    customTitle = nil
                    editingTitle = ""
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("自訂你的成就標題，讓分享更個人化！")
            }
            .alert("編輯鼓勵語", isPresented: $showEncouragementEditor) {
                TextField("輸入鼓勵語（最多80字）", text: $editingEncouragement)
                    .lineLimit(3)
                Button("確定") {
                    if editingEncouragement.count <= 80 {
                        customEncouragement = editingEncouragement.isEmpty ? nil : editingEncouragement
                    }
                }
                Button("重置") {
                    customEncouragement = nil
                    editingEncouragement = ""
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("添加你的訓練感想或勵志語錄！")
            }
            .alert(editingOverlayId == nil ? "添加自由文字" : "編輯文字", isPresented: $showTextOverlayEditor) {
                TextField("輸入文字（最多30字）", text: $editingOverlayText)
                    .lineLimit(2)
                Button("確定") {
                    saveTextOverlay()
                }
                Button("取消", role: .cancel) {
                    editingOverlayId = nil
                }
            } message: {
                Text(editingOverlayId == nil ? "在分享卡上添加你的個性文字！" : "修改你的文字內容")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("選擇照片開始生成分享卡")
                .font(.headline)

            Text("您也可以不選擇照片,直接使用預設背景")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("選擇照片") {
                showPhotoPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Properties

    private var previewWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 32
        let maxWidth = screenWidth - padding

        switch selectedSize {
        case .instagram916:
            // 保持 9:16 比例 (豎屏，較窄)
            return min(maxWidth, 300)
        case .instagram11:
            // 保持 1:1 比例 (正方形)
            return min(maxWidth, 360)
        case .instagram45:
            // 保持 4:5 比例 (豎屏，中等寬度)
            return min(maxWidth, 320)
        }
    }

    private var previewHeight: CGFloat {
        switch selectedSize {
        case .instagram916:
            return previewWidth * (16.0 / 9.0)
        case .instagram11:
            return previewWidth
        case .instagram45:
            return previewWidth * (5.0 / 4.0)
        }
    }

    /// 預覽縮放比例（將 1080x1920 縮放到預覽尺寸）
    private var previewScale: CGFloat {
        return previewWidth / selectedSize.width
    }

    // MARK: - Data Loading

    /// 準備完整的 workout 數據（同步執行，無延遲）
    private func prepareFullWorkoutData() {
        // 優先使用 workoutDetail 的數據（來自詳情 API）
        if let detail = workoutDetail {
            // 創建一個新的 WorkoutV2 對象，包含 workoutDetail 的完整數據
            fullWorkout = WorkoutV2(
                id: workout.id,
                provider: workout.provider,
                activityType: workout.activityType,
                startTimeUtc: workout.startTimeUtc,
                endTimeUtc: workout.endTimeUtc,
                durationSeconds: workout.durationSeconds,
                distanceMeters: workout.distanceMeters,
                deviceName: workout.deviceName,
                basicMetrics: workout.basicMetrics,
                advancedMetrics: workout.advancedMetrics,
                createdAt: workout.createdAt,
                schemaVersion: workout.schemaVersion,
                storagePath: workout.storagePath,
                dailyPlanSummary: detail.dailyPlanSummary,
                aiSummary: detail.aiSummary,
                shareCardContent: detail.shareCardContent
            )
        } else {
            fullWorkout = workout
        }
    }

    // MARK: - Export & Share

    private func exportAndShare() async {
        guard let cardData = viewModel.cardData else { return }

        // 創建包含用戶調整後變換參數、自訂文案和文字疊加層的 cardData
        let transformedData = WorkoutShareCardData(
            workout: cardData.workout,
            workoutDetail: cardData.workoutDetail,
            userPhoto: cardData.userPhoto,
            layoutMode: cardData.layoutMode,
            colorScheme: cardData.colorScheme,
            photoScale: photoScale,
            photoOffset: photoOffset,
            customAchievementTitle: customTitle,
            customEncouragementText: customEncouragement,
            textOverlays: textOverlays
        )

        let shareCardView = WorkoutShareCardView(data: transformedData, size: selectedSize)

        if let image = await viewModel.exportAsImage(size: selectedSize, view: AnyView(shareCardView)) {
            await MainActor.run {
                self.generatedImage = image
                self.showShareSheet = true
            }
        }
    }

    // MARK: - Layout Management

    /// 切換布局模式
    private func changeLayout(_ layout: ShareCardLayoutMode) {
        selectedLayoutMode = layout
        Task {
            await viewModel.regenerateWithLayout(layout)
        }
    }

    /// 布局模式顯示名稱
    private func layoutDisplayName(_ layout: ShareCardLayoutMode) -> String {
        switch layout {
        case .bottom: return "底部版型"
        case .top: return "頂部版型"
        case .side: return "側邊版型"
        case .auto: return "自動選擇"
        }
    }

    // MARK: - Text Overlay Management

    /// 添加新文字疊加層
    private func addNewTextOverlay() {
        editingOverlayText = ""
        editingOverlayId = nil
        showTextOverlayEditor = true
    }

    /// 編輯現有文字疊加層
    private func editTextOverlay(_ overlay: TextOverlay) {
        editingOverlayText = overlay.text
        editingOverlayId = overlay.id
        showTextOverlayEditor = true
    }

    /// 刪除文字疊加層
    private func deleteTextOverlay(_ id: UUID) {
        textOverlays.removeAll { $0.id == id }
    }

    /// 保存文字疊加層
    private func saveTextOverlay() {
        guard !editingOverlayText.isEmpty, editingOverlayText.count <= 30 else { return }

        if let editingId = editingOverlayId {
            // 編輯現有疊加層
            if let index = textOverlays.firstIndex(where: { $0.id == editingId }) {
                textOverlays[index].text = editingOverlayText
            }
        } else {
            // 添加新疊加層（預設位置在畫面中央）
            let centerPosition = CGPoint(
                x: selectedSize.width / 2,
                y: selectedSize.height / 2
            )
            let newOverlay = TextOverlay(
                text: editingOverlayText,
                position: centerPosition
            )
            textOverlays.append(newOverlay)
        }

        // 重置編輯狀態
        editingOverlayId = nil
        editingOverlayText = ""
    }
}

// MARK: - Photo Picker

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let result = results.first else {
                print("⚠️ [PhotoPicker] 未選擇任何圖片")
                return
            }

            let itemProvider = result.itemProvider

            print("📸 [PhotoPicker] 開始載入圖片...")

            // 方法 1: 使用 loadDataRepresentation（更可靠）
            itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, error in
                if let error = error {
                    print("⚠️ [PhotoPicker] loadDataRepresentation 失敗: \(error.localizedDescription)")
                    // Fallback 到方法 2
                    self?.loadImageUsingObject(itemProvider)
                    return
                }

                guard let data = data, let image = UIImage(data: data) else {
                    print("⚠️ [PhotoPicker] 無法將數據轉換為圖片，嘗試方法 2")
                    // Fallback 到方法 2
                    self?.loadImageUsingObject(itemProvider)
                    return
                }

                print("✅ [PhotoPicker] 圖片載入成功（方法 1），尺寸: \(image.size)")

                DispatchQueue.main.async {
                    self?.parent.selectedImage = image
                }
            }
        }

        // Fallback 方法：使用 loadObject
        private func loadImageUsingObject(_ itemProvider: NSItemProvider) {
            print("📸 [PhotoPicker] 使用 loadObject 載入圖片...")

            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let error = error {
                    print("❌ [PhotoPicker] loadObject 也失敗: \(error.localizedDescription)")
                    return
                }

                guard let image = object as? UIImage else {
                    print("❌ [PhotoPicker] 無法轉換為 UIImage")
                    return
                }

                print("✅ [PhotoPicker] 圖片載入成功（方法 2），尺寸: \(image.size)")

                DispatchQueue.main.async {
                    self?.parent.selectedImage = image
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutShareCardSheetView(
        workout: WorkoutV2(
            id: "preview-1",
            provider: "apple_health",
            activityType: "running",
            startTimeUtc: ISO8601DateFormatter().string(from: Date()),
            endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(5400)),
            durationSeconds: 5400,
            distanceMeters: 13200,
            deviceName: "Apple Watch",
            basicMetrics: BasicMetrics(
                avgPaceSPerKm: 392
            ),
            advancedMetrics: AdvancedMetrics(
                trainingType: "long_run"
            ),
            createdAt: nil,
            schemaVersion: nil,
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: ShareCardContent(
                achievementTitle: "LSD 90 分鐘完成!",
                encouragementText: "配速穩定,進步正在累積。",
                streakDays: 7,
                achievementBadge: nil
            )
        ),
        workoutDetail: nil
    )
}
