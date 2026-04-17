import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    @State private var showTimeWarning = false
    @State private var showDistanceTimeEditor = false
    @State private var hasLoadedRaces = false

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.next_step", comment: "Next Step"),
            ctaEnabled: !viewModel.isLoading,
            isLoading: viewModel.isLoading,
            skipTitle: nil,
            ctaAccessibilityId: "RaceSetup_SaveButton",
            ctaAction: {
                Task {
                    if await viewModel.createRaceTarget() {
                        handleNavigationAfterTargetCreation()
                    }
                }
            },
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: OnboardingLayout.sectionSpacing) {
                primaryGoalConfigurationSection

                if viewModel.isRaceAPIAvailable || !viewModel.availableTargets.isEmpty {
                    sourceOptionsSection
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 8)
            .accessibilityIdentifier(raceSetupModeIdentifier)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("RaceSetup_Screen")
        .navigationTitle(NSLocalizedString("onboarding.set_training_goal", comment: "Set Training Goal"))
        .alert(NSLocalizedString("start_stage.time_too_short_title", comment: "時間較為緊迫"),
               isPresented: $showTimeWarning) {
            Button(NSLocalizedString("common.ok", comment: "確定"), role: .cancel) {
                showTimeWarning = false
            }
        } message: {
            Text(NSLocalizedString("start_stage.time_too_short_message",
                                  comment: "距離賽事不足 2 週，可能無法達到預期的訓練效果。建議選擇更晚的賽事日期。"))
        }
        .sheet(isPresented: $showDistanceTimeEditor) {
            RaceDistanceTimeEditorSheet(
                selectedDistance: $viewModel.selectedDistance,
                targetHours: $viewModel.targetHours,
                targetMinutes: $viewModel.targetMinutes,
                availableDistances: viewModel.availableDistances,
                isDistanceEditable: !isCatalogRaceSelected
            )
        }
        .task {
            if !hasLoadedRaces {
                hasLoadedRaces = true
                await viewModel.loadCuratedRaces()
            }
            await viewModel.loadAvailableTargets()
        }
    }

    private var raceSetupModeIdentifier: String {
        if viewModel.selectedRaceEvent != nil {
            return "RaceSetup_Mode_SelectedRace"
        }
        if viewModel.isRaceAPIAvailable {
            return "RaceSetup_Mode_DatabaseOrManual"
        }
        return "RaceSetup_Mode_ManualOnly"
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(AppFont.systemScaled(size: 13))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )

            Text(title)
                .font(AppFont.body())
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }

    private var primaryGoalConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(NSLocalizedString("onboarding.your_running_goal", comment: "Your Running Goal"),
                          systemImage: "flag.checkered")

            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    goalNameSourceSection

                    scheduleRowsSection

                    if let selectedRace = viewModel.selectedRaceEvent,
                       selectedRace.isTimeTight {
                        InlineWarningBanner(
                            title: NSLocalizedString("onboarding.tight_schedule_title", comment: "時間較緊迫"),
                            message: NSLocalizedString("onboarding.tight_schedule_message",
                                                       comment: "距離賽事不足 4 週，系統會根據可用時間自動調整訓練計畫。")
                        )
                    }

                    Divider()

                    targetFinishSummaryCard
                }
            }
            .accessibilityIdentifier("RaceSetup_ManualInputForm")
        }
    }

    @ViewBuilder
    private var goalNameSourceSection: some View {
        if isCatalogRaceSelected || viewModel.isRaceAPIAvailable {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    goalNameFieldSection
                    raceSourcePanel
                        .frame(width: 168, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    goalNameFieldSection
                    raceSourcePanel
                }
            }
        } else {
            goalNameFieldSection
        }
    }

    @ViewBuilder
    private var sourceOptionsSection: some View {
        if !viewModel.availableTargets.isEmpty {
            existingTargetsSection
        }
    }

    private var existingTargetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(NSLocalizedString("onboarding.or_select_existing_target",
                                            comment: "先前設定的目標賽事"),
                          systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")

            SectionCard {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableTargets.sorted { a, b in
                            Date(timeIntervalSince1970: TimeInterval(a.raceDate)) <
                            Date(timeIntervalSince1970: TimeInterval(b.raceDate))
                        }, id: \.id) { target in
                            Button(action: {
                                viewModel.selectTarget(target)
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(target.name)
                                        .font(AppFont.bodySmall())
                                        .fontWeight(.semibold)
                                        .lineLimit(2)

                                    Text("\(target.distanceKm)km")
                                        .font(AppFont.captionSmall())
                                        .foregroundColor(isExistingTargetSelected(target) ? .white.opacity(0.88) : .secondary)
                                }
                                .frame(width: 148, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isExistingTargetSelected(target) ? Color.accentColor : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isExistingTargetSelected(target) ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
                                )
                                .foregroundColor(isExistingTargetSelected(target) ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func isExistingTargetSelected(_ target: Target) -> Bool {
        viewModel.selectedRaceEvent == nil && viewModel.selectedTargetKey == target.id
    }

    private var isCatalogRaceSelected: Bool {
        viewModel.selectedRaceEvent != nil && viewModel.selectedRaceDistance != nil
    }

    private var formattedRaceDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: viewModel.raceDate)
    }

    private var formattedWeeksUntilRace: String {
        String(viewModel.trainingWeeks)
    }

    private var formattedWeeksUntilRaceText: String {
        String(format: NSLocalizedString("onboarding.weeks_until_race", comment: "距離賽事週數：%d"), viewModel.trainingWeeks)
    }

    private var formattedSelectedRaceCountdown: String {
        guard let selectedRace = viewModel.selectedRaceEvent else { return "" }
        return String.localizedStringWithFormat(
            NSLocalizedString("race_card.days_countdown", comment: "還有 %d 天"),
            selectedRace.daysUntilEvent
        )
    }

    private var goalNameFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("onboarding.goal_name_label", comment: "目標名稱"))
                .font(AppFont.caption())
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: isCatalogRaceSelected ? "checkmark.seal.fill" : "text.cursor")
                    .foregroundColor(.accentColor)

                TextField(NSLocalizedString("onboarding.target_race_example", comment: "Target race example"),
                          text: $viewModel.raceName)
                    .textContentType(.name)
                    .font(AppFont.body())
                    .disabled(isCatalogRaceSelected)
                    .accessibilityIdentifier("RaceSetup_RaceNameField")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCatalogRaceSelected ? Color.accentColor.opacity(0.28) : Color(.systemGray4),
                            lineWidth: 1)
            )

            if isCatalogRaceSelected {
                Text(NSLocalizedString("onboarding.goal_prefilled_from_race",
                                       comment: "已由賽事資料庫帶入，可改回手動輸入後編輯"))
                    .font(AppFont.captionSmall())
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var raceSourcePanel: some View {
        if let selectedRace = viewModel.selectedRaceEvent,
           let selectedDistance = viewModel.selectedRaceDistance {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedRace.name)
                            .font(AppFont.bodySmall())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text(selectedDistance.name)
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(formattedSelectedRaceCountdown)
                        .font(AppFont.captionSmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }

                raceSourceInfoRow(systemImage: "calendar", text: formattedRaceDate)
                raceSourceInfoRow(systemImage: "mappin.and.ellipse", text: selectedRace.city)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        compactRaceActionButton(
                            title: NSLocalizedString("onboarding.change_race", comment: "更換賽事"),
                            foreground: .accentColor,
                            background: Color.accentColor.opacity(0.08),
                            accessibilityId: "RaceSetup_ChangeRaceButton"
                        ) {
                            coordinator.navigate(to: .raceEventList)
                        }

                        compactRaceActionButton(
                            title: NSLocalizedString("onboarding.clear_selected_race", comment: "改回手動輸入"),
                            foreground: .secondary,
                            background: Color(.systemGray6),
                            accessibilityId: "RaceSetup_ClearRaceButton"
                        ) {
                            viewModel.clearSelectedRace()
                        }
                    }

                    VStack(spacing: 8) {
                        compactRaceActionButton(
                            title: NSLocalizedString("onboarding.change_race", comment: "更換賽事"),
                            foreground: .accentColor,
                            background: Color.accentColor.opacity(0.08),
                            accessibilityId: "RaceSetup_ChangeRaceButton"
                        ) {
                            coordinator.navigate(to: .raceEventList)
                        }

                        compactRaceActionButton(
                            title: NSLocalizedString("onboarding.clear_selected_race", comment: "改回手動輸入"),
                            foreground: .secondary,
                            background: Color(.systemGray6),
                            accessibilityId: "RaceSetup_ClearRaceButton"
                        ) {
                            viewModel.clearSelectedRace()
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .accessibilityIdentifier("RaceSetup_SelectedRaceCard")
        } else if viewModel.isRaceAPIAvailable {
            raceDatabaseEntryCard
        }
    }

    private func compactRaceActionButton(
        title: String,
        foreground: Color,
        background: Color,
        accessibilityId: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.caption())
                .fontWeight(.semibold)
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(background)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }

    private func raceSourceInfoRow(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(AppFont.caption())
            .foregroundColor(.secondary)
            .lineLimit(1)
    }

    private var raceDatabaseEntryCard: some View {
        Button(action: {
            coordinator.navigate(to: .raceEventList)
        }) {
            VStack(alignment: .leading, spacing: 10) {
                Label(NSLocalizedString("onboarding.browse_race_database", comment: "從賽事資料庫選擇"),
                      systemImage: "trophy.fill")
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("onboarding.browse_race_database_desc", comment: "瀏覽即將舉辦的賽事，快速設定目標"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                HStack(spacing: 6) {
                    Text(NSLocalizedString("common.select", comment: "Select"))
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(AppFont.systemScaled(size: 12))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.10))
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
            )
            .accessibilityIdentifier("RaceSetup_BrowseDatabaseCard")
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("RaceSetup_BrowseDatabaseButton")
    }

    private var scheduleRowsSection: some View {
        VStack(spacing: 8) {
            if isCatalogRaceSelected {
                goalDetailRow(
                    title: NSLocalizedString("onboarding.goal_date", comment: "Goal Date"),
                    value: formattedRaceDate,
                    systemImage: "calendar"
                )
            } else {
                goalDatePickerRow
            }

            if isCatalogRaceSelected {
                goalDetailRow(
                    title: NSLocalizedString("onboarding.weeks_until_race_label", comment: "距離賽事週數"),
                    value: formattedWeeksUntilRaceText,
                    systemImage: "calendar.badge.clock"
                )
            } else {
                goalDetailRow(
                    title: NSLocalizedString("onboarding.weeks_until_race_label", comment: "距離賽事週數"),
                    value: formattedWeeksUntilRace,
                    systemImage: "calendar.badge.clock"
                )
            }
        }
    }

    private var goalDatePickerRow: some View {
        HStack(spacing: 12) {
            Label(NSLocalizedString("onboarding.goal_date", comment: "Goal Date"),
                  systemImage: "calendar")
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)

            Spacer()

            DatePicker("",
                      selection: $viewModel.raceDate,
                      in: Date()...,
                      displayedComponents: .date)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func goalDetailRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(AppFont.bodySmall())
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private var targetFinishSummaryCard: some View {
        Button(action: {
            showDistanceTimeEditor = true
        }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(
                        isCatalogRaceSelected
                        ? NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time")
                        : NSLocalizedString("onboarding.distance_and_target_time", comment: "距離與目標時間")
                    )
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Label(NSLocalizedString("common.edit", comment: "Edit"),
                          systemImage: "slider.horizontal.3")
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.10))
                        )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        if !isCatalogRaceSelected {
                            targetSettingValue(
                                title: NSLocalizedString("onboarding.race_distance", comment: "Race Distance"),
                                value: viewModel.availableDistances[viewModel.selectedDistance] ?? viewModel.selectedDistance
                            )
                        }

                        targetSettingValue(
                            title: NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time"),
                            value: String(format: "%d:%02d:00", viewModel.targetHours, viewModel.targetMinutes)
                        )

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if !isCatalogRaceSelected {
                            targetSettingValue(
                                title: NSLocalizedString("onboarding.race_distance", comment: "Race Distance"),
                                value: viewModel.availableDistances[viewModel.selectedDistance] ?? viewModel.selectedDistance
                            )
                        }

                        targetSettingValue(
                            title: NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time"),
                            value: String(format: "%d:%02d:00", viewModel.targetHours, viewModel.targetMinutes)
                        )
                    }
                }

                HStack(spacing: 8) {
                    Text(NSLocalizedString("common.pace", comment: "Pace"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    Text(UnitManager.shared.formatPaceString(viewModel.targetPace))
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("RaceSetup_TargetTimeSection")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("RaceSetup_TargetTimeEditorButton")
    }

    private func targetSettingValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(.secondary)

            Text(value)
                .font(AppFont.body())
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - 導航邏輯處理

    private func handleNavigationAfterTargetCreation() {
        let targetDistance = Double(viewModel.selectedDistance) ?? 42.195
        let standardWeeks = TrainingPlanCalculator.getStandardTrainingWeeks(for: targetDistance)
        let trainingWeeks = viewModel.trainingWeeks
        let isRaceV2Flow = coordinator.selectedTargetTypeId == "race_run"

        coordinator.selectedTargetId = viewModel.selectedTargetKey

        print("[OnboardingView] 🧭 Navigation Decision: trainingWeeks=\(trainingWeeks), standardWeeks=\(standardWeeks), targetId=\(viewModel.selectedTargetKey ?? "nil")")

        if trainingWeeks < 2 {
            showTimeWarning = true
        } else if trainingWeeks >= standardWeeks {
            coordinator.selectedStartStage = nil
            UserDefaults.standard.removeObject(forKey: OnboardingCoordinator.startStageUserDefaultsKey)
            coordinator.shouldNavigateToStartStageAfterMethodology = false
            if isRaceV2Flow {
                coordinator.navigate(to: .methodologySelection)
            } else {
                coordinator.navigate(to: .trainingDays)
            }
        } else {
            coordinator.weeksRemaining = trainingWeeks
            coordinator.targetDistance = targetDistance
            coordinator.shouldNavigateToStartStageAfterMethodology = true
            if isRaceV2Flow {
                coordinator.navigate(to: .methodologySelection)
            } else {
                coordinator.navigate(to: .startStage)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OnboardingView()
        }
    }
}
