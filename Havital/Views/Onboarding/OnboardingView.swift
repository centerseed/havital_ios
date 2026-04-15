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
            VStack(spacing: OnboardingLayout.sectionSpacing) {
                // MARK: - 賽事資料庫入口（只在 API 可用時顯示）
                if viewModel.isRaceAPIAvailable {
                    if let selectedRace = viewModel.selectedRaceEvent,
                       let selectedDistance = viewModel.selectedRaceDistance {
                        // State 2: 已選賽事 — 顯示摘要卡 + 更換賽事
                        VStack(spacing: 8) {
                            selectedRaceSummaryCard(race: selectedRace, distance: selectedDistance)

                            Button(action: {
                                coordinator.navigate(to: .raceEventList)
                            }) {
                                Text(NSLocalizedString("onboarding.change_race", comment: "更換賽事"))
                                    .font(AppFont.bodySmall())
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("RaceSetup_ChangeRaceButton")
                        }
                    } else {
                        // State 1: 尚未選賽事 — 顯示資料庫入口 + 分隔線
                        VStack(spacing: 16) {
                            raceDatabaseEntryCard

                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(height: 1)
                                Text(NSLocalizedString("onboarding.or_manual_input", comment: "或手動輸入"))
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)
                                    .fixedSize()
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                // State 3 (isRaceAPIAvailable == false): 不渲染卡片，直接顯示手動輸入

                // MARK: - 主要內容區域
                if viewModel.selectedRaceEvent != nil {
                    // State 2: 已選賽事 — 只顯示目標完賽時間編輯
                    targetFinishTimeSection
                } else {
                    // State 1 / State 3: 顯示完整手動輸入表單
                    manualInputForm
                }
            }
            .padding(.top, 8)
        }
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
                availableDistances: viewModel.availableDistances
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

    // MARK: - 賽事資料庫入口卡片（State 1）

    private var raceDatabaseEntryCard: some View {
        Button(action: {
            coordinator.navigate(to: .raceEventList)
        }) {
            HStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("onboarding.browse_race_database", comment: "從賽事資料庫選擇"))
                        .font(AppFont.headline())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(NSLocalizedString("onboarding.browse_race_database_desc", comment: "瀏覽即將舉辦的賽事，快速設定目標"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("RaceSetup_BrowseDatabaseButton")
    }

    // MARK: - 已選賽事摘要卡（State 2）

    @ViewBuilder
    private func selectedRaceSummaryCard(race: RaceEvent, distance: RaceDistance) -> some View {
        let dateString: String = {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            formatter.locale = Locale.current
            return formatter.string(from: race.eventDate)
        }()

        VStack(alignment: .leading, spacing: 12) {
            Text(race.name)
                .font(AppFont.headline())
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 6) {
                Label(race.city, systemImage: "mappin.circle.fill")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.white.opacity(0.9))

                Label(dateString, systemImage: "calendar")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.white.opacity(0.9))

                Label(distance.name, systemImage: "figure.run")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack {
                Text(String(format: NSLocalizedString("race_card.days_countdown", comment: "還有 %d 天"), race.daysUntilEvent))
                    .font(AppFont.caption())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))
                    )
                Spacer()
            }

            if race.isTimeTight {
                InlineWarningBanner(
                    title: NSLocalizedString("onboarding.tight_schedule_title", comment: "時間較緊迫"),
                    message: NSLocalizedString("onboarding.tight_schedule_message",
                                               comment: "距離賽事不足 4 週，系統會根據可用時間自動調整訓練計畫。")
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor)
        )
        .accessibilityIdentifier("RaceSetup_SelectedRaceCard")
    }

    // MARK: - 目標完賽時間區塊（State 2 使用）

    private var targetFinishTimeSection: some View {
        Button(action: {
            showDistanceTimeEditor = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time"))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            Text(String(format: "%d:%02d:00", viewModel.targetHours, viewModel.targetMinutes))
                                .font(AppFont.headline())
                                .foregroundColor(.primary)
                        }
                    }

                    Divider()
                        .padding(.leading, 32)

                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("common.pace", comment: "Pace"))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            Text(UnitManager.shared.formatPaceString(viewModel.targetPace))
                                .font(AppFont.headline())
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.vertical, 4)

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("common.edit", comment: "Edit"))
                        .font(AppFont.captionSmall())
                        .foregroundColor(.accentColor)
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("RaceSetup_TargetTimeEditorButton")
    }

    // MARK: - 手動輸入表單（State 1 / State 3）

    private var manualInputForm: some View {
        VStack(spacing: 0) {
            Form {
                Section(
                    header: Text(NSLocalizedString("onboarding.your_running_goal", comment: "Your Running Goal")),
                    footer: Text(NSLocalizedString("onboarding.goal_description", comment: "Goal description"))
                ) {
                    if !viewModel.availableTargets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("onboarding.or_select_existing_target",
                                                  comment: "或選擇已設定的未來賽事"))
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.availableTargets.sorted { a, b in
                                        Date(timeIntervalSince1970: TimeInterval(a.raceDate)) <
                                        Date(timeIntervalSince1970: TimeInterval(b.raceDate))
                                    }, id: \.id) { target in
                                        Button(action: {
                                            viewModel.selectTarget(target)
                                        }) {
                                            VStack(spacing: 4) {
                                                Text(target.name)
                                                    .font(AppFont.caption())
                                                    .fontWeight(.semibold)
                                                    .lineLimit(1)
                                                Text("\(target.distanceKm)km")
                                                    .font(AppFont.captionSmall())
                                            }
                                            .frame(minWidth: 80)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(viewModel.selectedTargetKey == target.id
                                                          ? Color.accentColor : Color(.systemGray6))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(viewModel.selectedTargetKey == target.id
                                                            ? Color.accentColor : Color(.systemGray3),
                                                            lineWidth: 1.5)
                                            )
                                            .foregroundColor(viewModel.selectedTargetKey == target.id
                                                             ? .white : .primary)
                                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    TextField(NSLocalizedString("onboarding.target_race_example", comment: "Target race example"),
                              text: $viewModel.raceName)
                        .textContentType(.name)

                    DatePicker(NSLocalizedString("onboarding.goal_date", comment: "Goal Date"),
                              selection: $viewModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)

                    Text(String(format: NSLocalizedString("onboarding.weeks_until_race",
                                                          comment: "Weeks until race"),
                                viewModel.trainingWeeks))
                        .foregroundColor(.secondary)
                }

                Section(
                    header: Text(NSLocalizedString("onboarding.distance_and_target_time",
                                                  comment: "距離與目標時間"))
                ) {
                    Button(action: {
                        showDistanceTimeEditor = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "figure.run")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("onboarding.race_distance",
                                                              comment: "Race Distance"))
                                            .font(AppFont.caption())
                                            .foregroundColor(.secondary)
                                        Text(viewModel.availableDistances[viewModel.selectedDistance]
                                             ?? viewModel.selectedDistance)
                                            .font(AppFont.headline())
                                            .foregroundColor(.primary)
                                    }
                                }

                                Divider()
                                    .padding(.leading, 32)

                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("onboarding.target_finish_time",
                                                              comment: "Target Finish Time"))
                                            .font(AppFont.caption())
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%d:%02d:00",
                                                    viewModel.targetHours, viewModel.targetMinutes))
                                            .font(AppFont.headline())
                                            .foregroundColor(.primary)
                                    }
                                }

                                Divider()
                                    .padding(.leading, 32)

                                HStack(spacing: 8) {
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("common.pace", comment: "Pace"))
                                            .font(AppFont.caption())
                                            .foregroundColor(.secondary)
                                        Text(UnitManager.shared.formatPaceString(viewModel.targetPace))
                                            .font(AppFont.headline())
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)

                            Spacer()

                            VStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.accentColor)
                                Text(NSLocalizedString("common.edit", comment: "Edit"))
                                    .font(AppFont.captionSmall())
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("RaceSetup_TargetTimeEditorButton")
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .frame(minHeight: 500)
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
