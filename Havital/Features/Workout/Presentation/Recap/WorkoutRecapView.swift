import SwiftUI

// MARK: - WorkoutRecapView (SKELETON — visuals to be designed)
//
// ⚠️ 這是「底層骨架」：資料綁定、付費 gating、dismiss 流程都已接好且可運作，
//    但視覺刻意維持最簡。claude design 完成設計後，直接替換各 section 的 body 即可，
//    不需動觸發 / 資料層。
//
// 已接好的接縫（design 可直接用）：
//   - content: WorkoutRecapContent（所有欄位皆已格式化）
//   - content.isPremium → 決定 AI 顯示完整 or teaser + 升級提示
//   - dismiss()：關閉 = InterruptCoordinator 標記該筆已讀（每筆只彈一次）
//   - onWriteDiary / onUpgrade：行為接縫（目前先 dismiss，之後接日記/付費流程）

struct WorkoutRecapView: View {
    let content: WorkoutRecapContent
    var onWriteDiary: (() -> Void)? = nil
    var onUpgrade: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showConfetti = true

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        metricsSection
                        diarySection
                    }
                    .padding(20)
                }
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("訓練回顧")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.Common.done.localized) { dismiss() }
                            .font(AppFont.label())
                    }
                }
            }

            // 撒花：放在 sheet 內容最上層（不掛在 ScrollView overlay，避免被裁切），
            // 進場灑落一次，~3 秒後自動移除（不留殘留）。
            if showConfetti {
                RecapConfettiCannon()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            withAnimation(.easeOut(duration: 0.4)) { showConfetti = false }
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections (DESIGN: 替換以下視覺)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = content.celebrationTitle {
                Text(title)
                    .font(AppFont.numberMedium())
            } else if let type = content.trainingTypeName {
                Text("完成了一次\(type)")
                    .font(AppFont.numberMedium())
            } else {
                Text("訓練完成")
                    .font(AppFont.numberMedium())
            }
            if let encouragement = content.encouragement {
                Text(encouragement)
                    .font(AppFont.captionRegular())
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsSection: some View {
        HStack(spacing: 0) {
            metricCell(label: "距離", value: content.distanceText)
            divider
            metricCell(label: "配速", value: content.paceText)
            divider
            metricCell(label: "時間", value: content.durationText)
            if let vdot = content.vdot {
                divider
                metricCell(label: "VDOT", value: String(format: "%.1f", vdot))
            }
            if let rpe = content.rpe {
                divider
                metricCell(label: "主觀強度", value: String(format: "%.0f", rpe))
            }
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.numberMedium().monospacedDigit())
            Text(label)
                .font(AppFont.micro())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1).padding(.vertical, 8)
    }

    private var diarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("訓練心得")
                .font(AppFont.bodyStrong())
            Button {
                (onWriteDiary ?? { dismiss() })()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                    Text("寫下今天的感受")
                }
                .font(AppFont.label())
                .foregroundColor(PacerizColor.blueDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PacerizColor.blue.opacity(0.10))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
