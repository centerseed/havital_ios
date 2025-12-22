# User Preferences API - iOS Integration Guide

## 概述

此 API 用於管理用戶的語言和時區偏好設定，確保訓練計畫的週數計算、課表生成時間都能正確對應用戶所在時區。

---

## API Endpoints

### 1. 獲取用戶偏好設定

**Endpoint**: `GET /api/v1/user/preferences`

**Headers**:
```
Authorization: Bearer {firebase_id_token}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "language": "zh-TW",
    "timezone": "Asia/Taipei",
    "supported_languages": ["zh-TW", "ja-JP", "en-US"],
    "language_names": {
      "zh-TW": "繁體中文",
      "ja-JP": "日本語",
      "en-US": "English"
    }
  }
}
```

---

### 2. 更新用戶偏好設定

**Endpoint**: `PUT /api/v1/user/preferences`

**Headers**:
```
Authorization: Bearer {firebase_id_token}
Content-Type: application/json
```

**Request Body**:
```json
{
  "timezone": "Asia/Taipei",  // 可選，IANA 時區格式
  "language": "zh-TW"         // 可選，語言代碼
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Timezone set to Asia/Taipei",
  "data": {
    "timezone": "Asia/Taipei",
    "language": "zh-TW"
  }
}
```

**Error Response** (400 Bad Request):
```json
{
  "success": false,
  "error": "At least one of language or timezone must be provided"
}
```

---

## iOS 實作指南

### Step 1: 獲取裝置時區

iOS 會自動提供符合 IANA 標準的時區字串，可以直接使用：

```swift
import Foundation

class TimezoneHelper {
    /// 獲取裝置當前時區（IANA 格式）
    static func getDeviceTimezone() -> String {
        return TimeZone.current.identifier
        // 回傳範例: "Asia/Taipei", "America/New_York"
    }

    /// 獲取時區的本地化顯示名稱
    static func getTimezoneDisplayName() -> String {
        let tz = TimeZone.current
        return tz.localizedName(for: .standard, locale: Locale.current) ?? tz.identifier
        // 回傳範例: "台北標準時間", "Taipei Standard Time"
    }
}
```

---

### Step 2: 用戶註冊時設定時區

在用戶首次註冊或登入時，自動獲取並發送時區資訊到後端：

```swift
import FirebaseAuth

class UserPreferencesManager {

    private let baseURL = "https://api.havital.com"

    /// 用戶首次註冊時初始化偏好設定
    func initializeUserPreferences() async throws {
        guard let idToken = try await Auth.auth().currentUser?.getIDToken() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let timezone = TimeZone.current.identifier
        let language = Locale.current.language.languageCode?.identifier ?? "zh-TW"

        try await updatePreferences(timezone: timezone, language: language, idToken: idToken)
    }

    /// 更新用戶偏好設定
    func updatePreferences(
        timezone: String? = nil,
        language: String? = nil,
        idToken: String
    ) async throws {
        var requestBody: [String: String] = [:]

        if let timezone = timezone {
            requestBody["timezone"] = timezone
        }
        if let language = language {
            requestBody["language"] = language
        }

        guard !requestBody.isEmpty else {
            throw NSError(domain: "Validation", code: 400,
                         userInfo: [NSLocalizedDescriptionKey: "At least one field required"])
        }

        let url = URL(string: "\(baseURL)/api/v1/user/preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "Network", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        print("Preferences updated successfully")
    }

    /// 獲取用戶偏好設定
    func getPreferences(idToken: String) async throws -> UserPreferences {
        let url = URL(string: "\(baseURL)/api/v1/user/preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "Network", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        let apiResponse = try JSONDecoder().decode(PreferencesResponse.self, from: data)
        return apiResponse.data
    }
}

// MARK: - Data Models

struct UserPreferences: Codable {
    let language: String
    let timezone: String
    let supportedLanguages: [String]
    let languageNames: [String: String]

    enum CodingKeys: String, CodingKey {
        case language
        case timezone
        case supportedLanguages = "supported_languages"
        case languageNames = "language_names"
    }
}

struct PreferencesResponse: Codable {
    let success: Bool
    let data: UserPreferences
}
```

---

### Step 3: 在設定頁面提供時區選擇

```swift
import SwiftUI

struct TimezonePicker: View {
    @State private var selectedTimezone: String = TimeZone.current.identifier

    // 常用時區列表
    let commonTimezones = [
        TimeZoneOption(id: "Asia/Taipei", name: "台北 (GMT+8)"),
        TimeZoneOption(id: "Asia/Tokyo", name: "東京 (GMT+9)"),
        TimeZoneOption(id: "Asia/Hong_Kong", name: "香港 (GMT+8)"),
        TimeZoneOption(id: "Asia/Singapore", name: "新加坡 (GMT+8)"),
        TimeZoneOption(id: "America/New_York", name: "紐約 (GMT-5/-4)"),
        TimeZoneOption(id: "America/Los_Angeles", name: "洛杉磯 (GMT-8/-7)"),
        TimeZoneOption(id: "Europe/London", name: "倫敦 (GMT+0/+1)"),
        TimeZoneOption(id: "Australia/Sydney", name: "雪梨 (GMT+10/+11)")
    ]

    var body: some View {
        Form {
            Section(header: Text("時區設定")) {
                Picker("選擇時區", selection: $selectedTimezone) {
                    ForEach(commonTimezones) { option in
                        Text(option.name).tag(option.id)
                    }
                }
            }

            Section {
                Button("儲存") {
                    Task {
                        await saveTimezone()
                    }
                }
            }
        }
        .navigationTitle("時區設定")
    }

    private func saveTimezone() async {
        do {
            let idToken = try await Auth.auth().currentUser?.getIDToken() ?? ""
            let manager = UserPreferencesManager()
            try await manager.updatePreferences(timezone: selectedTimezone, idToken: idToken)
        } catch {
            print("Failed to update timezone: \(error)")
        }
    }
}

struct TimeZoneOption: Identifiable {
    let id: String
    let name: String
}
```

---

### Step 4: App 啟動時同步時區

確保用戶時區變更時（例如旅行）能自動同步：

```swift
import UIKit
import FirebaseAuth

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 監聽時區變更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timezoneDidChange),
            name: UIApplication.significantTimeChangeNotification,
            object: nil
        )

        return true
    }

    @objc private func timezoneDidChange() {
        Task {
            await syncTimezoneIfNeeded()
        }
    }

    private func syncTimezoneIfNeeded() async {
        guard let idToken = try? await Auth.auth().currentUser?.getIDToken() else {
            return
        }

        let deviceTimezone = TimeZone.current.identifier
        let manager = UserPreferencesManager()

        do {
            let preferences = try await manager.getPreferences(idToken: idToken)

            // 如果裝置時區與後端不同，自動更新
            if preferences.timezone != deviceTimezone {
                try await manager.updatePreferences(timezone: deviceTimezone, idToken: idToken)
                print("Timezone synced: \(deviceTimezone)")
            }
        } catch {
            print("Failed to sync timezone: \(error)")
        }
    }
}
```

---

## 最佳實踐

### 1. **自動初始化時區**
- ✅ 用戶註冊後立即發送時區資訊
- ✅ App 啟動時檢查時區是否變更

### 2. **錯誤處理**
```swift
do {
    try await manager.updatePreferences(timezone: timezone, idToken: idToken)
} catch let error as NSError {
    switch error.code {
    case 400:
        print("Invalid timezone format")
    case 401:
        print("Authentication failed")
    case 500:
        print("Server error")
    default:
        print("Unknown error: \(error)")
    }
}
```

### 3. **本地快取**
```swift
class PreferencesCache {
    static let shared = PreferencesCache()

    private let defaults = UserDefaults.standard
    private let timezoneKey = "user_timezone"

    var cachedTimezone: String? {
        get { defaults.string(forKey: timezoneKey) }
        set { defaults.set(newValue, forKey: timezoneKey) }
    }
}
```

### 4. **支援的時區格式**

**✅ 正確的 IANA 時區格式**:
- `Asia/Taipei`
- `America/New_York`
- `Europe/London`

**❌ 不支援的格式**:
- `GMT+8` (非 IANA 格式)
- `Taipei` (缺少地區前綴)
- `CST` (時區縮寫，不明確)

---

## 完整範例：註冊流程整合

```swift
class RegistrationViewController: UIViewController {

    func completeRegistration() async {
        do {
            // 1. 建立 Firebase 用戶
            let authResult = try await Auth.auth().createUser(
                withEmail: email,
                password: password
            )

            // 2. 獲取 ID Token
            let idToken = try await authResult.user.getIDToken()

            // 3. 初始化用戶偏好（包含時區）
            let timezone = TimeZone.current.identifier
            let language = Locale.current.language.languageCode?.identifier ?? "zh-TW"

            let manager = UserPreferencesManager()
            try await manager.updatePreferences(
                timezone: timezone,
                language: language,
                idToken: idToken
            )

            print("✅ Registration completed with timezone: \(timezone)")

            // 4. 導航到主頁面
            navigateToHome()

        } catch {
            print("❌ Registration failed: \(error)")
            showError(error)
        }
    }
}
```

---

## 測試建議

### 1. **測試不同時區**

在模擬器中測試不同時區：
```
Settings → General → Date & Time → Time Zone
```

### 2. **測試時區變更**

模擬旅行場景，驗證時區自動同步功能。

### 3. **測試離線場景**

確保離線時不會崩潰，並在連線恢復時自動同步。

---

## 常見問題 (FAQ)

### Q1: 為什麼需要時區資訊？
**A**: 訓練計畫的週數計算、課表生成時間都依賴用戶時區。例如：
- 判斷「當前週數」（週一 00:00 ~ 週日 23:59，用戶時區）
- 判斷是否為週末（可提前生成下週課表）

### Q2: 時區變更後會發生什麼？
**A**: 週數計算會依據新時區重新計算，可能導致週數變化。建議提示用戶確認。

### Q3: 支援所有 IANA 時區嗎？
**A**: 是的，後端使用 `pytz` 驗證，支援所有標準 IANA 時區。

### Q4: 夏令時如何處理？
**A**: IANA 時區格式自動處理夏令時，無需額外處理。

---

## 聯絡資訊

如有問題或需要技術支援，請聯繫：
- **Email**: dev@havital.com
- **文檔**: https://docs.havital.com

---

**最後更新**: 2024-10-23
**API 版本**: v1
