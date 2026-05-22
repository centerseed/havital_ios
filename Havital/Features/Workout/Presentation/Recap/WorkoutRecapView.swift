import SwiftUI

// MARK: - WorkoutRecapView
//
// 訓練完成 Recap，對齊 Claude Design 的 RecapSheet（recap.jsx）：
//   單頁不捲動 = 可分享成果卡（RecapShareCard）+ 精簡 RPE 色階條 + 單行心得 + 底部分享鈕。
//
// 已接好的接縫：
//   - content: WorkoutRecapContent（欄位皆已格式化）
//   - dismiss()：關閉 = InterruptCoordinator 標記已讀（每筆只彈一次）
//   - onWriteDiary / onUpgrade：行為接縫
//   - RPE 選擇即時 updateRPE 持久化
//   - 分享：把 RecapShareCard 渲染成圖 → 系統分享

struct WorkoutRecapView: View {
    let content: WorkoutRecapContent
    var onWriteDiary: (() -> Void)? = nil
    var onUpgrade: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showConfetti = false

    @State private var selectedPhoto: UIImage?
    @State private var selectedRPE: Int?
    @State private var shareImage: UIImage?
    @State private var isExporting = false
    @State private var activeSheet: RecapActiveSheet?

    // 同一個 view 不可掛多個 .sheet(isPresented:)（後者會壓制前者）→ 用單一 item 驅動。
    private enum RecapActiveSheet: Int, Identifiable {
        case photo, diary, share
        var id: Int { rawValue }
    }

    private var workoutRepository: WorkoutRepository {
        DependencyContainer.shared.resolve()
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 14) {
                    RecapShareCard(content: content, photo: selectedPhoto, onPhotoTap: {
                        activeSheet = .photo
                    })
                    .shadow(color: RecapPalette.brand.opacity(0.20), radius: 16, x: 0, y: 10)

                    rpeSection
                    diaryInline
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("本次訓練完成")
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

            if showConfetti {
                RecapConfettiCannon()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .task {
            // 等 sheet 轉場稍穩再灑花（cannon 自播墜落 5 秒、末 2 秒淡出）。
            try? await Task.sleep(nanoseconds: 300_000_000)
            showConfetti = true
            try? await Task.sleep(nanoseconds: 5_200_000_000)
            showConfetti = false
        }
        .onAppear {
            if selectedRPE == nil, let rpe = content.rpe {
                selectedRPE = Int(rpe.rounded())
            }
        }
        .sheet(item: $activeSheet) { which in
            switch which {
            case .photo:
                PhotoPicker(selectedImage: $selectedPhoto)
            case .diary:
                RecapDiaryEditorView(
                    workoutId: content.id,
                    typeName: content.trainingTypeName,
                    distanceText: content.distanceText,
                    date: content.date,
                    rpe: selectedRPE,
                    onSave: { notes in
                        do {
                            try await workoutRepository.updateTrainingNotes(id: content.id, notes: notes)
                            return true
                        } catch {
                            return false
                        }
                    }
                )
            case .share:
                if let shareImage = shareImage {
                    ActivityViewController(activityItems: [shareImage])
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - RPE（精簡色階條，對齊 RPEDotStripCompact）

    private var rpeSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedRPE == nil ? "今天感覺如何？" : "今天的體感 \(selectedRPE!)/10")
                    .font(AppFont.micro())
                    .foregroundColor(.primary)
                Spacer()
                if let rpe = selectedRPE {
                    Text(rpeFeedback(rpe))
                        .font(AppFont.micro())
                        .foregroundColor(RecapPalette.rpe(rpe))
                }
            }
            .padding(.horizontal, 2)

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { value in
                    rpePill(value)
                }
            }
        }
    }

    private func rpePill(_ value: Int) -> some View {
        let c = RecapPalette.rpe(value)
        let selected = selectedRPE == value
        let dim = selectedRPE != nil && !selected
        return Button {
            selectRPE(value)
        } label: {
            Text("\(value)")
                .font(AppFont.micro().monospacedDigit())
                .foregroundColor(selected ? .white : c)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(selected ? c : c.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .scaleEffect(selected ? 1.08 : 1.0)
                .opacity(dim ? 0.55 : 1.0)
                .shadow(color: selected ? c.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func rpeFeedback(_ v: Int) -> String {
        switch v {
        case ...3: return "輕巧地完成 ✓"
        case 4...5: return "節奏掌握得不錯 ✓"
        case 6...7: return "紮實的一次 ✓"
        default: return "硬仗打完了 💪"
        }
    }

    private func selectRPE(_ value: Int) {
        withAnimation(.easeOut(duration: 0.15)) { selectedRPE = value }
        let workoutId = content.id
        Task { try? await workoutRepository.updateRPE(id: workoutId, rpe: value) }
    }

    // MARK: - Diary（單行精簡卡，對齊 DiaryInline）

    private var diaryInline: some View {
        Button {
            activeSheet = .diary
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("寫下今天的感受")
                        .font(AppFont.micro())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                    Text("一句話也算 · 點此開始")
                        .font(AppFont.micro())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
                    Text("分享這次成就")
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
