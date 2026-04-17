import SwiftUI

/// 簡化的心率區間編輯視圖，使用心率儲備計算法
struct HRRHeartRateZoneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UserProfileFeatureViewModel()
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("hr_zone.settings", comment: "Heart Rate Zone Settings"))) {
                    Text(NSLocalizedString("hr_zone.description", comment: "Heart rate zone description"))
                        .font(AppFont.footnote())
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("hr_zone.max_hr", comment: "Max Heart Rate"))
                                    .font(AppFont.headline())

                                Text(NSLocalizedString("hr_zone.max_hr_info_message", comment: "Max HR info message"))
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Spacer()

                            HStack(spacing: 4) {
                                TextField("", text: $maxHeartRate)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)

                                Text("bpm")
                                    .foregroundColor(.secondary)
                                    .font(AppFont.bodySmall())
                            }
                        }
                    }
                    .onAppear {
                        if let maxHR = viewModel.maxHeartRate, maxHR > 0 {
                            maxHeartRate = "\(maxHR)"
                        } else {
                            maxHeartRate = "190"
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("hr_zone.resting_hr", comment: "Resting Heart Rate"))
                                    .font(AppFont.headline())

                                Text(NSLocalizedString("hr_zone.resting_hr_info_message", comment: "Resting HR info message"))
                                    .font(AppFont.caption())
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Spacer()

                            HStack(spacing: 4) {
                                TextField("", text: $restingHeartRate)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)

                                Text("bpm")
                                    .foregroundColor(.secondary)
                                    .font(AppFont.bodySmall())
                            }
                        }
                    }
                    .onAppear {
                        if let restingHR = viewModel.restingHeartRate, restingHR > 0 {
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
                        // Use HeartRateZone entity directly instead of deprecated HeartRateZonesManager
                        let zones = HeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)
                        
                        ForEach(zones, id: \.zone) { zone in
                            HStack {
                                Text(String(format: NSLocalizedString("hr_zone.zone", comment: "Zone info"), zone.zone, zone.name))
                                    .font(AppFont.bodySmall())
                                
                                Spacer()
                                
                                Text("\(Int(zone.range.lowerBound.rounded()))-\(Int(zone.range.upperBound.rounded())) bpm")
                                    .font(AppFont.bodySmall())
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
        viewModel.updateHeartRateData(maxHR: maxHR, restingHR: restingHR)
        
        // 發送到後端 API (using ViewModel → Repository)
        Task {
            let userData = [
                "max_hr": maxHR,
                "relaxing_hr": restingHR
            ] as [String : Any]

            let success = await viewModel.updateUserProfile(userData)

            await MainActor.run {
                isLoading = false
                if success {
                    dismiss()
                } else {
                    alertMessage = NSLocalizedString("hr_zone.save_failed_generic", comment: "Failed to save heart rate zones")
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    HRRHeartRateZoneEditorView()
}
