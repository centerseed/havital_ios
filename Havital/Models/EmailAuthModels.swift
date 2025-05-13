import Foundation

// Models for Email Authentication API Responses

/// 註冊回傳資料
struct RegisterData: Decodable {
    let uid: String
    let email: String
    let message: String
}

/// 登入回傳用戶資料
struct LoginDataUser: Decodable {
    let uid: String
    let email: String
}

/// 登入回傳資料
struct LoginData: Decodable {
    let token: String
    let user: LoginDataUser
}

/// 驗證 Email 回傳資料
struct VerifyData: Decodable {
    let uid: String
    let message: String
}
