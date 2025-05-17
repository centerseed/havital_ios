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

            VStack(spacing: 16) {
                // 週進度水平時間條
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
                }.padding(.horizontal, 32)
                    .padding(.vertical, 8)
                
                // 進度圓環與強度多環水平排列
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // 左側雙環進度 (45%)
                        VStack(spacing: 16) {
                            
                            
                            // 週跑量圓環
                            CircleProgressView(
                                progress: min(viewModel.currentWeekDistance / max(plan.totalDistance, 1.0), 1.0),
                                distanceInfo: "\(viewModel.formatDistance(viewModel.currentWeekDistance))/\(viewModel.formatDistance(plan.totalDistance))",
                                title: "本週跑量"
                            )
                            .frame(width: 100, height: 100)
                        }
                        .frame(width: geometry.size.width * 0.45, alignment: .center)
                        
                        // 右側水平進度條 (55%)
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Text("本週訓練負荷")
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: geometry.size.width * 0.6 - 16, alignment: .center)
                            }
                            
                            VStack(spacing: 12) {
                                HStack() {
                                    Text("低強度")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .leading)
                                    
                                    HorizontalProgressBar(value: 0.67, color: .blue)
                                        .frame(height: 12)
                                    
                                    Text("60%")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 40, alignment: .trailing)
                                }
                                
                                HStack() {
                                    Text("中強度")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .leading)
                                    
                                    HorizontalProgressBar(value: 0.3, color: .green)
                                        .frame(height: 16)
                                    
                                    Text("30%")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 40, alignment: .trailing)
                                }
                                
                                HStack() {
                                    Text("高強度")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .leading)
                                    
                                    HorizontalProgressBar(value: 0.1, color: .orange)
                                        .frame(height: 16)
                                    
                                    Text("10%")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(width: geometry.size.width * 0.55, alignment: .leading)
                    }
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
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
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
    
    init(progress: Double, distanceInfo: String, title: String = "") {
        self.progress = progress
        self.distanceInfo = distanceInfo
        self.title = title
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
                        
                    Text("km")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// 水平進度條元件
struct HorizontalProgressBar: View {
    let value: CGFloat
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景條
                Capsule()
                    .fill(color.opacity(0.2))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // 進度條
                Capsule()
                    .fill(color)
                    .frame(width: max(geometry.size.width * value, 0), height: geometry.size.height)
            }
        }
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
