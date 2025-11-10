import SwiftUI

@MainActor
class HeartRateSetupViewModel: ObservableObject {
    @Published var maxHeartRate = 190 // 預設最大心率
    @Published var restingHeartRate = 60 // 預設靜息心率
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToPersonalBest = false

    let targetDistance: Double // 從 OnboardingView 傳入的目標賽事距離

    init(targetDistance: Double) {
        self.targetDistance = targetDistance
        // 從 UserPreferenceManager 載入已有的心率資料
        if let savedMaxHR = UserPreferenceManager.shared.maxHeartRate {
            maxHeartRate = savedMaxHR
        }
        if let savedRestingHR = UserPreferenceManager.shared.restingHeartRate {
            restingHeartRate = savedRestingHR
        }
    }

    func saveHeartRate() async {
        // 驗證輸入值
        if maxHeartRate <= restingHeartRate {
            error = NSLocalizedString("hr_zone.max_greater_than_resting", comment: "Max HR must be greater than resting HR")
            return
        }

        if maxHeartRate > 250 || maxHeartRate < 100 {
            error = NSLocalizedString("hr_zone.max_hr_range", comment: "Max HR must be between 100-250")
            return
        }

        if restingHeartRate < 30 || restingHeartRate > 120 {
            error = NSLocalizedString("hr_zone.resting_hr_range", comment: "Resting HR must be between 30-120")
            return
        }

        isLoading = true
        error = nil

        do {
            // 更新本地資料
            UserPreferenceManager.shared.updateHeartRateData(
                maxHR: maxHeartRate,
                restingHR: restingHeartRate
            )

            // 發送到後端 API
            let userData = [
                "max_hr": maxHeartRate,
                "relaxing_hr": restingHeartRate
            ] as [String : Any]

            try await UserService.shared.updateUserData(userData)
            print("✅ 心率資料已保存")

            isLoading = false
            navigateToPersonalBest = true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func skipHeartRate() {
        // 跳過心率設定，使用預設值
        navigateToPersonalBest = true
    }
}

struct HeartRateSetupView: View {
    @StateObject private var viewModel: HeartRateSetupViewModel
    @Environment(\.dismiss) private var dismiss

    init(targetDistance: Double) {
        _viewModel = StateObject(wrappedValue: HeartRateSetupViewModel(targetDistance: targetDistance))
    }

    var body: some View {
        ZStack {
            Form {
                Section(
                    header: Text(NSLocalizedString("onboarding.heart_rate_title", comment: "Heart Rate Settings"))
                        .padding(.top, 10),
                    footer: Text(NSLocalizedString("onboarding.heart_rate_description", comment: "Setting your heart rate zones helps us create a more personalized training plan"))
                ) {
                    Text(NSLocalizedString("onboarding.heart_rate_intro", comment: "Please set your maximum and resting heart rate"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                }

                Section(header: Text(NSLocalizedString("hr_zone.max_hr", comment: "Max Heart Rate"))) {
                    HStack {
                        Spacer()
                        Picker("", selection: $viewModel.maxHeartRate) {
                            ForEach(100...250, id: \.self) { value in
                                Text("\(value)")
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)

                        Text("bpm")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("hr_zone.max_hr_info_title", comment: "What is Max Heart Rate?"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("hr_zone.max_hr_info_message", comment: "The highest heart rate you can achieve during maximum physical exertion"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text(NSLocalizedString("hr_zone.resting_hr", comment: "Resting Heart Rate"))) {
                    HStack {
                        Spacer()
                        Picker("", selection: $viewModel.restingHeartRate) {
                            ForEach(30...120, id: \.self) { value in
                                Text("\(value)")
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)

                        Text("bpm")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("hr_zone.resting_hr_info_title", comment: "What is Resting Heart Rate?"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("hr_zone.resting_hr_info_message", comment: "Your heart rate when completely at rest, best measured first thing in the morning"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }

            // 隱藏導航用的 NavigationLink
            NavigationLink(
                destination: PersonalBestView(targetDistance: viewModel.targetDistance)
                    .navigationBarBackButtonHidden(true),
                isActive: $viewModel.navigateToPersonalBest
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle(NSLocalizedString("onboarding.heart_rate_title", comment: "Heart Rate Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.back", comment: "Back"))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.saveHeartRate()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(NSLocalizedString("onboarding.next", comment: "Next"))
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    viewModel.skipHeartRate()
                }) {
                    Text(NSLocalizedString("onboarding.skip_heart_rate", comment: "Skip (Use Default Values)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct HeartRateSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HeartRateSetupView(targetDistance: 42.195)
        }
    }
}
