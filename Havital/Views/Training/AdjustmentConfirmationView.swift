import SwiftUI

struct AdjustmentConfirmationView: View {
    @State private var adjustmentItems: [EditableAdjustmentItem]
    @State private var newAdjustmentText: String = ""
    @State private var isUpdating: Bool = false
    @State private var isAddingAdjustment: Bool = false

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
        GeometryReader { geometry in
            NavigationView {
                VStack(spacing: 0) {
                    headerSection

                    ScrollView {
                        VStack(spacing: 16) {
                            adjustmentItemsList

                            addNewAdjustmentSection

                            // 在 ScrollView 內部添加主要操作按鈕
                            VStack(spacing: 16) {
                                Button {
                                    print("產生本週課表 button tapped")
                                    confirmAdjustments()
                                } label: {
                                    HStack {
                                        if isUpdating {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text(NSLocalizedString("adjustment.generate_weekly_plan", comment: "Generate this week's training plan button"))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .disabled(isUpdating)
                                .background(isUpdating ? Color.gray.opacity(0.5) : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding(.top, 20)
                        }
                        .padding()
                    }
                }
                .navigationTitle(NSLocalizedString("adjustment.title", comment: "Adjustment confirmation screen title"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("adjustment.header_title", comment: "Header title for adjustment suggestions"))
                .font(.headline)
                .fontWeight(.bold)

            Text(adjustmentItems.isEmpty ?
                 NSLocalizedString("adjustment.description_no_items", comment: "Description when no adjustment items") :
                 NSLocalizedString("adjustment.description_with_items", comment: "Description when adjustment items exist"))
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6))
    }

    private var adjustmentItemsList: some View {
        VStack(spacing: 12) {
            if adjustmentItems.isEmpty {
                Text(NSLocalizedString("adjustment.no_suggestions", comment: "No adjustment suggestions available"))
                    .font(.callout)
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
                        TextField(NSLocalizedString("adjustment.content_placeholder", comment: "Placeholder for adjustment content"), text: $adjustmentItems[index].content, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...6)
                    } else {
                        Text(adjustmentItems[index].content)
                            .font(.callout)
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
            Text(NSLocalizedString("adjustment.add_custom_title", comment: "Add custom adjustment title"))
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                TextField(NSLocalizedString("adjustment.text_field_placeholder", comment: "Placeholder for new adjustment text field"), text: $newAdjustmentText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)

                Button(action: {
                    print("新增調整建議 button tapped")
                    addNewAdjustment()
                }) {
                    HStack {
                        if isAddingAdjustment {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(NSLocalizedString("adjustment.add_button", comment: "Add adjustment button"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .disabled(newAdjustmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating || isAddingAdjustment)
                .background((newAdjustmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating || isAddingAdjustment) ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .contentShape(Rectangle()) // 確保整個按鈕區域都可點擊
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }


    private func addNewAdjustment() {
        let trimmedText = newAdjustmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("addNewAdjustment called with text: '\(trimmedText)'")
        guard !trimmedText.isEmpty else {
            print("Text is empty, returning early")
            return
        }

        // 如果需要顯示 loading 指示器，可以短暫設置
        isAddingAdjustment = true

        // 延遲執行以顯示 loading 效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let newItem = EditableAdjustmentItem(content: trimmedText, apply: true)
            self.adjustmentItems.append(newItem)
            print("Added new item, total items: \(self.adjustmentItems.count)")
            self.newAdjustmentText = ""
            self.isAddingAdjustment = false
        }
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