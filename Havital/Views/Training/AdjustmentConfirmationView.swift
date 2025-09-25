import SwiftUI

struct AdjustmentConfirmationView: View {
    @State private var adjustmentItems: [EditableAdjustmentItem]
    @State private var newAdjustmentText: String = ""
    @State private var isUpdating: Bool = false

    let summaryId: String
    let onConfirm: ([AdjustmentItem]) -> Void
    let onCancel: () -> Void

    init(initialItems: [AdjustmentItem], summaryId: String, onConfirm: @escaping ([AdjustmentItem]) -> Void, onCancel: @escaping () -> Void) {
        self._adjustmentItems = State(initialValue: initialItems.map { EditableAdjustmentItem(from: $0) })
        self.summaryId = summaryId
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection

                ScrollView {
                    VStack(spacing: 16) {
                        adjustmentItemsList

                        addNewAdjustmentSection
                    }
                    .padding()
                }

                actionButtons
            }
            .navigationTitle("調整建議確認")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("取消") { onCancel() },
                trailing: Button("完成") { confirmAdjustments() }
                    .disabled(isUpdating)
            )
        }
        .disabled(isUpdating)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("下週課表調整建議")
                .font(.title2)
                .fontWeight(.bold)

            Text("請選擇要應用的調整建議。您也可以新增自己的訓練需求。")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6))
    }

    private var adjustmentItemsList: some View {
        VStack(spacing: 12) {
            if adjustmentItems.isEmpty {
                Text("目前沒有調整建議")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(adjustmentItems.indices, id: \.self) { index in
                    adjustmentItemRow(at: index)
                }
            }
        }
    }

    private func adjustmentItemRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    adjustmentItems[index].apply.toggle()
                }) {
                    Image(systemName: adjustmentItems[index].apply ? "checkmark.square.fill" : "square")
                        .foregroundColor(adjustmentItems[index].apply ? .blue : .gray)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if adjustmentItems[index].isEditing {
                        TextField("調整建議內容", text: $adjustmentItems[index].content)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(adjustmentItems[index].content)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button(action: {
                    adjustmentItems[index].isEditing.toggle()
                }) {
                    Image(systemName: adjustmentItems[index].isEditing ? "checkmark" : "pencil")
                        .foregroundColor(.blue)
                }

                Button(action: {
                    adjustmentItems.remove(at: index)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(adjustmentItems[index].apply ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private var addNewAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新增自訂調整")
                .font(.headline)

            VStack(spacing: 8) {
                TextField("輸入您的訓練需求或調整建議...", text: $newAdjustmentText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)

                Button("新增調整建議") {
                    addNewAdjustment()
                }
                .disabled(newAdjustmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(maxWidth: .infinity)
                .padding()
                .background(newAdjustmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("忽略所有調整") {
                let emptyItems: [AdjustmentItem] = []
                onConfirm(emptyItems)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.3))
            .foregroundColor(.black)
            .cornerRadius(8)

            Button("應用選擇的調整") {
                confirmAdjustments()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(isUpdating)
        }
        .padding()
    }

    private func addNewAdjustment() {
        let trimmedText = newAdjustmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let newItem = EditableAdjustmentItem(content: trimmedText, apply: true)
        adjustmentItems.append(newItem)
        newAdjustmentText = ""
    }

    private func confirmAdjustments() {
        let selectedItems = adjustmentItems
            .filter { $0.apply }
            .map { AdjustmentItem(content: $0.content, apply: $0.apply) }

        onConfirm(selectedItems)
    }
}

// MARK: - Helper Models
struct EditableAdjustmentItem: Identifiable {
    let id = UUID()
    var content: String
    var apply: Bool
    var isEditing: Bool = false

    init(content: String, apply: Bool) {
        self.content = content
        self.apply = apply
    }

    init(from item: AdjustmentItem) {
        self.content = item.content
        self.apply = item.apply
    }
}

// MARK: - Preview
struct AdjustmentConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        AdjustmentConfirmationView(
            initialItems: [
                AdjustmentItem(content: "建議安排休息週以促進恢復", apply: true),
                AdjustmentItem(content: "增加恢復跑時間", apply: false),
                AdjustmentItem(content: "減少間歇訓練強度", apply: true)
            ],
            summaryId: "week_3_summary",
            onConfirm: { items in
                print("確認調整: \(items)")
            },
            onCancel: {
                print("取消調整")
            }
        )
    }
}