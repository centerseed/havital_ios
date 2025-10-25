import SwiftUI

struct LapAnalysisView: View {
    let laps: [LapData]
    let dataProvider: String
    let deviceModel: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Garmin attribution
            HStack {
                Text(L10n.LapAnalysisView.title.localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()

                // Garmin Attribution for lap data (badge only, no device name)
                ConditionalGarminAttributionView(
                    dataProvider: dataProvider,
                    deviceModel: nil,  // 不傳遞 deviceModel，只顯示 badge
                    displayStyle: .compact
                )
            }
            
            if laps.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "timer.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text(L10n.LapAnalysisView.noLapData.localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Lap data table
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Table header
                        HStack(spacing: 4) {
                            Text(L10n.LapAnalysisView.lapColumn.localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.1, alignment: .center)
                            
                            Text(L10n.LapAnalysisView.distanceColumn.localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                            
                            Text(L10n.LapAnalysisView.timeColumn.localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                            
                            Text(L10n.LapAnalysisView.paceColumn.localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                            
                            Text(L10n.LapAnalysisView.heartRateColumn.localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                        }
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        
                        // Table rows - 移除 ScrollView 讓長截圖能完整顯示所有資料
                        VStack(spacing: 0) {
                            ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
                                LapRowView(lap: lap, isEven: index % 2 == 0, width: geometry.size.width)
                                    .id(lap.id)
                            }
                        }
                    }
                    .cornerRadius(8)
                }
                .frame(height: CGFloat(laps.count * 35 + 40)) // 移除最大高度限制，讓所有資料都顯示
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

struct LapRowView: View {
    let lap: LapData
    let isEven: Bool
    let width: CGFloat
    
    var body: some View {
        HStack(spacing: 4) {
            // Lap number
            Text("\(lap.lapNumber)")
                .font(.caption)
                .frame(width: width * 0.1, alignment: .center)
            
            // Distance - 精簡顯示
            Text(lap.totalDistanceM != nil ? String(format: "%.2f", lap.totalDistanceM! / 1000) : "--")
                .font(.caption)
                .frame(width: width * 0.225, alignment: .center)
            
            // Time
            Text(lap.formattedTime)
                .font(.caption)
                .frame(width: width * 0.225, alignment: .center)
            
            // Pace
            Text(lap.formattedPace)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .frame(width: width * 0.225, alignment: .center)
            
            // Heart rate - 只顯示數字
            Text(lap.avgHeartRateBpm != nil ? "\(lap.avgHeartRateBpm!)" : "--")
                .font(.caption)
                .frame(width: width * 0.225, alignment: .center)
        }
        .frame(height: 35)
        .background(isEven ? Color(.tertiarySystemGroupedBackground).opacity(0.5) : Color.clear)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Preview with data
            LapAnalysisView(
                laps: [
                    LapData.previewData(lapNumber: 1, distance: 1000, time: 300, pace: 300, heartRate: 145),
                    LapData.previewData(lapNumber: 2, distance: 1000, time: 290, pace: 290, heartRate: 150),
                    LapData.previewData(lapNumber: 3, distance: 1000, time: 285, pace: 285, heartRate: 155),
                    LapData.previewData(lapNumber: 4, distance: 1000, time: 295, pace: 295, heartRate: 148),
                    LapData.previewData(lapNumber: 5, distance: 1000, time: 305, pace: 305, heartRate: 142)
                ],
                dataProvider: "garmin",
                deviceModel: "Forerunner 945"
            )
            
            // Preview without data
            LapAnalysisView(
                laps: [],
                dataProvider: "garmin",
                deviceModel: nil
            )
        }
        .padding()
    }
}

// MARK: - LapData Preview Extension

extension LapData {
    static func previewData(lapNumber: Int, distance: Double, time: Int, pace: Double, heartRate: Int?) -> LapData {
        // Create preview data by constructing a JSON dictionary
        let decoder = JSONDecoder()

        var jsonDict: [String: Any] = [
            "lap_number": lapNumber,
            "start_time_offset_s": (lapNumber - 1) * time,
            "total_time_s": time,
            "total_distance_m": distance,
            "avg_speed_m_per_s": 1000.0 / pace,
            "avg_pace_s_per_km": pace
        ]

        if let hr = heartRate {
            jsonDict["avg_heart_rate_bpm"] = hr
        }

        let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict)
        return try! decoder.decode(LapData.self, from: jsonData)
    }
}