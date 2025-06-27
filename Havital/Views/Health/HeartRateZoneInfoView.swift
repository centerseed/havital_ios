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
                    // 說明文字
                    Text("心率區間使用心率儲備（HRR）方法計算，提供更個人化的訓練強度區間。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // 心率設定資訊
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("目前設定")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(isEditing ? "取消" : "編輯") {
                                if isEditing {
                                    // 取消編輯，恢復原始值
                                    loadCurrentValues()
                                }
                                isEditing.toggle()
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        if isEditing {
                            // 編輯模式
                            VStack(spacing: 12) {
                                HStack {
                                    Text("最大心率")
                                        .font(.subheadline)
                                    Spacer()
                                    TextField("最大心率 (bpm)", text: $maxHeartRate)
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
                                    Text("靜息心率")
                                        .font(.subheadline)
                                    Spacer()
                                    TextField("靜息心率 (bpm)", text: $restingHeartRate)
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
                                        Text("儲存設定")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .disabled(isSaving || maxHeartRate.isEmpty || restingHeartRate.isEmpty)
                                .padding(.horizontal)
                            }
                        } else {
                            // 顯示模式
                            HStack {
                                Text("最大心率")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(maxHeartRate) bpm")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            HStack {
                                Text("靜息心率")
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
                    
                    // 心率區間詳情
                    VStack(alignment: .leading, spacing: 8) {
                        Text("心率區間詳情")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView("載入中...")
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ForEach(zones, id: \.zone) { zone in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("區間 \(zone.zone): \(zone.name)")
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
                                    
                                    Text("好處: \(zone.benefit)")
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
            .navigationTitle("心率區間資訊")
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
            .alert("提示", isPresented: $showingAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("最大心率", isPresented: $showingMaxHRInfo) {
                Button("了解", role: .cancel) { }
            } message: {
                Text("最大心率是您在極限運動時能達到的最高心率。\n\n一般可以使用 220-年齡 的公式來估算，但實際值可能因人而異。\n\n建議範圍：100-250 bpm")
            }
            .alert("靜息心率", isPresented: $showingRestingHRInfo) {
                Button("了解", role: .cancel) { }
            } message: {
                Text("靜息心率是您完全放鬆時（如剛起床時）測量到的心率。\n\n一般成人的靜息心率在 60-100 bpm 之間，運動員可能更低。\n\n建議範圍：30-120 bpm")
            }
            .task {
                await loadZoneData()
            }
        }
    }
    
    private func loadZoneData() async {
        isLoading = true
        
        // 確保區間資料已計算
        await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
        
        // 獲取心率數據
        loadCurrentValues()
        
        // 獲取心率區間
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
        
        isSaving = true
        
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
                    isSaving = false
                    isEditing = false
                }
                
                // 重新載入數據以更新顯示
                await loadZoneData()
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = "儲存失敗: \(error.localizedDescription)"
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
