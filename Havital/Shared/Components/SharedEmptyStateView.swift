import SwiftUI

// MARK: - 共用空狀態視圖
/// 顯示無數據時的空狀態
/// 命名為 SharedEmptyStateView 避免衝突，遷移完成後可重命名
struct SharedEmptyStateView: View {

    // MARK: - Properties
    let message: String
    var title: String?
    var iconName: String = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    // MARK: - Initialization
    init(
        message: String,
        title: String? = nil,
        iconName: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.title = title
        self.iconName = iconName
        self.actionTitle = actionTitle
        self.action = action
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            // 圖示
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 8)

            VStack(spacing: 12) {
                // 標題（可選）
                if let title = title {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                // 說明文字
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }

            // 操作按鈕（可選）
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text(actionTitle)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 預設配置
extension SharedEmptyStateView {

    /// 無訓練計畫
    static func noTrainingPlan(action: @escaping () -> Void) -> SharedEmptyStateView {
        SharedEmptyStateView(
            message: NSLocalizedString("training.no_plan_message", comment: "You don't have a training plan yet"),
            title: NSLocalizedString("training.no_plan_title", comment: "No Training Plan"),
            iconName: "calendar.badge.plus",
            actionTitle: NSLocalizedString("training.create_plan", comment: "Create Plan"),
            action: action
        )
    }

    /// 無運動記錄
    static func noWorkouts() -> SharedEmptyStateView {
        SharedEmptyStateView(
            message: NSLocalizedString("workout.no_records_message", comment: "Start exercising to see your workout history"),
            title: NSLocalizedString("workout.no_records_title", comment: "No Workouts"),
            iconName: "figure.run"
        )
    }

    /// 無搜尋結果
    static func noSearchResults() -> SharedEmptyStateView {
        SharedEmptyStateView(
            message: NSLocalizedString("search.no_results_message", comment: "Try adjusting your search criteria"),
            title: NSLocalizedString("search.no_results_title", comment: "No Results"),
            iconName: "magnifyingglass"
        )
    }
}

// MARK: - Preview
#if DEBUG
struct SharedEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SharedEmptyStateView(
                message: "You don't have any data yet",
                title: "No Data"
            )
            .previewDisplayName("Basic")

            SharedEmptyStateView.noTrainingPlan {
                print("Create plan tapped")
            }
            .previewDisplayName("No Training Plan")

            SharedEmptyStateView.noWorkouts()
                .previewDisplayName("No Workouts")
        }
    }
}
#endif
