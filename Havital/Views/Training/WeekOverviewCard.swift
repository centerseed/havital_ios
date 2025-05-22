import SwiftUI

struct WeekOverviewCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlan
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showWeekSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本週概覽")
                .font(.headline)
                .padding(.horizontal, 4)
            
            // 卡片內容
            VStack(spacing: 0) {
                // 主要內容
                VStack(spacing: 16) {

            VStack(spacing: 16) {
                // 當有強度數據時才顯示頂部進度條
                if plan.intensityTotalMinutes != nil {
                    VStack(spacing: 6) {
                        HStack {
                            Text("訓練進度")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(plan.weekOfPlan) / \(plan.totalWeeks) 週")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        WeekProgressBar(progress: Double(plan.weekOfPlan) / Double(plan.totalWeeks))
                            .frame(height: 12)
                            .onTapGesture { showWeekSelector = true }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }

                HStack(spacing: 8) {
                    Text("本週跑量和訓練負荷")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // 進度圓環水平排列
                GeometryReader { geometry in
                    HStack(spacing: 16) {
                        if let intensity = plan.intensityTotalMinutes {
                            // 有強度數據時顯示：左側跑量環，右側強度進度條
                            // 左側跑量環 (40%)
                            VStack(spacing: 16) {
                                CircleProgressView(
                                    progress: min(viewModel.currentWeekDistance / max(plan.totalDistance, 1.0), 1.0),
                                    distanceInfo: "\(viewModel.formatDistance(viewModel.currentWeekDistance))/\(viewModel.formatDistance(plan.totalDistance))",
                                    title: "本週跑量"
                                )
                                .frame(width: 100, height: 100)
                            }
                            .frame(width: geometry.size.width * 0.45, alignment: .center)
                            
                            // 右側強度進度條 (60%)
                            VStack(spacing: 10) {
                                VStack(spacing: 12) {
                                    let total = intensity.total > 0 ? intensity.total : 1
                                    
                                    // 低強度
                                    VStack(spacing: 4) {
                                        HStack(alignment: .center) {
                                            Text("低強度")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            
                                            if intensity.low == 0 {
                                                Image(systemName: "info.circle")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                                    .help("本週無建議低強度訓練")
                                            }
                                            
                                            Spacer()
                                            Text("\(intensity.low)分")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        HorizontalProgressBar(
                                            progress: Double(intensity.low) / Double(total),
                                            color: .blue,
                                            showDashed: intensity.low == 0
                                        )
                                    }
                                    
                                    // 中強度
                                    VStack(spacing: 4) {
                                        HStack(alignment: .center) {
                                            Text("中強度")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            
                                            if intensity.medium == 0 {
                                                Image(systemName: "info.circle")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                                    .help("本週無建議中強度訓練")
                                            }
                                            
                                            Spacer()
                                            Text("\(intensity.medium)分")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        HorizontalProgressBar(
                                            progress: Double(intensity.medium) / Double(total),
                                            color: .green,
                                            showDashed: intensity.medium == 0
                                        )
                                    }
                                    
                                    // 高強度
                                    VStack(spacing: 4) {
                                        HStack(alignment: .center) {
                                            Text("高強度")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            
                                            if intensity.high == 0 {
                                                Image(systemName: "info.circle")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                                    .help("本週無建議高強度訓練")
                                            }
                                            
                                            Spacer()
                                            Text("\(intensity.high)分")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        HorizontalProgressBar(
                                            progress: Double(intensity.high) / Double(total),
                                            color: .orange,
                                            showDashed: intensity.high == 0
                                        )
                                    }                    
                                }
                            }
                            .frame(width: geometry.size.width * 0.55 - 16, alignment: .leading)
                        } else {
                            // 沒有強度數據時顯示：左側週進度環，右側跑量環
                            // 左側週進度環 (50%)
                            VStack(spacing: 8) {
                                CircleProgressView(
                                    progress: Double(plan.weekOfPlan) / Double(plan.totalWeeks),
                                    distanceInfo: "\(plan.weekOfPlan)/\(plan.totalWeeks)",
                                    title: "訓練進度",
                                    unit: "週"
                                )
                                .frame(width: 100, height: 100)
                                .onTapGesture { showWeekSelector = true }
                            }
                            .frame(width: geometry.size.width * 0.5, alignment: .center)
                            
                            // 右側跑量環 (50%)
                            VStack(spacing: 8) {
                                CircleProgressView(
                                    progress: min(viewModel.currentWeekDistance / max(plan.totalDistance, 1.0), 1.0),
                                    distanceInfo: "\(viewModel.formatDistance(viewModel.currentWeekDistance))/\(viewModel.formatDistance(plan.totalDistance))",
                                    title: "本週跑量"
                                )
                                .frame(width: 100, height: 100)
                            }
                            .frame(width: geometry.size.width * 0.5, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 120)
                
                // 訓練目的
                VStack(alignment: .leading, spacing: 2) {
                    Text("週目標")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(plan.purpose)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
                }
                .padding(.top, 4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
            )
        }
        .sheet(isPresented: $showWeekSelector) {
            NavigationView {
                if viewModel.isLoadingWeeklySummaries {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.weeklySummaries, id: \.weekIndex) { item in
                        HStack {
                            // 左側：週次與完成率
                            Text("第 \(item.weekIndex) 週")
                                .font(.headline)
                                .foregroundColor(.primary)
                            // 顯示完成率（若有）
                            if let percent = item.completionPercentage {
                                HStack(spacing: 8) {
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 40, height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(LinearGradient(
                                                gradient: Gradient(colors: [.blue, .teal]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: 40 * min(percent, 100) / 100, height: 6)
                                    }
                                    Text("\(Int(percent))%")
                                        .fixedSize()
                                        .font(.footnote.bold())
                                        .foregroundColor(.blue)
                                }
                            }
                            Spacer()
                            // 右側：功能按鈕
                            HStack(spacing: 8) {
                                if item.weekSummary != nil {
                                    Button {
                                        Task { await viewModel.fetchWeeklySummary(weekNumber: item.weekIndex) }
                                        showWeekSelector = false
                                    } label: {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("回顧")
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                        }
                                        .fixedSize() 
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                if item.weekPlan != nil {
                                    Button {
                                        Task { await viewModel.fetchWeekPlan(week: item.weekIndex, healthKitManager: healthKitManager) }
                                        showWeekSelector = false
                                    } label: {
                                        HStack(alignment: .center, spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("課表")
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                        }
                                        .fixedSize() 
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundColor(.green)
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                                .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                        )
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                    .padding(.horizontal, 6)
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationTitle("訓練進度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { showWeekSelector = false }
                }
            }
            .task { await viewModel.fetchWeeklySummaries() }
        }
        .sheet(isPresented: $viewModel.showWeeklySummary) {
            if let summary = viewModel.weeklySummary {
                WeeklySummaryView(
                    summary: summary,
                    weekNumber: viewModel.lastFetchedWeekNumber,
                    isVisible: $viewModel.showWeeklySummary
                )
            }
        }
    }
}

// 週進度條元件
struct WeekProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景條
                Capsule()
                    .fill(Color.blue.opacity(0.2))
                
                // 進度條
                Capsule()
                    .fill(Color.blue)
                    .frame(width: max(geometry.size.width * CGFloat(min(progress, 1.0)), 0))
                
                // 指示箭頭
                if progress > 0.03 && progress < 0.97 {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .offset(x: geometry.size.width * CGFloat(min(progress, 1.0)) - 4)
                }
            }
        }
        .frame(height: 12)
    }
}

// 跑量圓環元件
struct CircleProgressView: View {
    let progress: Double
    var distanceInfo: String
    var title: String
    var unit: String?
    
    init(progress: Double, distanceInfo: String, title: String = "", unit: String? = nil) {
        self.progress = progress
        self.distanceInfo = distanceInfo
        self.title = title
        self.unit = unit
    }
    
    var body: some View {
        ZStack {
            // 背景環
            Circle()
                .stroke(lineWidth: 10)
                .opacity(0.2)
                .foregroundColor(.blue)
            
            // 進度環
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: -90))
                .animation(.linear, value: progress)
            
            // 跑量資訊和標題
            VStack(spacing: 4) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 0) {
                    Text(distanceInfo)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        
                    Text(unit ?? "km")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// 水平進度條
struct HorizontalProgressBar: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 8
    var showDashed: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: height / 2)
                    .frame(width: geometry.size.width, height: height)
                    .foregroundColor(color.opacity(0.1))
                
                if showDashed {
                    // 虛線樣式
                    HStack(spacing: 2) {
                        ForEach(0..<Int(geometry.size.width / 6), id: \.self) { i in
                            Rectangle()
                                .frame(width: 4, height: height)
                                .foregroundColor(color.opacity(0.6))
                        }
                    }
                    .frame(width: geometry.size.width, alignment: .leading)
                } else {
                    // 實線樣式
                    RoundedRectangle(cornerRadius: height / 2)
                        .frame(width: min(progress * geometry.size.width, geometry.size.width), height: height)
                        .foregroundColor(color)
                        .animation(.linear, value: progress)
                }
            }
        }
        .frame(height: height)
    }
}

// 多環進度視圖
struct MultiRingProgressView: View {
    let values: [(max: Double, current: Double, color: Color)]
    var gapSize: CGFloat = 0.3 // 環之間的間隙大小，0表示沒有間隙
    
    init(values: [(max: Double, current: Double, color: Color)], gapSize: CGFloat = 0.2) {
        self.values = values
        self.gapSize = gapSize
    }

    var body: some View {
        ZStack {
            ForEach(Array(values.enumerated()).filter { $0.element.max > 0 }, id: \.offset) { idx, item in
                let progress = min(item.current / max(item.max, 1.0), 1.0)
                let lineWidth = CGFloat(8 - idx * 2)
                let scale = 1.0 - CGFloat(idx) * (gapSize)

                Circle()
                    .stroke(lineWidth: lineWidth)
                    .opacity(0.3)
                    .foregroundColor(item.color)
                    .scaleEffect(scale)

                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .foregroundColor(item.color)
                    .rotationEffect(Angle(degrees: -90))
                    .scaleEffect(scale)
                    .animation(.linear, value: progress)
            }
        }
    }
}
