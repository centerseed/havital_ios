import SwiftUI

// MARK: - WorkoutReflectionView
//
// RPE + 心得合併畫面，供 WorkoutDetailView 呼叫。
// 沿用 RecapDiaryEditorView 的 contextStrip / promptSection / editorCard 設計，
// 並加入上半的 RPE 色階條（沿用 recap 1-10 pill 配色）。
//
// 無 RPE 時首次進入 detail 會自動彈此畫面（由 WorkoutReflectionGate 判斷）。
// 也可從 advancedMetricsCard / TrainingNotesCard 手動觸發。

struct WorkoutReflectionView: View {
    let workoutId: String
    let typeName: String?
    let distanceText: String
    let date: Date
    let initialRPE: Int?
    let initialNotes: String?
    let onSaveRPE: (Int?) async -> Bool
    let onSaveNotes: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRPE: Int?
    @State private var notes: String
    @State private var isSaving = false
    @State private var showError = false
    @FocusState private var focused: Bool

    private let maxChars = WorkoutConstants.maxTrainingNotesLength

    init(
        workoutId: String,
        typeName: String?,
        distanceText: String,
        date: Date,
        initialRPE: Int?,
        initialNotes: String?,
        onSaveRPE: @escaping (Int?) async -> Bool,
        onSaveNotes: @escaping (String) async -> Bool
    ) {
        self.workoutId = workoutId
        self.typeName = typeName
        self.distanceText = distanceText
        self.date = date
        self.initialRPE = initialRPE
        self.initialNotes = initialNotes
        self.onSaveRPE = onSaveRPE
        self.onSaveNotes = onSaveNotes
        _selectedRPE = State(initialValue: initialRPE)
        _notes = State(initialValue: initialNotes ?? "")
    }

    // MARK: - Computed

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M/d (E) HH:mm"
        return f.string(from: date)
    }

    private var isOverLimit: Bool { notes.count > maxChars }
    private var isNearLimit: Bool { notes.count > maxChars - 50 }
    private var counterColor: Color {
        if isOverLimit { return PacerizColor.error }
        if isNearLimit { return PacerizColor.orange }
        return .secondary
    }

    private let prompts: [(label: String, icon: String)] = [
        ("配速", "🏃"), ("呼吸", "💨"), ("腿/腳", "🦵"), ("心率", "❤️"),
        ("補給", "💧"), ("比上次", "⏮"), ("後段", "🔚"), ("明天", "🌅")
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                contextStrip
                rpeSection
                promptSection
                editorCard
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("workout.reflection.title", comment: "訓練回顧"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "取消")) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("common.save", comment: "儲存")).fontWeight(.semibold)
                        }
                    }
                    .disabled(isOverLimit || isSaving)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
            }
            .alert(NSLocalizedString("workout.reflection.saveError", comment: "儲存失敗，請重試"), isPresented: $showError) {
                Button(NSLocalizedString("common.ok", comment: "確定"), role: .cancel) {}
            }
        }
    }

    // MARK: - Context Strip

    private var contextStrip: some View {
        HStack(spacing: 10) {
            Circle().fill(PacerizColor.blue).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(typeName ?? NSLocalizedString("workout.defaultType", comment: "訓練")) · \(distanceText)")
                    .font(AppFont.micro())
                    .foregroundColor(.primary)
                Text(dateText)
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            if let rpe = selectedRPE {
                HStack(spacing: 4) {
                    Text("RPE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                    Text("\(rpe)").font(.system(size: 12, weight: .heavy).monospacedDigit()).foregroundColor(.primary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemFill), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - RPE Section (1-10 color scale pills, from WorkoutRecapView)

    private var rpeSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedRPE == nil
                     ? NSLocalizedString("workout.rpe.prompt", comment: "今天感覺如何？")
                     : String(format: NSLocalizedString("workout.rpe.selected", comment: "今天的體感 %d/10"), selectedRPE!))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rpePill(_ value: Int) -> some View {
        let c = RecapPalette.rpe(value)
        let selected = selectedRPE == value
        let dim = selectedRPE != nil && !selected
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedRPE = value }
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
        case ...3: return NSLocalizedString("workout.rpe.feedback.low", comment: "輕巧地完成 ✓")
        case 4...5: return NSLocalizedString("workout.rpe.feedback.medium", comment: "節奏掌握得不錯 ✓")
        case 6...7: return NSLocalizedString("workout.rpe.feedback.high", comment: "紮實的一次 ✓")
        default:    return NSLocalizedString("workout.rpe.feedback.max", comment: "硬仗打完了 💪")
        }
    }

    // MARK: - Prompts (from RecapDiaryEditorView)

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("workout.diary.promptHint", comment: "可以從這裡開始 ↓"))
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                Spacer()
                Text(NSLocalizedString("workout.diary.promptTip", comment: "點主題會自動帶起頭"))
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 2)

            ReflectionFlowChips(items: prompts) { p in insertPrompt(p.label) }
        }
    }

    private func insertPrompt(_ topic: String) {
        let sep = notes.isEmpty ? "" : (notes.hasSuffix("\n") ? "" : "\n")
        notes += "\(sep)\(topic)："
        focused = true
    }

    // MARK: - Editor Card (from RecapDiaryEditorView)

    private var editorCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(NSLocalizedString("workout.diary.placeholder", comment: "寫下這次訓練的感受⋯ 一句話也算。"))
                        .font(AppFont.bodyRegular())
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $notes)
                    .focused($focused)
                    .font(AppFont.bodyRegular())
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 160, maxHeight: .infinity)
            }

            HStack {
                Text(NSLocalizedString("workout.diary.privacy", comment: "這份心得只有你看得到"))
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                Spacer()
                Text("\(notes.count) / \(maxChars)")
                    .font(AppFont.micro().monospacedDigit())
                    .foregroundColor(counterColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                Rectangle().fill(Color(UIColor.separator).opacity(0.5)).frame(height: 0.5)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxHeight: .infinity)
    }

    // MARK: - Save

    @MainActor
    private func save() async {
        guard !isOverLimit else { return }
        isSaving = true

        // Save RPE if changed
        let rpeChanged = selectedRPE != initialRPE
        if rpeChanged {
            let rpeOk = await onSaveRPE(selectedRPE)
            if !rpeOk {
                isSaving = false
                showError = true
                return
            }
        }

        // Save notes
        let notesOk = await onSaveNotes(notes)
        isSaving = false
        if notesOk {
            dismiss()
        } else {
            showError = true
        }
    }
}

// MARK: - ReflectionFlowChips (internal, mirrors RecapDiaryEditorView's FlowChips)

private struct ReflectionFlowChips: View {
    let items: [(label: String, icon: String)]
    let onTap: ((label: String, icon: String)) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { col in
                        let idx = row * 4 + col
                        if idx < items.count {
                            chip(items[idx])
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chip(_ p: (label: String, icon: String)) -> some View {
        Button {
            onTap(p)
        } label: {
            HStack(spacing: 5) {
                Text(p.icon).font(.system(size: 12))
                Text(p.label).font(AppFont.micro())
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(UIColor.separator).opacity(0.4), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
