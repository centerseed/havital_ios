import SwiftUI
import Charts

struct WorkoutDetailViewV2: View {
    @StateObject private var viewModel: WorkoutDetailViewModelV2
    @Environment(\.dismiss) private var dismiss
    @State private var showHRZoneInfo = false
    @State private var selectedZoneTab: ZoneTab = .heartRate
    
    enum ZoneTab: CaseIterable {
        case heartRate, pace
        
        var title: String {
            switch self {
            case .heartRate: return "心率區間"
            case .pace: return "配速區間"
            }
        }
    }
    
    init(workout: WorkoutV2) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModelV2(workout: workout))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 基本資訊卡片（始終顯示）
                basicInfoCard
                
                // 高級指標卡片
                if viewModel.workout.advancedMetrics != nil {
                    advancedMetricsCard
                }
                
                // 載入狀態或錯誤訊息
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    // 只有在非載入狀態且無錯誤時顯示圖表
                    LazyVStack(spacing: 16) {
                        // 心率變化圖表
                        heartRateChartSection
                        
                        // 配速變化圖表
                        if !viewModel.paces.isEmpty {
                            paceChartSection
                        }
                        
                        // 區間分佈卡片（合併顯示）
                        if let hrZones = viewModel.workout.advancedMetrics?.hrZoneDistribution,
                           let paceZones = viewModel.workout.advancedMetrics?.paceZoneDistribution {
                            combinedZoneDistributionCard(hrZones: convertToV2ZoneDistribution(hrZones), paceZones: convertToV2ZoneDistribution(paceZones))
                        } else if let hrZones = viewModel.workout.advancedMetrics?.hrZoneDistribution {
                            heartRateZoneCard(convertToV2ZoneDistribution(hrZones))
                        } else if let paceZones = viewModel.workout.advancedMetrics?.paceZoneDistribution {
                            paceZoneCard(convertToV2ZoneDistribution(paceZones))
                        }
                    }
                }
                
                // 數據來源和設備信息卡片（移到最底下）
                sourceInfoCard
            }
            .padding()
        }
        .navigationTitle("運動詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("關閉") {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadWorkoutDetail()
        }
        .onDisappear {
            // 確保在 View 消失時取消任務
            viewModel.cancelLoadingTasks()
        }
    }
    
    // MARK: - 基本資訊卡片
    
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(viewModel.workoutType.workoutTypeDisplayName())
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                if let trainingType = viewModel.trainingType {
                    Text(trainingType)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }

                Spacer()
                
                // Garmin Attribution for basic metrics
                ConditionalGarminAttributionView(
                    dataProvider: viewModel.workout.provider,
                    deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName,
                    displayStyle: .titleLevel
                )  
            }
            
            // 運動數據網格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                DataItem(title: "距離", value: viewModel.distance ?? "-", icon: "location")
                DataItem(title: "時間", value: viewModel.duration, icon: "clock")
                DataItem(title: "卡路里", value: viewModel.calories ?? "-", icon: "flame")
                
                if let pace = viewModel.pace {
                    DataItem(title: "配速", value: pace, icon: "speedometer")
                }
                
                if let avgHR = viewModel.averageHeartRate {
                    DataItem(title: "平均心率", value: avgHR, icon: "heart")
                }
                
                if let maxHR = viewModel.maxHeartRate {
                    DataItem(title: "最大心率", value: maxHR, icon: "heart.fill")
                }
            }
            
            // 日期時間
            Text("開始時間: \(formatDate(viewModel.workout.startDate))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 數據來源信息卡片
    
    private var sourceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("數據來源")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("提供商")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        // For Garmin data: show Logo + Device Name
                        if viewModel.workout.provider.lowercased().contains("garmin") {
                            ConditionalGarminAttributionView(
                                dataProvider: viewModel.workout.provider,
                                deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName,
                                displayStyle: .secondary
                            )
                        } else {
                            // For non-Garmin data: show provider name
                            Text(viewModel.workout.provider)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("活動類型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.workout.activityType.workoutTypeDisplayName())
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 圖表區塊
    
    private var heartRateChartSection: some View {
        Group {
            if !viewModel.heartRates.isEmpty {
                HeartRateChartView(
                    heartRates: viewModel.heartRates,
                    maxHeartRate: viewModel.maxHeartRateString,
                    averageHeartRate: viewModel.chartAverageHeartRate,
                    minHeartRate: viewModel.minHeartRateString,
                    yAxisRange: viewModel.yAxisRange,
                    isLoading: viewModel.isLoading,
                    error: viewModel.error,
                    dataProvider: viewModel.workout.provider,
                    deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName
                )
            } else {
                // 簡化的空狀態顯示
                VStack {
                    Text("心率數據")
                        .font(.headline)
                    Text("無心率數據")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var paceChartSection: some View {
        Group {
            if !viewModel.paces.isEmpty {
                PaceChartView(
                    paces: viewModel.paces,
                    isLoading: viewModel.isLoading,
                    error: viewModel.error,
                    dataProvider: viewModel.workout.provider,
                    deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName
                )
            }
        }
    }
    
    // MARK: - 高級指標卡片
    
    private var advancedMetricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("進階指標")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                if let dynamicVdot = viewModel.workout.advancedMetrics?.dynamicVdot {
                    DataItem(title: "動態跑力", value: String(format: "%.1f", dynamicVdot), icon: "chart.line.uptrend.xyaxis")
                }
                
                if let tss = viewModel.workout.advancedMetrics?.tss {
                    DataItem(title: "訓練負荷", value: String(format: "%.1f", tss), icon: "heart.circle")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 心率區間分佈卡片
    
    private func heartRateZoneCard(_ hrZones: V2ZoneDistribution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("心率區間分佈")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showHRZoneInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 8) {
                if let recovery = hrZones.recovery {
                    ZoneRow(title: "恢復區", percentage: recovery, color: .green)
                }
                if let easy = hrZones.easy {
                    ZoneRow(title: "有氧區", percentage: easy, color: .blue)
                }
                if let marathon = hrZones.marathon {
                    ZoneRow(title: "馬拉松區", percentage: marathon, color: .yellow)
                }
                if let threshold = hrZones.threshold {
                    ZoneRow(title: "閾值區", percentage: threshold, color: .orange)
                }
                if let interval = hrZones.interval {
                    ZoneRow(title: "間歇區", percentage: interval, color: .red)
                }
                if let anaerobic = hrZones.anaerobic {
                    ZoneRow(title: "無氧區", percentage: anaerobic, color: .purple)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showHRZoneInfo) {
            HeartRateZoneInfoView()
        }
    }
    
    // MARK: - 配速區間分佈卡片
    
    private func paceZoneCard(_ paceZones: V2ZoneDistribution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("配速區間分佈")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let recovery = paceZones.recovery {
                    ZoneRow(title: "恢復配速", percentage: recovery, color: .green)
                }
                if let easy = paceZones.easy {
                    ZoneRow(title: "輕鬆配速", percentage: easy, color: .blue)
                }
                if let marathon = paceZones.marathon {
                    ZoneRow(title: "馬拉松配速", percentage: marathon, color: .yellow)
                }
                if let threshold = paceZones.threshold {
                    ZoneRow(title: "閾值配速", percentage: threshold, color: .orange)
                }
                if let interval = paceZones.interval {
                    ZoneRow(title: "間歇配速", percentage: interval, color: .red)
                }
                if let anaerobic = paceZones.anaerobic {
                    ZoneRow(title: "無氧配速", percentage: anaerobic, color: .purple)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 合併區間分佈卡片
    
    private func combinedZoneDistributionCard(hrZones: V2ZoneDistribution, paceZones: V2ZoneDistribution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("區間分佈")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if selectedZoneTab == .heartRate {
                    Button(action: { showHRZoneInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // 標籤選擇器
            Picker("區間類型", selection: $selectedZoneTab) {
                ForEach(ZoneTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 動態內容
            VStack(spacing: 8) {
                if selectedZoneTab == .heartRate {
                    zoneRows(for: hrZones, isHeartRate: true)
                } else {
                    zoneRows(for: paceZones, isHeartRate: false)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showHRZoneInfo) {
            HeartRateZoneInfoView()
        }
    }
    
    @ViewBuilder
    private func zoneRows(for zones: V2ZoneDistribution, isHeartRate: Bool) -> some View {
        if let recovery = zones.recovery {
            ZoneRow(
                title: isHeartRate ? "恢復區" : "恢復配速",
                percentage: recovery,
                color: .green
            )
        }
        if let easy = zones.easy {
            ZoneRow(
                title: isHeartRate ? "有氧區" : "輕鬆配速",
                percentage: easy,
                color: .blue
            )
        }
        if let marathon = zones.marathon {
            ZoneRow(
                title: isHeartRate ? "馬拉松區" : "馬拉松配速",
                percentage: marathon,
                color: .yellow
            )
        }
        if let threshold = zones.threshold {
            ZoneRow(
                title: isHeartRate ? "閾值區" : "閾值配速",
                percentage: threshold,
                color: .orange
            )
        }
        if let interval = zones.interval {
            ZoneRow(
                title: isHeartRate ? "間歇區" : "間歇配速",
                percentage: interval,
                color: .red
            )
        }
        if let anaerobic = zones.anaerobic {
            ZoneRow(
                title: isHeartRate ? "無氧區" : "無氧配速",
                percentage: anaerobic,
                color: .purple
            )
        }
    }
    
    // MARK: - 載入和錯誤狀態
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("載入運動詳情中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.red)
            
            Text("載入失敗")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 類型轉換方法
    
    private func convertToV2ZoneDistribution(_ zones: ZoneDistribution) -> V2ZoneDistribution {
        return V2ZoneDistribution(from: zones)
    }
    
    private func convertToV2IntensityMinutes(_ intensity: APIIntensityMinutes) -> V2IntensityMinutes {
        return V2IntensityMinutes(from: intensity)
    }
    
    // MARK: - 輔助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatIntensityMinutes(_ intensityMinutes: V2IntensityMinutes) -> String {
        var parts: [String] = []
        
        if let low = intensityMinutes.low, low > 0 {
            parts.append("低: \(String(format: "%.0f", low))分")
        }
        if let medium = intensityMinutes.medium, medium > 0 {
            parts.append("中: \(String(format: "%.0f", medium))分")
        }
        if let high = intensityMinutes.high, high > 0 {
            parts.append("高: \(String(format: "%.0f", high))分")
        }
        
        return parts.isEmpty ? "-" : parts.joined(separator: "\n")
    }
}

// MARK: - 輔助 Views

struct DataItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
    }
}

struct ZoneRow: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(percentage / 100.0))), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.1f%%", percentage))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .trailing)
        }
    }
}



#Preview {
    WorkoutDetailViewV2(workout: WorkoutV2(
        id: "preview-1",
        provider: "Garmin",
        activityType: "running",
        startTimeUtc: ISO8601DateFormatter().string(from: Date()),
        endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
        durationSeconds: 3600,
        distanceMeters: 5000, deviceName: "Garmin",
        basicMetrics: nil,
        advancedMetrics: nil,
        createdAt: nil,
        schemaVersion: nil,
        storagePath: nil
    ))
} 
