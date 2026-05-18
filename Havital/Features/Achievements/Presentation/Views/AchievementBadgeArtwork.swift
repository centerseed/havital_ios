import SwiftUI

enum AchievementBadgeArtwork {
    static func assetName(for badge: AchievementBadge) -> String {
        if let assetName = badge.assetName, !assetName.isEmpty {
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
        case "BADGE-START-PLAN-STARTED":
            return "achievement_badge_start_plan_started_calendar"
        case "BADGE-START-FIRST-WEEK":
            return "achievement_badge_start_first_week_seven_flags"
        case "BADGE-START-FIRST-LONG-RUN":
            return "achievement_badge_start_first_long_run_road"
        case "BADGE-BUILD-LONG-RUN-DONE":
            return "achievement_badge_build_long_run_route_pin"
        case "BADGE-START-FIRST-RECOVERY":
            return "achievement_badge_start_first_recovery_leaf_runner"
        case "BADGE-ADAPT-RECOVERY-EARNED":
            return "achievement_badge_adapt_recovery_earned_pin_star"
        case "BADGE-BUILD-SHOWING-UP":
            return "achievement_badge_build_showing_up_footprints"
        case "BADGE-BUILD-ROUTINE-BUILDER":
            return "achievement_badge_build_routine_builder_week_line"
        case "BADGE-BUILD-EIGHT-WEEK-BLOCK":
            return "achievement_badge_build_eight_week_block_grid"
        case "BADGE-BUILD-WEEKLY-GOAL":
            return "achievement_badge_build_weekly_goal_target"
        case "BADGE-BUILD-VOLUME-BASE":
            return "achievement_badge_build_volume_base_heart"
        case "BADGE-BUILD-PLAN-FINISHER":
            return "achievement_badge_build_plan_finisher_calendar"
        case "BADGE-ADAPT-LOAD-BALANCED":
            return "achievement_badge_adapt_load_balance_scale"
        case "BADGE-ADAPT-HEAT-ADJUSTED":
            return "achievement_badge_adapt_heat_adjusted_runner"
        case "BADGE-ADAPT-COMEBACK":
            return "achievement_badge_adapt_comeback_bridge"
        case "BADGE-ADAPT-REST-WEEK":
            return "achievement_badge_adapt_respect_recovery_week_pause"
        case "BADGE-ADAPT-SMART-SKIP":
            return "achievement_badge_adapt_smart_skip_lightbulb"
        case "BADGE-ADAPT-PACE-PATIENCE":
            return "achievement_badge_adapt_recovery_patience_hourglass"
        case "BADGE-PROVE-NEW-PB":
            return "achievement_badge_prove_new_pb"
        case "BADGE-PROVE-FIRST-5K":
            return "achievement_badge_prove_first_5k"
        case "BADGE-PROVE-FIRST-10K":
            return "achievement_badge_prove_first_10k"
        case "BADGE-PROVE-FIRST-HALF":
            return "achievement_badge_prove_first_half_marathon_21k"
        case "BADGE-PROVE-FIRST-MARATHON":
            return "achievement_badge_prove_first_marathon_42k"
        case "BADGE-PROVE-DISTANCE-BREAKTHROUGH":
            return "achievement_badge_prove_distance_breakthrough_growth_chart"
        case "BADGE-PROVE-RACE-READY":
            return "achievement_badge_prove_marathon_ready_42k_ready"
        case "BADGE-PROVE-GOAL-COMPLETED":
            return "achievement_badge_prove_race_ready_summit_flag"
        case "BADGE-ID-5K-RUNNER":
            return "achievement_badge_identity_5k_runner"
        case "BADGE-ID-10K-RUNNER":
            return "achievement_badge_identity_10k_runner"
        case "BADGE-ID-HALF-MARATHONER":
            return "achievement_badge_identity_half_marathoner"
        case "BADGE-ID-MARATHON-BUILDER":
            return "achievement_badge_identity_marathon_builder_42k"
        case "BADGE-ID-CONSISTENT-RUNNER":
            return "achievement_badge_identity_consistent_runner_route"
        case "BADGE-ID-SMART-TRAINER":
            return "achievement_badge_identity_smart_trainer_heart"
        case "BADGE-ID-PB-HUNTER":
            return "achievement_badge_identity_pb_hunter_target"
        default:
            return "achievement_badge_identity_smart_trainer_lightbulb"
        }
    }
}

struct AchievementBadgeImage: View {
    let assetName: String
    let status: AchievementBadgeStatus
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .saturation(isUnlocked ? 1 : 0)
                .opacity(isUnlocked ? 1 : 0.42)

            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(AppFont.captionSmall())
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.42))
                    .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
    }

    private var isUnlocked: Bool {
        status == .unlocked || status == .inProgress
    }
}
