//
//  PersonalBestView.swift
//  Havital
//
//  Personal Best onboarding step
//  Refactored to use OnboardingFeatureViewModel (Clean Architecture)
//

import SwiftUI

struct PersonalBestView: View {
    @StateObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    // Clean Architecture: Use AuthenticationViewModel from environment
    @EnvironmentObject private var authViewModel: AuthenticationViewModel

    let targetDistance: Double

    init(targetDistance: Double) {
        self.targetDistance = targetDistance
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    var body: some View {
        ZStack {
            Form {
                Section(
                    header: Text(NSLocalizedString("onboarding.personal_best_title", comment: "Personal Best Title")).padding(.top, 10),
                    footer: Text(NSLocalizedString("onboarding.personal_best_description", comment: "Personal Best Description"))
                ) {
                    Toggle(NSLocalizedString("onboarding.has_personal_best", comment: "Has Personal Best"), isOn: $viewModel.hasPersonalBest)

                    // Show quick select list if user has existing PBs
                    if viewModel.hasPersonalBest && !viewModel.availablePersonalBests.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("onboarding.select_existing_pb", comment: "Or select existing personal best"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.availablePersonalBests.keys.sorted { a, b in
                                        Double(a) ?? 0 > Double(b) ?? 0
                                    }, id: \.self) { distanceKey in
                                        if let records = viewModel.availablePersonalBests[distanceKey],
                                           let bestRecord = records.first {
                                            Button(action: {
                                                viewModel.selectPersonalBest(distanceKey: distanceKey)
                                            }) {
                                                VStack(spacing: 4) {
                                                    Text("\(distanceKey)km")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                    Text(bestRecord.formattedTime())
                                                        .font(.caption2)
                                                }
                                                .frame(minWidth: 70)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(viewModel.selectedPersonalBestKey == distanceKey ? Color.accentColor : Color(.systemGray6))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(viewModel.selectedPersonalBestKey == distanceKey ? Color.accentColor : Color(.systemGray3), lineWidth: 1.5)
                                                )
                                                .foregroundColor(viewModel.selectedPersonalBestKey == distanceKey ? .white : .primary)
                                                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                if viewModel.hasPersonalBest {
                    Section(header: Text(NSLocalizedString("onboarding.personal_best_details", comment: "Personal Best Details"))) {
                        Text(NSLocalizedString("onboarding.select_distance_time", comment: "Select Distance and Time"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)

                        Picker(NSLocalizedString("onboarding.distance_selection", comment: "Distance Selection"), selection: $viewModel.selectedPBDistance) {
                            ForEach(Array(viewModel.availablePBDistances.keys.sorted(by: { Double($0)! < Double($1)! })), id: \.self) { key in
                                Text(viewModel.availablePBDistances[key] ?? key)
                                    .tag(key)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack {
                            Picker(NSLocalizedString("onboarding.time_hours", comment: "Hours"), selection: $viewModel.personalBestHours) {
                                ForEach(0...6, id: \.self) { hour in
                                    Text("\(hour)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text(NSLocalizedString("onboarding.time_hours", comment: "Hours"))

                            Picker(NSLocalizedString("onboarding.time_minutes", comment: "Minutes"), selection: $viewModel.personalBestMinutes) {
                                ForEach(0...59, id: \.self) { minute in
                                    Text("\(minute)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text(NSLocalizedString("onboarding.time_minutes", comment: "Minutes"))

                            Picker(NSLocalizedString("onboarding.time_seconds", comment: "Seconds"), selection: $viewModel.personalBestSeconds) {
                                ForEach(0...59, id: \.self) { second in
                                    Text("\(second)")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            Text(NSLocalizedString("onboarding.time_seconds", comment: "Seconds"))
                        }
                        .padding(.vertical, 8)

                        if !viewModel.currentPace.isEmpty {
                            HStack {
                                Text(NSLocalizedString("onboarding.average_pace_calculation", comment: "Average Pace"))
                                Spacer()
                                Text("\(viewModel.currentPace) \(NSLocalizedString("onboarding.per_kilometer", comment: "Per Kilometer"))")
                            }
                            .foregroundColor(.secondary)
                        } else if viewModel.hasPersonalBest && totalTimeInSeconds == 0 {
                            Text(NSLocalizedString("onboarding.enter_valid_time", comment: "Enter Valid Time"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Section(header: Text(NSLocalizedString("onboarding.skip_personal_best", comment: "Skip Personal Best"))) {
                        Text(NSLocalizedString("onboarding.skip_personal_best_message", comment: "Skip Personal Best Message"))
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
        }
        .navigationTitle(NSLocalizedString("onboarding.personal_best_title_nav", comment: "Personal Best"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if coordinator.isReonboarding && coordinator.navigationPath.isEmpty {
                    Button {
                        authViewModel.cancelReonboarding()
                    } label: {
                        Image(systemName: "xmark")
                    }
                } else if !coordinator.navigationPath.isEmpty {
                    Button {
                        coordinator.goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(NSLocalizedString("common.back", comment: "Back"))
                        }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        let success = await viewModel.updatePersonalBest()
                        if success {
                            coordinator.navigate(to: .weeklyDistance)
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("onboarding.next", comment: "Next"))
                        }
                    }
                }
                .disabled(viewModel.isLoading || (viewModel.hasPersonalBest && totalTimeInSeconds == 0))
            }
        }
        .task {
            // Set target distance and load existing PBs
            viewModel.targetDistance = targetDistance
            if targetDistance <= 5 {
                viewModel.selectedPBDistance = "3"
            } else {
                viewModel.selectedPBDistance = "5"
            }
            await viewModel.loadPersonalBests()
        }
    }

    // MARK: - Computed Properties

    private var totalTimeInSeconds: Int {
        viewModel.personalBestHours * 3600 + viewModel.personalBestMinutes * 60 + viewModel.personalBestSeconds
    }
}

struct PersonalBestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PersonalBestView(targetDistance: 21.0975)
        }
    }
}
