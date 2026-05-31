//
//  TrainingWeeksSetupView.swift
//  Havital
//
//  Training Weeks selection onboarding step
//  For non-race targets (beginner, maintenance)
//  Refactored to use shared OnboardingFeatureViewModel via @EnvironmentObject
//

import SwiftUI

struct TrainingWeeksSetupView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    private let minWeeks = 4
    private let maxWeeks = 24
    private let recommendedWeeks: [String: Int] = [
        "beginner": 8,
        "maintenance": 12
    ]

    private let quickOptions = [4, 8, 12, 16, 20, 24]

    // Beginner distance options: 5K → [6,8,10], 10K → [8,10,12]
    private let beginnerDistanceOptions: [Int: [Int]] = [
        5: [6, 8, 10],
        10: [8, 10, 12]
    ]
    private let beginnerDistanceRange: [Int: ClosedRange<Int>] = [
        5: 6...10,
        10: 8...12
    ]

    @State private var selectedWeeks: Int = 12
    @State private var showCustomPicker = false
    @State private var selectedBeginnerDistanceKm: Int = 5

    private var isBeginner: Bool {
        coordinator.selectedTargetTypeId == "beginner"
    }

    private var currentBeginnerWeekOptions: [Int] {
        beginnerDistanceOptions[selectedBeginnerDistanceKm] ?? [6, 8, 10]
    }

    private var currentBeginnerRange: ClosedRange<Int> {
        beginnerDistanceRange[selectedBeginnerDistanceKm] ?? 6...10
    }

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.continue", comment: "Continue"),
            ctaEnabled: true,
            isLoading: false,
            skipTitle: nil,
            ctaAccessibilityId: "TrainingWeeks_NextButton",
            ctaAction: {
                saveAndNavigate()
            },
            skipAction: nil
        ) {
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
                .padding(.top, 20)

                // Beginner-only: 5K/10K distance selector
                if isBeginner {
                    beginnerDistanceSelector
                }

                selectedWeeksCard

                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("onboarding.quick_options", comment: "Quick Options"))
                        .font(AppFont.headline())

                    if isBeginner {
                        beginnerQuickOptionsGrid
                    } else {
                        quickOptionsGrid
                    }
                }

                if !isBeginner {
                    customPickerSection
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("TrainingWeeks_Screen")
        .navigationTitle(NSLocalizedString("onboarding.training_weeks_nav_title", comment: "Training Duration"))
        .onAppear {
            if isBeginner {
                // Initialize beginner distance from coordinator if already set, else default to 5K
                let storedKm = coordinator.intendedRaceDistanceKm
                if storedKm == 10 {
                    selectedBeginnerDistanceKm = 10
                } else {
                    selectedBeginnerDistanceKm = 5
                }
                // Set default weeks for the selected distance (8 is valid for both 5K and 10K)
                let options = beginnerDistanceOptions[selectedBeginnerDistanceKm] ?? [6, 8, 10]
                selectedWeeks = options.contains(8) ? 8 : (options.first ?? 8)
                coordinator.intendedRaceDistanceKm = selectedBeginnerDistanceKm
            } else if let targetTypeId = coordinator.selectedTargetTypeId,
               let recommended = recommendedWeeks[targetTypeId] {
                selectedWeeks = recommended
            } else if let existingWeeks = coordinator.trainingWeeks {
                selectedWeeks = existingWeeks
            }
        }
    }

    // MARK: - Beginner Distance Selector

    @ViewBuilder
    private var beginnerDistanceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("onboarding.beginner_target_distance", comment: "Target Distance"))
                .font(AppFont.headline())

            HStack(spacing: 12) {
                ForEach([5, 10], id: \.self) { km in
                    distanceButton(km: km)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func distanceButton(km: Int) -> some View {
        let isSelected = selectedBeginnerDistanceKm == km
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedBeginnerDistanceKm = km
                coordinator.intendedRaceDistanceKm = km
                // Clamp selectedWeeks into the new distance's valid range
                let options = beginnerDistanceOptions[km] ?? [6, 8, 10]
                if !options.contains(selectedWeeks) {
                    // Snap to nearest valid option
                    selectedWeeks = options.min(by: { abs($0 - selectedWeeks) < abs($1 - selectedWeeks) }) ?? options[1]
                }
            }
        }) {
            Text("\(km)K")
                .font(AppFont.body())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .accentColor : .primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("BeginnerDistance_\(km)K")
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
                            .font(AppFont.systemScaled(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.accentColor)

                        Text(NSLocalizedString("common.weeks", comment: "weeks"))
                            .font(AppFont.title3())
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isRecommendedWeeks {
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

            infoMessage
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var isRecommendedWeeks: Bool {
        if isBeginner {
            return selectedWeeks == 8
        }
        return coordinator.selectedTargetTypeId.flatMap { recommendedWeeks[$0] } == selectedWeeks
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

    // MARK: - Beginner Quick Options Grid (3 buttons only)
    @ViewBuilder
    private var beginnerQuickOptionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(currentBeginnerWeekOptions, id: \.self) { weeks in
                quickOptionButton(weeks: weeks)
            }
        }
    }

    // MARK: - Quick Options Grid (maintenance)
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
    }

    @ViewBuilder
    private func quickOptionButton(weeks: Int) -> some View {
        let isSelected = selectedWeeks == weeks
        let isRecommended: Bool = {
            if isBeginner { return weeks == 8 }
            return coordinator.selectedTargetTypeId.flatMap { recommendedWeeks[$0] } == weeks
        }()

        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedWeeks = weeks
                showCustomPicker = false
            }
        }) {
            VStack(spacing: 4) {
                Text("\(weeks)")
                    .font(AppFont.systemScaled(size: 24, weight: .semibold, design: .rounded))
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
        .accessibilityIdentifier("TrainingWeeks_\(weeks)")
    }

    // MARK: - Custom Picker Section (maintenance only)
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
    }

    // MARK: - Actions
    private func saveAndNavigate() {
        coordinator.trainingWeeks = selectedWeeks
        if isBeginner {
            // Ensure intendedRaceDistanceKm is set (may already be set via distance selector)
            coordinator.intendedRaceDistanceKm = selectedBeginnerDistanceKm
        }
        Logger.debug("[TrainingWeeksSetupView] Selected \(selectedWeeks) weeks for \(coordinator.selectedTargetTypeId ?? "unknown"), distance: \(coordinator.intendedRaceDistanceKm.map { "\($0)K" } ?? "nil")")
        if coordinator.selectedTargetTypeId == "maintenance" {
            coordinator.navigate(to: .maintenanceRaceDistance)
        } else {
            coordinator.navigate(to: .trainingDays)
        }
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
