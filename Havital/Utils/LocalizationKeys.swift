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
        }
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
        static let viewDetails = "record.view_details"
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