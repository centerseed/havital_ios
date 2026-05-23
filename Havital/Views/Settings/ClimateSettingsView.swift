import SwiftUI

private func climateLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private struct ClimateSettingsPayload: Codable {
    let enabled: Bool
    let adaptationLevel: String
    let manualStartThresholdC: Double?
    let regionKey: String?
    let presets: [String]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case adaptationLevel = "adaptation_level"
        case manualStartThresholdC = "manual_start_threshold_c"
        case regionKey = "region_key"
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

private struct ClimateSettingsContext {
    let profile: ClimateProfileResponse
    let metrics: ClimateAdaptationMetricsResponse
}

private protocol ClimateSettingsRepository {
    func fetchSettingsContext() async throws -> ClimateSettingsContext
    func updateSettings(_ payload: ClimateSettingsPayload) async throws
}

private final class ClimateSettingsRemoteDataSource {
    private let httpClient: HTTPClient
    private let parser: APIParser
    private let authSessionRepository: AuthSessionRepository

    init(
        httpClient: HTTPClient = DependencyContainer.shared.resolve(),
        parser: APIParser = DefaultAPIParser.shared,
        authSessionRepository: AuthSessionRepository = DependencyContainer.shared.resolve()
    ) {
        self.httpClient = httpClient
        self.parser = parser
        self.authSessionRepository = authSessionRepository
    }

    func fetchSettingsContext() async throws -> ClimateSettingsContext {
        let uid = try await resolveCurrentUid()

        async let profileResponse = request(
            ClimateProfileResponse.self,
            path: "/v1/users/\(uid)/climate/profile",
            method: .GET
        )
        async let metricsResponse = request(
            ClimateAdaptationMetricsResponse.self,
            path: "/v1/users/\(uid)/climate/adaptation-metrics",
            method: .GET
        )

        let (profile, metrics) = try await (profileResponse, metricsResponse)
        return ClimateSettingsContext(profile: profile, metrics: metrics)
    }

    func updateSettings(_ payload: ClimateSettingsPayload) async throws {
        let uid = try await resolveCurrentUid()
        let body = try JSONEncoder().encode(payload)
        _ = try await httpClient.request(
            path: "/v1/users/\(uid)/climate/settings",
            method: .PUT,
            body: body
        )
    }

    private func request<T: Codable>(_ type: T.Type, path: String, method: HTTPMethod) async throws -> T {
        let rawData = try await httpClient.request(path: path, method: method, body: nil)
        return try ResponseProcessor.extractData(type, from: rawData, using: parser)
    }

    private func resolveCurrentUid() async throws -> String {
        if let uid = authSessionRepository.getCurrentUser()?.uid {
            return uid
        }

        let currentUser = try await authSessionRepository.fetchCurrentUser()
        return currentUser.uid
    }
}

private final class ClimateSettingsRepositoryImpl: ClimateSettingsRepository {
    private let remoteDataSource: ClimateSettingsRemoteDataSource

    init(remoteDataSource: ClimateSettingsRemoteDataSource = ClimateSettingsRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchSettingsContext() async throws -> ClimateSettingsContext {
        try await remoteDataSource.fetchSettingsContext()
    }

    func updateSettings(_ payload: ClimateSettingsPayload) async throws {
        try await remoteDataSource.updateSettings(payload)
    }
}

@MainActor
private final class ClimateSettingsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var profile: ClimateProfileResponse?
    @Published var metrics: ClimateAdaptationMetricsResponse?
    @Published var enabled = false
    @Published var adaptationLevel = "normal"
    @Published var useManualThreshold = false
    @Published var manualThreshold = 27.0

    private let repository: ClimateSettingsRepository

    init(repository: ClimateSettingsRepository = ClimateSettingsRepositoryImpl()) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let context = try await repository.fetchSettingsContext()
            apply(profile: context.profile, metrics: context.metrics)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = ClimateSettingsPayload(
            enabled: enabled,
            adaptationLevel: adaptationLevel,
            manualStartThresholdC: useManualThreshold ? manualThreshold : nil,
            regionKey: profile?.settings.regionKey,
            presets: nil,
            createdAt: nil,
            updatedAt: nil
        )

        do {
            try await repository.updateSettings(payload)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(profile: ClimateProfileResponse, metrics: ClimateAdaptationMetricsResponse) {
        self.profile = profile
        self.metrics = metrics
        enabled = profile.settings.enabled
        ClimateAdjustmentSyncStore.setEnabled(profile.settings.enabled)
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
                    ProgressView(climateLocalized("climate_settings.loading"))
                }
            }
            .navigationTitle(climateLocalized("climate_settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(climateLocalized("common.close")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button(climateLocalized("common.save")) {
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
                    Text(climateLocalized("climate_settings.enable_title"))
                        .font(.headline)
                    Text(climateLocalized("climate_settings.feels_like_subtitle"))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(toggleStatusDescription(profile))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text(climateLocalized("climate_settings.effective_notice"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func currentStatusSection(_ profile: ClimateProfileResponse) -> some View {
        Section(climateLocalized("climate_settings.current_status.section")) {
            if let currentStatus = profile.heatProfile.currentStatus {
                statusRow(
                    climateLocalized("climate_settings.current_status.is_adjusted"),
                    currentStatus.isAdjusted ? climateLocalized("climate_settings.current_status.adjusted") : climateLocalized("climate_settings.current_status.not_adjusted")
                )

                if let feelsLike = currentStatus.feelsLikeTempC {
                    statusRow(climateLocalized("climate_settings.current_status.feels_like"), String(format: "%.1f°C", feelsLike))
                }

                statusRow(climateLocalized("climate_settings.current_status.pace_adjustment"), currentStatusPaceText(currentStatus))

                if let longRunText = currentStatusLongRunText(currentStatus) {
                    statusRow(climateLocalized("climate_settings.current_status.long_run_adjustment"), longRunText)
                }

                if let statusText = currentStatus.statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                statusRow(climateLocalized("climate_settings.your_setting"), profile.heatProfile.uiSummary.currentSettingLabel)
                statusRow(climateLocalized("climate_settings.adjustment_start"), "\(Int(profile.heatProfile.uiSummary.adjustmentStartTempC))°C")
                statusRow(climateLocalized("climate_settings.common_adjustment"), primaryAdjustmentPreview(profile))
                Text(climateLocalized("climate_settings.current_status.unavailable"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func controlsSection(_ profile: ClimateProfileResponse) -> some View {
        Section {
            Picker(climateLocalized("climate_settings.adaptation_level"), selection: $viewModel.adaptationLevel) {
                Text(climateLocalized("climate_settings.adaptation.unacclimated")).tag("unacclimated")
                Text(climateLocalized("climate_settings.adaptation.normal")).tag("normal")
                Text(climateLocalized("climate_settings.adaptation.acclimated")).tag("acclimated")
            }

            Toggle(climateLocalized("climate_settings.manual_threshold.toggle"), isOn: $viewModel.useManualThreshold)

            if viewModel.useManualThreshold {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(climateLocalized("climate_settings.manual_threshold.start_temp"))
                        Spacer()
                        Text(String(format: "%.1f°C", viewModel.manualThreshold))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.manualThreshold, in: 24...30, step: 0.5)
                    Text(String(format: climateLocalized("climate_settings.manual_threshold.danger_fixed_format"), Int(profile.heatProfile.uiSummary.dangerTempC)))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(climateLocalized("climate_settings.your_setting"))
        } footer: {
            Text(climateLocalized("climate_settings.future_only_footer"))
        }
    }

    @ViewBuilder
    private var explanationEntrySection: some View {
        Section {
            Button {
                showExplanation = true
            } label: {
                HStack {
                    Text(climateLocalized("climate_settings.explanation.open"))
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
        profile.heatProfile.interventionRules.compactMap(\.paceText).first ?? climateLocalized("climate_settings.not_available")
    }

    private func toggleStatusDescription(_ profile: ClimateProfileResponse) -> String {
        if viewModel.enabled {
            return climateLocalized("climate_settings.enabled_description")
        }
        return climateLocalized("climate_settings.disabled_description")
    }

    private func currentStatusPaceText(_ currentStatus: ClimateCurrentStatus) -> String {
        guard currentStatus.isAdjusted else { return "0%" }
        guard let paceAdjustmentPct = currentStatus.paceAdjustmentPct else { return climateLocalized("climate_settings.current_status.adjusted") }
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
                Section(climateLocalized("climate_settings.explanation.how_it_works")) {
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

                Section(climateLocalized("climate_settings.explanation.intervention_rules")) {
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
                    Section(climateLocalized("climate_settings.metrics.section")) {
                        LabeledContent(climateLocalized("climate_settings.metrics.recommended"), value: localizedAdaptation(metrics.recommendedAdaptationLevel))
                        LabeledContent(climateLocalized("climate_settings.metrics.current"), value: localizedAdaptation(metrics.currentAdaptationLevel))
                        LabeledContent(climateLocalized("climate_settings.metrics.hot_hours"), value: String(format: "%.1f h", metrics.indicators.hotTrainingHours14d))
                        LabeledContent(climateLocalized("climate_settings.metrics.hot_workouts"), value: String(format: climateLocalized("climate_settings.metrics.workout_count_format"), metrics.indicators.hotWorkoutCount14d))
                        LabeledContent(climateLocalized("climate_settings.metrics.pace_achievement"), value: percentText(metrics.indicators.hotPaceAchievementRatePct))
                        LabeledContent(climateLocalized("climate_settings.metrics.hr_efficiency"), value: localizedTrend(metrics.indicators.hotHrEfficiencyTrend))
                        if let delta = metrics.indicators.hotHrEfficiencyDeltaPct {
                            LabeledContent(climateLocalized("climate_settings.metrics.efficiency_change"), value: String(format: "%.1f%%", delta))
                        }
                        if metrics.dataInsufficient, let reason = metrics.dataInsufficientReason {
                            Text(reason)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(climateLocalized("climate_settings.source.section")) {
                    LabeledContent(climateLocalized("climate_settings.source.region_strategy"), value: profile.adapter.displayName)
                    LabeledContent(climateLocalized("climate_settings.source.weather_source"), value: profile.adapter.dataSource)
                    Text(profile.heatProfile.uiSummary.sourceDisclosure)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(climateLocalized("climate_settings.explanation.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(climateLocalized("common.close")) { dismiss() }
                }
            }
        }
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return climateLocalized("climate_settings.insufficient_data") }
        return String(format: "%.1f%%", value)
    }

    private func localizedAdaptation(_ value: String) -> String {
        switch value {
        case "unacclimated": return climateLocalized("climate_settings.adaptation.unacclimated")
        case "acclimated": return climateLocalized("climate_settings.adaptation.acclimated")
        default: return climateLocalized("climate_settings.adaptation.normal")
        }
    }

    private func localizedTrend(_ value: String) -> String {
        switch value {
        case "improving": return climateLocalized("climate_settings.trend.improving")
        case "declining": return climateLocalized("climate_settings.trend.declining")
        case "stable": return climateLocalized("climate_settings.trend.stable")
        default: return climateLocalized("climate_settings.insufficient_data")
        }
    }
}

#Preview {
    ClimateSettingsView()
}
