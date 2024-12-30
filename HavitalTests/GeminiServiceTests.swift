import XCTest
@testable import Havital
import GoogleGenerativeAI

class GeminiServiceTests: XCTestCase {
    var sut: GeminiService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = GeminiService.shared
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    func testGenerateContent() async throws {
        // Given
        let input = [
            "user_info": [
                "age": 30,
                "aerobics_level": 3,
                "strength_level": 3,
                "busy_level": 3,
                "proactive_level": 3,
                "workout_days": ["Monday", "Wednesday", "Friday"],
                "preferred_workout": "running"
            ]
        ]
        
        // When
        do {
            // Make sure we're using the correct file name
            let result = try await sut.generateContent(
                withPromptFiles: ["prompt_training_plan_base", "prompt_training_plan_onboard"],
                input: input
                schema: trainingPlanSchema
            )
            
            // Then
            XCTAssertNotNil(result)
            XCTAssertTrue(result.keys.contains("purpose"))
            XCTAssertTrue(result.keys.contains("days"))
            
            if let days = result["days"] as? [[String: Any]] {
                XCTAssertFalse(days.isEmpty)
                if let firstDay = days.first {
                    XCTAssertTrue(firstDay.keys.contains("target"))
                    XCTAssertTrue(firstDay.keys.contains("training_items"))
                }
            }
        } catch GeminiError.invalidPromptFile {
            XCTFail("Could not find prompt file. Make sure 'prompt_training_plan_base.json' is included in the test target.")
        } catch {
            XCTFail("Generate content failed with error: \(error)")
        }
    }
    
    func testInvalidApiKey() async {
        // Given
        let input = ["test": "test"]
        
        // When/Then
        do {
            _ = try await sut.generateContent(
                withPromptFiles: ["prompt_training_plan_base"],
                input: input
                schema: trainingPlanSchema
            )
            XCTFail("Should throw invalid API key error")
        } catch {
            XCTAssertEqual(error as? GeminiError, .invalidApiKey)
        }
    }
    
    func testInvalidPromptFile() async {
        // Given
        let input = ["test": "test"]
        
        // When/Then
        do {
            _ = try await sut.generateContent(
                withPromptFiles: ["nonexistent"],
                input: input
                schema: trainingPlanSchema
            )
            XCTFail("Should throw invalid prompt file error")
        } catch {
            XCTAssertEqual(error as? GeminiError, .invalidPromptFile)
        }
    }
}
