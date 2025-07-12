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
                // 重新上傳按鈕（非顯眼）
                Button(action: {
                    Task {
                        do {
                            let result = try await WorkoutV2Service.shared.uploadWorkout(viewModel.workout, force: true)
                            await MainActor.run {
                                viewModel.checkUploadStatus()
                                loadWorkoutData()
                            }
                        } catch {
                            print("手動上傳失敗: \(error)")
                        }
                    }
                }) {
                    Text("重新上傳訓練紀錄")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        HeartRateChartView(
            heartRates: viewModel.heartRates,
            maxHeartRate: maxHeartRateString,
            averageHeartRate: viewModel.averageHeartRate,
            minHeartRate: minHeartRateString,
            yAxisRange: viewModel.yAxisRange,
            isLoading: viewModel.isLoading,
            error: viewModel.error
        )
    }

    private var maxHeartRateString: String {
        guard let max = viewModel.heartRates.map({ $0.value }).max(), !viewModel.heartRates.isEmpty else { return "--" }
        return "\(Int(max)) bpm"
    }

    private var minHeartRateString: String {
        guard let min = viewModel.heartRates.map({ $0.value }).min(), !viewModel.heartRates.isEmpty else { return "--" }
        return "\(Int(min)) bpm"
    }

    private var paceChartSection: some View {
        PaceChartView(
            paces: viewModel.paces,
            isLoading: viewModel.isLoading,
            error: nil
        )
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
            let summaryId = WorkoutV2Service.shared.makeWorkoutId(for: viewModel.workout)
            // 嘗試快取
            if let cached = WorkoutV2Service.shared.getCachedWorkoutSummary(for: summaryId) {
                await MainActor.run {
                    self.dynamicVDOT = cached.vdot
                    viewModel.averageHeartRate = cached.avgHR
                    viewModel.trainingLoad = cached.trimp
                    self.summaryTypeChinese = DayType(rawValue: cached.type)?.chineseName ?? cached.type
                    self.hrZonePct = cached.hrZonePct
                }
            }
            // 向後端請求
            do {
                let summary = try await WorkoutV2Service.shared.getWorkoutSummary(workoutId: summaryId)
                WorkoutV2Service.shared.saveCachedWorkoutSummary(summary, for: summaryId)
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

    private func formatPaceFromSeconds(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
