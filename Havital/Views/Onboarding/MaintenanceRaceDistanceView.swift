import SwiftUI

struct MaintenanceRaceDistanceView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    @State private var selectedOption: RaceDistanceOption? = nil

    enum RaceDistanceOption: CaseIterable {
        case marathon, halfMarathon, tenK, fiveK, unsure

        var title: String {
            switch self {
            case .marathon:     return NSLocalizedString("onboarding.race_distance.marathon", comment: "全馬（42K）")
            case .halfMarathon: return NSLocalizedString("onboarding.race_distance.half_marathon", comment: "半馬（21K）")
            case .tenK:         return NSLocalizedString("onboarding.race_distance.10k", comment: "10K")
            case .fiveK:        return NSLocalizedString("onboarding.race_distance.5k", comment: "5K")
            case .unsure:       return NSLocalizedString("onboarding.race_distance.unsure", comment: "不確定（略過）")
            }
        }

        var distanceKm: Int? {
            switch self {
            case .marathon:     return 42
            case .halfMarathon: return 21
            case .tenK:         return 10
            case .fiveK:        return 5
            case .unsure:       return nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("onboarding.race_distance.title", comment: "你休賽季後預計參加的目標賽事？"))
                            .font(AppFont.title2())
                            .fontWeight(.bold)

                        Text(NSLocalizedString("onboarding.race_distance.subtitle", comment: "這將幫助我們設定合理的訓練里程碑"))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    VStack(spacing: 12) {
                        ForEach(RaceDistanceOption.allCases, id: \.self) { option in
                            Button(action: { selectedOption = option }) {
                                HStack {
                                    Text(option.title)
                                        .font(AppFont.body())
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedOption == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedOption == option
                                              ? Color.accentColor.opacity(0.1)
                                              : Color(UIColor.secondarySystemGroupedBackground))
                                )
                            }
                            .padding(.horizontal)
                        }
                    }

                    Color.clear.frame(height: 100)
                }
            }

            bottomButton
        }
        .navigationTitle(NSLocalizedString("onboarding.race_distance.nav_title", comment: "目標賽事"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: saveAndNavigate) {
                Text(NSLocalizedString("onboarding.continue", comment: "下一步"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityIdentifier("MaintenanceRaceDistance_NextButton")
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func saveAndNavigate() {
        coordinator.intendedRaceDistanceKm = selectedOption?.distanceKm
        coordinator.navigate(to: .trainingDays)
    }
}
