import SwiftUI

/// 訓練心得顯示卡片
/// 顯示運動的訓練心得，提供編輯按鈕
struct TrainingNotesCard: View {
    let notes: String?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題和編輯按鈕
            HStack {
                Text(NSLocalizedString(L10n.WorkoutDetail.trainingNotesTitle, comment: ""))
                    .font(AppFont.headline())
                    .fontWeight(.semibold)

                Spacer()

                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: notes == nil || notes!.isEmpty ? "plus.circle" : "pencil")
                        Text(notes == nil || notes!.isEmpty ?
                            NSLocalizedString(L10n.WorkoutDetail.trainingNotesAdd, comment: "") :
                            NSLocalizedString(L10n.WorkoutDetail.trainingNotesEdit, comment: ""))
                    }
                    .font(AppFont.bodySmall())
                    .foregroundColor(.blue)
                }
            }

            // 心得內容或佔位符
            if let notes = notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFont.body())
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(NSLocalizedString(L10n.WorkoutDetail.trainingNotesPlaceholder, comment: ""))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview("有心得") {
    TrainingNotesCard(
        notes: "今天的訓練感覺非常好！配速控制得很穩定，心率也在合理範圍內。最後2公里加速時感覺有力，說明體能狀態不錯。下次可以嘗試稍微提高一點強度。",
        onEdit: {}
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("無心得") {
    TrainingNotesCard(
        notes: nil,
        onEdit: {}
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
