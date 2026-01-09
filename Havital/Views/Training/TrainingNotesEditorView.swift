import SwiftUI

/// 訓練心得編輯器視圖
/// Sheet modal 用於編輯運動的訓練心得
struct TrainingNotesEditorView: View {
    let workoutId: String
    let initialNotes: String?
    let onSave: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var notesText: String = ""
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let maxCharacters = WorkoutConstants.maxTrainingNotesLength

    // 字符計數顏色
    private var characterCountColor: Color {
        if notesText.count > maxCharacters {
            return .red
        } else if notesText.count > maxCharacters - 100 {
            return .orange
        }
        return .secondary
    }

    // 是否可以保存
    private var canSave: Bool {
        notesText.count <= maxCharacters
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 主要內容
                VStack(spacing: 0) {
                    // 字符計數器
                    HStack {
                        Spacer()
                        Text("\(notesText.count) / \(maxCharacters)")
                            .font(.caption)
                            .foregroundColor(characterCountColor)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }
                    .background(Color(UIColor.systemGroupedBackground))

                    // 文字編輯器
                    TextEditor(text: $notesText)
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollContentBackground(.hidden)
                        .background(Color(UIColor.systemBackground))
                }

                // 載入遮罩
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text(NSLocalizedString(L10n.WorkoutDetail.trainingNotesSaving, comment: ""))
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(NSLocalizedString(L10n.WorkoutDetail.trainingNotesEditorTitle, comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString(L10n.WorkoutDetail.trainingNotesCancel, comment: "")) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString(L10n.WorkoutDetail.trainingNotesSave, comment: "")) {
                        saveNotes()
                    }
                    .disabled(!canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .alert(NSLocalizedString(L10n.WorkoutDetail.trainingNotesSaveError, comment: ""), isPresented: $showError) {
                Button(NSLocalizedString(L10n.Common.ok, comment: "")) {
                    showError = false
                }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            // 初始化文本
            notesText = initialNotes ?? ""
        }
    }

    // MARK: - 保存方法

    private func saveNotes() {
        guard canSave else { return }

        isSaving = true

        Task {
            do {
                // 檢查任務是否被取消
                try Task.checkCancellation()

                let success = await onSave(notesText)

                // 再次檢查任務是否被取消
                try Task.checkCancellation()

                await MainActor.run {
                    isSaving = false

                    if success {
                        dismiss()
                    } else {
                        errorMessage = NSLocalizedString(L10n.WorkoutDetail.trainingNotesSaveError, comment: "")
                        showError = true
                    }
                }
            } catch is CancellationError {
                // 任務被取消，靜默處理
                Logger.debug("[TrainingNotesEditorView] Save task cancelled")
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                // 其他錯誤
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("有現有心得") {
    TrainingNotesEditorView(
        workoutId: "preview-workout-123",
        initialNotes: "今天的訓練感覺非常好！",
        onSave: { notes in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return true
        }
    )
}

#Preview("空白心得") {
    TrainingNotesEditorView(
        workoutId: "preview-workout-456",
        initialNotes: nil,
        onSave: { notes in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return true
        }
    )
}

#Preview("長文本") {
    TrainingNotesEditorView(
        workoutId: "preview-workout-789",
        initialNotes: String(repeating: "這是一段很長的訓練心得。", count: 50),
        onSave: { notes in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return true
        }
    )
}
