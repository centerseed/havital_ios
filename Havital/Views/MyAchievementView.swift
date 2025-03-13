import SwiftUI
import Charts
import HealthKit

struct SectionTitleWithInfo: View {
    let title: String
    let explanation: String
    @State private var showingInfo = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
            
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .alert(title, isPresented: $showingInfo) {
                Button("了解", role: .cancel) {}
            } message: {
                Text(explanation)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct MyAchievementView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 心率區間設定
                    HeartRateZonesSettingsView()
                        .environmentObject(healthKitManager)
                        .padding(.horizontal)
                                        
                    // 使用 HRR 方法的心率區間分析
                    WeeklyHeartRateAnalysisViewHRR()
                        .environmentObject(healthKitManager)
                        .padding(.horizontal)
                                        
                    // 體能表現趨勢
                    VStack(alignment: .leading) {
                        SectionTitleWithInfo(
                            title: "體能表現趨勢",
                            explanation: "體能表現趨勢反映了你的運動強度和恢復狀況。通常運動日當天會累積疲勞，訓練表現分數會下降。而透過休息讓身體恢復，預期的表現分數會上升。\n 透過持續且強度適中的運動，整體的表現趨勢會上升。"
                        )
                                            
                        PerformanceChartView()
                            .environmentObject(healthKitManager)
                            .frame(height: 250)
                            .padding()
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 1)
                        .padding(.horizontal)
                    
                    // HRV 趨勢圖
                    VStack(alignment: .leading) {
                        SectionTitleWithInfo(
                            title: "心率變異性 (HRV) 趨勢",
                            explanation: "心率變異性（HRV）是衡量身體恢復能力和壓力水平的重要指標。較高的HRV通常表示更好的恢復能力和較低的壓力水平。"
                        )
                        
                        HRVTrendChartView()
                            .environmentObject(healthKitManager)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                    
                    // 睡眠靜息心率圖
                    VStack(alignment: .leading) {
                        SectionTitleWithInfo(
                            title: "睡眠靜息心率",
                            explanation: "睡眠靜息心率是評估心臟健康和整體健康狀況的重要指標。較低的靜息心率通常表示更好的心臟功能和更高的體能水平。"
                        )
                        
                        SleepHeartRateChartView()
                            .environmentObject(healthKitManager)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("訓練數據")
            .task {
                // 確保已計算心率區間
                await HeartRateZonesBridge.shared.syncHeartRateZones()
            }
        }
    }
}

// 心率區間設定視圖
struct HeartRateZonesSettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var maxHeartRate: String = ""
    @State private var restingHeartRate: String = ""
    @State private var zones: [HeartRateZonesManager.HeartRateZone] = []
    @State private var isLoading = true
    @State private var showEditView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("心率區間設定")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showEditView = true
                } label: {
                    Label("編輯", systemImage: "pencil")
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            if isLoading {
                ProgressView("載入中...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最大心率")
                            .font(.subheadline)
                        Spacer()
                        Text("\(maxHeartRate) bpm")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("靜息心率")
                            .font(.subheadline)
                        Spacer()
                        Text("\(restingHeartRate) bpm")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Text("心率區間")
                        .font(.subheadline)
                        .padding(.top, 4)
                    
                    ForEach(zones, id: \.zone) { zone in
                        HStack(alignment: .top) {
                            Circle()
                                .fill(zoneColor(for: zone.zone))
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(zone.name) (區間 \(zone.zone))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(Int(zone.range.lowerBound.rounded()))-\(Int(zone.range.upperBound.rounded())) bpm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(zone.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
        .task {
            await loadZoneData()
        }
        .sheet(isPresented: $showEditView) {
            HRRHeartRateZoneEditorView()
                .onDisappear {
                    Task {
                        await loadZoneData()
                    }
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


struct WeeklyHeartRateAnalysisViewHRR: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var analysis: HealthKitManager.WeeklyHeartRateAnalysis?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showZoneInfo = false
    @State private var selectedZone: Int? = nil
    @State private var selectedZoneInfo: HealthKitManager.HeartRateZone? = nil  // 新增 state 儲存選取的區間詳細資料
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleWithInfo(
                title: "本週心率區間分析 (HRR)",
                explanation: "心率區間分析使用心率儲備（HRR）法計算，基於您的最大心率與靜息心率。這提供了更個人化的訓練強度分級，幫助您更有效地達成訓練目標。"
            )
            
            if isLoading {
                ProgressView("載入數據中...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let error = error {
                Text("無法載入數據")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let analysis = analysis, !analysis.zoneDistribution.isEmpty {
                VStack(spacing: 16) {
                    // 活動時間總結
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("中等強度")
                                .font(.subheadline)
                            Text(healthKitManager.formatDuration(analysis.moderateActivityTime))
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("高強度")
                                .font(.subheadline)
                            Text(healthKitManager.formatDuration(analysis.vigorousActivityTime))
                                .font(.headline)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // 心率區間分佈圖
                    Chart {
                        ForEach(Array(analysis.zoneDistribution.sorted(by: { $0.key < $1.key })), id: \.key) { zone, duration in
                            BarMark(
                                x: .value("區間", "區間 \(zone)"),
                                y: .value("時間", duration / 60) // 轉換為分鐘
                            )
                            .foregroundStyle(zoneColor(for: zone))
                            .annotation(position: .top) {
                                Text(formatMinutes(duration / 60))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 150)
                    .padding(.horizontal)
                    
                    // 區間詳細說明
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(analysis.zoneDistribution.sorted(by: { $0.key < $1.key })), id: \.key) { zone, duration in
                                Button {
                                    // 在按鈕 Action 中進行非同步呼叫，將結果存入 selectedZoneInfo
                                    Task {
                                        selectedZone = zone
                                        if let hrZones = try? await healthKitManager.getHRRHeartRateZones(),
                                           let info = hrZones.first(where: { $0.zone == zone }) {
                                            selectedZoneInfo = info
                                        } else {
                                            selectedZoneInfo = nil
                                        }
                                        showZoneInfo = true
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                Text("無訓練數據")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
        .task {
            await loadHRRAnalysis()
        }
        // alert 只根據已儲存的 selectedZoneInfo 來建立，沒有非同步邏輯
        .alert(isPresented: $showZoneInfo) {
            if let info = selectedZoneInfo {
                return Alert(
                    title: Text("區間 \(info.zone)"),
                    message: Text("\(info.description)\n\n好處: \(info.benefit)"),
                    dismissButton: .default(Text("了解"))
                )
            } else {
                return Alert(
                    title: Text("心率區間"),
                    message: Text("無法加載區間詳情"),
                    dismissButton: .default(Text("確定"))
                )
            }
        }
    }
    
    private func loadHRRAnalysis() async {
        isLoading = true
        do {
            // 使用基於心率儲備的區間計算方法
            analysis = try await healthKitManager.fetchHRRWeeklyHeartRateAnalysis()
        } catch {
            self.error = error
        }
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
    
    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 1 {
            return "<1分"
        }
        return String(format: "%.0f分", minutes)
    }
}


#Preview {
    MyAchievementView()
        .environmentObject(HealthKitManager())
}
