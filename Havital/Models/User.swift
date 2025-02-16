import Foundation

struct User: Codable {
    let id: String
    let email: String
    let name: String?
    let photoURL: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case photoURL = "photo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GoogleLoginRequest: Codable {
    let idToken: String
    
    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}
