import SwiftUI

// MARK: - ClimateDay 顯示規則（T-0165）

/// 週視圖：七天一律溫度膠囊，顏色隨 `heat_pressure_level`。
/// `comfortable` **不說話** —— 只有溫度，無警示色、無圖示升級。
///
/// 顏色沿用改版前 `ClimateMeta` 的定義（黃 → 橘 → 紅 → 深紅），i18n key 也沿用同一組，
/// 所以三語文案不需要新增。
extension ClimateDay {

    var badgeAccentColor: Color {
        switch normalizedHeatPressureLevel {
        case "mild":
            return .yellow
        case "moderate":
            return .orange
        case "high":
            return .red
        case "danger":
            return Color(red: 0.55, green: 0.10, blue: 0.12)
        default:
            // comfortable：不說話。中性灰，讀者一眼掃過去不會被拉住注意力。
            return .secondary
        }
    }

    var badgeBackgroundColor: Color {
        if isComfortable {
            return Color.secondary.opacity(0.10)
        }
        return badgeAccentColor.opacity(normalizedHeatPressureLevel == "danger" ? 0.18 : 0.15)
    }

    var badgeForegroundColor: Color {
        if isComfortable {
            return .secondary
        }
        // 黃色在淺色背景上對比不足，mild 用橘字（沿用改版前的處理）。
        return normalizedHeatPressureLevel == "mild" ? .orange : badgeAccentColor
    }

    /// 涼爽日不升級圖示 —— 連溫度計都不放，只留溫度數字。
    var badgeSystemImageName: String? {
        switch normalizedHeatPressureLevel {
        case "mild", "moderate":
            return "thermometer.medium"
        case "high", "danger":
            return "thermometer.sun.fill"
        default:
            return nil
        }
    }

    var shortLevelDisplayText: String {
        switch normalizedHeatPressureLevel {
        case "mild": return NSLocalizedString("climate.short_level.mild", comment: "")
        case "moderate": return NSLocalizedString("climate.short_level.moderate", comment: "")
        case "high": return NSLocalizedString("climate.short_level.high", comment: "")
        case "danger": return NSLocalizedString("climate.short_level.danger", comment: "")
        default: return NSLocalizedString("climate.short_level.default", comment: "")
        }
    }

    var levelDisplayText: String {
        switch normalizedHeatPressureLevel {
        case "mild": return NSLocalizedString("climate.level.mild", comment: "")
        case "moderate": return NSLocalizedString("climate.level.moderate", comment: "")
        case "high": return NSLocalizedString("climate.level.high", comment: "")
        case "danger": return NSLocalizedString("climate.level.danger", comment: "")
        default: return NSLocalizedString("climate.level.default", comment: "")
        }
    }

    var sectionTitle: String { NSLocalizedString("climate.section_title", comment: "") }
    var levelTitle: String { NSLocalizedString("climate.level_title", comment: "") }
    var temperatureTitle: String { NSLocalizedString("climate.temperature_title", comment: "") }
    var adjustmentTitle: String { NSLocalizedString("climate.adjustment_title", comment: "") }
    var originalPaceTitle: String { NSLocalizedString("climate.original_pace_title", comment: "") }
    var adjustedPaceTitle: String { NSLocalizedString("climate.adjusted_pace_title", comment: "") }

    var feelsLikeTempText: String {
        String(format: "%.1f°C", feelsLikeTempC)
    }

    /// 「配速 +5%」。四捨五入為 0 不顯示（避免「配速 +0%」）。
    var adjustmentText: String? {
        guard paceAdjustmentPct.rounded() != 0 else { return nil }
        return String(format: NSLocalizedString("climate.adjustment.pace_pct", comment: ""), paceAdjustmentPct)
    }

    /// 長跑建議縮減幅度。
    ///
    /// ⚠️ wire 上的 `long_run_keep_ratio` 是**保留比例**（0.7 = 跑原訂的 70%），
    /// 但 `climate.long_run_reduction` 這條文案講的是**縮減幅度**（「長跑建議縮減 %.0f%%」）。
    /// 改版前的 iOS 直接把 0.7 餵進去 → 顯示「長跑建議縮減 1%」。這裡改為 (1 - ratio) × 100 = 30%。
    var longRunReductionText: String? {
        guard let ratio = longRunKeepRatio, ratio > 0, ratio < 1 else { return nil }
        return String(format: NSLocalizedString("climate.long_run_reduction", comment: ""), (1 - ratio) * 100)
    }

    var heatAdaptationExplanation: String {
        NSLocalizedString("climate.explanation", comment: "")
    }

    var recommendationTitle: String {
        NSLocalizedString("climate.recommendation_title", comment: "")
    }

    /// 建議訓練時段／室內（依等級，對齊 SPEC-climate-engine 附錄 A）。
    var trainingTimeRecommendation: String {
        switch normalizedHeatPressureLevel {
        case "danger": return NSLocalizedString("climate.recommendation.danger", comment: "")
        case "high": return NSLocalizedString("climate.recommendation.high", comment: "")
        case "moderate": return NSLocalizedString("climate.recommendation.moderate", comment: "")
        default: return NSLocalizedString("climate.recommendation.default", comment: "")
        }
    }

    /// 詳情頁 header 上的「等級 · 體感 32.0°C」。
    var headerChipText: String {
        "\(shortLevelDisplayText) · \(temperatureTitle) \(feelsLikeTempText)"
    }
}

// MARK: - 週視圖膠囊

/// 七天恆滿的溫度膠囊。休息日、力量日、涼爽日都有 —— 溫度是日期的屬性。
struct ClimateCapsuleView: View {
    let climate: ClimateDay

    var body: some View {
        HStack(spacing: 3) {
            if let icon = climate.badgeSystemImageName {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(climate.temperatureText)
                .font(AppFont.micro())
                .fontWeight(.semibold)
        }
        .foregroundColor(climate.badgeForegroundColor)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(climate.badgeBackgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel(
            climate.isComfortable
                ? climate.temperatureText
                : "\(climate.temperatureText) \(climate.shortLevelDisplayText)"
        )
    }
}
