import Foundation

/// 無課表轉換畫面的純顯示計算（與 SwiftUI 解耦，可單測）。
struct NoPlanConversionContent {
    let currentWeek: Int
    let totalWeeks: Int
    let raceName: String?
    let daysToRace: Int?
    let upcomingWeeks: [WeekPreview]

    var completedWeeks: Int { max(0, currentWeek - 1) }
    var showsRaceCountdown: Bool { raceName != nil && daysToRace != nil }
    var nextWeekPreview: WeekPreview? { upcomingWeeks.first }
}
