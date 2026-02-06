import SwiftUI

/// 暖身/緩和跑顯示組件
/// 用於顯示訓練課程的暖身或緩和段資訊
struct WarmupCooldownView: View {
    let segment: RunSegment
    let type: SegmentType

    enum SegmentType {
        case warmup
        case cooldown

        var icon: String {
            switch self {
            case .warmup: return "🔥"
            case .cooldown: return "❄️"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .warmup: return Color.orange.opacity(0.1)
            case .cooldown: return Color.blue.opacity(0.1)
            }
        }

        var label: String {
            switch self {
            case .warmup: return "暖身"
            case .cooldown: return "緩和"
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            // 圖標標示
            Text(type.icon)
                .font(.caption)

            // 類型標籤
            Text(type.label)
                .font(.caption)
                .fontWeight(.medium)

            // 距離
            if let distanceKm = segment.distanceKm {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1fkm", distanceKm))
                    .font(.caption)
            } else if let distanceM = segment.distanceM {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%dm", distanceM))
                    .font(.caption)
            }

            // 配速
            if let pace = segment.pace {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(pace)
                    .font(.caption)
            }

            // 心率區間
            if let hrRange = segment.heartRateRange, hrRange.isValid,
               let displayText = hrRange.displayText {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("HR \(displayText)")
                    .font(.caption)
            }

            // 強度
            if let intensity = segment.intensity {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(intensity)
                    .font(.caption)
                    .italic()
            }

            // 描述
            if let description = segment.description, !description.isEmpty {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(type.backgroundColor)
        .cornerRadius(8)
    }
}

// MARK: - 預覽

#Preview("Warmup with Distance and Pace") {
    WarmupCooldownView(
        segment: RunSegment(
            distanceKm: 2.0,
            distanceM: nil,
            durationMinutes: 15,
            pace: "6:30",
            heartRateRange: HeartRateRangeV2(min: 120, max: 140),
            intensity: "easy",
            description: "輕鬆熱身"
        ),
        type: .warmup
    )
    .padding()
}

#Preview("Cooldown with Distance Only") {
    WarmupCooldownView(
        segment: RunSegment(
            distanceKm: 1.0,
            distanceM: nil,
            durationMinutes: 8,
            pace: "6:30",
            heartRateRange: nil,
            intensity: nil,
            description: "緩和跑"
        ),
        type: .cooldown
    )
    .padding()
}

#Preview("Warmup with Meters") {
    WarmupCooldownView(
        segment: RunSegment(
            distanceKm: nil,
            distanceM: 800,
            durationMinutes: 6,
            pace: "6:00",
            heartRateRange: nil,
            intensity: "moderate",
            description: nil
        ),
        type: .warmup
    )
    .padding()
}
