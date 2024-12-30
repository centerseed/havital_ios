import Foundation
import GoogleGenerativeAI

enum GeminiError: Error, Equatable {
    case invalidApiKey
    case invalidPromptFile
    case invalidResponse
    case networkError(Error)
    
    static func == (lhs: GeminiError, rhs: GeminiError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidApiKey, .invalidApiKey):
            return true
        case (.invalidPromptFile, .invalidPromptFile):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

class GeminiService {
    static let shared = GeminiService()
    private var apiKey: String?
    
    private init() {
        loadApiKey()
    }
    
    private func loadApiKey() {
        guard let path = Bundle.main.path(forResource: "key", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let key = dict["GeminiApiKey"] as? String else {
            return
        }
        apiKey = key
    }
    
    private func getModel(with schema: Schema) throws -> GenerativeModel {
        guard let apiKey = apiKey else {
            throw GeminiError.invalidApiKey
        }
        
        return GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            generationConfig: GenerationConfig(
                responseMIMEType: "application/json",
                responseSchema: schema
            )
        )
    }
    
    private func loadPrompts(from fileNames: [String]) throws -> String {
        let promptContents = try fileNames.map { fileName -> String in
            // First try with explicit path
            if let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Resources/Prompts"),
               let content = try? String(contentsOf: url) {
                return content
            }
            
            // Then try without subdirectory
            if let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
               let content = try? String(contentsOf: url) {
                return content
            }
            
            // Finally, try direct file path
            if let path = Bundle.main.path(forResource: fileName, ofType: "json"),
               let content = try? String(contentsOfFile: path) {
                return content
            }
            
            throw GeminiError.invalidPromptFile
        }
        return promptContents.joined(separator: "\n")
    }
    
    public func generateContent(withPromptFiles fileNames: [String], input: [String: Any], schema: Schema) async throws -> [String: Any] {
        let model = try getModel(with: schema)
        let promptContent = try loadPrompts(from: fileNames)
        let inputJson = try JSONSerialization.data(withJSONObject: input)
        let inputString = String(data: inputJson, encoding: .utf8) ?? "{}"
        
        let prompt = promptContent + "\n" + inputString
        print(prompt)
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let responseText = response.text,
                  let responseData = responseText.data(using: .utf8),
                  let jsonResponse = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                throw GeminiError.invalidResponse
            }
            
            return jsonResponse
        } catch {
            throw GeminiError.networkError(error)
        }
    }
    
    // MARK: - Public Methods
    
    func generateTrainingPlan(withPromptFiles fileNames: [String], input: [String: Any]) async throws -> [String: Any] {
        return try await generateContent(withPromptFiles: fileNames, input: input, schema: trainingPlanSchema)
    }
    
    func generateSummary(withPromptFiles fileNames: [String], input: [String: Any]) async throws -> [String: Any] {
        return try await generateContent(withPromptFiles: fileNames, input: input, schema: summarySchema)
    }
}
