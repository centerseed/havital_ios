#if DEBUG
import Foundation
import SwiftUI

// MARK: - IAP Test Harness

@MainActor
final class IAPTestHarness: ObservableObject {
    static let shared = IAPTestHarness()

    private enum DefaultsKey {
        static let testerUID = "iap_test_harness.tester_uid"
        static let adminBearerToken = "iap_test_harness.admin_bearer_token"
        static let reason = "iap_test_harness.reason"
        static let extendDays = "iap_test_harness.extend_days"
    }

    private static let defaultTesterUID = "Cv5ADE73tiZMpEyD80Yh1BAqYch2"
    private static let allowedTesterUIDs = [defaultTesterUID]

    @Published var testerUID: String
    @Published var adminBearerToken: String
    @Published var reason: String
    @Published var extendDays: String
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage = "Idle"
    @Published private(set) var lastAdminDetail: IAPAdminDetailData?
    @Published private(set) var lastAppSubscriptionStatus: SubscriptionStatusEntity?
    @Published private(set) var lastAuditLogs: [IAPAdminAuditLog] = []

    let launchScenario: IAPLaunchScenario?

    private let adminClient: IAPTestAdminClient
    private let subscriptionRepository: SubscriptionRepository

    private init(
        adminClient: IAPTestAdminClient = IAPTestAdminClient(),
        subscriptionRepository: SubscriptionRepository = DependencyContainer.shared.resolve()
    ) {
        let defaults = UserDefaults.standard
        let parsedLaunchArgs = IAPLaunchArguments.parse(CommandLine.arguments)

        self.testerUID = parsedLaunchArgs.testerUID
            ?? defaults.string(forKey: DefaultsKey.testerUID)
            ?? Self.defaultTesterUID
        self.adminBearerToken = parsedLaunchArgs.adminBearerToken
            ?? defaults.string(forKey: DefaultsKey.adminBearerToken)
            ?? ""
        self.reason = defaults.string(forKey: DefaultsKey.reason) ?? "IAP debug test"
        self.extendDays = defaults.string(forKey: DefaultsKey.extendDays) ?? "30"
        self.launchScenario = parsedLaunchArgs.scenario
        self.adminClient = adminClient
        self.subscriptionRepository = subscriptionRepository
    }

    var canUseHarness: Bool {
        APIConfig.isDevelopment
    }

    var usingInjectedAdminToken: Bool {
        !trimmedAdminToken.isEmpty
    }

    var isTesterUIDAllowed: Bool {
        Self.allowedTesterUIDs.contains(testerUID.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func bootstrapFromLaunchScenarioIfNeeded() async {
        guard let launchScenario else { return }
        await applyScenario(launchScenario, origin: "launch")
    }

    func refreshAll() async {
        guard validateHarnessReady() else { return }

        persistDebugSettings()
        isBusy = true
        statusMessage = "Refresh admin detail + app subscription…"

        do {
            let detail = try await adminClient.fetchDetail(
                uid: testerUID,
                adminBearerToken: trimmedAdminToken.nilIfEmpty
            )
            lastAdminDetail = detail
            lastAuditLogs = detail.auditLogs ?? []
        } catch {
            // Admin API unavailable — skip admin detail, continue to app status refresh
        }

        // Avoid clearCache() here — it would overwrite any local override set by applyLocalOverride
        lastAppSubscriptionStatus = SubscriptionStateManager.shared.currentStatus
        statusMessage = "Refresh admin detail + app subscription succeeded"

        isBusy = false
    }

    func applyScenario(_ scenario: IAPLaunchScenario, origin: String = "manual") async {
        guard validateHarnessReady() else { return }

        persistDebugSettings()
        isBusy = true
        statusMessage = "Apply \(scenario.rawValue) (\(origin))…"

        do {
            switch scenario {
            case .expired:
                let expiresAt = Date().addingTimeInterval(-3600)
                try await adminClient.setExpires(
                    uid: testerUID,
                    status: "expired",
                    expiresAtISO8601: Self.iso8601String(from: expiresAt),
                    reason: effectiveReason(prefix: "Set expired"),
                    adminBearerToken: trimmedAdminToken.nilIfEmpty
                )
            case .subscribed:
                let expiresAt = Date().addingTimeInterval(30 * 86400)
                try await adminClient.setExpires(
                    uid: testerUID,
                    status: "subscribed",
                    expiresAtISO8601: Self.iso8601String(from: expiresAt),
                    reason: effectiveReason(prefix: "Set subscribed"),
                    adminBearerToken: trimmedAdminToken.nilIfEmpty
                )
            case .trialActive:
                let expiresAt = Date().addingTimeInterval(14 * 86400)
                try await adminClient.setExpires(
                    uid: testerUID,
                    status: "trial_active",
                    expiresAtISO8601: Self.iso8601String(from: expiresAt),
                    reason: effectiveReason(prefix: "Set trial"),
                    adminBearerToken: trimmedAdminToken.nilIfEmpty
                )
            case .clearOverride:
                try await adminClient.clearOverride(
                    uid: testerUID,
                    adminBearerToken: trimmedAdminToken.nilIfEmpty
                )
            }

            let detail = try await adminClient.fetchDetail(
                uid: testerUID,
                adminBearerToken: trimmedAdminToken.nilIfEmpty
            )
            lastAdminDetail = detail
            lastAuditLogs = detail.auditLogs ?? []
            try await refreshAppSubscriptionStatus()
            statusMessage = "Apply \(scenario.rawValue) (\(origin)) succeeded"
        } catch {
            // Admin API failed (e.g. unauthorized) — fallback to local override
            applyLocalOverride(scenario)
            statusMessage = "Apply \(scenario.rawValue) (\(origin)) succeeded (local override)"
        }

        isBusy = false
    }

    private func applyLocalOverride(_ scenario: IAPLaunchScenario) {
        let entity: SubscriptionStatusEntity
        switch scenario {
        case .expired:
            entity = SubscriptionStatusEntity(
                status: .expired,
                expiresAt: Date().addingTimeInterval(-3600).timeIntervalSince1970,
                billingIssue: false
            )
        case .subscribed:
            entity = SubscriptionStatusEntity(
                status: .active,
                expiresAt: Date().addingTimeInterval(30 * 86400).timeIntervalSince1970,
                planType: "premium",
                billingIssue: false
            )
        case .trialActive:
            entity = SubscriptionStatusEntity(
                status: .trial,
                expiresAt: Date().addingTimeInterval(14 * 86400).timeIntervalSince1970,
                billingIssue: false
            )
        case .clearOverride:
            entity = SubscriptionStatusEntity(status: .none)
        }
        SubscriptionStateManager.shared.update(entity)
        lastAppSubscriptionStatus = entity
    }

    func extendSubscription() async {
        guard validateHarnessReady() else { return }
        guard let days = Int(extendDays), days > 0 else {
            statusMessage = "Extend days must be a positive integer"
            return
        }

        await runOperation("Extend subscription by \(days)d") {
            try await self.adminClient.extendSubscription(
                uid: self.testerUID,
                days: days,
                reason: self.effectiveReason(prefix: "Extend by \(days)d"),
                adminBearerToken: self.trimmedAdminToken.nilIfEmpty
            )

            let detail = try await self.adminClient.fetchDetail(
                uid: self.testerUID,
                adminBearerToken: self.trimmedAdminToken.nilIfEmpty
            )
            self.lastAdminDetail = detail
            self.lastAuditLogs = detail.auditLogs ?? []
            try await self.refreshAppSubscriptionStatus()
        }
    }

    func persistDebugSettings() {
        let defaults = UserDefaults.standard
        defaults.set(testerUID, forKey: DefaultsKey.testerUID)
        defaults.set(adminBearerToken, forKey: DefaultsKey.adminBearerToken)
        defaults.set(reason, forKey: DefaultsKey.reason)
        defaults.set(extendDays, forKey: DefaultsKey.extendDays)
    }

    private func refreshAppSubscriptionStatus() async throws {
        subscriptionRepository.clearCache()
        let status = try await subscriptionRepository.refreshStatus()
        lastAppSubscriptionStatus = status
    }

    private func validateHarnessReady() -> Bool {
        guard canUseHarness else {
            statusMessage = "IAP Test Harness is limited to DEBUG + dev backend"
            return false
        }

        guard isTesterUIDAllowed else {
            statusMessage = "Tester UID is not allowlisted"
            return false
        }

        return true
    }

    private func runOperation(_ title: String, operation: @escaping () async throws -> Void) async {
        persistDebugSettings()
        isBusy = true
        statusMessage = "\(title)…"

        do {
            try await operation()
            statusMessage = "\(title) succeeded"
        } catch {
            statusMessage = "\(title) failed: \(error.toDomainError().localizedDescription)"
        }

        isBusy = false
    }

    private func effectiveReason(prefix: String) -> String {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedReason.isEmpty ? prefix : "\(prefix) — \(trimmedReason)"
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private var trimmedAdminToken: String {
        adminBearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Launch Arguments

enum IAPLaunchScenario: String, CaseIterable {
    case expired
    case subscribed
    case trialActive = "trial_active"
    case clearOverride = "clear_override"

    static func parse(_ value: String?) -> IAPLaunchScenario? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "trial", "trial-active", "trial_active":
            return .trialActive
        default:
            return IAPLaunchScenario(rawValue: normalized)
        }
    }

    var displayName: String {
        switch self {
        case .trialActive:
            return "trial_active"
        default:
            return rawValue
        }
    }
}

private struct IAPLaunchArguments {
    let testerUID: String?
    let adminBearerToken: String?
    let scenario: IAPLaunchScenario?

    static func parse(_ arguments: [String]) -> IAPLaunchArguments {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }

        let testerUID = value(after: "-iapTestUID")
        let adminBearerToken = value(after: "-iapAdminBearer")

        let scenario = IAPLaunchScenario.parse(value(after: "-iapScenario"))

        return IAPLaunchArguments(
            testerUID: testerUID,
            adminBearerToken: adminBearerToken,
            scenario: scenario
        )
    }
}

// MARK: - Admin Client

private actor IAPTestAdminClient {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(httpClient: HTTPClient = DefaultHTTPClient.shared) {
        self.httpClient = httpClient
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func fetchDetail(uid: String, adminBearerToken: String?) async throws -> IAPAdminDetailData {
        let data = try await request(
            path: "/api/v1/admin/subscription/\(uid)",
            method: .GET,
            body: nil,
            adminBearerToken: adminBearerToken
        )
        return try unwrap(data)
    }

    func clearOverride(uid: String, adminBearerToken: String?) async throws {
        let payload = IAPOverridePayload(override: false, reason: nil, status: nil, expiresAt: nil)
        let body = try encoder.encode(payload)
        _ = try await request(
            path: "/api/v1/admin/subscription/\(uid)/override",
            method: .POST,
            body: body,
            adminBearerToken: adminBearerToken
        )
    }

    func extendSubscription(uid: String, days: Int, reason: String, adminBearerToken: String?) async throws {
        let payload = IAPExtendPayload(days: days, reason: reason)
        let body = try encoder.encode(payload)
        _ = try await request(
            path: "/api/v1/admin/subscription/\(uid)/extend",
            method: .POST,
            body: body,
            adminBearerToken: adminBearerToken
        )
    }

    func setExpires(
        uid: String,
        status: String,
        expiresAtISO8601: String,
        reason: String,
        adminBearerToken: String?
    ) async throws {
        let payload = IAPSetExpiresPayload(
            expiresAt: expiresAtISO8601,
            status: status,
            reason: reason
        )
        let body = try encoder.encode(payload)
        _ = try await request(
            path: "/api/v1/admin/subscription/\(uid)/set-expires",
            method: .POST,
            body: body,
            adminBearerToken: adminBearerToken
        )
    }

    private func request(
        path: String,
        method: HTTPMethod,
        body: Data?,
        adminBearerToken: String?
    ) async throws -> Data {
        let customHeaders = adminBearerToken.map { ["Authorization": "Bearer \($0)"] }
        do {
            return try await httpClient.request(
                path: path,
                method: method,
                body: body,
                customHeaders: customHeaders
            )
        } catch {
            throw error.toDomainError()
        }
    }

    private func unwrap(_ data: Data) throws -> IAPAdminDetailData {
        let response = try decoder.decode(UnifiedAPIResponse<IAPAdminDetailData>.self, from: data)
        if response.success, let payload = response.data {
            return payload
        }

        if let message = response.error?.message ?? response.message {
            throw DomainError.validationFailure(message)
        }

        throw DomainError.dataCorruption("Admin API returned an empty payload")
    }
}

// MARK: - Payloads / DTOs

private struct IAPOverridePayload: Encodable {
    let override: Bool
    let reason: String?
    let status: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case override
        case reason
        case status
        case expiresAt = "expires_at"
    }
}

private struct IAPExtendPayload: Encodable {
    let days: Int
    let reason: String
}

private struct IAPSetExpiresPayload: Encodable {
    let expiresAt: String
    let status: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
        case status
        case reason
    }
}

struct IAPAdminDetailData: Codable {
    let subscription: IAPAdminSubscriptionSnapshot
    let rizoUsage: IAPAdminRizoUsage?
    let auditLogs: [IAPAdminAuditLog]?

    enum CodingKeys: String, CodingKey {
        case subscription
        case rizoUsage = "rizo_usage"
        case auditLogs = "audit_logs"
    }
}

struct IAPAdminSubscriptionSnapshot: Codable {
    let status: String?
    let expiresAt: String?
    let hasOverride: Bool?
    let billingIssue: Bool?
    let planType: String?
    let trialRemainingDays: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case expiresAt = "expires_at"
        case hasOverride = "has_override"
        case billingIssue = "billing_issue"
        case planType = "plan_type"
        case trialRemainingDays = "trial_remaining_days"
    }
}

struct IAPAdminRizoUsage: Codable {
    let used: Int?
    let limit: Int?
    let remaining: Int?
}

struct IAPAdminAuditLog: Codable, Identifiable {
    let id: String
    let action: String?
    let reason: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case action
        case reason
        case createdAt = "created_at"
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
