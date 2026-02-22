import Foundation

/// 配速計算輔助類別
/// 封裝 VDOT 並提供配速計算方法，作為 TrainingEditSheetV2 等子 Editor 的輕量配速來源
/// 取代對 TrainingPlanViewModel 的依賴，讓 V2 編輯頁面可獨立使用
final class PaceCalculationHelper: ObservableObject {
    let vdot: Double?

    init(vdot: Double?) {
        self.vdot = vdot
    }

    var currentVDOT: Double? { vdot }

    var calculatedPaces: [PaceCalculator.PaceZone: String] {
        guard let vdot else { return [:] }
        return PaceCalculator.calculateTrainingPaces(vdot: vdot)
    }

    func getSuggestedPace(for trainingType: String) -> String? {
        guard let vdot else { return nil }
        return PaceCalculator.getSuggestedPace(for: trainingType, vdot: vdot)
    }

    func getPaceRange(for trainingType: String) -> (min: String, max: String)? {
        guard let vdot else { return nil }
        return PaceCalculator.getPaceRange(for: trainingType, vdot: vdot)
    }
}
