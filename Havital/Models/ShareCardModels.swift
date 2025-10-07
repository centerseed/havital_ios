import Foundation
import SwiftUI

// MARK: - Share Card Data Models

/// 分享卡完整數據結構
struct WorkoutShareCardData {
    let workout: WorkoutV2
    let workoutDetail: WorkoutV2Detail?
    let userPhoto: UIImage?

    // 版型與配色
    let layoutMode: ShareCardLayoutMode
    let colorScheme: ShareCardColorScheme

    // MARK: - 文案內容 (優先使用 API,回退到本地生成)

    /// 成就主語句
    var achievementTitle: String {
        if let title = workout.shareCardContent?.achievementTitle {
            return title
        }
        return generateLocalAchievementTitle()
    }

    /// 鼓勵語
    var encouragementText: String {
        if let text = workout.shareCardContent?.encouragementText {
            return text
        }
        return generateLocalEncouragement()
    }

    /// 連續訓練資訊
    var streakInfo: String? {
        guard let days = workout.shareCardContent?.streakDays, days > 0 else {
            return nil
        }
        return "🏅 連續訓練 \(days) 天"
    }

    // MARK: - 本地文案生成 (當 API 無內容時使用)

    private func generateLocalAchievementTitle() -> String {
        // 規則: 根據訓練類型生成
        let trainingType = workout.advancedMetrics?.trainingType ?? "運動"
        let duration = workout.formattedDuration

        // 翻譯訓練類型
        let localizedType: String
        switch trainingType.lowercased() {
        case "easy_run", "easy":
            localizedType = "輕鬆跑"
        case "recovery_run":
            localizedType = "恢復跑"
        case "long_run":
            localizedType = "LSD"
        case "tempo":
            localizedType = "節奏跑"
        case "threshold":
            localizedType = "乳酸閾值跑"
        case "interval":
            localizedType = "間歇訓練"
        case "fartlek":
            localizedType = "法特萊克訓練"
        case "hill_training":
            localizedType = "爬坡訓練"
        case "race":
            localizedType = "比賽"
        default:
            localizedType = trainingType
        }

        return "\(localizedType) \(duration) 完成!"
    }

    private func generateLocalEncouragement() -> String {
        // 規則: 根據訓練類型和表現生成鼓勵語
        let encouragements = [
            "配速穩定,進步正在累積。",
            "今天的節奏剛剛好。",
            "呼吸順暢,這節奏正好。",
            "保持這個步調,持續進步!",
            "穩健的步伐,踏實的進步。"
        ]

        return encouragements.randomElement() ?? "配速穩定,進步正在累積。"
    }
}

// MARK: - Layout Mode

/// 版型模式
enum ShareCardLayoutMode: String, Codable {
    case auto      // 自動選擇
    case bottom    // 底部橫條
    case side      // 側邊浮層
    case top       // 頂部置中
}

// MARK: - Color Scheme

/// 配色方案
struct ShareCardColorScheme {
    let backgroundColor: Color
    let textColor: Color
    let overlayOpacity: Double
    let useGradient: Bool

    /// 預設配色方案 (黑色半透明背景 + 白字)
    static let `default` = ShareCardColorScheme(
        backgroundColor: .black,
        textColor: .white,
        overlayOpacity: 0.3,
        useGradient: false
    )

    /// 亮背景配色方案 (白色半透明背景 + 黑字)
    static let light = ShareCardColorScheme(
        backgroundColor: .white,
        textColor: .black,
        overlayOpacity: 0.3,
        useGradient: false
    )

    /// 頂部漸層配色方案
    static let topGradient = ShareCardColorScheme(
        backgroundColor: .black,
        textColor: .white,
        overlayOpacity: 0.5,
        useGradient: true
    )
}

// MARK: - Photo Analysis

/// 照片分析結果
struct PhotoAnalysisResult {
    let brightness: Double              // 0-1
    let subjectPosition: SubjectPosition
    let dominantColors: [Color]
    let suggestedLayout: ShareCardLayoutMode
    let suggestedTextColor: Color
    let suggestedColorScheme: ShareCardColorScheme
}

/// 主體位置
enum SubjectPosition {
    case top
    case bottom
    case left
    case right
    case center
}

// MARK: - Export Size

/// 導出尺寸
enum ShareCardSize {
    case instagram916  // 1080x1920 (9:16)
    case instagram11   // 1080x1080 (1:1)

    var cgSize: CGSize {
        switch self {
        case .instagram916:
            return CGSize(width: 1080, height: 1920)
        case .instagram11:
            return CGSize(width: 1080, height: 1080)
        }
    }

    var width: CGFloat { cgSize.width }
    var height: CGFloat { cgSize.height }
    var aspectRatio: String {
        switch self {
        case .instagram916: return "9:16"
        case .instagram11: return "1:1"
        }
    }
}
