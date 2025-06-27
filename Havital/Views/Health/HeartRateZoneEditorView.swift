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
                Section(header: Text("心率區間設定")) {
                    Text("心率區間使用心率儲備（HRR）方法計算，提供更個人化的訓練強度區間。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                
                Section(header: Text("最大心率")) {
                    HStack {
                        TextField("最大心率 (bpm)", text: $maxHeartRate)
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
                
                Section(header: Text("靜息心率")) {
                    HStack {
                        TextField("靜息心率 (bpm)", text: $restingHeartRate)
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
                    Section(header: Text("心率區間預覽")) {
                        let zones = HeartRateZonesManager.shared.calculateHeartRateZones(maxHR: maxHR, restingHR: restingHR)
                        
                        ForEach(zones, id: \.zone) { zone in
                            HStack {
                                Text("區間 \(zone.zone): \(zone.name)")
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
                            Text("儲存設定")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isLoading || maxHeartRate.isEmpty || restingHeartRate.isEmpty)
                }
            }
            .navigationTitle("心率區間設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("最大心率", isPresented: $showingMaxHRInfo) {
                Button("了解", role: .cancel) { }
            } message: {
                Text("最大心率是您在極限運動時能達到的最高心率。\n\n一般可以使用 220-年齡 的公式來估算，但實際值可能因人而異。\n\n建議範圍：100-220 bpm")
            }
            .alert("靜息心率", isPresented: $showingRestingHRInfo) {
                Button("了解", role: .cancel) { }
            } message: {
                Text("靜息心率是您完全放鬆時（如剛起床時）測量到的心率。\n\n一般成人的靜息心率在 50-80 bpm 之間，運動員可能更低。\n\n建議範圍：30-80 bpm")
            }
        }
    }
    
    private func saveHeartRateZones() {
        guard let maxHR = Int(maxHeartRate), let restingHR = Int(restingHeartRate) else {
            alertMessage = "請輸入有效的心率數值"
            showingAlert = true
            return
        }
        
        // 驗證輸入值
        if maxHR <= restingHR {
            alertMessage = "最大心率必須大於靜息心率"
            showingAlert = true
            return
        }
        
        if maxHR > 250 || maxHR < 100 {
            alertMessage = "最大心率應在 100-250 bpm 之間"
            showingAlert = true
            return
        }
        
        if restingHR < 30 || restingHR > 100 {
            alertMessage = "靜息心率應在 30-100 bpm 之間"
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
                    alertMessage = "儲存失敗: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    HRRHeartRateZoneEditorView()
}
