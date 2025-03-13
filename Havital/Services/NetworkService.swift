import Foundation

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    func request<T: Decodable>(_ endpoint: Endpoint, body: Encodable? = nil) async throws -> T {
        var urlRequest = try endpoint.makeRequest()
        
        if let body = body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }
        
        // Add authentication token to header if user is authenticated
        if endpoint.requiresAuth {
            let token = try await AuthenticationService.shared.getIdToken()
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let requiresAuth: Bool
    let queryItems: [URLQueryItem]?
    let body: Data?
    
    init(
        path: String,
        method: HTTPMethod = .get,
        requiresAuth: Bool = true,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) throws {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth
        self.queryItems = queryItems
        self.body = try body?.toJSONData()
    }
    
    func makeRequest() throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api-service-364865009192.asia-east1.run.app" // Replace with your API domain
        components.path = path
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

extension Encodable {
    func toJSONData() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
