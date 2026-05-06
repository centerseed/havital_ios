import XCTest

final class LocalizationCoverageTests: XCTestCase {
    func test_all_nslocalizedstring_literal_keys_exist_in_supported_locales() throws {
        let projectRoot = try findProjectRoot()
        let swiftRoot = projectRoot.appendingPathComponent("Havital")
        let locales = ["en", "ja", "zh-Hant"]
        let usedKeys = try collectNSLocalizedStringLiteralKeys(under: swiftRoot)

        XCTAssertFalse(usedKeys.isEmpty, "Localization coverage test found no NSLocalizedString keys")

        for locale in locales {
            let stringsURL = projectRoot
                .appendingPathComponent("Havital/Resources")
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("Localizable.strings")
            let definedKeys = try collectDefinedLocalizationKeys(from: stringsURL)
            let missing = usedKeys.subtracting(definedKeys).sorted()

            XCTAssertTrue(
                missing.isEmpty,
                "\(locale) Localizable.strings is missing \(missing.count) keys: \(missing.joined(separator: ", "))"
            )
        }
    }

    private func findProjectRoot() throws -> URL {
        var current = URL(fileURLWithPath: #filePath)
        while current.path != "/" {
            let candidate = current.deletingLastPathComponent()
            let resources = candidate.appendingPathComponent("Havital/Resources/en.lproj/Localizable.strings")
            if FileManager.default.fileExists(atPath: resources.path) {
                return candidate
            }
            current = candidate
        }
        throw XCTSkip("Unable to locate project root from #filePath")
    }

    private func collectNSLocalizedStringLiteralKeys(under root: URL) throws -> Set<String> {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var keys = Set<String>()
        let pattern = #"NSLocalizedString\(\s*"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            regex.enumerateMatches(in: content, range: range) { match, _, _ in
                guard let match,
                      let keyRange = Range(match.range(at: 1), in: content) else { return }
                keys.insert(String(content[keyRange]))
            }
        }

        return keys
    }

    private func collectDefinedLocalizationKeys(from stringsURL: URL) throws -> Set<String> {
        let content = try String(contentsOf: stringsURL, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"^\s*"([^"]+)"\s*="#, options: [.anchorsMatchLines])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        var keys = Set<String>()

        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                  let keyRange = Range(match.range(at: 1), in: content) else { return }
            keys.insert(String(content[keyRange]))
        }

        return keys
    }
}
