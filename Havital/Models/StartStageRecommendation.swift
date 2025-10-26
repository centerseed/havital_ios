//
//  StartStageRecommendation.swift
//  Havital
//
//  訓練起始階段推薦演算法
//  根據剩餘週數和目標距離，推薦最適合的訓練起始階段
//

import Foundation

/// 訓練起始階段
enum TrainingStagePhase: String, Codable, CaseIterable {
    case conversion = "conversion"
    case base = "base"
    case build = "build"
    case peak = "peak"
    case taper = "taper"

    var displayName: String {
        switch self {
        case .conversion: return NSLocalizedString("stage.conversion", comment: "轉換期")
        case .base: return NSLocalizedString("stage.base", comment: "基礎期")
        case .build: return NSLocalizedString("stage.build", comment: "增強期")
        case .peak: return NSLocalizedString("stage.peak", comment: "巔峰期")
        case .taper: return NSLocalizedString("stage.taper", comment: "減量期")
        }
    }

    /// 後端 API 使用的識別字串
    var apiIdentifier: String {
        return self.rawValue
    }
}

/// 風險等級
enum TrainingRiskLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .low: return NSLocalizedString("risk.low", comment: "低")
        case .medium: return NSLocalizedString("risk.medium", comment: "中")
        case .high: return NSLocalizedString("risk.high", comment: "高")
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

/// 訓練週數分配
struct TrainingDistribution: Codable, Equatable {
    let conversionWeeks: Int
    let baseWeeks: Int
    let buildWeeks: Int
    let peakWeeks: Int
    let taperWeeks: Int

    var totalWeeks: Int {
        return conversionWeeks + baseWeeks + buildWeeks + peakWeeks + taperWeeks
    }
}

/// 替代階段選項
struct StageAlternative: Codable, Identifiable, Equatable {
    let id: String
    let stage: TrainingStagePhase
    let stageName: String
    let suitableFor: String
    let riskLevel: TrainingRiskLevel
    let description: String

    init(stage: TrainingStagePhase,
         suitableFor: String,
         riskLevel: TrainingRiskLevel,
         description: String) {
        self.id = stage.rawValue
        self.stage = stage
        self.stageName = stage.displayName
        self.suitableFor = suitableFor
        self.riskLevel = riskLevel
        self.description = description
    }
}

/// 起始階段推薦結果
struct StartStageRecommendation: Codable, Equatable {
    let recommendedStage: TrainingStagePhase
    let stageName: String
    let reason: String
    let riskLevel: TrainingRiskLevel
    let weeksRemaining: Int
    let alternatives: [StageAlternative]
    let trainingDistribution: TrainingDistribution
    let isFullMarathon: Bool

    /// 是否時間過短（<2週），無法達到訓練效果
    var isTooShort: Bool {
        return weeksRemaining < 2
    }
}

/// 訓練計劃計算器
class TrainingPlanCalculator {

    /// 判斷某個訓練階段是否可用（依據剩餘週數）
    /// - Parameters:
    ///   - stage: 訓練階段
    ///   - weeksRemaining: 剩餘週數
    /// - Returns: 是否可用
    static func isStageAvailable(_ stage: TrainingStagePhase, weeksRemaining: Int) -> Bool {
        switch stage {
        case .peak:
            // 巔峰期：總是可用（即使只有1-2週）
            return true
        case .build:
            // 增強期：至少需要3週
            return weeksRemaining >= 3
        case .base:
            // 基礎期：至少需要6週才能完整執行三階段
            return weeksRemaining >= 6
        case .conversion, .taper:
            // 不支援從這些階段開始
            return false
        }
    }


    /// 取得標準訓練週數（依據賽事距離）
    /// - Parameter distanceKm: 目標賽事距離（公里）
    /// - Returns: 建議的標準訓練週數
    static func getStandardTrainingWeeks(for distanceKm: Double) -> Int {
        if distanceKm >= 42.0 {
            // 全馬：16-20 週
            return 18
        } else if distanceKm >= 21.0 {
            // 半馬：12-16 週
            return 14
        } else if distanceKm >= 10.0 {
            // 10K：10-12 週
            return 11
        } else {
            // 5K：8-10 週
            return 9
        }
    }

    /// 計算訓練階段週數分配
    /// - Parameters:
    ///   - trainingWeeks: 總訓練週數
    ///   - targetDistanceKm: 目標距離（公里）
    ///   - startFromStage: 起始階段
    /// - Returns: 各階段週數分配（總週數必定等於 trainingWeeks）
    static func calculateTrainingPeriods(
        trainingWeeks: Int,
        targetDistanceKm: Double,
        startFromStage: TrainingStagePhase = .base
    ) -> TrainingDistribution {
        let isFullMarathon = targetDistanceKm > 21.1

        // 🔧 修正：當剩餘週數極短時，縮短減量期以確保至少有訓練時間
        var taperWeeks: Int
        if trainingWeeks <= 2 {
            // 極短週期：減量期 = 0，所有時間用於訓練
            taperWeeks = 0
        } else if trainingWeeks == 3 {
            // 3週：減量期 = 1週（即使全馬）
            taperWeeks = 1
        } else {
            // 正常情況：全馬2週，其他1週
            taperWeeks = isFullMarathon ? 2 : 1
        }

        let remainingWeeks = max(0, trainingWeeks - taperWeeks)

        var conversionWeeks = 0
        var baseWeeks = 0
        var buildWeeks = 0
        var peakWeeks = 0

        switch startFromStage {
        case .build:
            // 從增強期開始：平均分配 build 和 peak
            if remainingWeeks >= 2 {
                buildWeeks = Int(ceil(Double(remainingWeeks) / 2.0))
                peakWeeks = remainingWeeks - buildWeeks
            } else if remainingWeeks == 1 {
                // 只有1週：全部給 build
                buildWeeks = 1
                peakWeeks = 0
            } else {
                // 0週：無法訓練
                buildWeeks = 0
                peakWeeks = 0
            }

        case .peak:
            // 從巔峰期開始：全部給 peak
            peakWeeks = remainingWeeks

        case .base:
            // 從基礎期開始：動態分配
            if remainingWeeks >= 10 {
                // 充足時間：標準比例分配
                baseWeeks = Int(Double(remainingWeeks) * 0.4)
                buildWeeks = Int(Double(remainingWeeks) * 0.3)
                peakWeeks = remainingWeeks - baseWeeks - buildWeeks
            } else if remainingWeeks >= 6 {
                // 6-9週：壓縮但完整三階段
                baseWeeks = 2
                buildWeeks = Int(ceil(Double(remainingWeeks - 2) / 2.0))
                peakWeeks = remainingWeeks - baseWeeks - buildWeeks
            } else if remainingWeeks >= 3 {
                // 3-5週：極度壓縮
                baseWeeks = 1
                buildWeeks = 1
                peakWeeks = remainingWeeks - 2
            } else if remainingWeeks >= 1 {
                // 1-2週：只有基礎期（不合理但至少總週數正確）
                baseWeeks = remainingWeeks
                buildWeeks = 0
                peakWeeks = 0
            } else {
                // 0週：無法訓練
                baseWeeks = 0
                buildWeeks = 0
                peakWeeks = 0
            }

        case .conversion, .taper:
            // 不支援從這些階段開始
            peakWeeks = remainingWeeks
        }

        return TrainingDistribution(
            conversionWeeks: conversionWeeks,
            baseWeeks: baseWeeks,
            buildWeeks: buildWeeks,
            peakWeeks: peakWeeks,
            taperWeeks: taperWeeks
        )
    }

    /// 推薦訓練起始階段（核心邏輯）
    /// - Parameters:
    ///   - weeksRemaining: 距離比賽剩餘週數
    ///   - targetDistanceKm: 目標距離（公里）
    /// - Returns: 推薦結果
    static func recommendStartStage(
        weeksRemaining: Int,
        targetDistanceKm: Double = 21.1
    ) -> StartStageRecommendation {
        // 推薦邏輯
        let recommendedStage: TrainingStagePhase
        let riskLevel: TrainingRiskLevel
        let reason: String

        if weeksRemaining < 2 {
            // 時間過短，無法達到訓練效果
            recommendedStage = .peak
            riskLevel = .high
            reason = NSLocalizedString("start_stage.too_short_reason",
                                      comment: "距離賽事不足 2 週，時間過於緊迫")
        } else if weeksRemaining <= 2 {
            // 2週：只能從巔峰期開始（增強期需要≥3週）
            recommendedStage = .peak
            riskLevel = .medium
            reason = String(format: NSLocalizedString("start_stage.peak_reason",
                                                     comment: "適合有訓練基礎的跑者"), weeksRemaining)
        } else if weeksRemaining < 12 {
            // 3-11週：建議從增強期開始（時間較短，建議跳過基礎期）
            recommendedStage = .build
            riskLevel = .low
            reason = String(format: NSLocalizedString("start_stage.build_medium_reason",
                                                     comment: "適合有規律訓練習慣的跑者"), weeksRemaining)
        } else {
            // 12週以上：時間充足，建議從基礎期開始完整訓練
            recommendedStage = .base
            riskLevel = .low
            reason = String(format: NSLocalizedString("start_stage.base_reason",
                                                     comment: "時間充足，建議完整訓練"), weeksRemaining)
        }

        // 計算週數分配
        let distribution = calculateTrainingPeriods(
            trainingWeeks: weeksRemaining,
            targetDistanceKm: targetDistanceKm,
            startFromStage: recommendedStage
        )

        // 生成替代選項（只包含可用選項）
        var alternatives: [StageAlternative] = []

        if weeksRemaining >= 2 {
            // 只有時間 >= 2 週才提供替代選項
            if recommendedStage == .build {
                // 推薦增強期時，提供「巔峰期」和「基礎期」選項

                // 巔峰期（總是可用）
                alternatives.append(StageAlternative(
                    stage: .peak,
                    suitableFor: NSLocalizedString("start_stage.peak_suitable",
                                                  comment: "訓練充分的資深跑者"),
                    riskLevel: .medium,  // 🔧 修正：相對於推薦的增強期，選擇巔峰期需要更高訓練基礎，中風險
                    description: NSLocalizedString("start_stage.peak_description",
                                                  comment: "適合週跑量40km+的跑者")
                ))

                // 基礎期（只有可用時才添加：需要≥6週）
                if isStageAvailable(.base, weeksRemaining: weeksRemaining) {
                    let baseRiskLevel: TrainingRiskLevel = weeksRemaining >= 10 ? .low : .medium
                    let baseDescription: String
                    if weeksRemaining >= 10 {
                        baseDescription = NSLocalizedString("start_stage.base_description",
                                                           comment: "從基礎期開始，循序漸進")
                    } else {
                        baseDescription = NSLocalizedString("start_stage.base_short_time_description",
                                                           comment: "時間較短，各階段訓練效果可能不佳")
                    }

                    alternatives.append(StageAlternative(
                        stage: .base,
                        suitableFor: NSLocalizedString("start_stage.base_suitable",
                                                      comment: "完整計劃"),
                        riskLevel: baseRiskLevel,
                        description: baseDescription
                    ))
                }
            } else if recommendedStage == .peak {
                // 推薦巔峰期時，提供「增強期」和「基礎期」選項

                // 增強期（只有可用時才添加：需要≥3週）
                if isStageAvailable(.build, weeksRemaining: weeksRemaining) {
                    alternatives.append(StageAlternative(
                        stage: .build,
                        suitableFor: NSLocalizedString("start_stage.build_suitable",
                                                      comment: "有訓練習慣的跑者"),
                        riskLevel: .low,  // 🔧 修正：相對於推薦的巔峰期，選擇增強期更安全，低風險
                        description: NSLocalizedString("start_stage.build_description",
                                                      comment: "更安全的選擇")
                    ))
                }

                // 基礎期（只有可用時才添加：需要≥6週）
                if isStageAvailable(.base, weeksRemaining: weeksRemaining) {
                    alternatives.append(StageAlternative(
                        stage: .base,
                        suitableFor: NSLocalizedString("start_stage.base_suitable",
                                                      comment: "完整計劃"),
                        riskLevel: .high,
                        description: NSLocalizedString("start_stage.base_very_short_description",
                                                      comment: "時間不足，各階段訓練效果可能不佳")
                    ))
                }
            } else if recommendedStage == .base {
                // 推薦基礎期時，提供「增強期」選項（增強期總是可用在此情況，因為推薦基礎期代表至少有充足時間）
                alternatives.append(StageAlternative(
                    stage: .build,
                    suitableFor: NSLocalizedString("start_stage.build_suitable",
                                                  comment: "有訓練習慣的跑者"),
                    riskLevel: .medium,
                    description: NSLocalizedString("start_stage.build_skip_base_description",
                                                  comment: "如果已有週跑量20-30km")
                ))
            }
        }

        return StartStageRecommendation(
            recommendedStage: recommendedStage,
            stageName: recommendedStage.displayName,
            reason: reason,
            riskLevel: riskLevel,
            weeksRemaining: weeksRemaining,
            alternatives: alternatives,
            trainingDistribution: distribution,
            isFullMarathon: targetDistanceKm > 21.1
        )
    }
}
