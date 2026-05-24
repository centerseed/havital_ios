import SwiftUI
import UIKit

enum AchievementBadgeArtwork {
    static func assetName(for badge: AchievementBadge) -> String {
        if let assetName = badge.assetName,
           !assetName.isEmpty,
           UIImage(named: assetName) != nil {
            return assetName
        }

        return fallbackAssetName(for: badge.badgeId)
    }

    static func assetName(for snapshot: AchievementBadgeSnapshot) -> String {
        fallbackAssetName(for: snapshot.badgeId)
    }

    private static func fallbackAssetName(for badgeId: String) -> String {
        switch badgeId {
        case "BADGE-START-FIRST-RUN":
            return "achievement_badge_start_first_run_marker"
        case "BADGE-START-PLAN-STARTED", "BADGE-PLAN-00-PLAN-STARTED":
            return "achievement_badge_plan_00_plan_started"
        case "BADGE-START-FIRST-WEEK", "BADGE-PLAN-01-FIRST-QUALIFIED-WEEK":
            return "achievement_badge_plan_01_first_qualified_week"
        case "BADGE-PLAN-02-TWO-QUALIFIED-WEEKS":
            return "achievement_badge_plan_02_two_qualified_weeks"
        case "BADGE-PLAN-04-FOUR-QUALIFIED-WEEKS":
            return "achievement_badge_plan_04_four_qualified_weeks"
        case "BADGE-PLAN-08-EIGHT-QUALIFIED-WEEKS":
            return "achievement_badge_plan_08_eight_qualified_weeks"
        case "BADGE-PLAN-12-TWELVE-QUALIFIED-WEEKS":
            return "achievement_badge_plan_12_twelve_qualified_weeks"
        case "BADGE-PLAN-24-TWENTY-FOUR-QUALIFIED-WEEKS":
            return "achievement_badge_plan_24_twenty_four_qualified_weeks"
        case "BADGE-RHYTHM-01-FIRST-ACTIVE-WEEK":
            return "achievement_badge_rhythm_01_first_active_week"
        case "BADGE-RHYTHM-02-RETURN-WEEK":
            return "achievement_badge_rhythm_02_return_week"
        case "BADGE-RHYTHM-04-FOUR-WEEK-RHYTHM":
            return "achievement_badge_rhythm_04_four_week_rhythm"
        case "BADGE-RHYTHM-08-EIGHT-WEEK-RHYTHM":
            return "achievement_badge_rhythm_08_eight_week_rhythm"
        case "BADGE-RHYTHM-12-SEASON-RUNNER":
            return "achievement_badge_rhythm_12_season_runner"
        case "BADGE-RHYTHM-24-HALF-YEAR-RUNNER":
            return "achievement_badge_rhythm_24_half_year_runner"
        case "BADGE-RHYTHM-52-YEAR-RUNNER":
            return "achievement_badge_rhythm_52_year_runner"
        case "BADGE-RESULTS-01-FIRST-MAJOR-RESULT", "BADGE-PROVE-NEW-PB":
            return "achievement_badge_results_01_first_major_result"
        case "BADGE-RESULTS-03-THREE-MAJOR-RESULTS":
            return "achievement_badge_results_03_three_major_results"
        case "BADGE-RESULTS-05-FIVE-MAJOR-RESULTS":
            return "achievement_badge_results_05_five_major_results"
        case "BADGE-RESULTS-10-TEN-MAJOR-RESULTS":
            return "achievement_badge_results_10_ten_major_results"
        case "BADGE-RESULTS-20-TWENTY-MAJOR-RESULTS":
            return "achievement_badge_results_20_twenty_major_results"
        case "BADGE-RESULTS-COLLECTOR":
            return "achievement_badge_results_collector"
        case "BADGE-MILEAGE-MARKERS-100K":
            return "achievement_badge_mileage_markers_100k"
        case "BADGE-MILEAGE-MARKERS-200K":
            return "achievement_badge_mileage_markers_200k"
        case "BADGE-MILEAGE-MARKERS-400K":
            return "achievement_badge_mileage_markers_400k"
        case "BADGE-MILEAGE-MARKERS-600K":
            return "achievement_badge_mileage_markers_600k"
        case "BADGE-MILEAGE-MARKERS-800K":
            return "achievement_badge_mileage_markers_800k"
        case "BADGE-MILEAGE-MARKERS-10000K":
            return "achievement_badge_mileage_markers_10000k"
        default:
            return "achievement_badge_results_collector"
        }
    }
}

struct AchievementBadgeImage: View {
    let assetName: String
    let status: AchievementBadgeStatus
    let size: CGFloat

    var body: some View {
        if isUnlocked {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Locked: gray rounded-rect with large "?" — user-requested "mystery" look
            // instead of grayscale artwork + lock chip.
            let cornerRadius = size * 0.22
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(UIColor.systemGray5))
                Text("?")
                    .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(UIColor.systemGray2))
            }
            .frame(width: size, height: size)
        }
    }

    private var isUnlocked: Bool {
        status == .unlocked
    }
}
