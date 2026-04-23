import SwiftUI
import FirebaseAuth

private struct ClimateSettingsPayload: Codable {
    let enabled: Bool
    let adaptationLevel: String
    let manualStartThresholdC: Double?
    let presets: [String]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case adaptationLevel = "adaptation_level"
        case manualStartThresholdC = "manual_start_threshold_c"
        case presets
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct ClimateAdapterDisclosure: Codable {
    let id: String
    let displayName: String
    let dataSource: String
    let isFallback: Bool
    let disclosure: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case dataSource = "data_source"
        case isFallback = "is_fallback"
        case disclosure
    }
}

private struct ClimateUISummary: Codable {
    let featureName: String
    let currentSettingLabel: String
    let adjustmentStartTempC: Double
    let dangerTempC: Double
    let howItWorks: [String]
    let sourceDisclosure: String

    enum CodingKeys: String, CodingKey {
        case featureName = "feature_name"
        case currentSettingLabel = "current_setting_label"
        case adjustmentStartTempC = "adjustment_start_temp_c"
        case dangerTempC = "danger_temp_c"
        case howItWorks = "how_it_works"
        case sourceDisclosure = "source_disclosure"
    }
}

private struct ClimateInterventionRule: Codable, Identifiable {
    let level: String
    let temperatureRangeLabel: String
    let summaryText: String
    let paceText: String?
    let longRunText: String?
    let trainingWindowText: String?

    var id: String { level }

    enum CodingKeys: String, CodingKey {
        case level
        case temperatureRangeLabel = "temperature_range_label"
        case summaryText = "summary_text"
        case paceText = "pace_text"
        case longRunText = "long_run_text"
        case trainingWindowText = "training_window_text"
    }
}

private struct ClimateCurrentStatus: Codable {
    let isAdjusted: Bool
    let feelsLikeTempC: Double?
    let paceAdjustmentPct: Double?
    let longRunReductionPct: Double?
    let statusText: String?

    enum CodingKeys: String, CodingKey {
        case isAdjusted = "is_adjusted"
        case feelsLikeTempC = "feels_like_temp_c"
        case paceAdjustmentPct = "pace_adjustment_pct"
        case longRunReductionPct = "long_run_reduction_pct"
        case statusText = "status_text"
    }
}

private struct ClimateHeatProfile: Codable {
    let baseProfileName: String
    let uiSummary: ClimateUISummary
    let interventionRules: [ClimateInterventionRule]
    let currentStatus: ClimateCurrentStatus?

    enum CodingKeys: String, CodingKey {
        case baseProfileName = "base_profile_name"
        case uiSummary = "ui_summary"
        case interventionRules = "intervention_rules"
        case currentStatus = "current_status"
    }
}

private struct ClimateProfileResponse: Codable {
    let uid: String
    let locale: String
    let adapter: ClimateAdapterDisclosure
    let settings: ClimateSettingsPayload
    let heatProfile: ClimateHeatProfile

    enum CodingKeys: String, CodingKey {
        case uid
        case locale
        case adapter
        case settings
        case heatProfile = "heat_profile"
    }
}

private struct ClimateIndicators: Codable {
    let hotTrainingHours14d: Double
    let hotWorkoutCount14d: Int
    let hotPaceAchievementRatePct: Double?
    let hotHrEfficiencyTrend: String
    let hotHrEfficiencyDeltaPct: Double?

    enum CodingKeys: String, CodingKey {
        case hotTrainingHours14d = "hot_training_hours_14d"
        case hotWorkoutCount14d = "hot_workout_count_14d"
        case hotPaceAchievementRatePct = "hot_pace_achievement_rate_pct"
        case hotHrEfficiencyTrend = "hot_hr_efficiency_trend"
        case hotHrEfficiencyDeltaPct = "hot_hr_efficiency_delta_pct"
    }
}

private struct ClimateAdaptationMetricsResponse: Codable {
    let indicators: ClimateIndicators
    let recommendedAdaptationLevel: String
    let currentAdaptationLevel: String
    let dataInsufficient: Bool
    let dataInsufficientReason: String?

    enum CodingKeys: String, CodingKey {
        case indicators
        case recommendedAdaptationLevel = "recommended_adaptation_level"
        case currentAdaptationLevel = "current_adaptation_level"
        case dataInsufficient = "data_insufficient"
        case dataInsufficientReason = "data_insufficient_reason"
    }
}

@MainActor
private final class ClimateSettingsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var profile: ClimateProfileResponse?
    @Published var metrics: ClimateAdaptationMetricsResponse?
    @Published var enabled = true
    @Published var adaptationLevel = "normal"
    @Published var useManualThreshold = false
    @Published var manualThreshold = 27.0

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "找不到目前登入使用者。"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let profileResponse = APIClient.shared.request(
                ClimateProfileResponse.self,
                path: "/v1/users/\(uid)/climate/profile"
            )
            async let metricsResponse = APIClient.shared.request(
                ClimateAdaptationMetricsResponse.self,
                path: "/v1/users/\(uid)/climate/adaptation-metrics"
            )

            let (loadedProfile, loadedMetrics) = try await (profileResponse, metricsResponse)
            apply(profile: loadedProfile, metrics: loadedMetrics)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "找不到目前登入使用者。"
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = ClimateSettingsPayload(
            enabled: enabled,
            adaptationLevel: adaptationLevel,
            manualStartThresholdC: useManualThreshold ? manualThreshold : nil,
            presets: nil,
            createdAt: nil,
            updatedAt: nil
        )

        do {
            let body = try JSONEncoder().encode(payload)
            _ = try await APIClient.shared.request(
                ClimateSettingsPayload.self,
                path: "/v1/users/\(uid)/climate/settings",
                method: "PUT",
                body: body
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(profile: ClimateProfileResponse, metrics: ClimateAdaptationMetricsResponse) {
        self.profile = profile
        self.metrics = metrics
        enabled = profile.settings.enabled
        adaptationLevel = profile.settings.adaptationLevel
        if let threshold = profile.settings.manualStartThresholdC {
            useManualThreshold = true
            manualThreshold = threshold
        } else {
            useManualThreshold = false
            manualThreshold = profile.heatProfile.uiSummary.adjustmentStartTempC
        }
    }
}

struct ClimateSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ClimateSettingsViewModel()
    @State private var showExplanation = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                if let profile = viewModel.profile {
                    toggleSection(profile)

                    if viewModel.enabled {
                        currentStatusSection(profile)
                        controlsSection(profile)
                        explanationEntrySection
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("載入熱適應設定中…")
                }
            }
            .navigationTitle("熱適應")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("儲存") {
                            Task { await viewModel.save() }
                        }
                        .disabled(viewModel.profile == nil)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(isPresented: $showExplanation) {
                if let profile = viewModel.profile {
                    HeatAdaptationExplanationView(
                        profile: profile,
                        metrics: viewModel.metrics
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func toggleSection(_ profile: ClimateProfileResponse) -> some View {
        Section {
            Toggle(isOn: $viewModel.enabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("啟用熱適應")
                        .font(.headline)
                    Text(toggleStatusDescription(profile))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func currentStatusSection(_ profile: ClimateProfileResponse) -> some View {
        Section("目前狀態") {
            if let currentStatus = profile.heatProfile.currentStatus {
                statusRow("現在是否調整", currentStatus.isAdjusted ? "已調整" : "未調整")

                if let feelsLike = currentStatus.feelsLikeTempC {
                    statusRow("目前體感溫度", String(format: "%.1f°C", feelsLike))
                }

                statusRow("配速調整幅度", currentStatusPaceText(currentStatus))

                if let longRunText = currentStatusLongRunText(currentStatus) {
                    statusRow("長跑調整", longRunText)
                }

                if let statusText = currentStatus.statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                statusRow("你的設定", profile.heatProfile.uiSummary.currentSettingLabel)
                statusRow("開始介入", "\(Int(profile.heatProfile.uiSummary.adjustmentStartTempC))°C")
                statusRow("常見調整幅度", primaryAdjustmentPreview(profile))
                Text("目前頁面還拿不到『當下是否已調整』；這需要後端補 current status。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func controlsSection(_ profile: ClimateProfileResponse) -> some View {
        Section {
            Picker("熱適應程度", selection: $viewModel.adaptationLevel) {
                Text("未適應／初學").tag("unacclimated")
                Text("一般").tag("normal")
                Text("已熱適應").tag("acclimated")
            }

            Toggle("手動調整開始溫度", isOn: $viewModel.useManualThreshold)

            if viewModel.useManualThreshold {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("開始介入溫度")
                        Spacer()
                        Text(String(format: "%.1f°C", viewModel.manualThreshold))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.manualThreshold, in: 24...30, step: 0.5)
                    Text("危險等級固定在 \(Int(profile.heatProfile.uiSummary.dangerTempC))°C。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("你的設定")
        } footer: {
            Text("變更只會影響之後新生成的課表，不會回改已生成的結果。")
        }
    }

    @ViewBuilder
    private var explanationEntrySection: some View {
        Section {
            Button {
                showExplanation = true
            } label: {
                HStack {
                    Text("查看熱適應說明")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func primaryAdjustmentPreview(_ profile: ClimateProfileResponse) -> String {
        profile.heatProfile.interventionRules.compactMap(\.paceText).first ?? "目前未提供"
    }

    private func toggleStatusDescription(_ profile: ClimateProfileResponse) -> String {
        if viewModel.enabled {
            return "目前已啟用。系統會在下一次生成課表時，依預報與你的熱適應設定判斷是否要放慢配速或縮短長跑。"
        }
        return "目前已關閉。之後新生成的課表會維持原始配速，不套用熱適應調整。"
    }

    private func currentStatusPaceText(_ currentStatus: ClimateCurrentStatus) -> String {
        guard currentStatus.isAdjusted else { return "0%" }
        guard let paceAdjustmentPct = currentStatus.paceAdjustmentPct else { return "已調整" }
        return String(format: "%.1f%%", paceAdjustmentPct)
    }

    private func currentStatusLongRunText(_ currentStatus: ClimateCurrentStatus) -> String? {
        guard let longRunReductionPct = currentStatus.longRunReductionPct else { return nil }
        return String(format: "%.1f%%", longRunReductionPct)
    }
}

private struct HeatAdaptationExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: ClimateProfileResponse
    let metrics: ClimateAdaptationMetricsResponse?

    var body: some View {
        NavigationStack {
            List {
                Section("熱適應怎麼運作") {
                    ForEach(Array(profile.heatProfile.uiSummary.howItWorks.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                            Text(item)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("什麼情況會介入") {
                    ForEach(profile.heatProfile.interventionRules) { rule in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(rule.temperatureRangeLabel)
                                .font(.headline)
                            Text(rule.summaryText)
                                .font(.subheadline)
                            if let paceText = rule.paceText {
                                Text(paceText)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            if let longRunText = rule.longRunText {
                                Text(longRunText)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            if let trainingWindowText = rule.trainingWindowText {
                                Text(trainingWindowText)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let metrics {
                    Section("你的近 14 天熱適應狀態") {
                        LabeledContent("系統建議", value: localizedAdaptation(metrics.recommendedAdaptationLevel))
                        LabeledContent("目前設定", value: localizedAdaptation(metrics.currentAdaptationLevel))
                        LabeledContent("熱環境時數", value: String(format: "%.1f h", metrics.indicators.hotTrainingHours14d))
                        LabeledContent("熱壓力訓練", value: "\(metrics.indicators.hotWorkoutCount14d) 次")
                        LabeledContent("配速達成率", value: percentText(metrics.indicators.hotPaceAchievementRatePct))
                        LabeledContent("心率效率", value: localizedTrend(metrics.indicators.hotHrEfficiencyTrend))
                        if let delta = metrics.indicators.hotHrEfficiencyDeltaPct {
                            LabeledContent("效率變化", value: String(format: "%.1f%%", delta))
                        }
                        if metrics.dataInsufficient, let reason = metrics.dataInsufficientReason {
                            Text(reason)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("資料來源") {
                    LabeledContent("區域策略", value: profile.adapter.displayName)
                    LabeledContent("氣象來源", value: profile.adapter.dataSource)
                    Text(profile.heatProfile.uiSummary.sourceDisclosure)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("熱適應說明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "資料不足" }
        return String(format: "%.1f%%", value)
    }

    private func localizedAdaptation(_ value: String) -> String {
        switch value {
        case "unacclimated": return "未適應／初學"
        case "acclimated": return "已熱適應"
        default: return "一般"
        }
    }

    private func localizedTrend(_ value: String) -> String {
        switch value {
        case "improving": return "改善中"
        case "declining": return "惡化中"
        case "stable": return "穩定"
        default: return "資料不足"
        }
    }
}

#Preview {
    ClimateSettingsView()
}
