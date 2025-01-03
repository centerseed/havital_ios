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

struct WeeklyHeartRateAnalysisView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var analysis: HealthKitManager.WeeklyHeartRateAnalysis?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleWithInfo(
                title: "本週心率區間分析",
                explanation: "心率區間分析可以幫助你了解訓練的強度分佈。中等強度（區間2-3）有助於提升基礎體能和燃脂，高強度（區間4-5）則可以提高心肺功能和運動表現。"
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
                        }
                    }
                    .frame(height: 150)
                    .padding(.horizontal)
                    
                    // 區間詳細說明
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(analysis.zoneDistribution.sorted(by: { $0.key < $1.key })), id: \.key) { zone, duration in
                                VStack(alignment: .leading) {
                                    Text("區間 \(zone)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(healthKitManager.formatDuration(duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(zoneColor(for: zone).opacity(0.1))
                                .cornerRadius(8)
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
            await loadAnalysis()
        }
    }
    
    private func loadAnalysis() async {
        isLoading = true
        do {
            analysis = try await healthKitManager.fetchWeeklyHeartRateAnalysis()
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
}

struct MyAchievementView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WeeklyHeartRateAnalysisView()
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
                            .onAppear {
                                print("PerformanceChartView appeared")
                            }
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
            .navigationTitle("我的成就")
        }
    }
}

#Preview {
    MyAchievementView()
        .environmentObject(HealthKitManager())
}
