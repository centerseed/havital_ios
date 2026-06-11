#if DEBUG
import SwiftUI

/// DEBUG-only 畫廊：用 mock payload 渲染 BenchmarkExecuteCard / BenchmarkCalibrationCard。
/// 進入點：以 launch argument `-BenchmarkCardGallery` 啟動 app。
/// 不影響 production 啟動路徑。
struct BenchmarkCardGalleryHost: View {
    @State private var executeSelected0 = true
    @State private var executeSelected1 = false
    @State private var calibSelected0 = false
    @State private var calibSelected1 = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    sectionHeader("執行確認卡 — BenchmarkExecuteCard")

                    // Execute card 1: 5K + 指定週六
                    BenchmarkExecuteCard(
                        payload: BenchmarkExecutePayload(
                            distanceKm: 5.0,
                            scheduledWeekday: 6
                        ),
                        index: 0,
                        isSelected: $executeSelected0
                    )

                    // Execute card 2: 3K + 無指定週間
                    BenchmarkExecuteCard(
                        payload: BenchmarkExecutePayload(
                            distanceKm: 3.0,
                            scheduledWeekday: nil
                        ),
                        index: 1,
                        isSelected: $executeSelected1
                    )

                    Divider().padding(.vertical, 4)

                    sectionHeader("校準成果卡 — BenchmarkCalibrationCard")

                    // Calibration card 1: 完整 before/after（shouldHedge: false）
                    BenchmarkCalibrationCard(
                        payload: BenchmarkCalibrationPayload(
                            workoutDate: "2026-06-18",
                            distanceKm: 5.0,
                            durationS: 1320,
                            shouldHedge: false,
                            paceBeforeSPerKm: 330,
                            paceAfterSPerKm: 322,
                            raceDistanceLabel: "半馬",
                            raceTimeBeforeS: 6750,
                            raceTimeAfterS: 6490,
                            vdotBefore: 42.5,
                            vdotAfter: 44.0
                        ),
                        index: 0,
                        isSelected: $calibSelected0
                    )

                    // Calibration card 2: 降級版（只有成績+VDOT，shouldHedge: true）
                    BenchmarkCalibrationCard(
                        payload: BenchmarkCalibrationPayload(
                            workoutDate: "2026-06-11",
                            distanceKm: 5.0,
                            durationS: 1500,
                            shouldHedge: true,
                            paceBeforeSPerKm: nil,
                            paceAfterSPerKm: nil,
                            raceDistanceLabel: nil,
                            raceTimeBeforeS: nil,
                            raceTimeAfterS: nil,
                            vdotBefore: 40.0,
                            vdotAfter: 41.5
                        ),
                        index: 1,
                        isSelected: $calibSelected1
                    )

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Benchmark Cards Gallery")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppFont.caption())
            .foregroundColor(.secondary)
            .textCase(.none)
    }
}

#Preview {
    BenchmarkCardGalleryHost()
}
#endif
