import Foundation

/// 把後端結構化 diffDays 在地化成卡片可顯示的文字行。
/// 規則（spec §3.3）：類型有變 → 「舊desc → 新desc」；只距離變 → 「類型 舊→新 公里」。
enum PlanChangeDiffFormatter {

    /// 多日 → 多行字串（每日一行）。
    static func text(for diffDays: [PlanChangeDiffDay]) -> String {
        diffDays.map(line(for:)).joined(separator: "\n")
    }

    /// 單日 → 一行。
    static func line(for day: PlanChangeDiffDay) -> String {
        let weekday = weekdayLabel(day.dayIndex)
        let unit = NSLocalizedString("rizo.plan_change.distance_unit", comment: "公里")

        let typeChanged = (day.from?.category != day.to?.category)
            || (day.from?.runType != day.to?.runType)

        if !typeChanged,
           let to = day.to, to.category == "run",
           let fromKm = day.from?.distanceKm, let toKm = to.distanceKm {
            // 只距離變
            return "\(weekday) \(typeLabel(to)) \(distance(fromKm)) → \(distance(toKm)) \(unit)"
        }
        // 類型/跨類有變
        return "\(weekday) \(faceDesc(day.from, unit: unit)) → \(faceDesc(day.to, unit: unit))"
    }

    // MARK: - helpers

    private static func weekdayLabel(_ index: Int) -> String {
        guard (1...7).contains(index) else { return "" }
        return NSLocalizedString("rizo.plan_change.weekday.\(index)", comment: "週幾")
    }

    private static func faceDesc(_ face: PlanChangeDayFace?, unit: String) -> String {
        guard let face = face else { return "—" }
        let label = typeLabel(face)
        if face.category == "run", let km = face.distanceKm {
            return "\(label) \(distance(km)) \(unit)"
        }
        return label
    }

    private static func typeLabel(_ face: PlanChangeDayFace) -> String {
        let key: String
        switch face.category {
        case "rest": key = "training.type.rest"
        case "cross": key = "training.type.cross_training"
        case "strength": key = "training.type.strength"
        default:
            if let rt = face.runType, !rt.isEmpty {
                key = "training.type.\(rt)"
            } else {
                key = "training.type.easy"
            }
        }
        let localized = NSLocalizedString(key, comment: "")
        if localized == key, let rt = face.runType, !rt.isEmpty {
            return rt   // 查無 key → 顯示後端原值，不空白
        }
        return localized
    }

    /// 整數不顯小數；非整數保留（不四捨五入）。
    private static func distance(_ km: Double) -> String {
        if km.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(km))
        }
        return String(format: "%g", km)
    }
}
