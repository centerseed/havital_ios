---
type: TD
id: TD-version-gate-announcements
status: Draft
created: 2026-04-16
updated: 2026-04-16
features:
  - Version Gate (soft + hard)
  - Announcement Banner + Message Center
target_version: 1.3.0
---

# 技術設計：Version Gate + 公告系統（App 1.3.0）

## 調查報告

### 已讀文件（附具體發現）

| 檔案 | 發現 |
|------|------|
| `Havital/Features/Authentication/Data/DTOs/UserSyncResponse.swift` | 目前 3 個欄位：`user`, `onboardingStatus`, `shouldCompleteOnboarding`。無 `versionCheck`。`CodingKeys` 需補 `versionCheck = "version_check"`。 |
| `Havital/Services/Core/HTTPClient.swift:296-324` | `validateHTTPResponse()` switch 有 400/401/403/404/429/500-599，**426 不在任何 case，落到 `default: throw HTTPError.httpError(426, errorBody)`**。需加 named case。 |
| `Havital/Services/Core/HTTPErrorPayloads.swift` | FastAPI 格式 `{"detail": {...}}`。`SubscriptionErrorDetailWrapper`、`RizoUsageDetailWrapper` 為既有範本，426 payload 按同樣模式新增。 |
| `Havital/Shared/Errors/DomainError.swift` | 有 `subscriptionRequired`、`trialExpired`、`rizoQuotaExceeded`。**無 `forceUpdateRequired`**，需新增。`shouldShowErrorView` 需排除此 case。 |
| `Havital/Features/Authentication/Domain/Errors/AuthError.swift` | 有 `backendSyncFailed`、`onboardingRequired`。**無 `forceUpdateRequired`**，需新增。 |
| `Havital/Features/Authentication/Data/Repositories/AuthRepositoryImpl.swift:82-93` | `signInWithGoogle()` Step 5 呼叫 `backendAuth.syncUserWithBackend()` 取得 `syncResponse`，Step 6 直接進 mapper。**攔截點在 Step 5 → Step 6 之間**。`signInWithApple()` 兩個 overload 相同位置也需處理。|
| `Havital/Features/Authentication/Data/DataSources/BackendAuthDataSource.swift` | `syncUserWithBackend()` 負責解析 `UserSyncResponse`，是最早拿到 `versionCheck` 的地方。架構規則：攔截邏輯放 RepositoryImpl，不放 DataSource。 |
| `Havital/Features/Authentication/Presentation/ViewModels/AuthenticationViewModel.swift` | Singleton。`ContentView` 用的是此 ViewModel（不是 `AuthCoordinatorViewModel`）。有 `@Published var error: DomainError?`，需新增 `requiresForceUpdate: Bool` 和 `forceUpdateUrl: String?`。 |
| `Havital/Views/ContentView.swift:17-80` | 路由順序：`shouldShowLoadingScreen` → `!isAuthenticated` → `!hasCompletedOnboarding` → `isReonboardingMode` → main app。**ForceUpdateView 需插入最高優先（loading 之後，login 之前）**。 |
| `Havital/Features/Authentication/Presentation/ViewModels/AuthCoordinatorViewModel.swift` | `AuthState` enum 目前 5 個 case，不被 ContentView 直接使用（ContentView 用的是 AuthenticationViewModel）。本次不動此 ViewModel。 |

### 搜尋但未找到

- `Announcement*` Swift 檔案 → 無，屬全新模組
- `ForceUpdate*` Swift 檔案 → 無，屬全新模組
- `docs/specs/SPEC-*version*` / `SPEC-*announcement*` → 無正式 Spec。本 TD 從後端 API 文件直接提煉 AC，並自行賦予 AC ID。

### 未確認事項（已在實作章節標記）

- 首頁 Banner 嵌入哪個具體 View（TrainingOverviewView 或 TabView root）→ **[未確認]**，Developer 實作前需 grep 確認主畫面入口。
- `AppVersion` 比對邏輯是否有現成 utility → **[未確認]**，本次不需要前端比對（由後端 `forceUpdate` 欄位決定），但 426 保底路徑亦不需要前端比對版本。

---

## AC Compliance Matrix

### Feature A：Version Gate

| AC ID | AC 描述 | 預計實作位置 | Test Function | 狀態 |
|-------|---------|------------|---------------|------|
| AC-VG-01 | 登入時 `versionCheck.forceUpdate=true` → `ContentView` 顯示全螢幕不可關閉 `ForceUpdateView` | `AuthRepositoryImpl` + `AuthenticationViewModel` + `ContentView` | `test_ac_vg_01_force_update_shows_view` | STUB |
| AC-VG-02 | `ForceUpdateView` CTA tap → 開啟 `vc.updateUrl`（App Store 連結） | `ForceUpdateView` | `test_ac_vg_02_cta_opens_appstore` | STUB |
| AC-VG-03 | 任意 API 返回 HTTP 426 → `AuthenticationViewModel.requiresForceUpdate=true`，UI 顯示更新提示（不 crash，不空白） | `HTTPClient` + `DomainError` + `AuthenticationViewModel` | `test_ac_vg_03_426_triggers_force_update` | STUB |
| AC-VG-04 | `versionCheck=nil`（後端未回傳此欄位）→ 正常進入 App，無任何更新邏輯觸發 | `AuthRepositoryImpl` | `test_ac_vg_04_nil_versioncheck_no_gate` | STUB |
| AC-VG-05 | `versionCheck.forceUpdate=false` → 正常進入 App，不觸發 `ForceUpdateView` | `AuthRepositoryImpl` | `test_ac_vg_05_soft_false_no_block` | STUB |

### Feature B：公告系統

| AC ID | AC 描述 | 預計實作位置 | Test Function | 狀態 |
|-------|---------|------------|---------------|------|
| AC-ANN-01 | App 啟動後有 `is_seen=false` 公告 → 首頁顯示 `published_at` 最新一則 Banner | `AnnouncementViewModel` | `test_ac_ann_01_banner_shows_latest_unread` | STUB |
| AC-ANN-02 | Banner 顯示後 → 自動 POST `/v2/announcements/{id}/seen` → 下次進首頁不再顯示同一則 | `AnnouncementViewModel` | `test_ac_ann_02_banner_auto_marks_seen` | STUB |
| AC-ANN-03 | 無未讀公告（全部 `is_seen=true`）→ 首頁不顯示 Banner | `AnnouncementViewModel` | `test_ac_ann_03_no_banner_when_all_read` | STUB |
| AC-ANN-04 | 進入訊息中心 → 顯示全部公告列表（含已讀），每則顯示 title + body + published_at | `MessageCenterView` | `test_ac_ann_04_message_center_shows_all` | STUB |
| AC-ANN-05 | 進入訊息中心 → POST `/v2/announcements/seen-batch`（body: 所有未讀 ID）→ 紅點角標消失 | `AnnouncementViewModel` | `test_ac_ann_05_batch_seen_clears_badge` | STUB |
| AC-ANN-06 | 公告有 `cta_url=paceriz://subscription` → 點 CTA 導向訂閱頁；無 `cta_url` → 無 CTA 按鈕 | `AnnouncementBannerView` | `test_ac_ann_06_deeplink_cta_routing` | STUB |
| AC-ANN-07 | 公告有 `image_url` → Banner 顯示圖片；無 `image_url` → 純文字 Banner（不空白不 crash）| `AnnouncementBannerView` | `test_ac_ann_07_image_url_fallback` | STUB |

---

## Feature A：Version Gate

### 1. DTO 變更

**修改 `Havital/Features/Authentication/Data/DTOs/UserSyncResponse.swift`**

```swift
// 在 UserSyncResponse 新增
struct UserSyncResponse: Codable {
    let user: UserDTO
    let onboardingStatus: OnboardingStatusDTO
    let shouldCompleteOnboarding: Bool
    let versionCheck: VersionCheckDTO?   // ← NEW：Optional，後端不回傳時自動 nil

    enum CodingKeys: String, CodingKey {
        case user
        case onboardingStatus       = "onboarding_status"
        case shouldCompleteOnboarding = "should_complete_onboarding"
        case versionCheck           = "version_check"   // ← NEW
    }
}

// 新增 DTO
struct VersionCheckDTO: Codable {
    let minAppVersion: String?
    let forceUpdate: Bool
    let updateUrl: String?

    enum CodingKeys: String, CodingKey {
        case minAppVersion = "min_app_version"
        case forceUpdate   = "force_update"
        case updateUrl     = "update_url"
    }
}
```

**設計理由：** Swift `Codable` 的 `Optional` 在 JSON 缺少欄位時自動解碼為 `nil`，舊版後端不回傳此欄位時不會 `DecodingError`，向下相容。

### 2. 新增 ForceUpdate HTTP Error Payload

**修改 `Havital/Services/Core/HTTPErrorPayloads.swift`**：新增 426 payload 結構。

426 用 `JSONResponse` 直接回傳（不是 FastAPI `HTTPException`），所以**不需要** `detail` wrapper，直接 decode：

```swift
// MARK: - Force Update Error (426)
// 後端用 JSONResponse 直接回傳，無 FastAPI {"detail": ...} 包裝

struct ForceUpdatePayload: Decodable {
    let error: String
    let updateUrl: String?
    let minAppVersion: String?

    enum CodingKeys: String, CodingKey {
        case error
        case updateUrl       = "update_url"
        case minAppVersion   = "min_app_version"
    }
}
```

> **注意：** 403/429 用 `SubscriptionErrorDetailWrapper` / `RizoUsageDetailWrapper` 是因為那兩個走 FastAPI `HTTPException` 自動加的 `{"detail": {...}}`。426 是後端完全控制的 `JSONResponse`，格式是 `{"error": "...", "update_url": "...", "min_app_version": "..."}`，直接 decode 即可。

### 3. HTTPError + HTTPClient 426 Case

**修改 `Havital/Services/Core/HTTPClient.swift`**

在 `HTTPError` enum 新增：
```swift
case forceUpdateRequired(ForceUpdatePayload)
```

在 `validateHTTPResponse()` switch 新增 case（在 `case 429:` 之後）：
```swift
case 426:
    if let body = try? Self.errorPayloadDecoder.decode(ForceUpdatePayload.self, from: data) {
        throw HTTPError.forceUpdateRequired(body)
    }
    // fallback：decode 失敗時（舊版後端格式不符），建最小 payload
    throw HTTPError.forceUpdateRequired(
        ForceUpdatePayload(error: "upgrade_required", updateUrl: nil, minAppVersion: nil)
    )
```

`HTTPError.errorDescription` 補充：
```swift
case .forceUpdateRequired:
    return "App 版本過舊，請前往 App Store 更新"
```

`HTTPError.isCancelled` 不影響（`forceUpdateRequired` 不是取消）。

### 4. DomainError 新增 Case

**修改 `Havital/Shared/Errors/DomainError.swift`**

```swift
// MARK: - 版本強制更新
case forceUpdateRequired(updateUrl: String?)
```

- `errorDescription`: `"App 版本過舊，請前往 App Store 更新"`
- `shouldShowErrorView`: 回傳 `false`（由 ContentView 路由層接管，不走 ErrorView）
- `isRetryable`: 回傳 `false`

`HTTPError.toDomainError()` 補充：
```swift
case .forceUpdateRequired(let payload):
    return .forceUpdateRequired(updateUrl: payload.updateUrl)
```

### 5. AuthenticationError 新增 Case

**修改 `Havital/Features/Authentication/Domain/Errors/AuthError.swift`**

```swift
case forceUpdateRequired(updateUrl: String?)
```

`toDomainError()` 補充：
```swift
case .forceUpdateRequired(let url):
    return .forceUpdateRequired(updateUrl: url)
```

`errorDescription` 補充：
```swift
case .forceUpdateRequired:
    return "App 版本過舊，請前往 App Store 更新"
```

### 6. AuthRepositoryImpl 攔截點

**修改 `Havital/Features/Authentication/Data/Repositories/AuthRepositoryImpl.swift`**

在 `signInWithGoogle()`、`signInWithApple()`、`signInWithApple(credential:)` 三個方法中，**Step 5 之後、Step 6 之前**插入：

```swift
// Step 5: Backend user sync
let syncResponse = try await backendAuth.syncUserWithBackend(request: syncRequest)

// [NEW] Step 5.5: Version Gate 攔截
if let vc = syncResponse.versionCheck, vc.forceUpdate {
    Logger.warn("[AuthRepository] 🚫 Force update required. minVersion=\(vc.minAppVersion ?? "?") updateUrl=\(vc.updateUrl ?? "?")")
    throw AuthenticationError.forceUpdateRequired(updateUrl: vc.updateUrl)
}

// Step 6: Map DTO → AuthUser Entity
```

**三個 signIn 方法都要加**，不能遺漏。

### 7. AuthenticationViewModel 狀態

**修改 `Havital/Features/Authentication/Presentation/ViewModels/AuthenticationViewModel.swift`**

新增兩個 `@Published` 屬性：
```swift
/// Version Gate 狀態：需要強制更新時為 true
@Published var requiresForceUpdate: Bool = false

/// App Store 更新 URL（可能為 nil，此時 CTA 改為顯示純文字）
@Published var forceUpdateUrl: String? = nil
```

在 sign-in 方法（Google / Apple / DemoLogin）的 error catch 處理中，新增：
```swift
// 在 catch AuthenticationError 或 DomainError 的 switch 裡
case .forceUpdateRequired(let url):
    requiresForceUpdate = true
    forceUpdateUrl = url
    isLoading = false
    return  // 不設 error，由 ContentView 路由層接管
```

同樣，當全局收到 `DomainError.forceUpdateRequired` 時（來自 426）：
```swift
case .forceUpdateRequired(let url):
    requiresForceUpdate = true
    forceUpdateUrl = url
```

### 8. ForceUpdateView（新建）

**新建 `Havital/Features/Authentication/Presentation/Views/ForceUpdateView.swift`**

```swift
// 設計規格
// - 全螢幕覆蓋，不可 dismiss（不顯示關閉按鈕，不響應手勢）
// - 顯示：App icon + 標題「請更新 Paceriz」+ 說明文字
// - CTA 按鈕：「前往 App Store」→ UIApplication.shared.open(updateUrl)
// - 若 updateUrl == nil：按鈕文字改為「請前往 App Store 更新」且禁用（或隱藏）
// - 不提供任何繞過路徑
```

UI 層只做渲染，不含任何業務邏輯（符合架構規則）。

### 9. ContentView 路由插入

**修改 `Havital/Views/ContentView.swift`**

在 `if appStateManager.shouldShowLoadingScreen` 之後、`else if !authViewModel.isAuthenticated` 之前插入：

```swift
// Version Gate：forceUpdate 優先於一切（登入前也可能觸發）
else if authViewModel.requiresForceUpdate {
    ForceUpdateView(updateUrl: authViewModel.forceUpdateUrl)
}
```

**順序重要**：`loading → forceUpdate → login → onboarding → main`

---

## Feature B：公告系統

### 目錄結構（全新）

```
Havital/Features/Announcement/
  Data/
    DTOs/AnnouncementDTO.swift
    DataSources/AnnouncementRemoteDataSource.swift
    Mappers/AnnouncementMapper.swift
    Repositories/AnnouncementRepositoryImpl.swift
  Domain/
    Entities/Announcement.swift
    Repositories/AnnouncementRepository.swift
    Errors/AnnouncementError.swift
  Presentation/
    ViewModels/AnnouncementViewModel.swift
    Views/AnnouncementBannerView.swift
    Views/MessageCenterView.swift
```

### 1. Domain Entity

**`Havital/Features/Announcement/Domain/Entities/Announcement.swift`**

```swift
struct Announcement: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let imageUrl: String?
    let ctaLabel: String?
    let ctaUrl: String?
    let publishedAt: Date
    let expiresAt: Date?
    let isSeen: Bool
}
```

- **Entity 不加 `Codable`**（架構規則：Domain 不依賴序列化格式）。

### 2. DTO

**`Havital/Features/Announcement/Data/DTOs/AnnouncementDTO.swift`**

```swift
struct AnnouncementDTO: Codable {
    let id: String
    let title: String
    let body: String
    let imageUrl: String?
    let ctaLabel: String?
    let ctaUrl: String?
    let publishedAt: String
    let expiresAt: String?
    let isSeen: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case imageUrl   = "image_url"
        case ctaLabel   = "cta_label"
        case ctaUrl     = "cta_url"
        case publishedAt = "published_at"
        case expiresAt  = "expires_at"
        case isSeen     = "is_seen"
    }
}

struct AnnouncementListResponse: Codable {
    let success: Bool
    let data: [AnnouncementDTO]
}

struct SeenBatchRequest: Codable {
    let announcementIds: [String]

    enum CodingKeys: String, CodingKey {
        case announcementIds = "announcement_ids"
    }
}
```

### 3. Mapper

**`Havital/Features/Announcement/Data/Mappers/AnnouncementMapper.swift`**

```swift
enum AnnouncementMapper {
    static func toDomain(_ dto: AnnouncementDTO) -> Announcement? {
        guard let publishedAt = ISO8601DateFormatter().date(from: dto.publishedAt) else {
            return nil
        }
        return Announcement(
            id: dto.id,
            title: dto.title,
            body: dto.body,
            imageUrl: dto.imageUrl,
            ctaLabel: dto.ctaLabel,
            ctaUrl: dto.ctaUrl,
            publishedAt: publishedAt,
            expiresAt: dto.expiresAt.flatMap { ISO8601DateFormatter().date(from: $0) },
            isSeen: dto.isSeen
        )
    }
}
```

### 4. Repository Protocol

**`Havital/Features/Announcement/Domain/Repositories/AnnouncementRepository.swift`**

```swift
protocol AnnouncementRepository {
    /// GET /v2/announcements → 所有有效公告（後端已過濾過期/草稿）
    func fetchAnnouncements() async throws -> [Announcement]
    
    /// POST /v2/announcements/{id}/seen
    func markSeen(id: String) async throws
    
    /// POST /v2/announcements/seen-batch
    func markSeenBatch(ids: [String]) async throws
}
```

### 5. Remote DataSource

**`Havital/Features/Announcement/Data/DataSources/AnnouncementRemoteDataSource.swift`**

```swift
final class AnnouncementRemoteDataSource {
    private enum Endpoint {
        static let list        = "/v2/announcements"
        static func seen(_ id: String) -> String { "/v2/announcements/\(id)/seen" }
        static let seenBatch   = "/v2/announcements/seen-batch"
    }

    private let httpClient: HTTPClient
    private let parser: APIParser

    init(httpClient: HTTPClient = DefaultHTTPClient.shared,
         parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    func fetchAnnouncements() async throws -> [AnnouncementDTO] {
        let data = try await httpClient.request(path: Endpoint.list, method: .GET)
        let response = try ResponseProcessor.extractData(
            AnnouncementListResponse.self, from: data, using: parser
        )
        return response.data
    }

    func markSeen(id: String) async throws {
        _ = try await httpClient.request(path: Endpoint.seen(id), method: .POST)
    }

    func markSeenBatch(ids: [String]) async throws {
        let body = try JSONEncoder().encode(SeenBatchRequest(announcementIds: ids))
        _ = try await httpClient.request(path: Endpoint.seenBatch, method: .POST, body: body)
    }
}
```

### 6. Repository Implementation

**`Havital/Features/Announcement/Data/Repositories/AnnouncementRepositoryImpl.swift`**

```swift
final class AnnouncementRepositoryImpl: AnnouncementRepository {
    private let dataSource: AnnouncementRemoteDataSource

    init(dataSource: AnnouncementRemoteDataSource) {
        self.dataSource = dataSource
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        let dtos = try await dataSource.fetchAnnouncements()
        return dtos.compactMap { AnnouncementMapper.toDomain($0) }
    }

    func markSeen(id: String) async throws {
        try await dataSource.markSeen(id: id)
    }

    func markSeenBatch(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await dataSource.markSeenBatch(ids: ids)
    }
}
```

### 7. AnnouncementViewModel

**`Havital/Features/Announcement/Presentation/ViewModels/AnnouncementViewModel.swift`**

```swift
@MainActor
final class AnnouncementViewModel: ObservableObject, TaskManageable {

    // MARK: - Published
    @Published var bannerAnnouncement: Announcement? = nil
    @Published var allAnnouncements: [Announcement] = []
    @Published var unreadCount: Int = 0

    // MARK: - TaskManageable
    let taskRegistry = TaskRegistry()

    // MARK: - Dependencies
    private let repository: AnnouncementRepository

    init(repository: AnnouncementRepository) {
        self.repository = repository
    }

    deinit { cancelAllTasks() }

    // MARK: - Home Banner（App 啟動後呼叫）
    func loadBannerAnnouncement() {
        executeTask(id: TaskID("load_banner")) {
            let announcements = try await self.repository.fetchAnnouncements()
                .tracked(from: "AnnouncementViewModel: loadBannerAnnouncement")
            
            let unread = announcements
                .filter { !$0.isSeen }
                .sorted { $0.publishedAt > $1.publishedAt }
            
            self.unreadCount = unread.count
            self.bannerAnnouncement = unread.first
            
            // Banner 顯示後立刻標記為已讀（AC-ANN-02）
            if let banner = self.bannerAnnouncement {
                try await self.repository.markSeen(id: banner.id)
                    .tracked(from: "AnnouncementViewModel: markSeen")
            }
        }
    }

    // MARK: - Message Center（進入訊息中心時呼叫）
    func loadMessageCenter() {
        executeTask(id: TaskID("load_message_center")) {
            let announcements = try await self.repository.fetchAnnouncements()
                .tracked(from: "AnnouncementViewModel: loadMessageCenter")
            self.allAnnouncements = announcements.sorted { $0.publishedAt > $1.publishedAt }
            
            // 一次性標記所有未讀（AC-ANN-05）
            let unreadIds = announcements.filter { !$0.isSeen }.map { $0.id }
            if !unreadIds.isEmpty {
                try await self.repository.markSeenBatch(ids: unreadIds)
                    .tracked(from: "AnnouncementViewModel: markSeenBatch")
                self.unreadCount = 0
            }
        }
    }
}
```

**注意：** ViewModel 依賴 `AnnouncementRepository` Protocol，不依賴 RepositoryImpl（架構規則）。

### 8. DI 注冊

**在適當的 `DependencyContainer` extension 新增**（建議放在 `AnnouncementRepositoryImpl.swift` 底部）：

```swift
extension DependencyContainer {
    func registerAnnouncementModule() {
        let dataSource = AnnouncementRemoteDataSource(
            httpClient: resolve(),
            parser: resolve()
        )
        let repo = AnnouncementRepositoryImpl(dataSource: dataSource)
        register(repo as AnnouncementRepository, forProtocol: AnnouncementRepository.self)
    }
}
```

並在 app 啟動時的 DI 設置處呼叫 `registerAnnouncementModule()`。

### 9. AnnouncementBannerView 設計規格

**`Havital/Features/Announcement/Presentation/Views/AnnouncementBannerView.swift`**

| 元素 | 規格 |
|------|------|
| 圖片 | `AsyncImage(url: imageUrl)` + placeholder；`imageUrl=nil` → 隱藏圖片區域（AC-ANN-07）|
| 標題 | `announcement.title`，一行，超出截斷 |
| 內文 | `announcement.body`，最多 2 行 |
| CTA 按鈕 | `ctaLabel` 有值 → 顯示按鈕；`nil` → 不渲染（AC-ANN-06）|
| CTA 行為 | `ctaUrl` 以 `paceriz://` 開頭 → deeplink；`https://` → Safari；其他 → 忽略 |
| 掛載位置 | `TrainingPlanV2View.swift:73`，插入 `VStack(spacing: 24)` 第一個元素（`switch viewModel.planStatus` 之前），無論 planStatus 為何都顯示 |

### 10. MessageCenterView 設計規格

**`Havital/Features/Announcement/Presentation/Views/MessageCenterView.swift`**

- `List` / `ScrollView` 顯示 `allAnnouncements`
- 每則：圖片縮圖（可選）+ title + body（折疊）+ published_at（相對時間）
- 已讀/未讀視覺區別（例如未讀有藍點）
- 進入時呼叫 `viewModel.loadMessageCenter()`

---

## 介面合約清單

### Version Gate

| 函式 / 端點 | 參數 | 型別 | 必填 | 說明 |
|------------|------|------|------|------|
| `POST /auth/sync` response | `version_check` | `VersionCheckDTO?` | 否 | Optional，後端不回傳時 nil |
| `VersionCheckDTO.force_update` | — | `Bool` | 是（若有 versionCheck）| true → 阻斷進入 App |
| `VersionCheckDTO.update_url` | — | `String?` | 否 | App Store URL，nil 時 CTA 降級 |
| `HTTP 426` response body | `detail.update_url` | `String?` | 否 | 同上 |

### Announcement

| 函式 / 端點 | 參數 | 型別 | 必填 | 說明 |
|------------|------|------|------|------|
| `GET /v2/announcements` | — | — | — | 無 request body |
| response `data[].id` | — | `String` | 是 | |
| response `data[].is_seen` | — | `Bool` | 是 | 前端以此過濾未讀 |
| response `data[].published_at` | — | ISO8601 String | 是 | 排序依據 |
| response `data[].cta_url` | — | `String?` | 否 | deeplink 或 https |
| `POST /v2/announcements/{id}/seen` | `id` path param | `String` | 是 | |
| `POST /v2/announcements/seen-batch` body | `announcement_ids` | `[String]` | 是 | empty array → RepositoryImpl skip |

---

## 任務拆分

| # | 任務 | 角色 | Done Criteria |
|---|------|------|--------------|
| T01 | DTO + HTTPError 426 + DomainError + AuthenticationError 修改 | Developer | `UserSyncResponse` 有 `versionCheck` 欄位；`HTTPClient.validateHTTPResponse` 有 case 426；`DomainError.forceUpdateRequired` 存在且 `shouldShowErrorView=false`；clean build pass |
| T02 | AuthRepositoryImpl 攔截 + AuthenticationViewModel forceUpdate 狀態 | Developer | 在 Step 5 → Step 6 三個 signIn 方法都有攔截；`AuthenticationViewModel` 有 `requiresForceUpdate`/`forceUpdateUrl`；mock forceUpdate=true 時 ViewModel 狀態正確；clean build pass |
| T03 | ForceUpdateView + ContentView 路由 | Developer | ForceUpdateView 全螢幕不可 dismiss；CTA 導向 URL；`ContentView` 在 loading 後 login 前插入 forceUpdate case；clean build pass |
| T04 | Announcement 模組（Data + Domain） | Developer | 所有新增檔案依架構目錄放置；`AnnouncementRepositoryImpl` 能正確解析 mock response；DI 注冊完成；clean build pass |
| T05 | AnnouncementViewModel + Views | Developer | `loadBannerAnnouncement()` 取最新未讀；Banner render 後 markSeen；`loadMessageCenter()` markSeenBatch；deeplink routing 正確；clean build pass |
| T06 | QA 驗收（Version Gate） | QA | AC-VG-01 ~ AC-VG-05 逐條在 simulator 驗證，截圖為證 |
| T07 | QA 驗收（公告系統） | QA | AC-ANN-01 ~ AC-ANN-07 逐條在 simulator 驗證，截圖為證 |

---

## Risk Assessment

### 1. 不確定的技術點

- **首頁 Banner 掛載位置**：已確認為 `TrainingPlanV2View.swift:73`，插入 `VStack(spacing: 24)` 第一個元素（switch 之前）。
- **426 body 格式**：已確認為直接格式 `{"error": "...", "update_url": "...", "min_app_version": "..."}`，無 `detail` wrapper。使用 `ForceUpdatePayload` 直接 decode，無需 wrapper struct。

### 2. 替代方案與選擇理由

| 決策 | 選擇 | 捨棄方案 | 理由 |
|------|------|---------|------|
| 攔截點位置 | `AuthRepositoryImpl`（業務邏輯層）| `BackendAuthDataSource`（資料存取層）| DataSource 是純資料，不做業務判斷；攔截邏輯屬業務規則，放 Repository 符合架構 |
| ForceUpdate 路由 | `ContentView` 直接判斷 `requiresForceUpdate` | 用 `DomainError` 驅動 ErrorView | ErrorView 可被 dismiss，ForceUpdateView 不行；路由層顯式控制更安全 |
| Announcement 快取 | 不快取（每次都 GET） | 本機快取 | 公告資料小、更新頻率低；避免快取失效問題；MVP 先不加複雜度 |
| Banner 已讀時機 | Banner onAppear 後立刻 markSeen | 用戶點擊後才 markSeen | 符合後端設計（Banner render = seen）；避免同一 session 重複出現 |

### 3. 需要用戶確認的決策

1. **首頁 Banner 掛載位置**：已確認，`TrainingPlanV2View.swift:73`，VStack 第一個元素。
2. **426 body 格式**：已確認，直接格式 `{"error": "...", "update_url": "...", "min_app_version": "..."}`，無 `detail` wrapper。
3. **MessageCenter 入口**：訊息中心頁面的入口（Tab / Navigation / Sheet）需由 Designer 或 PM 確認後 Developer 實作。

### 4. 最壞情況與修正成本

| 情境 | 影響 | 修正成本 |
|------|------|---------|
| 426 body 格式偏離（後端未來改格式）→ `ForceUpdatePayload` decode 失敗 | fallback 仍 `throw HTTPError.forceUpdateRequired(最小 payload)`，UI 顯示更新提示，只是沒有 updateUrl | 低：只改 payload struct |
| Banner 掛載在錯誤 View → 重複顯示 | UX 破壞，但不 crash | 低：移動 View 插入位置 |
| `AuthRepositoryImpl` 攔截遺漏某個 signIn overload | 該登入路徑不受 Version Gate 保護 | 中：需逐一補 case，但影響範圍明確 |
| 舊版 `AuthenticationService`（legacy, deprecated）未處理 `forceUpdateRequired` | legacy 路徑（Google/Apple 登入舊流程）不觸發 ForceUpdateView；但 HTTPClient 的 426 case 仍會往上浮，最終 `authViewModel.error` 會收到 | 低：legacy 路徑正在被廢棄中；且 426 保底路徑仍有效 |

---

## 上線順序（對應後端建議）

```
Step 1: 發布 App 1.3.0
  ├── T01~T07 全部完成，QA PASS
  ├── 包含：讀取 version_check（soft gate）
  ├── 包含：處理 426（hard gate）
  ├── 包含：公告 Banner + 訊息中心
  └── 上架 App Store

Step 2: 等 1.3.0 自然滲透
  └── 觀察 backend device_info.app_version 分佈

Step 3: IAP 正式上線時
  └── PUT /api/v1/admin/app-config/version
      { "min_app_version": "1.3.0", "hard_min_app_version": "1.3.0", ... }
      → 1.3.0+ 用戶：force_update=false，正常使用
      → <1.3.0 用戶：收到 426，看到 ForceUpdateView
```
