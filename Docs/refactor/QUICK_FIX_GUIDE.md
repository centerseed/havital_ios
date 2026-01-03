# 快速修復指南

如果編譯或測試失敗，使用此指南快速定位和修復問題。

---

## 🔧 預期可能需要的修復

### 修復 1: 添加 Error.toDomainError() 擴展

**文件**: `Havital/Shared/Errors/DomainError.swift`

如果看到錯誤: `Value of type 'Error' has no member 'toDomainError'`

**在文件末尾添加**:

```swift
// MARK: - Error Extensions
extension Error {
    func toDomainError() -> DomainError {
        // 已經是 DomainError
        if let domainError = self as? DomainError {
            return domainError
        }

        // TrainingPlanError 轉換
        if let trainingError = self as? TrainingPlanError {
            return trainingError.toDomainError()
        }

        // HTTPError 轉換
        if let httpError = self as? HTTPError {
            switch httpError {
            case .notFound(let message):
                return .notFound(message)
            case .unauthorized:
                return .unauthorized
            case .serverError(let code, let message):
                return .networkFailure("\(code): \(message)")
            default:
                return .networkFailure(localizedDescription)
            }
        }

        // NSError 取消檢查
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return .cancellation
        }

        // 未知錯誤
        return .unknown(localizedDescription)
    }
}
```

---

### 修復 2: 檢查 DomainError 是否有 .cancellation case

**文件**: `Havital/Shared/Errors/DomainError.swift`

如果看到錯誤: `Type 'DomainError' has no member 'cancellation'`

**確保 DomainError enum 有此 case**:

```swift
enum DomainError: Error, Equatable {
    case networkFailure(String)
    case notFound(String)
    case unauthorized
    case validationFailure(String)
    case dataCorruption(String)
    case cancellation  // ⭐ 確保有這一行
    case unknown(String)

    // ... 其他代碼
}
```

---

### 修復 3: 添加 DomainError 便利方法

**文件**: `Havital/Shared/Errors/DomainError.swift`

如果 ViewModel 中使用了 `error.toNSError()`，添加此擴展:

```swift
extension DomainError {
    func toNSError() -> NSError {
        let domain = "com.havital.domain"
        let message = self.localizedDescription ?? "Unknown error"

        switch self {
        case .networkFailure:
            return NSError(domain: domain, code: -1001, userInfo: [NSLocalizedDescriptionKey: message])
        case .notFound:
            return NSError(domain: domain, code: -1002, userInfo: [NSLocalizedDescriptionKey: message])
        case .unauthorized:
            return NSError(domain: domain, code: -1003, userInfo: [NSLocalizedDescriptionKey: message])
        case .validationFailure:
            return NSError(domain: domain, code: -1004, userInfo: [NSLocalizedDescriptionKey: message])
        case .dataCorruption:
            return NSError(domain: domain, code: -1005, userInfo: [NSLocalizedDescriptionKey: message])
        case .cancellation:
            return NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
        case .unknown:
            return NSError(domain: domain, code: -9999, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    var localizedDescription: String? {
        switch self {
        case .networkFailure(let message),
             .notFound(let message),
             .validationFailure(let message),
             .dataCorruption(let message),
             .unknown(let message):
            return message
        case .unauthorized:
            return "Unauthorized access"
        case .cancellation:
            return "Task was cancelled"
        }
    }
}
```

---

### 修復 4: 確認 Modification 模型存在

**文件**: 檢查 `Havital/Models/Modification.swift` 是否存在

如果不存在，Repository Protocol 中的 Modifications 方法會報錯。

**選項 1**: 暫時註釋掉 Repository 中的 Modifications 方法
**選項 2**: 創建簡單的佔位符模型

```swift
struct Modification: Codable {
    let id: String
    let description: String
}

struct NewModification: Codable {
    let description: String
}
```

---

### 修復 5: 測試 Target 名稱

**文件**: 所有測試文件

如果看到: `No such module 'paceriz_dev'`

**檢查實際的 Bundle Identifier**:
1. 在 Xcode 中選擇 Havital target
2. 查看 General > Bundle Identifier
3. 將測試文件中的 `@testable import paceriz_dev` 改為實際名稱

可能是:
```swift
@testable import Havital
// 或
@testable import HavitalApp
```

---

### 修復 6: 確認 ResponseProcessor 存在

**文件**: `TrainingPlanRemoteDataSource.swift`

如果看到: `Cannot find 'ResponseProcessor' in scope`

**檢查是否有此工具類**，或替換為:

```swift
// 替換
return try ResponseProcessor.extractData(WeeklyPlan.self, from: rawData, using: parser)

// 為
let response = try parser.parse(APIResponse<WeeklyPlan>.self, from: rawData)
return response.data
```

其中 `APIResponse` 定義為:

```swift
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
}
```

---

## 🧪 測試相關修復

### 測試失敗: "Task was cancelled"

如果測試輸出顯示 cancellation error:

**原因**: 測試結束太快，async 任務被取消

**解決**: 添加適當的 await

```swift
// ❌ 錯誤
func testSomething() {
    Task {
        await viewModel.loadData()
    }
    // 測試立即結束，Task 被取消
}

// ✅ 正確
func testSomething() async throws {
    await viewModel.loadData()
    XCTAssertNotNil(viewModel.data)
}
```

---

### 測試失敗: "XCTAssertEqual failed"

**調試方法**:

```swift
// 添加詳細輸出
func testCreateWeeklySummary_Success() async throws {
    await viewModel.createWeeklySummary(weekNumber: 3)

    // 調試輸出
    print("📊 State: \(viewModel.summaryState)")
    print("📊 Error: \(String(describing: viewModel.summaryError))")
    print("📊 isGenerating: \(viewModel.isGenerating)")

    XCTAssertEqual(viewModel.summaryState.data?.id, "summary_1")
}
```

---

### 測試失敗: "Mock not configured"

**確認 Mock 設置**:

```swift
func testSomething() async throws {
    // ✅ 在調用前設置 Mock
    mockRepository.weeklySummaryToReturn = try TrainingPlanTestFixtures.createWeeklySummary()

    await viewModel.createWeeklySummary()

    XCTAssertNotNil(viewModel.currentSummary)
}
```

---

## 🎯 完整的 DomainError.swift 範例

如果需要完整重寫，使用此模板:

```swift
import Foundation

// MARK: - Domain Error
enum DomainError: Error, Equatable {
    case networkFailure(String)
    case notFound(String)
    case unauthorized
    case validationFailure(String)
    case dataCorruption(String)
    case cancellation
    case unknown(String)

    static func == (lhs: DomainError, rhs: DomainError) -> Bool {
        switch (lhs, rhs) {
        case (.networkFailure(let l), .networkFailure(let r)),
             (.notFound(let l), .notFound(let r)),
             (.validationFailure(let l), .validationFailure(let r)),
             (.dataCorruption(let l), .dataCorruption(let r)),
             (.unknown(let l), .unknown(let r)):
            return l == r
        case (.unauthorized, .unauthorized),
             (.cancellation, .cancellation):
            return true
        default:
            return false
        }
    }

    var localizedDescription: String? {
        switch self {
        case .networkFailure(let message),
             .notFound(let message),
             .validationFailure(let message),
             .dataCorruption(let message),
             .unknown(let message):
            return message
        case .unauthorized:
            return "Unauthorized access"
        case .cancellation:
            return "Task was cancelled"
        }
    }

    func toNSError() -> NSError {
        let domain = "com.havital.domain"
        let message = self.localizedDescription ?? "Unknown error"

        switch self {
        case .networkFailure:
            return NSError(domain: domain, code: -1001, userInfo: [NSLocalizedDescriptionKey: message])
        case .notFound:
            return NSError(domain: domain, code: -1002, userInfo: [NSLocalizedDescriptionKey: message])
        case .unauthorized:
            return NSError(domain: domain, code: -1003, userInfo: [NSLocalizedDescriptionKey: message])
        case .validationFailure:
            return NSError(domain: domain, code: -1004, userInfo: [NSLocalizedDescriptionKey: message])
        case .dataCorruption:
            return NSError(domain: domain, code: -1005, userInfo: [NSLocalizedDescriptionKey: message])
        case .cancellation:
            return NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
        case .unknown:
            return NSError(domain: domain, code: -9999, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}

// MARK: - Error Extensions
extension Error {
    func toDomainError() -> DomainError {
        if let domainError = self as? DomainError {
            return domainError
        }

        if let trainingError = self as? TrainingPlanError {
            return trainingError.toDomainError()
        }

        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return .cancellation
        }

        return .unknown(localizedDescription)
    }
}
```

---

## 📞 獲取幫助

如果遇到未列出的錯誤:

1. **複製完整錯誤訊息**
2. **檢查錯誤文件和行號**
3. **查看 REFACTOR_COMPLETION_REPORT.md 中的架構說明**
4. **確認所有新文件都已加入 Xcode Target**

---

**快速修復優先順序**:
1. ✅ DomainError.swift 擴展（最常見）
2. ✅ 測試 Target 名稱
3. ✅ Mock 配置
4. ✅ 其他小問題

**修復後別忘了**: `git add . && git commit -m "fix: compilation errors"`
