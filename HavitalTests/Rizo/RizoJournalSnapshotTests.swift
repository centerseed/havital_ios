import SwiftUI
import XCTest
@testable import paceriz_dev

/// 用 ImageRenderer 把 RizoJournalSection 三種 AC 狀態渲染成 PNG（mock 資料，不連後端）。
/// 產物落地 /tmp/rizo_journal_shots/ 供截圖證據。
@MainActor
final class RizoJournalSnapshotTests: XCTestCase {

    private let outDir = "/tmp/rizo_journal_shots"

    private func render(_ view: some View, name: String, height: CGFloat) {
        let host = view
            .frame(width: 390)
            .frame(height: height, alignment: .top)
            .background(Color(UIColor.systemGroupedBackground))
        let renderer = ImageRenderer(content: host)
        renderer.scale = 3.0
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else {
            XCTFail("renderer 失敗: \(name)")
            return
        }
        let path = "\(outDir)/\(name).png"
        XCTAssertNoThrow(try data.write(to: URL(fileURLWithPath: path)))
        print("[SNAPSHOT] wrote \(path) size=\(uiImage.size)")
    }

    private func settle(_ vm: RizoJournalViewModel, untilRecorded: Bool) async {
        for _ in 0..<300 {
            if !untilRecorded || vm.isRecorded { return }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 3_000_000)
        }
    }

    func test_snapshot_selectionState() async {
        let vm = RizoJournalPreviewFactory.makeViewModel(recorded: false)
        await settle(vm, untilRecorded: false)
        render(
            RizoJournalSection(viewModel: vm, freeNote: { "後段腿很沉" }).padding(16),
            name: "01_note_only_ready",
            height: 220
        )
    }

    func test_snapshot_recordedWithReply() async {
        let vm = RizoJournalPreviewFactory.makeViewModel(recorded: true)
        await settle(vm, untilRecorded: true)
        XCTAssertTrue(vm.isRecorded, "應已記錄")
        render(
            RizoJournalSection(viewModel: vm, freeNote: { "後段腿很沉" }).padding(16),
            name: "02_recorded_with_reply",
            height: 360
        )
    }
}
