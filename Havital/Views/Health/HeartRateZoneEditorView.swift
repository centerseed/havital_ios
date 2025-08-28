import SwiftUI

/// 簡化的心率區間編輯視圖，使用心率儲備計算法
struct HRRHeartRateZoneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingMaxHRInfo = false
    @State private var showingRestingHRInfo = false
    
    private let userPreferenceManager = UserPreferenceManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("hr_zone.settings", comment: "Heart Rate Zone Settings"))) {
                    Text(NSLocalizedString("hr_zone.description", comment: "Heart rate zone description"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                
                Section(header: Text(NSLocalizedString("hr_zone.max_hr", comment: "Max Heart Rate"))) {
                    HStack {
                        TextField(NSLocalizedString("hr_zone.max_hr_placeholder", comment: "Max Heart Rate (bpm)"), text: $maxHeartRate)
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            showingMaxHRInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .onAppear {
                        if let maxHR = userPreferenceManager.maxHeartRate, maxHR > 0 {
                            maxHeartRate = "\(maxHR)"
                        } else {
                            maxHeartRate = "190"
                        }
                    }
                }
                
                Section(header: Text(NSLocalizedString("hr_zone.resting_hr", comment: "Resting Heart Rate"))) {
                    HStack {
                        TextField(NSLocalizedString("hr_zone.resting_hr_placeholder", comment: "Resting Heart Rate (bpm)"), text: $restingHeartRate)
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            showingRestingHRInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .onAppear {
                        if let restingHR = userPreferenceManager.restingHeartRate, restingHR > 0 {
                            restingHeartRate = "\(restingHR)"
                        } else {
                            restingHeartRate = "60"
                        }
                    }
                }
                
                // 心率區間預覽
                if let maxHR = Int(maxHeartRate), let restingHR = Int(restingHeartRate),
                    maxHR > restingHR, maxHR > 0, restingHR > 0 {
                    Section(header: Text(NSLocalizedString("hr_zone.preview", comment: "Heart Rate Zone Preview"))) {
                        let zones = HeartRateZonesManager.shared.calculateHeartRateZones(maxHR: maxHR, restingHR: restingHR)
                        
                        ForEach(zones, id: \.zone) { zone in
                            HStack {
                                Text(String(format: NSLocalizedString("hr_zone.zone", comment: "Zone info"), zone.zone, zone.name))
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(Int(zone.range.lowerBound.rounded()))-\(Int(zone.range.upperBound.rounded())) bpm")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: saveHeartRateZones) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(NSLocalizedString("hr_zone.save_settings", comment: "Save Settings"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isLoading || maxHeartRate.isEmpty || restingHeartRate.isEmpty)
                }
            }
            .navigationTitle(NSLocalizedString("hr_zone.settings", comment: "Heart Rate Zone Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        dismiss()
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
        
        if restingHR < 30 || restingHR > 100 {
            alertMessage = NSLocalizedString("hr_zone.resting_hr_range", comment: "Resting HR range")
            showingAlert = true
            return
        }
        
        isLoading = true
        
        // 更新本地數據
        userPreferenceManager.updateHeartRateData(maxHR: maxHR, restingHR: restingHR)
        
        // 發送到後端 API
        Task {
            do {
                let userData = [
                    "max_hr": maxHR,
                    "relaxing_hr": restingHR
                ] as [String : Any]
                
                try await UserService.shared.updateUserData(userData)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = String(format: NSLocalizedString("hr_zone.save_failed", comment: "Save failed"), error.localizedDescription)
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    HRRHeartRateZoneEditorView()
}
