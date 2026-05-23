import SwiftUI

// MARK: - WorkoutRecapView
//
// 統一分享畫面（RecapShareCard + 照片 + 底部分享鈕）。
// showConfetti = true 時撒花（自動彈完訓場景），false 時靜態（從 WorkoutDetailView 進入）。
//
// 已接好的接縫：
//   - content: WorkoutRecapContent（欄位皆已格式化）
//   - showConfetti: Bool（情境旗標，預設 false）
//   - dismiss()：關閉 = InterruptCoordinator 標記已讀（每筆只彈一次）

struct WorkoutRecapView: View {
    let content: WorkoutRecapContent
    var showConfetti: Bool = false
    var onWriteDiary: (() -> Void)? = nil
    var onUpgrade: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isConfettiVisible = false

    @State private var selectedPhoto: UIImage?
    @State private var shareImage: UIImage?
    @State private var isExporting = false
    @State private var activeSheet: RecapActiveSheet?

    // 同一個 view 不可掛多個 .sheet(isPresented:)（後者會壓制前者）→ 用單一 item 驅動。
    private enum RecapActiveSheet: Int, Identifiable {
        case photo, share
        var id: Int { rawValue }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 14) {
                    RecapShareCard(content: content, photo: selectedPhoto, onPhotoTap: {
                        activeSheet = .photo
                    })
                    .shadow(color: RecapPalette.brand.opacity(0.20), radius: 16, x: 0, y: 10)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle(NSLocalizedString("workout.share.title", comment: "分享訓練成果"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(Color(UIColor.secondarySystemGroupedBackground), in: Circle())
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) { shareBar }
            }

            if isConfettiVisible {
                RecapConfettiCannon()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .task {
            guard showConfetti else { return }
            // 等 sheet 轉場稍穩再灑花（cannon 自播墜落 5 秒、末 2 秒淡出）。
            try? await Task.sleep(nanoseconds: 300_000_000)
            isConfettiVisible = true
            try? await Task.sleep(nanoseconds: 5_200_000_000)
            isConfettiVisible = false
        }
        .sheet(item: $activeSheet) { which in
            switch which {
            case .photo:
                PhotoPicker(selectedImage: $selectedPhoto)
            case .share:
                if let shareImage = shareImage {
                    ActivityViewController(activityItems: [shareImage])
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Share（底部主要動作）

    private var shareBar: some View {
        VStack(spacing: 0) {
            Button {
                Task { await exportAndShare() }
            } label: {
                HStack(spacing: 10) {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(NSLocalizedString("workout.share.action", comment: "分享這次成就"))
                        .font(AppFont.labelStrong())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [RecapPalette.brand, RecapPalette.brand.opacity(0.87)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: RecapPalette.brand.opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(alignment: .top) {
            Rectangle().fill(Color(UIColor.separator).opacity(0.5)).frame(height: 0.5)
        }
    }

    @MainActor
    private func exportAndShare() async {
        isExporting = true
        defer { isExporting = false }

        let exportSize = CGSize(width: 360, height: 450)  // 4:5
        let card = RecapShareCard(content: content, photo: selectedPhoto, cornerRadius: 0)
            .frame(width: exportSize.width, height: exportSize.height)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 4.0  // → 1440 x 1800

        if let image = renderer.uiImage {
            shareImage = image
            activeSheet = .share
        }
    }
}
