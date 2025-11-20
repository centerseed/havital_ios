import SwiftUI

/// 底部橫條版型 - 緊湊卡片式設計
struct BottomInfoOverlay: View {
    let data: WorkoutShareCardData
    var onEditTitle: (() -> Void)? = nil
    var onEditEncouragement: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // 整張圖的統一漸層遮罩（由上往下 0 -> 0.4）
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.4), location: 1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // 主標題區域（如果標題為空字串則不顯示）
                    if !data.achievementTitle.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(.white)

                            Text(data.achievementTitle)
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .onTapGesture {
                                    onEditTitle?()
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 42)
                        .padding(.vertical, 20)
                    }

                    // 核心數據區域（水平排列，簡潔樣式）
                    HStack(spacing: 24) {
                        // 距離
                        if let distance = data.workout.distanceMeters {
                            HStack(spacing: 9) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.9))
                                Text(String(format: "%.1f km", distance / 1000))
                                    .font(.system(size: 42))
                                    .foregroundColor(.white)
                            }
                        }

                        // 配速（優先使用 avgPaceSPerKm，否則從 avgSpeedMPerS 計算）
                        if let paceText = getPaceText() {
                            HStack(spacing: 9) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.9))
                                Text(paceText)
                                    .font(.system(size: 42))
                                    .foregroundColor(.white)
                            }
                        }

                        // 平均心率
                        if let avgHR = data.workout.basicMetrics?.avgHeartRateBpm {
                            HStack(spacing: 9) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(Int(avgHR))")
                                    .font(.system(size: 42))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 42)
                    .padding(.vertical, 18)

                    // AI 評語區域（如果簡評為空字串則不顯示）
                    if !data.encouragementText.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.9))

                            Text(data.encouragementText)
                                .font(.system(size: 42, weight: .regular))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .onTapGesture {
                                    onEditEncouragement?()
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 42)
                        .padding(.vertical, 20)
                    }

                    // 分隔線
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)

                    // 品牌標示區域
                    Image("paceriz_light")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
        }
    }

    /// 格式化課表資訊
    private func formatDailyPlan(_ plan: DailyPlanSummary) -> String {
        var parts: [String] = []

        // 訓練型態
        if let trainingType = plan.trainingType {
            parts.append(formatTrainingType(trainingType))
        }

        // 配速（輕鬆跑、長距離輕鬆跑、恢復跑不顯示）
        let shouldShowPace = !(plan.trainingType?.lowercased().contains("easy") == true ||
                              plan.trainingType?.lowercased().contains("recovery") == true ||
                              plan.trainingType?.lowercased().contains("long") == true)

        if shouldShowPace {
            // 優先使用 pace 字段（已格式化的字串）
            if let pace = plan.pace, !pace.isEmpty {
                parts.append(pace)
            } else if let segments = plan.trainingDetails?.segments, !segments.isEmpty {
                // 取第一個 segment 的配速（也是已格式化的字串）
                if let firstPace = segments.first?.pace, !firstPace.isEmpty {
                    parts.append(firstPace)
                }
            }
        }

        // 距離 - 優先使用 trainingDetails.totalDistanceKm，其次是 distanceKm
        if let distance = plan.trainingDetails?.totalDistanceKm ?? plan.distanceKm, distance > 0 {
            parts.append(String(format: "%.1f km", distance))
        }

        return parts.joined(separator: " · ")
    }

    /// 格式化訓練類型
    private func formatTrainingType(_ type: String) -> String {
        switch type.lowercased() {
        case "easy_run", "easy": return "輕鬆跑"
        case "recovery_run": return "恢復跑"
        case "long_run": return "長距離輕鬆跑"
        case "tempo": return "節奏跑"
        case "threshold": return "乳酸閾值跑"
        case "interval": return "間歇訓練"
        case "fartlek": return "法特萊克"
        case "hill_training": return "爬坡訓練"
        case "race": return "比賽"
        default: return type
        }
    }

    /// 格式化配速（從秒數轉換）
    private func formatPaceFromSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d'%02d\"", minutes, secs)
    }

    /// 格式化配速
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    /// 獲取配速文字（優先使用 avgPaceSPerKm，否則從 avgSpeedMPerS 計算）
    private func getPaceText() -> String? {
        // 優先使用 avgPaceSPerKm
        if let pace = data.workout.basicMetrics?.avgPaceSPerKm {
            return formatPace(pace)
        }

        // 如果沒有，從 avgSpeedMPerS 計算
        if let speed = data.workout.basicMetrics?.avgSpeedMPerS, speed > 0 {
            // 配速（秒/公里）= 1000 / 速度（米/秒）
            let paceSecondsPerKm = 1000.0 / speed
            return formatPace(paceSecondsPerKm)
        }

        return nil
    }
}

/// 數據項組件（用於分享卡）
struct ShareCardDataItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.9))

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}
