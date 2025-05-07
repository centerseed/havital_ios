import Charts
import HealthKit
import SwiftUI

struct WorkoutDetailView: View {
    @StateObject private var viewModel: WorkoutDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showHRZoneInfo = false
    @State private var dynamicVDOT: Double?
    @State private var isCalculatingVDOT = false
    @State private var summaryTypeChinese: String?
    @State private var hrZonePct: ZonePct?

    private let vdotCalculator = VDOTCalculator()

    init(
        workout: HKWorkout, healthKitManager: HealthKitManager,
        initialHeartRateData: [(Date, Double)], initialPaceData: [(Date, Double)]
    ) {
        _viewModel = StateObject(
            wrappedValue: WorkoutDetailViewModel(
                workout: workout,
                healthKitManager: healthKitManager,
                initialHeartRateData: initialHeartRateData,
                initialPaceData: initialPaceData
            ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 頂部卡片：依照要求調整版型
                VStack(spacing: 12) {
                    
                    
                   
                    
                    // 動態跑力和訓練負荷 + 基本資訊
                    HStack(spacing: 20) {
                        // 左側：動態跑力和訓練負荷
                        VStack(spacing: 20) {
                            // 動態跑力
                            VStack(alignment: .center, spacing: 4) {
                                Text("動態跑力")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if isCalculatingVDOT {
                                    ProgressView()
                                        .frame(height: 30)
                                } else if let vdot = dynamicVDOT {
                                    Text(String(format: "%.1f", vdot))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.blue)
                                } else {
                                    Text("--")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 訓練負荷
                            if let trimp = viewModel.trainingLoad {
                                VStack(alignment: .center, spacing: 4) {
                                    Text("訓練負荷")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(String(format: "%.1f", trimp))
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 右側：基本資訊
                        VStack(alignment: .leading, spacing: 10) {
                            // 訓練類型和日期
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(summaryTypeChinese ?? viewModel.workout.workoutActivityType.name)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    
                                Text(formatDate(viewModel.workout.startDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 分隔線
                            Divider()
                                .padding(.horizontal)
                            
                            // 距離
                            if let distance = viewModel.distance {
                                HStack(spacing: 6) {
                                    Image(systemName: "figure.walk")
                                        .font(.subheadline)
                                        .frame(width: 16)
                                    Text(distance)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            // 時間
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.subheadline)
                                    .frame(width: 16)
                                Text(viewModel.duration)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.secondary)
                            
                            // 配速
                            if let pace = viewModel.pace {
                                HStack(spacing: 6) {
                                    Image(systemName: "stopwatch")
                                        .font(.subheadline)
                                        .frame(width: 16)
                                    Text(pace)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            // 卡路里
                            if let calories = viewModel.calories {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .font(.subheadline)
                                        .frame(width: 16)
                                    Text(calories)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                .padding(.horizontal)

                // 心率變化圖表
                heartRateChartSection
                    .padding(.horizontal)

                // 配速變化圖表
                if !viewModel.paces.isEmpty {
                    paceChartSection
                        .padding(.horizontal)
                }

                // 心率區間分佈
                heartRateZoneSection
                    .padding(.horizontal)

                // 同步狀態顯示
                if viewModel.isUploaded, let uploadTime = viewModel.uploadTime {
                    uploadStatusSection(uploadTime)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("訓練詳情")
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
        .onAppear {
            viewModel.loadHeartRateData()
            loadWorkoutData()
        }
        .task {
            // 確保心率區間已同步
            await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
        }
        .id(viewModel.workoutId)
        .sheet(isPresented: $showHRZoneInfo) {
            HeartRateZoneInfoView()
        }
    }

    private func uploadStatusSection(_ uploadTime: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已同步到雲端")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("同步時間: \(formatUploadTime(uploadTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var heartRateChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("心率變化")
                .font(.headline)

            if viewModel.isLoading {
                VStack {
                    ProgressView("載入心率數據中...")
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    error,
                    systemImage: "heart.slash",
                    description: Text("請稍後再試")
                )
                .frame(height: 200)
            } else if viewModel.heartRates.isEmpty {
                ContentUnavailableView(
                    "沒有心率數據",
                    systemImage: "heart.slash",
                    description: Text("無法獲取此次訓練的心率數據")
                )
                .frame(height: 200)
            } else {
                // 心率範圍信息區塊 - 改進版
                HStack(spacing: 16) {
                    // 最高心率
                    VStack(alignment: .center, spacing: 4) {
                        Text("最高心率")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(viewModel.maxHeartRate.replacingOccurrences(of: " bpm", with: ""))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.red)

                            Text("bpm")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)

                    // 平均心率 (可選)
                    if let avgHR = viewModel.averageHeartRate {
                        VStack(alignment: .center, spacing: 4) {
                            Text("平均心率")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(Int(avgHR))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)

                                Text("bpm")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // 最低心率
                    VStack(alignment: .center, spacing: 4) {
                        Text("最低心率")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(viewModel.minHeartRate.replacingOccurrences(of: " bpm", with: ""))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)

                            Text("bpm")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                Chart {
                    ForEach(viewModel.heartRates) { point in
                        LineMark(
                            x: .value("時間", point.time),
                            y: .value("心率", point.value)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("時間", point.time),
                            y: .value("心率", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red.opacity(0.1), Color.red.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: viewModel.yAxisRange.min...(viewModel.yAxisRange.max))
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        // 在這裡可以自定義繪製格線
                        ZStack {
                            // 繪製水平格線
                            ForEach(
                                Array(
                                    stride(
                                        from: viewModel.yAxisRange.min,
                                        to: viewModel.yAxisRange.max, by: 20)), id: \.self
                            ) { yValue in
                                if let yPosition = proxy.position(forY: yValue) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1)
                                        .position(x: geometry.size.width / 2, y: yPosition)
                                        .frame(width: geometry.size.width)
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    // 增加 Y 軸的標記密度，間接增加參考線
                    AxisMarks(position: .leading, values: .stride(by: 10)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        if let heartRate = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(heartRate))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: viewModel.yAxisRange.min...viewModel.yAxisRange.max)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(
                                    "\(Calendar.current.component(.hour, from: date)):\(String(format: "%02d", Calendar.current.component(.minute, from: date)))"
                                )
                                .font(.caption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { value in
                        if let heartRate = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(heartRate))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYScale(domain: viewModel.yAxisRange.min...(viewModel.yAxisRange.max + 10))

            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var paceChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配速變化")
                .font(.headline)

            if viewModel.paces.isEmpty {
                ContentUnavailableView(
                    "沒有配速數據",
                    systemImage: "figure.walk.motion",
                    description: Text("無法獲取此次訓練的配速數據")
                )
                .frame(height: 180)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // 配速圖表範圍和標籤
                    HStack {
                        HStack(spacing: 4) {
                            Text("最快:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatPaceFromMetersPerSecond(getMaxPace()))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("最慢:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatPaceFromMetersPerSecond(getMinPace()))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }

                    Chart {
                        ForEach(viewModel.paces) { point in
                            // 將配速從 m/s 轉換為 min:ss/km 用於顯示（越低越快，所以反向處理）
                            LineMark(
                                x: .value("時間", point.time),
                                y: .value("配速", 1000 / point.value)  // 轉換為秒/公里
                            )
                            .foregroundStyle(Color.green.gradient)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("時間", point.time),
                                y: .value("配速", 1000 / point.value)  // 轉換為秒/公里
                            )
                            .foregroundStyle(Color.green.opacity(0.1))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 180)
                    .chartYScale(domain: paceChartYRange)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(
                                        "\(Calendar.current.component(.hour, from: date)):\(String(format: "%02d", Calendar.current.component(.minute, from: date)))"
                                    )
                                    .font(.caption)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        // 修正部分：確保Y軸顯示正確格式的配速
                        AxisMarks(position: .leading, values: .stride(by: 30)) { value in
                            if let paceInSeconds = value.as(Double.self) {
                                AxisValueLabel {
                                    Text(formatPaceFromSeconds(paceInSeconds))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // 確保格式化函數正確轉換配速
    private func formatPaceFromSeconds(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    // 修正 Y 軸範圍計算，確保在適當範圍內顯示
    private var paceChartYRange: ClosedRange<Double> {
        if viewModel.paces.isEmpty {
            return 300...600  // 默認範圍 (約 5:00-10:00 min/km)
        }

        // 將速度 (m/s) 轉換為配速 (秒/km)
        let paces = viewModel.paces.map { 1000 / $0.value }

        // 找出最快和最慢的配速
        guard let min = paces.min(), let max = paces.max() else {
            return 300...600
        }

        // 加入一些邊距
        let padding = (max - min) * 0.1
        let lowerBound = Swift.max(min - padding, 0)
        let upperBound = max + padding

        return lowerBound...upperBound
    }

    // 心率區間分佈 (使用後端返回資料)
    private var heartRateZoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("心率區間分佈")
                .font(.headline)
            if let pct = hrZonePct {
                Chart {
                    let order: [ZoneType] = [.recovery, .easy, .marathon, .threshold, .anaerobic, .interval]
                    ForEach(order, id: \.self) { zone in
                        let value: Double = {
                            switch zone {
                            case .anaerobic: return pct.anaerobic
                            case .easy:      return pct.easy
                            case .interval:  return pct.interval
                            case .marathon:  return pct.marathon
                            case .recovery:  return pct.recovery
                            case .threshold: return pct.threshold
                            }
                        }()
                        BarMark(
                            x: .value("區間", zone.chineseName),
                            y: .value("比例", value)
                        )
                        .foregroundStyle({
                            switch zone {
                            case .recovery:  return Color.gray
                            case .easy:      return Color.blue
                            case .marathon:  return Color.green
                            case .threshold: return Color.yellow
                            case .anaerobic: return Color.red
                            case .interval:  return Color.purple
                            }
                        }())
                        .annotation(position: .top) {
                            Text("\(Int(value))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 150)
            } else {
                ContentUnavailableView(
                    "無法獲取心率區間",
                    systemImage: "heart.slash",
                    description: Text("請稍後再試")
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - 輔助函數

    private func loadWorkoutData() {
        // 開始載入動態跑力
        isCalculatingVDOT = true
        Task {
            defer {
                Task { @MainActor in
                    self.isCalculatingVDOT = false
                }
            }
            // 統一組 workoutId
            let summaryId = WorkoutService.shared.makeWorkoutId(for: viewModel.workout)
            // 嘗試快取
            if let cached = WorkoutService.shared.getCachedWorkoutSummary(for: summaryId) {
                await MainActor.run {
                    self.dynamicVDOT = cached.vdot
                    viewModel.averageHeartRate = cached.avgHR
                    viewModel.trainingLoad = cached.trimp
                    self.summaryTypeChinese = DayType(rawValue: cached.type)?.chineseName ?? cached.type
                    self.hrZonePct = cached.hrZonePct
                }
                return
            }
            // 向後端請求
            do {
                let summary = try await WorkoutService.shared.getWorkoutSummary(workoutId: summaryId)
                WorkoutService.shared.saveCachedWorkoutSummary(summary, for: summaryId)
                await MainActor.run {
                    self.dynamicVDOT = summary.vdot
                    viewModel.averageHeartRate = summary.avgHR
                    viewModel.trainingLoad = summary.trimp
                    self.summaryTypeChinese = DayType(rawValue: summary.type)?.chineseName ?? summary.type
                    self.hrZonePct = summary.hrZonePct
                }
            } catch {
                // 計算未就緒或失敗，使用 local fallback
                // 與原邏輯相同
                do {
                    let heartRateData = try await viewModel.healthKitManager.fetchHeartRateData(for: viewModel.workout)
                    let hrCount = heartRateData.count
                    let trimmed = hrCount >= 3 ? heartRateData[1..<(hrCount-1)] : heartRateData[0..<hrCount]
                    let avgHR = trimmed.map{$0.1}.reduce(0,+)/Double(trimmed.count)
                    let distance = viewModel.workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                    var localVdot = 0.0
                    if distance != 0 {
                        localVdot = vdotCalculator.calculateDynamicVDOTFromPace(
                            distanceKm: distance/1000,
                            paceStr: String(format: "%d:%02d", Int((viewModel.workout.duration/distance*1000))/60, Int((viewModel.workout.duration/distance*1000))%60),
                            hr: avgHR, maxHR: Double(UserPreferenceManager.shared.maxHeartRate ?? 180), restingHR: Double(UserPreferenceManager.shared.restingHeartRate ?? 60)
                        )
                    }
                    await MainActor.run {
                        self.dynamicVDOT = localVdot
                        viewModel.averageHeartRate = avgHR
                        self.summaryTypeChinese = DayType(rawValue: viewModel.workoutType)?.chineseName ?? viewModel.workoutType
                        self.hrZonePct = nil
                    }
                } catch {}
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatUploadTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
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

    // 配速圖表相關函數

    // 獲取最快配速（最大值）
    private func getMaxPace() -> Double {
        guard !viewModel.paces.isEmpty else { return 0 }
        return viewModel.paces.map { $0.value }.max() ?? 0
    }

    // 獲取最慢配速（最小值）
    private func getMinPace() -> Double {
        guard !viewModel.paces.isEmpty else { return 0 }
        return viewModel.paces.map { $0.value }.min() ?? 0
    }

    // 將 m/s 轉換為 min:ss/km 格式
    private func formatPaceFromMetersPerSecond(_ metersPerSecond: Double) -> String {
        guard metersPerSecond > 0 else { return "--:--" }

        // 計算每公里秒數
        let secondsPerKm = 1000 / metersPerSecond

        return formatPaceFromSeconds(secondsPerKm)
    }
}
