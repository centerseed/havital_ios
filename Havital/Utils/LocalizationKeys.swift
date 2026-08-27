import Foundation

/// Type-safe localization keys for Havital app
enum L10n {
    
    // MARK: - Main Navigation
    enum Tab {
        static let trainingPlan = "tab.training_plan"
        static let trainingRecord = "tab.training_record"
        static let performanceData = "tab.performance_data"
        static let achievement = "tab.achievement"
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
        static let time = "common.time"
        static let pace = "common.pace"
        static let date = "common.date"
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
        static let ok = "common.ok" // "OK"
        static let error = "common.error" // "Error"
        static let generating = "common.generating" // "Generating..."
        static let initializing = "common.initializing" // "Initializing..."
        static let submit = "common.submit" // "Submit"
        static let later = "common.later" // "Later"
        static let reload = "common.reload" // "Reload"
        static let add = "common.add" // "Add"
        static let reset = "common.reset" // "Reset"
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

    // MARK: - Login
    enum Login {
        static let language = "login.language"
        static let languagePickerAccessibility = "login.language_picker_accessibility"
    }

    enum ForceUpdate {
        static let title = "force_update.title"
        static let message = "force_update.message"
        static let cta = "force_update.cta"
    }

    enum MessageCenter {
        static let empty = "message_center.empty"
        static let title = "message_center.title"
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
        static let browseDatabase = "edit_target.browse_database" // "從賽事資料庫選擇"
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
        static let syncFailed = "datasource.sync_failed"
        static let syncing = "datasource.syncing"
    }



    // MARK: - Workout
    enum Workout {
        static let details = "workout.details" // "訓練詳情"
        static let shareCard = "workout.share_card" // "分享訓練成果"
        static let shareScreenshot = "workout.share_screenshot" // "分享截圖"
        static let startTime = "workout.start_time" // "開始時間"
        static let reuploadSuccess = "workout.reupload_success" // "訓練已成功重新上傳！"
        static let uploadSuccessInsufficientHr = "workout.upload_success_insufficient_hr" // "訓練已上傳但心率資料不足。"
        static let reuploadError = "workout.reupload_error" // "重新上傳時發生錯誤："
        static let reuploadFailed = "workout.reupload_failed" // "重新上傳失敗，請稍後再試。"
        static let provider = "workout.provider" // "來源"
        static let activityType = "workout.activity_type" // "活動類型"
        static let resyncData = "workout.resync_data" // "重新同步資料"
        static let forceReuploadDescription = "workout.force_reupload_description" // "強制重新上傳這筆訓練紀錄，包含重新嘗試抓取心率資料"
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
        
        static let progress = "training.progress" // "訓練進度"
        static let currentProgress = "training.current_progress" // "目前進度"
        static let currentWeekOfTotal = "training.current_week_of_total" // "第 %d 週 / 總共 %d 週"
        static let currentStage = "training.current_stage" // "目前階段：%@"
        static let weekRange = "training.week_range" // "第 %d-%d 週"
        static let cannotGetProgress = "training.cannot_get_progress" // "無法取得目前訓練進度"
        static let targetRace = "training.target_race" // "目標賽事"
        static let raceAssessment = "training.race_assessment" // "賽事評估"
        static let trainingStages = "training.training_stages" // "訓練階段"
        static let cannotGetStages = "training.cannot_get_stages" // "無法取得訓練階段資訊"
        static let weekNumber = "training.week_number" // "第 %d 週"
        static let weekProgressFormat = "training.week_progress_format" // "%d / %d weeks"
        static let getWeeklyReview = "training.get_weekly_review" // "取得週回顧"
        static let paceZone = "training.pace_zone" // "配速區間"
        static let heartRateZone = "training.heart_rate_zone" // "心率區間"
        static let phasesCount = "training.phases_count" // "%d phases"
        static let intensityLowShort = "training.intensity.low_short" // "Low %d%%"
        static let intensityMediumShort = "training.intensity.medium_short" // "Medium %d%%"
        static let intensityHighShort = "training.intensity.high_short" // "High %d%%"
        
        // Loading Animation Messages
        enum LoadingAnimation {
            // Generate Plan Messages
            static let analyzingFitness = "training.loading.analyzing_fitness"
            static let planningIntensity = "training.loading.planning_intensity"
            static let preparingCustomPlan = "training.loading.preparing_custom_plan"

            // Pipeline Narrative keys (Feature 1)
            static let pipelineStep1WithData     = "training.loading.pipeline_step1_with_data"
            static let pipelineStep1VdotOnly     = "training.loading.pipeline_step1_vdot_only"
            static let pipelineStep1Fallback     = "training.loading.pipeline_step1_fallback"
            static let pipelineStep2WithData     = "training.loading.pipeline_step2_with_data"
            static let pipelineStep2Fallback     = "training.loading.pipeline_step2_fallback"
            static let pipelineStep3WithWeek     = "training.loading.pipeline_step3_with_week"
            static let pipelineStep3Fallback     = "training.loading.pipeline_step3_fallback"

            // Generate Review Messages
            static let analyzingTrainingData = "training.loading.analyzing_training_data"
            static let evaluatingProgress = "training.loading.evaluating_progress"
            static let preparingReview = "training.loading.preparing_review"
        }

        enum Stage {
            static let base       = "training.stage.base"
            static let build      = "training.stage.build"
            static let peak       = "training.stage.peak"
            static let taper      = "training.stage.taper"
            static let conversion = "training.stage.conversion"
            static let unknown    = "training.stage.unknown"
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
        static let trainingType = "training.training_type"

        // TrainingOverviewV2View — Hero + Stats card
        static let targetTime = "training.target_time"          // "目標時間"
        static let targetPace = "training.target_pace"          // "目標配速"
        static let overview = "training.overview"               // "訓練總覽"
        static let overviewEditAction = "training.overview.edit"             // "編輯"
        static let overviewDaysUnit = "training.overview.days_unit"          // "天"
        static let overviewPhaseWeekChip = "training.overview.phase_week_chip" // "%@ · 第 %d / %d 週"
        static let overviewBeginnerSubtitle = "training.overview.beginner_subtitle"     // "從零開始，建立穩定跑步基礎"
        static let overviewMaintenanceSubtitle = "training.overview.maintenance_subtitle" // "保持訓練節奏，維持體能狀態"

        // TrainingOverviewV2View — Task 3: MethodologyStrategyCard + MilestonesCard (reuse existing keys)
        static let overviewKeyMilestones = "training.overview.key_milestones"   // new "關鍵里程碑" (JSX-aligned)
        static let overviewChangeMethodology = "training.change_methodology"    // reuse existing "更換方法論"
        static let overviewIntensityDistribution = "training.intensity_distribution" // reuse existing "強度分配"
        static let overviewMilestoneDisclaimer = "training.milestone_disclaimer"     // reuse existing disclaimer
        static let overviewSelectMethodology = "training.select_methodology"         // reuse existing "選擇方法論"
        static let overviewUpdatingPlan = "training.updating_overview"               // reuse existing "正在更新訓練計畫..."

        // TrainingProgressViewV2 / PhaseRoadmapView shared keys
        static let currentWeekLabel = "training.current_week_label"    // "本週"
        static let recoveryWeek = "training.recovery_week"             // "恢復週"
        static let workoutTypeLongRun = "training.workout_type.long_run"  // "長距離"
        static let qualitySession = "training.quality_session"         // "品質課"

        enum TrainingType {
            static let easy = "training.type.easy"
            static let tempo = "training.type.tempo"
            static let interval = "training.type.interval"
            static let long = "training.type.long"
            static let recovery = "training.type.recovery"
            static let race = "training.type.race"
            static let benchmark = "training.type.benchmark"
            static let fartlek = "training.type.fartlek"
            static let hill = "training.type.hill"
            static let speed = "training.type.speed"
            static let lsd = "training.type.lsd"
            static let threshold = "training.type.threshold"
            static let progression = "training.type.progression"
            static let combination = "training.type.combination"
            static let steadyIntervals = "training.type.steady_intervals"
            static let rest = "training.type.rest"
            static let crossTraining = "training.type.cross_training"
            static let hiking = "training.type.hiking"
            static let strength = "training.type.strength"
            static let yoga = "training.type.yoga"
            static let cycling = "training.type.cycling"
            static let restDay = "training.type.rest_day"
            // 新增間歇訓練類型
            static let strides = "training.type.strides"
            static let hillRepeats = "training.type.hill_repeats"
            static let cruiseIntervals = "training.type.cruise_intervals"
            static let shortInterval = "training.type.short_interval"
            static let longInterval = "training.type.long_interval"
            static let norwegian4x4 = "training.type.norwegian_4x4"
            static let norwegianSingles = "training.type.norwegian_singles"
            static let yasso800 = "training.type.yasso_800"
            // 新增組合訓練類型
            static let fastFinish = "training.type.fast_finish"
            // 新增比賽配速訓練
            static let racePace = "training.type.race_pace"
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

        // Daniels Pace Zones (顯示用，帶配速等級代碼如 [R] [T])
        enum PaceZone {
            static let recovery = "training.pace_zone.recovery"
            static let easy = "training.pace_zone.easy"
            static let tempo = "training.pace_zone.tempo"
            static let marathon = "training.pace_zone.marathon"
            static let threshold = "training.pace_zone.threshold"
            static let anaerobic = "training.pace_zone.anaerobic"
            static let interval = "training.pace_zone.interval"
        }

        // 分段課表單位（如 "3 段"）
        static let segmentsUnit = "training.segments_unit"
    }
    
    // MARK: - Phase Roadmap (Task 2/5 — PhaseRoadmapView)
    enum PhaseRoadmap {
        static let title = "phase_roadmap.title"                       // "計畫路線"
        static let subtitle = "phase_roadmap.subtitle"                 // "%d 個階段 · %d 週"
        static let subtitleRaceCount = "phase_roadmap.subtitle_race_count" // "%d 場比賽"
        static let addRace = "phase_roadmap.add_race"                  // "加賽事"
        static let inProgressBadge = "phase_roadmap.in_progress_badge" // "進行中 · 第 %d / %d 週"
        static let completedBadge = "phase_roadmap.completed_badge"    // "✓ 已完成"
        static let focusLabel = "phase_roadmap.focus_label"            // "重點"
        static let showAllWeeks = "phase_roadmap.show_all_weeks"       // "顯示全部 %d 週 · 還有 %d 週"
        static let collapseWeeks = "phase_roadmap.collapse_weeks"      // "收起 · 只看本週附近"
        static let raceBadge = "phase_roadmap.race_badge"              // "賽"
        static let mainRaceLabel = "phase_roadmap.main_race_label"     // "主賽事"
        static let targetTimePrefix = "phase_roadmap.target_time_prefix" // "目標 "
    }

    // MARK: - Weekly Mileage Chart (WeeklyMileageChartView)
    enum MileageChart {
        static let title = "mileage_chart.title"                         // "週跑量曲線"
        static let subtitle = "mileage_chart.subtitle"                   // "%d 週 · 單位 %@"
        static let axisWeek = "mileage_chart.axis_week"                  // "週"
        static let legendWeekly = "mileage_chart.legend_weekly"          // "每週跑量"
        static let legendLongRun = "mileage_chart.legend_long_run"       // "長跑"
        static let legendRaceThreshold = "mileage_chart.legend_race_threshold"   // "門檻"
        static let legendSafetyCeiling = "mileage_chart.legend_safety_ceiling"   // "上限"
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
        static let effortScore = "workout.effort_score"  // iOS 18+ Effort Score
        static let addRPE = "workout.detail.add_rpe"
        static let clearRPE = "workout.detail.clear_rpe"
        static let rpeEditorTitle = "workout.detail.rpe_editor_title"
        static let rpeDescription = "workout.detail.rpe_description"
        static let rpePickerTitle = "workout.detail.rpe_picker_title"
        static let rpeSelectedFormat = "workout.detail.rpe_selected_format"
        static let rpeScaleTitle = "workout.detail.rpe_scale_title"
        static let rpeScaleLow = "workout.detail.rpe_scale_low"
        static let rpeScaleMedium = "workout.detail.rpe_scale_medium"
        static let rpeScaleHigh = "workout.detail.rpe_scale_high"
        static let rpeSelectedLow = "workout.detail.rpe_selected_low"
        static let rpeSelectedMedium = "workout.detail.rpe_selected_medium"
        static let rpeSelectedHigh = "workout.detail.rpe_selected_high"
        static let rpeSaveError = "workout.detail.rpe_save_error"
        
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

        // Training Notes
        static let trainingNotesTitle = "workout.detail.training_notes_title"
        static let trainingNotesAdd = "workout.detail.training_notes_add"
        static let trainingNotesEdit = "workout.detail.training_notes_edit"
        static let trainingNotesSave = "workout.detail.training_notes_save"
        static let trainingNotesCancel = "workout.detail.training_notes_cancel"
        static let trainingNotesSaving = "workout.detail.training_notes_saving"
        static let trainingNotesPlaceholder = "workout.detail.training_notes_placeholder"
        static let trainingNotesSaveError = "workout.detail.training_notes_save_error"
        static let trainingNotesEditorTitle = "workout.detail.training_notes_editor_title"

        // Treadmill Correction
        static let treadmillCorrectionTitle = "workout.detail.treadmill_correction_title"
        static let treadmillCorrectionDescription = "workout.detail.treadmill_correction_description"
        static let treadmillCorrectionActualDistance = "workout.detail.treadmill_correction_actual_distance"
        static let treadmillCorrectionIncline = "workout.detail.treadmill_correction_incline"
        static let treadmillCorrectionNotes = "workout.detail.treadmill_correction_notes"
        static let treadmillCorrectionApply = "workout.detail.treadmill_correction_apply"
        static let treadmillCorrectionApplied = "workout.detail.treadmill_correction_applied"
        static let treadmillCorrectionAppliedDistance = "workout.detail.treadmill_correction_applied_distance"
        static let treadmillCorrectionModify = "workout.detail.treadmill_correction_modify"
        static let treadmillCorrectionSuccess = "workout.detail.treadmill_correction_success"
        static let treadmillCorrectionError = "workout.detail.treadmill_correction_error"
        static let treadmillCorrectionDistanceError = "workout.detail.treadmill_correction_distance_error"
        static let treadmillCorrectionInclineError = "workout.detail.treadmill_correction_incline_error"
        static let treadmillCorrectionNotesError = "workout.detail.treadmill_correction_notes_error"
        static let treadmillCorrectionDistancePlaceholder = "workout.detail.treadmill_correction_distance_placeholder"
        static let treadmillCorrectionInclinePlaceholder = "workout.detail.treadmill_correction_incline_placeholder"
        static let treadmillCorrectionNotesPlaceholder = "workout.detail.treadmill_correction_notes_placeholder"

        // Trim (運動紀錄裁剪)
        static let trimTitle = "workout.detail.trim_title"
        static let trimDescription = "workout.detail.trim_description"
        static let trimKeepStart = "workout.detail.trim_keep_start"
        static let trimKeepEnd = "workout.detail.trim_keep_end"
        static let trimKeepDuration = "workout.detail.trim_keep_duration"
        static let trimApply = "workout.detail.trim_apply"
        static let trimModify = "workout.detail.trim_modify"
        static let trimApplied = "workout.detail.trim_applied"
        static let trimSuccess = "workout.detail.trim_success"
        static let trimError = "workout.detail.trim_error"
        static let trimCannotTrimError = "workout.detail.trim_cannot_trim_error"
        static let trimWindowTooShortError = "workout.detail.trim_window_too_short_error"
        static let trimAlreadyTrimmedHint = "workout.detail.trim_already_trimmed_hint"
    }

    enum LowData {
        static let vdotHint = "low_data.vdot_hint"
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
        static let basketball = "activity.type.basketball"
        static let soccer = "activity.type.soccer"
        static let tennis = "activity.type.tennis"
        static let volleyball = "activity.type.volleyball"
        static let golf = "activity.type.golf"
        static let strengthTraining = "activity.type.strength_training"
        static let yoga = "activity.type.yoga"
        static let training = "activity.type.training"
        static let fitnessEquipment = "activity.type.fitness_equipment"
        static let pilates = "activity.type.pilates"
        static let elliptical = "activity.type.elliptical"
        static let rowing = "activity.type.rowing"
        static let kayaking = "activity.type.kayaking"
        static let surfing = "activity.type.surfing"
        static let diving = "activity.type.diving"
        static let skiing = "activity.type.skiing"
        static let snowboarding = "activity.type.snowboarding"
        static let iceSkating = "activity.type.ice_skating"
        static let boxing = "activity.type.boxing"
        static let mixedMartialArts = "activity.type.mixed_martial_arts"
        static let mountaineering = "activity.type.mountaineering"
        static let rockClimbing = "activity.type.rock_climbing"
        static let dance = "activity.type.dance"
        static let meditation = "activity.type.meditation"
        static let americanFootball = "activity.type.american_football"
        static let baseball = "activity.type.baseball"
        static let cricket = "activity.type.cricket"
        static let rugby = "activity.type.rugby"
        static let hockey = "activity.type.hockey"
        static let lacrosse = "activity.type.lacrosse"
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
        static let avgHeartRate = "record.avg_heart_rate"
        static let maxHeartRate = "record.max_heart_rate"
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

        // Filter chips
        enum Filter {
            static let all = "record.filter.all" // "全部"
            static let easyRun = "record.filter.easy_run" // "輕鬆跑"
            static let tempo = "record.filter.tempo" // "節奏跑"
            static let interval = "record.filter.interval" // "間歇"
            static let longRun = "record.filter.long_run" // "長距離"
        }

        // Group headers
        enum Group {
            static let today = "record.group.today" // "今天"
            static let yesterday = "record.group.yesterday" // "昨天"
            static let earlierThisWeek = "record.group.earlier_this_week" // "本週稍早"
            static let lastWeek = "record.group.last_week" // "上週"
            static let older = "record.group.older" // "更早"
            static let runCountFormat = "record.group.run_count_format" // "%d 次跑步"
            static let totalKmFormat = "record.group.total_km_format" // "共 %.1f km"
            static let monthGroupFormat = "record.group.month_group_format" // "%d年%d月"
        }
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
        static let unknownWorkout = "performance.unknown_workout"
        static let performanceIndexFormat = "performance.performance_index_format"
        static let gaitMetricPicker = "performance.gait_metric_picker"
        static let heatAdaptation = "performance.heat_adaptation"
        
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
            static let readMore = "performance.vdot.read_more"
            static let blogUrl = "performance.vdot.blog_url"
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
            static let fitnessIndexShort = "performance.training_load.fitness_index_short"
            static let fitnessIndexExplanation = "performance.training_load.fitness_index_explanation"
            static let tsb = "performance.training_load.tsb"
            static let tsbShort = "performance.training_load.tsb_short"
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
            static let zone6Name = "performance.heart_rate_zone.zone6_name"

            // Zone Descriptions
            static let zone1Description = "performance.heart_rate_zone.zone1_description"
            static let zone2Description = "performance.heart_rate_zone.zone2_description"
            static let zone3Description = "performance.heart_rate_zone.zone3_description"
            static let zone4Description = "performance.heart_rate_zone.zone4_description"
            static let zone5Description = "performance.heart_rate_zone.zone5_description"
            static let zone6Description = "performance.heart_rate_zone.zone6_description"

            // Zone Benefits
            static let zone1Benefit = "performance.heart_rate_zone.zone1_benefit"
            static let zone2Benefit = "performance.heart_rate_zone.zone2_benefit"
            static let zone3Benefit = "performance.heart_rate_zone.zone3_benefit"
            static let zone4Benefit = "performance.heart_rate_zone.zone4_benefit"
            static let zone5Benefit = "performance.heart_rate_zone.zone5_benefit"
            static let zone6Benefit = "performance.heart_rate_zone.zone6_benefit"
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
        static let metric = "unit.metric"
        static let imperial = "unit.imperial"
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

    // MARK: - Data Sync
    enum Sync {
        static let title = "sync.title" // "數據同步"
        static let syncData = "sync.sync_data" // "同步 %@ 數據"
        static let syncingRecords = "sync.syncing_records" // "正在同步您的運動記錄..."
        static let complete = "sync.complete" // "同步完成"
        static let errorRecordsFailed = "sync.error_records_failed" // "有 %d 條記錄同步失敗"
        static let failed = "sync.failed" // "同步失敗"
        static let skip = "sync.skip" // "跳過"
        static let retry = "sync.retry" // "重試"
        static let timeoutWarningTitle = "sync.timeout_warning_title" // "同步時間比預期長"
        static let timeoutWarningMessage = "sync.timeout_warning_message" // "您可以選擇跳過並繼續，同步將在後台完成。"
        
        // Progress Steps
        static let checkingHealthAuth = "sync.checking_health_auth" // "正在檢查 Apple Health 授權..."
        static let getting30DayRecords = "sync.getting_30_day_records" // "正在獲取近 30 天的運動記錄..."
        static let noHealthRecords = "sync.no_health_records" // "在近 30 天內未找到 Apple Health 運動記錄..."
        static let uploadingRecords = "sync.uploading_records" // "正在將 %d 條運動記錄上傳到雲端..."
        static let uploadingRecordProgress = "sync.uploading_record_progress" // "正在上傳運動記錄 (%d/%d)..."
        static let allRecordsFailed = "sync.all_records_failed" // "所有運動記錄上傳失敗: %@"
        static let reloadData = "sync.reload_data" // "正在重新載入運動數據..."
        static let appleHealthFailed = "sync.apple_health_failed" // "Apple Health 同步失敗: %@"
        
        static let checkingGarminStatus = "sync.checking_garmin_status" // "正在檢查 Garmin 處理狀態..."
        static let garminProcessingDetected = "sync.garmin_processing_detected" // "檢測到 Garmin 數據正在處理中..."
        static let garminProcessingContinue = "sync.garmin_processing_continue" // "檢測到 Garmin 正在處理，直接進入輪詢模式"
        static let startGarminHistorical = "sync.start_garmin_historical" // "開始處理 Garmin 歷史數據..."
        static let processingGarminData = "sync.processing_garmin_data" // "正在處理 Garmin 數據 (預計 %@)..."
        static let garminHistoricalSuccess = "sync.garmin_historical_success" // "成功觸發新的 Garmin 歷史數據處理"
        static let processingInProgress = "sync.processing_in_progress" // "檢測到處理正在進行中...\n正在連接到處理程序"
        static let cannotConnectGarmin = "sync.cannot_connect_garmin" // "無法連接到進行中的 Garmin 處理: %@"
        static let garminSyncFailed = "sync.garmin_sync_failed" // "Garmin 同步失敗: %@"
        static let processingGarminProgress = "sync.processing_garmin_progress" // "正在處理 Garmin 數據...\n進度: %d/%d (%d%%)"
        static let processingGarminInitializing = "sync.processing_garmin_initializing" // "正在處理 Garmin 數據...\n正在初始化..."
        
        static let preparingStrava = "sync.preparing_strava" // "正在準備 Strava 同步..."
        static let stravaTriggered = "sync.strava_triggered" // "已觸發 Strava 同步..."
        static let processingStravaProgress = "sync.processing_strava_progress" // "正在處理 Strava 數據，已同步 %d 條記錄..."
        static let stravaSyncFailed = "sync.strava_sync_failed" // "Strava 同步失敗: %@"
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

    /// 日期／數字格式用的 locale。
    ///
    /// **不要在 UI 用 `Locale.current`。** app 切語言換的是 bundle（`Bundle.setLanguage`），
    /// `Locale.current` 是行程啟動時決定的，要重啟才跟得上 —— 症狀是切完語言字串都翻了、
    /// 只有日期還停在舊語系（2026-08-26 QA）。
    var locale: Locale {
        switch self {
        case .traditionalChinese: return Locale(identifier: "zh_Hant_TW")
        case .english: return Locale(identifier: "en_US")
        case .japanese: return Locale(identifier: "ja_JP")
        }
    }

    /// 緊湊縮寫（登入畫面右上角語言切換用）
    var shortCode: String {
        switch self {
        case .traditionalChinese:
            return "ZH"
        case .english:
            return "EN"
        case .japanese:
            return "JP"
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
    
    /// 系統語言 → app 支援語言。
    ///
    /// **不要用 `SupportedLanguage(rawValue:)` 直接吃系統回來的字串。** raw value 是
    /// `zh-Hant`／`en`／`ja` 這三個 lproj 目錄名，而系統給的是 BCP-47 標籤，帶地區
    /// 甚至帶書寫系統（`zh-Hant-TW`／`zh-TW`／`en-GB`／`ja-JP`）。exact match 一定
    /// miss，然後靜默落到 `?? .traditionalChinese` —— 對日本用戶就是「系統日文、
    /// app 中文」，而且完全沒有 log 說它 miss 了。
    ///
    /// **候選順序：`Locale.preferredLanguages` 在前。** 那是使用者在系統設定裡排的
    /// 真實順序；`Bundle.main.preferredLocalizations` 是「bundle 有哪些語言」比對過
    /// 之後的結果，而且會被本 app 自己寫進 UserDefaults 的 `AppleLanguages` 蓋掉
    /// （`LanguageManager.applyLocalLanguage` 就在寫它）——首啟時那是一個先有雞
    /// 還是先有蛋的順序問題，不該當成系統語言的唯一來源。
    static func resolveFromSystem(
        preferredLanguages: [String] = Locale.preferredLanguages,
        preferredLocalizations: [String] = Bundle.main.preferredLocalizations
    ) -> SupportedLanguage {
        for tag in preferredLanguages + preferredLocalizations {
            if let matched = SupportedLanguage(languageTag: tag) { return matched }
        }
        // 一個都對不上（例如系統只設了韓文）→ 走 `CFBundleDevelopmentRegion`
        // 的語言，也就是繁中。
        return .traditionalChinese
    }

    /// BCP-47 語言標籤 → app 支援語言。看的是語言 subtag，不是整串。
    ///
    /// 中文只出 `zh-Hant` 一份，所以任何 `zh`（含 `zh-Hans`）都收斂到繁中 ——
    /// 沒有簡體資源，硬要分只會讓簡中用戶掉到英文。
    init?(languageTag: String) {
        let subtags = languageTag.lowercased().split(separator: "-", omittingEmptySubsequences: true)
        guard let language = subtags.first else { return nil }
        switch language {
        case "zh":  self = .traditionalChinese
        case "en":  self = .english
        case "ja":  self = .japanese
        default:    return nil
        }
    }

    static var current: SupportedLanguage {
        resolveFromSystem()
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
        static let contactUs = "feedback.contact_us"
        static let contactUsHint = "feedback.contact_us_hint"
        static let threads = "feedback.threads"
        static let facebook = "feedback.facebook"

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
        static let contactFacebookPage = "profile_view.contact_facebook_page"

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
        static let title = "edit_schedule.title" // "編輯週課表"
        static let unsavedChanges = "edit_schedule.unsaved_changes" // "未儲存的變更"
        static let unsavedChangesMessage = "edit_schedule.unsaved_changes_message"
        static let discardChanges = "edit_schedule.discard_changes" // "放棄變更"
        static let editTraining = "edit_schedule.edit_training" // "編輯訓練"
        static let cancel = "edit_schedule.cancel" // "取消"
        static let save = "edit_schedule.save" // "儲存"
        static let confirm = "edit_schedule.confirm" // "確定"
        static let apply = "edit_schedule.apply" // "套用"
        static let delete = "edit_schedule.delete" // "刪除"
        static let close = "edit_schedule.close" // "關閉"
        static let cannotEdit = "edit_schedule.cannot_edit" // "無法編輯"
        static let addSegment = "edit_schedule.add_segment" // "新增區段"
        static let totalDistance = "edit_schedule.total_distance" // "總距離"
        static let paceLabel = "edit_schedule.pace_label" // "Pace:"
        static let distanceLabel = "edit_schedule.distance_label" // "Distance:"
        static let addStrengthTraining = "edit_schedule.add_strength_training" // "Add strength training"
        static let convertToStrengthDay = "edit_schedule.convert_to_strength_day" // "Convert to strength day"
        static let workTime = "edit_schedule.work_time" // "Work time"
        static let selectWorkTime = "edit_schedule.select_work_time" // "Select work time"
        static let reapplyDefaults = "edit_schedule.reapply_defaults" // "Reapply defaults"
        static let changeToRestDay = "edit_schedule.change_to_rest_day" // "Change to rest day"
        static let typeChangeAlert = "edit_schedule.type_change_alert" // "Changing type will clear the current exercises. Continue?"
        static let removeStrengthTraining = "edit_schedule.remove_strength_training" // "Remove strength training"
        static let easyTrainingSection = "edit_schedule.easy_training_section" // "Easy training"
        static let intensityTrainingSection = "edit_schedule.intensity_training_section" // "Intensity training"
        static let longDistanceTrainingSection = "edit_schedule.long_distance_training_section" // "Long-distance training"
        static let otherTrainingSection = "edit_schedule.other_training_section" // "Other"

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
        static let norwegian4x4Settings = "edit_schedule.norwegian_4x4_settings" // "挪威4x4訓練設定"
        static let norwegian4x4Description = "edit_schedule.norwegian_4x4_description" // "4組4分鐘高強度間歇（92% VO2max），組間休息3分鐘"
        static let yasso800Settings = "edit_schedule.yasso_800_settings" // "亞索800訓練設定"
        static let yasso800Description = "edit_schedule.yasso_800_description" // "800公尺重複跑，用於預測馬拉松成績並提升VO2max"
        static let time = "edit_schedule.time" // "時間"
        static let restTime = "edit_schedule.rest_time" // "休息時間"

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

        // Pace Zone Descriptions
        enum PaceZone {
            // Recovery
            static let recoveryDesc = "edit_schedule.pace_zone.recovery.description" // "用於恢復日，放鬆慢跑，促進身體恢復"
            static let recoveryBenefit = "edit_schedule.pace_zone.recovery.benefit" // "效益：促進肌肉恢復、減少疲勞累積"

            // Easy
            static let easyDesc = "edit_schedule.pace_zone.easy.description" // "日常訓練基礎配速，可以舒適對話，建立有氧基礎"
            static let easyBenefit = "edit_schedule.pace_zone.easy.benefit" // "效益：建立有氧基礎、增強耐力、降低受傷風險"

            // Tempo
            static let tempoDesc = "edit_schedule.pace_zone.tempo.description" // "乳酸閾值訓練，維持 20-30 分鐘，提升跑步經濟性"
            static let tempoBenefit = "edit_schedule.pace_zone.tempo.benefit" // "效益：提升乳酸閾值、改善跑步經濟性、增強心肺功能"

            // Marathon
            static let marathonDesc = "edit_schedule.pace_zone.marathon.description" // "目標馬拉松比賽配速，長距離持續配速訓練"
            static let marathonBenefit = "edit_schedule.pace_zone.marathon.benefit" // "效益：適應馬拉松配速、提升長距離耐力、模擬比賽強度"

            // Threshold
            static let thresholdDesc = "edit_schedule.pace_zone.threshold.description" // "高強度有氧訓練，提升最大攝氧量"
            static let thresholdBenefit = "edit_schedule.pace_zone.threshold.benefit" // "效益：提升最大攝氧量、增強有氧能力、改善速度耐力"

            // Anaerobic
            static let anaerobicDesc = "edit_schedule.pace_zone.anaerobic.description" // "無氧耐力訓練，接近最大強度，提升無氧能力"
            static let anaerobicBenefit = "edit_schedule.pace_zone.anaerobic.benefit" // "效益：提升無氧耐力、增強高強度持續能力、改善乳酸耐受度"

            // Interval
            static let intervalDesc = "edit_schedule.pace_zone.interval.description" // "高強度間歇訓練，短距離快速，提升速度與爆發力"
            static let intervalBenefit = "edit_schedule.pace_zone.interval.benefit" // "效益：提升最大攝氧量、增強速度與爆發力、改善跑步效率"
        }

        // Additional
        static let saveFailed = "edit_schedule.save_failed" // "保存失敗"
        static let saveFailedMessage = "edit_schedule.save_failed_message" // "無法同步週課表，請稍後再試。"
        static let tapToolbarSaveToSync = "edit_schedule.tap_toolbar_save_to_sync" // "變更已暫存，請點右上角儲存以同步到雲端"
        static let restInPlace = "edit_schedule.rest_in_place" // "原地休息"
        static let dragging = "edit_schedule.dragging" // "拖曳中..."
        static let dragToTarget = "edit_schedule.drag_to_target" // "拖曳到目標位置"

        // Weekdays
        static let monday = "edit_schedule.monday" // "週一"
        static let tuesday = "edit_schedule.tuesday" // "週二"
        static let wednesday = "edit_schedule.wednesday" // "週三"
        static let thursday = "edit_schedule.thursday" // "週四"
        static let friday = "edit_schedule.friday" // "週五"
        static let saturday = "edit_schedule.saturday" // "週六"
        static let sunday = "edit_schedule.sunday" // "週日"
        static let unknown = "edit_schedule.unknown" // "未知"
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

        // Metric Labels for Radar Chart
        static let speedLabel = "training_readiness.speed_label" // "速度"
        static let enduranceLabel = "training_readiness.endurance_label" // "耐力"
        static let raceFitnessLabel = "training_readiness.race_fitness_label" // "比賽適能"
        static let trainingLoadLabel = "training_readiness.training_load_label" // "訓練負荷"

        // Speed Metric Details
        enum Speed {
            static let title = "training_readiness.speed.title" // "速度指標"
            static let description = "training_readiness.speed.description" // "評估您的跑步配速能力"
            static let whatItMeans = "training_readiness.speed.what_it_means" // "配速是否符合訓練進展的期望"
            static let howToImprove1 = "training_readiness.speed.how_to_improve_1" // "儘量達成速度課表的計劃配速"
            static let howToImprove2 = "training_readiness.speed.how_to_improve_2" // "跑好間歇跑的衝刺區間配速"
            static let whenDecreases = "training_readiness.speed.when_decreases" // "無法跑到目標配速，或太久沒有訓練"
        }

        // Endurance Metric Details
        enum Endurance {
            static let title = "training_readiness.endurance.title" // "耐力指標"
            static let description = "training_readiness.endurance.description" // "評估您的長距離跑穩定性"
            static let whatItMeans = "training_readiness.endurance.what_it_means" // "長距離跑的心率和配速的穩定性"
            static let howToImprove1 = "training_readiness.endurance.how_to_improve_1" // "輕鬆跑、LSD 確實跑在 Zone 2 心率區間"
            static let howToImprove2 = "training_readiness.endurance.how_to_improve_2" // "逐週增加距離，保持配速穩定"
            static let whenDecreases = "training_readiness.endurance.when_decreases" // "心率提升幅度較配速提升還大，或太久沒有長跑"
        }

        // Race Fitness Metric Details
        enum RaceFitness {
            static let title = "training_readiness.race_fitness.title" // "比賽適能"
            static let description = "training_readiness.race_fitness.description" // "評估為目標賽事的準備進度"
            static let whatItMeans = "training_readiness.race_fitness.what_it_means" // "體能表現狀態離目標配速還有多遠"
            static let howToImprove1 = "training_readiness.race_fitness.how_to_improve_1" // "儘量跟上每週的課表安排"
            static let howToImprove2 = "training_readiness.race_fitness.how_to_improve_2" // "高品質的休息與恢復"
            static let howToImprove3 = "training_readiness.race_fitness.how_to_improve_3" // "適當的力量訓練"
            static let whenDecreases = "training_readiness.race_fitness.when_decreases" // "天氣過熱、身體狀況不佳，或缺乏多樣訓練"
        }

        // Training Load Metric Details
        enum Load {
            static let title = "training_readiness.load.title" // "訓練負荷"
            static let description = "training_readiness.load.description" // "評估訓練量是否適當"
            static let whatItMeans = "training_readiness.load.what_it_means" // "訓練量是否過大"
            static let howToImprove1 = "training_readiness.load.how_to_improve_1" // "跑量、強度按照課表安排穩步提升"
            static let howToImprove2 = "training_readiness.load.how_to_improve_2" // "如果負荷過大，考慮安排休息週好好恢復"
            static let howToImprove3 = "training_readiness.load.how_to_improve_3" // "高強度訓練後安排恢復日"
            static let whenDecreases = "training_readiness.load.when_decreases" // "訓練量持續過高，且恢復狀態不好"
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
        static let updated = "my_achievement.updated" // " 更新"

        // Personal Best v2
        enum PersonalBest {
            static let title = "my_achievement.personal_best.title"  // "個人最佳成績"
            static let explanation = "my_achievement.personal_best.explanation"  // "顯示你在不同距離的最佳完賽時間和配速"
            static let noData = "my_achievement.personal_best.no_data"  // "暫無個人最佳成績\n完成第一次訓練後即可查看"
            static let firstPlace = "my_achievement.personal_best.first_place"  // "第一名"
            static let secondPlace = "my_achievement.personal_best.second_place"  // "第二名"
            static let thirdPlace = "my_achievement.personal_best.third_place"  // "第三名"
            static let detailExplanation = "my_achievement.personal_best.detail_explanation"  // 詳細說明
            static let topRecords = "my_achievement.personal_best.top_records"  // 歷史最佳
        }

        enum Celebration {
            static let newRecord = "my_achievement.celebration.new_record"  // "新紀錄！"
            static let improved = "my_achievement.celebration.improved"  // "進步了"
            static let newPB = "my_achievement.celebration.new_pb"  // "New PB"
            static let firstRecord = "my_achievement.celebration.first_record"  // 首次標準距離紀錄
            static let otherPBs = "my_achievement.celebration.other_pbs"  // 另有 %d 個 PB
            static let share = "my_achievement.celebration.share"  // 分享
            static let save = "my_achievement.celebration.save"  // 儲存
            static let saveImage = "my_achievement.celebration.save_image"  // 存圖片
            static let date = "my_achievement.celebration.date"  // 日期
            static let result = "my_achievement.celebration.result"  // 成績
            static let shareCardTitle = "my_achievement.celebration.share_card_title"  // PB 分享卡
            static let newBadge = "my_achievement.celebration.new_badge"  // 新徽章
            static let newPBAndBadge = "my_achievement.celebration.new_pb_and_badge"  // 新 PB + 徽章
            static let alsoUnlocked = "my_achievement.celebration.also_unlocked"  // 同時解鎖
        }
    }

    // MARK: - Personal Achievements
    enum Achievements {
        static let title = "achievements.title"
        static let loading = "achievements.loading"

        enum Story {
            static let title = "achievements.story.title"
            static let explanation = "achievements.story.explanation"
            static let unlockedCount = "achievements.story.unlocked_count"
            static let recentUnlock = "achievements.story.recent_unlock"
            static let noRecentUnlock = "achievements.story.no_recent_unlock"
            static let nextBadge = "achievements.story.next_badge"
        }

        enum Hero {
            static let title = "achievements.hero.title"
            static let explanation = "achievements.hero.explanation"
            static let pickerTitle = "achievements.hero.picker_title"
            static let pickerEmpty = "achievements.hero.picker_empty"
            static let unlockedAt = "achievements.hero.unlocked_at"
            static let noSelection = "achievements.hero.no_selection"
        }

        enum Empty {
            static let title = "achievements.empty.title"
            static let start = "achievements.empty.start"
        }

        enum Backfill {
            static let ready = "achievements.backfill.ready"
            static let count = "achievements.backfill.count"
        }

        enum PB {
            static let title = "achievements.pb.title"
            static let explanation = "achievements.pb.explanation"
            static let empty = "achievements.pb.empty"
            static let record = "achievements.pb.record"
        }

        enum Stats {
            static let title = "achievements.stats.title"
            static let explanation = "achievements.stats.explanation"
            static let totalRuns = "achievements.stats.total_runs"
            static let totalDistance = "achievements.stats.total_distance"
            static let completedWeeks = "achievements.stats.completed_weeks"
            static let longestRun = "achievements.stats.longest_run"
            static let firstWorkout = "achievements.stats.first_workout"
            static let kilometers = "achievements.stats.kilometers"
        }

        enum Insights {
            static let title = "achievements.insights.title"
            static let explanation = "achievements.insights.explanation"
        }

        enum Share {
            static let title = "achievements.share.title"
            static let explanation = "achievements.share.explanation"
            static let item = "achievements.share.item"
            static let action = "achievements.share.action"
            static let previewTitle = "achievements.share.preview_title"
            static let privacyTitle = "achievements.share.privacy_title"
            static let privacyBody = "achievements.share.privacy_body"
            static let publicFields = "achievements.share.public_fields"
            static let defaultPublicFields = "achievements.share.default_public_fields"
            static let sensitiveExcluded = "achievements.share.sensitive_excluded"
            static let privacyFooter = "achievements.share.privacy_footer"
            static let badgeLabel = "achievements.share.badge_label"
            // Share card eyebrow capsule labels
            static let tagNewPB = "achievements.share.tag_new_pb"
            static let tagNewBadge = "achievements.share.tag_new_badge"
            static let tagPBAndBadge = "achievements.share.tag_pb_and_badge"
            // Reuse Task 8 key to avoid duplication
            static let alsoUnlocked = "my_achievement.celebration.also_unlocked"
            // New badge share card — chapter chip label ("%@" = chapter name)
            static let cardChapterLabel = "achievements.share.card.chapter_label"
        }

        enum Badges {
            static let title = "achievements.badges.title"
            static let explanation = "achievements.badges.explanation"
            static let badge = "achievements.badges.badge"
            static let historical = "achievements.badges.historical"
            static let progress = "achievements.badges.progress"
            static let emptyPreview = "achievements.badges.empty_preview"
        }

        enum Detail {
            static let title = "achievements.detail.title"
            static let story = "achievements.detail.story"
            static let progress = "achievements.detail.progress"
            static let source = "achievements.detail.source"
            static let historical = "achievements.detail.historical"
            static let unlockedAt = "achievements.detail.unlocked_at"
            static let criteriaUnavailable = "achievements.detail.criteria_unavailable"
            static let criteria = "achievements.detail.criteria"
        }

        enum Status {
            static let unlocked = "achievements.status.unlocked"
            static let inProgress = "achievements.status.in_progress"
            static let locked = "achievements.status.locked"
            static let insufficientData = "achievements.status.insufficient_data"
            static let unknown = "achievements.status.unknown"
        }

        enum Chapter {
            static let start = "achievements.chapter.start"
            static let build = "achievements.chapter.build"
            static let adapt = "achievements.chapter.adapt"
            static let prove = "achievements.chapter.prove"
            static let identity = "achievements.chapter.identity"
            static let unknown = "achievements.chapter.unknown"
        }

        enum Error {
            static let loadFailed = "achievements.error.load_failed"
        }

        enum StatsBanner {
            static let unlockedLabel = "achievements.stats_banner.unlocked_label" // "徽章已解鎖"
            static let pbLabel = "achievements.stats_banner.pb_label" // "PB 紀錄"
            static let streakLabel = "achievements.stats_banner.streak_label" // "連續訓練"
        }

        enum HeroCard {
            static let latestUnlock = "achievements.hero_card.latest_unlock" // "✨ 最新解鎖"
            static let share = "achievements.hero_card.share" // "分享"
            static let nextTarget = "achievements.hero_card.next_target" // "🎯 下一個目標"
            static let viewAllTracks = "achievements.hero_card.view_all_tracks" // "看全部主線"
            static let remaining = "achievements.hero_card.remaining" // "還差"
        }

        enum PBCard {
            static let sectionTitle = "achievements.pb_card.section_title" // "個人最佳"
            static let setCountFormat = "achievements.pb_card.set_count_format" // "%d / 4 已創下"
            static let cardTitle = "achievements.pb_card.card_title" // "個人最佳紀錄"
            static let viewAll = "achievements.pb_card.view_all" // "查看全部"
            static let noPB = "achievements.pb_card.no_pb" // "還沒有個人最佳紀錄"
            static let noPBHint = "achievements.pb_card.no_pb_hint" // "完成第一次計時跑就能創下 PB"
            static let moreDistancesFormat = "achievements.pb_card.more_distances_format" // "+%d 個其他距離紀錄"
        }

        enum BadgeCollection {
            static let title = "achievements.badge_collection.title" // "徽章收藏"
            static let unlockedCountFormat = "achievements.badge_collection.unlocked_count_format" // "%d/%d 已解鎖"
            static let viewMore = "achievements.badge_collection.view_more" // "看更多"
        }

        enum BadgeTile {
            static let insufficientData = "achievements.badge_tile.insufficient_data" // "資料不足"
            static let locked = "achievements.badge_tile.locked" // "尚未解鎖"
        }

        enum Tracks {
            static let title = "achievements.tracks.title" // "成就主線"
            static let empty = "achievements.tracks.empty" // "尚無主線資料"
        }
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
        static let title = "share_card.title" // "Share Card"
        static let metricDistanceKm = "share_card.metric.distance_km" // "Distance (km)"
        static let metricTotalTime = "share_card.metric.total_time" // "Total Time"
        static let metricAvgPace = "share_card.metric.avg_pace" // "Average Pace"
        static let tutorialTitle = "share_card.tutorial.title" // "Share Card Editing Guide"
        static let tutorialStartEditing = "share_card.tutorial.start_editing" // "Start Editing"
        static let tutorialEditTitleTitle = "share_card.tutorial.edit_title.title" // "Tap title or AI review"
        static let tutorialEditTitleDescription = "share_card.tutorial.edit_title.description" // "Edit or delete text content"
        static let tutorialAddTextTitle = "share_card.tutorial.add_text.title" // "Add text"
        static let tutorialAddTextDescription = "share_card.tutorial.add_text.description" // "Add custom text and move it freely"
        static let tutorialLayoutSizeTitle = "share_card.tutorial.layout_size.title" // "Layout and size"
        static let tutorialLayoutSizeDescription = "share_card.tutorial.layout_size.description" // "Switch layout styles and image sizes"
        static let tutorialChoosePhotoTitle = "share_card.tutorial.choose_photo.title" // "Choose photo"
        static let tutorialChoosePhotoDescription = "share_card.tutorial.choose_photo.description" // "Change background photo and adjust its position"
        static let editorTitle = "share_card.editor.title" // "Create Share Card"
        static let editAchievementTitle = "share_card.editor.edit_achievement_title" // "Edit Achievement Title"
        static let editAIReview = "share_card.editor.edit_ai_review" // "Edit AI Review"
        static let addFreeText = "share_card.editor.add_free_text" // "Add Free Text"
        static let editText = "share_card.editor.edit_text" // "Edit Text"
        static let addFreeTextMessage = "share_card.editor.add_free_text_message" // "Add your own text to the share card."
        static let editTextMessage = "share_card.editor.edit_text_message" // "Edit your text."
        static let titlePlaceholder = "share_card.editor.title_placeholder" // "Enter title (max 50 chars)"
        static let aiReviewPlaceholder = "share_card.editor.ai_review_placeholder" // "Enter AI review (max 80 chars)"
        static let freeTextPlaceholder = "share_card.editor.free_text_placeholder" // "Enter text (max 30 chars)"
        static let layout = "share_card.editor.layout" // "Layout"
        static let size = "share_card.editor.size" // "Size"
        static let addText = "share_card.editor.add_text" // "Add Text"
    }

    // MARK: - Onboarding Additional
    enum OnboardingAdditional {
        static let trainingPlanPreview = "onboarding.training_plan_preview" // "您的訓練計畫預覽"
        static let goalAssessment = "onboarding.goal_assessment" // "目標評估"
        static let trainingFocus = "onboarding.training_focus_title" // "訓練重點"
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

    // MARK: - Empty State
    enum EmptyState {
        // Titles
        static let noDataTitle = "empty_state.no_data_title" // "無%@數據"
        static let loadingFailedTitle = "empty_state.loading_failed_title" // "載入失敗"
        static let apiErrorTitle = "empty_state.api_error_title" // "數據載入失敗"
        static let noPermissionTitle = "empty_state.no_permission_title" // "無權限"
        static let noDataSourceTitle = "empty_state.no_data_source_title" // "未選擇數據來源"
        static let hrvDataTitle = "empty_state.hrv_data_title" // "無 HRV 數據"
        static let sleepHeartRateDataTitle = "empty_state.sleep_heart_rate_data_title" // "無睡眠心率數據"
        static let vdotDataTitle = "empty_state.vdot_data_title" // "無跑力數據"
        static let workoutDataTitle = "empty_state.workout_data_title" // "無運動數據"
        static let healthDataTitle = "empty_state.health_data_title" // "無健康數據"

        // Descriptions
        static let noDataDesc = "empty_state.no_data_desc" // "目前沒有可顯示的%@數據"
        static let loadingFailedDesc = "empty_state.loading_failed_desc" // "無法載入數據，請檢查網路連線後重試"
        static let apiErrorDesc = "empty_state.api_error_desc" // "伺服器暫時無法提供數據"
        static let noPermissionDesc = "empty_state.no_permission_desc" // "請在設定中允許存取相關數據"
        static let noDataSourceDesc = "empty_state.no_data_source_desc" // "請選擇數據來源以查看相關資訊"
        static let hrvDataDesc = "empty_state.hrv_data_desc" // "無法獲取心率變異性數據"
        static let sleepHeartRateDataDesc = "empty_state.sleep_heart_rate_data_desc" // "無法獲取睡眠心率數據"
        static let vdotDataDesc = "empty_state.vdot_data_desc" // "暫無跑力數據，請先完成跑步訓練"
        static let workoutDataDesc = "empty_state.workout_data_desc" // "尚未記錄任何運動數據"
        static let healthDataDesc = "empty_state.health_data_desc" // "無法獲取健康數據"
    }

    // MARK: - Distance Labels
    enum Distance {
        static let mile = "distance.mile"                   // "1.6 公里"
        static let threeK = "distance.3k"                   // "3 公里"
        static let fiveK = "distance.5k"                    // "5 公里"
        static let tenK = "distance.10k"                    // "10 公里"
        static let halfMarathon = "distance.half_marathon"  // "半程馬拉松"
        static let halfMarathonShort = "distance.half_marathon_short"  // "半馬"
        static let fullMarathon = "distance.full_marathon"  // "全程馬拉松"
        static let fullMarathonShort = "distance.full_marathon_short"  // "全馬"
    }

    enum Notification {
        enum SundayReminder {
            static let title = "notification.sunday_reminder.title"
            static let body  = "notification.sunday_reminder.body"
        }
    }

    // MARK: - Paywall Conversion (no-plan state)
    enum PaywallConversion {
        static let progress = "paywall.conversion.progress"
        static let progressWithRace = "paywall.conversion.progress_race"
        static let lockedPreviewTitle = "paywall.conversion.locked_preview_title"
        static let lockedPreviewBody = "paywall.conversion.locked_preview_body"
        static let recoverySuffix = "paywall.conversion.recovery_suffix"
        static let ctaStartTrial = "paywall.conversion.cta_trial"
        static let ctaGenerateWeek1 = "paywall.conversion.cta_generate"
        static let ctaRestore = "paywall.conversion.cta_restore"
        static let dailyValueHint = "paywall.conversion.daily_value_hint"
    }

    // MARK: - App 2.0 骨架（DESIGN-app2-decision-chain-api.md §3）
    enum App2 {
        enum Tab {
            static let state = "app2.tab.state"
            static let plan = "app2.tab.plan"
            static let records = "app2.tab.records"
            static let achievements = "app2.tab.achievements"
            /// 設定不再是 tab（設計 frame-00 第四格是成就），這條保留給頭像開的設定頁標題。
            static let settings = "app2.tab.settings"
        }

        enum Home {
            static let greeting = "app2.home.greeting"
            static let goalSection = "app2.home.goal_section"
            static let goalTarget = "app2.home.goal_target"
            static let goalEstimate = "app2.home.goal_estimate"
            static let goalWeek = "app2.home.goal_week"
            static let statusSection = "app2.home.status_section"
            static let todayTodo = "app2.home.today_todo"
            static let todayDone = "app2.home.today_done"
            static let planRow = "app2.home.plan_row"
            static let actualRow = "app2.home.actual_row"
            static let weekReviewSub = "app2.home.week_review_sub"
            static let rizoSub = "app2.home.rizo_sub"
            static let recoverySeconds = "app2.home.recovery_seconds"
            static let recoveryMetres = "app2.home.recovery_metres"
            static let noGoalTitle = "app2.home.no_goal_title"
            static let noGoalBody = "app2.home.no_goal_body"
            static let noPlanBody = "app2.home.no_plan_body"
            static let insightsSection = "app2.home.insights_section"
            static let todaySection = "app2.home.today_section"
            static let rizoEntry = "app2.home.rizo_entry"
            static let weekReviewEntry = "app2.home.week_review_entry"
            /// 今日課表卡的分段表。`熱身`／`衝刺`／`緩和` 走既有的 `training.segment.*`
            /// （三語已齊），只有這兩個沒有現成的詞。
            static let segmentRecovery = "app2.home.segment_recovery"
            static let segmentMain = "app2.home.segment_main"
            /// `%d 分鐘`
            static let minutes = "app2.home.minutes"
            /// `力量 · %d 個動作`
            static let strengthRow = "app2.home.strength_row"
            /// 結構預覽的標題：`趟數 × %d 趟`
            static let structureReps = "app2.home.structure_reps"
            /// 配速結構圖下方的段落標註列（設計 frame-02 的圖例）。
            static let structureNoteSteady = "app2.home.structure_note_steady"
            static let structureNoteInterval = "app2.home.structure_note_interval"
            /// 今日課表讀不到（**不是**「尚未產生」）。
            static let planUnavailableBody = "app2.home.plan_unavailable_body"
            /// 本週課表在，但今天不在裡面。
            static let noSessionTodayBody = "app2.home.no_session_today_body"
            /// 週回顧 CTA 的四組文案（設計 dc.html:5112：週日＝本週、其餘＝上週）。
            static let weekReviewGenerateCurrent = "app2.home.week_review_generate_current"
            static let weekReviewGenerateLast = "app2.home.week_review_generate_last"
            static let weekReviewSubCurrent = "app2.home.week_review_sub_current"
            static let weekReviewSubLast = "app2.home.week_review_sub_last"
            static let weekReviewView = "app2.home.week_review_view"
            static let weekReviewViewSub = "app2.home.week_review_view_sub"
            /// 內嵌 Rizo 卡。
            static let rizoCoachTitle = "app2.home.rizo_coach_title"
            static let rizoInputPlaceholder = "app2.home.rizo_input_placeholder"
            /// 訓練狀況卡展開態的 Rizo 佔位字。
            ///
            /// 收合／展開連結的字（`看更多`／`收起`）走既有的
            /// `app2.achievements.see_more` 與 `training.collapse`（frame-00c2，
            /// 2026-08-26 裁決把它接進 headline 句尾），不開第二份同義字串。
            static let statusRizoPlaceholder = "app2.home.status_rizo_placeholder"

            /// Rizo 對話 sheet（frame-00d）：主題卡、開場白、建議問題 chips。
            static let rizoTopicLabel = "app2.home.rizo_topic_label"
            static let rizoTopicAdvice = "app2.home.rizo_topic_advice"
            static let rizoTopicPlan = "app2.home.rizo_topic_plan"
            static let rizoOpening = "app2.home.rizo_opening"
            static let rizoOpeningPrompt = "app2.home.rizo_opening_prompt"
            static let rizoChipAdvice1 = "app2.home.rizo_chip_advice_1"
            static let rizoChipAdvice2 = "app2.home.rizo_chip_advice_2"
            static let rizoChipAdvice3 = "app2.home.rizo_chip_advice_3"
            static let rizoChipPlan1 = "app2.home.rizo_chip_plan_1"
            static let rizoChipPlan2 = "app2.home.rizo_chip_plan_2"
            static let rizoChipPlan3 = "app2.home.rizo_chip_plan_3"
            /// 休息日卡（設計 dc.html「今日課表 · 休息日卡片」）。
            static let todayRest = "app2.home.today_rest"
            static let restTitle = "app2.home.rest_title"
            static let restBody = "app2.home.rest_body"
            static let crossTitle = "app2.home.cross_title"
            static let crossBody = "app2.home.cross_body"
            /// 首頁 v2 header（設計 `screens/frame-00b-home-v2.png`）。
            static let notifications = "app2.home.notifications"
            static let menu = "app2.home.menu"
            static let menuProfile = "app2.home.menu_profile"
            static let menuEditPlan = "app2.home.menu_edit_plan"
            static let insightsMore = "app2.home.insights_more"
            /// 今日課表卡下方的「已完成 → 看訓練詳情」列。
            static let todayCompletedTitle = "app2.home.today_completed_title"
            static let todayCompletedSub = "app2.home.today_completed_sub"
        }


        /// 今日課表卡與訓練詳情共用的設計稿靜態文案。
        enum Session {
            /// 長距離課的補給建議 —— 設計稿文案，不是 payload 欄位。
            static let fuelingNote = "app2.session.fueling_note"
            /// 體感強度卡的標題（設計「體感強度 · Z2」）。
            static let effortTitle = "app2.session.effort_title"
            /// 體感分數 `3 / 10`。
            static let effortScore = "app2.session.effort_score"
            /// 標題列的強度 chip（`低強度`／`中強度`／`高強度`／`耐力`／`恢復`）。
            static let effortChipLow = "app2.session.effort_chip_low"
            static let effortChipMedium = "app2.session.effort_chip_medium"
            static let effortChipHigh = "app2.session.effort_chip_high"
            static let effortChipEndurance = "app2.session.effort_chip_endurance"
            static let effortChipRecovery = "app2.session.effort_chip_recovery"
        }

        /// 編輯週課表（設計 frame-03～09）。
        enum PlanEdit {
            static let selectType = "app2.plan_edit.select_type"
            static let adjacentWarning = "app2.plan_edit.adjacent_warning"
            static let distanceChip = "app2.plan_edit.distance_chip"
            static let paceChip = "app2.plan_edit.pace_chip"
            static let detailChip = "app2.plan_edit.detail_chip"
            static let deltaUp = "app2.plan_edit.delta_up"
            static let deltaDown = "app2.plan_edit.delta_down"
            static let deltaSame = "app2.plan_edit.delta_same"
            static let loadFailed = "app2.plan_edit.load_failed"

            // frame-03 版面
            static let paceTable = "app2.plan_edit.pace_table"
            static let editModeBanner = "app2.plan_edit.edit_mode_banner"
            static let volumeTitle = "app2.plan_edit.volume_title"
            static let warningTitle = "app2.plan_edit.warning_title"
            static let today = "app2.plan_edit.today"
            /// 拖曳落點佔位的文字（`放開以移到這裡 · 與週三對調`）。
            static let dropHere = "app2.plan_edit.drop_here"
            static let advancedEdit = "app2.plan_edit.advanced_edit"
            static let planRow = "app2.plan_edit.plan_row"
            static let strengthSummary = "app2.plan_edit.strength_summary"
            static let supplementaryNote = "app2.plan_edit.supplementary_note"
            static let supplementaryNoteMinutes = "app2.plan_edit.supplementary_note_minutes"
            static let heartRateSummary = "app2.plan_edit.heart_rate_summary"
            static let savedToast = "app2.plan_edit.saved_toast"
            /// frame-04 課型選單的副標。
            static let typeSheetSubtitle = "app2.plan_edit.type_sheet_subtitle"
        }

        /// 編輯單日（設計 frame-05 間歇／frame-06 組合／frame-07 肌力／frame-08 休息／frame-09 輪盤）。
        enum DayEdit {
            // Hero kicker（依 `TrainingScheduleEditorFamily` 分）
            static let kickerEasy = "app2.day_edit.kicker_easy"
            static let kickerTempo = "app2.day_edit.kicker_tempo"
            static let kickerLongRun = "app2.day_edit.kicker_long_run"
            static let kickerIntervalDistance = "app2.day_edit.kicker_interval_distance"
            static let kickerIntervalTime = "app2.day_edit.kicker_interval_time"
            static let kickerCombination = "app2.day_edit.kicker_combination"
            static let kickerStrength = "app2.day_edit.kicker_strength"
            static let kickerRest = "app2.day_edit.kicker_rest"
            static let kickerCross = "app2.day_edit.kicker_cross"

            // frame-05 距離制間歇
            static let quickTemplates = "app2.day_edit.quick_templates"
            static let quickTemplatesHint = "app2.day_edit.quick_templates_hint"
            static let repeatsUnit = "app2.day_edit.repeats_unit"
            static let recoveryNote = "app2.day_edit.recovery_note"
            static let warmupCooldown = "app2.day_edit.warmup_cooldown"
            static let supplementaryStrength = "app2.day_edit.supplementary_strength"
            static let supplementaryStrengthSub = "app2.day_edit.supplementary_strength_sub"
            static let addExercise = "app2.day_edit.add_exercise"
            static let addSupplementaryStrength = "app2.day_edit.add_supplementary_strength"

            // frame-06 組合訓練
            static let combinationHint = "app2.day_edit.combination_hint"
            static let segmentList = "app2.day_edit.segment_list"
            static let segmentCount = "app2.day_edit.segment_count"
            static let dragToReorder = "app2.day_edit.drag_to_reorder"
            static let notAdded = "app2.day_edit.not_added"
            static let segmentEasy = "app2.day_edit.segment_easy"
            static let segmentFast = "app2.day_edit.segment_fast"

            // frame-07 肌力
            static let strengthTypeWarning = "app2.day_edit.strength_type_warning"
            static let exerciseCount = "app2.day_edit.exercise_count"
            static let addFromLibrary = "app2.day_edit.add_from_library"
            static let strengthEmptyHint = "app2.day_edit.strength_empty_hint"

            // frame-08 休息日
            static let restActiveTitle = "app2.day_edit.rest_active_title"
            static let restActiveSub = "app2.day_edit.rest_active_sub"
            static let restConvertSection = "app2.day_edit.rest_convert_section"
            static let restToStrengthTitle = "app2.day_edit.rest_to_strength_title"
            static let restToStrengthSub = "app2.day_edit.rest_to_strength_sub"
            static let restToCrossTitle = "app2.day_edit.rest_to_cross_title"
            static let restToCrossSub = "app2.day_edit.rest_to_cross_sub"
            static let restFooterHint = "app2.day_edit.rest_footer_hint"

            // frame-09 輪盤
            static let wheelPaceTitle = "app2.day_edit.wheel_pace_title"
            static let wheelDistanceTitle = "app2.day_edit.wheel_distance_title"
            static let wheelRestTitle = "app2.day_edit.wheel_rest_title"
            /// `配速表建議 I 強度 4:18–4:25／km`。區間算不出來時整列不出現。
            static let paceTableSuggestion = "app2.day_edit.pace_table_suggestion"
            static let secondsUnit = "app2.day_edit.seconds_unit"
        }

        /// 訓練詳情（設計 frame-02／dc.html「課表詳細 · …」）。
        enum Detail {
            static let title = "app2.detail.title"
            static let distance = "app2.detail.distance"
            static let duration = "app2.detail.duration"
            static let phases = "app2.detail.phases"
            static let phaseCount = "app2.detail.phase_count"
            static let pacePreview = "app2.detail.pace_preview"
            static let goal = "app2.detail.goal"
            static let structure = "app2.detail.structure"
            static let recoveryNote = "app2.detail.recovery_note"
            /// 「力量訓練」區塊小標（2026-08-27 晚走查裁決（d））。
            static let strengthSection = "app2.detail.strength_section"
            static let strengthSetsReps = "app2.detail.strength_sets_reps"
            static let strengthSetsSeconds = "app2.detail.strength_sets_seconds"
            static let strengthSets = "app2.detail.strength_sets"
            /// 課型說明區塊的小標（「這堂課練什麼」）。內文本體是既有的
            /// `TrainingTypeInfo`（`training_type_info.<type>.*`），不另建一份文案。
            static let purposeSection = "app2.detail.purpose_section"
            static let purposeMore = "app2.detail.purpose_more"
            /// 單段課的配速帶（設計 frame-02c）。
            static let paceBandFast = "app2.detail.pace_band_fast"
            static let paceBandSlow = "app2.detail.pace_band_slow"
            /// 訓練結構 header 的「N 段 · M 分鐘」。
            static let structureMeta = "app2.detail.structure_meta"
            /// 單段課結構首列的補充句。
            static let structureSteadyNote = "app2.detail.structure_steady_note"
            /// 主課段的課型確定性附註句（設計 frame-02d）。
            static let structureNoteThreshold = "app2.detail.structure_note_threshold"
            static let structureNoteLong = "app2.detail.structure_note_long"
            /// 目標區間兩張卡（設計 frame-02d）。
            static let targetZone = "app2.detail.target_zone"
            static let effortLabel = "app2.detail.effort_label"
            static let estimatedTime = "app2.detail.estimated_time"
            static let minutesUnit = "app2.detail.minutes_unit"
        }

        /// 訓練詳情（**已完成的一筆紀錄**，設計 frame-15～17）。
        ///
        /// 只放設計稿新增的字。距離／時長／卡路里／平均配速／平均心率／最大心率／
        /// 進階指標／訓練心得／里程校正／時間裁剪／重新上傳／刪除，全部沿用 1.4 既有的
        /// `workout.*` 鍵（三語已齊），不在這裡開第二份同義詞。
        enum WorkoutDetail {
            static let title = "app2.workout_detail.title"
            /// `新 PB · %@`
            static let newPersonalBest = "app2.workout_detail.new_pb"
            static let coachSection = "app2.workout_detail.coach_section"
            /// Rizo 分析的展開／收合（設計 frame-02f）。
            static let expandAnalysis = "app2.workout_detail.expand_analysis"
            static let collapseAnalysis = "app2.workout_detail.collapse_analysis"
            /// 指標磚的「跑力」（設計 frame-02f 的 `跑力 57.2 VDOT`）。
            static let runningPower = "app2.workout_detail.running_power"
            static let planned = "app2.workout_detail.planned"
            static let actual = "app2.workout_detail.actual"
            /// `均心 %d`
            static let avgHeartRateShort = "app2.workout_detail.avg_hr_short"
            static let verticalRatio = "app2.workout_detail.vertical_ratio"
            static let trendSection = "app2.workout_detail.trend_section"
            static let trendHeartRate = "app2.workout_detail.trend_heart_rate"
            static let trendPace = "app2.workout_detail.trend_pace"
            static let recordSection = "app2.workout_detail.record_section"

            static let vdotRow = "app2.workout_detail.vdot_row"
            static let vdotSubtitle = "app2.workout_detail.vdot_subtitle"
            static let vdotAutomatic = "app2.workout_detail.vdot_automatic"
            static let vdotAutomaticDesc = "app2.workout_detail.vdot_automatic_desc"
            static let vdotIncluded = "app2.workout_detail.vdot_included"
            static let vdotIncludedDesc = "app2.workout_detail.vdot_included_desc"
            static let vdotExcluded = "app2.workout_detail.vdot_excluded"
            static let vdotExcludedDesc = "app2.workout_detail.vdot_excluded_desc"

            static let toolsRow = "app2.workout_detail.tools_row"
            static let toolsRowSub = "app2.workout_detail.tools_row_sub"
            static let toolMileageSub = "app2.workout_detail.tool_mileage_sub"
            static let toolTrimSub = "app2.workout_detail.tool_trim_sub"
            static let toolReuploadSub = "app2.workout_detail.tool_reupload_sub"
            static let toolDeleteSub = "app2.workout_detail.tool_delete_sub"

            static let activityRunning = "app2.workout_detail.activity_running"
            static let activityTreadmill = "app2.workout_detail.activity_treadmill"
            static let activityTrail = "app2.workout_detail.activity_trail"
            static let activityTrack = "app2.workout_detail.activity_track"
        }

        /// 週回顧（設計 frame-18／frame-19）。
        enum WeeklyReview {
            static let title = "app2.weekly_review.title"
            static let tabReview = "app2.weekly_review.tab_review"
            static let tabPlan = "app2.weekly_review.tab_plan"
            /// `第 %d 週`
            static let weekKicker = "app2.weekly_review.week_kicker"
            static let statsSection = "app2.weekly_review.stats_section"
            static let sessions = "app2.weekly_review.sessions"
            static let completionRate = "app2.weekly_review.completion_rate"
            /// `計畫 %.1f km`
            static let plannedKmFootnote = "app2.weekly_review.planned_km_footnote"
            static let highlightsSection = "app2.weekly_review.highlights_section"
            static let observationsSection = "app2.weekly_review.observations_section"
            static let analysisSection = "app2.weekly_review.analysis_section"
            static let intensityDistribution = "app2.weekly_review.intensity_distribution"
            static let capability = "app2.weekly_review.capability"

            static let nextWeekTitle = "app2.weekly_review.next_week_title"
            /// `建議項目 · %d`
            static let suggestionsSection = "app2.weekly_review.suggestions_section"
            static let noSuggestions = "app2.weekly_review.no_suggestions"
            static let accept = "app2.weekly_review.accept"
            static let skip = "app2.weekly_review.skip"
            /// `套用 %d 項到下週課表`
            static let applyToNextWeek = "app2.weekly_review.apply_to_next_week"
            static let applied = "app2.weekly_review.applied"

            static let notGeneratedBody = "app2.weekly_review.not_generated_body"
            /// 歷史週唯讀回看且那一週沒有回顧（2026-08-27 走查裁決（q））。
            static let historyNotGeneratedBody = "app2.weekly_review.history_not_generated_body"
            static let generate = "app2.weekly_review.generate"
            static let generationWindowClosed = "app2.weekly_review.generation_window_closed"
            static let quotaTitle = "app2.weekly_review.quota_title"
            static let quotaBody = "app2.weekly_review.quota_body"
            static let upsellTitle = "app2.weekly_review.upsell_title"
            static let upsellBody = "app2.weekly_review.upsell_body"
        }

        enum Plan {
            static let title = "app2.plan.title"
            static let volumeTitle = "app2.plan.volume_title"
            static let today = "app2.plan.today"
            static let weekVolume = "app2.plan.week_volume"
            static let completed = "app2.plan.completed"
            static let intensitySection = "app2.plan.intensity_section"
            static let intensityLow = "app2.plan.intensity_low"
            static let intensityMedium = "app2.plan.intensity_medium"
            static let intensityHigh = "app2.plan.intensity_high"
            static let daysSection = "app2.plan.days_section"
            static let rest = "app2.plan.rest"
            /// 未產生態的產生入口（2026-08-27 晚走查裁決（i））。
            static let generateWeek = "app2.plan.generate_week"
            static let generatingWeek = "app2.plan.generating_week"
            static let generateFailed = "app2.plan.generate_failed"
            /// 上週回顧未完成時的 CTA（2026-08-27 晚走查裁決（k））。
            static let completeReviewFirst = "app2.plan.complete_review_first"
            /// header 的週回顧入口（2026-08-27 走查裁決（q））。
            static let openWeeklyReview = "app2.plan.open_weekly_review"
        }

        /// 訓練計畫總覽（設計 frame-20）。
        enum PlanOverview {
            static let title = "app2.plan_overview.title"
            static let goalSection = "app2.plan_overview.goal_section"
            /// `還有 %d 週`
            static let weeksUntilRace = "app2.plan_overview.weeks_until_race"
            static let currentYou = "app2.plan_overview.current_you"
            static let target = "app2.plan_overview.target"
            /// `約 %@ km / 週`
            static let weeklyVolume = "app2.plan_overview.weekly_volume"
            static let noEstimate = "app2.plan_overview.no_estimate"
            static let progressLabel = "app2.plan_overview.progress_label"
            /// `第 %1$d / %2$d 週`
            static let weekOfTotal = "app2.plan_overview.week_of_total"
            /// `%d 個階段`
            static let stagesSection = "app2.plan_overview.stages_section"
            static let stagesSubtitle = "app2.plan_overview.stages_subtitle"
            /// 里程碑區塊小標（2026-08-27 晚走查裁決（c））。
            static let milestonesSection = "app2.plan_overview.milestones_section"
            static let stageActive = "app2.plan_overview.stage_active"
            static let stageUpcoming = "app2.plan_overview.stage_upcoming"
            static let stageDone = "app2.plan_overview.stage_done"
            /// `%1$d / %2$d 週`
            static let stageProgress = "app2.plan_overview.stage_progress"
            static let rhythmSection = "app2.plan_overview.rhythm_section"
            static let runDays = "app2.plan_overview.run_days"
            /// `%d 天`
            static let runDaysValue = "app2.plan_overview.run_days_value"
            static let longRunDay = "app2.plan_overview.long_run_day"
            static let methodology = "app2.plan_overview.methodology"
            /// 更換訓練方法（2026-08-27 晚走查裁決（e））。
            static let changeMethodology = "app2.plan_overview.change_methodology"
            static let changeMethodologyNote = "app2.plan_overview.change_methodology_note"
            static let changeMethodologyFailed = "app2.plan_overview.change_methodology_failed"
            static let methodologyChanged = "app2.plan_overview.methodology_changed"
            static let manageSection = "app2.plan_overview.manage_section"
            static let manageRaces = "app2.plan_overview.manage_races"
            static let manageRacesSub = "app2.plan_overview.manage_races_sub"
            static let resetGoal = "app2.plan_overview.reset_goal"
            static let resetGoalSub = "app2.plan_overview.reset_goal_sub"
            static let autoAdjustNote = "app2.plan_overview.auto_adjust_note"
            static let noPlanTitle = "app2.plan_overview.no_plan_title"
            static let noPlanBody = "app2.plan_overview.no_plan_body"
            /// overview 綁不上本週課表 → 期程整段不顯示，畫面要說明原因。
            static let stagesUnavailable = "app2.plan_overview.stages_unavailable"
        }

        /// 賽事管理（設計 frame-12／13／14）。
        enum Races {
            static let title = "app2.races.title"
            static let subtitle = "app2.races.subtitle"
            static let mainSection = "app2.races.main_section"
            static let mainBadge = "app2.races.main_badge"
            static let supportSection = "app2.races.support_section"
            static let sortedByDate = "app2.races.sorted_by_date"
            static let countdown = "app2.races.countdown"
            /// `%d 天`
            static let countdownDays = "app2.races.countdown_days"
            static let countdownPast = "app2.races.countdown_past"
            /// 大數字後面的單位（`天`／`days`／`日`），與 `countdownDays` 是同一個詞的兩種排版。
            static let countdownUnit = "app2.races.countdown_unit"
            static let goalTime = "app2.races.goal_time"
            /// `%d 場`
            static let supportCountValue = "app2.races.support_count_value"
            static let supportCount = "app2.races.support_count"
            static let edit = "app2.races.edit"
            static let delete = "app2.races.delete"
            static let setAsMain = "app2.races.set_as_main"
            static let noSupport = "app2.races.no_support"
            static let noMainTitle = "app2.races.no_main_title"
            static let noMainBody = "app2.races.no_main_body"
            static let addRace = "app2.races.add_race"
            static let deleteConfirmTitle = "app2.races.delete_confirm_title"
            /// `確定要刪除「%@」嗎？`
            static let deleteConfirmBody = "app2.races.delete_confirm_body"

            // frame-13 新增／編輯
            static let addTitle = "app2.races.add_title"
            static let editTitle = "app2.races.edit_title"
            static let fromDatabase = "app2.races.from_database"
            static let fromDatabaseSub = "app2.races.from_database_sub"
            static let nameLabel = "app2.races.name_label"
            static let namePlaceholder = "app2.races.name_placeholder"
            static let typeLabel = "app2.races.type_label"
            static let distanceLabel = "app2.races.distance_label"
            static let dateLabel = "app2.races.date_label"
            static let targetTimeLabel = "app2.races.target_time_label"
            static let paceLabel = "app2.races.pace_label"
            static let paceHint = "app2.races.pace_hint"
            static let makeMain = "app2.races.make_main"
            static let makeMainSub = "app2.races.make_main_sub"
            static let makeMainNote = "app2.races.make_main_note"
            static let mainLockNote = "app2.races.main_lock_note"
            static let save = "app2.races.save"

            // frame-14 賽事資料庫
            static let databaseTitle = "app2.races.database_title"
            static let searchPlaceholder = "app2.races.search_placeholder"
            static let regionLabel = "app2.races.region_label"
            static let regionAll = "app2.races.region_all"
            static let regionTw = "app2.races.region_tw"
            static let regionJp = "app2.races.region_jp"
            static let filterLabel = "app2.races.filter_label"
            static let filterAll = "app2.races.filter_all"
            /// `%d 場賽事`
            static let resultCount = "app2.races.result_count"
            static let noResultTitle = "app2.races.no_result_title"
            static let noResultBody = "app2.races.no_result_body"
        }

        enum Records {
            static let title = "app2.records.title"
            static let trendTitle = "app2.records.trend_title"
            static let trendUnit = "app2.records.trend_unit"
            static let pace = "app2.records.pace"
            static let time = "app2.records.time"
            static let runsCount = "app2.records.runs_count"
            /// hero 左欄（設計 frame-10：「本月跑量」＋「較上月 ±N」）。
            static let monthSection = "app2.records.month_section"
            static let vsLastMonth = "app2.records.vs_last_month"
            static let ytdSection = "app2.records.ytd_section"
            static let distance = "app2.records.distance"
            static let workouts = "app2.records.workouts"
            static let weeklySection = "app2.records.weekly_section"
            static let listSection = "app2.records.list_section"
        }

        // MARK: 指標第二層（checklist §51–53）
        /// 首頁指標列點進去的三頁詳情。**只有訓練量／能力基準／恢復有稿**，
        /// 其餘指標不可點，所以這裡不放它們的字。
        enum Metric {
            /// top bar 右緣的「指標詳情」。
            static let pageSuffix = "app2.metric.page_suffix"

            // 範圍 tabs
            static let rangeWeeks8 = "app2.metric.range_weeks8"
            static let rangeWeeks26 = "app2.metric.range_weeks26"
            static let rangeYear = "app2.metric.range_year"
            static let rangeDays60 = "app2.metric.range_days60"
            static let rangeMonths6 = "app2.metric.range_months6"
            static let rangeAll = "app2.metric.range_all"

            // §51 訓練量
            static let volumeHeroTitle = "app2.metric.volume_hero_title"
            static let volumeTarget = "app2.metric.volume_target"
            /// 圖上目標線的標籤（`目標 30`）。
            static let volumeTargetLineFormat = "app2.metric.volume_target_line_format"
            /// `%d 週平均` —— 週數是**完整週的實際數量**，不寫死 8。
            static let volumeAverageFormat = "app2.metric.volume_average_format"
            static let volumeYtd = "app2.metric.volume_ytd"
            static let volumePeak = "app2.metric.volume_peak"
            static let volumeLoadTitle = "app2.metric.volume_load_title"
            static let volumeTsbBaseline = "app2.metric.volume_tsb_baseline"
            static let volumeCtl = "app2.metric.volume_ctl"
            static let volumeAtl = "app2.metric.volume_atl"
            static let volumeTsb = "app2.metric.volume_tsb"
            static let volumeSource = "app2.metric.volume_source"

            // §52 能力基準
            static let capabilityHeroTitle = "app2.metric.capability_hero_title"
            static let capabilityCompare = "app2.metric.capability_compare"
            /// `39.0（−0.3）`
            static let capabilityCompareFormat = "app2.metric.capability_compare_format"
            static let capabilityChartTitle = "app2.metric.capability_chart_title"
            static let capabilityAnchorMarker = "app2.metric.capability_anchor_marker"
            /// 圖上虛線段（未來預估）的圖例（2026-08-27 晚走查裁決（f））。
            static let projectedLegend = "app2.metric.projected_legend"
            /// `指標跑（8/2）`
            static let capabilityAnchorFormat = "app2.metric.capability_anchor_format"
            static let capabilityHowTitle = "app2.metric.capability_how_title"
            static let capabilityRowAnchor = "app2.metric.capability_row_anchor"
            static let capabilityRowDecision = "app2.metric.capability_row_decision"
            static let capabilityRowEvidence = "app2.metric.capability_row_evidence"
            static let capabilityRowConfidence = "app2.metric.capability_row_confidence"
            static let capabilityEvidenceCountFormat = "app2.metric.capability_evidence_count_format"
            static let capabilitySource = "app2.metric.capability_source"

            static let confidenceHigh = "app2.metric.confidence_high"
            static let confidenceMedium = "app2.metric.confidence_medium"
            static let confidenceLow = "app2.metric.confidence_low"
            static let vdotSourceBenchmark = "app2.metric.vdot_source_benchmark"
            static let vdotSourcePersonalBest = "app2.metric.vdot_source_personal_best"
            static let vdotSourceEstimated = "app2.metric.vdot_source_estimated"

            // §53 恢復
            static let recoveryHeroTitle = "app2.metric.recovery_hero_title"
            static let recoveryBaseline = "app2.metric.recovery_baseline"
            static let recoveryChartTitle = "app2.metric.recovery_chart_title"
            static let recoveryHrv = "app2.metric.recovery_hrv"
            static let recoveryRhr = "app2.metric.recovery_rhr"
            static let recoveryStatHrv = "app2.metric.recovery_stat_hrv"
            static let recoveryStatRhr = "app2.metric.recovery_stat_rhr"
            static let recoveryStatTrend = "app2.metric.recovery_stat_trend"
            static let recoveryTrendUp = "app2.metric.recovery_trend_up"
            static let recoveryTrendFlat = "app2.metric.recovery_trend_flat"
            static let recoveryTrendDown = "app2.metric.recovery_trend_down"
            static let recoverySource = "app2.metric.recovery_source"
        }

        /// 計畫結束態（設計 frame-00g 首頁結束態／兩種語意，frame-00g2 整期總結
        /// 故事版＋課表 tab 結束態）。
        ///
        /// 沿用既有詞的不在這裡開第二份：`目標` 走 `app2.home.goal_target`、
        /// `完成率` 走 `app2.weekly_review.completion_rate`、`VDOT` 是專有名詞
        /// （`Text(verbatim:)`，不進 .strings）。
        enum PlanEnd {
            /// 結束語意 chip：race＝「備賽完成」、maintenance＝「訓練期完成」。
            static let chipRace = "app2.plan_end.chip_race"
            static let chipMaintenance = "app2.plan_end.chip_maintenance"
            /// race 大標下的那一行：`%d 週備賽完成`。
            static let raceHeadlineFormat = "app2.plan_end.race_headline_format"
            /// maintenance 沒有賽名，大標是 `%d 週維持計畫`＋副標「訓練期完成」。
            static let maintenanceTitleFormat = "app2.plan_end.maintenance_title_format"
            static let maintenanceHeadline = "app2.plan_end.maintenance_headline"

            /// hero 右欄：有實際成績時的標籤。**目前沒有 producer**（無賽事成績綁定），
            /// 留著是因為降級規則要指得出「降級到什麼」。
            static let actualFinish = "app2.plan_end.actual_finish"
            /// 降級後的右欄標籤。**不是 `app2.home.goal_estimate`（預估完賽）**：
            /// 計畫已經走完，這個量講的是「當時推到哪」，不是「現在能跑幾分」。
            static let estimateThen = "app2.plan_end.estimate_then"
            /// 標明它屬 readiness 流（`AGENTS.md` 兩條資料流：跨流不得互相佐證）。
            static let estimateNote = "app2.plan_end.estimate_note"
            /// `距目標 %@`
            static let deltaTargetFormat = "app2.plan_end.delta_target_format"
            /// `目標 %@`
            static let targetTimeFormat = "app2.plan_end.target_time_format"
            /// 實際成績的來源 chip（隨成績一起出現，成績缺席時整組不畫）。
            static let finishSource = "app2.plan_end.finish_source"

            /// CTA：導**既有**的重設目標流程，不做新的目標選擇 UI。
            static let ctaNewGoal = "app2.plan_end.cta_new_goal"
            static let ctaNewGoalSub = "app2.plan_end.cta_new_goal_sub"
            static let summaryEntry = "app2.plan_end.summary_entry"
            static let summaryEntrySub = "app2.plan_end.summary_entry_sub"

            // MARK: 整期總結頁
            static let summaryTitle = "app2.plan_end.summary_title"
            /// 降級 chip：敘事端點未落地時掛在 header 右上。
            static let degradedChip = "app2.plan_end.degraded_chip"
            static let statTotalDistance = "app2.plan_end.stat_total_distance"
            static let statSessions = "app2.plan_end.stat_sessions"
            static let statTotalTime = "app2.plan_end.stat_total_time"
            static let statLongest = "app2.plan_end.stat_longest"
            static let statPeakWeek = "app2.plan_end.stat_peak_week"
            /// `每週跑量 · %d 週`
            static let weeklyChartTitleFormat = "app2.plan_end.weekly_chart_title_format"
            /// 柱狀圖底行：`峰值週 %@` / `累積 %@`
            static let peakWeekFormat = "app2.plan_end.peak_week_format"
            static let cumulativeFormat = "app2.plan_end.cumulative_format"
            static let capabilityTitle = "app2.plan_end.capability_title"

            // MARK: 故事版（frame-00g2（a））
            /// `這 %d 週的故事`
            static let storySectionFormat = "app2.plan_end.story_section_format"
            static let storySectionSub = "app2.plan_end.story_section_sub"
            /// 心得引用卡的標（琥珀底）。
            static let quoteLabel = "app2.plan_end.quote_label"
            /// 首頁 Rizo 敘事子卡的標。
            static let narrativeChip = "app2.plan_end.narrative_chip"

            // MARK: 課表 tab 結束態（frame-00g2（c producer））
            static let planTabSubtitle = "app2.plan_end.plan_tab_subtitle"
            static let planCompleteChip = "app2.plan_end.plan_complete_chip"
            static let planCompleteRace = "app2.plan_end.plan_complete_race"
            static let planCompleteMaintenance = "app2.plan_end.plan_complete_maintenance"
            /// `%1$d / %2$d 週`
            static let weeksProgressFormat = "app2.plan_end.weeks_progress_format"
            /// 三段小計各自一個 format，畫面上用 ` · ` 串 —— 缺哪一段就少那一段，
            /// 不用一個帶三個佔位符的長字串（那樣缺一個就整行不能出）。
            static let sessionsCountFormat = "app2.plan_end.sessions_count_format"
            static let completionRateFormat = "app2.plan_end.completion_rate_format"
            static let peakFormat = "app2.plan_end.peak_format"
            /// 課表 tab 結束態的 Rizo 一句話。**設計稿的靜態教練建議**，不是 payload
            /// 欄位（同 `app2.session.fueling_note` 的先例）。
            static let rizoLine = "app2.plan_end.rizo_line"
            /// 歷史課表回看（2026-08-27 裁決（e））：結束卡上的入口列、歷史模式的返程列，
            /// 以及該週從沒生成過課表（404）時的空態。三條與 Android 的
            /// `app2_plan_end_tab_history` / `_history_back` 同文案。
            static let historyEntry = "app2.plan_end.history_entry"
            static let historyBack = "app2.plan_end.history_back"
            static let historyBackCurrentWeek = "app2.plan_end.history_back_current_week"
            static let historyWeekEmpty = "app2.plan_end.history_week_empty"
        }

        enum Achievements {
            static let title = "app2.achievements.title"
            static let latestUnlock = "app2.achievements.latest_unlock"
            static let nextGoal = "app2.achievements.next_goal"
            static let personalBests = "app2.achievements.personal_bests"
            static let badges = "app2.achievements.badges"
            /// 「還差 %@」（設計 frame-11 的量化列）。既有的 `achievements.hero_card.remaining`
            /// 是單獨的詞，英文當前綴不成句，所以這裡是 format 而不是重複那個詞。
            static let remainingFormat = "app2.achievements.remaining_format"
            static let seeMore = "app2.achievements.see_more"
            /// 換展示徽章的確認框（設計包沒定義，是補缺口；與 Android 對齊）。
            static let setDisplayTitle = "app2.achievements.set_display_title"
            static let setDisplayBody = "app2.achievements.set_display_body"
            static let setDisplayAction = "app2.achievements.set_display_action"
        }

        enum Settings {
            static let title = "app2.settings.title"
            static let manageSubscription = "app2.settings.manage_subscription"
            /// 訂閱卡第二行的前綴（2026-08-27 晚走查裁決（h））。
            static let nextRenewal = "app2.settings.next_renewal"
            static let viewPlans = "app2.settings.view_plans"
            static let redeemCode = "app2.settings.redeem_code"
            /// 訓練日之間的分隔符（設計 frame-21 是「一・三・四」）。
            static let trainingDaysSeparator = "app2.settings.training_days_separator"
            static let accountSection = "app2.settings.account_section"
            static let subscriptionSection = "app2.settings.subscription_section"
            static let dataSourceSection = "app2.settings.data_source_section"
            static let trainingSection = "app2.settings.training_section"
            static let weeklyDistance = "app2.settings.weekly_distance"
            static let trainingDays = "app2.settings.training_days"
            static let raceCountdown = "app2.settings.race_countdown"
            static let notConnected = "app2.settings.not_connected"
            static let connected = "app2.settings.connected"
            /// 訂閱卡的「續訂中」狀態；其餘狀態沿用既有的 `profile.subscription.*`。
            static let subscriptionActive = "app2.settings.subscription_active"
            /// 「重新設定目標賽事」——導既有的目標設定流程，不重做一份。
            static let resetGoalRace = "app2.settings.reset_goal_race"
            static let goalSection = "app2.settings.goal_section"
            static let systemSection = "app2.settings.system_section"
            static let heatAdaptationSub = "app2.settings.heat_adaptation_sub"

            // MARK: 方案與訂閱（frame-22）
            static let plansTitle = "app2.settings.plans_title"
            static let planFree = "app2.settings.plan_free"
            static let planFreePrice = "app2.settings.plan_free_price"
            static let planFreeFeature1 = "app2.settings.plan_free_feature1"
            static let planFreeFeature2 = "app2.settings.plan_free_feature2"
            static let planFreeFeature3 = "app2.settings.plan_free_feature3"
            static let planProFeature1 = "app2.settings.plan_pro_feature1"
            static let planProFeature2 = "app2.settings.plan_pro_feature2"
            static let planProFeature3 = "app2.settings.plan_pro_feature3"
            static let planCurrentBadge = "app2.settings.plan_current_badge"
            static let currentSubscription = "app2.settings.current_subscription"
            static let planRow = "app2.settings.plan_row"
            static let cancelSubscription = "app2.settings.cancel_subscription"

            // MARK: 訓練設定（frame-23）
            /// 單位、建議帶、天數提示、長跑日一律沿用 `app2.onboarding.*` 既有字
            /// （frame-23 與 frame-37／38 是同一組詞），不另造第二份。
            static let targetWeeklyDistance = "app2.settings.target_weekly_distance"

            // MARK: 數據來源（frame-24／25）
            static let dataSourceIntro = "app2.settings.data_source_intro"
            static let dataSourcePrivacy = "app2.settings.data_source_privacy"
            static let disconnect = "app2.settings.disconnect"
            static let noSourceTitle = "app2.settings.no_source_title"
            static let noSourceBody = "app2.settings.no_source_body"

            // MARK: 心率區間（frame-26）
            static let hrIntro = "app2.settings.hr_intro"
            static let hrZonesTitle = "app2.settings.hr_zones_title"
            static let hrFootnote = "app2.settings.hr_footnote"

            // MARK: 配速區間（frame-27）
            static let vdotValue = "app2.settings.vdot_value"
            static let vdotNote = "app2.settings.vdot_note"
            static let paceListTitle = "app2.settings.pace_list_title"
            static let vdotUnavailable = "app2.settings.vdot_unavailable"

            // MARK: 系統（frame-28）
            static let unitSection = "app2.settings.unit_section"
            static let distanceUnit = "app2.settings.distance_unit"
            static let unitNote = "app2.settings.unit_note"
            /// 切換鈕上的短標（既有的 `unit.metric` 是「公制（公里）」，塞不進膠囊）。
            static let unitMetric = "app2.settings.unit_metric"
            static let unitImperial = "app2.settings.unit_imperial"

            // MARK: 刪除帳戶（frame-29）
            static let deleteConfirmTitle = "app2.settings.delete_confirm_title"
            static let deleteConfirmBody = "app2.settings.delete_confirm_body"
            static let deleteItemWorkouts = "app2.settings.delete_item_workouts"
            static let deleteItemAchievements = "app2.settings.delete_item_achievements"
            static let deleteItemDataSources = "app2.settings.delete_item_data_sources"
            static let deleteSubscriptionNote = "app2.settings.delete_subscription_note"
            /// `輸入 %@ 以確認`
            static let deleteTypeHint = "app2.settings.delete_type_hint"
            /// 使用者要輸入的確認詞（三語各自不同，所以是可在地化字串）。
            static let deleteKeyword = "app2.settings.delete_keyword"
            static let deletePermanent = "app2.settings.delete_permanent"
        }

        /// 2.0 onboarding（設計 frame-30 ~ frame-39）。
        /// 流程邏輯沿用既有 `OnboardingCoordinator`／`OnboardingFeatureViewModel`，
        /// 這裡只有 2.0 版面新出現的字。既有詞（weekday.*、distance.*、
        /// onboarding.analyzing_preferences…）不重造。
        enum Onboarding {
            // 共用外殼
            static let segGoal = "app2.onboarding.seg_goal"
            static let segTraining = "app2.onboarding.seg_training"
            static let segPlan = "app2.onboarding.seg_plan"
            /// `第 %1$d / %2$d 段`
            static let stepFormat = "app2.onboarding.step_format"
            static let continueCta = "app2.onboarding.continue"
            static let back = "app2.onboarding.back"

            // frame-30 開場
            static let welcomeTitle = "app2.onboarding.welcome_title"
            static let welcomeSubtitle = "app2.onboarding.welcome_subtitle"
            static let welcomeStep1Title = "app2.onboarding.welcome_step1_title"
            static let welcomeStep1Body = "app2.onboarding.welcome_step1_body"
            static let welcomeStep2Title = "app2.onboarding.welcome_step2_title"
            static let welcomeStep2Body = "app2.onboarding.welcome_step2_body"
            static let welcomeStep3Title = "app2.onboarding.welcome_step3_title"
            static let welcomeStep3Body = "app2.onboarding.welcome_step3_body"
            static let welcomeNote = "app2.onboarding.welcome_note"
            static let welcomeCta = "app2.onboarding.welcome_cta"
            static let welcomeDuration = "app2.onboarding.welcome_duration"

            // frame-31 目標類型
            static let goalTitle = "app2.onboarding.goal_title"
            static let goalSubtitle = "app2.onboarding.goal_subtitle"
            static let goalRaceTitle = "app2.onboarding.goal_race_title"
            static let goalRaceBody = "app2.onboarding.goal_race_body"
            static let goalMaintenanceTitle = "app2.onboarding.goal_maintenance_title"
            static let goalMaintenanceBody = "app2.onboarding.goal_maintenance_body"
            static let goalBeginnerTitle = "app2.onboarding.goal_beginner_title"
            static let goalBeginnerBody = "app2.onboarding.goal_beginner_body"

            // frame-32 目標賽事
            static let raceTitle = "app2.onboarding.race_title"
            static let raceSubtitle = "app2.onboarding.race_subtitle"
            static let raceSupported = "app2.onboarding.race_supported"
            static let raceSearch = "app2.onboarding.race_search"
            static let raceSetAsGoal = "app2.onboarding.race_set_as_goal"
            static let raceGoalBadge = "app2.onboarding.race_goal_badge"
            /// `%d 週後`
            static let raceWeeksAway = "app2.onboarding.race_weeks_away"
            static let raceManualDivider = "app2.onboarding.race_manual_divider"
            static let raceNamePlaceholder = "app2.onboarding.race_name_placeholder"
            static let raceTargetTime = "app2.onboarding.race_target_time"
            static let raceHour = "app2.onboarding.race_hour"
            static let raceMinute = "app2.onboarding.race_minute"
            static let raceSecond = "app2.onboarding.race_second"
            static let raceCustomDistance = "app2.onboarding.race_custom_distance"

            // frame-33 心率
            static let hrTitle = "app2.onboarding.hr_title"
            static let hrSubtitle = "app2.onboarding.hr_subtitle"
            static let hrMax = "app2.onboarding.hr_max"
            static let hrResting = "app2.onboarding.hr_resting"
            static let hrBpm = "app2.onboarding.hr_bpm"
            static let hrMaxHint = "app2.onboarding.hr_max_hint"
            static let hrRestingHint = "app2.onboarding.hr_resting_hint"
            static let hrBandsTitle = "app2.onboarding.hr_bands_title"
            static let hrBandsFooter = "app2.onboarding.hr_bands_footer"
            static let hrBandRecovery = "app2.onboarding.hr_band_recovery"
            static let hrBandEndurance = "app2.onboarding.hr_band_endurance"
            static let hrBandTempo = "app2.onboarding.hr_band_tempo"
            static let hrBandThreshold = "app2.onboarding.hr_band_threshold"
            static let hrBandAnaerobic = "app2.onboarding.hr_band_anaerobic"

            // frame-34 連結裝置
            static let deviceTitle = "app2.onboarding.device_title"
            static let deviceSubtitle = "app2.onboarding.device_subtitle"
            static let deviceConnected = "app2.onboarding.device_connected"
            static let deviceDisconnect = "app2.onboarding.device_disconnect"
            static let deviceConnect = "app2.onboarding.device_connect"
            static let deviceAppleHealthSub = "app2.onboarding.device_apple_health_sub"
            static let deviceGarminSub = "app2.onboarding.device_garmin_sub"
            static let deviceSyncing = "app2.onboarding.device_syncing"
            /// `%@ 已連結`
            static let deviceSyncNoteTitle = "app2.onboarding.device_sync_note_title"
            static let deviceSyncNoteBody = "app2.onboarding.device_sync_note_body"
            static let devicePrivacy = "app2.onboarding.device_privacy"
            static let deviceSkip = "app2.onboarding.device_skip"

            // frame-35 近期成績
            static let resultTitle = "app2.onboarding.result_title"
            static let resultSubtitle = "app2.onboarding.result_subtitle"
            static let resultDistance = "app2.onboarding.result_distance"
            static let resultFinishTime = "app2.onboarding.result_finish_time"
            static let resultAvgPace = "app2.onboarding.result_avg_pace"
            static let resultVdot = "app2.onboarding.result_vdot"
            static let resultWhen = "app2.onboarding.result_when"
            static let resultWithinYear = "app2.onboarding.result_within_year"
            static let resultOverYear = "app2.onboarding.result_over_year"
            static let resultOverYearNote = "app2.onboarding.result_over_year_note"
            static let resultSkip = "app2.onboarding.result_skip"

            // frame-36 訓練方法
            static let methodTitle = "app2.onboarding.method_title"
            static let methodSubtitle = "app2.onboarding.method_subtitle"
            static let methodRecommended = "app2.onboarding.method_recommended"
            static let methodPickOwn = "app2.onboarding.method_pick_own"

            // frame-37 訓練日
            static let daysTitle = "app2.onboarding.days_title"
            static let daysSubtitle = "app2.onboarding.days_subtitle"
            /// `已選 %1$d 天 · 建議每週 %2$d–%3$d 天`
            static let daysSelectedFormat = "app2.onboarding.days_selected_format"
            static let daysLongRun = "app2.onboarding.days_long_run"
            static let daysLongRunNote = "app2.onboarding.days_long_run_note"
            static let daysNote = "app2.onboarding.days_note"

            // frame-38 跑量確認
            static let mileageTitle = "app2.onboarding.mileage_title"
            static let mileageSubtitle = "app2.onboarding.mileage_subtitle"
            /// `來自你的 %@ 跑步紀錄`
            static let mileageSourceFormat = "app2.onboarding.mileage_source_format"
            static let mileageRecentAvg = "app2.onboarding.mileage_recent_avg"
            /// 沒有同步紀錄時的替代標題（那個數字是預設值，不是平均）。
            static let mileageManualLabel = "app2.onboarding.mileage_manual_label"
            static let mileageUnit = "app2.onboarding.mileage_unit"
            static let mileageConfirmQuestion = "app2.onboarding.mileage_confirm_question"
            static let mileageAboutRight = "app2.onboarding.mileage_about_right"
            static let mileageAdjust = "app2.onboarding.mileage_adjust"
            static let mileageSliderTitle = "app2.onboarding.mileage_slider_title"
            /// `建議 %1$d–%2$d`
            static let mileageSuggestedFormat = "app2.onboarding.mileage_suggested_format"
            static let mileageStart = "app2.onboarding.mileage_start"
            static let mileagePeak = "app2.onboarding.mileage_peak"
            static let mileageNote = "app2.onboarding.mileage_note"
            static let mileageCta = "app2.onboarding.mileage_cta"
            static let mileageNoHistory = "app2.onboarding.mileage_no_history"

            // frame-39 完成
            static let doneBadge = "app2.onboarding.done_badge"
            static let doneKicker = "app2.onboarding.done_kicker"
            /// `%d 週的訓練計畫`
            static let doneWeeksFormat = "app2.onboarding.done_weeks_format"
            static let doneGoalRace = "app2.onboarding.done_goal_race"
            /// `還有 %d 週`
            static let doneRemainingWeeksFormat = "app2.onboarding.done_remaining_weeks_format"
            static let doneNow = "app2.onboarding.done_now"
            static let doneTarget = "app2.onboarding.done_target"
            /// `這 %d 週怎麼安排`
            static let doneStagesTitleFormat = "app2.onboarding.done_stages_title_format"
            static let doneStagesSubtitle = "app2.onboarding.done_stages_subtitle"
            /// `W%1$d–%2$d`
            static let doneWeekRangeFormat = "app2.onboarding.done_week_range_format"
            static let doneCta = "app2.onboarding.done_cta"
            static let doneGenerating = "app2.onboarding.done_generating"
            /// `%@ 完賽`
            static let doneFinishSuffix = "app2.onboarding.done_finish_suffix"
            static let doneRhythmTitle = "app2.onboarding.done_rhythm_title"
            static let doneRhythmDays = "app2.onboarding.done_rhythm_days"
            /// `%d 天`
            static let doneRhythmDaysFormat = "app2.onboarding.done_rhythm_days_format"
            static let doneRhythmLongRun = "app2.onboarding.done_rhythm_long_run"
            static let doneRhythmMethod = "app2.onboarding.done_rhythm_method"
            static let doneFooterNote = "app2.onboarding.done_footer_note"
            /// `約 %d km / 週`
            static let doneWeeklyKmFormat = "app2.onboarding.done_weekly_km_format"
        }

        enum Common {
            static let stubBadge = "app2.common.stub_badge"
            static let stubFooter = "app2.common.stub_footer"
            static let noData = "app2.common.no_data"
            static let loadFailed = "app2.common.load_failed"
            static let retry = "app2.common.retry"
            static let usingSample = "app2.common.using_sample"
            static let settingsEntry = "app2.common.settings_entry"
        }
    }
}
