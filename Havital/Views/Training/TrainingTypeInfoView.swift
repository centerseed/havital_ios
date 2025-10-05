import SwiftUI

struct TrainingTypeInfoView: View {
    let trainingTypeInfo: TrainingTypeInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 標題區域
                    HStack(spacing: 12) {
                        Text(trainingTypeInfo.icon)
                            .font(.system(size: 40))

                        Text(trainingTypeInfo.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                    // 怎麼跑
                    InfoSection(
                        icon: "🌬️",
                        title: NSLocalizedString("training_type_info.how_to_run_title", comment: "怎麼跑"),
                        content: trainingTypeInfo.howToRun
                    )

                    // 為什麼要跑這種課
                    InfoSection(
                        icon: "💪",
                        title: NSLocalizedString("training_type_info.why_run_title", comment: "為什麼要跑這種課"),
                        content: trainingTypeInfo.whyRun
                    )

                    // 背後的訓練邏輯
                    InfoSection(
                        icon: "⚙️",
                        title: NSLocalizedString("training_type_info.logic_title", comment: "背後的訓練邏輯"),
                        content: trainingTypeInfo.logic
                    )

                    // 放在週課表的角色
                    InfoSection(
                        icon: "🔄",
                        title: NSLocalizedString("training_type_info.role_title", comment: "放在週課表的角色"),
                        content: trainingTypeInfo.role
                    )
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "關閉")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoSection: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.title3)

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
