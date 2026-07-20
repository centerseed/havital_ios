import SwiftUI
import XCTest
@testable import paceriz_dev

@MainActor
final class RizoHistoryResumeRenderingTests: XCTestCase {
    func test_historyDetailResumeActionRenders() throws {
        let conversation = RizoConversationSummary(
            sessionId: "source-session",
            scenario: "body_status",
            startedAt: "2026-07-20T01:00:00+00:00",
            updatedAt: "2026-07-20T01:02:00+00:00",
            turnCount: 2,
            titleSeed: "How far did I run yesterday?",
            lastResponse: "The pace stayed steady after kilometer two.",
            turns: [
                RizoHistoryItem(
                    sessionId: "source-session", scenario: "body_status",
                    userInput: "How far did I run yesterday?", rizoResponse: "You completed 5 km yesterday.",
                    ts: "2026-07-20T01:00:00+00:00"
                ),
                RizoHistoryItem(
                    sessionId: "source-session", scenario: "body_status",
                    userInput: "What about the pace?", rizoResponse: "It stayed near 5:20/km after kilometer two.",
                    ts: "2026-07-20T01:02:00+00:00"
                ),
            ]
        )
        let root = NavigationStack {
            RizoHistoryDetailView(conversation: conversation) { _ in true }
        }
        let host = UIHostingController(rootView: root)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.backgroundColor = .systemBackground
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: host.view.bounds.size)
        let image = renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0)
        let attachment = XCTAttachment(image: image)
        attachment.name = "t0179-rizo-history-resume"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
