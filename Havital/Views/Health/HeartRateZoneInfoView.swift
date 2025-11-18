import SwiftUI

// MARK: - Display Mode Enum
enum HeartRateViewMode {
    case onboarding(targetDistance: Double) // Onboarding 模式，包含目標距離用於導航
    case profile // Profile 模式
}

struct HeartRateZoneInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var maxHeartRate: Int = 190
    @State private var restingHeartRate: Int = 60
    @State private var zones: [HeartRateZonesManager.HeartRateZone] = []
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    @State private var navigateToPersonalBest = false

    private let userPreferenceManager = UserPreferenceManager.shared
    private let mode: HeartRateViewMode

    // MARK: - Initializers
    init(mode: HeartRateViewMode = .profile) {
        self.mode = mode
    }

    // MARK: - Computed Properties
    private var isOnboardingMode: Bool {
        if case .onboarding = mode {
            return true
        }
        return false
    }

    private var targetDistance: Double? {
        if case .onboarding(let distance) = mode {
            return distance
        }
        return nil
    }

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .toolbar {
                    if isOnboardingMode {
                        ToolbarItem(placement: .bottomBar) {
                            skipButton
                        }
                    }
                }
                .alert(NSLocalizedString("common.confirm", comment: "Confirm"), isPresented: $showingAlert) {
                    Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
                .task {
                    await loadZoneData()
                }
                .background(navigationLinkView)
        }
    }

    // MARK: - View Components
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                descriptionText
                heartRateSettingsView
                if !isOnboardingMode {
                    Divider()
                        .padding(.horizontal)
                    heartRateZoneDetailsView
                }
            }
        }
        .background(Color(UIColor.systemBackground)) // 確保有不透明的背景
    }

    @ViewBuilder
    private var descriptionText: some View {
        Text(isOnboardingMode ?
             NSLocalizedString("onboarding.heart_rate_description", comment: "Heart rate description") :
             NSLocalizedString("hr_zone.description", comment: "Heart rate zone description"))
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.top)
    }

    @ViewBuilder
    private var heartRateSettingsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !isOnboardingMode {
                editToggleHeader
            }

            if isEditing || isOnboardingMode {
                editModeContent
            } else {
                displayModeContent
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var editToggleHeader: some View {
        HStack {
            Text(NSLocalizedString("hr_zone.current_settings", comment: "Current Settings"))
                .font(.headline)

            Spacer()

            Button(isEditing ? NSLocalizedString("common.cancel", comment: "Cancel") : NSLocalizedString("common.edit", comment: "Edit")) {
                if isEditing {
                    loadCurrentValues()
                }
                isEditing.toggle()
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var editModeContent: some View {
        VStack(spacing: 20) {
            maxHeartRateEditor
            Divider().padding(.horizontal)
            restingHeartRateEditor

            if !isOnboardingMode {
                Button(action: { Task { await saveHeartRateZones() } }) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text(NSLocalizedString("hr_zone.save_settings", comment: "Save Settings"))
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(isSaving)
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var maxHeartRateEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("hr_zone.max_hr", comment: "Max Heart Rate"))
                        .font(.headline)

                    Text(NSLocalizedString("hr_zone.max_hr_info_message", comment: "Max HR info message"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                HStack(spacing: 4) {
                    Picker("", selection: $maxHeartRate) {
                        ForEach(100...250, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text("bpm")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }

            // 添加 220-年齡 公式提示
            Text(NSLocalizedString("hr_zone.max_hr_formula_hint", comment: "Tip: You can estimate your max heart rate using the formula: 220 - age"))
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .italic()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var restingHeartRateEditor: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("hr_zone.resting_hr", comment: "Resting Heart Rate"))
                    .font(.headline)

                Text(NSLocalizedString("hr_zone.resting_hr_info_message", comment: "Resting HR info message"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                Picker("", selection: $restingHeartRate) {
                    ForEach(30...120, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)

                Text("bpm")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var displayModeContent: some View {
        HStack {
            Text(NSLocalizedString("hr_zone.max_heart_rate_display", comment: "Max Heart Rate"))
                .font(.subheadline)
            Spacer()
            Text("\(maxHeartRate) bpm")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)

        HStack {
            Text(NSLocalizedString("hr_zone.resting_heart_rate_display", comment: "Resting Heart Rate"))
                .font(.subheadline)
            Spacer()
            Text("\(restingHeartRate) bpm")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var heartRateZoneDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("hr_zone.details", comment: "Heart Rate Zone Details"))
                .font(.headline)
                .padding(.horizontal)

            if isLoading {
                ProgressView(NSLocalizedString("hr_zone.loading", comment: "Loading..."))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(zones, id: \.zone) { zone in
                    zoneDetailRow(zone: zone)
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func zoneDetailRow(zone: HeartRateZonesManager.HeartRateZone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(format: NSLocalizedString("hr_zone.zone", comment: "Zone info"), zone.zone, zone.name))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(Int(zone.range.lowerBound.rounded()))-\(Int(zone.range.upperBound.rounded())) bpm")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }

            Text(zone.description)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(String(format: NSLocalizedString("hr_zone.benefit", comment: "Benefit"), zone.benefit))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(zoneColor(for: zone.zone).opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var navigationTitle: String {
        isOnboardingMode ?
            NSLocalizedString("onboarding.heart_rate_title", comment: "Heart Rate Settings") :
            NSLocalizedString("hr_zone.info", comment: "Heart Rate Zone Info")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isOnboardingMode {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.back", comment: "Back"))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { await saveHeartRateZones() }
                }) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(NSLocalizedString("onboarding.next", comment: "Next"))
                    }
                }
                .disabled(isSaving)
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var skipButton: some View {
        Button(action: {
            navigateToPersonalBest = true
        }) {
            Text(NSLocalizedString("onboarding.skip_heart_rate", comment: "Skip (Use Default Values)"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var navigationLinkView: some View {
        if isOnboardingMode, let distance = targetDistance {
            NavigationLink(
                destination: PersonalBestView(targetDistance: distance)
                    .navigationBarBackButtonHidden(true),
                isActive: $navigateToPersonalBest
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    // MARK: - Private Functions
    private func loadZoneData() async {
        isLoading = true

        await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
        loadCurrentValues()

        if !isOnboardingMode {
            zones = HeartRateZonesManager.shared.getHeartRateZones()
        }

        if isOnboardingMode {
            isEditing = true
        }

        isLoading = false
    }

    private func loadCurrentValues() {
        if let maxHR = userPreferenceManager.maxHeartRate {
            maxHeartRate = maxHR
        } else {
            maxHeartRate = 190
        }

        if let restingHR = userPreferenceManager.restingHeartRate {
            restingHeartRate = restingHR
        } else {
            restingHeartRate = 60
        }
    }

    private func saveHeartRateZones() async {
        if maxHeartRate <= restingHeartRate {
            alertMessage = NSLocalizedString("hr_zone.max_greater_than_resting", comment: "Max greater than resting")
            showingAlert = true
            return
        }

        if maxHeartRate > 250 || maxHeartRate < 100 {
            alertMessage = NSLocalizedString("hr_zone.max_hr_range", comment: "Max HR range")
            showingAlert = true
            return
        }

        if restingHeartRate < 30 || restingHeartRate > 120 {
            alertMessage = NSLocalizedString("hr_zone.resting_hr_range", comment: "Resting HR range")
            showingAlert = true
            return
        }

        isSaving = true

        userPreferenceManager.updateHeartRateData(maxHR: maxHeartRate, restingHR: restingHeartRate)

        do {
            let userData = [
                "max_hr": maxHeartRate,
                "relaxing_hr": restingHeartRate
            ] as [String : Any]

            try await UserService.shared.updateUserData(userData)

            await MainActor.run {
                isSaving = false
                if isOnboardingMode {
                    navigateToPersonalBest = true
                } else {
                    isEditing = false
                }
            }

            if !isOnboardingMode {
                await loadZoneData()
            }

        } catch {
            await MainActor.run {
                isSaving = false
                alertMessage = String(format: NSLocalizedString("hr_zone.save_failed", comment: "Save failed"), error.localizedDescription)
                showingAlert = true
            }
        }
    }

    private func zoneColor(for zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Previews
#Preview("Profile Mode") {
    HeartRateZoneInfoView(mode: .profile)
}

#Preview("Onboarding Mode") {
    HeartRateZoneInfoView(mode: .onboarding(targetDistance: 42.195))
}
