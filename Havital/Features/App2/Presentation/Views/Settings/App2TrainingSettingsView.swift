import SwiftUI

// MARK: - App2TrainingSettingsView
/// 2.0「訓練設定」（設計 frame-23）：目標週跑量滑桿 ＋ 訓練日勾選，一顆「儲存」一起寫。
///
/// 寫入走 `App2SettingsViewModel.saveTrainingSettings`，底下是既有的
/// `UpdateUserProfileUseCase`（`current_week_distance` / `prefer_week_days` /
/// `prefer_week_days_longrun`）—— 與 1.4 的 `WeeklyDistanceEditorView` 與
/// `EditTrainingDaysView` 同一條路徑，沒有第二份寫法。
///
/// 滑桿範圍與建議帶沿用 `App2OnboardingProjection.mileagePreview`（frame-38 同一組刻度），
/// 錨定在**已存檔的值**而不是滑桿當下值 —— 否則建議帶會跟著手指跑。
struct App2TrainingSettingsView: View {

    let onClose: () -> Void
    @ObservedObject var viewModel: App2SettingsViewModel

    @State private var weeklyDistance: Double = 0
    @State private var weekdays: Set<Int> = []
    @State private var longRunWeekday: Int = 6
    @State private var isSaving = false
    @State private var didLoadInitial = false

    /// 錨點：已存檔的週跑量。0（尚未設定）時退回 30 km，滑桿才不會塌成一個點。
    private var anchorKm: Double {
        let saved = Double(viewModel.weeklyDistanceKm)
        return saved > 0 ? saved : 30
    }

    /// `totalWeeks: 20` ＝ 取滿五個四週訓練塊（`mileagePreview` 的 `steps` 上限），
    /// 讓設定頁的滑桿上界穩定；建議帶只取錨點 ±10%，與週數無關。
    private var preview: App2OnboardingProjection.MileagePreview {
        App2OnboardingProjection.mileagePreview(startKm: anchorKm, totalWeeks: 20)
    }

    var body: some View {
        App2SettingsPageScaffold(
            title: L10n.App2.Settings.trainingSection.localized,
            onBack: onClose,
            backIdentifier: "App2_TrainingSettingsClose",
            titleIdentifier: "App2_TrainingSettingsView",
            ctaTitle: NSLocalizedString("common.save", comment: "Save"),
            ctaEnabled: !weekdays.isEmpty,
            ctaBusy: isSaving,
            ctaIdentifier: "App2_TrainingSettingsSave",
            ctaAction: { save() }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                distanceSection
                daysSection
            }
        }
        .onAppear(perform: loadInitialIfNeeded)
    }

    // MARK: - 目標週跑量

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: L10n.App2.Settings.targetWeeklyDistance.localized)

            App2Card(spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Spacer(minLength: 0)
                    Text("\(Int(weeklyDistance.rounded()))")
                        .font(.app2Numeric(40, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(L10n.App2.Onboarding.mileageUnit.localized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                    Spacer(minLength: 0)
                }
                .accessibilityIdentifier("App2_TrainingSettingsDistanceValue")

                Slider(value: $weeklyDistance, in: preview.sliderRange, step: 1)
                    .tint(App2Theme.accentBlue)
                    .accessibilityIdentifier("App2_TrainingSettingsDistanceSlider")

                HStack {
                    Text("\(Int(preview.sliderRange.lowerBound))")
                        .font(.app2Mono(12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                    Spacer()
                    Text(String(
                        format: L10n.App2.Onboarding.mileageSuggestedFormat.localized,
                        preview.suggestedBand.lowerBound, preview.suggestedBand.upperBound
                    ))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                    Spacer()
                    Text("\(Int(preview.sliderRange.upperBound))")
                        .font(.app2Mono(12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
            }
        }
    }

    // MARK: - 訓練日

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            App2SectionCaption(text: L10n.App2.Settings.trainingDays.localized)

            HStack(spacing: 7) {
                ForEach(1...7, id: \.self) { weekday in
                    App2OnboardingChip(
                        title: App2OnboardingFormat.weekdayShort(weekday),
                        isSelected: weekdays.contains(weekday),
                        identifier: "App2_TrainingSettingsWeekday_\(weekday)"
                    ) {
                        toggle(weekday)
                    }
                }
            }

            countHint

            if !weekdays.isEmpty {
                longRunPicker
            }
        }
    }

    private var countHint: some View {
        let count = weekdays.count
        let suggested = App2OnboardingProjection.suggestedTrainingDays
        let inBand = App2OnboardingProjection.isTrainingDayCountSuggested(count)
        return HStack(spacing: 8) {
            Circle()
                .fill(inBand ? App2Theme.accentBlue : App2Theme.inkMuted)
                .frame(width: 7, height: 7)
            Text(String(
                format: L10n.App2.Onboarding.daysSelectedFormat.localized,
                count, suggested.lowerBound, suggested.upperBound
            ))
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(inBand ? App2Theme.accentBlueDeep : App2Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("App2_TrainingSettingsDaysHint")
    }

    private var longRunPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            App2OnboardingFieldLabel(text: L10n.App2.Onboarding.daysLongRun.localized)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(weekdays.sorted(), id: \.self) { weekday in
                        App2OnboardingOutlineChip(
                            title: App2OnboardingFormat.weekdayFull(weekday),
                            isSelected: longRunWeekday == weekday,
                            identifier: "App2_TrainingSettingsLongRun_\(weekday)"
                        ) {
                            longRunWeekday = weekday
                        }
                        .frame(width: 96)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 狀態

    private func loadInitialIfNeeded() {
        guard !didLoadInitial else { return }
        didLoadInitial = true
        weekdays = viewModel.trainingWeekdays
        // 存檔的長跑日若不在訓練日裡（1.4 兩個欄位分開編輯，會不一致），
        // 退回最後一個訓練日，畫面上不會出現「選了一個沒被選中的日子」。
        let savedLongRun = viewModel.longRunWeekday
        longRunWeekday = weekdays.contains(savedLongRun)
            ? savedLongRun
            : (weekdays.sorted().last ?? savedLongRun)
        let saved = Double(viewModel.weeklyDistanceKm)
        weeklyDistance = min(
            max(saved > 0 ? saved : anchorKm, preview.sliderRange.lowerBound),
            preview.sliderRange.upperBound
        )
    }

    private func toggle(_ weekday: Int) {
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
            if longRunWeekday == weekday, let fallback = weekdays.sorted().last {
                longRunWeekday = fallback
            }
        } else {
            weekdays.insert(weekday)
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            let ok = await viewModel.saveTrainingSettings(
                weeklyDistanceKm: Int(weeklyDistance.rounded()),
                weekdays: weekdays,
                longRunWeekday: longRunWeekday
            )
            isSaving = false
            if ok { onClose() }
        }
    }
}
