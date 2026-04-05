import SwiftUI

// MARK: - WeeklyPreviewCardV2
/// 主畫面的週訓練骨架摘要卡片
/// 點擊後開啟 Bottom Sheet 顯示未來四週骨架
struct WeeklyPreviewCardV2: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    @State private var showPreviewSheet = false

    var body: some View {
        let weekCount = viewModel.upcomingWeeks.count

        Button {
            showPreviewSheet = true
        } label: {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("週訓練骨架")
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("接下來 \(weekCount) 週 · 點擊查看")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPreviewSheet) {
            WeeklyPreviewSheetV2(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }
}
