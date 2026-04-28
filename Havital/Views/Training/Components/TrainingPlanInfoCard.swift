import SwiftUI

struct TrainingPlanInfoCard: View {
    let workoutDetail: WorkoutV2Detail?
    let dataProvider: String?
    @State private var isAnalysisExpanded = false
    let forceExpandAnalysis: Bool

    init(workoutDetail: WorkoutV2Detail?, dataProvider: String? = nil, forceExpandAnalysis: Bool = false) {
        self.workoutDetail = workoutDetail
        self.dataProvider = dataProvider
        self.forceExpandAnalysis = forceExpandAnalysis
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("training.plan_info", comment: "Training Plan Info"))
                .font(AppFont.headline())
                .fontWeight(.semibold)

            // 移除高頻日誌：此方法在每次 UI 渲染時都會被調用

            if let dailyPlan = workoutDetail?.dailyPlanSummary {
                VStack(alignment: .leading, spacing: 12) {
                    // Day target
                    if let dayTarget = dailyPlan.dayTarget {
                        Text(dayTarget)
                            .font(AppFont.body())
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Training details grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        // Display distance - prioritize totalDistanceKm, then distanceKm, then calculate from segments
                        let displayDistance = getDisplayDistance(from: dailyPlan)
                        if displayDistance > 0 {
                            TrainingInfoItem(
                                title: NSLocalizedString("training.distance", comment: "Distance"),
                                value: String(format: "%.1f km", displayDistance),
                                icon: "location"
                            )
                        }
                        
                        // Display pace - use pace if available, otherwise show average of segments
                        // 低強度訓練（輕鬆跑 / LSD / 恢復跑）不顯示配速，避免用戶過度追求配速而偏離訓練目的
                        let displayPace = getDisplayPace(from: dailyPlan)
                        if !displayPace.isEmpty && !shouldHidePace(dailyPlan.trainingType) {
                            TrainingInfoItem(
                                title: NSLocalizedString("training.pace", comment: "Pace"),
                                value: displayPace,
                                icon: "speedometer"
                            )
                        }
                        
                        if let hrRange = dailyPlan.heartRateRange {
                            TrainingInfoItem(
                                title: NSLocalizedString("training.heart_rate_zone", comment: "HR Zone"),
                                value: "\(hrRange.min)-\(hrRange.max)",
                                icon: "heart"
                            )
                        }
                        
                        if let trainingType = dailyPlan.trainingType {
                            TrainingInfoItem(
                                title: NSLocalizedString("training.training_type", comment: "Training Type"),
                                value: formatTrainingType(trainingType),
                                icon: "figure.run"
                            )
                        }
                    }
                }
            }
            
            // AI Summary section
            if let aiSummary = workoutDetail?.aiSummary {
                // 移除高頻日誌：此方法在每次 UI 渲染時都會被調用
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("training.ai_analysis", comment: "AI Analysis"))
                            .font(AppFont.bodySmall())
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        Spacer()

                        if !forceExpandAnalysis {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAnalysisExpanded.toggle()
                                }
                            }) {
                                Text(isAnalysisExpanded ? NSLocalizedString("training.collapse", comment: "Collapse") : NSLocalizedString("training.expand", comment: "Expand"))
                                    .font(AppFont.caption())
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Text(aiSummary.analysis)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                        .lineLimit(forceExpandAnalysis || isAnalysisExpanded ? nil : 3)
                        .animation(.easeInOut(duration: 0.2), value: isAnalysisExpanded)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func getDisplayDistance(from dailyPlan: DailyPlanSummary) -> Double {
        let trainingDetails = dailyPlan.trainingDetails
        
        // Priority: training_details.total_distance_km -> distanceKm -> sum of segments
        if let totalDistance = trainingDetails?.totalDistanceKm, totalDistance > 0 {
            return totalDistance
        }
        
        if let distance = dailyPlan.distanceKm, distance > 0 {
            return distance
        }
        
        // Calculate from segments if available
        if let segments = trainingDetails?.segments, !segments.isEmpty {
            let segmentDistances = segments.compactMap { $0.distanceKm }
            let totalFromSegments = segmentDistances.reduce(0, +)
            return totalFromSegments
        }
        
        return 0
    }
    
    private func getDisplayPace(from dailyPlan: DailyPlanSummary) -> String {
        let trainingDetails = dailyPlan.trainingDetails
        
        // Use main pace if available and not empty
        if let pace = dailyPlan.pace, !pace.isEmpty {
            return pace
        }
        
        // If segments are available, show pace range or average
        if let segments = trainingDetails?.segments, !segments.isEmpty {
            let segmentPaces = segments.compactMap { segment -> String? in
                if let pace = segment.pace, !pace.isEmpty {
                    return pace
                } else {
                    return nil
                }
            }
            
            if !segmentPaces.isEmpty {
                if segmentPaces.count == 1 {
                    return segmentPaces[0]
                } else {
                    // Show pace range for segments
                    return "\(segmentPaces.first!) - \(segmentPaces.last!)"
                }
            }
        }
        
        return ""
    }
    
    private func shouldHidePace(_ type: String?) -> Bool {
        guard let type = type?.lowercased() else { return false }
        return type == "easy_run" || type == "easy" || type == "lsd" || type == "recovery_run"
    }

    private func formatTrainingType(_ type: String) -> String {
        switch type.lowercased() {
        case "easy_run", "easy":
            return NSLocalizedString("training.type.easy", comment: "Easy Run")
        case "recovery_run":
            return NSLocalizedString("training.type.recovery", comment: "Recovery Run")
        case "lsd":
            return NSLocalizedString("training.type.lsd", comment: "LSD Run")
        case "long_run":
            return NSLocalizedString("training.type.long", comment: "Long Run")
        case "tempo":
            return NSLocalizedString("training.type.tempo", comment: "Tempo Run")
        case "threshold":
            return NSLocalizedString("training.type.threshold", comment: "Threshold Run")
        case "race_pace":
            return NSLocalizedString("training.type.race_pace", comment: "Race Pace Run")
        case "race":
            return NSLocalizedString("training.type.race", comment: "Race")
        case "rest":
            return NSLocalizedString("training.type.rest_day", comment: "Rest Day")
        case "interval":
            return NSLocalizedString("training.type.interval", comment: "Interval Training")
        case "short_interval":
            return NSLocalizedString("training.type.short_interval", comment: "Short Intervals")
        case "long_interval":
            return NSLocalizedString("training.type.long_interval", comment: "Long Intervals")
        case "strides":
            return NSLocalizedString("training.type.strides", comment: "Strides")
        case "hill_repeats":
            return NSLocalizedString("training.type.hill_repeats", comment: "Hill Repeats")
        case "cruise_intervals":
            return NSLocalizedString("training.type.cruise_intervals", comment: "Cruise Intervals")
        case "norwegian_4x4":
            return NSLocalizedString("training.type.norwegian_4x4", comment: "Norwegian 4x4")
        case "norwegian_singles":
            return NSLocalizedString("training.type.norwegian_singles", comment: "Norwegian Singles")
        case "yasso_800":
            return NSLocalizedString("training.type.yasso_800", comment: "Yasso 800s")
        case "mile_repeats":
            return NSLocalizedString("training.type.mile_repeats", comment: "Mile Repeats")
        case "combination":
            return NSLocalizedString("training.type.combination", comment: "Combination Training")
        case "fartlek":
            return NSLocalizedString("training.type.fartlek", comment: "Fartlek")
        case "fast_finish":
            return NSLocalizedString("training.type.fast_finish", comment: "Fast Finish Run")
        case "progression":
            return NSLocalizedString("training.type.progression", comment: "Progression Run")
        case "cross_training":
            return NSLocalizedString("training.type.cross_training", comment: "Cross Training")
        case "strength":
            return NSLocalizedString("training.type.strength", comment: "Strength Training")
        case "yoga":
            return NSLocalizedString("training.type.yoga", comment: "Yoga")
        case "hiking":
            return NSLocalizedString("training.type.hiking", comment: "Hiking")
        case "cycling":
            return NSLocalizedString("training.type.cycling", comment: "Cycling")
        default:
            return type
        }
    }
}

struct TrainingInfoItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppFont.title3())
                .foregroundColor(.blue)
            
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
            
            Text(value)
                .font(AppFont.caption())
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    TrainingPlanInfoCard(workoutDetail: WorkoutV2Detail(
        id: "preview-1",
        provider: "Garmin",
        activityType: "running",
        sportType: "running",
        startTime: ISO8601DateFormatter().string(from: Date()),
        endTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
        userId: "user123",
        schemaVersion: "1.0",
        source: "garmin",
        storagePath: "/path/to/workout",
        createdAt: Optional<String>.none,
        updatedAt: Optional<String>.none,
        originalId: "original123",
        providerUserId: "provider123",
        garminUserId: Optional<String>.none,
        webhookStoragePath: Optional<String>.none,
        basicMetrics: Optional<V2BasicMetrics>.none,
        advancedMetrics: Optional<V2AdvancedMetrics>.none,
        timeSeries: Optional<V2TimeSeries>.none,
        routeData: Optional<V2RouteData>.none,
        deviceInfo: Optional<V2DeviceInfo>.none,
        environment: Optional<V2Environment>.none,
        metadata: Optional<V2Metadata>.none,
        laps: Optional<[LapData]>.none,
        dailyPlanSummary: DailyPlanSummary(
            dayTarget: "長距離輕鬆跑，建立耐力基礎。",
            distanceKm: 15,
            pace: "6:40",
            trainingType: "lsd",
            heartRateRange: DailySummaryHeartRateRange(min: 140, max: 160),
            trainingDetails: Optional<DailyTrainingDetails>.none
        ),
        aiSummary: AISummary(
            analysis: "這次長距離輕鬆跑訓練，您實際完成了約14.7公里，時間約101分鐘，配速約為6分43秒，與課表目標相當接近，建立耐力基礎的目標達成度很高。從心率分佈來看，大部分時間落在輕鬆和馬拉松配速區間，平均心率159 bpm，顯示訓練品質良好，有效地刺激了耐力系統。建議下次可以稍微增加距離，並注意到最大心率略高於預期，未來訓練中可嘗試更穩定的配速控制，確保心率維持在輕鬆跑的範圍內，以最大化訓練效果。"
        ),
        shareCardContent: Optional<ShareCardContent>.none,
        trainingNotes: Optional<String>.none
    ))
    .padding()
}
