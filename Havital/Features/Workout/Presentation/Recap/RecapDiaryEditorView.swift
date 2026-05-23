import SwiftUI

// MARK: - RecapDiaryEditorView
//
// 訓練心得編輯器，對齊 Claude Design 的 DiaryEditorScreen（recap.jsx）：
//   context strip（哪次訓練 + RPE）＋ 主題引導 chip（點了自動帶起頭）＋ 大 textarea
//   ＋ 字數計 ＋「省略也算 / 只有你看得到」微提示。
// 取代先前過於簡單的純 TextEditor。

struct RecapDiaryEditorView: View {
    let workoutId: String
    let typeName: String?
    let distanceText: String
    let date: Date
    let rpe: Int?
    var initialNotes: String = ""
    let onSave: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var notes: String
    @State private var isSaving = false
    @FocusState private var focused: Bool

    private let maxChars = WorkoutConstants.maxTrainingNotesLength

    init(
        workoutId: String,
        typeName: String?,
        distanceText: String,
        date: Date,
        rpe: Int?,
        initialNotes: String = "",
        onSave: @escaping (String) async -> Bool
    ) {
        self.workoutId = workoutId
        self.typeName = typeName
        self.distanceText = distanceText
        self.date = date
        self.rpe = rpe
        self.initialNotes = initialNotes
        self.onSave = onSave
        _notes = State(initialValue: initialNotes)
    }

    private let prompts: [(label: String, icon: String)] = [
        ("配速", "🏃"), ("呼吸", "💨"), ("腿/腳", "🦵"), ("心率", "❤️"),
        ("補給", "💧"), ("比上次", "⏮"), ("後段", "🔚"), ("明天", "🌅")
    ]

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                contextStrip
                promptSection
                editorCard
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("訓練心得")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("儲存").fontWeight(.semibold) }
                    }
                    .disabled(isOverLimit || isSaving)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
            }
        }
    }

    // MARK: - Context strip

    private var contextStrip: some View {
        HStack(spacing: 10) {
            Circle().fill(PacerizColor.blue).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(typeName ?? "訓練") · \(distanceText)")
                    .font(AppFont.micro())
                    .foregroundColor(.primary)
                Text(dateText)
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            if let rpe = rpe {
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

    // MARK: - Prompts

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("可以從這裡開始 ↓")
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                Spacer()
                Text("點主題會自動帶起頭")
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 2)

            FlowChips(items: prompts) { p in insertPrompt(p.label) }
        }
    }

    private func insertPrompt(_ topic: String) {
        let sep = notes.isEmpty ? "" : (notes.hasSuffix("\n") ? "" : "\n")
        notes += "\(sep)\(topic)："
        focused = true
    }

    // MARK: - Editor

    private var editorCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("寫下這次訓練的感受⋯ 一句話也算。")
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
                    .frame(minHeight: 200, maxHeight: .infinity)
            }

            HStack {
                Text("這份心得只有你看得到")
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

    @MainActor
    private func save() async {
        guard !isOverLimit else { return }
        isSaving = true
        let ok = await onSave(notes)
        isSaving = false
        if ok { dismiss() }
    }
}

// MARK: - FlowChips（主題 chip 自動換行排列）

private struct FlowChips: View {
    let items: [(label: String, icon: String)]
    let onTap: ((label: String, icon: String)) -> Void

    var body: some View {
        // 8 個 chip 兩行排列：4 + 4。
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
