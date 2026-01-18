import SwiftUI

struct WeeklySummaryView: View {
    let summary: WeeklyTrainingSummary
    let weekNumber: Int?
    @Binding var isVisible: Bool
    var onGenerateNextWeek: (() -> Void)?
    var onSetNewGoal: (() -> Void)? // 🆕 訓練完成時的回調
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingScreenshot = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 訓練完成度部分
                completionSection
                
                // 訓練分析部分
                analysisSection
                
                // 下週建議部分
                suggestionSection
                
                // 產生下週課表按鈕（正常流程）
                if let onGenerateNextWeek = onGenerateNextWeek {
                    Button {
                        onGenerateNextWeek()
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text(L10n.Training.Review.generateNextWeekPlan.localized)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.vertical)
                }

                // 🆕 設定新目標按鈕（訓練完成流程）
                if let onSetNewGoal = onSetNewGoal {
                    VStack(spacing: 16) {
                        Text(NSLocalizedString("training.cycle_completed_message", comment: "Great job! Your training cycle is complete. Don't forget to set your next training goal after reviewing your training!"))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            onSetNewGoal()
                        } label: {
                            HStack {
                                Image(systemName: "target")
                                Text(NSLocalizedString("training.set_new_goal", comment: "Set New Goal"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shareWeeklySummary()
                } label: {
                    if isGeneratingScreenshot {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isGeneratingScreenshot)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage = shareImage {
                ActivityViewController(activityItems: [shareImage])
            }
        }
    }

    // 計算導航標題
    private var navigationTitle: String {
        if let weekNumber = weekNumber {
            return L10n.Training.Review.weekReview.localized(with: weekNumber)
        } else {
            return L10n.Training.Review.lastWeekReview.localized
        }
    }
    
    // 訓練完成度區塊
    private var completionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.Review.trainingCompletion.localized)
                .font(AppFont.headline())
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 8)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(summary.trainingCompletion.percentage / 100, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .foregroundColor(completionColor)
                        .rotationEffect(Angle(degrees: 270))
                    
                    VStack {
                        Text("\(Int(summary.trainingCompletion.percentage))%")
                            .font(AppFont.title2())
                            .fontWeight(.bold)
                    }
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading) {
                    Text(summary.trainingCompletion.evaluation)
                        .font(AppFont.bodySmall())
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // 訓練分析區塊
    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.Review.trainingAnalysis.localized)
                .font(AppFont.headline())
            
            // 心率分析
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.Training.Review.heartRatePerformance.localized, systemImage: "heart.fill")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.red)
                
                HStack {
                    Text("\(L10n.Training.Review.average.localized): \(Int(summary.trainingAnalysis.heartRate.average ?? 0)) \(L10n.Unit.bpm.localized)")
                        .font(AppFont.caption())
                    
                    Spacer()
                    
                    Text("\(L10n.Training.Review.maximum.localized): \(Int(summary.trainingAnalysis.heartRate.max ?? 0)) \(L10n.Unit.bpm.localized)")
                        .font(AppFont.caption())
                }
                
                Text(summary.trainingAnalysis.heartRate.evaluation ?? "")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            
            // 配速分析
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.Training.Review.pacePerformance.localized, systemImage: "speedometer")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.green)
                
                HStack {
                    Text("\(L10n.Training.Review.average.localized): \(summary.trainingAnalysis.pace.average) \(L10n.SupportingRacesCard.paceUnit.localized)")
                        .font(AppFont.caption())
                    
                    Spacer()
                    
                    Text("\(L10n.Training.Review.trend.localized): \(summary.trainingAnalysis.pace.trend)")
                        .font(AppFont.caption())
                }
                
                Text(summary.trainingAnalysis.pace.evaluation ?? "")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            // 距離分析
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.Training.Review.distancePerformance.localized, systemImage: "figure.run")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.blue)
                
                HStack {
                    Text("\(L10n.Training.Review.totalDistance.localized): \(String(format: "%.1f", summary.trainingAnalysis.distance.total ?? 0)) \(L10n.Unit.km.localized)")
                        .font(AppFont.caption())
                    
                    Spacer()
                    
                    Text("\(summary.trainingAnalysis.distance.comparisonToPlan)")
                        .font(AppFont.caption())
                }
                
                Text(summary.trainingAnalysis.distance.evaluation ?? "")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // 下週建議區塊
    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.Review.nextWeekFocus.localized)
                .font(AppFont.headline())
            
            Text(summary.nextWeekSuggestions.focus)
                .font(AppFont.bodySmall())
                .padding(.bottom, 4)
            
            ForEach(summary.nextWeekSuggestions.recommendations, id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(AppFont.caption())
                        .padding(.top, 2)
                    
                    Text(recommendation)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // 根據完成度返回顏色
    private var completionColor: Color {
        let percentage = summary.trainingCompletion.percentage
        
        if percentage >= 80 {
            return .green
        } else if percentage >= 60 {
            return .yellow
        } else if percentage >= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func shareWeeklySummary() {
        isGeneratingScreenshot = true
        
        LongScreenshotCapture.captureView(
            VStack(alignment: .leading, spacing: 24) {
                // 標題部分（截圖時不包含分享按鈕）
                VStack(alignment: .leading, spacing: 8) {
                    if let weekNumber = weekNumber {
                        Text(L10n.Training.Review.weekReview.localized(with: weekNumber))
                            .font(AppFont.title2())
                            .fontWeight(.bold)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n.Training.Review.lastWeekReview.localized)
                            .font(AppFont.title2())
                            .fontWeight(.bold)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
                
                // 訓練完成度部分（為截圖優化）
                screenshotCompletionSection
                
                // 訓練分析部分（為截圖優化）
                screenshotAnalysisSection
                
                // 下週建議部分（為截圖優化）
                screenshotSuggestionSection
                
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
        ) { image in
            DispatchQueue.main.async {
                self.isGeneratingScreenshot = false
                self.shareImage = image
                self.showShareSheet = true
            }
        }
    }
    
    // MARK: - 為截圖優化的區塊視圖
    
    // 為截圖優化的訓練完成度區塊
    private var screenshotCompletionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.Review.trainingCompletion.localized)
                .font(AppFont.headline())
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 8)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(summary.trainingCompletion.percentage / 100, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .foregroundColor(completionColor)
                        .rotationEffect(Angle(degrees: 270))
                    
                    VStack {
                        Text("\(Int(summary.trainingCompletion.percentage))%")
                            .font(AppFont.title2())
                            .fontWeight(.bold)
                            .lineLimit(nil)
                    }
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading) {
                    Text(summary.trainingCompletion.evaluation)
                        .font(AppFont.bodySmall())
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // 為截圖優化的訓練分析區塊
    private var screenshotAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.Review.trainingAnalysis.localized)
                .font(AppFont.headline())
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // 心率分析
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.Training.Review.heartRatePerformance.localized, systemImage: "heart.fill")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.red)
                    .lineLimit(nil)
                
                HStack {
                    Text("\(L10n.Training.Review.average.localized): \(Int(summary.trainingAnalysis.heartRate.average ?? 0)) bpm")
                        .font(AppFont.caption())
                        .lineLimit(nil)
                    
                    Spacer()
                    
                    Text("\(L10n.Training.Review.maximum.localized): \(Int(summary.trainingAnalysis.heartRate.max ?? 0)) bpm")
                        .font(AppFont.caption())
                        .lineLimit(nil)
                }
                
                Text(summary.trainingAnalysis.heartRate.evaluation ?? "")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            
            // 配速分析
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.Training.Review.pacePerformance.localized, systemImage: "speedometer")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.green)
                    .lineLimit(nil)
                
                HStack {
                    Text("\(L10n.Training.Review.average.localized): \(summary.trainingAnalysis.pace.average) /km")
                        .font(AppFont.caption())
                        .lineLimit(nil)
                    
                    Spacer()
                    
                    Text("\(L10n.Training.Review.trend.localized): \(summary.trainingAnalysis.pace.trend)")
                        .font(AppFont.caption())
                        .lineLimit(nil)
                }
                
                Text(summary.trainingAnalysis.pace.evaluation ?? "")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            // 距離分析
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.Training.Review.distancePerformance.localized, systemImage: "figure.run")
                    .font(AppFont.bodySmall())
                    .foregroundColor(.blue)
                    .lineLimit(nil)
                
                HStack {
                    Text("\(L10n.Training.Review.totalDistance.localized): \(String(format: "%.1f", summary.trainingAnalysis.distance.total ?? 0)) km" ?? "")
                        .font(AppFont.caption())
                        .lineLimit(nil)
                    
                    Spacer()
                    
                    Text("\(summary.trainingAnalysis.distance.comparisonToPlan)")
                        .font(AppFont.caption())
                        .lineLimit(nil)
                }
                
                Text(summary.trainingAnalysis.distance.evaluation ?? "")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // 為截圖優化的下週建議區塊
    private var screenshotSuggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Training.Review.nextWeekFocus.localized)
                .font(AppFont.headline())
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(summary.nextWeekSuggestions.focus)
                .font(AppFont.bodySmall())
                .padding(.bottom, 4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            ForEach(summary.nextWeekSuggestions.recommendations, id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(AppFont.caption())
                        .padding(.top, 2)
                    
                    Text(recommendation)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

// 加載中的視圖
struct WeeklySummaryLoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(L10n.Training.Review.analyzingData.localized)
                .font(AppFont.headline())
            
            Text(L10n.Training.Review.loadingMessage.localized)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// 錯誤顯示視圖
struct WeeklySummaryErrorView: View {
    let error: Error
    var onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppFont.dataMedium())
                .foregroundColor(.orange)
            
            Text(L10n.Training.Review.loadingError.localized)
                .font(AppFont.headline())
            
            Text(error.localizedDescription)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let onRetry = onRetry {
                Button {
                    onRetry()
                } label: {
                    Text(L10n.Training.Review.retry.localized)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    // 創建預覽數據
    let summary = WeeklyTrainingSummary(
        id: "preview_summary_id",
        trainingCompletion: TrainingCompletion(
            percentage: 85,
            evaluation: "本週訓練完成度良好，繼續保持這樣的訓練節奏可以有效提升您的跑步能力。"
        ),
        trainingAnalysis: TrainingAnalysis(
            heartRate: HeartRateAnalysis(
                average: 145,
                max: 182,
                evaluation: "心率控制良好，大部分訓練都在正確的心率區間內進行，有效提升心肺功能。"
            ),
            pace: PaceAnalysis(
                average: "5:30",
                trend: "穩定",
                evaluation: "配速穩定且控制得當，顯示出良好的體能水平和節奏感。"
            ),
            distance: DistanceAnalysis(
                total: 32.5,
                comparisonToPlan: "達成目標",
                evaluation: "本週總距離達標，訓練量適中，對體能提升有良好幫助。"
            )
        ),
        nextWeekSuggestions: NextWeekSuggestions(
            focus: "提升速度耐力",
            recommendations: [
                "增加一次閾值跑訓練，提高乳酸閾值",
                "保持長跑距離，但嘗試在最後3公里提升配速",
                "確保足夠休息，特別是高強度訓練後"
            ]
        ),
        nextWeekAdjustments: NextWeekAdjustments(
            status: "調整課表",
            modifications: Modifications(
                intervalTraining: TrainingModification(
                    original: "8 x 400m，配速4:00/km，間歇休息1分鐘",
                    adjusted: "6 x 600m，配速4:10/km，間歇休息1分30秒"
                ),
                longRun: TrainingModification(
                    original: "18公里，配速5:45/km",
                    adjusted: "16公里，最後5公里加速至5:20/km"
                )
            ),
            adjustmentReason: "根據您的心率和配速表現，適當調整訓練強度和方式，在保持訓練效果的同時降低過度訓練風險。",
            items: [
                AdjustmentItem(content: "建議安排休息週以促進恢復", apply: true),
                AdjustmentItem(content: "增加恢復跑時間", apply: false),
                AdjustmentItem(content: "減少間歇訓練強度", apply: true)
            ]
        )
    )
    
    WeeklySummaryView(
        summary: summary,
        weekNumber: 3,
        isVisible: .constant(true),
        onGenerateNextWeek: nil,
        onSetNewGoal: nil
    )
}
