#if DEBUG
import SwiftUI

struct IAPTestConsoleView: View {
    @ObservedObject private var harness = IAPTestHarness.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                environmentSection
                configSection
                actionsSection
                adminSnapshotSection
                appSnapshotSection
                auditSection
            }
            .navigationTitle("IAP Test Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var environmentSection: some View {
        Section("Environment") {
            LabeledContent("Backend", value: APIConfig.baseURL)
            LabeledContent("Harness", value: harness.canUseHarness ? "Enabled" : "Disabled")
            LabeledContent("Tester UID Allowed", value: harness.isTesterUIDAllowed ? "Yes" : "No")
            LabeledContent("Admin Auth", value: harness.usingInjectedAdminToken ? "Injected Bearer" : "Current User Token")

            if let scenario = harness.launchScenario {
                HStack {
                    Text("Launch Scenario")
                    Spacer()
                    Text(scenario.displayName)
                        .foregroundStyle(.secondary)
                }

                Button("Apply Launch Scenario") {
                    Task {
                        await harness.applyScenario(scenario, origin: "console")
                    }
                }
                .disabled(harness.isBusy)
            }

            Text(harness.statusMessage)
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("IAPConsole_StatusMessage")
                .accessibilityLabel(harness.statusMessage)
        }
    }

    private var configSection: some View {
        Section("Config") {
            TextField("Tester UID", text: $harness.testerUID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Admin Bearer Token (optional)", text: $harness.adminBearerToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Reason", text: $harness.reason)

            TextField("Extend Days", text: $harness.extendDays)
                .keyboardType(.numberPad)
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Refresh Detail + App Status") {
                Task {
                    await harness.refreshAll()
                }
            }
            .disabled(harness.isBusy)

            Button("Set Subscribed") {
                Task {
                    await harness.applyScenario(.subscribed)
                }
            }
            .disabled(harness.isBusy)

            Button("Set Trial") {
                Task {
                    await harness.applyScenario(.trialActive)
                }
            }
            .disabled(harness.isBusy)

            Button("Set Expired") {
                Task {
                    await harness.applyScenario(.expired)
                }
            }
            .disabled(harness.isBusy)
            .foregroundStyle(.red)

            Button("Clear Override") {
                Task {
                    await harness.applyScenario(.clearOverride)
                }
            }
            .disabled(harness.isBusy)

            Button("Extend Subscription") {
                Task {
                    await harness.extendSubscription()
                }
            }
            .disabled(harness.isBusy)
        }
    }

    private var adminSnapshotSection: some View {
        Section("Admin Snapshot") {
            if let snapshot = harness.lastAdminDetail?.subscription {
                LabeledContent("Status", value: snapshot.status ?? "nil")
                LabeledContent("Plan", value: snapshot.planType ?? "nil")
                LabeledContent("Expires", value: snapshot.expiresAt ?? "nil")
                LabeledContent("Override", value: snapshot.hasOverride == true ? "true" : "false")
                LabeledContent("Billing Issue", value: snapshot.billingIssue == true ? "true" : "false")
                LabeledContent("Trial Days", value: snapshot.trialRemainingDays.map(String.init) ?? "nil")

                if let usage = harness.lastAdminDetail?.rizoUsage {
                    LabeledContent(
                        "Rizo Usage",
                        value: "\(usage.used ?? 0)/\(usage.limit ?? 0) remaining \(usage.remaining ?? 0)"
                    )
                }
            } else {
                Text("No admin detail loaded yet")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appSnapshotSection: some View {
        Section("App Snapshot") {
            if let status = harness.lastAppSubscriptionStatus {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(status.status.rawValue)
                }
                .accessibilityIdentifier("IAPConsole_AppStatus")
                .accessibilityLabel("App status: \(status.status.rawValue)")
                .accessibilityElement(children: .combine)

                // Stable status-value selector for Maestro assertions.
                Text("App status value: \(status.status.rawValue)")
                    .font(AppFont.caption2())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("IAPConsole_AppStatus_\(status.status.rawValue)")
                LabeledContent("Plan", value: status.planType ?? "nil")
                LabeledContent(
                    "Expires",
                    value: status.expiresAt.map { Date(timeIntervalSince1970: $0).formatted(date: .abbreviated, time: .shortened) } ?? "nil"
                )
                LabeledContent("Billing Issue", value: status.billingIssue ? "true" : "false")

                if let usage = status.rizoUsage {
                    LabeledContent("Rizo Usage", value: "\(usage.used)/\(usage.limit) remaining \(usage.remaining)")
                }
            } else {
                Text("No app subscription state loaded yet")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var auditSection: some View {
        Section("Recent Audit Logs") {
            if harness.lastAuditLogs.isEmpty {
                Text("No audit logs loaded yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(harness.lastAuditLogs.prefix(5)) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.action ?? "unknown")
                            .font(AppFont.subheadline())
                            .fontWeight(.semibold)
                        if let reason = log.reason, !reason.isEmpty {
                            Text(reason)
                                .font(AppFont.caption())
                                .foregroundStyle(.secondary)
                        }
                        Text(log.createdAt ?? log.id)
                            .font(AppFont.caption2())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
#endif
