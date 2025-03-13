import SwiftUI

/// 更新的心率區間編輯視圖，使用心率儲備計算法
struct HRRHeartRateZoneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // 用於計算預估最大心率的年齡
    @State private var age: String = ""
    
    private let userPreferenceManager = UserPreferenceManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("心率區間設定")) {
                    Text("心率區間使用心率儲備（HRR）方法計算，這提供了更個人化的訓練強度區間。計算公式為：區間心率 = 靜息心率 + (最大心率 - 靜息心率) × 區間百分比")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                
                Section(header: Text("最大心率")) {
                    TextField("最大心率 (bpm)", text: $maxHeartRate)
                        .onAppear {
                            if let maxHR = userPreferenceManager.maxHeartRate, maxHR > 0 {
                                maxHeartRate = "\(maxHR)"
                            } else {
                                maxHeartRate = "190"
                            }
                        }
                        .keyboardType(.numberPad)
                    
                    Text("最大心率是您在極限運動時能達到的最高心率。如果不確定，可以使用 220-年齡 的公式來估算。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    // 年齡輸入
                    HStack {
                        Text("年齡")
                        Spacer()
                        TextField("年齡", text: $age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    
                    Button("根據年齡計算") {
                        calculateMaxHRFromAge()
                    }
                }
                
                Section(header: Text("靜息心率")) {
                    TextField("靜息心率 (bpm)", text: $restingHeartRate)
                        .onAppear {
                            if let restingHR = userPreferenceManager.restingHeartRate, restingHR > 0 {
                                restingHeartRate = "\(restingHR)"
                            } else {
                                restingHeartRate = "60"
                            }
                        }
                        .keyboardType(.numberPad)
                    
                    Text("靜息心率是您完全放鬆時（如剛起床時）測量到的心率。一般成人的靜息心率在 60-100 bpm 之間，運動員可能更低。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
        }
    }
    
    // 根據年齡計算最大心率
    private func calculateMaxHRFromAge() {
        guard let ageValue = Int(age), ageValue > 0, ageValue < 120 else {
            alertMessage = "請輸入有效的年齡（1-120）"
            showingAlert = true
            return
        }
        
        // 使用 220-年齡 公式
        let calculatedMaxHR = 220 - ageValue
        maxHeartRate = "\(calculatedMaxHR)"
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
        
        if restingHR < 30 || restingHR > 120 {
            alertMessage = "靜息心率應在 30-120 bpm 之間"
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
