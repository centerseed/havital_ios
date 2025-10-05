import SwiftUI

/// 配速表展示視圖
/// 參考心率區間 UI 風格，顯示訓練配速區間範圍
struct PaceTableView: View {
    let vdot: Double
    let calculatedPaces: [PaceCalculator.PaceZone: String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 說明文字
                    Text("根據您的跑力計算的訓練配速建議，每個區間顯示最快配速 - 最慢配速範圍")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)

                    // 配速區間詳情
                    VStack(alignment: .leading, spacing: 8) {
                        Text("配速區間詳情")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(PaceCalculator.PaceZone.allCases, id: \.self) { zone in
                            paceZoneRow(for: zone)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("參考配速表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 子視圖

    private func paceZoneRow(for zone: PaceCalculator.PaceZone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(zone.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                // 顯示配速範圍（最快-最慢）
                if let paceRange = PaceCalculator.getPaceRange(for: zoneToPaceType(zone), vdot: vdot) {
                    Text("\(paceRange.min) - \(paceRange.max)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }

            Text(paceDescription(for: zone))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(paceBenefit(for: zone))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(paceColor(for: zone).opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - 輔助方法

    /// 將 PaceZone 轉換為訓練類型字串（用於 getPaceRange）
    private func zoneToPaceType(_ zone: PaceCalculator.PaceZone) -> String {
        switch zone {
        case .recovery:
            return "recovery"
        case .easy:
            return "easy"
        case .tempo:
            return "tempo"
        case .marathon:
            return "marathon"
        case .threshold:
            return "threshold"
        case .interval:
            return "interval"
        }
    }

    private func paceColor(for zone: PaceCalculator.PaceZone) -> Color {
        switch zone {
        case .recovery:
            return .blue
        case .easy:
            return .green
        case .tempo:
            return .yellow
        case .marathon:
            return .orange
        case .threshold:
            return .orange
        case .interval:
            return .red
        }
    }

    private func paceDescription(for zone: PaceCalculator.PaceZone) -> String {
        switch zone {
        case .recovery:
            return "用於恢復日，放鬆慢跑，促進身體恢復"
        case .easy:
            return "日常訓練基礎配速，可以舒適對話，建立有氧基礎"
        case .tempo:
            return "乳酸閾值訓練，維持 20-30 分鐘，提升跑步經濟性"
        case .marathon:
            return "目標馬拉松比賽配速，長距離持續配速訓練"
        case .threshold:
            return "高強度有氧訓練，提升最大攝氧量"
        case .interval:
            return "高強度間歇訓練，短距離快速，提升速度與爆發力"
        }
    }

    private func paceBenefit(for zone: PaceCalculator.PaceZone) -> String {
        switch zone {
        case .recovery:
            return "效益：促進肌肉恢復、減少疲勞累積"
        case .easy:
            return "效益：建立有氧基礎、增強耐力、降低受傷風險"
        case .tempo:
            return "效益：提升乳酸閾值、改善跑步經濟性、增強心肺功能"
        case .marathon:
            return "效益：適應馬拉松配速、提升長距離耐力、模擬比賽強度"
        case .threshold:
            return "效益：提升最大攝氧量、增強有氧能力、改善速度耐力"
        case .interval:
            return "效益：提升最大攝氧量、增強速度與爆發力、改善跑步效率"
        }
    }
}

// MARK: - Preview

#Preview {
    PaceTableView(
        vdot: 45.5,
        calculatedPaces: PaceCalculator.calculateTrainingPaces(vdot: 45.5)
    )
}
