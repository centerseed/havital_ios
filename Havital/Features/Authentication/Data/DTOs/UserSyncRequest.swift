import Foundation

// MARK: - User Sync Request DTO
/// Data Transfer Object for syncing Firebase user with backend
/// Maps to backend API: POST /auth/sync
struct UserSyncRequest: Codable {
    // MARK: - Required Fields

    /// Firebase user unique identifier
    let firebaseUid: String

    /// Firebase ID Token for authentication
    let idToken: String

    // MARK: - Optional Fields

    /// FCM push notification token
    let fcmToken: String?

    /// Device information for analytics
    let deviceInfo: DeviceInfo?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case firebaseUid = "firebase_uid"
        case idToken = "id_token"
        case fcmToken = "fcm_token"
        case deviceInfo = "device_info"
    }

    // MARK: - Initialization

    init(
        firebaseUid: String,
        idToken: String,
        fcmToken: String? = nil,
        deviceInfo: DeviceInfo? = nil
    ) {
        self.firebaseUid = firebaseUid
        self.idToken = idToken
        self.fcmToken = fcmToken
        self.deviceInfo = deviceInfo
    }
}

// MARK: - Device Info DTO
/// Device information for user sync request
struct DeviceInfo: Codable {
    /// Device model (e.g., "iPhone 15 Pro")
    let model: String?

    /// iOS version (e.g., "17.0")
    let osVersion: String?

    /// App version (e.g., "1.0.0")
    let appVersion: String?

    /// Device locale (e.g., "en_US")
    let locale: String?

    enum CodingKeys: String, CodingKey {
        case model
        case osVersion = "os_version"
        case appVersion = "app_version"
        case locale
    }

    init(
        model: String? = nil,
        osVersion: String? = nil,
        appVersion: String? = nil,
        locale: String? = nil
    ) {
        self.model = model
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.locale = locale
    }
}
