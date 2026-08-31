import SwiftUI

// MARK: - MileageChartGalleryHost
//
// DEBUG-only 視覺驗收 host（沿用 BenchmarkCardGalleryHost 慣例）。
// 啟動方式：xcrun simctl launch <udid> com.havital.paceriz.dev -MileageChartGallery
//
// 用途：在真實模擬器上渲染 WeeklyMileageChartView 的兩組情境，
//   1) 新資料（有 safety_ceiling_km + race_threshold_km + long_run.max_km）
//   2) 舊資料（三者皆缺）→ 必須不 crash、不畫參考線
// 深／淺色由模擬器外觀切換驗證。

#if DEBUG
struct MileageChartGalleryHost: View {

    /// "all"（預設）/ "modern" / "legacy" / "imperial"
    /// 用 SIMCTL_CHILD_UITEST_MILEAGE_CHART_SCENARIO 指定，方便逐張截圖驗收
    private var scenario: String {
        ProcessInfo.processInfo.environment["UITEST_MILEAGE_CHART_SCENARIO"]?.lowercased() ?? "all"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    if base == "all" || base == "modern" {
                        sectionHeader("New data - both reference lines")
                        WeeklyMileageChartView(preview: Self.modernPreview)
                    }

                    if base == "all" || base == "legacy" {
                        sectionHeader("Legacy data - no reference lines / no long run")
                        WeeklyMileageChartView(preview: Self.legacyPreview)
                    }

                    if base == "all" || base == "imperial" {
                        sectionHeader("Imperial - distance_unit = mi")
                        WeeklyMileageChartView(preview: Self.imperialPreview)
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Weekly Mileage Chart Gallery")
            .navigationBarTitleDisplayMode(.inline)
        }
        // scenario 後綴 "-dark" 時強制深色：部分模擬器不吃 `simctl ui appearance dark`
        .preferredColorScheme(forceDark ? .dark : nil)
    }

    private var forceDark: Bool { scenario.hasSuffix("-dark") }

    /// 去掉 "-dark" 後綴的情境名
    private var base: String {
        forceDark ? String(scenario.dropLast(5)) : scenario
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.secondary)
    }

    // MARK: - Fixtures

    /// 20 週：base 8 / build 6 / peak 4 / taper 2，無每 4 週假凹陷
    private static func weeks(imperial: Bool, withLongRun: Bool) -> [WeekPreview] {
        let stages: [(String, Int)] = [("base", 8), ("build", 6), ("peak", 4), ("taper", 2)]
        var result: [WeekPreview] = []
        var week = 1
        var km = 34.0
        for (stage, count) in stages {
            for _ in 0..<count {
                let isTaper = stage == "taper"
                let targetKm = isTaper ? km * 0.65 : km
                result.append(
                    WeekPreview(
                        week: week,
                        stageId: stage,
                        targetKm: targetKm,
                        targetKmDisplay: imperial
                            ? (UnitSystem.imperial.convertedDistance(targetKm) * 100).rounded() / 100
                            : nil,
                        distanceUnit: imperial ? "mi" : nil,
                        isRecovery: false,
                        milestoneRef: nil,
                        intensityRatio: nil,
                        qualityOptions: [],
                        longRun: withLongRun ? "long_run" : nil,
                        longRunKm: withLongRun ? (targetKm * 0.34) : nil
                    )
                )
                week += 1
                if !isTaper { km += 2.6 }
            }
        }
        return result
    }

    static let modernPreview = WeeklyPreviewV2(
        id: "gallery-modern",
        methodologyId: "paceriz",
        weeks: weeks(imperial: false, withLongRun: true),
        createdAt: nil,
        updatedAt: nil,
        safetyCeilingKm: 72,
        raceThresholdKm: 42.2
    )

    static let legacyPreview = WeeklyPreviewV2(
        id: "gallery-legacy",
        methodologyId: "paceriz",
        weeks: weeks(imperial: false, withLongRun: false),
        createdAt: nil,
        updatedAt: nil
    )

    static let imperialPreview = WeeklyPreviewV2(
        id: "gallery-imperial",
        methodologyId: "paceriz",
        weeks: weeks(imperial: true, withLongRun: true),
        createdAt: nil,
        updatedAt: nil,
        safetyCeilingKm: 72,
        raceThresholdKm: 42.2
    )
}
#endif
