import Foundation

struct UIAssertionGuide {
    struct ExpectedElement {
        let identifier: String?
        let visibleText: String?
        let mustContainText: String?
    }

    enum OverviewTab: Int {
        case targetInfo = 0
        case trainingPlan = 1
    }

    static func expectedOverviewElements(from fixtureURL: URL, tab: OverviewTab) throws -> [ExpectedElement] {
        let object = try loadJSONObject(from: fixtureURL)
        var elements: [ExpectedElement] = []

        switch tab {
        case .targetInfo:
            if let targetName = object["target_name"] as? String {
                elements.append(ExpectedElement(identifier: nil, visibleText: targetName, mustContainText: nil))
            }

        case .trainingPlan:
            if let methodology = object["methodology_overview"] as? [String: Any],
               let name = methodology["name"] as? String {
                elements.append(ExpectedElement(identifier: "v2.overview.methodology_card", visibleText: nil, mustContainText: nil))
                elements.append(ExpectedElement(identifier: nil, visibleText: name, mustContainText: nil))
            }

            if object["approach_summary"] as? String != nil {
                elements.append(ExpectedElement(identifier: "v2.overview.stage_list", visibleText: nil, mustContainText: nil))
            }

            if let stages = object["training_stages"] as? [[String: Any]] {
                for stage in stages {
                    if let stageId = stage["stage_id"] as? String {
                        elements.append(ExpectedElement(identifier: "v2.overview.stage.\(stageId)", visibleText: nil, mustContainText: nil))
                    }
                }
            }
        }

        return deduplicated(elements)
    }

    static func expectedWeeklyElements(from fixtureURL: URL) throws -> [ExpectedElement] {
        let object = try loadJSONObject(from: fixtureURL)
        var elements: [ExpectedElement] = [
            ExpectedElement(identifier: "v2.weekly.screen", visibleText: nil, mustContainText: nil),
            ExpectedElement(identifier: "v2.weekly.progress_card", visibleText: nil, mustContainText: nil),
            ExpectedElement(identifier: "v2.weekly.overview_card", visibleText: nil, mustContainText: nil),
            ExpectedElement(identifier: "v2.weekly.intensity.low", visibleText: nil, mustContainText: nil),
            ExpectedElement(identifier: "v2.weekly.intensity.medium", visibleText: nil, mustContainText: nil),
            ExpectedElement(identifier: "v2.weekly.intensity.high", visibleText: nil, mustContainText: nil),
            ExpectedElement(identifier: "v2.weekly.timeline_header", visibleText: nil, mustContainText: nil),
        ]

        if let days = object["days"] as? [[String: Any]] {
            for day in days {
                if let dayIndex = day["day_index"] as? Int {
                    elements.append(ExpectedElement(identifier: "v2.weekly.day_\(dayIndex).card", visibleText: nil, mustContainText: nil))
                    elements.append(ExpectedElement(identifier: "v2.weekly.day_\(dayIndex).run_type", visibleText: nil, mustContainText: nil))
                }
            }
        }

        return elements
    }

    static func expectedVisibleElements(
        methodologyId: String,
        phaseId: String,
        fromWeeklyFixture fixtureURL: URL
    ) throws -> [ExpectedElement] {
        let elements = try expectedWeeklyElements(from: fixtureURL)

        // Keep methodology/phase routing centralized in the guide so UITests
        // do not hardcode per-fixture expectations inline.
        switch (methodologyId, phaseId) {
        case ("paceriz", "base"),
             ("paceriz", "build"),
             ("paceriz", "peak"),
             ("paceriz", "taper"),
             ("hansons", "base"),
             ("hansons", "peak"),
             ("norwegian", "base"),
             ("norwegian", "peak"),
             ("polarized", "base"),
             ("polarized", "peak"),
             ("complete_10k", "conversion"),
             ("aerobic_endurance", "base"),
             ("balanced_fitness", "base"):
            break
        default:
            break
        }

        return deduplicated(elements)
    }

    static func expectedSummaryElements(from fixtureURL: URL) throws -> [ExpectedElement] {
        let object = try loadJSONObject(from: fixtureURL)
        var elements: [ExpectedElement] = [
            ExpectedElement(identifier: "v2.summary.screen", visibleText: nil, mustContainText: nil),
            ExpectedElement(identifier: "v2.summary.completion_card", visibleText: nil, mustContainText: nil),
        ]

        if let completion = object["training_completion"] as? [String: Any],
           let percentage = completion["percentage"] as? Double {
            let displayPercentage = percentage <= 1 ? Int(round(percentage * 100)) : Int(round(percentage))
            elements.append(ExpectedElement(identifier: nil, visibleText: "\(displayPercentage)%", mustContainText: nil))
        }

        if let weeklyHighlights = object["weekly_highlights"] as? [String: Any],
           let highlights = weeklyHighlights["highlights"] as? [Any],
           !highlights.isEmpty {
            elements.append(ExpectedElement(identifier: "v2.summary.highlights_toggle", visibleText: nil, mustContainText: nil))
        }

        if let trainingAnalysis = object["training_analysis"] as? [String: Any],
           !trainingAnalysis.isEmpty {
            elements.append(ExpectedElement(identifier: "v2.summary.analysis_toggle", visibleText: nil, mustContainText: nil))
        }

        if let adjustments = object["next_week_adjustments"] as? [String: Any],
           adjustments["summary"] as? String != nil {
            elements.append(ExpectedElement(identifier: "v2.summary.next_week_toggle", visibleText: nil, mustContainText: nil))
        }

        return deduplicated(elements)
    }

    private static func loadJSONObject(from fixtureURL: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: fixtureURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "UIAssertionGuide", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture root must be an object"])
        }
        return object
    }

    private static func deduplicated(_ elements: [ExpectedElement]) -> [ExpectedElement] {
        var seen = Set<String>()
        return elements.filter {
            seen.insert("\($0.identifier ?? "")|\($0.visibleText ?? "")|\($0.mustContainText ?? "")").inserted
        }
    }
}
