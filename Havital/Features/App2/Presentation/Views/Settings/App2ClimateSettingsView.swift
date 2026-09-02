import SwiftUI

// MARK: - App2ClimateSettingsView
/// 2.0「熱適應」設定頁（T-0392）。
///
/// 走查清單 §30-7 只把高溫適應畫成系統卡裡的一顆開關，沒有這一頁的 frame；
/// 2026-09-02 使用者裁決「直接用 2.0 風格重寫一個」，所以照 2.0 既有子頁的構造組
/// （`App2SettingsPageScaffold` ＋ `App2GroupedList` ＋ `App2NoteBox`），不發明新視覺語彙。
///
/// 資料與寫入走 `ClimateSettingsViewModel`（`load()` / `save()`）——與 1.4 的
/// `ClimateSettingsView` 同一份 view model、同一組 `climate_settings.*` 三語字串，
/// 不是第二份設定來源。
///
/// 1.4 那一頁的「說明」是巢狀 sheet（運作方式／介入規則）。這裡直接攤在頁面下半，
/// 少一次點擊，也不用在 push 的堆疊裡再疊一層 present。
struct App2ClimateSettingsView: View {

    let onClose: () -> Void

    @StateObject private var viewModel = ClimateSettingsViewModel()

    private static let adaptationLevels = ["unacclimated", "normal", "acclimated"]

    /// 哪幾段該出現、狀態畫實測還是退回摘要、配速那一格印什麼、滑桿的界
    /// ——判斷全在 `App2ClimateSettingsProjection`，這裡只負責畫。
    private typealias Projection = App2ClimateSettingsProjection

    var body: some View {
        App2SettingsPageScaffold(
            title: climateLocalized("climate_settings.title"),
            onBack: onClose,
            backIdentifier: "App2_ClimateSettingsClose",
            titleIdentifier: "App2_ClimateSettingsView",
            ctaTitle: climateLocalized("common.save"),
            ctaEnabled: viewModel.profile != nil,
            ctaBusy: viewModel.isSaving,
            ctaIdentifier: "App2_ClimateSettingsSave",
            ctaAction: { Task { await viewModel.save() } }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage = viewModel.errorMessage {
                    App2NoteBox(symbol: "exclamationmark.triangle.fill", accent: App2Theme.accentRed) {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(App2Theme.inkSecondary)
                    }
                }

                if let profile = viewModel.profile {
                    ForEach(Projection.sections(enabled: viewModel.enabled), id: \.self) { section in
                        switch section {
                        case .enable: enableSection(profile)
                        case .currentStatus: currentStatusSection(profile)
                        case .controls: controlsSection(profile)
                        case .explanation: explanationSection(profile)
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - 啟用

    private func enableSection(_ profile: ClimateProfileResponse) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            App2GroupedList {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(climateLocalized("climate_settings.enable_title"))
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(App2Theme.inkPrimary)
                            Text(climateLocalized("climate_settings.feels_like_subtitle"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(App2Theme.inkMuted)
                        }
                        Spacer(minLength: 8)
                        Toggle("", isOn: $viewModel.enabled)
                            .labelsHidden()
                            .tint(App2Theme.accentBlue)
                            .accessibilityIdentifier("App2_ClimateSettingsEnabled")
                    }

                    Text(viewModel.enabled
                         ? climateLocalized("climate_settings.enabled_description")
                         : climateLocalized("climate_settings.disabled_description"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSubtle)
                }
                .padding(15)
            }

            Text(climateLocalized("climate_settings.effective_notice"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkFaint)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - 目前狀態

    @ViewBuilder
    private func currentStatusSection(_ profile: ClimateProfileResponse) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: climateLocalized("climate_settings.current_status.section"))

            App2GroupedList {
                if Projection.statusMode(currentStatus: profile.heatProfile.currentStatus) == .live,
                   let status = profile.heatProfile.currentStatus {
                    statusRow(
                        climateLocalized("climate_settings.current_status.is_adjusted"),
                        status.isAdjusted
                            ? climateLocalized("climate_settings.current_status.adjusted")
                            : climateLocalized("climate_settings.current_status.not_adjusted")
                    )
                    if let feelsLike = status.feelsLikeTempC {
                        statusRow(
                            climateLocalized("climate_settings.current_status.feels_like"),
                            String(format: "%.1f°C", feelsLike)
                        )
                    }
                    statusRow(
                        climateLocalized("climate_settings.current_status.pace_adjustment"),
                        Projection.paceText(
                            status,
                            adjustedLabel: climateLocalized("climate_settings.current_status.adjusted")
                        )
                    )
                    if let longRunReductionPct = status.longRunReductionPct {
                        statusRow(
                            climateLocalized("climate_settings.current_status.long_run_adjustment"),
                            String(format: "%.1f%%", longRunReductionPct)
                        )
                    }
                    if let statusText = status.statusText, !statusText.isEmpty {
                        footnote(statusText)
                    }
                } else {
                    // 沒有當日觀測就退成「你的設定」摘要——與 1.4 同一組欄位。
                    statusRow(
                        climateLocalized("climate_settings.your_setting"),
                        profile.heatProfile.uiSummary.currentSettingLabel
                    )
                    statusRow(
                        climateLocalized("climate_settings.adjustment_start"),
                        "\(Int(profile.heatProfile.uiSummary.adjustmentStartTempC))°C"
                    )
                    statusRow(
                        climateLocalized("climate_settings.common_adjustment"),
                        profile.heatProfile.interventionRules.compactMap(\.paceText).first
                            ?? climateLocalized("climate_settings.not_available")
                    )
                    footnote(climateLocalized("climate_settings.current_status.unavailable"))
                }
            }
        }
    }

    // MARK: - 你的設定

    private func controlsSection(_ profile: ClimateProfileResponse) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: climateLocalized("climate_settings.your_setting"))

            App2GroupedList {
                VStack(alignment: .leading, spacing: 10) {
                    Text(climateLocalized("climate_settings.adaptation_level"))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                    adaptationPicker
                }
                .padding(15)

                divider

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(climateLocalized("climate_settings.manual_threshold.toggle"))
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Spacer(minLength: 6)
                        Toggle("", isOn: $viewModel.useManualThreshold)
                            .labelsHidden()
                            .tint(App2Theme.accentBlue)
                            .accessibilityIdentifier("App2_ClimateSettingsManualThreshold")
                    }

                    if viewModel.useManualThreshold {
                        HStack {
                            Text(climateLocalized("climate_settings.manual_threshold.start_temp"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(App2Theme.inkMuted)
                            Spacer()
                            Text(String(format: "%.1f°C", viewModel.manualThreshold))
                                .font(.app2Mono(15, weight: .bold))
                                .foregroundStyle(App2Theme.inkPrimary)
                                .accessibilityIdentifier("App2_ClimateSettingsThresholdValue")
                        }
                        Slider(
                            value: $viewModel.manualThreshold,
                            in: Projection.thresholdRange,
                            step: Projection.thresholdStep
                        )
                            .tint(App2Theme.accentBlue)
                            .accessibilityIdentifier("App2_ClimateSettingsThresholdSlider")
                        footnote(String(
                            format: climateLocalized("climate_settings.manual_threshold.danger_fixed_format"),
                            Int(profile.heatProfile.uiSummary.dangerTempC)
                        ))
                    }
                }
                .padding(15)
            }

            Text(climateLocalized("climate_settings.future_only_footer"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkFaint)
                .padding(.horizontal, 4)
        }
    }

    private var adaptationPicker: some View {
        HStack(spacing: 2) {
            ForEach(Self.adaptationLevels, id: \.self) { level in
                let isSelected = viewModel.adaptationLevel == level
                Text(climateLocalized("climate_settings.adaptation.\(level)"))
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(isSelected ? App2Theme.inkPrimary : App2Theme.inkMuted)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(App2Theme.cardBackground)
                                .shadow(color: App2Theme.shadowInk.opacity(0.1), radius: 3, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.adaptationLevel = level }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_ClimateSettingsAdaptation_\(level)")
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.insetBackground)
        )
    }

    // MARK: - 說明（1.4 是巢狀 sheet，這裡直接攤開）

    private func explanationSection(_ profile: ClimateProfileResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                App2SectionCaption(text: climateLocalized("climate_settings.explanation.how_it_works"))

                App2GroupedList {
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(Array(profile.heatProfile.uiSummary.howItWorks.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.app2Mono(11, weight: .bold))
                                    .foregroundStyle(App2Theme.accentBlue)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(App2Theme.accentBlue.opacity(0.1)))
                                Text(item)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(App2Theme.inkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(15)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                App2SectionCaption(text: climateLocalized("climate_settings.explanation.intervention_rules"))

                VStack(spacing: 10) {
                    ForEach(profile.heatProfile.interventionRules) { rule in
                        App2GroupedList {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(rule.temperatureRangeLabel)
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(App2Theme.inkPrimary)
                                Text(rule.summaryText)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(App2Theme.inkSecondary)
                                ForEach([rule.paceText, rule.longRunText, rule.trainingWindowText]
                                    .compactMap { $0 }, id: \.self) { line in
                                    Text(line)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(App2Theme.inkMuted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 小元件

    private func statusRow(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(App2Theme.inkSubtle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15)
            .padding(.bottom, 13)
    }

    private var divider: some View {
        Rectangle()
            .fill(App2Theme.insetBorder)
            .frame(height: 1)
            .padding(.horizontal, 15)
    }

}
