import SwiftUI
import UIKit
import XCTest
@testable import paceriz_dev

final class App2ThemeAppearanceTests: XCTestCase {

    func testLightKeepsApp2DesignHex() {
        XCTAssertEqual(hex(App2Theme.pageTop, .light), "F3F6FA")
        XCTAssertEqual(hex(App2Theme.cardBackground, .light), "FFFFFF")
        XCTAssertEqual(hex(App2Theme.inkPrimary, .light), "10151C")
        XCTAssertEqual(hex(App2Theme.inkSecondary, .light), "4A5561")
        XCTAssertEqual(hex(App2Theme.accentBlue, .light), "1890FF")
        XCTAssertEqual(hex(App2Theme.insetBackground, .light), "F5F7FA")
    }

    /// AC-APPEAR-03：dark 有自己的一張表（T-0393），不再借 1.x `color.dark`。
    func testDarkUsesApp2OwnSurfaceTable() {
        XCTAssertEqual(hex(App2Theme.pageTop, .dark), "0B0B0D")
        XCTAssertEqual(hex(App2Theme.pageBottom, .dark), "0B0B0D")
        XCTAssertEqual(hex(App2Theme.cardBackground, .dark), "232329")
        XCTAssertEqual(hex(App2Theme.insetBackground, .dark), "2E2E35")
        XCTAssertEqual(hex(App2Theme.inkPrimary, .dark), "FFFFFF")
    }

    /// AC-APPEAR-11：次墨五階在 dark 不得塌成同一個灰——1.x 借值時就是塌的，
    /// light 下的層次整個消失（2026-09-02 使用者實機）。
    func testDarkInkKeepsFiveDistinctSteps() {
        let steps = [
            hex(App2Theme.inkSecondary, .dark),
            hex(App2Theme.inkSubtle, .dark),
            hex(App2Theme.inkTertiary, .dark),
            hex(App2Theme.inkMuted, .dark),
            hex(App2Theme.inkFaint, .dark)
        ]
        XCTAssertEqual(steps, ["C8CDD3", "B0B6BD", "9AA1A9", "8A9199", "7C838B"])
        XCTAssertEqual(Set(steps).count, 5, "五階必須互不相同")
    }

    /// R3：亮綠在 dark 壓暗一階（大面積鋪在近黑上會刺眼）。品牌藍不變，色相也不變。
    func testDarkDimsBrightGreenOnly() {
        XCTAssertEqual(hex(App2Theme.accentGreenBright, .light), "22C55E")
        XCTAssertEqual(hex(App2Theme.accentGreenBright, .dark), "1E9E52")
    }

    func testDarkKeepsApp2BrandBlue() {
        XCTAssertEqual(hex(App2Theme.accentBlue, .dark), "1890FF")
        XCTAssertEqual(hex(App2Theme.accentBlue, .light), hex(App2Theme.accentBlue, .dark))
    }

    func testPreferenceColorSchemeMapping() {
        XCTAssertNil(App2AppearancePreference.system.colorScheme)
        XCTAssertEqual(App2AppearancePreference.light.colorScheme, .light)
        XCTAssertEqual(App2AppearancePreference.dark.colorScheme, .dark)
        XCTAssertEqual(App2AppearancePreference(rawValue: "nope") ?? .system, .system)
    }

    @MainActor
    func testPreferencePersistsLocally() {
        let store = App2AppearanceStore.shared
        let previous = store.preference
        store.preference = .dark
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: App2AppearanceStore.defaultsKey),
            "dark"
        )
        store.preference = .system
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: App2AppearanceStore.defaultsKey),
            "system"
        )
        store.preference = previous
    }

    func testDarkNeutralFillIsCardNotPage() {
        XCTAssertEqual(hex(App2Theme.neutralFill, .dark), "232329")
        XCTAssertEqual(hex(App2Theme.cardBackground, .dark), "232329")
        XCTAssertEqual(hex(App2Theme.pageTop, .dark), "0B0B0D")
    }

    func testDarkHeroStaysDesignedDark() {
        XCTAssertEqual(hex(App2Theme.sourceDarkTile, .dark), "0B0D10")
        XCTAssertEqual(hex(App2Theme.sourceDarkTile, .light), "0B0D10")
    }

    func testAccentCardGradientEndsAtCardBackground() {
        XCTAssertEqual(hex(App2Theme.cardBackground, .dark), "232329")
        XCTAssertEqual(hex(App2Theme.cardBackground, .light), "FFFFFF")
        XCTAssertEqual(hex(App2Theme.neutralFill, .dark), hex(App2Theme.cardBackground, .dark))
    }

    func testApp2PresentationHasNoStaticWhiteCardFills() throws {
        let app2 = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Havital/Features/App2")
        let enumerator = FileManager.default.enumerator(at: app2, includingPropertiesForKeys: nil)
        XCTAssertNotNil(enumerator)
        let forbidden = [
            ".init(color: .white",
            ".init(color: Color.white",
            ".fill(Color.white)",
            ".fill(.white)",
            ".fill(Color.white.opacity(0.45",
            ".fill(Color.white.opacity(0.5",
            "background: Color.white.opacity(0.5",
            "background: Color.white.opacity(0.7",
            "option == selected ? Color.white",
            "isSelected ? Color.white : Color.clear",
        ]
        var hits: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = String(line)
                if s.contains("foregroundStyle") { continue }
                if forbidden.contains(where: { s.contains($0) }) {
                    hits.append("\(url.lastPathComponent):\(index + 1): \(s.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(hits.isEmpty, hits.joined(separator: "\n"))
    }

    func testOneXHostsStayLight() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let app = try String(
            contentsOf: root.appendingPathComponent("Havital/HavitalApp.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(app.contains("preferredColorScheme"))
        let shell = try String(
            contentsOf: root.appendingPathComponent(
                "Havital/Features/App2/Presentation/App2RootView.swift"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(shell.contains("preferredColorScheme(appearanceStore.preference.colorScheme)"))
        let login = try String(
            contentsOf: root.appendingPathComponent("Havital/Views/LoginView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(login.contains(".preferredColorScheme(.light)"))
        // TrainingCalendarView（App2 紀錄頁日曆鈕的 sheet）2026-09-04 c904dd6f 起不再鎖 light，
        // 跟系統外觀走（SPEC-app-appearance.md §8 例外）；這裡只斷言它沒有恢復強制 light。
        let calendar = try String(
            contentsOf: root.appendingPathComponent(
                "Havital/Views/Training/Components/TrainingCalendarView.swift"
            ),
            encoding: .utf8
        )
        XCTAssertFalse(calendar.contains(".preferredColorScheme(.light)"))
    }

    private func hex(_ color: Color, _ style: UIUserInterfaceStyle) -> String {
        let resolved = UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: style)
        )
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02X%02X%02X",
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded())
        )
    }
}
