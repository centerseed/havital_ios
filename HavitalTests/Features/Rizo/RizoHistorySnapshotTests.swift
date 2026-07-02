import SwiftUI
import XCTest
@testable import paceriz_dev

/// 把 Rizo 歷史唯讀詳情渲染成 PNG（mock 資料，不連後端）。
/// 產物落地 /tmp/rizo_history_shots/ 供版面結構的視覺證據。
/// 註：此處樣本文字用 ASCII（i18n hook 擋測試檔硬編 CJK）；
/// 真實中文字形渲染 + 真實帳號資料的驗證由模擬器真機測試（下一步）負責。
@MainActor
final class RizoHistorySnapshotTests: XCTestCase {

    private let outDir = "/tmp/rizo_history_shots"

    private func render(_ view: some View, name: String, height: CGFloat) {
        let host = view
            .frame(width: 390)
            .frame(height: height, alignment: .top)
            .background(Color(UIColor.systemGroupedBackground))
        let renderer = ImageRenderer(content: host)
        renderer.scale = 3.0
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else {
            XCTFail("ImageRenderer failed: \(name)"); return
        }
        try? FileManager.default.createDirectory(
            atPath: outDir, withIntermediateDirectories: true)
        let path = "\(outDir)/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path))
        print("[snapshot] \(path)")
    }

    private func sampleConversation() -> RizoConversationSummary {
        let turns = [
            RizoHistoryItem(sessionId: "s1", scenario: "body_status",
                            userInput: "", rizoResponse: "Morning! You're in good shape today, good to follow the plan.",
                            ts: "2026-07-01T08:00:00.000000+00:00"),
            RizoHistoryItem(sessionId: "s1", scenario: "body_status",
                            userInput: "A bit tired, want to go easier",
                            rizoResponse: "No problem, I'll lower today's intensity to an easy run.",
                            ts: "2026-07-01T08:01:00.000000+00:00"),
        ]
        return RizoConversationSummary.group(from: turns)[0]
    }

    func test_render_detail() {
        render(RizoHistoryDetailView(conversation: sampleConversation()),
               name: "detail", height: 420)
    }
}
