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
    @State private var selectedSize: ShareCardSize = .instagram916
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 預覽區域
                if let cardData = viewModel.cardData {
                    ScrollView {
                        WorkoutShareCardView(data: cardData, size: selectedSize)
                            .frame(width: previewWidth, height: previewHeight)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                            .padding()
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
                    // 照片選擇
                    Button(action: {
                        showPhotoPicker = true
                    }) {
                        Label(selectedPhoto == nil ? "選擇照片" : "更換照片", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    // 版型選擇
                    if viewModel.cardData != nil {
                        Picker("版型", selection: $viewModel.selectedLayout) {
                            Text("自動").tag(ShareCardLayoutMode.auto)
                            Text("底部橫條").tag(ShareCardLayoutMode.bottom)
                            Text("側邊浮層").tag(ShareCardLayoutMode.side)
                            Text("頂部置中").tag(ShareCardLayoutMode.top)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.selectedLayout) { _, newLayout in
                            Task {
                                await viewModel.regenerateWithLayout(newLayout)
                            }
                        }

                        // 尺寸選擇
                        Picker("尺寸", selection: $selectedSize) {
                            Text("9:16 (Instagram Stories)").tag(ShareCardSize.instagram916)
                            Text("1:1 (Instagram Post)").tag(ShareCardSize.instagram11)
                        }
                        .pickerStyle(.menu)
                    }

                    // 分享按鈕
                    if viewModel.cardData != nil {
                        Button(action: {
                            Task {
                                await exportAndShare()
                            }
                        }) {
                            Label("分享", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
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
                // 初次載入,無照片時也生成預設分享卡
                await viewModel.generateShareCard(
                    workout: workout,
                    workoutDetail: workoutDetail,
                    userPhoto: nil
                )
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(selectedImage: $selectedPhoto)
                    .onChange(of: selectedPhoto) { _, newPhoto in
                        if newPhoto != nil {
                            Task {
                                await viewModel.generateShareCard(
                                    workout: workout,
                                    workoutDetail: workoutDetail,
                                    userPhoto: newPhoto
                                )
                            }
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
