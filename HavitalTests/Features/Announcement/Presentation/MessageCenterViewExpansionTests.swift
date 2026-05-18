import XCTest
import SwiftUI
@testable import paceriz_dev

final class MessageCenterViewExpansionTests: XCTestCase {
    private let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func read(_ relativePath: String) throws -> String {
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func assertContains(
        _ haystack: String,
        _ needle: String,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            haystack.contains(needle),
            message.isEmpty ? "Missing expected fragment: \(needle)" : message,
            file: file,
            line: line
        )
    }

    func testMessageCenterExpandsCardsInlineInsteadOfOpeningDetailSheet() throws {
        let source = try read("Havital/Features/Announcement/Presentation/Views/MessageCenterView.swift")

        assertContains(source, "@State private var expandedAnnouncementIDs",
                       "MessageCenterView must track expanded cards locally in the list")
        assertContains(source, "isExpanded: expandedAnnouncementIDs.contains(announcement.id)",
                       "Each card must receive its expanded state from the local set")
        assertContains(source, "toggleExpansion(for: announcement)",
                       "Tapping a card must expand/collapse it inline")

        XCTAssertFalse(source.contains(".sheet(item: $viewModel.selectedMessageCenterAnnouncement"),
                       "Message center cards must not open AnnouncementPopupView as a detail sheet")
        XCTAssertFalse(source.contains("openMessageCenterAnnouncement(announcement)"),
                       "Message center cards must not rely on selectedMessageCenterAnnouncement for detail presentation")
    }

    func testExpandedCardShowsFullBodyImageAndCTAWhileCollapsedCardSummarizes() throws {
        let source = try read("Havital/Features/Announcement/Presentation/Views/MessageCenterView.swift")

        assertContains(source, ".lineLimit(3)",
                       "Collapsed body summary must be capped at 3 lines")
        assertContains(source, "if isExpanded {",
                       "Expanded body must render in a separate reading section")
        assertContains(source, "Image(systemName: isExpanded ? \"chevron.up\" : \"chevron.down\")",
                       "Cards must expose collapsed/expanded affordance")
        assertContains(source, "AsyncImage(url: url)",
                       "Expanded cards must render announcement imageUrl with AsyncImage")
        assertContains(source, "onCTA(announcement)",
                       "Expanded CTA must delegate to MessageCenterView")
        assertContains(source, "viewModel.handlePopupCTA(announcement)",
                       "MessageCenterView must keep using AnnouncementViewModel.handlePopupCTA")
        assertContains(source, "MessageCenter_AnnouncementCTA_\\(announcement.id)",
                       "CTA must have a stable accessibility identifier")
    }

    @MainActor
    func testMessageCenterViewRendersAnnouncementListInHostingController() async {
        let repository = MessageCenterRenderRepository()
        await repository.setAnnouncements([
            Announcement(
                id: "render-announcement",
                title: "Render announcement",
                body: "A longer announcement body that can be collapsed and expanded from the message center list.",
                imageUrl: nil,
                ctaLabel: "Read more",
                ctaUrl: "https://example.com",
                publishedAt: Date(),
                expiresAt: nil,
                isSeen: false
            )
        ])
        let viewModel = AnnouncementViewModel(repository: repository)
        let host = UIHostingController(rootView: NavigationView {
            MessageCenterView(viewModel: viewModel)
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()

        viewModel.loadMessageCenter()
        await waitUntil {
            viewModel.allAnnouncements.count == 1
                && viewModel.allAnnouncements.allSatisfy(\.isSeen)
        }

        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }

        XCTAssertEqual(image.size, host.view.bounds.size)
        XCTAssertFalse(host.view.subviews.isEmpty, "MessageCenterView should render a non-empty SwiftUI hierarchy")
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 1.5,
        pollInterval: UInt64 = 50_000_000,
        condition: @escaping @MainActor () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }

        XCTFail("Timed out waiting for condition")
    }
}

private actor MessageCenterRenderRepository: AnnouncementRepository {
    private var announcements: [Announcement] = []

    func setAnnouncements(_ announcements: [Announcement]) {
        self.announcements = announcements
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        announcements
    }

    func markSeen(id: String) async throws {}

    func markSeenBatch(ids: [String]) async throws {
        announcements = announcements.map { announcement in
            guard ids.contains(announcement.id) else { return announcement }
            return Announcement(
                id: announcement.id,
                title: announcement.title,
                body: announcement.body,
                imageUrl: announcement.imageUrl,
                ctaLabel: announcement.ctaLabel,
                ctaUrl: announcement.ctaUrl,
                publishedAt: announcement.publishedAt,
                expiresAt: announcement.expiresAt,
                isSeen: true
            )
        }
    }
}
