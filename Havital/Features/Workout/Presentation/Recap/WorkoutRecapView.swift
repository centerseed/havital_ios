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
    var canvasData: ShareCardCanvasData = .empty
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

    // Overlay 編輯狀態（標題 / 配速曲線 / 路線）
    @State private var editorState = ShareCardEditorState.default
    @State private var overlayDragStart: (kind: ShareCardOverlayKind, layout: ShareCardElementLayout)?

    // 功能 3：照片拖曳定位 + pinch 縮放
    @State private var photoOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var photoScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    // 卡片比例（4:5 預設）。刻意不持久化：每次開分享畫面都回到 4:5。
    @State private var selectedAspect: ShareCardAspect = .portrait45

    // 首次進入分享畫面的功能說明卡
    @State private var showFeatureTip = false

    // 同一個 view 不可掛多個 .sheet(isPresented:)（後者會壓制前者）→ 用單一 item 驅動。
    private enum RecapActiveSheet: Int, Identifiable {
        case photo, share
        var id: Int { rawValue }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 14) {
                    // 卡片尺寸（與 exportAndShare 共用 selectedAspect，預覽＝匯出）
                    GeometryReader { geo in
                        let cardWidth = geo.size.width
                        let cardHeight = cardWidth / selectedAspect.ratio

                        let cardSize = CGSize(width: cardWidth, height: cardHeight)

                        ZStack {
                            RecapShareCard(
                                content: content,
                                photo: selectedPhoto,
                                onPhotoTap: { activeSheet = .photo },
                                customTitle: customTitle,
                                photoOffset: photoOffset,
                                photoScale: photoScale,
                                aspect: selectedAspect,
                                canvasData: canvasData,
                                editorState: editorState,
                                showEditChrome: true
                            )
                            // 有照片時掛「拖曳 + 縮放」（overlay 手勢層在上層優先）。
                            // SimultaneousGesture：兩指縮放的同時仍可拖曳，不必先放開再拖。
                            .gesture(
                                selectedPhoto != nil
                                ? photoGesture(cardSize: cardSize)
                                : nil
                            )

                            shareCardOverlayGestures(cardSize: cardSize)
                        }
                        .frame(width: cardWidth, height: cardHeight)
                        .shadow(color: RecapPalette.brand.opacity(0.20), radius: 16, x: 0, y: 10)
                    }
                    .aspectRatio(selectedAspect.ratio, contentMode: .fit)

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
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        ShareCardAspectPicker(selection: $selectedAspect)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 6)
                        ShareCardEditorControls(
                            canvasData: canvasData,
                            editorState: $editorState
                        )
                        shareBar
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
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

            if showFeatureTip {
                ShareCardFeatureTipSheet(
                    onDismissTemporarily: {
                        withAnimation(.easeOut(duration: 0.2)) { showFeatureTip = false }
                    },
                    onDismissPermanently: {
                        ShareCardTipStorage.markDismissedPermanently()
                        withAnimation(.easeOut(duration: 0.2)) { showFeatureTip = false }
                    }
                )
                .zIndex(1)
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
        .task {
            // 首次進分享畫面 → 自動彈功能說明卡（觸發策略見 ShareCardTipStorage）
            guard ShareCardTipStorage.shouldShow() else { return }
            // 等本畫面轉場稍穩再彈，避免與 sheet 進場動畫打架
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                return  // 使用者在說明卡出現前就離開畫面 → 不計數、不顯示
            }
            // 計數時機 = 說明卡「實際顯示」時（spec §4），故移到 sleep 之後
            ShareCardTipStorage.markAutoShown()
            withAnimation(.easeOut(duration: 0.25)) { showFeatureTip = true }
        }
        .sheet(item: $activeSheet) { which in
            switch which {
            case .photo:
                PhotoPicker(selectedImage: $selectedPhoto)
                    .onChange(of: selectedPhoto) { _, _ in
                        // 換照片時重置平移與縮放（舊照片的位移套在新照片上會亂跑）
                        resetPhotoTransform()
                    }
            case .share:
                if let shareImage = shareImage {
                    ActivityViewController(activityItems: [shareImage])
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - 照片手勢（拖曳 + pinch 縮放）
    //
    // 夾制算法本身在 ShareCardPhotoMath（與匯出共用同一份，預覽＝分享圖）。

    private func photoGesture(cardSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard let photo = selectedPhoto else { return }
                    photoOffset = ShareCardPhotoMath.clampOffset(
                        base: lastOffset,
                        translation: value.translation,
                        image: photo.size,
                        card: cardSize,
                        photoScale: photoScale
                    )
                }
                .onEnded { _ in
                    lastOffset = photoOffset
                },
            MagnifyGesture()
                .onChanged { value in
                    guard let photo = selectedPhoto else { return }
                    photoScale = ShareCardPhotoMath.clampScale(lastScale * value.magnification)
                    // 縮小後可偏移範圍變小 → 立刻把 offset 夾回界內，否則會露白。
                    photoOffset = ShareCardPhotoMath.clampOffset(
                        photoOffset,
                        image: photo.size,
                        card: cardSize,
                        photoScale: photoScale
                    )
                }
                .onEnded { _ in
                    lastScale = photoScale
                    lastOffset = photoOffset
                }
        )
    }

    private func resetPhotoTransform() {
        photoOffset = .zero
        lastOffset = .zero
        photoScale = 1.0
        lastScale = 1.0
    }

    // MARK: - Overlay 拖曳 / 標題短按

    @ViewBuilder
    private func shareCardOverlayGestures(cardSize: CGSize) -> some View {
        ZStack {
            if editorState.titleLayout.isVisible,
               recapDisplayTitle != nil {
                overlayGestureTarget(
                    kind: .title,
                    layout: editorState.titleLayout,
                    size: titleHitSize(cardSize: cardSize),
                    cardSize: cardSize
                )
                .gesture(titleOverlayGesture(cardSize: cardSize))
            }

            if editorState.paceChartLayout.isVisible, canvasData.hasPaceSeries {
                overlayGestureTarget(
                    kind: .paceChart,
                    layout: editorState.paceChartLayout,
                    size: ShareCardPaceChartMath.chartSize(cardSize: cardSize),
                    cardSize: cardSize
                )
                .gesture(overlayDragGesture(kind: .paceChart, cardSize: cardSize))
            }

            if editorState.routeLayout.isVisible, canvasData.hasRoute {
                let side = ShareCardRouteMath.squareSize(
                    cardWidth: cardSize.width,
                    scale: editorState.routeScale
                )
                overlayGestureTarget(
                    kind: .routeGlyph,
                    layout: editorState.routeLayout,
                    size: CGSize(width: side, height: side),
                    cardSize: cardSize
                )
                .gesture(overlayDragGesture(kind: .routeGlyph, cardSize: cardSize))
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .allowsHitTesting(true)
    }

    private func overlayGestureTarget(
        kind: ShareCardOverlayKind,
        layout: ShareCardElementLayout,
        size: CGSize,
        cardSize: CGSize
    ) -> some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .position(
                x: cardSize.width * layout.centerX,
                y: cardSize.height * layout.centerY
            )
            .accessibilityIdentifier("share-card-overlay-\(kind)")
    }

    private func titleHitSize(cardSize: CGSize) -> CGSize {
        CGSize(width: cardSize.width * 0.80, height: 40)
    }

    private var recapDisplayTitle: String? {
        let defaultTitle: String
        if let type = content.trainingTypeName, !type.isEmpty {
            defaultTitle = String(
                format: NSLocalizedString("workout.share.card.completed_format", comment: ""),
                type
            )
        } else {
            defaultTitle = NSLocalizedString("workout.share.card.completed_default", comment: "")
        }
        return RecapShareCardLogic.displayTitle(
            editorState: editorState,
            customTitle: customTitle,
            defaultTitle: defaultTitle
        )
    }

    private func overlayDragGesture(kind: ShareCardOverlayKind, cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                applyOverlayDrag(kind: kind, translation: value.translation, cardSize: cardSize)
            }
            .onEnded { _ in
                overlayDragStart = nil
            }
    }

    private func titleOverlayGesture(cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let distance = hypot(value.translation.width, value.translation.height)
                guard distance >= 8 else { return }
                applyOverlayDrag(kind: .title, translation: value.translation, cardSize: cardSize)
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if distance < 8 {
                    editingTitle = customTitle ?? ""
                    showTitleEditor = true
                }
                overlayDragStart = nil
            }
    }

    private func applyOverlayDrag(
        kind: ShareCardOverlayKind,
        translation: CGSize,
        cardSize: CGSize
    ) {
        if overlayDragStart?.kind != kind {
            overlayDragStart = (kind, ShareCardEditorLogic.layout(kind: kind, in: editorState))
        }
        guard let start = overlayDragStart else { return }

        var temp = editorState
        switch kind {
        case .title: temp.titleLayout = start.layout
        case .paceChart: temp.paceChartLayout = start.layout
        case .routeGlyph: temp.routeLayout = start.layout
        }
        ShareCardEditorLogic.dragOverlay(
            kind: kind,
            translation: translation,
            cardSize: cardSize,
            state: &temp
        )
        editorState = temp
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

        // 4:5 → 360×450；9:16 → 360×640。比例、照片縮放與位移全部沿用預覽的值，
        // 確保分享出去的圖跟畫面上看到的一模一樣。
        // cornerRadius: 0 → 全出血矩形，避免縮圖透明棋盤。
        let exportSize = selectedAspect.exportSize(width: 360)
        let card = RecapShareCard(
            content: content,
            photo: selectedPhoto,
            cornerRadius: 0,
            customTitle: customTitle,
            photoOffset: photoOffset,
            photoScale: photoScale,
            aspect: selectedAspect,
            canvasData: canvasData,
            editorState: editorState,
            showEditChrome: false
        )
        .frame(width: exportSize.width, height: exportSize.height)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 4.0  // 4:5 → 1440×1800；9:16 → 1440×2560

        if let image = renderer.uiImage {
            shareImage = image
            activeSheet = .share
        }
    }
}
