import Foundation

/// Type-safe localization keys for Havital app
enum L10n {
    
    // MARK: - Main Navigation
    enum Tab {
        static let trainingPlan = "tab.training_plan"
        static let trainingRecord = "tab.training_record"
        static let performanceData = "tab.performance_data"
        static let profile = "tab.profile"
    }
    
    // MARK: - Common Actions
    enum Common {
        static let save = "common.save"
        static let cancel = "common.cancel"
        static let delete = "common.delete"
        static let edit = "common.edit"
        static let done = "common.done"
        static let close = "common.close"
        static let confirm = "common.confirm"
        static let loading = "common.loading"
        static let retry = "common.retry"
        static let refresh = "common.refresh"
        static let settings = "common.settings"
        static let logout = "common.logout"
        static let login = "common.login"
        static let next = "common.next"
        static let back = "common.back"
        static let skip = "common.skip"
        static let start = "common.start"
        static let stop = "common.stop"
        static let pause = "common.pause"
        static let resume = "common.resume"
        static let finish = "common.finish"
        static let weekUnit = "common.week_unit" // "週"
    }
    
    // MARK: - Authentication
    enum Auth {
        static let welcome = "auth.welcome"
        static let loginTitle = "auth.login_title"
        static let logoutTitle = "auth.logout_title"
        static let loginSubtitle = "auth.login_subtitle"
        static let emailPlaceholder = "auth.email_placeholder"
        static let passwordPlaceholder = "auth.password_placeholder"
        static let forgotPassword = "auth.forgot_password"
        static let noAccount = "auth.no_account"
        static let signUp = "auth.sign_up"
        static let loginFailed = "auth.login_failed"
        static let logoutConfirm = "auth.logout_confirm"
        static let registerTitle = "auth.register_title" // "註冊帳號"
        static let register = "auth.register" // "註冊"
        static let registerFailed = "auth.register_failed" // "註冊失敗"
        static let registerSuccess = "auth.register_success" // "註冊成功"
        static let registerSuccessMessage = "auth.register_success_message" // "請至您的電子信箱點擊確認連結，完成驗證後返回此處登入。"
        static let verifyEmailTitle = "auth.verify_email_title" // "驗證 Email"
        static let verifyCodePlaceholder = "auth.verify_code_placeholder" // "驗證碼 (oobCode)"
        static let verifyEmail = "auth.verify_email" // "驗證 Email"
        static let verifyFailed = "auth.verify_failed" // "驗證失敗"
        static let verifySuccess = "auth.verify_success" // "驗證成功"
    }
    
    // MARK: - Calendar Sync Setup
    enum CalendarSyncSetup {
        static let title = "calendar_sync_setup.title" // "同步至行事曆"
        static let description = "calendar_sync_setup.description" // "將訓練日同步到你的行事曆，幫助你更好地安排時間。"
        static let syncMethod = "calendar_sync_setup.sync_method" // "同步方式"
        static let allDay = "calendar_sync_setup.all_day" // "全天活動"
        static let specificTime = "calendar_sync_setup.specific_time" // "指定時間"
        static let trainingTime = "calendar_sync_setup.training_time" // "訓練時間"
        static let startTime = "calendar_sync_setup.start_time" // "開始時間"
        static let endTime = "calendar_sync_setup.end_time" // "結束時間"
        static let adjustNote = "calendar_sync_setup.adjust_note" // "你可以之後在行事曆中調整時間"
        static let startSync = "calendar_sync_setup.start_sync" // "開始同步"
        static let accessError = "calendar_sync_setup.access_error" // "請在設定中允許 Havital 存取行事曆"
    }
    
    // MARK: - Edit Target View
    enum EditTarget {
        static let title = "edit_target.title" // "編輯賽事目標"
        static let raceInfo = "edit_target.race_info" // "賽事資訊"
        static let raceName = "edit_target.race_name" // "賽事名稱"
        static let raceDate = "edit_target.race_date" // "賽事日期"
        static let remainingWeeks = "edit_target.remaining_weeks" // "距離比賽還有 %d 週"
        static let raceDistance = "edit_target.race_distance" // "比賽距離"
        static let selectDistance = "edit_target.select_distance" // "選擇距離"
        static let targetTime = "edit_target.target_time" // "目標完賽時間"
        static let hoursUnit = "edit_target.hours_unit" // "時"
        static let minutesUnit = "edit_target.minutes_unit" // "分"
        static let averagePace = "edit_target.average_pace" // "平均配速：%@ /公里"
        static let distance3k = "distance.3k" // "3公里"
        static let distance5k = "distance.5k" // "5公里"
        static let distance10k = "distance.10k" // "10公里"
        static let distance15k = "distance.15k" // "15公里"
        static let distanceHalf = "distance.half_marathon" // "半程馬拉松"
        static let distanceFull = "distance.full_marathon" // "全程馬拉松"
        static let addTitle = "edit_target.add_title" // "添加支援賽事"
        static let editTitle = "edit_target.edit_title" // "編輯支援賽事"
        static let deleteRace = "edit_target.delete_race" // "刪除賽事"
        static let deleteConfirmTitle = "edit_target.delete_confirm_title" // "確認刪除"
        static let deleteConfirmMessage = "edit_target.delete_confirm_message" // "確定要刪除這個支援賽事嗎？此操作無法復原。"
    }
    
    // MARK: - Weekly Distance Editor View
    enum WeeklyDistanceEditor {
        static let title = "weekly_distance_editor.title" // "編輯週跑量"
        static let weeklyDistance = "weekly_distance_editor.weekly_distance" // "週跑量：%d 公里"
        static let nextWeekNotice = "weekly_distance_editor.next_week_notice" // "當週跑量的修改會在下一週的課表生效"
    }

    // MARK: - Training Item Detail View
enum TrainingItemDetail {
    static let purpose = "training_item_detail.purpose" // "目的"
    static let benefits = "training_item_detail.benefits" // "效果"
    static let method = "training_item_detail.method" // "實行方式"
    static let precautions = "training_item_detail.precautions" // "注意事項"
    static let notFound = "training_item_detail.not_found" // "無法找到該運動項目的說明"
}

// MARK: - Training Progress View
enum TrainingProgress {
    static let review = "training_progress.review" // "回顧"
    static let schedule = "training_progress.schedule" // "課表"
    static let generateSchedule = "training_progress.generate_schedule" // "產生課表"
}

// MARK: - Training Plan View
enum TrainingPlan {
    static let cycleCompleted = "training_plan.cycle_completed" // "訓練週期已完成"
    static let congratulations = "training_plan.congratulations" // "恭喜您完成這個訓練週期！"
    static let loadingSchedule = "training_plan.loading_schedule" // "課表載入中..."
}

// MARK: - Workout Summary Row
enum WorkoutSummaryRow {
    static let calculatingHeartRate = "workout_summary_row.calculating_heart_rate" // "心率計算中..."
}

// MARK: - Next Week Planning View
enum NextWeekPlanning {
    static let title = "next_week_planning.title" // "下週計劃設定"
    static let weeklyFeeling = "next_week_planning.weekly_feeling" // "本週訓練感受（0-最差，5-最佳）"
    static let overallFeeling = "next_week_planning.overall_feeling" // "整體感受："
    static let trainingExpectation = "next_week_planning.training_expectation" // "對於下週的訓練期望，Vita會依據實際情況做出調整，也可以自由的編輯新產生的運動計畫"
    static let difficultyAdjustment = "next_week_planning.difficulty_adjustment" // "難度調整"
    static let daysAdjustment = "next_week_planning.days_adjustment" // "運動天數調整"
    static let trainingItemAdjustment = "next_week_planning.training_item_adjustment" // "運動項目變化調整"
    static let startGenerating = "next_week_planning.start_generating" // "開始產生下次計劃"
    static let generatingPlan = "next_week_planning.generating_plan" // "Vita 正在為你產生訓練計劃..."
    static let pleaseWait = "next_week_planning.please_wait" // "請稍候"
    static let cancel = "next_week_planning.cancel" // "取消"

    enum Adjustment {
        static let decrease = "next_week_planning.adjustment.decrease" // "減少"
        static let keepSame = "next_week_planning.adjustment.keep_same" // "維持不變"
        static let increase = "next_week_planning.adjustment.increase" // "增加"
    }
}

    // MARK: - Training Plan Overview View
    enum TrainingPlanOverview {
        static let title = "training_plan_overview.title" // "訓練計劃總覽"
        static let targetEvaluation = "training_plan_overview.target_evaluation" // "目標評估"
        static let trainingMethod = "training_plan_overview.training_method" // "訓練方法"
        static let trainingStages = "training_plan_overview.training_stages" // "訓練階段"
        static let weekRange = "training_plan_overview.week_range" // "第%d-%d週"
        static let generatePlan = "training_plan_overview.generate_plan" // "產生第%d週訓練計劃"
        static let errorTitle = "training_plan_overview.error_title" // "錯誤"
        static let errorConfirm = "training_plan_overview.error_confirm" // "確定"
    }

    // MARK: - Week Selector Sheet
    enum WeekSelector {
        static let weekNumber = "week_selector.week_number" // "第 %d 週"
        static let review = "week_selector.review" // "回顧"
        static let schedule = "week_selector.schedule" // "課表"
        static let close = "week_selector.close" // "關閉"
    }

    // MARK: - Pace Chart View
enum PaceChart {
    static let title = "pace_chart.title" // "配速變化"
    static let unit = "pace_chart.unit" // "(分鐘/公里)"
    static let loading = "pace_chart.loading" // "載入配速數據中..."
    static let tryAgain = "pace_chart.try_again" // "請稍後再試"
    static let noData = "pace_chart.no_data" // "沒有配速數據"
    static let unableToGetData = "pace_chart.unable_to_get_data" // "無法獲取此次訓練的配速數據"
    static let fastest = "pace_chart.fastest" // "最快:"
    static let slowest = "pace_chart.slowest" // "最慢:"
}

// MARK: - Heart Rate Chart View
enum HeartRateChart {
    static let title = "heart_rate_chart.title" // "心率變化"
    static let loading = "heart_rate_chart.loading" // "載入心率數據中..."
    static let tryAgain = "heart_rate_chart.try_again" // "請稍後再試"
    static let noData = "heart_rate_chart.no_data" // "沒有心率數據"
    static let unableToGetData = "heart_rate_chart.unable_to_get_data" // "無法獲取此次訓練的心率數據"
}

// MARK: - Gait Analysis Chart View
enum GaitAnalysisChart {
    static let title = "gait_analysis_chart.title" // "步態分析"
    static let loading = "gait_analysis_chart.loading" // "載入步態分析數據中..."
    static let tryAgain = "gait_analysis_chart.try_again" // "請稍後再試"
    static let noData = "gait_analysis_chart.no_data" // "沒有步態分析數據"
    static let unableToGetData = "gait_analysis_chart.unable_to_get_data" // "無法獲取此次訓練的步態分析數據"
    static let average = "gait_analysis_chart.average" // "平均值"
    static let minimum = "gait_analysis_chart.minimum" // "最小值"
    static let maximum = "gait_analysis_chart.maximum" // "最大值"

    enum GaitTab {
        static let stanceTime = "gait_analysis_chart.gait_tab.stance_time" // "觸地時間"
        static let verticalRatio = "gait_analysis_chart.gait_tab.vertical_ratio" // "移動效率"
        static let cadence = "gait_analysis_chart.gait_tab.cadence" // "步頻"

        static let stanceTimeDescription = "gait_analysis_chart.gait_tab.stance_time_description" // "腳部接觸地面的時間，越短代表跑姿越有效率"
        static let verticalRatioDescription = "gait_analysis_chart.gait_tab.vertical_ratio_description" // "垂直移動與總移動距離的比率，越低代表移動效率越好"
        static let cadenceDescription = "gait_analysis_chart.gait_tab.cadence_description" // "每分鐘步數，理想範圍約180左右"
    }
}
    
    // MARK: - Onboarding
    enum Onboarding {
        static let welcome = "onboarding.welcome"
        static let setGoal = "onboarding.set_goal"
        static let raceDistance = "onboarding.race_distance"
        static let targetTime = "onboarding.target_time"
        static let trainingDays = "onboarding.training_days"
        static let weeklyVolume = "onboarding.weekly_volume"
        static let selectDays = "onboarding.select_days"
        static let connectData = "onboarding.connect_data"
        static let complete = "onboarding.complete"
        static let skipForNow = "onboarding.skip_for_now"
        
        // Data Source Selection
        static let chooseDataSource = "onboarding.choose_data_source"
        static let selectPlatformDescription = "onboarding.select_platform_description"
        static let processing = "onboarding.processing"
        static let continueStep = "onboarding.continue"
        
        // Apple Health
        static let appleHealthSubtitle = "onboarding.apple_health_subtitle"
        static let appleHealthDescription = "onboarding.apple_health_description"
        
        // Garmin
        static let garminSubtitle = "onboarding.garmin_subtitle"
        static let garminDescription = "onboarding.garmin_description"

        // Strava
        static let stravaSubtitle = "onboarding.strava_subtitle"
        static let stravaDescription = "onboarding.strava_description"

        // Time units
        static let hoursLabel = "onboarding.hours_label"
        static let minutesLabel = "onboarding.minutes_label"
        
        // Alerts
        static let garminAlreadyBound = "onboarding.garmin_already_bound"
        static let garminAlreadyBoundMessage = "onboarding.garmin_already_bound_message"
        static let iUnderstand = "onboarding.i_understand"
        static let error = "onboarding.error"
        static let confirm = "onboarding.confirm"
        
        // Target Race Examples
        static let targetRaceExample = "onboarding.target_race_example"
        
        // Personal Best View
        static let personalBestTitle = "onboarding.personal_best_title"
        static let personalBestDescription = "onboarding.personal_best_description"
        static let hasPersonalBest = "onboarding.has_personal_best"
        static let personalBestDetails = "onboarding.personal_best_details"
        static let selectDistanceTime = "onboarding.select_distance_time"
        static let distanceSelection = "onboarding.distance_selection"
        static let timeHours = "onboarding.time_hours"
        static let timeMinutes = "onboarding.time_minutes"
        static let averagePaceCalculation = "onboarding.average_pace_calculation"
        static let perKilometer = "onboarding.per_kilometer"
        static let enterValidTime = "onboarding.enter_valid_time"
        static let skipPersonalBest = "onboarding.skip_personal_best"
        static let skipPersonalBestMessage = "onboarding.skip_personal_best_message"
        static let personalBestTitleNav = "onboarding.personal_best_title_nav"
        static let next = "onboarding.next"
        
        // Training Days Setup
        static let trainingDaysTitle = "onboarding.training_days_title"
        static let selectTrainingDays = "onboarding.select_training_days"
        static let trainingDaysDescription = "onboarding.training_days_description"
        static let setupLongRunDay = "onboarding.setup_long_run_day"
        static let longRunDayDescription = "onboarding.long_run_day_description"
        static let selectLongRunDay = "onboarding.select_long_run_day"
        static let longRunDayMustBeTrainingDay = "onboarding.long_run_day_must_be_training_day"
        static let suggestSaturdayLongRun = "onboarding.suggest_saturday_long_run"
        static let savePreferencesPreview = "onboarding.save_preferences_preview"
        static let completeSetupViewSchedule = "onboarding.complete_setup_view_schedule"
        
        // Loading Messages
        static let analyzingPreferences = "onboarding.analyzing_preferences"
        static let calculatingIntensity = "onboarding.calculating_intensity"
        static let almostReady = "onboarding.almost_ready"
        static let evaluatingGoal = "onboarding.evaluating_goal"
        static let calculatingTrainingIntensity = "onboarding.calculating_training_intensity"
        static let generatingOverview = "onboarding.generating_overview"
        
        // Weekday Names
        static let monday = "onboarding.monday"
        static let tuesday = "onboarding.tuesday"
        static let wednesday = "onboarding.wednesday"
        static let thursday = "onboarding.thursday"
        static let friday = "onboarding.friday"
        static let saturday = "onboarding.saturday"
        static let sunday = "onboarding.sunday"

        // Weekly Distance Setup
        static let currentWeeklyDistance = "onboarding.current_weekly_distance"
        static let weeklyDistanceDescription = "onboarding.weekly_distance_description"
        static let targetDistanceLabel = "onboarding.target_distance_label"
        static let adjustWeeklyVolume = "onboarding.adjust_weekly_volume"
        static let weeklyVolumeLabel = "onboarding.weekly_volume_label"
        static let kmLabel = "onboarding.km_label"
        static let weeklyDistanceTitle = "onboarding.weekly_distance_title"
        static let skip = "onboarding.skip"
        static let back = "onboarding.back"
        static let nextStep = "onboarding.next_step"
    }
    
    // MARK: - Workout Row Component
    enum WorkoutRow {
        static let today = "workout_row.today"
        static let synced = "workout_row.synced"
        static let notSynced = "workout_row.not_synced"
        static let distance = "workout_row.distance"
        static let time = "workout_row.time"
        static let calories = "workout_row.calories"
    }
    
    // MARK: - Circular Progress Component
    enum CircularProgress {
        static let week = "circular_progress.week"
    }
    
    // MARK: - Target Race Card Component
    enum TargetRaceCard {
        static let title = "target_race_card.title"
        static let targetFinishTime = "target_race_card.target_finish_time"
        static let targetPace = "target_race_card.target_pace"
        static let perKilometer = "target_race_card.per_kilometer"
        static let daysUnit = "target_race_card.days_unit"
        static let distanceUnit = "target_race_card.distance_unit"
    }

    // MARK: - Goal Wheel Component
    enum GoalWheel {
        static let targetHeartRate = "goal_wheel.target_heart_rate"
        static let targetPace = "goal_wheel.target_pace"
        static let perKilometer = "goal_wheel.per_kilometer"
        static let bpm = "goal_wheel.bpm"
        static let done = "goal_wheel.done"
        static let cancel = "goal_wheel.cancel"
    }
    
    // MARK: - Training Stage Card Component
    enum TrainingStageCard {
        static let weekRange = "training_stage_card.week_range" // "第{start}-{end}週"
        static let weekStart = "training_stage_card.week_start" // "第{start}週開始"
        static let trainingFocus = "training_stage_card.training_focus" // "重點訓練:"
    }
    
    // MARK: - Lap Analysis View Component
    enum LapAnalysisView {
        static let title = "lap_analysis_view.title" // "圈速分析"
        static let noLapData = "lap_analysis_view.no_lap_data" // "無圈速數據"
        static let lapColumn = "lap_analysis_view.lap_column" // "圈"
        static let distanceColumn = "lap_analysis_view.distance_column" // "距離"
        static let timeColumn = "lap_analysis_view.time_column" // "時間"
        static let paceColumn = "lap_analysis_view.pace_column" // "配速"
        static let heartRateColumn = "lap_analysis_view.heart_rate_column" // "心率"
    }
    
    // MARK: - App Loading View Component
    enum AppLoadingView {
        static let initializationFailed = "app_loading_view.initialization_failed" // "應用程式初始化失敗"
        static let checkConnection = "app_loading_view.check_connection" // "請確認網路連線正常，然後重新嘗試"
        static let restart = "app_loading_view.restart" // "重新啟動"
    }
    
    // MARK: - Supporting Races Card Component
    enum SupportingRacesCard {
        static let title = "supporting_races_card.title" // "支援賽事"
        static let noRaces = "supporting_races_card.no_races" // "暫無支援賽事"
        static let pastRaces = "supporting_races_card.past_races" // "之前的賽事"
        static let daysRemaining = "supporting_races_card.days_remaining" // "剩餘 %d 天"
        static let kmUnit = "supporting_races_card.km_unit" // "公里"
        static let paceUnit = "supporting_races_card.pace_unit" // "/km"
    }
    
    // MARK: - Garmin Reconnection Alert Component
    enum GarminReconnectionAlert {
        static let title = "garmin_reconnection_alert.title" // "Garmin 帳號需要重新綁定"
        static let defaultMessage = "garmin_reconnection_alert.default_message" // "您的 Garmin Connect™ 帳號可能被其他帳號綁定，請重新綁定以確保數據正常同步。"
        static let reconnectButton = "garmin_reconnection_alert.reconnect_button" // "重新綁定 Garmin"
        static let remindLaterButton = "garmin_reconnection_alert.remind_later_button" // "稍後提醒"
    }
    
    // MARK: - Profile
    enum Profile {
        static let title = "profile.title"
        static let personalInfo = "profile.personal_info"
        static let trainingInfo = "profile.training_info"
        static let heartRateInfo = "profile.heart_rate_info"
        static let dataSources = "profile.data_sources"
        static let settings = "profile.settings"
        static let name = "profile.name"
        static let email = "profile.email"
        static let birthDate = "profile.birth_date"
        static let gender = "profile.gender"
        static let male = "profile.male"
        static let female = "profile.female"
        static let height = "profile.height"
        static let weight = "profile.weight"
        static let restingHR = "profile.resting_hr"
        static let maxHR = "profile.max_hr"
        static let weeklyMileage = "profile.weekly_mileage"
        static let editProfile = "profile.edit_profile"
    }
    
    // MARK: - Data Sources
    enum DataSource {
        static let title = "datasource.title"
        static let appleHealth = "datasource.apple_health"
        static let garminConnect = "datasource.garmin_connect"
        static let notConnected = "datasource.not_connected"
        static let connected = "datasource.connected"
        static let disconnect = "datasource.disconnect"
        static let connect = "datasource.connect"
        static let syncNow = "datasource.sync_now"
        static let lastSync = "datasource.last_sync"
        static let syncSuccess = "datasource.sync_success"
        static let syncFailed = "datasource.sync_failed"
        static let syncing = "datasource.syncing"
    }
    
    // MARK: - Training Plan
    enum Training {
        static let planTitle = "training.plan_title"
        static let weeklyPlan = "training.weekly_plan"
        static let dailyTraining = "training.daily_training"
        static let weeklyVolume = "training.weekly_volume"
        static let trainingReview = "training.training_review"
        static let generatePlan = "training.generate_plan"
        static let noPlan = "training.no_plan"
        static let createPlan = "training.create_plan"
        static let week = "training.week"
        static let today = "training.today"
        static let tomorrow = "training.tomorrow"
        static let yesterday = "training.yesterday"
        static let restDay = "training.rest_day"
        static let completed = "training.completed"
        static let pending = "training.pending"
        static let skipped = "training.skipped"
        static let editVolume = "training.edit_volume"
        static let editDays = "training.edit_days"
        
        // Loading Animation Messages
        enum LoadingAnimation {
            // Generate Plan Messages
            static let analyzingFitness = "training.loading.analyzing_fitness"
            static let planningIntensity = "training.loading.planning_intensity"
            static let preparingCustomPlan = "training.loading.preparing_custom_plan"
            
            // Generate Review Messages
            static let analyzingTrainingData = "training.loading.analyzing_training_data"
            static let evaluatingProgress = "training.loading.evaluating_progress"
            static let preparingReview = "training.loading.preparing_review"
        }
        
        // Training Review Sections
        enum Review {
            // Main titles
            static let weeklyReview = "training.review.weekly_review"
            static let lastWeekReview = "training.review.last_week_review"
            static let weekReview = "training.review.week_review"
            static let generateNextWeekPlan = "training.review.generate_next_week_plan"
            
            // Section titles
            static let trainingCompletion = "training.review.training_completion"
            static let trainingAnalysis = "training.review.training_analysis"
            static let nextWeekFocus = "training.review.next_week_focus"
            static let planAdjustmentSuggestions = "training.review.plan_adjustment_suggestions"
            
            // Performance subsections
            static let heartRatePerformance = "training.review.heart_rate_performance"
            static let pacePerformance = "training.review.pace_performance"
            static let distancePerformance = "training.review.distance_performance"
            
            // Training types
            static let intervalTraining = "training.review.interval_training"
            static let longRunTraining = "training.review.long_run_training"
            
            // Labels
            static let originalPlan = "training.review.original_plan"
            static let adjustedPlan = "training.review.adjusted_plan"
            static let average = "training.review.average"
            static let maximum = "training.review.maximum"
            static let totalDistance = "training.review.total_distance"
            static let trend = "training.review.trend"
            
            // Loading and error states
            static let analyzingData = "training.review.analyzing_data"
            static let loadingMessage = "training.review.loading_message"
            static let loadingError = "training.review.loading_error"
            static let retry = "training.review.retry"
        }
        
        // Training Plan Info Card
        static let planInfo = "training.plan_info"
        static let aiAnalysis = "training.ai_analysis"
        static let expand = "training.expand"
        static let collapse = "training.collapse"
        static let distance = "training.distance"
        static let pace = "training.pace"
        static let heartRateZone = "training.heart_rate_zone"
        static let trainingType = "training.training_type"
        
        enum TrainingType {
            static let easy = "training.type.easy"
            static let tempo = "training.type.tempo"
            static let interval = "training.type.interval"
            static let long = "training.type.long"
            static let recovery = "training.type.recovery"
            static let race = "training.type.race"
            static let fartlek = "training.type.fartlek"
            static let hill = "training.type.hill"
            static let speed = "training.type.speed"
            static let lsd = "training.type.lsd"
            static let threshold = "training.type.threshold"
            static let progression = "training.type.progression"
            static let combination = "training.type.combination"
            static let rest = "training.type.rest"
            static let crossTraining = "training.type.cross_training"
            static let hiking = "training.type.hiking"
            static let strength = "training.type.strength"
            static let yoga = "training.type.yoga"
            static let cycling = "training.type.cycling"
            static let restDay = "training.type.rest_day"
        }
        
        // Heart Rate Zones
        enum Zone {
            static let anaerobic = "training.zone.anaerobic"
            static let easy = "training.zone.easy"
            static let interval = "training.zone.interval"
            static let marathon = "training.zone.marathon"
            static let recovery = "training.zone.recovery"
            static let threshold = "training.zone.threshold"
        }
    }
    
    // MARK: - Workout Detail
    enum WorkoutDetail {
        // Upload Actions
        static let reupload = "workout.detail.reupload"
        static let reuploadAlert = "workout.detail.reupload_alert"
        static let cancel = "workout.detail.cancel"
        static let confirm = "workout.detail.confirm"
        static let confirmUpload = "workout.detail.confirm_upload"
        static let reuploadMessage = "workout.detail.reupload_message"
        static let reuploadResult = "workout.detail.reupload_result"
        static let insufficientHeartRate = "workout.detail.insufficient_heart_rate"
        static let stillUpload = "workout.detail.still_upload"
        static let insufficientHeartRateMessage = "workout.detail.insufficient_heart_rate_message"

        // Delete Actions
        static let deleteWorkout = "workout.detail.delete_workout"
        static let deleteConfirmTitle = "workout.detail.delete_confirm_title"
        static let deleteConfirmMessage = "workout.detail.delete_confirm_message"
        static let deleteSuccess = "workout.detail.delete_success"
        static let deleteFailed = "workout.detail.delete_failed"
        
        // Data Sections
        static let heartRateData = "workout.detail.heart_rate_data"
        static let noHeartRateData = "workout.detail.no_heart_rate_data"
        static let gaitAnalysis = "workout.detail.gait_analysis" 
        static let noGaitData = "workout.detail.no_gait_data"
        static let advancedMetrics = "workout.detail.advanced_metrics"
        static let heartRateZones = "workout.detail.heart_rate_zones"
        static let paceZones = "workout.detail.pace_zones"
        static let zoneDistribution = "workout.detail.zone_distribution"
        static let zoneType = "workout.detail.zone_type"
        
        // Metrics
        static let dynamicVdot = "workout.detail.dynamic_vdot"
        static let trainingLoad = "workout.detail.training_load"
        static let movementEfficiency = "workout.detail.movement_efficiency"
        
        // Heart Rate Zones
        static let recoveryZone = "workout.detail.recovery_zone"
        static let aerobicZone = "workout.detail.aerobic_zone"
        static let marathonZone = "workout.detail.marathon_zone"
        static let thresholdZone = "workout.detail.threshold_zone"
        static let intervalZone = "workout.detail.interval_zone"
        static let anaerobicZone = "workout.detail.anaerobic_zone"
        
        // Pace Zones
        static let recoveryPace = "workout.detail.recovery_pace"
        static let easyPace = "workout.detail.easy_pace"
        static let marathonPace = "workout.detail.marathon_pace"
        static let thresholdPace = "workout.detail.threshold_pace"
        static let intervalPace = "workout.detail.interval_pace"
        static let anaerobicPace = "workout.detail.anaerobic_pace"
        
        // Loading States
        static let loadingDetails = "workout.detail.loading_details"
        static let loadFailed = "workout.detail.load_failed"
        
        // Intensity Minutes
        static let low = "workout.detail.intensity_low"
        static let medium = "workout.detail.intensity_medium"
        static let high = "workout.detail.intensity_high"
        static let minutes = "workout.detail.minutes"
    }
    
    // MARK: - Workout Metrics
    enum WorkoutMetrics {
        static let distance = "workout.metrics.distance"
        static let time = "workout.metrics.time"
        static let calories = "workout.metrics.calories"
    }
    
    // MARK: - Activity Types
    enum ActivityType {
        static let running = "activity.type.running"
        static let cycling = "activity.type.cycling"
        static let swimming = "activity.type.swimming"
        static let walking = "activity.type.walking"
        static let hiking = "activity.type.hiking"
        static let strengthTraining = "activity.type.strength_training"
        static let yoga = "activity.type.yoga"
        static let pilates = "activity.type.pilates"
        static let other = "activity.type.other"
    }
    
    // MARK: - Training Record
    enum Record {
        static let title = "record.title"
        static let allWorkouts = "record.all_workouts"
        static let thisWeek = "record.this_week"
        static let thisMonth = "record.this_month"
        static let thisYear = "record.this_year"
        static let distance = "record.distance"
        static let duration = "record.duration"
        static let pace = "record.pace"
        static let heartRate = "record.heart_rate"
        static let calories = "record.calories"
        static let elevation = "record.elevation"
        static let cadence = "record.cadence"
        static let noRecords = "record.no_records"
        static let noRecordsDescription = "record.no_records_description"
        static let viewDetails = "record.view_details"
        
        // Device Info
        static let deviceInfoTitle = "record.device_info.title"
        static let deviceInfoDescription = "record.device_info.description"
        static let deviceInfoNativeSupport = "record.device_info.native_support"
        static let deviceInfoLimitations = "record.device_info.limitations"
        static let deviceInfoFutureSupport = "record.device_info.future_support"
    }
    
    // MARK: - Performance
    enum Performance {
        static let title = "performance.title"
        static let overview = "performance.overview"
        static let weeklyStats = "performance.weekly_stats"
        static let monthlyStats = "performance.monthly_stats"
        static let yearlyStats = "performance.yearly_stats"
        static let totalDistance = "performance.total_distance"
        static let totalTime = "performance.total_time"
        static let avgPace = "performance.avg_pace"
        static let avgHR = "performance.avg_hr"
        static let totalWorkouts = "performance.total_workouts"
        static let longestRun = "performance.longest_run"
        static let fastestPace = "performance.fastest_pace"
        static let progress = "performance.progress"
        
        // Achievement View specific
        static let vdotTrend = "performance.vdot_trend"
        static let vdotExplanation = "performance.vdot_explanation"
        
        enum TimeRange {
            static let week = "performance.time_range.week"
            static let month = "performance.time_range.month"
            static let threeMonths = "performance.time_range.three_months"
        }
        
        enum DataSource {
            static let serverError = "performance.data_source.server_error"
            static let noHealthData = "performance.data_source.no_health_data"
            static let loadDataError = "performance.data_source.load_data_error"
            static let loadHealthDataError = "performance.data_source.load_health_data_error"
        }
        
        enum Chart {
            static let date = "performance.chart.date"
            static let restingHeartRate = "performance.chart.resting_heart_rate"
            static let vdotValue = "performance.chart.vdot_value"
            static let loading = "performance.chart.loading"
        }
        
        enum VDOT {
            static let dynamicVdot = "performance.vdot.dynamic_vdot"
            static let weightedVdot = "performance.vdot.weighted_vdot"
            static let latestVdot = "performance.vdot.latest_vdot"
            static let vdotTitle = "performance.vdot.vdot_title"
            static let whatIsVdot = "performance.vdot.what_is_vdot"
            static let vdotDescription = "performance.vdot.vdot_description"
            static let setHeartRateZones = "performance.vdot.set_heart_rate_zones"
            static let calculatingVdot = "performance.vdot.calculating_vdot"
            static let averageWeightedVdot = "performance.vdot.average_weighted_vdot"
            static let latestDynamicVdot = "performance.vdot.latest_dynamic_vdot"
            static let heartRateZonePrompt = "performance.vdot.heart_rate_zone_prompt"
            static let noStatistics = "performance.vdot.no_statistics"
            static let dataPointCount = "performance.vdot.data_point_count"
            static let trend = "performance.vdot.trend"
        }
        
        enum HRV {
            static let loadingHrv = "performance.hrv.loading_hrv"
            static let noHrvData = "performance.hrv.no_hrv_data"
            static let hrvTitle = "performance.hrv.hrv_title"
            static let selectDataSourceHrv = "performance.hrv.select_data_source_hrv"
        }

        enum TrainingLoad {
            static let trainingLoadTitle = "performance.training_load.training_load_title"
            static let trainingLoadExplanation = "performance.training_load.training_load_explanation"
            static let fitnessIndex = "performance.training_load.fitness_index"
            static let fitnessIndexExplanation = "performance.training_load.fitness_index_explanation"
            static let tsb = "performance.training_load.tsb"
            static let tsbExplanation = "performance.training_load.tsb_explanation"
            static let insufficientData = "performance.training_load.insufficient_data"
            static let loadingTrainingLoad = "performance.training_load.loading_training_load"
            static let noTrainingLoadData = "performance.training_load.no_training_load_data"
            static let selectDataSourceTrainingLoad = "performance.training_load.select_data_source_training_load"
        }
        
        enum HeartRateZone {
            // Zone Names
            static let zone1Name = "performance.heart_rate_zone.zone1_name"
            static let zone2Name = "performance.heart_rate_zone.zone2_name" 
            static let zone3Name = "performance.heart_rate_zone.zone3_name"
            static let zone4Name = "performance.heart_rate_zone.zone4_name"
            static let zone5Name = "performance.heart_rate_zone.zone5_name"
            
            // Zone Descriptions
            static let zone1Description = "performance.heart_rate_zone.zone1_description"
            static let zone2Description = "performance.heart_rate_zone.zone2_description"
            static let zone3Description = "performance.heart_rate_zone.zone3_description" 
            static let zone4Description = "performance.heart_rate_zone.zone4_description"
            static let zone5Description = "performance.heart_rate_zone.zone5_description"
            
            // Zone Benefits
            static let zone1Benefit = "performance.heart_rate_zone.zone1_benefit"
            static let zone2Benefit = "performance.heart_rate_zone.zone2_benefit"
            static let zone3Benefit = "performance.heart_rate_zone.zone3_benefit"
            static let zone4Benefit = "performance.heart_rate_zone.zone4_benefit"
            static let zone5Benefit = "performance.heart_rate_zone.zone5_benefit"
        }
    }
    
    // MARK: - Settings
    enum Settings {
        static let title = "settings.title"
        static let general = "settings.general"
        static let notifications = "settings.notifications"
        static let privacy = "settings.privacy"
        static let about = "settings.about"
        static let language = "settings.language"
        static let timezone = "settings.timezone"
        static let units = "settings.units"
        static let metric = "settings.metric"
        static let imperial = "settings.imperial"
        static let theme = "settings.theme"
        static let light = "settings.light"
        static let dark = "settings.dark"
        static let auto = "settings.auto"
        static let deleteAccount = "settings.delete_account"
        static let deleteConfirm = "settings.delete_confirm"
        static let version = "settings.version"
        static let terms = "settings.terms"
        static let privacyPolicy = "settings.privacy_policy"
    }
    
    // MARK: - Language Settings
    enum Language {
        static let title = "language.title"
        static let zhTW = "language.zh-TW"
        static let enUS = "language.en-US"
        static let jaJP = "language.ja-JP"
        static let changeConfirm = "language.change_confirm"
        static let changed = "language.changed"
        static let restartMessage = "language.restart_message"
        static let syncMessage = "language.sync_message"
        static let metricOnlyMessage = "language.metric_only_message"
        static let restartRequiredMessage = "language.restart_required_message"
    }

    // MARK: - Timezone Settings
    enum Timezone {
        static let title = "timezone.title"
        static let current = "timezone.current"
        static let changeConfirm = "timezone.change_confirm"
        static let changeWarningMessage = "timezone.change_warning_message"
        static let detectingTimezone = "timezone.detecting_timezone"
        static let autoDetected = "timezone.auto_detected"
        static let selectTimezone = "timezone.select_timezone"
        static let commonTimezones = "timezone.common_timezones"
        static let syncMessage = "timezone.sync_message"
    }
    
    // MARK: - Errors
    enum Error {
        static let network = "error.network"
        static let server = "error.server"
        static let unknown = "error.unknown"
        static let invalidData = "error.invalid_data"
        static let authentication = "error.authentication"
        static let permissionDenied = "error.permission_denied"
        static let notFound = "error.not_found"
        static let timeout = "error.timeout"
        static let tryAgain = "error.try_again"
        static let healthPermission = "error.health_permission"
        static let calendarPermission = "error.calendar_permission"
        static let notificationPermission = "error.notification_permission"
    }
    
    // MARK: - Success Messages
    enum Success {
        static let saved = "success.saved"
        static let updated = "success.updated"
        static let deleted = "success.deleted"
        static let synced = "success.synced"
        static let planGenerated = "success.plan_generated"
        static let profileUpdated = "success.profile_updated"
        static let settingsSaved = "success.settings_saved"
    }
    
    // MARK: - Units
    enum Unit {
        static let km = "unit.km"
        static let mi = "unit.mi"
        static let m = "unit.m"
        static let ft = "unit.ft"
        static let minPerKm = "unit.min_per_km"
        static let minPerMi = "unit.min_per_mi"
        static let bpm = "unit.bpm"
        static let kcal = "unit.kcal"
        static let hours = "unit.hours"
        static let minutes = "unit.minutes"
        static let seconds = "unit.seconds"
        static let kg = "unit.kg"
        static let lbs = "unit.lbs"
        static let cm = "unit.cm"
        static let inch = "unit.inch"
    }
    
    // MARK: - Date & Time
    enum Date {
        static let today = "date.today"
        static let yesterday = "date.yesterday"
        static let tomorrow = "date.tomorrow"
        static let week = "date.week"
        static let month = "date.month"
        static let year = "date.year"
        static let monday = "date.monday"
        static let tuesday = "date.tuesday"
        static let wednesday = "date.wednesday"
        static let thursday = "date.thursday"
        static let friday = "date.friday"
        static let saturday = "date.saturday"
        static let sunday = "date.sunday"
        static let mon = "date.mon"
        static let tue = "date.tue"
        static let wed = "date.wed"
        static let thu = "date.thu"
        static let fri = "date.fri"
        static let sat = "date.sat"
        static let sun = "date.sun"
    }
    
    // MARK: - Heart Rate Zone
    enum HeartRateZone {
        static let settings = "hr_zone.settings"
        static let description = "hr_zone.description"
        static let currentSettings = "hr_zone.current_settings"
        static let maxHr = "hr_zone.max_hr"
        static let maxHrPlaceholder = "hr_zone.max_hr_placeholder"
        static let restingHr = "hr_zone.resting_hr"
        static let restingHrPlaceholder = "hr_zone.resting_hr_placeholder"
        static let preview = "hr_zone.preview"
        static let zone = "hr_zone.zone"
        static let saveSettings = "hr_zone.save_settings"
        static let info = "hr_zone.info"
        static let details = "hr_zone.details"
        static let loading = "hr_zone.loading"
        static let benefit = "hr_zone.benefit"
        static let maxHrInfoTitle = "hr_zone.max_hr_info_title"
        static let maxHrInfoMessage = "hr_zone.max_hr_info_message"
        static let restingHrInfoTitle = "hr_zone.resting_hr_info_title"
        static let restingHrInfoMessage = "hr_zone.resting_hr_info_message"
        static let invalidInput = "hr_zone.invalid_input"
        static let maxGreaterThanResting = "hr_zone.max_greater_than_resting"
        static let maxHrRange = "hr_zone.max_hr_range"
        static let restingHrRange = "hr_zone.resting_hr_range"
        static let saveFailed = "hr_zone.save_failed"
        static let understand = "hr_zone.understand"
        // Additional keys for HeartRateZoneInfoView
        static let maxHeartRateDisplay = "hr_zone.max_heart_rate_display"
        static let restingHeartRateDisplay = "hr_zone.resting_heart_rate_display"
    }

    // MARK: - Alerts & Confirmations
    enum Alert {
        static let unsavedChanges = "alert.unsaved_changes"
        static let discardChanges = "alert.discard_changes"
        static let keepEditing = "alert.keep_editing"
        static let discard = "alert.discard"
        static let deleteWorkout = "alert.delete_workout"
        static let deleteWorkoutConfirm = "alert.delete_workout_confirm"
        static let disconnectSource = "alert.disconnect_source"
        static let disconnectConfirm = "alert.disconnect_confirm"
    }
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Supported Languages
enum SupportedLanguage: String, CaseIterable {
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    
    var displayName: String {
        switch self {
        case .traditionalChinese:
            return L10n.Language.zhTW.localized
        case .english:
            return L10n.Language.enUS.localized
        case .japanese:
            return L10n.Language.jaJP.localized
        }
    }
    
    var apiCode: String {
        switch self {
        case .traditionalChinese:
            return "zh-TW"
        case .english:
            return "en-US"
        case .japanese:
            return "ja-JP"
        }
    }
    
    init?(apiCode: String) {
        switch apiCode {
        case "zh-TW", "zh", "zh-tw", "zh_tw":
            self = .traditionalChinese
        case "en-US", "en", "en-us", "en_us":
            self = .english
        case "ja-JP", "ja", "ja-jp", "ja_jp":
            self = .japanese
        default:
            return nil
        }
    }
    
    static var current: SupportedLanguage {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "zh-Hant"
        return SupportedLanguage(rawValue: preferredLanguage) ?? .traditionalChinese
    }
}

// MARK: - Feedback

extension L10n {
    enum Feedback {
        static let title = "feedback.title"
        static let type = "feedback.type"
        static let category = "feedback.category"
        static let description = "feedback.description"
        static let descriptionHint = "feedback.description_hint"
        static let contactEmail = "feedback.contact_email"
        static let contactEmailHint = "feedback.contact_email_hint"
        static let contactEmailPlaceholder = "feedback.contact_email_placeholder"
        static let attachments = "feedback.attachments"
        static let attachmentsHint = "feedback.attachments_hint"
        static let addImage = "feedback.add_image"
        static let systemInfo = "feedback.system_info"
        static let userEmail = "feedback.user_email"
        static let appVersion = "feedback.app_version"
        static let deviceInfo = "feedback.device_info"
        static let successTitle = "feedback.success_title"
        static let successMessage = "feedback.success_message"

        enum FeedbackType {
            static let issue = "feedback.type.issue"
            static let suggestion = "feedback.type.suggestion"
        }

        enum Category {
            static let uncategorized = "feedback.category.uncategorized"
            static let weeklyPlanFailed = "feedback.category.weekly_plan_failed"
            static let weeklySummaryFailed = "feedback.category.weekly_summary_failed"
            static let trainingOverviewFailed = "feedback.category.training_overview_failed"
            static let other = "feedback.category.other"
        }

        enum Error {
            static let descriptionRequired = "feedback.error.description_required"
        }
    }

    // MARK: - Content View
    enum ContentView {
        static let dataSourceRequired = "content_view.data_source_required" // "需要綁定數據源"
        static let goToSettings = "content_view.go_to_settings" // "前往設定"
        static let later = "content_view.later" // "稍後"
        static let dataSourceRequiredMessage = "content_view.data_source_required_message" // "您尚未綁定數據源，請前往個人資料頁面選擇 Apple Health、Garmin Connect 或 Strava 作為您的訓練數據來源。"
    }

    // MARK: - Profile View
    enum ProfileView {
        static let appleUser = "profile_view.apple_user" // "Apple User"
        static let garminAlreadyBound = "profile_view.garmin_already_bound" // "Garmin Connect™ Account Already Bound"
        static let stravaAlreadyBound = "profile_view.strava_already_bound" // "Strava Account Already Bound"
        static let ok = "profile_view.ok" // "OK"
        static let garminAlreadyBoundMessage = "profile_view.garmin_already_bound_message"
        static let stravaAlreadyBoundMessage = "profile_view.strava_already_bound_message"

        // Developer Section
        enum Developer {
            static let sectionTitle = "profile_view.developer.section_title" // "🧪 開發者測試"
            static let testRating = "profile_view.developer.test_rating" // "測試評分提示"
            static let clearRatingCache = "profile_view.developer.clear_rating_cache" // "清除評分快取"
            static let debugFailedWorkouts = "profile_view.developer.debug_failed_workouts" // "調試 - 失敗運動記錄"
            static let printHeartRate = "profile_view.developer.print_heart_rate" // "打印心率設定狀態"
            static let clearHeartRate = "profile_view.developer.clear_heart_rate" // "清除所有心率設定"
            static let simulateRemindTomorrow = "profile_view.developer.simulate_remind_tomorrow" // "模擬「明天再提醒」(1分鐘後過期)"
        }
    }

    // MARK: - Edit Schedule
    enum EditSchedule {
        // General
        static let cancel = "edit_schedule.cancel" // "取消"
        static let save = "edit_schedule.save" // "儲存"
        static let confirm = "edit_schedule.confirm" // "確定"
        static let apply = "edit_schedule.apply" // "套用"
        static let delete = "edit_schedule.delete" // "刪除"
        static let close = "edit_schedule.close" // "關閉"
        static let cannotEdit = "edit_schedule.cannot_edit" // "無法編輯"
        static let addSegment = "edit_schedule.add_segment" // "新增區段"

        // Training Types
        static let easyRun = "edit_schedule.easy_run" // "輕鬆跑"
        static let tempoRun = "edit_schedule.tempo_run" // "節奏跑"
        static let intervalTraining = "edit_schedule.interval_training" // "間歇訓練"
        static let combinationRun = "edit_schedule.combination_run" // "組合訓練"
        static let longDistanceRun = "edit_schedule.long_distance_run" // "長距離跑"
        static let longEasyRun = "edit_schedule.long_easy_run" // "長距離輕鬆跑"
        static let recoveryRun = "edit_schedule.recovery_run" // "恢復跑"
        static let thresholdRun = "edit_schedule.threshold_run" // "閾值跑"
        static let rest = "edit_schedule.rest" // "休息"

        // Training Detail Editor
        static let easyRunSettings = "edit_schedule.easy_run_settings" // "輕鬆跑設定"
        static let tempoRunSettings = "edit_schedule.tempo_run_settings" // "節奏跑設定"
        static let intervalSettings = "edit_schedule.interval_settings" // "間歇訓練設定"
        static let combinationSettings = "edit_schedule.combination_settings" // "組合跑設定"
        static let longRunSettings = "edit_schedule.long_run_settings" // "長距離跑設定"
        static let trainingSettings = "edit_schedule.training_settings" // "訓練設定"

        static let suggestedPace = "edit_schedule.suggested_pace" // "建議配速: %@"
        static let sprintSuggestedPace = "edit_schedule.sprint_suggested_pace" // "衝刺段建議配速: %@"
        static let paceRange = "edit_schedule.pace_range" // "配速區間: %@ - %@"
        static let intervalPaceRange = "edit_schedule.interval_pace_range" // "間歇配速區間: %@ - %@"

        static let distance = "edit_schedule.distance" // "距離 (公里)"
        static let distancePlaceholder = "edit_schedule.distance_placeholder" // "例如: 5.0"
        static let pace = "edit_schedule.pace" // "配速 (分:秒/公里)"
        static let pacePlaceholder = "edit_schedule.pace_placeholder" // "例如: 4:30"
        static let description = "edit_schedule.description" // "訓練說明"
        static let segmentDescription = "edit_schedule.segment_description" // "區段描述"

        static let repeats = "edit_schedule.repeats" // "重複次數"
        static let repeatsPlaceholder = "edit_schedule.repeats_placeholder" // "例如: 6"
        static let sprintSegment = "edit_schedule.sprint_segment" // "衝刺段"
        static let recoverySegment = "edit_schedule.recovery_segment" // "恢復段"
        static let segment = "edit_schedule.segment" // "區段 %d"

        // Pace Selection
        static let selectPace = "edit_schedule.select_pace" // "選擇配速"
        static let paceSelection = "edit_schedule.pace_selection" // "配速選擇"
        static let selectIntervalDistance = "edit_schedule.select_interval_distance" // "選擇間歇距離"
        static let intervalDistanceSelection = "edit_schedule.interval_distance_selection" // "間歇距離選擇"
        static let selectTrainingType = "edit_schedule.select_training_type" // "選擇訓練類型"
        static let trainingTypeSelection = "edit_schedule.training_type_selection" // "訓練類型選擇"

        // Pace Table
        static let paceTableDescription = "edit_schedule.pace_table_description" // "根據您的跑力計算的訓練配速建議，每個區間顯示最快配速 - 最慢配速範圍"
        static let paceZoneDetails = "edit_schedule.pace_zone_details" // "配速區間詳情"
        static let referencePaceTable = "edit_schedule.reference_pace_table" // "參考配速表"
    }

    // MARK: - Training Readiness
    enum TrainingReadiness {
        static let trainingMetrics = "training_readiness.training_metrics" // "訓練指標"
        static let metricsExplanation = "training_readiness.metrics_explanation" // "訓練指標說明"
        static let metricsSubtitle = "training_readiness.metrics_subtitle" // "了解每個指標的含義，學習如何提升分數"
        static let quickTips = "training_readiness.quick_tips" // "快速建議"
        static let done = "training_readiness.done" // "完成"
        static let whatItMeans = "training_readiness.what_it_means" // "這個指標代表什麼"
        static let howToImprove = "training_readiness.how_to_improve" // "如何提升分數"
        static let whenItDecreases = "training_readiness.when_it_decreases" // "分數何時下降"

        enum Tips {
            static let tip1 = "training_readiness.tips.tip1" // "每週包含：3-4 次輕鬆跑 + 1 次速度課表 + 1-2 次長跑"
            static let tip2 = "training_readiness.tips.tip2" // "保持訓練頻率，比偶爾的高強度訓練更重要"
            static let tip3 = "training_readiness.tips.tip3" // "關注分數趨勢，不要糾結每日波動"
            static let tip4 = "training_readiness.tips.tip4" // "如果訓練負荷分數很低，需要安排恢復時間"
        }
    }

    // MARK: - My Achievement View
    enum MyAchievement {
        static let fitnessAndTSB = "my_achievement.fitness_and_tsb" // "體適能指數 & 訓練壓力平衡"
        static let syncing = "my_achievement.syncing" // "同步中..."
        static let tsbStatus = "my_achievement.tsb_status" // "TSB 狀態指標"
        static let fatigue = "my_achievement.fatigue" // "疲勞累積"
        static let balanced = "my_achievement.balanced" // "平衡狀態"
        static let optimal = "my_achievement.optimal" // "最佳狀態"
        static let markerExplanation = "my_achievement.marker_explanation" // "標記說明"
        static let hasTraining = "my_achievement.has_training" // "有訓練"
        static let restDay = "my_achievement.rest_day" // "休息日"
        static let reasonableTrainingLoad = "my_achievement.reasonable_training_load" // "合理訓練負荷區域"

        // Training Load Detail
        static let trainingLoadDetail = "my_achievement.training_load_detail" // "訓練負荷詳細說明"
        static let trainingLoadSubtitle = "my_achievement.training_load_subtitle" // "了解您的體適能指數和訓練壓力平衡，幫助您優化訓練計劃"
        static let fitnessIndex = "my_achievement.fitness_index" // "體適能指數 (Fitness Index)"
        static let fitnessIndexDescription = "my_achievement.fitness_index_description" // "體適能指數反映您**相對於自己過往表現**的運動能力水平。這個數值會根據您最近的訓練強度、頻率和持續時間動態調整，重點在於觀察**趨勢變化**。"
        static let howToInterpret = "my_achievement.how_to_interpret" // "如何解讀趨勢："
        static let keyPoint = "my_achievement.key_point" // "💡 重點：關注線條的**走向**比單一數值更重要"
        static let tsb = "my_achievement.tsb" // "訓練壓力平衡 (TSB)"
        static let tsbDescription = "my_achievement.tsb_description" // "TSB 反映您當前的訓練疲勞與恢復狀態之間的平衡。這個指標幫助您了解何時需要休息，何時可以增加訓練強度。"
        static let tsbInterpretation = "my_achievement.tsb_interpretation" // "TSB 狀態解讀："
        static let chartGuide = "my_achievement.chart_guide" // "圖表解讀指南"
        static let dotExplanation = "my_achievement.dot_explanation" // "圓點標記說明"
        static let solidDot = "my_achievement.solid_dot" // "實心圓點：有訓練的日子"
        static let hollowDot = "my_achievement.hollow_dot" // "空心圓點：當日無訓練"
        static let practicalTips = "my_achievement.practical_tips" // "實用建議"
        static let importantReminder = "my_achievement.important_reminder" // "重要提醒"
        static let reminder1 = "my_achievement.reminder1" // "• 訓練負荷數據需要至少 2-3 週的運動記錄才能提供準確的趨勢分析"
        static let reminder2 = "my_achievement.reminder2" // "• 體適能指數下降不一定是壞事，可能代表正在進行有計畫的減量或恢復期"
        static let reminder3 = "my_achievement.reminder3" // "• 建議同時觀察 TSB 和 HRV 趨勢，綜合判斷身體的恢復狀態"
        static let reminder4 = "my_achievement.reminder4" // "• 如有身體不適，請優先考慮休息，數據僅供參考不可完全依賴"
        static let complete = "my_achievement.complete" // "完成"
    }

    // MARK: - Debug Tools (Optional - Low Priority)
    #if DEBUG
    enum Debug {
        static let confirmDelete = "debug.confirm_delete" // "確定要刪除測試數據嗎？"
        static let deleteByTimeRange = "debug.delete_by_time_range" // "根據時間範圍刪除"
        static let deleteMarkedOnly = "debug.delete_marked_only" // "只刪除已標記測試記錄"
        static let deleteAll = "debug.delete_all" // "刪除所有數據"
        static let selectDeleteMethod = "debug.select_delete_method" // "選擇刪除方式。時間範圍刪除可以刪除指定時間內的所有健身記錄。"
        static let syncStatus = "debug.sync_status" // "同步狀態"
        static let refreshStatus = "debug.refresh_status" // "重新整理狀態"
        static let testFeatures = "debug.test_features" // "測試功能"
        static let createTestWorkout = "debug.create_test_workout" // "創建測試健身記錄"
        static let manualCheckUpload = "debug.manual_check_upload" // "手動檢查並上傳"
        static let testNotification = "debug.test_notification" // "測試通知"
        static let clearUploadHistory = "debug.clear_upload_history" // "清除上傳歷史"
        static let testDataManagement = "debug.test_data_management" // "測試數據管理"
        static let deleteTestData = "debug.delete_test_data" // "刪除測試數據"
        static let findWorkouts = "debug.find_workouts" // "查找健身記錄"
        static let deleteWarning = "debug.delete_warning" // "刪除功能會移除 HealthKit 中的健身記錄。請謹慎操作，刪除後無法恢復。"
        static let healthKitObserver = "debug.health_kit_observer" // "HealthKit 觀察者設置"
        static let testObserver = "debug.test_observer" // "測試觀察者設置"
        static let operationLog = "debug.operation_log" // "操作日誌"
        static let selectTimeRange = "debug.select_time_range" // "選擇時間範圍"
        static let foundWorkouts = "debug.found_workouts" // "找到的健身記錄"
        static let deleteAllRecords = "debug.delete_all_records" // "刪除所有記錄 (%d)"
        static let deleteWarningMessage = "debug.delete_warning_message" // "警告：此操作將從您的健康數據中永久刪除這些健身記錄"
        static let confirmDeleteTitle = "debug.confirm_delete_title" // "確定刪除"
        static let confirmDeleteMessage = "debug.confirm_delete_message" // "這將從您的 HealthKit 數據中永久刪除 %d 條健身記錄。此操作無法撤銷。"
        static let createdTestWorkout = "debug.created_test_workout" // "已創建測試健身記錄 ID: %@"
    }
    #endif

    // MARK: - Share Card
    enum ShareCard {
        static let generateShareCard = "share_card.generate" // "生成分享卡"
        static let choosePhoto = "share_card.choose_photo" // "選擇照片"
    }

    // MARK: - Onboarding Additional
    enum OnboardingAdditional {
        static let trainingPlanPreview = "onboarding.training_plan_preview" // "您的訓練計畫預覽"
        static let goalAssessment = "onboarding.goal_assessment" // "目標評估"
        static let trainingFocus = "onboarding.training_focus" // "訓練重點"
    }

    // MARK: - Miscellaneous
    enum Misc {
        static let loading = "misc.loading" // "載入中..."
        static let retry = "misc.retry" // "重試"
        static let back = "misc.back" // "返回"
        static let backToThisWeek = "misc.back_to_this_week" // "返回本週"
        static let segment = "misc.segment" // "第%d段"
        static let times = "misc.times" // "× %d"
        static let noEnoughData = "misc.no_enough_data" // "沒有足夠的訓練資料"
        static let recentThreeMonthsPerformance = "misc.recent_three_months_performance" // "近三個月訓練表現"
        static let trainingDay = "misc.training_day" // "訓練日"
        static let mainContent = "misc.main_content" // "主要內容"
        static let diagHRVIssue = "misc.diag_hrv_issue" // "診斷 HRV 問題"
        static let stravaAccountBound = "misc.strava_account_bound" // "Strava Account Already Bound"
    }
}