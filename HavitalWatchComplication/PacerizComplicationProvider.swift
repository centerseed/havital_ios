import SwiftUI
import WidgetKit

struct PacerizEntry: TimelineEntry {
    let date: Date
    let summary: String
}

struct PacerizProvider: TimelineProvider {
    func placeholder(in context: Context) -> PacerizEntry {
        PacerizEntry(date: Date(), summary: "Paceriz")
    }

    func getSnapshot(in context: Context, completion: @escaping (PacerizEntry) -> Void) {
        completion(PacerizEntry(date: Date(), summary: Self.todaySummary()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PacerizEntry>) -> Void) {
        let entry = PacerizEntry(date: Date(), summary: Self.todaySummary())
        let nextRefresh = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    static func todaySummary() -> String {
        // SPIKE: move this snapshot read to an app group shared store before TestFlight.
        guard
            let data = UserDefaults.standard.data(forKey: "paceriz.watch.today_snapshot"),
            let snapshot = try? JSONDecoder().decode(ComplicationSnapshotDTO.self, from: data)
        else {
            return "無課表"
        }

        if snapshot.runType == "rest" {
            return "休息日"
        }

        if
            let repeated = snapshot.segments.first(where: { ($0.repTotal ?? 0) > 1 }),
            let meters = repeated.targetMeters,
            let total = repeated.repTotal
        {
            return "\(Int(meters))m × \(total)"
        }

        if let meters = snapshot.totalDistanceMeters {
            return distanceSummary(meters)
        }

        return snapshot.segments.first?.label ?? "今日課表"
    }

    private static func distanceSummary(_ meters: Double) -> String {
        if meters >= 1000 {
            let kilometers = meters / 1000
            return String(format: kilometers.rounded() == kilometers ? "%.0fK Easy" : "%.1fK Easy", kilometers)
        }
        return "\(Int(meters))m Easy"
    }
}

struct PacerizComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PacerizEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 1) {
                Text("P")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(entry.summary)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
            }
            .widgetURL(URL(string: "paceriz-watch://today"))
        case .accessoryCorner:
            Text(entry.summary)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.55)
                .widgetURL(URL(string: "paceriz-watch://today"))
        default:
            Text(entry.summary)
                .widgetURL(URL(string: "paceriz-watch://today"))
        }
    }
}

@main
struct PacerizComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PacerizToday", provider: PacerizProvider()) { entry in
            PacerizComplicationView(entry: entry)
        }
        .configurationDisplayName("Paceriz Today")
        .description("Shows today's Paceriz workout.")
        .supportedFamilies([.accessoryCorner, .accessoryCircular])
    }
}

private struct ComplicationSnapshotDTO: Decodable {
    let runType: String
    let totalDistanceMeters: Double?
    let segments: [ComplicationSegmentDTO]

    enum CodingKeys: String, CodingKey {
        case segments
        case runType = "run_type"
        case totalDistanceMeters = "total_distance_meters"
    }
}

private struct ComplicationSegmentDTO: Decodable {
    let targetMeters: Double?
    let label: String
    let repTotal: Int?

    enum CodingKeys: String, CodingKey {
        case label
        case targetMeters = "target_meters"
        case repTotal = "rep_total"
    }
}
