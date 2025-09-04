import SwiftUI

struct HeartRateZoneInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = ""
    @State private var zones: [HeartRateZonesManager.HeartRateZone] = []
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingMaxHRInfo = false
    @State private var showingRestingHRInfo = false
    @State private var isSaving = false
    
    private let userPreferenceManager = UserPreferenceManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Description text
                    Text(NSLocalizedString("hr_zone.description", comment: "Heart rate zone description"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Heart rate settings information
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("hr_zone.current_settings", comment: "Current Settings"))
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(isEditing ? NSLocalizedString("common.cancel", comment: "Cancel") : NSLocalizedString("common.edit", comment: "Edit")) {
                                if isEditing {
                                    // Cancel editing, restore original values
                                    loadCurrentValues()
                                }
                                isEditing.toggle()
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        if isEditing {
                            // Edit mode
                            VStack(spacing: 12) {
                                HStack {
                                    Text(NSLocalizedString("hr_zone.max_hr", comment: "Max Heart Rate"))
                                        .font(.subheadline)
                                    Spacer()
                                    TextField(NSLocalizedString("hr_zone.max_hr_placeholder", comment: "Max Heart Rate (bpm)"), text: $maxHeartRate)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                    
                                    Button(action: {
                                        showingMaxHRInfo = true
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Text(NSLocalizedString("hr_zone.resting_hr", comment: "Resting Heart Rate"))
                                        .font(.subheadline)
                                    Spacer()
                                    TextField(NSLocalizedString("hr_zone.resting_hr_placeholder", comment: "Resting Heart Rate (bpm)"), text: $restingHeartRate)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                    
                                    Button(action: {
                                        showingRestingHRInfo = true
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                                
                                Button(action: saveHeartRateZones) {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Text(NSLocalizedString("hr_zone.save_settings", comment: "Save Settings"))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .disabled(isSaving || maxHeartRate.isEmpty || restingHeartRate.isEmpty)
                                .padding(.horizontal)
                            }
                        } else {
                            // Display mode
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
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Heart rate zone details
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("hr_zone.details", comment: "Heart Rate Zone Details"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView(NSLocalizedString("hr_zone.loading", comment: "Loading..."))
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ForEach(zones, id: \.zone) { zone in
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
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(NSLocalizedString("hr_zone.info", comment: "Heart Rate Zone Info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert(NSLocalizedString("common.confirm", comment: "Confirm"), isPresented: $showingAlert) {
                Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert(NSLocalizedString("hr_zone.max_hr_info_title", comment: "Max Heart Rate"), isPresented: $showingMaxHRInfo) {
                Button(NSLocalizedString("hr_zone.understand", comment: "Understand"), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("hr_zone.max_hr_info_message", comment: "Max HR info message"))
            }
            .alert(NSLocalizedString("hr_zone.resting_hr_info_title", comment: "Resting Heart Rate"), isPresented: $showingRestingHRInfo) {
                Button(NSLocalizedString("hr_zone.understand", comment: "Understand"), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("hr_zone.resting_hr_info_message", comment: "Resting HR info message"))
            }
            .task {
                await loadZoneData()
            }
        }
    }
    
    private func loadZoneData() async {
        isLoading = true

        // Ensure zone data is calculated
        await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()

        // Load heart rate data
        loadCurrentValues()

        // Get heart rate zones
        zones = HeartRateZonesManager.shared.getHeartRateZones()

        isLoading = false
    }
    
    private func loadCurrentValues() {
        if let maxHR = userPreferenceManager.maxHeartRate {
            maxHeartRate = "\(maxHR)"
        } else {
            maxHeartRate = "190"
        }
        
        if let restingHR = userPreferenceManager.restingHeartRate {
            restingHeartRate = "\(restingHR)"
        } else {
            restingHeartRate = "60"
        }
    }
    
    private func saveHeartRateZones() {
        guard let maxHR = Int(maxHeartRate), let restingHR = Int(restingHeartRate) else {
            alertMessage = NSLocalizedString("hr_zone.invalid_input", comment: "Invalid input")
            showingAlert = true
            return
        }
        
        // 驗證輸入值
        if maxHR <= restingHR {
            alertMessage = NSLocalizedString("hr_zone.max_greater_than_resting", comment: "Max greater than resting")
            showingAlert = true
            return
        }
        
        if maxHR > 250 || maxHR < 100 {
            alertMessage = NSLocalizedString("hr_zone.max_hr_range", comment: "Max HR range")
            showingAlert = true
            return
        }
        
        if restingHR < 30 || restingHR > 120 {
            alertMessage = NSLocalizedString("hr_zone.resting_hr_range", comment: "Resting HR range")
            showingAlert = true
            return
        }
        
        isSaving = true

        // Update local data
        userPreferenceManager.updateHeartRateData(maxHR: maxHR, restingHR: restingHR)

        // Send to backend API
        Task {
            do {
                let userData = [
                    "max_hr": maxHR,
                    "relaxing_hr": restingHR
                ] as [String : Any]

                try await UserService.shared.updateUserData(userData)

                await MainActor.run {
                    isSaving = false
                    isEditing = false
                }

                // Reload data to update display
                await loadZoneData()

            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = String(format: NSLocalizedString("hr_zone.save_failed", comment: "Save failed"), error.localizedDescription)
                    showingAlert = true
                }
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

#Preview {
    HeartRateZoneInfoView()
}
