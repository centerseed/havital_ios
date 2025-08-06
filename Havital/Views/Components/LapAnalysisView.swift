import SwiftUI

struct LapAnalysisView: View {
    let laps: [LapData]
    let dataProvider: String
    let deviceModel: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Garmin attribution
            HStack {
                Text("圈速分析")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Garmin Attribution for lap data
                ConditionalGarminAttributionView(
                    dataProvider: dataProvider,
                    deviceModel: deviceModel,
                    displayStyle: .secondary
                )
            }
            
            if laps.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "timer.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("無圈速數據")
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
                            Text("圈")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.1, alignment: .center)
                            
                            Text("距離")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                            
                            Text("時間")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                            
                            Text("配速")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                            
                            Text("心率")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(width: geometry.size.width * 0.225, alignment: .center)
                        }
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        
                        // Table rows
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
                                    LapRowView(lap: lap, isEven: index % 2 == 0, width: geometry.size.width)
                                        .id(lap.id)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .frame(height: min(CGFloat(laps.count * 35 + 40), 340))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
        .background(isEven ? Color(.systemGray6).opacity(0.3) : Color(.systemBackground))
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
        // This is a simplified approach for preview - in real implementation this would come from JSON decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let jsonData = """
        {
            "lap_number": \(lapNumber),
            "start_time_offset_s": \((lapNumber - 1) * time),
            "total_time_s": \(time),
            "total_distance_m": \(distance),
            "avg_speed_m_per_s": \(1000.0 / pace),
            "avg_pace_s_per_km": \(pace),
            "avg_heart_rate_bpm": \(heartRate ?? 0)
        }
        """.data(using: .utf8)!
        
        return try! decoder.decode(LapData.self, from: jsonData)
    }
}