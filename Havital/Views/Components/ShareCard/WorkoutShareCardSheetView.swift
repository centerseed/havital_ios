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
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var fullWorkout: WorkoutV2?  // 完整的 workout 數據（包含 shareCardContent）

    // 圖片變換狀態
    @State private var photoScale: CGFloat = 1.0
    @State private var photoOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 預覽區域
                if let cardData = viewModel.cardData {
                    ScrollView {
                        // 創建包含變換參數的 cardData
                        let transformedData = WorkoutShareCardData(
                            workout: cardData.workout,
                            workoutDetail: cardData.workoutDetail,
                            userPhoto: cardData.userPhoto,
                            layoutMode: cardData.layoutMode,
                            colorScheme: cardData.colorScheme,
                            photoScale: photoScale,
                            photoOffset: photoOffset
                        )

                        VStack {
                            // 提示文字（僅在有照片時顯示）
                            if selectedPhoto != nil {
                                Text("雙指縮放、拖曳調整圖片位置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }

                            WorkoutShareCardView(data: transformedData, size: selectedSize)
                                .scaleEffect(previewScale)
                                .frame(width: previewWidth, height: previewHeight)
                                .cornerRadius(12)
                                .shadow(radius: 8)
                                .padding()
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
                } else if viewModel.isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在生成分享卡...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    emptyStateView
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

                    // 尺寸選擇（顯示當前比例）
                    if viewModel.cardData != nil {
                        Button(action: {
                            // 切換尺寸
                            selectedSize = selectedSize == .instagram916 ? .instagram11 : .instagram916
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14))
                                Text(selectedSize == .instagram916 ? "1:1 (Instagram Post)" : "9:16 (Instagram Stories)")
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
            .task {
                // 初次載入：先確保有完整的 workout 數據（包含 shareCardContent）
                await loadFullWorkoutData()

                // 使用完整的 workout 數據生成分享卡
                await viewModel.generateShareCard(
                    workout: fullWorkout ?? workout,
                    workoutDetail: workoutDetail,
                    userPhoto: nil
                )
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(selectedImage: $selectedPhoto)
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                if newPhoto != nil {
                    // 重置圖片變換狀態
                    photoScale = 1.0
                    photoOffset = .zero
                    lastScale = 1.0
                    lastOffset = .zero

                    Task {
                        await viewModel.generateShareCard(
                            workout: fullWorkout ?? workout,
                            workoutDetail: workoutDetail,
                            userPhoto: newPhoto
                        )
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = generatedImage {
                    ActivityViewController(activityItems: [image])
                }
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
            // 保持 9:16 比例
            return min(maxWidth, 300)
        case .instagram11:
            // 保持 1:1 比例
            return min(maxWidth, 360)
        }
    }

    private var previewHeight: CGFloat {
        switch selectedSize {
        case .instagram916:
            return previewWidth * (16.0 / 9.0)
        case .instagram11:
            return previewWidth
        }
    }

    /// 預覽縮放比例（將 1080x1920 縮放到預覽尺寸）
    private var previewScale: CGFloat {
        switch selectedSize {
        case .instagram916:
            return previewWidth / selectedSize.width
        case .instagram11:
            return previewWidth / selectedSize.width
        }
    }

    // MARK: - Data Loading

    /// 檢查並打印 workout 的 shareCardContent 狀態
    private func loadFullWorkoutData() async {
        // 詳細調試信息
        print("📋 [WorkoutShareCardSheetView] 檢查 shareCardContent")
        print("   - workout.id: \(workout.id)")
        print("   - workout.shareCardContent 是否為 nil: \(workout.shareCardContent == nil)")
        print("   - workoutDetail 是否為 nil: \(workoutDetail == nil)")
        print("   - workoutDetail?.shareCardContent 是否為 nil: \(workoutDetail?.shareCardContent == nil)")

        // 優先使用 workoutDetail 的數據（來自詳情 API）
        if let detail = workoutDetail {
            print("✅ [WorkoutShareCardSheetView] 使用 workoutDetail 的數據")
            print("   - shareCardContent: \(detail.shareCardContent != nil)")
            print("   - dailyPlanSummary: \(detail.dailyPlanSummary != nil)")

            if let detailContent = detail.shareCardContent {
                print("   - achievementTitle: \(detailContent.achievementTitle ?? "nil")")
                print("   - encouragementText: \(detailContent.encouragementText ?? "nil")")
                print("   - streakDays: \(detailContent.streakDays?.description ?? "nil")")
            }

            if let planSummary = detail.dailyPlanSummary {
                print("   - trainingType: \(planSummary.trainingType ?? "nil")")
                print("   - distanceKm: \(planSummary.distanceKm?.description ?? "nil")")
                print("   - pace: \(planSummary.pace ?? "nil")")
            }

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
                dailyPlanSummary: detail.dailyPlanSummary,  // 使用詳情 API 的 dailyPlanSummary
                aiSummary: detail.aiSummary,  // 使用詳情 API 的 aiSummary
                shareCardContent: detail.shareCardContent  // 使用詳情 API 的 shareCardContent
            )
        } else if let workoutContent = workout.shareCardContent {
            print("⚠️ [WorkoutShareCardSheetView] workoutDetail 無 shareCardContent，使用 workout.shareCardContent")
            print("   - achievementTitle: \(workoutContent.achievementTitle ?? "nil")")
            print("   - encouragementText: \(workoutContent.encouragementText ?? "nil")")
            print("   - streakDays: \(workoutContent.streakDays?.description ?? "nil")")
            fullWorkout = workout
        } else {
            print("⚠️ [WorkoutShareCardSheetView] 兩者都無 shareCardContent，將使用本地生成")
            fullWorkout = workout
        }
    }

    // MARK: - Export & Share

    private func exportAndShare() async {
        guard let cardData = viewModel.cardData else { return }

        let shareCardView = WorkoutShareCardView(data: cardData, size: selectedSize)

        if let image = await viewModel.exportAsImage(size: selectedSize, view: AnyView(shareCardView)) {
            await MainActor.run {
                self.generatedImage = image
                self.showShareSheet = true
            }
        }
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

            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let error = error {
                    print("❌ [PhotoPicker] 載入圖片失敗: \(error.localizedDescription)")
                    return
                }

                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.selectedImage = image
                    }
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
