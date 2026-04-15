import Foundation
import AdServices

// MARK: - AttributionManager

/// Fetches Apple Search Ads attribution on first launch.
/// Result is cached in UserDefaults — subsequent reads are instant.
final class AttributionManager {

    static let shared = AttributionManager()

    private static let sourceKey = "analytics_attribution_source"
    private static let campaignIdKey = "analytics_attribution_campaign_id"
    private static let fetchedKey = "analytics_attribution_fetched"

    private init() {}

    // MARK: - Public

    /// The install source derived from attribution.
    /// Returns immediately from cache; returns `"organic"` if attribution hasn't resolved yet.
    var source: String {
        UserDefaults.standard.string(forKey: Self.sourceKey) ?? "organic"
    }

    /// Campaign ID from Apple Search Ads (nil for organic installs).
    var campaignId: String? {
        UserDefaults.standard.string(forKey: Self.campaignIdKey)
    }

    /// Fetch attribution token and resolve source. Fire-and-forget — call once at app launch.
    /// Safe to call multiple times; only the first call does real work.
    func fetchIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.fetchedKey) else { return }

        Task.detached(priority: .utility) { [self] in
            await self.resolveAttribution()
        }
    }

    // MARK: - Private

    private func resolveAttribution() async {
        do {
            let token = try AAAttribution.attributionToken()
            let data = try await fetchAttributionData(token: token)

            if let attribution = data["attribution"] as? Bool, attribution,
               let campaignId = data["campaignId"] as? Int {
                store(source: "apple_search_ads", campaignId: String(campaignId))
            } else {
                store(source: "organic", campaignId: nil)
            }
        } catch {
            // AC-ANALYTICS-06: fallback to organic on any failure
            store(source: "organic", campaignId: nil)
            #if DEBUG
            Logger.debug("[Attribution] Fallback to organic: \(error.localizedDescription)")
            #endif
        }
    }

    private func fetchAttributionData(token: String) async throws -> [String: Any] {
        let url = URL(string: "https://api-adservices.apple.com/api/v1/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = token.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return json
    }

    private func store(source: String, campaignId: String?) {
        UserDefaults.standard.set(source, forKey: Self.sourceKey)
        if let campaignId {
            UserDefaults.standard.set(campaignId, forKey: Self.campaignIdKey)
        }
        UserDefaults.standard.set(true, forKey: Self.fetchedKey)

        #if DEBUG
        Logger.debug("[Attribution] Resolved: source=\(source), campaignId=\(campaignId ?? "nil")")
        #endif
    }
}
