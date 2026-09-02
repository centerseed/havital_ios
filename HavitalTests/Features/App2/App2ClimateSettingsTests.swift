import XCTest
@testable import paceriz_dev

/// T-0392：2.0 熱適應頁的儲存契約。
///
/// 頁面本身只是版面，會出錯的是「手動門檻要不要送出去」——`useManualThreshold`
/// 關掉時必須送 nil（後端才會回到自動門檻），開著時送滑桿當下的值。
/// 這一段在 1.4 沒有測試護著，改版面時最容易被改掉。
@MainActor
final class App2ClimateSettingsTests: XCTestCase {

    func test_save_manualThresholdOff_sendsNil() async {
        let repo = FakeClimateRepository(profile: makeProfile(manualStartThresholdC: 26))
        let viewModel = ClimateSettingsViewModel(repository: repo)
        await viewModel.load()
        XCTAssertTrue(viewModel.useManualThreshold, "profile 帶手動門檻時開關要是開的")

        viewModel.useManualThreshold = false
        await viewModel.save()

        XCTAssertNil(repo.lastPayload?.manualStartThresholdC, "關掉手動門檻＝送 nil，回到自動")
    }

    func test_save_manualThresholdOn_sendsSliderValue() async {
        let repo = FakeClimateRepository(profile: makeProfile(manualStartThresholdC: nil))
        let viewModel = ClimateSettingsViewModel(repository: repo)
        await viewModel.load()
        XCTAssertFalse(viewModel.useManualThreshold)

        viewModel.useManualThreshold = true
        viewModel.manualThreshold = 28.5
        viewModel.adaptationLevel = "acclimated"
        await viewModel.save()

        XCTAssertEqual(repo.lastPayload?.manualStartThresholdC, 28.5)
        XCTAssertEqual(repo.lastPayload?.adaptationLevel, "acclimated")
    }

    func test_save_failure_surfacesErrorAndKeepsEdits() async {
        let repo = FakeClimateRepository(profile: makeProfile(manualStartThresholdC: nil))
        repo.updateError = URLError(.timedOut)
        let viewModel = ClimateSettingsViewModel(repository: repo)
        await viewModel.load()

        viewModel.enabled = false
        await viewModel.save()

        XCTAssertNotNil(viewModel.errorMessage, "寫入失敗要有話講")
        XCTAssertFalse(viewModel.enabled, "失敗不得把使用者的編輯回捲")
    }

    // MARK: - 頁面判斷（App2ClimateSettingsProjection）

    func test_sections_disabledKeepsOnlyTheSwitch() {
        XCTAssertEqual(App2ClimateSettingsProjection.sections(enabled: false), [.enable])
        XCTAssertEqual(
            App2ClimateSettingsProjection.sections(enabled: true),
            [.enable, .currentStatus, .controls, .explanation],
            "開著時四段齊；底下每一段講的都是「怎麼調整」"
        )
    }

    func test_statusMode_fallsBackWhenNoObservation() {
        XCTAssertEqual(
            App2ClimateSettingsProjection.statusMode(currentStatus: nil),
            .fallback,
            "沒有當日觀測就退回「你的設定」摘要，不是畫一片空的實測"
        )
        XCTAssertEqual(
            App2ClimateSettingsProjection.statusMode(currentStatus: makeStatus(isAdjusted: true, pct: 2.5)),
            .live
        )
    }

    func test_paceText_threeCases() {
        XCTAssertEqual(
            App2ClimateSettingsProjection.paceText(
                makeStatus(isAdjusted: false, pct: nil), adjustedLabel: "已調整"
            ),
            "0%"
        )
        XCTAssertEqual(
            App2ClimateSettingsProjection.paceText(
                makeStatus(isAdjusted: true, pct: 2.5), adjustedLabel: "已調整"
            ),
            "2.5%"
        )
        XCTAssertEqual(
            App2ClimateSettingsProjection.paceText(
                makeStatus(isAdjusted: true, pct: nil), adjustedLabel: "已調整"
            ),
            "已調整",
            "有調整但後端沒給百分比時不得印 0% —— 那會讓人以為沒調整"
        )
    }

    func test_thresholdSliderBounds() {
        XCTAssertEqual(App2ClimateSettingsProjection.thresholdRange, 24...30)
        XCTAssertEqual(App2ClimateSettingsProjection.thresholdStep, 0.5)
    }

    private func makeStatus(isAdjusted: Bool, pct: Double?) -> ClimateCurrentStatus {
        ClimateCurrentStatus(
            isAdjusted: isAdjusted,
            feelsLikeTempC: 29,
            paceAdjustmentPct: pct,
            longRunReductionPct: nil,
            statusText: nil
        )
    }

    // MARK: - Fakes

    private final class FakeClimateRepository: ClimateSettingsRepository {
        private let profile: ClimateProfileResponse
        var updateError: Error?
        private(set) var lastPayload: ClimateSettingsPayload?

        init(profile: ClimateProfileResponse) {
            self.profile = profile
        }

        func fetchSettingsContext() async throws -> ClimateSettingsContext {
            ClimateSettingsContext(profile: profile, metrics: makeMetrics())
        }

        func updateSettings(_ payload: ClimateSettingsPayload) async throws {
            lastPayload = payload
            if let updateError { throw updateError }
        }

        private func makeMetrics() -> ClimateAdaptationMetricsResponse {
            ClimateAdaptationMetricsResponse(
                indicators: ClimateIndicators(
                    hotTrainingHours14d: 3,
                    hotWorkoutCount14d: 2,
                    hotPaceAchievementRatePct: 80,
                    hotHrEfficiencyTrend: "flat",
                    hotHrEfficiencyDeltaPct: nil
                ),
                recommendedAdaptationLevel: "normal",
                currentAdaptationLevel: "normal",
                dataInsufficient: false,
                dataInsufficientReason: nil
            )
        }
    }

    private func makeProfile(manualStartThresholdC: Double?) -> ClimateProfileResponse {
        ClimateProfileResponse(
            uid: "u1",
            locale: "zh-TW",
            adapter: ClimateAdapterDisclosure(
                id: "a1",
                displayName: "測試來源",
                dataSource: "test",
                isFallback: false,
                disclosure: "測試"
            ),
            settings: ClimateSettingsPayload(
                enabled: true,
                adaptationLevel: "normal",
                manualStartThresholdC: manualStartThresholdC,
                regionKey: "tw",
                presets: nil,
                createdAt: nil,
                updatedAt: nil
            ),
            heatProfile: ClimateHeatProfile(
                baseProfileName: "base",
                uiSummary: ClimateUISummary(
                    featureName: "熱適應",
                    currentSettingLabel: "一般",
                    adjustmentStartTempC: 27,
                    dangerTempC: 32,
                    howItWorks: ["一", "二"],
                    sourceDisclosure: "測試"
                ),
                interventionRules: [
                    ClimateInterventionRule(
                        level: "mild",
                        temperatureRangeLabel: "27–29°C",
                        summaryText: "配速放寬",
                        paceText: "+2%",
                        longRunText: nil,
                        trainingWindowText: nil
                    )
                ],
                currentStatus: nil
            )
        )
    }
}
