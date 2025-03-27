import SwiftUI
import Charts
import HealthKit

struct SectionTitleWithInfo: View {
    let title: String
    let explanation: String
    @State private var showingInfo = false
    var useSheet: Bool = false
    var sheetContent: (() -> AnyView)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .if(!useSheet) { view in
                view.alert(title, isPresented: $showingInfo) {
                    Button("了解", role: .cancel) {}
                } message: {
                    Text(explanation)
                }
            }
            .if(useSheet && sheetContent != nil) { view in
                view.sheet(isPresented: $showingInfo) {
                    sheetContent?()
                }
            }
            
            Spacer()
        }
    }
}

// Extension to support conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct MyAchievementView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // VDOT Chart Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitleWithInfo(
                            title: "VDOT 趨勢",
                            explanation: "VDOT 是根據您的跑步表現所計算出的有氧能力指標。隨著訓練進度的增加，您的 VDOT 值會逐漸提升。"
                        )
                        .padding(.horizontal)
                        
                        VDOTChartView()
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // 使用 HRR 方法的心率區間分析
                    WeeklyHeartRateAnalysisViewHRR()
                        .environmentObject(healthKitManager)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        .padding(.horizontal)
                    
                    // HRV 趨勢圖
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitleWithInfo(
                            title: "心率變異性 (HRV) 趨勢",
                            explanation: "心率變異性（HRV）是衡量身體恢復能力和壓力水平的重要指標。較高的HRV通常表示更好的恢復能力和較低的壓力水平。"
                        )
                        .padding(.horizontal)
                        
                        HRVTrendChartView()
                            .environmentObject(healthKitManager)
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                    
                    // 睡眠靜息心率圖
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitleWithInfo(
                            title: "睡眠靜息心率",
                            explanation: "睡眠靜息心率是評估心臟健康和整體健康狀況的重要指標。較低的靜息心率通常表示更好的心臟功能和更高體能水平。"
                        )
                        .padding(.horizontal)
                        
                        SleepHeartRateChartView()
                            .environmentObject(healthKitManager)
                            .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("表現數據")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 確保已計算心率區間
                await HeartRateZonesBridge.shared.syncHeartRateZones()
            }
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
    @State private var selectedZoneInfo: HealthKitManager.HeartRateZone? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleWithInfo(
                title: "最近一週心率區間分析 (HRR)",
                explanation: "心率區間分析使用心率儲備（HRR）法計算，基於您的最大心率與靜息心率。這提供了更個人化的訓練強度分級，幫助您更有效地達成訓練目標。",
                useSheet: true,
                sheetContent: { AnyView(HeartRateZoneInfoView()) }
            )
            .padding(.horizontal)
            
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
                }
                .padding(.vertical)
            } else {
                Text("無訓練數據")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding()
            }
        }
        .task {
            await loadHRRAnalysis()
        }
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
