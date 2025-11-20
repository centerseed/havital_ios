import SwiftUI

// MARK: - Goal Type Enum
enum GoalType {
    case specificRace  // 有具體賽事目標
    case beginner5k    // 新手，想先能跑5km
}

// MARK: - ViewModel
@MainActor
class GoalTypeSelectionViewModel: ObservableObject {
    @Published var selectedGoalType: GoalType?
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToRaceSetup = false
    @Published var navigateToTrainingDays = false

    /// 創建新手 5km 目標
    func createBeginner5kGoal() async -> Bool {
        isLoading = true
        error = nil

        do {
            // 創建一個 4 週的 5km 訓練目標（約一個月）
            let raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date()) ?? Date()
            let target = Target(
                id: UUID().uuidString,
                type: "race_run",
                name: NSLocalizedString("onboarding.beginner_5k_goal", comment: "能跑 5 公里"),
                distanceKm: 5,
                targetTime: 30 * 60, // 預設目標 30 分鐘
                targetPace: "6:00", // 配速 6:00/km
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: 4  // 改為 4 週
            )

            try await UserService.shared.createTarget(target)
            print("✅ 新手 5km 目標創建成功")

            // 保存新手計劃標記，供後續頁面使用
            UserDefaults.standard.set(true, forKey: "onboarding_isBeginner5kPlan")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }
}

// MARK: - View
struct GoalTypeSelectionView: View {
    @StateObject private var viewModel = GoalTypeSelectionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 主要內容區域
            ScrollView {
                VStack(spacing: 24) {
                    // 標題和說明
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("onboarding.goal_type_title", comment: "選擇你的訓練目標"))
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(NSLocalizedString("onboarding.goal_type_description", comment: "根據你的跑步經驗和目標，我們會為你制定合適的訓練計劃"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // 選項 1: 有具體賽事目標
                    GoalTypeCard(
                        icon: "flag.checkered",
                        title: NSLocalizedString("onboarding.goal_type_specific_race", comment: "我有具體賽事目標"),
                        description: NSLocalizedString("onboarding.goal_type_specific_race_desc", comment: "設定賽事日期、距離和目標時間"),
                        isSelected: viewModel.selectedGoalType == .specificRace
                    ) {
                        viewModel.selectedGoalType = .specificRace
                    }
                    .padding(.horizontal)

                    // 選項 2: 完成第一個五公里
                    GoalTypeCard(
                        icon: "figure.run",
                        title: NSLocalizedString("onboarding.goal_type_beginner_5k", comment: "完成第一個五公里，感受跑步樂趣"),
                        description: NSLocalizedString("onboarding.goal_type_beginner_5k_desc", comment: "12 週訓練計劃，帶你達成 5 公里目標"),
                        isSelected: viewModel.selectedGoalType == .beginner5k
                    ) {
                        viewModel.selectedGoalType = .beginner5k
                    }
                    .padding(.horizontal)

                    // 錯誤訊息
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // 留出底部按鈕空間
            }

            // 底部按鈕
            VStack(spacing: 0) {
                Divider()

                Button(action: {
                    handleNextStep()
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("onboarding.next_step", comment: "下一步"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.selectedGoalType == nil || viewModel.isLoading)
                .padding()
                .background(viewModel.selectedGoalType == nil ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))

            // 導航到賽事設定頁面（使用現有的 OnboardingView）
            NavigationLink(
                destination: OnboardingView()
                    .navigationBarBackButtonHidden(true),
                isActive: $viewModel.navigateToRaceSetup
            ) {
                EmptyView()
            }
            .hidden()

            // 導航到訓練日數選擇頁面
            NavigationLink(
                destination: TrainingDaysSetupView()
                    .navigationBarBackButtonHidden(true),
                isActive: $viewModel.navigateToTrainingDays
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle(NSLocalizedString("onboarding.goal_type_nav_title", comment: "訓練目標"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.back", comment: "返回"))
                }
            }
        }
    }

    // MARK: - Private Methods
    private func handleNextStep() {
        guard let goalType = viewModel.selectedGoalType else { return }

        switch goalType {
        case .specificRace:
            // 導航到詳細賽事設定頁面
            viewModel.navigateToRaceSetup = true

        case .beginner5k:
            // 創建新手 5km 目標，然後導航到訓練日數選擇
            Task {
                if await viewModel.createBeginner5kGoal() {
                    viewModel.navigateToTrainingDays = true
                }
            }
        }
    }
}

// MARK: - Goal Type Card Component
struct GoalTypeCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 圖標
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 50)

                // 文字內容
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // 選擇指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct GoalTypeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GoalTypeSelectionView()
        }
    }
}
