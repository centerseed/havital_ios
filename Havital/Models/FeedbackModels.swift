import Foundation
import UIKit

// MARK: - Feedback Type

enum FeedbackType: String, Codable, CaseIterable {
    case issue = "issue"
    case suggestion = "suggestion"

    var displayName: String {
        switch self {
        case .issue:
            return NSLocalizedString("feedback.type.issue", comment: "Issue")
        case .suggestion:
            return NSLocalizedString("feedback.type.suggestion", comment: "Suggestion")
        }
    }
}

// MARK: - Feedback Category

enum FeedbackCategory: String, Codable, CaseIterable {
    case weeklyPlan = "weekly_plan"
    case weeklyReview = "weekly_review"
    case trainingOverview = "training_overview"
    case other = "other"

    var displayName: String {
        switch self {
        case .weeklyPlan:
            return NSLocalizedString("feedback.category.weekly_plan_failed", comment: "Weekly Plan Generation Failed")
        case .weeklyReview:
            return NSLocalizedString("feedback.category.weekly_summary_failed", comment: "Weekly Summary Generation Failed")
        case .trainingOverview:
            return NSLocalizedString("feedback.category.training_overview_failed", comment: "Training Overview Generation Failed")
        case .other:
            return NSLocalizedString("feedback.category.other", comment: "Other")
        }
    }
}

// MARK: - Feedback Request

struct FeedbackRequest: Codable {
    let type: String
    let category: String
    let description: String
    let email: String
    let appVersion: String
    let deviceInfo: String
    let images: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case category
        case description
        case email
        case appVersion = "app_version"
        case deviceInfo = "device_info"
        case images
    }
}

// MARK: - Feedback Response

struct FeedbackResponse: Codable {
    let issueNumber: Int
    let issueUrl: String

    enum CodingKeys: String, CodingKey {
        case issueNumber = "issue_number"
        case issueUrl = "issue_url"
    }
}

// MARK: - Device Info Helper

struct DeviceInfoHelper {
    static func getDeviceInfo() -> String {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let modelName = getModelName()
        return "\(modelName) / iOS \(systemVersion)"
    }

    private static func getModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapToDeviceName(identifier: identifier)
    }

    private static func mapToDeviceName(identifier: String) -> String {
        switch identifier {
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        default:
            if identifier.hasPrefix("iPhone") {
                return "iPhone"
            } else if identifier.hasPrefix("iPad") {
                return "iPad"
            }
            return identifier
        }
    }
}

// MARK: - App Version Helper

struct AppVersionHelper {
    static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}
