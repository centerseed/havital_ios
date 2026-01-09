# Authentication Module - Clean Architecture 重構規劃

**規劃日期**: 2026-01-06 (修正版 v2.0)
**目標完成**: 3-4 天
**優先級**: 🔴 高
**依賴**: AuthenticationService (1130 行)

---

## ✅ 架構審查修正記錄

本規劃已根據 Clean Architecture 原則進行全面審查和修正：

### 🔴 已修正的嚴重問題 (必須修正)

1. ✅ **Domain 層依賴隔離** (問題 #1)
   - 移除 `ASAuthorizationAppleIDCredential` 等 SDK 類型
   - 新增 `AppleAuthCredential` 和 `GoogleAuthCredential` 抽象類型
   - Domain 層現在零外部依賴

2. ✅ **AuthUser Entity 純淨性** (問題 #2)
   - 移除 `idToken`, `refreshToken`, `expiresAt` 技術細節
   - Token 管理移至 Data 層的 AuthSessionRepositoryImpl
   - Entity 現在只包含業務屬性（uid, email, displayName, onboarding 狀態）

3. ✅ **事件發布職責明確** (問題 #3)
   - 明確規定：Repository 永不發布事件（被動原則）
   - ViewModel 負責在成功操作後發布事件
   - 新增完整的事件流程圖和發布/訂閱規則

### 🟠 已改進的中等問題 (建議改進)

4. ✅ **Repository 職責分離** (問題 #4)
   - 拆分為 3 個獨立 Repository：
     - `AuthRepository` (核心認證)
     - `AuthSessionRepository` (Token 管理)
     - `OnboardingRepository` (Onboarding 狀態)
   - 避免單一 Protocol 過於龐大（原 16 個方法 → 3 個各 4-5 個方法）

5. ✅ **認證快取策略安全化** (問題 #5)
   - Token **不快取**，每次從 Firebase 即時獲取
   - AuthUser 業務數據快取 **5 分鐘**
   - 快取前驗證 Firebase Auth State
   - 明確區分快取內容：業務數據 ✅ / Token ❌

6. ✅ **AuthCache 介面完整定義** (問題 #6)
   - 新增 AuthCache Protocol（5 個方法）
   - 提供 UserDefaultsAuthCache 實現
   - 包含過期檢查、自動清理機制

### 📊 架構改進總結

| 項目 | 修正前 | 修正後 | 改進 |
|------|--------|--------|------|
| **Domain 層依賴** | 引用 SDK 類型 | 零外部依賴 | ✅ 符合 CA 原則 |
| **AuthUser 屬性** | 10 個（含 Token） | 7 個（純業務） | ✅ 技術細節隔離 |
| **Repository 數量** | 1 個（16 方法） | 3 個（各 4-5 方法） | ✅ 職責分離 |
| **事件發布者** | 不明確 | ViewModel 明確負責 | ✅ 遵循 CLAUDE.md |
| **Token 快取** | 快取 Token | 不快取 | ✅ 安全性提升 |
| **快取介面** | 未定義 | 完整 Protocol + 實現 | ✅ 可測試性 |
| **檔案數量** | 13 個 | 18 個 | ✅ 職責更清晰 |

---

## 📋 執行摘要

### 現狀分析
- **來源文件**: `Havital/Services/AuthenticationService.swift` (1130 行)
- **功能**: Firebase Auth + Google Sign-In + Apple Sign-In + Demo Login + 用戶同步
- **當前問題**:
  - 混合了 UI 狀態管理 (@Published) 和業務邏輯
  - 直接調用後端 API (應通過 Repository)
  - Singleton 模式難以測試
  - 與多個 Manager 耦合

### 目標架構
```
Features/Authentication/
├── Domain/
│   ├── Repositories/
│   │   ├── AuthRepository.swift (核心認證操作)
│   │   ├── AuthSessionRepository.swift (Token 管理)
│   │   └── OnboardingRepository.swift (Onboarding 狀態)
│   ├── Entities/
│   │   ├── AuthUser.swift (純業務模型: UID, Email, DisplayName, OnboardingStatus)
│   │   ├── AppleAuthCredential.swift (Apple 認證抽象，不依賴 SDK)
│   │   └── GoogleAuthCredential.swift (Google 認證抽象)
│   └── Errors/
│       └── AuthError.swift (業務層錯誤定義)
│
├── Data/
│   ├── DataSources/
│   │   ├── FirebaseAuthDataSource.swift
│   │   ├── GoogleSignInDataSource.swift
│   │   ├── AppleSignInDataSource.swift
│   │   └── BackendAuthDataSource.swift
│   ├── Repositories/
│   │   ├── AuthRepositoryImpl.swift
│   │   ├── AuthSessionRepositoryImpl.swift
│   │   └── OnboardingRepositoryImpl.swift
│   ├── Mappers/
│   │   ├── FirebaseUserMapper.swift
│   │   └── AuthCredentialMapper.swift
│   ├── DTOs/
│   │   ├── UserSyncRequest.swift
│   │   └── UserSyncResponse.swift
│   └── Cache/
│       ├── AuthCache.swift (Protocol)
│       └── UserDefaultsAuthCache.swift (實現)
│
└── Presentation/
    └── ViewModels/
        ├── LoginViewModel.swift
        ├── SignupViewModel.swift
        └── AuthCoordinatorViewModel.swift
```

---

## 🏗️ 詳細設計

### 修正說明 (基於架構審查)

本規劃已根據 Clean Architecture 原則修正以下關鍵問題：

1. ✅ **Domain 層依賴隔離**: 移除所有外部 SDK 類型引用
2. ✅ **Entity 純淨性**: AuthUser 不再包含技術細節（Token 移至 Data 層）
3. ✅ **Repository 職責分離**: 拆分為 3 個獨立 Repository
4. ✅ **事件發布規則**: 明確由 ViewModel 負責，Repository 保持被動
5. ✅ **快取策略安全**: 短期快取業務數據，Token 即時獲取
6. ✅ **介面完整定義**: 補充 AuthCache Protocol 設計

---

### Phase 1: Domain Layer (純業務模型，零外部依賴)

#### 1.1 AuthError 錯誤定義

**設計原則**: 業務層錯誤，不暴露技術實現細節

**錯誤類型**:
- `googleSignInFailed(String)` - Google 登入失敗（包含用戶可讀訊息）
- `appleSignInFailed(String)` - Apple 登入失敗
- `firebaseAuthFailed(String)` - Firebase 認證失敗
- `backendSyncFailed(String)` - 後端同步失敗
- `invalidCredentials` - 無效憑證
- `networkFailure` - 網路錯誤
- `tokenExpired` - Token 過期
- `userNotFound` - 用戶不存在
- `onboardingRequired` - 需要完成 Onboarding

**錯誤轉換鏈路**:
1. DataSource 捕獲 SDK/API 錯誤
2. 轉換為 AuthError 並附加上下文訊息
3. RepositoryImpl 包裝並傳遞
4. ViewModel 轉換為用戶友好訊息

---

#### 1.2 AuthUser Entity (純業務模型)

**設計原則**: 只包含業務需要的用戶資訊，不包含技術細節

**核心屬性**:
- `uid: String` - 用戶唯一識別碼
- `email: String?` - 用戶郵箱
- `displayName: String?` - 顯示名稱
- `photoURL: URL?` - 頭像 URL
- `isAuthenticated: Bool` - 認證狀態（業務層概念）
- `hasCompletedOnboarding: Bool` - Onboarding 完成狀態
- `onboardingMode: OnboardingMode` - Onboarding 模式

**OnboardingMode 枚舉**:
- `none` - 無需 Onboarding
- `initial` - 首次註冊，需要完整設定
- `reonboarding` - 重新設定個人資料

**重要變更**:
- ❌ 移除 `idToken`（Firebase 技術細節，移至 Data 層）
- ❌ 移除 `refreshToken`（技術細節）
- ❌ 移除 `expiresAt`（技術細節）

---

#### 1.3 認證憑證抽象 (新增)

**AppleAuthCredential** - Apple 認證抽象類型
- `identityToken: Data` - 身份 Token
- `authorizationCode: Data` - 授權碼
- `fullName: PersonNameComponents?` - 完整姓名
- `email: String?` - 郵箱

**GoogleAuthCredential** - Google 認證抽象類型
- `idToken: String` - Google ID Token
- `accessToken: String` - 存取 Token

**設計目的**:
- Domain 層不依賴 `ASAuthorizationAppleIDCredential` 等 SDK 類型
- Mapper 負責 SDK 類型 → Domain 抽象類型的轉換

---

#### 1.4 Repository Protocols (職責分離)

**AuthRepository** - 核心認證操作
- `signInWithGoogle()` → AuthUser
- `signInWithApple(credential: AppleAuthCredential)` → AuthUser
- `signInWithEmail(email, password)` → AuthUser (如果支援)
- `demoLogin()` → AuthUser
- `signOut()`

**AuthSessionRepository** - Token 和會話管理
- `getCurrentUser()` → AuthUser?
- `fetchCurrentUser()` → AuthUser (從 Firebase + Backend)
- `getIdToken()` → String
- `refreshIdToken()` → String
- `isAuthenticated()` → Bool

**OnboardingRepository** - Onboarding 狀態管理
- `startReonboarding()`
- `completeOnboarding()`
- `resetOnboarding()`
- `getOnboardingStatus()` → OnboardingStatus

**職責分離理由**:
- 單一職責原則：每個 Repository 管理一個業務領域
- 降低複雜度：避免單一 Protocol 過於龐大
- 提升可測試性：可獨立 Mock 和測試
- 未來擴展性：可獨立演化各個 Repository

---

### Phase 2: Data Layer (技術實現層)

#### 2.1 DataSources 設計

**FirebaseAuthDataSource** - Firebase 認證操作

**核心職責**:
- 使用 Google/Apple Token 進行 Firebase OAuth 認證
- 管理 Firebase Auth State Listener（全局唯一）
- 獲取和刷新 Firebase ID Token
- Nonce 生成和 SHA256 雜湊（Apple Sign-In）
- 登出操作

**關鍵方法**:
- `signInWithGoogle(idToken, accessToken)` → Firebase User
- `signInWithApple(idToken, rawNonce)` → Firebase User
- `getCurrentUser()` → Firebase User? (同步獲取)
- `getIdToken()` → String (帶自動刷新)
- `signOut()`
- `addAuthStateListener(callback)` → NSObjectProtocol

**重要實現細節**:
- Listener 在 Application 啟動時註冊一次
- Nonce 使用 CryptoKit 生成 32 位元隨機字串
- Token 過期自動刷新機制

---

**GoogleSignInDataSource** - Google Sign-In SDK 操作

**核心職責**:
- 調用 Google Sign-In SDK 顯示登入畫面
- 提取 ID Token 和 Access Token
- 錯誤處理（用戶取消、網路錯誤等）

**關鍵方法**:
- `performSignIn()` → (idToken: String, accessToken: String)

**實現細節**:
- 使用 GoogleSignIn.sharedInstance.signIn()
- 處理用戶取消場景（不拋錯誤，返回特定狀態）
- 轉換 Google SDK 錯誤為 AuthError

---

**AppleSignInDataSource** - Apple Sign-In SDK 操作

**核心職責**:
- 配置和顯示 Apple Sign-In Controller
- 處理 ASAuthorizationController Delegate 回調
- 提取 Identity Token 和 Authorization Code

**關鍵方法**:
- `performSignIn(nonce)` → ASAuthorizationAppleIDCredential

**實現細節**:
- 使用 Continuation 將 Delegate 回調轉為 async/await
- Nonce 用於防止重放攻擊
- 處理 fullName 和 email（僅首次提供）

---

**BackendAuthDataSource** - 後端 API 調用

**核心職責**:
- 同步 Firebase 用戶到後端數據庫
- 獲取和更新 Onboarding 狀態
- 管理 FCM Token 同步

**關鍵方法**:
- `syncUserWithBackend(idToken)` → UserSyncResponse
- `getOnboardingStatus(uid)` → OnboardingStatus
- `completeOnboarding(uid, data)`
- `resetOnboarding(uid)`

**API 端點**:
- POST `/auth/sync` - 用戶同步
- GET `/auth/users/{uid}/onboarding` - 獲取狀態
- POST `/auth/users/{uid}/complete-onboarding` - 完成設定
- POST `/auth/users/{uid}/reset-onboarding` - 重置

---

#### 2.2 Repository Implementations

**AuthRepositoryImpl** - 核心認證流程實現

**登入流程** (以 Google 為例):
1. 調用 GoogleSignInDataSource 獲取 Token
2. 調用 FirebaseAuthDataSource 進行 Firebase 認證
3. 獲取 Firebase ID Token
4. 調用 BackendAuthDataSource 同步用戶
5. 使用 Mapper 將 DTO → AuthUser Entity
6. 保存到 AuthCache
7. 返回 AuthUser（**不發布事件**，由 ViewModel 負責）

**AuthSessionRepositoryImpl** - Token 和會話管理

**Token 管理策略**:
- Token **不快取**，每次從 Firebase 即時獲取
- Firebase SDK 內部已處理 Token 刷新
- 過期自動重試機制

**用戶獲取策略** (修正後的安全快取):
- `getCurrentUser()` - 返回快取的 AuthUser（**不含 Token**）
- 快取有效期: **5 分鐘**
- 快取前驗證 Firebase Auth State
- 背景刷新僅更新業務數據（email, displayName 等）

**OnboardingRepositoryImpl** - Onboarding 狀態管理

**職責**:
- 調用 BackendAuthDataSource 的 Onboarding API
- 管理 Reonboarding 流程
- 發布 Onboarding 相關事件（由 Coordinator 負責）

---

#### 2.3 AuthCache Protocol 設計 (新增)

**核心介面**:
- `saveUser(_ user: AuthUser)` - 保存用戶資訊
- `getCurrentUser() -> AuthUser?` - 獲取快取（含過期檢查）
- `clearCache()` - 清除所有快取
- `isValid() -> Bool` - 檢查快取是否過期
- `getExpirationDate() -> Date?` - 獲取過期時間

**實現類型**: UserDefaultsAuthCache
- 使用 UserDefaults 存儲
- 自動加密敏感字段（如 email）
- 5 分鐘過期時間
- 應用啟動時清理過期快取

**快取內容**:
- ✅ uid, email, displayName, photoURL（業務數據）
- ✅ hasCompletedOnboarding, onboardingMode（狀態）
- ❌ Token 相關（不快取，安全考慮）

---

#### 2.4 DTOs 和 Mappers

**UserSyncRequest DTO**:
- `firebaseUid` - Firebase 用戶 ID
- `idToken` - Firebase ID Token
- `fcmToken` - FCM 推送 Token（可選）
- `deviceInfo` - 設備資訊（可選）

**UserSyncResponse DTO**:
- `user: UserDTO` - 用戶基本資訊
- `onboardingStatus: OnboardingStatusDTO` - Onboarding 狀態
- `shouldCompleteOnboarding: Bool` - 是否需要完成設定

**AuthCredentialMapper**:
- `ASAuthorizationAppleIDCredential` → `AppleAuthCredential`
- `GIDGoogleUser` → `GoogleAuthCredential`
- 隔離 Domain 層與 SDK 依賴

**FirebaseUserMapper**:
- `FirebaseAuth.User` + `UserSyncResponse` → `AuthUser`
- 合併 Firebase 和後端數據
- 處理空值和預設值

---

### Phase 3: Presentation Layer (UI 狀態管理)

#### 3.1 LoginViewModel 設計

**核心職責**:
- 管理登入 UI 狀態（載入中、成功、失敗）
- 調用 AuthRepository 執行登入邏輯
- **發布認證事件**（Repository 不發布）
- 處理用戶可讀的錯誤訊息

**狀態管理**:
- `state: ViewState<AuthUser>` - 統一狀態枚舉（.loading, .loaded, .error, .empty）
- `isGoogleSignInLoading: Bool` - Google 登入載入狀態
- `isAppleSignInLoading: Bool` - Apple 登入載入狀態

**關鍵方法**:
- `signInWithGoogle()` - Google 登入流程
- `signInWithApple(credential: AppleAuthCredential)` - Apple 登入流程
- `demoLogin()` - Demo 模式登入（僅開發環境）

**事件發布時機** (遵循 CLAUDE.md 規則):
- ✅ 登入成功後: `CacheEventBus.publish(.userAuthenticated)`
- ✅ 登出成功後: `CacheEventBus.publish(.userLogout)`
- ❌ Repository 不發布事件（保持被動）

**DI 注入**:
- 依賴 `AuthRepository` Protocol（不依賴具體實現）
- 使用 convenience init 從 DependencyContainer 解析
- 完全可測試（可注入 Mock Repository）

---

#### 3.2 AuthCoordinatorViewModel 設計

**核心職責**:
- 管理應用級認證狀態
- 協調認證流程和 Onboarding 流程
- 監聽認證事件並更新全局狀態
- 決定顯示哪個畫面（登入、Onboarding、主畫面）

**AuthState 枚舉**:
- `.loading` - 初始化中，檢查認證狀態
- `.unauthenticated` - 未登入，顯示登入畫面
- `.authenticated(AuthUser)` - 已登入且完成 Onboarding
- `.onboarding(AuthUser)` - 已登入但需要 Onboarding
- `.error(Error)` - 認證錯誤

**關鍵方法**:
- `initializeAuthState()` - 應用啟動時初始化
- `signOut()` - 登出並清除所有狀態
- `handleOnboardingComplete()` - 處理 Onboarding 完成

**事件訂閱** (遵循 CLAUDE.md 規則):
- 訂閱 `.userAuthenticated` → 重新載入用戶狀態
- 訂閱 `.userLogout` → 切換到登入畫面
- 訂閱 `.onboardingCompleted` → 切換到主畫面

**狀態轉換流程**:
```
.loading (啟動)
  ↓ fetchCurrentUser()
.unauthenticated (無 Firebase session)
  ↓ signInWithGoogle()
.authenticated (有 session + 完成 onboarding)
  或
.onboarding (有 session + 未完成 onboarding)
  ↓ completeOnboarding()
.authenticated
  ↓ signOut()
.unauthenticated
```

---

#### 3.3 CacheEventBus 事件規則 (關鍵修正)

**遵循 CLAUDE.md 的核心原則**:

✅ **發布者位置**:
- **LoginViewModel**: 登入成功後發布 `.userAuthenticated`
- **AuthCoordinatorViewModel**: 登出時發布 `.userLogout`
- **OnboardingCoordinator**: 完成 Onboarding 後發布 `.onboardingCompleted`
- ❌ **Repository**: 永不發布事件（被動原則）

✅ **訂閱者位置**:
- **AuthCoordinatorViewModel**: 訂閱所有認證事件，管理全局狀態
- **TrainingPlanViewModel**: 訂閱 `.userAuthenticated` → 載入訓練計畫
- **UserProfileViewModel**: 訂閱 `.userAuthenticated` → 載入用戶資料
- ❌ **Repository/DataSource**: 永不訂閱事件

**認證相關事件定義**:
- `.userAuthenticated` - 用戶登入成功（Google/Apple/Email）
- `.userLogout` - 用戶登出（清除所有快取）
- `.onboardingStarted` - 開始 Onboarding
- `.onboardingCompleted` - 完成 Onboarding
- `.reonboardingStarted` - 開始重新 Onboarding
- `.authTokenExpired` - Token 過期（觸發自動刷新或登出）

**事件流程範例** (Google 登入):
```
用戶點擊 Google 登入按鈕
  ↓
LoginViewModel.signInWithGoogle() 調用
  ↓
AuthRepository.signInWithGoogle() 執行（無事件）
  ↓
LoginViewModel 收到 AuthUser
  ↓
CacheEventBus.publish(.userAuthenticated) ← ViewModel 發布
  ↓
AuthCoordinatorViewModel 訂閱接收 → 更新 authState
  ↓
TrainingPlanViewModel 訂閱接收 → 載入訓練數據
  ↓
UserProfileViewModel 訂閱接收 → 載入用戶資料
```

---

## 📁 目錄結構與文件列表

### 必需創建的文件 (18 個)

#### Domain Layer (7 個文件)
```
Features/Authentication/Domain/
├── Repositories/
│   ├── AuthRepository.swift (核心認證: 5 個方法)
│   ├── AuthSessionRepository.swift (Token 管理: 5 個方法)
│   └── OnboardingRepository.swift (Onboarding: 4 個方法)
├── Entities/
│   ├── AuthUser.swift (純業務模型: 7 個屬性)
│   ├── AppleAuthCredential.swift (Apple 認證抽象)
│   └── GoogleAuthCredential.swift (Google 認證抽象)
└── Errors/
    └── AuthError.swift (9 個錯誤類型)
```

**文件說明**:
- 3 個 Repository Protocol（職責分離，避免單一 Protocol 過於龐大）
- 3 個 Entity（AuthUser 不含 Token，Credential 為 SDK 抽象）
- 1 個 Error（業務層錯誤定義）

---

#### Data Layer (11 個文件)
```
Features/Authentication/Data/
├── DataSources/
│   ├── FirebaseAuthDataSource.swift (Firebase 認證)
│   ├── GoogleSignInDataSource.swift (Google SDK)
│   ├── AppleSignInDataSource.swift (Apple SDK)
│   └── BackendAuthDataSource.swift (後端 API)
├── Repositories/
│   ├── AuthRepositoryImpl.swift (核心認證實現)
│   ├── AuthSessionRepositoryImpl.swift (Token 管理)
│   └── OnboardingRepositoryImpl.swift (Onboarding 管理)
├── Mappers/
│   ├── FirebaseUserMapper.swift (Firebase User + DTO → AuthUser)
│   └── AuthCredentialMapper.swift (SDK Credential → Domain 抽象)
├── DTOs/
│   ├── UserSyncRequest.swift (用戶同步請求)
│   └── UserSyncResponse.swift (用戶同步響應)
└── Cache/
    ├── AuthCache.swift (Protocol: 快取介面定義)
    └── UserDefaultsAuthCache.swift (實現: 5 分鐘快取)
```

**文件說明**:
- 4 個 DataSource 實現（各 150-250 行）
- 3 個 RepositoryImpl（各 250-350 行，不含原 AuthenticationService 的龐大代碼）
- 2 個 Mapper（各 80-120 行）
- 2 個 DTO（各 50-100 行）
- 2 個 Cache（Protocol + 實現，各 80-120 行）

**總計**: 11 個文件

---

#### Presentation Layer (3 個文件)
```
Features/Authentication/Presentation/ViewModels/
├── LoginViewModel.swift
├── SignupViewModel.swift
└── AuthCoordinatorViewModel.swift
```

**文件說明**:
- LoginViewModel: 180-220 行
- SignupViewModel: 150-200 行
- AuthCoordinatorViewModel: 200-250 行 (應用級認證狀態)

---

### 測試文件 (8-10 個預計)
```
HavitalTests/Features/Authentication/
├── Domain/
│   ├── AuthRepositoryTests.swift
│   └── AuthErrorTests.swift
├── Data/
│   ├── FirebaseAuthDataSourceTests.swift
│   ├── GoogleSignInDataSourceTests.swift
│   ├── AppleSignInDataSourceTests.swift
│   ├── BackendAuthDataSourceTests.swift
│   └── AuthRepositoryImplTests.swift
└── Presentation/
    ├── LoginViewModelTests.swift
    └── AuthCoordinatorViewModelTests.swift
```

---

## 🔄 集成點與事件

### CacheEventBus 事件
```swift
enum CacheEvent {
    case userAuthenticated         // 用戶登入成功
    case userLogout                // 用戶登出
    case onboardingStarted         // 開始 Onboarding
    case onboardingCompleted       // 完成 Onboarding
    case reonboardingStarted       // 開始重新 Onboarding
    case authTokenExpired          // Token 過期
}
```

### 訂閱者
- **TrainingPlanViewModel**: 訂閱 `.userAuthenticated` → 加載訓練計畫
- **UserProfileViewModel**: 訂閱 `.userAuthenticated` → 加載用戶資料
- **AppStateManager**: 訂閱所有認證事件 → 管理應用狀態

---

## 📊 實施步驟 (修正後 3-4 天)

### Day 1 (4-5 小時) - Domain Layer + Cache
- [ ] 創建 Domain 層 (7 個文件)
  - 3 個 Repository Protocol（職責分離）
  - 3 個 Entity（AuthUser, AppleAuthCredential, GoogleAuthCredential）
  - 1 個 AuthError（9 個錯誤類型）
- [ ] 創建 AuthCache Protocol 和實現
- [ ] 創建 Data 層目錄結構（空檔案佔位）
- [ ] 驗證 Domain 層無外部依賴（編譯通過）

### Day 2 (4-5 小時) - Data Layer (DataSources + Mappers)
- [ ] 實現 4 個 DataSource
  - FirebaseAuthDataSource（含 Nonce 生成）
  - GoogleSignInDataSource
  - AppleSignInDataSource（Delegate → async/await）
  - BackendAuthDataSource（API 調用）
- [ ] 實現 2 個 Mapper
  - AuthCredentialMapper（SDK → Domain 抽象）
  - FirebaseUserMapper（Firebase + DTO → AuthUser）
- [ ] 實現 2 個 DTO
- [ ] 單元測試：DataSource Mock 測試

### Day 3 (3-4 小時) - Repository Implementations
- [ ] 實現 3 個 RepositoryImpl
  - AuthRepositoryImpl（核心認證流程，7 步驟）
  - AuthSessionRepositoryImpl（Token 管理，安全快取策略）
  - OnboardingRepositoryImpl（Onboarding API 調用）
- [ ] 實現 UserDefaultsAuthCache（5 分鐘過期）
- [ ] 單元測試：RepositoryImpl 快取策略測試

### Day 4 (3-4 小時) - Presentation Layer + Integration
- [ ] 實現 3 個 ViewModel
  - LoginViewModel（含事件發布）
  - AuthCoordinatorViewModel（含事件訂閱）
  - SignupViewModel（如果支援 Email/Password）
- [ ] DependencyContainer 註冊（3 個 Repository + 4 個 DataSource）
- [ ] 事件驗證：確認事件發布/訂閱流程正確
- [ ] 基本整合測試：Google Sign-In 端對端流程

### Day 5 (2-3 小時，可選) - Testing + Validation
- [ ] 編寫完整測試套件（Domain + Data + Presentation）
- [ ] 手動驗證所有登入方式（Google, Apple, Demo）
- [ ] 驗證 Firebase Listener 管理（無重複註冊）
- [ ] 驗證快取策略（5 分鐘過期，Token 不快取）
- [ ] 驗證事件流（ViewModel 發布，Repository 不發布）

---

## ⚠️ 風險與注意事項

### 高優先級風險

| 風險 | 影響 | 緩解 |
|------|------|------|
| Firebase Auth state listener | 雙重事件觸發 | 確保只有一個 listener，移除舊的 |
| Nonce 生成和驗證 | Apple Sign-In 失敗 | 保留原有 nonce 邏輯，單元測試 |
| Token 刷新時機 | 請求失敗 | 在 RepositoryImpl 中實現自動刷新 |
| Onboarding 狀態管理 | UI 顯示錯誤 | 與後端協調，明確 API 契約 |

### 集成檢查清單

```
Firebase:
- [ ] 保留原有 Auth state listener
- [ ] 移除 Singleton manager 的監聽器
- [ ] 驗證 nonce 生成和 SHA256 轉換

Google Sign-In:
- [ ] 驗證 idToken 和 accessToken 提取
- [ ] 測試網絡錯誤和用戶取消場景
- [ ] 檢查 GoogleSignInConfiguration 設置

Apple Sign-In:
- [ ] 驗證 ASAuthorizationController 代理
- [ ] 測試不同 iOS 版本 (14.5+)
- [ ] 檢查 presentation anchor 設置

後端 API:
- [ ] 確認 /auth/sync 端點
- [ ] 確認 onboarding status 字段
- [ ] 測試 idToken 驗證

DI:
- [ ] 註冊 AuthRepository 和所有 DataSource
- [ ] 驗證 ViewModel convenience init 工作
- [ ] 檢查無循環依賴
```

---

## 📚 Code Review 檢查清單

### Architecture
- [ ] Domain 層無任何外部依賴 (Firebase, Google SDK 等)
- [ ] ViewModel 只依賴 Protocol，不依賴實現
- [ ] Repository 實現了雙軌快取策略
- [ ] Error 正確轉換為 DomainError

### Code Quality
- [ ] 所有方法有文檔註解
- [ ] 錯誤處理涵蓋所有路徑
- [ ] 沒有 Force unwrap (!)，使用 guard/if let
- [ ] 非同步操作正確使用 async/await

### Testing
- [ ] Domain 層 100% 測試覆蓋 (Error, Entity)
- [ ] DataSource mock 測試
- [ ] RepositoryImpl 快取策略測試
- [ ] ViewModel 狀態管理測試

---

## 🎯 成功標準

✅ **完成標準**:
1. 所有 13 個文件已創建並編譯無誤
2. AuthenticationService 的 22 個主要方法都已遷移或替換
3. DependencyContainer 完整註冊
4. 至少 8-10 個測試文件，覆蓋 40%+ 代碼
5. 現有功能驗證 (Google Sign-In, Apple Sign-In, Demo Login)
6. CacheEventBus 事件正確發布與訂閱
7. 無編譯警告和廢棄 API 使用

✅ **性能標準**:
- 登入流程 < 2 秒 (不含網絡)
- Token 刷新無阻塞 UI
- 後台事件訂閱無記憶體洩漏

---

## 📌 參考資源

- 相關文檔: `ARCH-002-Clean-Architecture-Design.md`
- UserProfile 模塊: `07-USERPROFILE-MODULE-REFACTORING.md` (參考完整實現)
- Workout 模塊: `06-WORKOUT-MODULE-REFACTORING.md` (參考測試編寫)
- Firebase Auth: 官方文檔
- Apple Sign-In: ASAuthorizationController 文檔
