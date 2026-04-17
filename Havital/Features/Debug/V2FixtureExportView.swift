#if DEBUG
import SwiftUI
import UIKit
import CryptoKit

// MARK: - V2FixtureExportView (A-0b)
/// DEBUG-only debug panel：觸發 V2 endpoint 並匯出 raw JSON 到 Share Sheet，供 Developer 存成 contract fixture。
///
/// 設計：
/// - 僅 DEBUG build 編譯（整檔 `#if DEBUG`）
/// - 不透過 `APIClient.request<T>`，避免走 decode path——直接用 URLSession 打 raw endpoint，保留原始 bytes
/// - 三顆按鈕對應三種 target_type（race_run / beginner / maintenance），每顆按鈕抓同一組 endpoint：
///     1. GET /v2/plan/overview
///     2. GET /v2/plan/status
///     3. GET /v2/plan/weekly/{planId}（若從 overview 能解析 planId，否則略過）
/// - 匯出檔案包 `_meta` envelope（captured_at / app_version / build / endpoint / uid_hash / target_type）並做 PII redaction
/// - Release build 零影響
struct V2FixtureExportView: View {

    // MARK: - State

    @State private var trainingVersion: String = "..."
    @State private var uidHash: String = "..."
    @State private var isExporting: Bool = false
    @State private var status: String = ""
    @State private var shareItems: [URL] = []
    @State private var showShareSheet: Bool = false

    // MARK: - Body

    var body: some View {
        List {
            Section(header: Text("Current Session")) {
                HStack {
                    Text("trainingVersion")
                    Spacer()
                    Text(trainingVersion)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(trainingVersion == "v2" ? .green : .orange)
                }
                HStack {
                    Text("uid_hash")
                    Spacer()
                    Text(uidHash)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Export V2 Fixture"), footer: footerText) {
                exportButton(label: "Export race_run overview + weekly + status", targetType: "race_run")
                exportButton(label: "Export beginner overview + weekly + status", targetType: "beginner")
                exportButton(label: "Export maintenance overview + weekly + status", targetType: "maintenance")
            }

            if !status.isEmpty {
                Section(header: Text("Status")) {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("V2 Fixture Export")
        .task {
            await refreshSessionInfo()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    @ViewBuilder
    private var footerText: some View {
        if trainingVersion != "v2" {
            Text("請先以 V2 demo user 登入（當前 trainingVersion=\(trainingVersion)）。")
                .foregroundColor(.orange)
        } else {
            Text("按下按鈕後會打 raw V2 endpoint，彈 Share Sheet 讓你存出 JSON。PII 已 redact。")
        }
    }

    @ViewBuilder
    private func exportButton(label: String, targetType: String) -> some View {
        Button {
            Task { await runExport(targetType: targetType) }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text(label)
                Spacer()
                if isExporting {
                    ProgressView()
                }
            }
        }
        .disabled(trainingVersion != "v2" || isExporting)
    }

    // MARK: - Actions

    private func refreshSessionInfo() async {
        let router: TrainingVersionRouter = DependencyContainer.shared.resolve()
        let version = await router.getTrainingVersion()
        let uid = AuthenticationService.shared.user?.uid ?? ""
        await MainActor.run {
            self.trainingVersion = version
            self.uidHash = V2FixtureExportHelpers.sha256Prefix8(uid)
        }
    }

    private func runExport(targetType: String) async {
        await MainActor.run {
            isExporting = true
            status = "打 endpoint 中…"
        }

        var exported: [URL] = []
        var logs: [String] = []

        // 1. overview
        if let url = await fetchAndWrite(
            endpoint: "/v2/plan/overview",
            targetType: targetType,
            logs: &logs
        ) {
            exported.append(url)
        }

        // 2. weekly/{planId} — 從 overview raw 解析 planId，若失敗則略過
        if let planId = await extractPlanIdFromOverview(logs: &logs) {
            if let url = await fetchAndWrite(
                endpoint: "/v2/plan/weekly/\(planId)",
                targetType: targetType,
                logs: &logs
            ) {
                exported.append(url)
            }
        } else {
            logs.append("略過 weekly（無法解析 planId）")
        }

        // 3. status
        if let url = await fetchAndWrite(
            endpoint: "/v2/plan/status",
            targetType: targetType,
            logs: &logs
        ) {
            exported.append(url)
        }

        await MainActor.run {
            isExporting = false
            status = logs.joined(separator: "\n")
            if !exported.isEmpty {
                shareItems = exported
                showShareSheet = true
            }
        }
    }

    private func fetchAndWrite(
        endpoint: String,
        targetType: String,
        logs: inout [String]
    ) async -> URL? {
        do {
            let rawData = try await V2FixtureExportHelpers.fetchRaw(path: endpoint)
            let envelope = V2FixtureExportHelpers.buildMetaEnvelope(
                endpoint: endpoint,
                targetType: targetType,
                rawData: rawData,
                uid: AuthenticationService.shared.user?.uid ?? ""
            )
            let fileURL = try V2FixtureExportHelpers.writeFixtureFile(
                envelope: envelope,
                endpoint: endpoint,
                targetType: targetType
            )
            logs.append("✅ \(endpoint) → \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            logs.append("❌ \(endpoint) failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func extractPlanIdFromOverview(logs: inout [String]) async -> String? {
        do {
            let data = try await V2FixtureExportHelpers.fetchRaw(path: "/v2/plan/overview")
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return nil
            }
            // APIResponse wrapper: { data: {...} } 或 raw {...}
            let body = (json["data"] as? [String: Any]) ?? json
            let overviewId = body["id"] as? String
            let currentWeek = (body["current_week"] as? Int)
                ?? (body["current_week_of_training"] as? Int)
                ?? 1
            if let overviewId {
                return "\(overviewId)_\(currentWeek)"
            }
            return nil
        } catch {
            logs.append("extractPlanId error: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Helpers (拆出以便單元測試)

enum V2FixtureExportHelpers {

    /// SHA256 前 8 字元（小寫 hex）
    static func sha256Prefix8(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "none" }
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(8))
    }

    /// 遞迴 redact JSON 物件中可能的 PII 欄位
    static let piiKeys: Set<String> = [
        "email", "phone", "phoneNumber", "phone_number",
        "idToken", "id_token", "accessToken", "access_token", "refreshToken", "refresh_token",
        "firebase_token", "firebaseToken", "authorization", "Authorization",
        "password", "uid"
    ]

    static func redactPII(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for (k, v) in dict {
                if piiKeys.contains(k) {
                    out[k] = "[REDACTED]"
                } else {
                    out[k] = redactPII(v)
                }
            }
            return out
        } else if let array = value as? [Any] {
            return array.map { redactPII($0) }
        } else {
            return value
        }
    }

    /// 組 `_meta` envelope；`rawData` 會先 decode 成 JSON object 再 redact，失敗則以字串保存
    static func buildMetaEnvelope(
        endpoint: String,
        targetType: String,
        rawData: Data,
        uid: String,
        now: Date = Date(),
        appVersion: String? = nil,
        buildNumber: String? = nil
    ) -> [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let resolvedVersion = appVersion
            ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "unknown"
        let resolvedBuild = buildNumber
            ?? (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
            ?? "unknown"

        var responseField: Any
        if let parsed = try? JSONSerialization.jsonObject(with: rawData) {
            responseField = redactPII(parsed)
        } else {
            responseField = String(data: rawData, encoding: .utf8) ?? "[binary]"
        }

        return [
            "_meta": [
                "captured_at": iso.string(from: now),
                "app_version": resolvedVersion,
                "build_number": resolvedBuild,
                "endpoint": endpoint,
                "uid_hash": sha256Prefix8(uid),
                "target_type": targetType
            ],
            "response": responseField
        ]
    }

    /// 打 raw V2 endpoint（bypass APIClient decode）
    static func fetchRaw(path: String) async throws -> Data {
        let urlString = APIConfig.baseURL + path
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = try await AuthenticationService.shared.getIdToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "V2FixtureExport",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"]
            )
        }
        return data
    }

    /// 將 envelope 以 pretty JSON 寫到 temp dir，回傳檔案 URL
    static func writeFixtureFile(
        envelope: [String: Any],
        endpoint: String,
        targetType: String,
        now: Date = Date()
    ) throws -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)

        // Sanitize endpoint 成檔名片段
        let endpointSlug = endpoint
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: "/", with: "_")

        let filename = "v2_\(targetType)_\(endpointSlug)_\(fmt.string(from: now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let data = try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - ShareSheet wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif
