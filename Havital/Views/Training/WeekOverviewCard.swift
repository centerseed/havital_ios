import SwiftUI

struct WeekOverviewCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let plan: WeeklyPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本週概覽")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 16) {
                // 使用GeometryReader动态计算和分配空间
                GeometryReader { geometry in
                    HStack(alignment: .center, spacing: 0) {
                        // 训练周期进度
                        VStack(spacing: 6) {
                            CircularProgressView(
                                progress: Double(plan.weekOfPlan) / Double(plan.totalWeeks),
                                currentWeek: plan.weekOfPlan,
                                totalWeeks: plan.totalWeeks
                            )
                            .frame(width: 80, height: 80)
                            
                            Text("訓練進度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: geometry.size.width / 2)
                        
                        // 如果有周跑量目标，显示第二个圆形进度条
                        VStack(spacing: 6) {
                            if viewModel.isLoadingDistance {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(1.0)
                                    .frame(width: 80, height: 80)
                            } else {
                                // 周跑量圆形进度条
                                ZStack {
                                    // 背景圓環
                                    Circle()
                                        .stroke(lineWidth: 8)
                                        .opacity(0.3)
                                        .foregroundColor(.blue)
                                    
                                    // 進度圓環
                                    Circle()
                                        .trim(from: 0.0, to: min(CGFloat(viewModel.currentWeekDistance / max(plan.totalDistance, 1.0)), 1.0))
                                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                        .foregroundColor(.blue)
                                        .rotationEffect(Angle(degrees: 270.0))
                                        .animation(.linear, value: viewModel.currentWeekDistance)
                                    
                                    // 中间的文字
                                    VStack(spacing: 2) {
                                        Text("\(String(format: "%.1f", viewModel.currentWeekDistance))")
                                            .font(.system(size: 16, weight: .bold))
                                        
                                        Text("\(viewModel.formatDistance(plan.totalDistance))")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: 80, height: 80)
                            }
                            
                            Text("本週跑量")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: geometry.size.width / 2)
                    }
                    .frame(width: geometry.size.width)
                }
                .frame(height: 100) // 設置一個固定高度以容納進度條和標籤
                
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
                
                // 顯示「產生下週課表」按鈕 (根據新的條件)
                // 在 TrainingPlanView 中的適當位置添加以下代碼

                // 判斷是否顯示產生課表按鈕
                /*
                if let plan = viewModel.weeklyPlan, let currentTrainingWeek = viewModel.calculateCurrentTrainingWeek() {
                    let (shouldShow, nextWeek) = viewModel.shouldShowNextWeekButton(plan: plan)
                    
                    if shouldShow {
                        // 顯示產生課表按鈕
                        VStack(spacing: 8) {
                            Text("當前訓練週數：第 \(currentTrainingWeek) 週")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                Task {
                                    await viewModel.generateNextWeekPlan()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("產生第 \(nextWeek) 週課表")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .disabled(viewModel.isLoading)
                    }
                }*/
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let currentWeek: Int
    let totalWeeks: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 背景圓環
            Circle()
                .stroke(lineWidth: 10)
                .opacity(0.3)
                .foregroundColor(.gray)
            
            // 進度圓環
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            // 中心文字
            VStack(spacing: 2) {
                Text("\(currentWeek)")
                    .font(.system(size: 22, weight: .bold))
                
                Text("/ \(totalWeeks)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("週")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}
