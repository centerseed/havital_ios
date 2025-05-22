import XCTest
@testable import Paceriz

class WeeklyPlanDecodingTests: XCTestCase {
    // 將測試 JSON 放在 Fixtures 資料夾
    let fixturesFolder = "WeeklyPlanFixtures"

    func testAllWeeklyPlanJSONs() throws {
    // 取得目前這個 swift 檔案所在的目錄
    let testFilePath = #file
    let testDir = (testFilePath as NSString).deletingLastPathComponent
    let fixturesDir = (testDir as NSString).appendingPathComponent("WeeklyPlanFixtures")
    
    let fileManager = FileManager.default
    let jsonFiles = try fileManager.contentsOfDirectory(atPath: fixturesDir)
        .filter { $0.hasSuffix(".json") }
    
    XCTAssertFalse(jsonFiles.isEmpty, "測試資料夾沒有任何 JSON 檔案")
    
    for jsonFile in jsonFiles {
        let jsonPath = (fixturesDir as NSString).appendingPathComponent(jsonFile)
        let data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        do {
            let plan = try JSONDecoder().decode(WeeklyPlan.self, from: data)
            XCTAssertNotNil(plan, "解析失敗: \(jsonFile)")
        } catch {
            XCTFail("解析 \(jsonFile) 失敗: \(error)")
        }
    }
}
}
