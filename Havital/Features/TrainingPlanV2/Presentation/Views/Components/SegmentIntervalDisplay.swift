import Foundation

/// 從段落序列的 `RunSegment` 導出顯示值。純函式、無 SwiftUI 依賴，因此可單測。
///
/// View（`PlannedSessionDetailView`）只負責把這裡的結果排版成 `DetailSegmentData`。
/// 判斷一律走 `segmentKind`（computed），未知的原始 kind 字串會降級為 `.steady`，
/// 不會被誤渲染成間歇組。
enum SegmentIntervalDisplay {

    struct Rest: Equatable {
        enum Unit { case seconds, minutes }
        let value: Int
        let unit: Unit
        /// 是否為動態恢復（慢跑／走跑）。只有 `"static"` 是靜止。
        let isMoving: Bool
    }

    /// 反覆趟數。非 interval 段回 nil。
    static func reps(_ seg: RunSegment) -> Int? {
        guard seg.segmentKind == .interval else { return nil }
        return seg.repeats
    }

    /// 恢復規格。非 interval 段、沒有恢復段、或恢復段不是時間制時回 nil。
    static func rest(_ seg: RunSegment) -> Rest? {
        guard seg.segmentKind == .interval, let recovery = seg.recovery else { return nil }
        // 只有 static 是靜止；未知型態一律視為動態，避免把慢跑恢復誤寫成「原地休息」。
        let isMoving = recovery.recoveryType != "static"
        if let sec = recovery.durationSeconds {
            return Rest(value: sec, unit: .seconds, isMoving: isMoving)
        }
        if let min = recovery.durationMinutes {
            return Rest(value: min, unit: .minutes, isMoving: isMoving)
        }
        return nil
    }

    /// 工作段標籤，如 "400m" / "1.2km" / "3分"。非 interval 段回 nil。
    static func workLabel(_ seg: RunSegment) -> String? {
        guard seg.segmentKind == .interval, let work = seg.work else { return nil }
        if let m = work.distanceM { return "\(m)m" }
        if let km = work.distanceKm { return String(format: "%.1fkm", km) }
        if let mins = work.durationMinutes {
            return "\(mins)\(NSLocalizedString("training.minute_abbr", comment: ""))"
        }
        return nil
    }
}
