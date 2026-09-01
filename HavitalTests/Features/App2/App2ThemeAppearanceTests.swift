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

    func testDarkMapsSurfaceAndInkTo1x() {
        XCTAssertEqual(hex(App2Theme.pageTop, .dark), "121212")
        XCTAssertEqual(hex(App2Theme.pageBottom, .dark), "121212")
        XCTAssertEqual(hex(App2Theme.cardBackground, .dark), "1E1E1E")
        XCTAssertEqual(hex(App2Theme.insetBackground, .dark), "2C2C2E")
        XCTAssertEqual(hex(App2Theme.inkPrimary, .dark), "FFFFFF")
        XCTAssertEqual(hex(App2Theme.inkSecondary, .dark), "B3B3B3")
        XCTAssertEqual(hex(App2Theme.inkMuted, .dark), "B3B3B3")
        XCTAssertEqual(hex(App2Theme.inkSubtle, .dark), "B3B3B3")
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
        XCTAssertEqual(hex(App2Theme.neutralFill, .dark), "1E1E1E")
        XCTAssertEqual(hex(App2Theme.cardBackground, .dark), "1E1E1E")
        XCTAssertEqual(hex(App2Theme.pageTop, .dark), "121212")
    }

    func testDarkHeroStaysDesignedDark() {
        XCTAssertEqual(hex(App2Theme.sourceDarkTile, .dark), "0B0D10")
        XCTAssertEqual(hex(App2Theme.sourceDarkTile, .light), "0B0D10")
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
