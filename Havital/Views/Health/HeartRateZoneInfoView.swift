import SwiftUI

struct HeartRateZoneInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = ""
    @State private var zones: [HeartRateZonesManager.HeartRateZone] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 說明文字
                    Text("心率區間使用心率儲備（HRR）方法計算，這提供了更個人化的訓練強度區間。計算公式為：區間心率 = 靜息心率 + (最大心率 - 靜息心率) × 區間百分比")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // 心率設定資訊
                    VStack(alignment: .leading, spacing: 8) {
                        Text("目前設定")
                            .font(.headline)
                            .padding(.horizontal)
                        
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
                                            .foregroundColor(.secondary)
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        HRRHeartRateZoneEditorView()
                    } label: {
                        Text("編輯")
                    }
                }
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
        if let maxHR = UserPreferenceManager.shared.maxHeartRate {
            maxHeartRate = "\(maxHR)"
        } else {
            maxHeartRate = "未設定"
        }
        
        if let restingHR = UserPreferenceManager.shared.restingHeartRate {
            restingHeartRate = "\(restingHR)"
        } else {
            restingHeartRate = "未設定"
        }
        
        // 獲取心率區間
        zones = HeartRateZonesManager.shared.getHeartRateZones()
        
        isLoading = false
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
