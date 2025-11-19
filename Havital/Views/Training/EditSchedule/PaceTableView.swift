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
                    Text(L10n.EditSchedule.paceTableDescription.localized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)

                    // 配速區間詳情
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.EditSchedule.paceZoneDetails.localized)
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(PaceCalculator.PaceZone.allCases, id: \.self) { zone in
                            paceZoneRow(for: zone)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(L10n.EditSchedule.referencePaceTable.localized)
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
        case .anaerobic:
            return "anaerobic"
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
        case .anaerobic:
            return .purple
        case .interval:
            return .red
        }
    }

    private func paceDescription(for zone: PaceCalculator.PaceZone) -> String {
        switch zone {
        case .recovery:
            return L10n.EditSchedule.PaceZone.recoveryDesc.localized
        case .easy:
            return L10n.EditSchedule.PaceZone.easyDesc.localized
        case .tempo:
            return L10n.EditSchedule.PaceZone.tempoDesc.localized
        case .marathon:
            return L10n.EditSchedule.PaceZone.marathonDesc.localized
        case .threshold:
            return L10n.EditSchedule.PaceZone.thresholdDesc.localized
        case .anaerobic:
            return L10n.EditSchedule.PaceZone.anaerobicDesc.localized
        case .interval:
            return L10n.EditSchedule.PaceZone.intervalDesc.localized
        }
    }

    private func paceBenefit(for zone: PaceCalculator.PaceZone) -> String {
        switch zone {
        case .recovery:
            return L10n.EditSchedule.PaceZone.recoveryBenefit.localized
        case .easy:
            return L10n.EditSchedule.PaceZone.easyBenefit.localized
        case .tempo:
            return L10n.EditSchedule.PaceZone.tempoBenefit.localized
        case .marathon:
            return L10n.EditSchedule.PaceZone.marathonBenefit.localized
        case .threshold:
            return L10n.EditSchedule.PaceZone.thresholdBenefit.localized
        case .anaerobic:
            return L10n.EditSchedule.PaceZone.anaerobicBenefit.localized
        case .interval:
            return L10n.EditSchedule.PaceZone.intervalBenefit.localized
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
