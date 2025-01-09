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
        print("=== Debug: Loading Prompt Files ===")
        let promptContents = try fileNames.map { fileName -> String in
            print("Attempting to load prompt file: \(fileName)")
            
            // First try with explicit path
            if let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Resources/Prompts") {
                print("Found file in Resources/Prompts: \(url.path)")
                if let content = try? String(contentsOf: url) {
                    return content
                }
            }
            
            // Then try without subdirectory
            if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
                print("Found file in root: \(url.path)")
                if let content = try? String(contentsOf: url) {
                    return content
                }
            }
            
            // Finally, try direct file path
            if let path = Bundle.main.path(forResource: fileName, ofType: "json") {
                print("Found file with direct path: \(path)")
                if let content = try? String(contentsOfFile: path) {
                    return content
                }
            }
            
            print("Error: Could not find prompt file: \(fileName)")
            throw GeminiError.invalidPromptFile
        }
        return promptContents.joined(separator: "\n")
    }
    
    private func loadPromptAndInsertData(fileName: String, data: String, lineNumber: Int) throws -> String {
        print("=== Debug: Loading Prompt File ===")
        print("File Name: \(fileName)")
        print("Line Number: \(lineNumber)")
        
        // First try with explicit path
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "Resources/Prompts") {
            print("Found file in Resources/Prompts: \(url.path)")
            if let content = try? String(contentsOf: url) {
                let lines = content.components(separatedBy: .newlines)
                guard lineNumber <= lines.count else {
                    print("Error: Line number \(lineNumber) exceeds file length \(lines.count)")
                    throw GeminiError.invalidPromptFile
                }
                
                var modifiedLines = lines
                modifiedLines.insert(data, at: lineNumber - 1)
                return modifiedLines.joined(separator: "\n")
            }
        }
        
        // Then try without subdirectory
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
            print("Found file in root: \(url.path)")
            if let content = try? String(contentsOf: url) {
                let lines = content.components(separatedBy: .newlines)
                guard lineNumber <= lines.count else {
                    print("Error: Line number \(lineNumber) exceeds file length \(lines.count)")
                    throw GeminiError.invalidPromptFile
                }
                
                var modifiedLines = lines
                modifiedLines.insert(data, at: lineNumber - 1)
                return modifiedLines.joined(separator: "\n")
            }
        }
        
        print("Error: Could not find prompt file")
        throw GeminiError.invalidPromptFile
    }
    
    public func generateContent(withPromptFiles fileNames: [String], input: [String: Any], schema: Schema) async throws -> [String: Any] {
        let model = try getModel(with: schema)
        print(fileNames)
        
        let promptContent = try loadPrompts(from: fileNames)
        print(promptContent)
        let inputJson = try JSONSerialization.data(withJSONObject: input)
        let inputString = String(data: inputJson, encoding: .utf8) ?? "{}"
        
        let prompt = promptContent + "\n" + inputString
        print("--------------- Promp start ---------------")
        print(prompt)
        print("--------------- Promp end ---------------")
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let responseText = response.text,
                  let responseData = responseText.data(using: .utf8),
                  var jsonResponse = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                throw GeminiError.invalidResponse
            }
            
            // 遞迴處理所有的字典值，將 Unicode 轉換為可讀的中文
            func convertUnicodeInDictionary(_ dict: [String: Any]) -> [String: Any] {
                var result: [String: Any] = [:]
                
                for (key, value) in dict {
                    if let strValue = value as? String {
                        // 處理字符串值
                        result[key] = strValue.removingPercentEncoding ?? strValue
                    } else if let dictValue = value as? [String: Any] {
                        // 遞迴處理嵌套的字典
                        result[key] = convertUnicodeInDictionary(dictValue)
                    } else if let arrayValue = value as? [Any] {
                        // 處理數組
                        result[key] = arrayValue.map { item -> Any in
                            if let dictItem = item as? [String: Any] {
                                return convertUnicodeInDictionary(dictItem)
                            } else if let strItem = item as? String {
                                return strItem.removingPercentEncoding ?? strItem
                            }
                            return item
                        }
                    } else {
                        result[key] = value
                    }
                }
                
                return result
            }
            
            // 處理整個回應
            jsonResponse = convertUnicodeInDictionary(jsonResponse)
            
            return jsonResponse
        } catch {
            print("Generate content error: \(error)")
            throw error
        }
    }
    
    // MARK: - Public Methods
    
    func generateTrainingPlan(withPromptFiles fileNames: [String], input: [String: Any]) async throws -> [String: Any] {
        return try await generateContent(withPromptFiles: fileNames, input: input, schema: trainingPlanSchema)
    }
    
    func generateFollowingPlan(input: [String: Any]) async throws -> [String: Any] {
        let model = try getModel(with: trainingPlanSchema)
        
        // 將 input 轉換為 JSON 字符串
        let inputJson = try JSONSerialization.data(withJSONObject: input)
        let inputString = String(data: inputJson, encoding: .utf8) ?? "{}"
        
        // 讀取基礎 prompt
        let basePrompt = try loadPrompts(from: ["prompt_training_plan_base"])
        
        // 讀取並插入數據到 following prompt
        let followingPrompt = try loadPromptAndInsertData(fileName: "prompt_following_plan", data: inputString, lineNumber: 3)
        
        // 合併兩個 prompt
        let combinedPrompt = """
        \(basePrompt)
        
        \(followingPrompt)
        """
        
        print("=== Generated Combined Prompt ===")
        print(combinedPrompt)
        
        do {
            let response = try await model.generateContent(combinedPrompt)
            
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
    
    func generateSummary(withPromptFiles fileNames: [String], input: [String: Any]) async throws -> [String: Any] {
        return try await generateContent(withPromptFiles: fileNames, input: input, schema: summarySchema)
    }
}
