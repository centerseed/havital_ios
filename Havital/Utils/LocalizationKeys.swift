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