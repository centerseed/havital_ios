import XCTest
@testable import paceriz_dev

/// 2.0 onboarding 的即時換算（`App2OnboardingProjection` 的純函式）。
///
/// 這一頁的數字是使用者**在決定要不要繼續之前**看到的東西，算錯不會有紅燈、
/// 只會讓人在完成頁才發現對不上。三組各自鎖住：
///
/// - 心率色帶必須完全來自既有 `HeartRateZone.calculateZones`（不得長出第二組百分比）
/// - VDOT 必須與後端 `core/calculations/vdot.py` 同一條公式（race 路徑 ×1.05）
/// - 跑量預覽的四個數字必須從「起始量 ＋ 總週數」單向推出來
@MainActor
final class App2OnboardingProjectionTests: XCTestCase {

    // MARK: - 心率區間

    func test_heartRateBands_areFiveAndEndAtMaxHR() {
        let bands = App2OnboardingProjection.heartRateBands(maxHR: 188, restingHR: 48)

        XCTAssertEqual(bands.count, 5, "設計 frame-33 是五條色帶")
        XCTAssertEqual(bands.map(\.index), [1, 2, 3, 4, 5])
        XCTAssertEqual(bands.last?.upperBpm, 188, "Z5 的上緣就是最大心率")
    }

    /// 每一條的上限都必須等於既有分區算出來的值 —— 不得有本地硬寫的百分比。
    func test_heartRateBands_upperBoundsComeFromExistingZoneModel() {
        let maxHR = 188
        let restingHR = 48
        let zones = HeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)
        let bands = App2OnboardingProjection.heartRateBands(maxHR: maxHR, restingHR: restingHR)

        for zoneNumber in 1...4 {
            let expected = Int(zones.first(where: { $0.zone == zoneNumber })!.range.upperBound.rounded())
            XCTAssertEqual(bands[zoneNumber - 1].upperBpm, expected,
                           "Z\(zoneNumber) 必須沿用既有 HeartRateZone 的上緣")
        }
    }

    func test_heartRateBands_areMonotonicallyIncreasing() {
        let bands = App2OnboardingProjection.heartRateBands(maxHR: 190, restingHR: 48)
        let uppers = bands.map(\.upperBpm)
        XCTAssertEqual(uppers, uppers.sorted(), "區間上限不得倒退")
    }

    func test_heartRateBands_emptyWhenRestingNotBelowMax() {
        XCTAssertTrue(App2OnboardingProjection.heartRateBands(maxHR: 150, restingHR: 150).isEmpty)
        XCTAssertTrue(App2OnboardingProjection.heartRateBands(maxHR: 140, restingHR: 150).isEmpty)
    }

    func test_estimatedMaxHR_is220MinusAgeWithFloor() {
        XCTAssertEqual(App2OnboardingProjection.estimatedMaxHR(age: 32), 188)
        XCTAssertEqual(App2OnboardingProjection.estimatedMaxHR(age: 30), 190)
        XCTAssertEqual(App2OnboardingProjection.estimatedMaxHR(age: 130), 100, "地板 100")
    }

    // MARK: - VDOT

    /// 手算對照（後端 `get_vdot` × 1.05）：5 km / 19:45
    /// v = 5000 / 19.75 = 253.16 m/min
    /// vo2 = -4.6 + 0.182258·v + 0.000104·v² = 48.21
    /// pct = 0.8 + 0.1894393·e^(-0.012778·19.75) + 0.2989558·e^(-0.1932605·19.75) = 0.9538
    /// vdot = 48.21 / 0.9538 = 50.54  →  race ×1.05 = 53.07
    func test_estimatedRaceVDOT_matchesBackendDanielsFormula() throws {
        let vdot = try XCTUnwrap(
            App2OnboardingProjection.estimatedRaceVDOT(distanceKm: 5, totalSeconds: 19 * 60 + 45)
        )
        XCTAssertEqual(vdot, 53.07, accuracy: 0.1)
    }

    func test_estimatedRaceVDOT_marathonIsLowerThanFiveKForSameRunner() throws {
        // 同一名跑者：5K 19:45 與全馬 3:10:00 —— 全馬換算出的 VDOT 應該接近但不相等。
        let fiveK = try XCTUnwrap(App2OnboardingProjection.estimatedRaceVDOT(distanceKm: 5, totalSeconds: 1185))
        let marathon = try XCTUnwrap(App2OnboardingProjection.estimatedRaceVDOT(distanceKm: 42.195, totalSeconds: 11400))
        XCTAssertGreaterThan(fiveK, 40)
        XCTAssertGreaterThan(marathon, 40)
    }

    func test_estimatedRaceVDOT_nilForEmptyOrImplausibleInput() {
        XCTAssertNil(App2OnboardingProjection.estimatedRaceVDOT(distanceKm: 5, totalSeconds: 0))
        XCTAssertNil(App2OnboardingProjection.estimatedRaceVDOT(distanceKm: 0, totalSeconds: 1200))
        // 走三小時的 5K：算出來會低於既有的合理下限，不該擺上畫面。
        XCTAssertNil(App2OnboardingProjection.estimatedRaceVDOT(distanceKm: 5, totalSeconds: 3 * 3600))
    }

    // MARK: - 訓練日建議帶

    func test_suggestedTrainingDays_isFourToSix() {
        XCTAssertEqual(App2OnboardingProjection.suggestedTrainingDays, 4...6)
        XCTAssertFalse(App2OnboardingProjection.isTrainingDayCountSuggested(3))
        XCTAssertTrue(App2OnboardingProjection.isTrainingDayCountSuggested(4))
        XCTAssertTrue(App2OnboardingProjection.isTrainingDayCountSuggested(6))
        XCTAssertFalse(App2OnboardingProjection.isTrainingDayCountSuggested(7))
    }

    // MARK: - 跑量預覽

    /// frame-38 參考值（起始 42 km、22 週）：建議帶 38–46、巔峰 68；滑桿上界
    /// 依 2026-08-28 裁決固定 150（宣告上限），不再是巔峰 70。
    func test_mileagePreview_reproducesDesignReferenceNumbers() {
        let preview = App2OnboardingProjection.mileagePreview(anchorKm: 42, declaredKm: 42, totalWeeks: 22)

        XCTAssertEqual(preview.suggestedBand, 38...46)
        XCTAssertEqual(preview.peakKm, 68)
        XCTAssertEqual(preview.sliderRange.lowerBound, 20, accuracy: 0.001)
        XCTAssertEqual(preview.sliderRange.upperBound, 150, accuracy: 0.001)
    }

    func test_mileagePreview_peakGrowsWithPlanLengthButSaturatesAtFiveSteps() {
        let short = App2OnboardingProjection.mileagePreview(anchorKm: 40, declaredKm: 40, totalWeeks: 4)
        let medium = App2OnboardingProjection.mileagePreview(anchorKm: 40, declaredKm: 40, totalWeeks: 12)
        let long = App2OnboardingProjection.mileagePreview(anchorKm: 40, declaredKm: 40, totalWeeks: 20)
        let veryLong = App2OnboardingProjection.mileagePreview(anchorKm: 40, declaredKm: 40, totalWeeks: 40)

        XCTAssertLessThan(short.peakKm, medium.peakKm)
        XCTAssertLessThan(medium.peakKm, long.peakKm)
        XCTAssertEqual(long.peakKm, veryLong.peakKm, "最多五階，40 週不會再往上推")
    }

    func test_mileagePreview_startAlwaysInsideSliderRange() {
        for start in stride(from: 5.0, through: 120.0, by: 5.0) {
            let preview = App2OnboardingProjection.mileagePreview(anchorKm: start, declaredKm: start, totalWeeks: 16)
            XCTAssertTrue(preview.sliderRange.contains(start),
                          "起始 \(start) km 落在滑桿範圍外：\(preview.sliderRange)")
        }
    }

    func test_mileagePreview_peakIsCappedAt150() {
        let preview = App2OnboardingProjection.mileagePreview(anchorKm: 140, declaredKm: 140, totalWeeks: 24)
        XCTAssertEqual(preview.peakKm, 150, "與後端宣告上限同值（2026-08-28 裁決 120→150）")
    }

    func test_mileagePreview_handlesTinyStart() {
        let preview = App2OnboardingProjection.mileagePreview(anchorKm: 0, declaredKm: 0, totalWeeks: 8)
        XCTAssertGreaterThanOrEqual(preview.sliderRange.lowerBound, 5)
        XCTAssertLessThan(preview.sliderRange.lowerBound, preview.sliderRange.upperBound)
    }

    /// 2026-08-28 實機回報的正回饋坑：滑桿範圍必須錨定，不得跟著宣告值擴張。
    func test_mileagePreview_sliderRangeIsAnchoredWhileDeclaredMoves() {
        let atAnchor = App2OnboardingProjection.mileagePreview(anchorKm: 20, declaredKm: 20, totalWeeks: 16)
        let draggedRight = App2OnboardingProjection.mileagePreview(anchorKm: 20, declaredKm: 32, totalWeeks: 16)

        XCTAssertEqual(atAnchor.sliderRange, draggedRight.sliderRange, "範圍不得隨滑桿現值變動")
        XCTAssertEqual(atAnchor.suggestedBand, draggedRight.suggestedBand, "建議帶錨定起始量")
        XCTAssertGreaterThan(draggedRight.peakKm, atAnchor.peakKm, "巔峰預估跟著宣告值動")
    }
}


// MARK: - 訓練方法推薦項（2026-08-27 走查裁決（k））
/// 重設目標不經過「選目標型態」那一頁，`flow.selectedTargetTypeV2` 是 nil。
/// 推薦項如果只看它，就會退成「清單第一個」＝ Hansons，畫面上把漢森標成推薦
/// （2026-08-27 使用者實機截圖）。
@MainActor
final class App2OnboardingMethodologyRecommendationTests: XCTestCase {

    private func targetType(
        id: String,
        defaultMethodology: String
    ) -> TargetTypeV2 {
        TargetTypeV2(
            id: id,
            name: id,
            description: "",
            defaultMethodology: defaultMethodology,
            availableMethodologies: ["hanson", "paceriz", "polarized"]
        )
    }

    private func methodology(_ id: String) -> MethodologyV2 {
        MethodologyV2(
            id: id, name: id, description: "",
            targetTypes: ["race_run"], phases: [], crossTrainingEnabled: false
        )
    }

    override func tearDown() {
        OnboardingCoordinator.shared.selectedTargetTypeId = nil
        super.tearDown()
    }

    /// re-onboarding：型態頁沒走過，但 coordinator 記得是 race_run
    /// → 推薦必須是後端給的 `default_methodology`（dev 實測 `paceriz`），不是清單第一個。
    func test_recommendation_usesCoordinatorTargetTypeWhenFlowSelectionIsNil() {
        let viewModel = App2OnboardingViewModel(isReonboarding: true)
        viewModel.flow.availableTargetTypes = [
            targetType(id: "beginner", defaultMethodology: "hanson"),
            targetType(id: "race_run", defaultMethodology: "paceriz")
        ]
        // 清單第一個刻意是 hanson —— 退化路徑會選到它。
        viewModel.flow.availableMethodologies = [methodology("hanson"), methodology("paceriz")]
        viewModel.flow.selectedTargetTypeV2 = nil
        OnboardingCoordinator.shared.selectedTargetTypeId = "race_run"

        XCTAssertEqual(viewModel.recommendedMethodologyId, "paceriz")
    }

    /// 兩處都不知道型態才退清單第一個。
    func test_recommendation_fallsBackToFirstOnlyWhenTargetTypeUnknown() {
        let viewModel = App2OnboardingViewModel(isReonboarding: true)
        viewModel.flow.availableTargetTypes = []
        viewModel.flow.availableMethodologies = [methodology("hanson"), methodology("paceriz")]
        viewModel.flow.selectedTargetTypeV2 = nil
        OnboardingCoordinator.shared.selectedTargetTypeId = nil

        XCTAssertEqual(viewModel.recommendedMethodologyId, "hanson")
    }
}
