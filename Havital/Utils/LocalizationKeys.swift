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