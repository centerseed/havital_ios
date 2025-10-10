import SwiftUI

/// 底部橫條版型 - 緊湊卡片式設計
struct BottomInfoOverlay: View {
    let data: WorkoutShareCardData

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // 主標題區域
                HStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)

                    Text(data.achievementTitle)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 42)
                .padding(.vertical, 20)
                .background(Color.black.opacity(0.4))

                // 課表資訊區域
                if let dailyPlan = data.workoutDetail?.dailyPlanSummary {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 36))
                            .foregroundColor(.white)

                        Text("課表：" + formatDailyPlan(dailyPlan))
                            .font(.system(size: 42))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 42)
                    .padding(.vertical, 20)
                    .background(Color.black.opacity(0.4))
                }

                // AI 評語區域
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.9))

                    Text(data.encouragementText)
                        .font(.system(size: 42, weight: .regular))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 42)
                .padding(.vertical, 20)
                .background(Color.black.opacity(0.4))

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

                    // 配速
                    if let pace = data.workout.basicMetrics?.avgPaceSPerKm {
                        HStack(spacing: 9) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.9))
                            Text(formatPace(pace))
                                .font(.system(size: 42))
                                .foregroundColor(.white)
                        }
                    }

                    // 動態跑力
                    if let vdot = data.workout.advancedMetrics?.dynamicVdot {
                        HStack(spacing: 9) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.9))
                            Text("跑力 \(String(format: "%.1f", vdot))")
                                .font(.system(size: 42))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 42)
                .padding(.vertical, 18)
                .background(Color.black.opacity(0.4))

                // 分隔線
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)

                // 品牌標示區域
                Text(NSLocalizedString("share_card.branding", comment: "Branding text"))
                    .font(.system(size: 42, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.4))
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
