import SwiftUI
import PhotosUI

/// 分享卡生成與編輯 Sheet - 簡潔版設計
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
    @State private var shareImage: UIImage?  // ShareLink 使用的圖片
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
    @State private var showTextOverlayList = false  // 控制文字列表顯示
    @State private var editingOverlayText: String = ""
    @State private var editingOverlayId: UUID?

    var body: some View {
        contentWithAlerts
    }

    private var contentWithAlerts: some View {
        contentWithLifecycle
            .alert("編輯成就標題", isPresented: $showTitleEditor) {
                titleEditorAlert
            } message: {
                Text("自訂你的成就標題，讓分享更個人化！")
            }
            .alert("編輯 AI 簡評", isPresented: $showEncouragementEditor) {
                encouragementEditorAlert
            } message: {
                Text("添加你的訓練感想或勵志語錄！")
            }
            .alert(editingOverlayId == nil ? "添加自由文字" : "編輯文字", isPresented: $showTextOverlayEditor) {
                textOverlayEditorAlert
            } message: {
                Text(editingOverlayId == nil ? "在分享卡上添加你的個性文字！" : "修改你的文字內容")
            }
    }

    private var contentWithLifecycle: some View {
        contentWithChangeHandlers
            .onAppear(perform: setupInitialCard)
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(selectedImage: $selectedPhoto)
            }
    }

    private var contentWithChangeHandlers: some View {
        contentWithPhotoHandlers
            .onChange(of: customTitle) { _, _ in
                Task { await updateShareImage() }
            }
            .onChange(of: customEncouragement) { _, _ in
                Task { await updateShareImage() }
            }
            // 注意：不監聽 textOverlays 變化，避免拖曳過程中重複生成圖片
            // 會在 updateTextOverlayPosition 中手動延遲更新
    }

    private var contentWithPhotoHandlers: some View {
        contentWithCardDataHandlers
            .onChange(of: selectedPhoto) { _, newPhoto in
                if let photo = newPhoto {
                    photoScale = 1.0
                    photoOffset = .zero
                    lastScale = 1.0
                    lastOffset = .zero

                    Task {
                        await viewModel.generateShareCard(
                            workout: fullWorkout ?? workout,
                            workoutDetail: workoutDetail,
                            userPhoto: photo
                        )
                        await updateShareImage()
                    }
                }
            }
            .onChange(of: photoScale) { _, _ in
                Task { await updateShareImage() }
            }
            .onChange(of: photoOffset) { _, _ in
                Task { await updateShareImage() }
            }
    }

    private var contentWithCardDataHandlers: some View {
        mainContentView
            .background(Color(UIColor.systemBackground))
            .onChange(of: viewModel.cardData?.workout.id) { _, _ in
                Task { await updateShareImage() }
            }
            .onChange(of: selectedSize) { _, _ in
                Task { await updateShareImage() }
            }
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 0) {
            topNavigationBar
            previewArea
            bottomToolbar
        }
    }

    // MARK: - Alert Content

    @ViewBuilder
    private var titleEditorAlert: some View {
        TextField("輸入標題（最多50字）", text: $editingTitle)
            .lineLimit(2)
        Button("確定") {
            if editingTitle.count <= 50 {
                customTitle = editingTitle.isEmpty ? nil : editingTitle
            }
        }
        Button("刪除", role: .destructive) {
            customTitle = ""  // 空字串代表已刪除
            editingTitle = ""
        }
        Button("重置") {
            customTitle = nil  // nil 代表使用原始值
            editingTitle = ""
        }
        Button("取消", role: .cancel) { }
    }

    @ViewBuilder
    private var encouragementEditorAlert: some View {
        TextField("輸入 AI 簡評（最多80字）", text: $editingEncouragement)
            .lineLimit(3)
        Button("確定") {
            if editingEncouragement.count <= 80 {
                customEncouragement = editingEncouragement.isEmpty ? nil : editingEncouragement
            }
        }
        Button("刪除", role: .destructive) {
            customEncouragement = ""  // 空字串代表已刪除
            editingEncouragement = ""
        }
        Button("重置") {
            customEncouragement = nil  // nil 代表使用原始值
            editingEncouragement = ""
        }
        Button("取消", role: .cancel) { }
    }

    @ViewBuilder
    private var textOverlayEditorAlert: some View {
        TextField("輸入文字（最多30字）", text: $editingOverlayText)
            .lineLimit(2)
        Button("確定") {
            saveTextOverlay()
        }
        Button("取消", role: .cancel) {
            editingOverlayId = nil
        }
    }

    // MARK: - Event Handlers

    private func setupInitialCard() {
        prepareFullWorkoutData()
        Task {
            await viewModel.generateShareCard(
                workout: fullWorkout ?? workout,
                workoutDetail: workoutDetail,
                userPhoto: nil
            )

            // 自動創建標題和鼓勵語的 TextOverlay（如果還沒有的話）
            await createInitialTextOverlays()
        }
    }

    private func createInitialTextOverlays() async {
        guard let cardData = viewModel.cardData else { return }

        // 只有在第一次載入且沒有任何自訂文字時才自動創建
        guard textOverlays.isEmpty else { return }

        var overlays: [TextOverlay] = []

        // 根據版型決定標題和鼓勵語的初始位置
        let titlePosition: CGPoint
        let encouragementPosition: CGPoint
        let width = selectedSize.width
        let height = selectedSize.height

        // 使用原本的 x 座標比例 0.26（已驗證可正確對齊數據區域）
        // y 座標調整以避免切邊
        let titleX = width * 0.26

        switch selectedLayoutMode {
        case .bottom, .auto:
            // 底部版型：標題和鼓勵語在底部偏上區域（留空間給數據和 badge）
            titlePosition = CGPoint(x: titleX, y: height * 0.72)
            encouragementPosition = CGPoint(x: titleX, y: height * 0.80)
        case .top:
            // 頂部版型：標題和鼓勵語在頂部區域（增加上邊距避免切邊）
            titlePosition = CGPoint(x: titleX, y: height * 0.12)
            encouragementPosition = CGPoint(x: titleX, y: height * 0.20)
        case .side:
            // 側邊版型：標題和鼓勵語在左側垂直居中（避開數據區域）
            titlePosition = CGPoint(x: titleX, y: height * 0.35)
            encouragementPosition = CGPoint(x: titleX, y: height * 0.55)
        }

        // 創建標題 TextOverlay（帶 icon）
        if !cardData.achievementTitle.isEmpty {
            let titleOverlay = TextOverlay(
                text: cardData.achievementTitle,
                position: titlePosition,
                fontSize: 48,
                fontWeight: .semibold,
                textColor: .white,
                iconName: "figure.run",
                iconSize: 42
            )
            overlays.append(titleOverlay)
        }

        // 創建鼓勵語 TextOverlay（帶 icon）
        if !cardData.encouragementText.isEmpty {
            let encouragementOverlay = TextOverlay(
                text: cardData.encouragementText,
                position: encouragementPosition,
                fontSize: 42,
                fontWeight: .regular,
                textColor: .white.opacity(0.95),
                iconName: "bubble.left.fill",
                iconSize: 36
            )
            overlays.append(encouragementOverlay)
        }

        textOverlays = overlays

        // 更新分享圖片
        await updateShareImage()
    }

    private func updateTextOverlaysForLayout(_ layout: ShareCardLayoutMode) {
        // 當版型改變時，只更新標題和鼓勵語的位置（保留自訂文字）
        let width = selectedSize.width
        let height = selectedSize.height

        // 使用與 createInitialTextOverlays 相同的 x 座標比例
        let titleX = width * 0.26

        for index in textOverlays.indices {
            let overlay = textOverlays[index]

            // 判斷是標題還是鼓勵語（根據 icon）
            if overlay.iconName == "figure.run" {
                // 這是標題
                switch layout {
                case .bottom, .auto:
                    textOverlays[index].position = CGPoint(x: titleX, y: height * 0.72)
                case .top:
                    textOverlays[index].position = CGPoint(x: titleX, y: height * 0.12)
                case .side:
                    textOverlays[index].position = CGPoint(x: titleX, y: height * 0.35)
                }
            } else if overlay.iconName == "bubble.left.fill" {
                // 這是鼓勵語
                switch layout {
                case .bottom, .auto:
                    textOverlays[index].position = CGPoint(x: titleX, y: height * 0.80)
                case .top:
                    textOverlays[index].position = CGPoint(x: titleX, y: height * 0.20)
                case .side:
                    textOverlays[index].position = CGPoint(x: titleX, y: height * 0.55)
                }
            }
            // 自訂文字（沒有 icon 或其他 icon）保持原位
        }
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("生成分享卡")
                .font(.headline)

            Spacer()

            if let shareImage = shareImage {
                ShareLink(item: Image(uiImage: shareImage), preview: SharePreview("分享卡", image: Image(uiImage: shareImage))) {
                    HStack(spacing: 4) {
                        Text("分享")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                    .frame(width: 70, height: 44)
                }
            } else {
                Color.clear.frame(width: 70, height: 44)
            }
        }
        .padding(.horizontal)
        .frame(height: 56)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Divider()
                .frame(height: 0.5)
                .background(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }

    // MARK: - Preview Area

    private var previewArea: some View {
        GeometryReader { geometry in
            if let cardData = viewModel.cardData {
                ScrollView {
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

                    VStack(spacing: 16) {
                        WorkoutShareCardView(
                            data: transformedData,
                            size: selectedSize,
                            previewScale: previewScale(for: geometry.size),
                            onTextOverlayPositionChanged: { overlayId, newPosition in
                                updateTextOverlayPosition(overlayId: overlayId, newPosition: newPosition)
                            },
                            onEditTitle: {
                                let currentData = viewModel.cardData
                                editingTitle = customTitle ?? currentData?.workout.shareCardContent?.achievementTitle ?? ""
                                showTitleEditor = true
                            },
                            onEditEncouragement: {
                                let currentData = viewModel.cardData
                                editingEncouragement = customEncouragement ?? currentData?.workout.shareCardContent?.encouragementText ?? ""
                                showEncouragementEditor = true
                            }
                        )
                            .scaleEffect(previewScale(for: geometry.size))
                            .frame(width: previewWidth(for: geometry.size), height: previewHeight(for: geometry.size))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                            .gesture(
                                selectedPhoto != nil ?
                                MagnificationGesture()
                                    .onChanged { value in
                                        photoScale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = photoScale
                                        photoScale = min(max(photoScale, 0.5), 3.0)
                                        lastScale = photoScale
                                    }
                                    .simultaneously(with:
                                        DragGesture()
                                            .onChanged { value in
                                                photoOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width / previewScale(for: geometry.size),
                                                    height: lastOffset.height + value.translation.height / previewScale(for: geometry.size)
                                                )
                                            }
                                            .onEnded { value in
                                                lastOffset = photoOffset
                                            }
                                    )
                                : nil
                            )

                        if selectedPhoto != nil {
                            Text("雙指縮放、拖曳調整圖片位置")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在生成分享卡...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            // 文字疊加層列表（可展開/收合）
            if !textOverlays.isEmpty {
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation {
                            showTextOverlayList.toggle()
                        }
                    }) {
                        HStack {
                            Text("已添加的文字 (\(textOverlays.count))")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: showTextOverlayList ? "chevron.down" : "chevron.up")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                    }

                    if showTextOverlayList {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(textOverlays) { overlay in
                                    HStack(spacing: 8) {
                                        Text(overlay.text)
                                            .font(.body)
                                            .lineLimit(1)

                                        Button(action: {
                                            editTextOverlay(overlay)
                                        }) {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 16))
                                                .foregroundColor(.blue)
                                        }

                                        Button(action: {
                                            deleteTextOverlay(overlay.id)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 16))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                }
            }

            Divider()

            // 工具列
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 20) {
                    // 📷 選擇照片
                    ToolbarButton(
                        icon: "photo",
                        label: "照片",
                        action: {
                            showPhotoPicker = true
                        }
                    )

                    // 🎨 版型選擇
                    Menu {
                        Button(action: { changeLayout(.bottom) }) {
                            HStack {
                                Text("底部版型")
                                if selectedLayoutMode == .bottom {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button(action: { changeLayout(.top) }) {
                            HStack {
                                Text("頂部版型")
                                if selectedLayoutMode == .top {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button(action: { changeLayout(.side) }) {
                            HStack {
                                Text("側邊版型")
                                if selectedLayoutMode == .side {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button(action: { changeLayout(.auto) }) {
                            HStack {
                                Text("自動選擇")
                                if selectedLayoutMode == .auto {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        ToolbarButtonLabel(icon: "rectangle.3.group", label: "版型")
                    }

                    // 📐 尺寸選擇
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
                        ToolbarButtonLabel(icon: "arrow.up.left.and.arrow.down.right", label: "尺寸")
                    }

                    // Aa 添加文字
                    ToolbarButton(
                        icon: "character.textbox",
                        label: "新增文字",
                        action: {
                            addNewTextOverlay()
                        }
                    )

                    // 重置圖片按鈕（僅在有照片且有變換時顯示）
                    if selectedPhoto != nil && (photoScale != 1.0 || photoOffset != .zero) {
                        ToolbarButton(
                            icon: "arrow.counterclockwise",
                            label: "重置",
                            action: {
                                withAnimation(.spring()) {
                                    photoScale = 1.0
                                    photoOffset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                }
                            }
                        )
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Helper Methods

    private func previewWidth(for size: CGSize) -> CGFloat {
        let maxWidth = size.width - 32
        switch selectedSize {
        case .instagram916:
            return min(maxWidth, 300)
        case .instagram11:
            return min(maxWidth, 360)
        case .instagram45:
            return min(maxWidth, 320)
        }
    }

    private func previewHeight(for size: CGSize) -> CGFloat {
        switch selectedSize {
        case .instagram916:
            return previewWidth(for: size) * (16.0 / 9.0)
        case .instagram11:
            return previewWidth(for: size)
        case .instagram45:
            return previewWidth(for: size) * (5.0 / 4.0)
        }
    }

    private func previewScale(for size: CGSize) -> CGFloat {
        return previewWidth(for: size) / selectedSize.width
    }

    private func prepareFullWorkoutData() {
        if let detail = workoutDetail {
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

    private func updateShareImage() async {
        guard let cardData = viewModel.cardData else { return }

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
                self.shareImage = image
            }
        }
    }

    private func changeLayout(_ layout: ShareCardLayoutMode) {
        selectedLayoutMode = layout

        // 更新標題和鼓勵語的位置以適應新版型
        updateTextOverlaysForLayout(layout)

        Task {
            await viewModel.regenerateWithLayout(layout)
            await updateShareImage()
        }
    }

    private func addNewTextOverlay() {
        editingOverlayText = ""
        editingOverlayId = nil
        showTextOverlayEditor = true
    }

    private func editTextOverlay(_ overlay: TextOverlay) {
        editingOverlayText = overlay.text
        editingOverlayId = overlay.id
        showTextOverlayEditor = true
    }

    private func deleteTextOverlay(_ id: UUID) {
        textOverlays.removeAll { $0.id == id }

        // 手動更新分享圖片
        Task {
            await updateShareImage()
        }
    }

    private func saveTextOverlay() {
        guard !editingOverlayText.isEmpty, editingOverlayText.count <= 30 else { return }

        if let editingId = editingOverlayId {
            if let index = textOverlays.firstIndex(where: { $0.id == editingId }) {
                textOverlays[index].text = editingOverlayText
            }
        } else {
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

        editingOverlayId = nil
        editingOverlayText = ""

        // 手動更新分享圖片
        Task {
            await updateShareImage()
        }
    }

    private func updateTextOverlayPosition(overlayId: UUID, newPosition: CGPoint) {
        if let index = textOverlays.firstIndex(where: { $0.id == overlayId }) {
            var overlay = textOverlays[index]
            // 限制位置在卡片範圍內
            let clampedX = max(0, min(newPosition.x, selectedSize.width))
            let clampedY = max(0, min(newPosition.y, selectedSize.height))
            overlay.position = CGPoint(x: clampedX, y: clampedY)

            // 立即更新位置（讓視覺即時反映）
            textOverlays[index] = overlay

            // 延遲重新生成分享圖片（避免頻繁重複生成，節省性能）
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
                await updateShareImage()
            }
        }
    }
}

// MARK: - Toolbar Button Component

// MARK: - Toolbar Button Components

/// 統一的工具列按鈕標籤視圖（供 Menu 和 Button 共用）
struct ToolbarButtonLabel: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 60, height: 60)
        .contentShape(Rectangle())
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarButtonLabel(icon: icon, label: label)
        }
        .buttonStyle(.plain)
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

            guard let result = results.first else { return }

            let itemProvider = result.itemProvider

            itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, error in
                if let error = error {
                    self?.loadImageUsingObject(itemProvider)
                    return
                }

                guard let data = data, let image = UIImage(data: data) else {
                    self?.loadImageUsingObject(itemProvider)
                    return
                }

                DispatchQueue.main.async {
                    self?.parent.selectedImage = image
                }
            }
        }

        private func loadImageUsingObject(_ itemProvider: NSItemProvider) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage else { return }

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
