import Foundation

// MARK: - App2OnboardingProjection
/// 2.0 onboarding 幾個「即時換算」的純函式。
///
/// **這裡只放既有實作沒有的東西。** 動手前查過的既有輪子，一律直接用、不重寫：
///
/// | 要的東西 | 既有實作 | 這裡做什麼 |
/// |---|---|---|
/// | 距離＋完成時間 → 每公里配速 | `OnboardingFeatureViewModel.currentPace`（PB）／`.targetPace`（目標賽事） | 不重寫，View 直接讀 |
/// | 最大／靜息心率 → 訓練區間 | `HeartRateZone.calculateZones(maxHR:restingHR:)`（Karvonen／HRR，六區） | 只把六區**併成設計要的五條色帶** |
/// | 長跑日預選 | `OnboardingFeatureViewModel.normalizeLongRunDaySelection()` | 不重寫，View 直接呼叫 |
/// | VDOT | `POST /v2/vdot/calculate`（`VDOTService`） | 不在本機算 |
/// | 週跑量容量的權威解析 | 後端 `resolve_weekly_volume_capacity`（`MAP-mileage-baseline.md` §2） | 只做**生成前的預覽**，見下 |
enum App2OnboardingProjection {

    // MARK: - 心率區間色帶（呈現層合併，不是第二套分區）

    /// 設計 frame-33 的五條色帶。`upperBpm` 是該區間的心率上限（bpm）。
    struct HeartRateBand: Equatable, Identifiable {
        let index: Int          // 1...5
        let nameKey: String
        let upperBpm: Int
        var id: Int { index }
    }

    /// 由既有的 `HeartRateZone` 六區併成設計的五條。
    ///
    /// 併法：Z1 恢復＝zone1、Z2 耐力＝zone2、Z3 節奏＝zone3、Z4 閾值＝zone4、
    /// Z5 無氧＝zone5(anaerobic) ∪ zone6(interval)，上緣就是最大心率。
    /// **沒有新增任何百分比常數** —— 每個上限都取自 `calculateZones` 的 `range.upperBound`。
    /// 設計稿印的示範數字（frame-33 的 132/146/160/174 與 frame-28 的 128/148/160/172）
    /// 彼此就不一致，是排版用的假值；真值以既有分區為準。
    static func heartRateBands(maxHR: Int, restingHR: Int) -> [HeartRateBand] {
        guard maxHR > restingHR else { return [] }
        let zones = HeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)

        func upper(_ zone: Int) -> Int {
            guard let z = zones.first(where: { $0.zone == zone }) else { return maxHR }
            return Int(z.range.upperBound.rounded())
        }

        return [
            HeartRateBand(index: 1, nameKey: L10n.App2.Onboarding.hrBandRecovery, upperBpm: upper(1)),
            HeartRateBand(index: 2, nameKey: L10n.App2.Onboarding.hrBandEndurance, upperBpm: upper(2)),
            HeartRateBand(index: 3, nameKey: L10n.App2.Onboarding.hrBandTempo, upperBpm: upper(3)),
            HeartRateBand(index: 4, nameKey: L10n.App2.Onboarding.hrBandThreshold, upperBpm: upper(4)),
            HeartRateBand(index: 5, nameKey: L10n.App2.Onboarding.hrBandAnaerobic, upperBpm: maxHR)
        ]
    }

    /// 「220 − 年齡」的最大心率估算。原本寫在 `HeartRateZoneInfoView.loadCurrentValues()`
    /// 裡，2.0 的心率頁要同一條規則 —— 收斂到這支，1.x 那支改成呼叫它。
    static func estimatedMaxHR(age: Int) -> Int {
        max(100, 220 - age)
    }

    // MARK: - 估算 VDOT（後端公式的前端鏡像，附退場條件）

    /// 由「距離 ＋ 完賽時間」估 VDOT，用於設計 frame-35 那張即時換算卡。
    ///
    /// **這是後端公式的鏡像，不是第二套模型。** 兩件事先講清楚：
    ///
    /// 1. **SSOT 在後端**：`cloud/api_service/core/calculations/vdot.py::get_vdot`
    ///    （Daniels）＋ `get_race_vdot`（比賽努力 ×1.05）。這裡逐項照抄同一組係數，
    ///    改常數要兩邊一起改。使用者在這一頁填的是**盡力跑的成績**，所以走 race 路徑
    ///    （與 `BenchmarkService.compute_benchmark_vdot` 同一條）。
    /// 2. **為什麼不打 API**：`POST /v2/vdot/calculate` 在
    ///    `cloud/api_service/core/contracts/ios_api_contract.py:94` 是 **`lifecycle="dormant"`**
    ///    ——契約有宣告、`api/` 下沒有實作，iOS 的 `VDOTService.calculateVDOT` 目前零呼叫點。
    ///
    /// **退場條件（新路徑何時死）**：那條端點一旦做實，這支函式連同它的測試一起刪，
    /// 改呼叫 `VDOTService.calculateVDOT`。在那之前它是這一頁唯一的來源。
    ///
    /// 設計稿印的 57.4（5K 19:45）與這條公式對不上（實際約 53.1），是排版用的假值。
    static func estimatedRaceVDOT(distanceKm: Double, totalSeconds: Int) -> Double? {
        guard distanceKm > 0, totalSeconds > 0 else { return nil }

        let minutes = Double(totalSeconds) / 60.0
        let metres = distanceKm * 1000.0
        let velocity = metres / minutes                                   // 公尺/分鐘
        let vo2 = -4.6 + 0.182258 * velocity + 0.000104 * velocity * velocity
        let pct = 0.8
            + 0.1894393 * exp(-0.012778 * minutes)
            + 0.2989558 * exp(-0.1932605 * minutes)
        guard pct > 0 else { return nil }

        let vdot = (vo2 / pct) * 1.05
        // 合理區間走既有閘門，不另立一組門檻。
        guard vdot.isFinite, PaceCalculator.isValidVDOT(vdot) else { return nil }
        return vdot
    }

    // MARK: - 訓練日建議帶

    /// 設計 frame-37 的「建議每週 4–6 天」。
    ///
    /// 既有 `TrainingDaysSetupView` 只有 `recommendedMinTrainingDays = 2`（能不能過的下限），
    /// 那是**閘門**；這條是**建議帶**，兩者語意不同、不互相取代。畫面上只作為提示，
    /// 不擋 CTA（少於 4 天或多於 6 天照樣能繼續）。
    static let suggestedTrainingDays: ClosedRange<Int> = 4...6

    static func isTrainingDayCountSuggested(_ count: Int) -> Bool {
        suggestedTrainingDays.contains(count)
    }

    // MARK: - 跑量預覽（生成前，畫面上一律標「預估」）

    /// 設計 frame-38 的四個數字：滑桿範圍、建議帶、巔峰週預估。
    struct MileagePreview: Equatable {
        let sliderRange: ClosedRange<Double>
        let suggestedBand: ClosedRange<Int>
        let peakKm: Int
    }

    /// 依「起始週量 × 計畫總週數」推預覽值。
    ///
    /// **這不是第二套容量規則。** 真正的週量容量由後端在生成當下解析
    /// （`MAP-mileage-baseline.md` §2 R1–R8 → `resolve_weekly_volume_capacity`），
    /// 前端拿不到那條路徑的輸入（八週中位數、高水位、宣告週齡）。這一頁需要的是
    /// 「使用者調滑桿時，畫面上要跟著動的參考數字」，所以只借 R2 的成長率刻度
    /// （錨 × 1.10）做逐週外推：
    ///
    /// - 建議帶 ＝ 起始量 ±10%（同一個刻度，四捨五入到整數 km）。
    /// - 巔峰週 ＝ `宣告值 × 1.10^k`，`k = clamp(總週數 / 4, 1, 5)` —— 每個四週訓練塊
    ///   往上推一階，最多五階，並以 120 km 封頂（與後端 `declared_weekly_km` 的正規化上限同值）。
    /// - 滑桿 ＝ 下界取起始量一半、上界取「起始量推出的巔峰」，各自對齊到 5 km 刻度。
    ///
    /// **滑桿範圍與建議帶吃 `anchorKm`（進頁當下的起始量），只有巔峰預估吃
    /// `declaredKm`（滑桿現值）。** 舊版三者全吃滑桿現值：往右拉→值變大→上界
    /// 跟著擴→同一個拇指位置映射到更大的值→再擴——正回饋讓右半段增速失控
    /// （2026-08-28 用戶實機回報「拉到右邊明顯跑量增的超快」）。
    static func mileagePreview(anchorKm: Double, declaredKm: Double, totalWeeks: Int) -> MileagePreview {
        let anchor = max(1, anchorKm)
        let declared = max(1, declaredKm)
        let steps = min(5, max(1, totalWeeks / 4))
        let peak = min(120.0, declared * pow(1.10, Double(steps)))
        let anchorPeak = min(120.0, anchor * pow(1.10, Double(steps)))

        let lowerBand = Int((anchor * 0.9).rounded())
        let upperBand = Int((anchor * 1.1).rounded())

        let sliderLower = max(5.0, (anchor * 0.5 / 5).rounded(.down) * 5)
        let sliderUpper = max(sliderLower + 5, (anchorPeak / 5).rounded(.up) * 5)

        return MileagePreview(
            sliderRange: sliderLower...sliderUpper,
            suggestedBand: lowerBand...max(lowerBand, upperBand),
            peakKm: Int(peak.rounded())
        )
    }
}
