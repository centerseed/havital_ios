import Foundation

// MARK: - TrainingEffortScale
/// 課型 → 體感強度（RPE）與心率／配速區間的對照表。
///
/// **這張表本來就在 repo 裡**，是 `PlannedSessionDetailView` 的兩支 private
/// `inferredRPE(for:)`／`inferredHRZone(for:)`（1.4 訓練詳情的「目標區間」膠囊）。
/// 2.0 的體感強度卡要的是同一組值，所以把它抬成共用型別讓兩邊都指過來 ——
/// 不是新開第二份對照。1.4 那兩支已經改成薄轉呼叫，值一個都沒動。
///
/// **為什麼要用課型推**：週課表 payload 沒有 RPE、也沒有訓練區間欄位
/// （只有 `heart_rate_range` 的心率上下限與 `climate_meta`）。`DayType` 是
/// 結構化的（由 `run_type`／`category` 解出來），所以這是型別對照，
/// 不是對顯示字做詞表比對。
enum TrainingEffortScale {

    /// 一堂課的體感級距。
    struct Value: Equatable {
        /// 顯示用的體感值，可能是區間（`3`／`4-5`）。
        let rpeText: String
        /// 畫進度條用的單一分數（滿分 10）。區間取上緣。
        let barScore: Int
        /// 心率／強度區間標記（`Z2`／`Z4-Z5`）。三語同形，不進 `.strings`。
        let zone: String
    }

    /// 判不出課型時的中性級距（1.4 兩支 `inferred*` 的 `default` 分支，值照抄）。
    static let fallback = Value(rpeText: "5", barScore: 5, zone: "Z2-Z3")

    /// 課型的體感級距。**跑步課才有**：休息日、肌力、交叉訓練沒有配速區間語意，
    /// 設計上也沒有那張卡 → nil。
    static func value(for type: DayType?) -> Value? {
        guard let type else { return nil }
        switch type {
        case .easy, .easyRun, .recovery_run:
            return Value(rpeText: "3", barScore: 3, zone: "Z2")
        case .lsd, .longRun:
            return Value(rpeText: "4-5", barScore: 5, zone: "Z2-Z3")
        case .fastFinish:
            return Value(rpeText: "4-7", barScore: 7, zone: "Z3-Z4")
        case .tempo, .cruiseIntervals, .norwegianSingles:
            return Value(rpeText: "6", barScore: 6, zone: "Z3-Z4")
        case .threshold, .progression:
            return Value(rpeText: "7", barScore: 7, zone: "Z4")
        case .interval, .shortInterval, .longInterval,
             .norwegian4x4, .yasso800, .strides, .hillRepeats:
            return Value(rpeText: "8", barScore: 8, zone: "Z4-Z5")
        case .race, .racePace:
            return Value(rpeText: "9", barScore: 9, zone: "Z5")
        case .rest, .strength, .yoga, .crossTraining,
             .cycling, .swimming, .elliptical, .rowing:
            return nil
        case .benchmark, .fartlek, .steadyIntervals, .combination, .hiking:
            return fallback
        }
    }

    /// 1.4 那兩支的原語意：**跑步課一律給得出值**（判不出來就用中性值）。
    static func rpeText(for type: DayType) -> String {
        (value(for: type) ?? fallback).rpeText
    }

    static func zone(for type: DayType) -> String {
        (value(for: type) ?? fallback).zone
    }

    /// 今日課表卡標題列右側的強度 chip（設計 `低強度`／`中強度`／`高強度`／
    /// `耐力`／`恢復`）。
    ///
    /// 級距由 `barScore` 切；長距離家族另外歸「耐力」、恢復跑與休息日歸「恢復」
    /// —— 這兩個是設計稿明列的例外，不是分數推得出來的。
    static func chipLabel(for type: DayType?) -> String? {
        guard let type else { return nil }
        switch type {
        case .rest, .recovery_run:
            return L10n.App2.Session.effortChipRecovery.localized
        case .lsd, .longRun, .hiking:
            return L10n.App2.Session.effortChipEndurance.localized
        default:
            guard let score = value(for: type)?.barScore else { return nil }
            if score <= 3 { return L10n.App2.Session.effortChipLow.localized }
            if score <= 6 { return L10n.App2.Session.effortChipMedium.localized }
            return L10n.App2.Session.effortChipHigh.localized
        }
    }

    /// 體感卡那一句話 —— **既有的課型文案**（`TrainingTypeInfo.howToRun`，
    /// `training_type_info.*` 三語已齊），不逐日生成：逐日敘述在用戶改過課表後
    /// 後端不重生，會出現與當日課型矛盾的句子（2026-08-26 使用者截圖）。
    static func sentence(for type: DayType?) -> String? {
        guard let type else { return nil }
        return TrainingTypeInfo.info(for: type)?.howToRun
    }
}
