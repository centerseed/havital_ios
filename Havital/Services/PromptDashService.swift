import Foundation

class PromptDashService {
    static let shared = PromptDashService()
    private let apiKey: String
    
    private init() {
        guard let path = Bundle.main.path(forResource: "APIKeys", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let apiKey = dict["PromptDashAPIKey"] as? String else {
            fatalError("Could not find PromptDashAPIKey in APIKeys.plist")
        }
        self.apiKey = apiKey
    }
    
    struct Variable {
        let key: String
        let value: String
    }
    
    enum PromptDashError: Error {
        case invalidURL
        case invalidResponse
        case networkError(Error)
        case fileNotFound(String)
        case fileReadError(Error)
        case invalidInput(String)
    }
    
    private func loadJSONContent(fileName: String) throws -> String {
        let possiblePaths = [
            Bundle.main.path(forResource: fileName, ofType: "json"),
            Bundle.main.path(forResource: fileName, ofType: "json", inDirectory: "Resources"),
            Bundle.main.path(forResource: fileName, ofType: "json", inDirectory: "Resources/Prompts"),
            Bundle.main.path(forResource: fileName, ofType: "json", inDirectory: "/Resources"),
            Bundle.main.path(forResource: fileName, ofType: "json", inDirectory: "/Resources/Prompts")
        ]
        
        for path in possiblePaths {
            if let path = path {
                if FileManager.default.fileExists(atPath: path) {
                    do {
                        let content = try String(contentsOfFile: path, encoding: .utf8)
                        return content
                    } catch {
                        throw PromptDashError.fileReadError(error)
                    }
                }
            }
        }
        
        throw PromptDashError.fileNotFound(fileName)
    }
    
    func generateContent(apiPath: String, userMessage: String, variables: [[String: String]]) async throws -> [String: Any] {
        guard let url = URL(string: "https://api.promptdash.io\(apiPath)") else {
            throw PromptDashError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "DASH_API_KEY")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let variableList = try variables.map { variable in
            guard let (key, jsonFileName) = variable.first else {
                throw PromptDashError.invalidInput("Invalid variable format")
            }
            let jsonContent = try loadJSONContent(fileName: jsonFileName)
            return ["name": key, "value": jsonContent]
        }
        
        let body: [String: Any] = [
            "userMessage": userMessage,
            "variables": variableList
        ]
        //print("body: \(body)")
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            //print("response: \(String(data: data, encoding: .utf8) ?? "")")

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw PromptDashError.invalidResponse
            }
            
            if let jsonData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseString = jsonData["response"] as? String,
               let responseData = responseString.data(using: .utf8),
               let responseJson = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                
                // 遞迴函數處理所有層級的 Unicode 字符
                func decodeUnicode(in dict: [String: Any]) -> [String: Any] {
                    var result: [String: Any] = [:]
                    
                    for (key, value) in dict {
                        switch value {
                        case let string as String:
                            // 處理字符串中的 Unicode
                            result[key] = string.removingPercentEncoding ?? string
                        case let array as [[String: Any]]:
                            // 處理數組中的字典
                            result[key] = array.map { decodeUnicode(in: $0) }
                        case let array as [String]:
                            // 處理字符串數組
                            result[key] = array.map { $0.removingPercentEncoding ?? $0 }
                        case let nestedDict as [String: Any]:
                            // 遞迴處理嵌套字典
                            result[key] = decodeUnicode(in: nestedDict)
                        default:
                            result[key] = value
                        }
                    }
                    
                    return result
                }
                
                // 處理整個回應
                return decodeUnicode(in: responseJson)
            }
            
            throw PromptDashError.invalidResponse
            
        } catch {
            throw PromptDashError.networkError(error)
        }
    }
}
