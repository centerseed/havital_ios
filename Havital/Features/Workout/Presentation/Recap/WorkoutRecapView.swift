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

    // 功能 1：自訂標題（nil=預設；""=不顯示；其他=自訂）
    @State private var customTitle: String? = nil
    @State private var editingTitle: String = ""
    @State private var showTitleEditor = false

    // 功能 3：照片拖曳定位
    @State private var photoOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // 同一個 view 不可掛多個 .sheet(isPresented:)（後者會壓制前者）→ 用單一 item 驅動。
    private enum RecapActiveSheet: Int, Identifiable {
        case photo, share
        var id: Int { rawValue }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 14) {
                    // 卡片尺寸（對齊 exportAndShare 的 4:5 比例）
                    GeometryReader { geo in
                        let cardWidth = geo.size.width
                        let cardHeight = cardWidth * (5.0 / 4.0)

                        RecapShareCard(
                            content: content,
                            photo: selectedPhoto,
                            onPhotoTap: { activeSheet = .photo },
                            customTitle: customTitle,
                            photoOffset: photoOffset
                        )
                        // 點標題文字 → 彈 alert 編輯
                        .onTapGesture { location in
                            // 底部 info block 大約在下方 30% 高度範圍
                            if location.y > cardHeight * 0.65 {
                                editingTitle = customTitle ?? ""
                                showTitleEditor = true
                            }
                        }
                        // 有照片時掛 DragGesture 供定位（不用 MagnificationGesture）
                        .gesture(
                            selectedPhoto != nil
                            ? DragGesture()
                                .onChanged { value in
                                    // 只更新 offset，不呼叫 ImageRenderer，避免卡頓
                                    photoOffset = clampedOffset(
                                        base: lastOffset,
                                        translation: value.translation,
                                        photo: selectedPhoto,
                                        cardSize: CGSize(width: cardWidth, height: cardHeight)
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = photoOffset
                                }
                            : nil
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .shadow(color: RecapPalette.brand.opacity(0.20), radius: 16, x: 0, y: 10)
                    }
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)

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
                // 標題編輯 Alert
                .alert(
                    NSLocalizedString("workout.share.card.edit_title", comment: ""),
                    isPresented: $showTitleEditor
                ) {
                    TextField("", text: $editingTitle)
                    Button(NSLocalizedString("common.confirm", comment: "")) {
                        let trimmed = editingTitle.trimmingCharacters(in: .whitespaces)
                        customTitle = trimmed.isEmpty ? nil : String(trimmed.prefix(30))
                    }
                    Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) {
                        customTitle = ""
                        editingTitle = ""
                    }
                    Button(NSLocalizedString("common.reset", comment: "")) {
                        customTitle = nil
                        editingTitle = ""
                    }
                    Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
                }
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
                    .onChange(of: selectedPhoto) { _, _ in
                        // 換照片時重置 offset
                        photoOffset = .zero
                        lastOffset = .zero
                    }
            case .share:
                if let shareImage = shareImage {
                    ActivityViewController(activityItems: [shareImage])
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Clamp 夾制算法
    //
    // scaledToFill 時，photo 在 cardSize 上的實際渲染尺寸：
    //   scale = max(cardW / imgW, cardH / imgH)   ← 選較大的縮放比才能填滿
    //   scaledW = imgW * scale,  scaledH = imgH * scale
    //
    // 溢出量（每軸溢出卡片的總像素）：
    //   overflowX = scaledW - cardW（≥ 0）
    //   overflowY = scaledH - cardH（≥ 0）
    //
    // 可偏移範圍（± 一半溢出量）：
    //   maxOffsetX = overflowX / 2,  maxOffsetY = overflowY / 2
    //
    // 不溢出的軸 overflow = 0 → maxOffset = 0 → offset 強制夾 0，避免黑邊。

    private func clampedOffset(
        base: CGSize,
        translation: CGSize,
        photo: UIImage?,
        cardSize: CGSize
    ) -> CGSize {
        guard let photo = photo, photo.size.width > 0, photo.size.height > 0 else {
            return .zero
        }

        let imgW = photo.size.width
        let imgH = photo.size.height
        let cardW = cardSize.width
        let cardH = cardSize.height

        let scale = max(cardW / imgW, cardH / imgH)
        let scaledW = imgW * scale
        let scaledH = imgH * scale

        let maxOffsetX = max(0, (scaledW - cardW) / 2)
        let maxOffsetY = max(0, (scaledH - cardH) / 2)

        let rawX = base.width + translation.width
        let rawY = base.height + translation.height

        return CGSize(
            width:  min(max(rawX, -maxOffsetX), maxOffsetX),
            height: min(max(rawY, -maxOffsetY), maxOffsetY)
        )
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
        // 渲染時帶入同樣的 customTitle 與 photoOffset，確保分享圖與畫面一致。
        // cornerRadius: 0 → 全出血矩形，避免縮圖透明棋盤。
        let card = RecapShareCard(
            content: content,
            photo: selectedPhoto,
            cornerRadius: 0,
            customTitle: customTitle,
            photoOffset: photoOffset
        )
        .frame(width: exportSize.width, height: exportSize.height)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 4.0  // → 1440 x 1800

        if let image = renderer.uiImage {
            shareImage = image
            activeSheet = .share
        }
    }
}
