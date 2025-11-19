import Foundation
import SwiftUI

// MARK: - Share Card Data Models

/// 文字疊加層
struct TextOverlay: Identifiable, Equatable {
    let id: UUID
    var text: String
    var position: CGPoint          // 相對於卡片的位置 (0-1080, 0-1920)
    var fontSize: CGFloat = 48     // 字體大小
    var fontWeight: Font.Weight = .bold
    var textColor: Color = .white
    var backgroundColor: Color? = nil  // 背景顏色（可選，預設無背景）
    var rotation: Angle = .zero
    var scale: CGFloat = 1.0

    init(id: UUID = UUID(),
         text: String,
         position: CGPoint,
         fontSize: CGFloat = 48,
         fontWeight: Font.Weight = .bold,
         textColor: Color = .white,
         backgroundColor: Color? = nil,
         rotation: Angle = .zero,
         scale: CGFloat = 1.0) {
        self.id = id
        self.text = text
        self.position = position
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.rotation = rotation
        self.scale = scale
    }

    static func == (lhs: TextOverlay, rhs: TextOverlay) -> Bool {
        lhs.id == rhs.id
    }
}

/// 分享卡完整數據結構
struct WorkoutShareCardData {
    let workout: WorkoutV2
    let workoutDetail: WorkoutV2Detail?
    let userPhoto: UIImage?

    // 版型與配色
    let layoutMode: ShareCardLayoutMode
    let colorScheme: ShareCardColorScheme

    // 圖片變換參數
    var photoScale: CGFloat = 1.0
    var photoOffset: CGSize = .zero

    // 自訂文案
    var customAchievementTitle: String?  // 用戶自訂標題
    var customEncouragementText: String? // 用戶自訂鼓勵語

    // 文字疊加層
    var textOverlays: [TextOverlay] = []  // 用戶添加的自由文字

    // MARK: - 文案內容 (優先使用 API,回退到本地生成)

    /// 成就主語句（優先順序：自訂 > API > 本地生成）
    var achievementTitle: String {
        // 如果有自訂值（包括空字串表示已刪除），優先使用
        if let customTitle = customAchievementTitle {
            print("✅ [ShareCardData] 使用自訂標題: \(customTitle)")
            return customTitle  // 可能是 "" 或自訂內容
        }

        // 其次使用 API 標題
        if let apiTitle = workout.shareCardContent?.achievementTitle, !apiTitle.isEmpty {
            print("✅ [ShareCardData] 使用 API 成就標題: \(apiTitle)")
            return apiTitle
        }

        // 最後使用本地生成
        let localTitle = generateLocalAchievementTitle()
        print("⚠️ [ShareCardData] 使用本地生成標題: \(localTitle)")
        return localTitle
    }

    /// 鼓勵語（優先順序：自訂 > API > 本地生成）
    var encouragementText: String {
        // 如果有自訂值（包括空字串表示已刪除），優先使用
        if let customText = customEncouragementText {
            print("✅ [ShareCardData] 使用自訂鼓勵語: \(customText)")
            return customText  // 可能是 "" 或自訂內容
        }

        // 其次使用 API 鼓勵語
        if let apiText = workout.shareCardContent?.encouragementText, !apiText.isEmpty {
            print("✅ [ShareCardData] 使用 API 鼓勵語: \(apiText)")
            return apiText
        }

        // 最後使用本地生成
        let localText = generateLocalEncouragement()
        print("⚠️ [ShareCardData] 使用本地生成鼓勵語: \(localText)")
        return localText
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
enum ShareCardSize: CaseIterable {
    case instagram916  // 1080x1920 (9:16) - Stories
    case instagram11   // 1080x1080 (1:1) - Square Post
    case instagram45   // 1080x1350 (4:5) - Portrait Post

    var cgSize: CGSize {
        switch self {
        case .instagram916:
            return CGSize(width: 1080, height: 1920)
        case .instagram11:
            return CGSize(width: 1080, height: 1080)
        case .instagram45:
            return CGSize(width: 1080, height: 1350)
        }
    }

    var width: CGFloat { cgSize.width }
    var height: CGFloat { cgSize.height }
    var aspectRatio: String {
        switch self {
        case .instagram916: return "9:16"
        case .instagram11: return "1:1"
        case .instagram45: return "4:5"
        }
    }

    var displayName: String {
        switch self {
        case .instagram916: return "Stories (9:16)"
        case .instagram11: return "Square (1:1)"
        case .instagram45: return "Portrait (4:5)"
        }
    }
}
