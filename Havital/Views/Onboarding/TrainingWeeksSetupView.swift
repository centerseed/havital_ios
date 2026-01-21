//
//  TrainingWeeksSetupView.swift
//  Havital
//
//  Training Weeks selection onboarding step
//  For non-race targets (beginner, maintenance)
//

import SwiftUI

struct TrainingWeeksSetupView: View {
    @StateObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    init() {
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    // 訓練週數範圍
    private let minWeeks = 4
    private let maxWeeks = 24
    private let recommendedWeeks: [String: Int] = [
        "beginner": 8,
        "maintenance": 12
    ]

    // 週數選項（常用週數）
    private let quickOptions = [4, 8, 12, 16, 20, 24]

    @State private var selectedWeeks: Int = 12
    @State private var showCustomPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title and description
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("onboarding.training_weeks_title", comment: "Training Duration"))
                            .font(AppFont.title2())
                            .fontWeight(.bold)

                        Text(NSLocalizedString("onboarding.training_weeks_description", comment: "How many weeks do you plan to train?"))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Selected weeks display
                    selectedWeeksCard

                    // Quick options
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("onboarding.quick_options", comment: "Quick Options"))
                            .font(AppFont.headline())
                            .padding(.horizontal)

                        quickOptionsGrid
                    }

                    // Custom picker toggle
                    customPickerSection

                    // Bottom padding
                    Color.clear.frame(height: 100)
                }
            }

            // Bottom button
            bottomButton
        }
        .navigationTitle(NSLocalizedString("onboarding.training_weeks_nav_title", comment: "Training Duration"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 根據目標類型設定推薦週數
            if let targetTypeId = coordinator.selectedTargetTypeId,
               let recommended = recommendedWeeks[targetTypeId] {
                selectedWeeks = recommended
            } else if let existingWeeks = coordinator.trainingWeeks {
                selectedWeeks = existingWeeks
            }
        }
    }

    // MARK: - Selected Weeks Card
    @ViewBuilder
    private var selectedWeeksCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("onboarding.selected_duration", comment: "Selected Duration"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(selectedWeeks)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.accentColor)

                        Text(NSLocalizedString("common.weeks", comment: "weeks"))
                            .font(AppFont.title3())
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Recommended badge
                if let targetTypeId = coordinator.selectedTargetTypeId,
                   let recommended = recommendedWeeks[targetTypeId],
                   selectedWeeks == recommended {
                    Text(NSLocalizedString("onboarding.recommended", comment: "Recommended"))
                        .font(AppFont.captionSmall())
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(12)
                }
            }

            // Info message
            infoMessage
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Info Message
    @ViewBuilder
    private var infoMessage: some View {
        if selectedWeeks < 8 {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(NSLocalizedString("onboarding.short_duration_warning", comment: "Short training duration may limit progress"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        } else if selectedWeeks >= 16 {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(NSLocalizedString("onboarding.long_duration_benefit", comment: "Longer training allows gradual progression"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Quick Options Grid
    @ViewBuilder
    private var quickOptionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(quickOptions, id: \.self) { weeks in
                quickOptionButton(weeks: weeks)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func quickOptionButton(weeks: Int) -> some View {
        let isSelected = selectedWeeks == weeks
        let isRecommended = coordinator.selectedTargetTypeId.flatMap { recommendedWeeks[$0] } == weeks

        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedWeeks = weeks
                showCustomPicker = false
            }
        }) {
            VStack(spacing: 4) {
                Text("\(weeks)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .accentColor : .primary)

                Text(NSLocalizedString("common.weeks", comment: "weeks"))
                    .font(AppFont.captionSmall())
                    .foregroundColor(.secondary)

                if isRecommended {
                    Text("★")
                        .font(AppFont.caption())
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Custom Picker Section
    @ViewBuilder
    private var customPickerSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                withAnimation {
                    showCustomPicker.toggle()
                }
            }) {
                HStack {
                    Text(NSLocalizedString("onboarding.custom_weeks", comment: "Custom Weeks"))
                        .font(AppFont.body())
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: showCustomPicker ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            if showCustomPicker {
                VStack(spacing: 16) {
                    Picker(NSLocalizedString("onboarding.select_weeks", comment: "Select Weeks"), selection: $selectedWeeks) {
                        ForEach(minWeeks...maxWeeks, id: \.self) { week in
                            Text("\(week) \(NSLocalizedString("common.weeks", comment: "weeks"))").tag(week)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Bottom Button
    @ViewBuilder
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()

            Button(action: {
                saveAndNavigate()
            }) {
                Text(NSLocalizedString("onboarding.continue", comment: "Continue"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions
    private func saveAndNavigate() {
        // 保存選擇的週數到 coordinator
        coordinator.trainingWeeks = selectedWeeks
        Logger.debug("[TrainingWeeksSetupView] Selected \(selectedWeeks) weeks for \(coordinator.selectedTargetTypeId ?? "unknown")")

        // ⭐ 方法論已經在前面選擇過了（如果有多個的話）
        // 這裡直接導航到訓練日設定
        coordinator.navigate(to: .trainingDays)
    }
}

// MARK: - Preview
struct TrainingWeeksSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingWeeksSetupView()
        }
    }
}
