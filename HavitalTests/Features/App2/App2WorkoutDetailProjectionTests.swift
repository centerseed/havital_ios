import XCTest
@testable import paceriz_dev

/// 已完成紀錄的訓練詳情投影（設計 frame-15～17）。
///
/// 與既有的 `WorkoutDetailUnitConversionTests` 不重疊：那一份鎖的是 1.4
/// `WorkoutDetailViewModelV2` 的配速取值優先序（暫停時該用 backend avg pace），
/// 這一份鎖的是 2.0 投影層的三件事：
/// 1. 「納入 VDOT 計算」的三態 ↔ 後端 `vdot_override` 的對應（送錯就是改到別人的能力估算）。
/// 2. 組不出值的格子**不出現**——`0 kcal` 是「沒算出來」，不是「燒了 0 大卡」。
/// 3. 單位換算與時長格式（英制時 `/mi`，超過一小時才有小時位）。
final class App2WorkoutDetailProjectionTests: XCTestCase {

    // MARK: - Helpers

    private func workout(
        id: String = "w1",
        provider: String = "garmin",
        activityType: String = "running",
        durationSeconds: Int = 3504,
        distanceMeters: Double? = 12_050,
        basicMetrics: BasicMetrics? = nil,
        advancedMetrics: AdvancedMetrics? = nil,
        dailyPlanSummary: DailyPlanSummary? = nil,
        aiSummary: AISummary? = nil
    ) -> WorkoutV2 {
        WorkoutV2(
            id: id,
            provider: provider,
            activityType: activityType,
            startTimeUtc: "2026-08-25T06:32:00Z",
            endTimeUtc: nil,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: nil,
            basicMetrics: basicMetrics,
            advancedMetrics: advancedMetrics,
            createdAt: nil,
            schemaVersion: nil,
            storagePath: nil,
            dailyPlanSummary: dailyPlanSummary,
            aiSummary: aiSummary,
            shareCardContent: nil
        )
    }

    private func make(
        _ workout: WorkoutV2,
        unitSystem: UnitSystem = .metric
    ) -> App2WorkoutDetailProjection {
        App2WorkoutDetailProjection.make(
            workout: workout,
            detail: nil,
            personalBestLabel: nil,
            unitSystem: unitSystem
        )
    }

    // MARK: - VDOT 三態 ↔ vdot_override

    func test_vdotInclusion_noOverrideIsAutomatic() {
        XCTAssertEqual(App2WorkoutDetailProjection.VDOTInclusion.from(nil), .automatic)
    }

    func test_vdotInclusion_notExcludedIsIncluded() {
        let override = VDOTOverride(excluded: false, reason: nil, updatedAt: nil)
        XCTAssertEqual(App2WorkoutDetailProjection.VDOTInclusion.from(override), .included)
    }

    func test_vdotInclusion_excludedKeepsExistingReason() {
        let override = VDOTOverride(excluded: true, reason: "trail", updatedAt: nil)
        XCTAssertEqual(
            App2WorkoutDetailProjection.VDOTInclusion.from(override),
            .excluded(reason: "trail")
        )
    }

    /// 「自動」必須送 `nil`（＝清掉 override），不是送 `excluded: false`。
    /// 送錯的話「自動」與「一定納入」在後端就是同一件事，三態塌成兩態。
    func test_automaticRequest_isNil() {
        XCTAssertNil(App2WorkoutDetailProjection.VDOTInclusion.automatic.request)
    }

    func test_includedRequest_isNotExcluded() {
        let request = App2WorkoutDetailProjection.VDOTInclusion.included.request
        XCTAssertEqual(request, VDOTOverrideRequest(excluded: false, reason: nil))
    }

    /// 排除必須帶 reason —— 後端的 reason taxonomy 是既有的，沒帶就退成 `other`。
    func test_excludedRequest_defaultsReasonToOther() {
        let request = App2WorkoutDetailProjection.VDOTInclusion.excluded(reason: nil).request
        XCTAssertEqual(request, VDOTOverrideRequest(excluded: true, reason: "other"))
    }

    func test_excludedRequest_preservesExistingReason() {
        let request = App2WorkoutDetailProjection.VDOTInclusion.excluded(reason: "trail").request
        XCTAssertEqual(request, VDOTOverrideRequest(excluded: true, reason: "trail"))
    }

    /// 面板上的勾勾比的是「哪一種選擇」，不是 reason —— 排除（越野）與排除（其他）
    /// 在畫面上是同一顆選項。
    func test_isSameChoice_ignoresExcludedReason() {
        XCTAssertTrue(
            App2WorkoutDetailProjection.VDOTInclusion.excluded(reason: nil)
                .isSameChoice(as: .excluded(reason: "trail"))
        )
        XCTAssertFalse(
            App2WorkoutDetailProjection.VDOTInclusion.automatic.isSameChoice(as: .included)
        )
    }

    // MARK: - 組不出值的格子不出現

    /// 卡路里整項拿掉（2026-08-27 走查使用者拍板）——有值也不畫。
    func test_metrics_neverShowsCalories() {
        let projection = make(workout(basicMetrics: BasicMetrics(caloriesKcal: 742)))
        XCTAssertFalse(projection.metrics.contains { $0.key == "calories" })
    }

    func test_metrics_omitsMissingHeartRate() {
        let projection = make(workout(basicMetrics: BasicMetrics(avgHeartRateBpm: nil)))
        XCTAssertFalse(projection.metrics.contains { $0.key == "avg_hr" })
        XCTAssertFalse(projection.metrics.contains { $0.key == "max_hr" })
    }

    func test_metrics_omitsMissingDistance() {
        let projection = make(workout(distanceMeters: nil))
        XCTAssertFalse(projection.metrics.contains { $0.key == "distance" })
        // 時長永遠在（它一定算得出來）。
        XCTAssertTrue(projection.metrics.contains { $0.key == "duration" })
    }

    func test_advancedMetrics_emptyWhenNoAdvancedPayload() {
        XCTAssertTrue(make(workout()).advancedMetrics.isEmpty)
    }

    // MARK: - 基礎／進階分類（2026-08-27（m）使用者拍板）
    //
    // 進階＝訓練負荷 TSS、跑力 Dynamic VDOT、垂直振幅比，**就這三項**；其餘（含 RPE）
    // 是基礎指標。這一組測試鎖的是「同一項不得在兩區各出現一次」——2026-08-26
    // 那條「進階區去掉 VDOT／TSS」的舊裁定已被取代，改成把它們從**基礎磚**移出。

    private func fullyLoadedWorkout() -> WorkoutV2 {
        workout(
            basicMetrics: BasicMetrics(
                avgHeartRateBpm: 148,
                maxHeartRateBpm: 172,
                avgPaceSPerKm: 291,
                caloriesKcal: 742
            ),
            advancedMetrics: AdvancedMetrics(
                dynamicVdot: 57.2,
                tss: 78,
                rpe: 4,
                avgVerticalRatioPercent: 8.2
            )
        )
    }

    func test_advancedMetrics_isTssThenVdotThenVerticalRatio() {
        let projection = make(fullyLoadedWorkout())
        XCTAssertEqual(projection.advancedMetrics.map(\.key), ["load", "vdot", "vertical_ratio"])
        XCTAssertEqual(projection.advancedMetrics.first { $0.key == "load" }?.value, "78")
        XCTAssertEqual(projection.advancedMetrics.first { $0.key == "vdot" }?.value, "57.2")
        XCTAssertEqual(projection.advancedMetrics.first { $0.key == "vertical_ratio" }?.unit, "%")
    }

    /// 進階那三項不得再出現在基礎指標磚上。
    func test_metrics_excludeAdvancedTrio() {
        let keys = make(fullyLoadedWorkout()).metrics.map(\.key)
        XCTAssertFalse(keys.contains("vdot"))
        XCTAssertFalse(keys.contains("load"))
        XCTAssertFalse(keys.contains("vertical_ratio"))
    }

    /// RPE 是基礎指標（不是進階）——(m) 的分類把它留在基礎那一區。
    func test_metrics_includeRPE() {
        let projection = make(fullyLoadedWorkout())
        let rpe = projection.metrics.first { $0.key == "rpe" }
        XCTAssertEqual(rpe?.value, "4")
        XCTAssertEqual(rpe?.unit, "/10")
        XCTAssertFalse(projection.advancedMetrics.contains { $0.key == "rpe" })
    }

    /// 基礎指標磚的順序：距離／時長 · 平均配速／平均心率 · 最大心率／RPE（無卡路里）。
    func test_metrics_orderAfterReclassification() {
        XCTAssertEqual(
            make(fullyLoadedWorkout()).metrics.map(\.key),
            ["distance", "duration", "pace", "avg_hr", "max_hr", "rpe"]
        )
    }

    /// 缺哪一項就少哪一格，不補 placeholder（進階區同樣規則）。
    func test_advancedMetrics_omitsMissingValues() {
        let projection = make(
            workout(advancedMetrics: AdvancedMetrics(dynamicVdot: 57.2))
        )
        XCTAssertEqual(projection.advancedMetrics.map(\.key), ["vdot"])
    }

    // MARK: - 單位與格式

    func test_distance_metricIsKilometres() {
        let metric = App2WorkoutDetailProjection.distanceMetric(meters: 12_050, unitSystem: .metric)
        XCTAssertEqual(metric.value, "12.05")
        XCTAssertEqual(metric.unit, "km")
    }

    func test_distance_imperialIsMiles() {
        let metric = App2WorkoutDetailProjection.distanceMetric(meters: 12_050, unitSystem: .imperial)
        XCTAssertEqual(metric.unit, "mi")
        XCTAssertEqual(metric.value, "7.49")
    }

    func test_pace_imperialConvertsPerMile() {
        XCTAssertEqual(
            App2WorkoutDetailProjection.formatPace(secondsPerKm: 291, unitSystem: .metric),
            "4:51"
        )
        // 291 s/km × 1.60934 ≈ 468 s/mi = 7:48
        XCTAssertEqual(
            App2WorkoutDetailProjection.formatPace(secondsPerKm: 291, unitSystem: .imperial),
            "7:48"
        )
    }

    func test_duration_showsHoursOnlyWhenPresent() {
        XCTAssertEqual(App2WorkoutDetailProjection.formatDuration(seconds: 3504), "58:24")
        XCTAssertEqual(App2WorkoutDetailProjection.formatDuration(seconds: 7384), "2:03:04")
        XCTAssertEqual(App2WorkoutDetailProjection.formatDuration(seconds: nil), "0:00")
    }

    // MARK: - Hero

    /// 標題優先用課型（「這堂課練什麼」），不是活動型別（「是跑步還是騎車」）。
    func test_title_prefersTrainingTypeOverActivityType() {
        let projection = make(
            workout(advancedMetrics: AdvancedMetrics(trainingType: "easy"))
        )
        XCTAssertEqual(projection.title, DayType.easy.localizedName)
    }

    func test_title_fallsBackToActivityTypeWhenNoTrainingType() {
        XCTAssertEqual(
            make(workout()).title,
            L10n.App2.WorkoutDetail.activityRunning.localized
        )
    }

    func test_providerLabel_mapsKnownProviders() {
        XCTAssertEqual(App2WorkoutDetailProjection.providerLabel("garmin"), "Garmin")
        XCTAssertEqual(App2WorkoutDetailProjection.providerLabel("strava"), "Strava")
        XCTAssertEqual(App2WorkoutDetailProjection.providerLabel("healthkit"), "Apple Health")
    }

    // MARK: - 主導心率區

    func test_dominantZone_picksLargestShare() {
        let zones = V2ZoneDistribution(
            from: ZoneDistribution(
                marathon: 5, threshold: 3, recovery: 12, interval: 0, anaerobic: 0, easy: 68
            )
        )
        // chip 是「Z 編號 ＋ 區名」（8/28 盤點 D18，frame-02f）——只寫區名的話
        // 用戶對不回自己設定頁那六條區間。
        XCTAssertEqual(
            App2WorkoutDetailProjection.dominantZoneLabel(zones),
            "Z2 " + NSLocalizedString("workout.detail.aerobic_zone", comment: "")
        )
    }

    /// 全零 ＝ 沒有分佈資料，不是「都在恢復區」——那顆 chip 不出現。
    func test_dominantZone_nilWhenAllZero() {
        let zones = V2ZoneDistribution(
            from: ZoneDistribution(
                marathon: 0, threshold: 0, recovery: 0, interval: 0, anaerobic: 0, easy: 0
            )
        )
        XCTAssertNil(App2WorkoutDetailProjection.dominantZoneLabel(zones))
        XCTAssertNil(App2WorkoutDetailProjection.dominantZoneLabel(nil))
    }

    // MARK: - 課表 vs 實際

    func test_plannedSummary_nilWhenNoPlanForThatDay() {
        XCTAssertNil(App2WorkoutDetailProjection.plannedSummary(nil))
    }

    func test_plannedSummary_joinsAvailableParts() {
        let plan = DailyPlanSummary(
            dayTarget: nil,
            distanceKm: 8,
            pace: "6:50",
            trainingType: "easy",
            heartRateRange: nil,
            trainingDetails: nil
        )
        XCTAssertEqual(
            App2WorkoutDetailProjection.plannedSummary(plan),
            "\(DayType.easy.localizedName) · 8.0 km · 6:50"
        )
    }

    func test_actualSummary_nilWhenNothingToSay() {
        XCTAssertNil(App2WorkoutDetailProjection.actualSummary(durationS: 0, avgHR: nil))
    }

    func test_actualSummary_durationOnlyWhenNoHeartRate() {
        XCTAssertEqual(
            App2WorkoutDetailProjection.actualSummary(durationS: 3504, avgHR: nil),
            "58:24"
        )
    }
}
