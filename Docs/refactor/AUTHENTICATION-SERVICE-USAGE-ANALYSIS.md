# AuthenticationService 使用分析

**分析日期**: 2026-01-07
**目標**: 分析 AuthenticationService.shared 的所有使用模式，為遷移至 Repository Pattern 做準備

---

## 使用統計

**總使用檔案數**: 19 個
**使用模式分類**: 4 種

---

## 使用模式分類

### Pattern 1: 檢查認證狀態 (最常見)

**使用方式**: `AuthenticationService.shared.isAuthenticated`

**使用檔案** (10 個):
1. AppDelegate.swift
2. AppStateManager.swift
3. HTTPClient.swift
4. HavitalApp.swift
5. ContentView.swift
6. LoginView.swift
7. OnboardingContainerView.swift
8. OnboardingView.swift
9. TrainingPlanView.swift
10. UserProfileView.swift

**遷移策略**:
- 創建 `AuthenticationViewModel` 管理認證狀態
- 提供 `@Published var isAuthenticated: Bool`
- Views 注入 `@EnvironmentObject var authViewModel: AuthenticationViewModel`

---

### Pattern 2: 獲取當前用戶資料 (次常見)

**使用方式**: `AuthenticationService.shared.appUser`

**使用檔案** (8 個):
1. AppStateManager.swift
2. ContentView.swift
3. OnboardingView.swift
4. PersonalBestView.swift
5. TrainingDaysSetupView.swift
6. LanguageSettingsView.swift
7. UserProfileView.swift
8. CompleteOnboardingUseCase.swift

**遷移策略**:
- `AuthenticationViewModel` 提供 `@Published var currentUser: AuthUser?`
- 使用 `AuthSessionRepository.getCurrentUser()` 獲取用戶
- 監聽認證狀態變化自動更新 currentUser

---

### Pattern 3: 執行登入/登出操作

**使用方式**:
- `AuthenticationService.shared.signInWithGoogle()`
- `AuthenticationService.shared.signInWithApple()`
- `AuthenticationService.shared.demoLogin()`
- `AuthenticationService.shared.signOut()`

**使用檔案** (6 個):
1. LoginView.swift
2. EmailLoginViewModel.swift (已遷移至 Feature)
3. OnboardingView.swift
4. UserProfileView.swift
5. WorkoutBackgroundManager.swift

**遷移策略**:
- 使用 `AuthRepository.signInWithGoogle()` 替代
- 使用 `AuthRepository.signOut()` 替代
- `AuthenticationViewModel` 包裝 Repository 方法

---

### Pattern 4: Onboarding 狀態管理

**使用方式**:
- `AuthenticationService.shared.hasCompletedOnboarding`
- `AuthenticationService.shared.startReonboarding()`
- `AuthenticationService.shared.resetOnboarding()`

**使用檔案** (5 個):
1. HavitalApp.swift
2. ContentView.swift
3. OnboardingView.swift
4. UserProfileView.swift
5. CompleteOnboardingUseCase.swift

**遷移策略**:
- 使用 `OnboardingRepository.getOnboardingStatus()` 替代
- 使用 `OnboardingRepository.startReonboarding()` 替代
- `AuthenticationViewModel` 管理 `@Published var onboardingStatus: OnboardingMode`

---

## 詳細使用分析

### Infrastructure Layer (5 個檔案)

#### 1. AppDelegate.swift
```swift
// Line 43: 檢查認證狀態
guard AuthenticationService.shared.isAuthenticated else {
    return
}
```
**遷移**: 注入 `AuthSessionRepository.isAuthenticated()`

#### 2. AppStateManager.swift
```swift
// Line 多處: 檢查認證和用戶資料
let isAuthenticated = AuthenticationService.shared.isAuthenticated
let currentUser = AuthenticationService.shared.appUser
```
**遷移**: 注入 `AuthSessionRepository`，使用 `isAuthenticated()` 和 `getCurrentUser()`

#### 3. HTTPClient.swift
```swift
// 獲取 ID Token
let token = try await AuthenticationService.shared.getIdToken()
```
**遷移**: 注入 `AuthSessionRepository.getIdToken()`

#### 4. WorkoutBackgroundManager.swift (UseCase)
```swift
guard AuthenticationService.shared.isAuthenticated else { return }
```
**遷移**: 注入 `AuthSessionRepository.isAuthenticated()`

#### 5. CompleteOnboardingUseCase.swift
```swift
let currentUser = AuthenticationService.shared.appUser
AuthenticationService.shared.resetOnboarding()
```
**遷移**: 注入 `AuthSessionRepository` + `OnboardingRepository`

---

### Presentation Layer - Views (10 個檔案)

#### HavitalApp.swift
```swift
@Published var isAuthenticated = AuthenticationService.shared.isAuthenticated
@Published var hasCompletedOnboarding = AuthenticationService.shared.hasCompletedOnboarding
```
**遷移**: 使用 `@EnvironmentObject var authViewModel: AuthenticationViewModel`

#### ContentView.swift
```swift
if AuthenticationService.shared.isAuthenticated {
    if AuthenticationService.shared.hasCompletedOnboarding {
        // Show main content
    }
}
```
**遷移**: 使用 `authViewModel.isAuthenticated` 和 `authViewModel.hasCompletedOnboarding`

#### LoginView.swift
```swift
await AuthenticationService.shared.signInWithGoogle()
await AuthenticationService.shared.signInWithApple()
await AuthenticationService.shared.demoLogin()
```
**遷移**: 使用 `LoginViewModel` (已存在) 調用 `AuthRepository` 方法

#### OnboardingView.swift
```swift
AuthenticationService.shared.appUser
AuthenticationService.shared.hasCompletedOnboarding
```
**遷移**: 使用 `authViewModel.currentUser` 和 `authViewModel.hasCompletedOnboarding`

#### UserProfileView.swift
```swift
try await AuthenticationService.shared.signOut()
AuthenticationService.shared.startReonboarding()
```
**遷移**: 使用 `authViewModel.signOut()` 和 `authViewModel.startReonboarding()`

---

### Service Layer (2 個檔案)

#### APIClient.swift (Legacy)
```swift
AuthenticationService.shared.getIdToken()
```
**遷移**: 此檔案為 legacy wrapper，可標記為 deprecated

#### FirebaseLoggingService.swift
```swift
AuthenticationService.shared.appUser?.id
```
**遷移**: 注入 `AuthSessionRepository.getCurrentUser()?.uid`

---

### Utility Layer (2 個檔案)

#### Utils/FirebaseLoggingExamples.swift
```swift
AuthenticationService.shared.appUser
```
**遷移**: 範例代碼，可更新為使用 `AuthSessionRepository`

---

## 遷移順序

### Phase 8A: 創建 AuthenticationViewModel (優先級: Critical)

**目標**: 創建統一的認證狀態管理 ViewModel

**檔案**: `Features/Authentication/Presentation/ViewModels/AuthenticationViewModel.swift`

**功能**:
```swift
@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AuthUser?
    @Published var onboardingStatus: OnboardingMode = .notStarted
    @Published var isLoading: Bool = false
    @Published var error: AuthenticationError?

    private let authRepository: AuthRepository
    private let authSessionRepository: AuthSessionRepository
    private let onboardingRepository: OnboardingRepository

    // Methods:
    func signInWithGoogle() async
    func signInWithApple(credential: AppleAuthCredential) async
    func signOut() async
    func startReonboarding() async
    func completeOnboarding() async
    func fetchCurrentUser() async
}
```

**預計工作量**: 2-3 小時

---

### Phase 8B: 遷移 Infrastructure Layer (優先級: High)

**目標**: 將 Infrastructure 層的 AuthenticationService 使用遷移至 Repository

**檔案** (5 個):
1. AppDelegate.swift
2. AppStateManager.swift
3. HTTPClient.swift
4. WorkoutBackgroundManager.swift (UseCase)
5. CompleteOnboardingUseCase.swift

**策略**: 注入 `AuthSessionRepository` 替代 `AuthenticationService.shared`

**預計工作量**: 2-3 小時

---

### Phase 8C: 遷移 Views 至 AuthenticationViewModel (優先級: High)

**目標**: 將 Views 從直接使用 `AuthenticationService.shared` 遷移至使用 `AuthenticationViewModel`

**檔案** (10 個):
1. HavitalApp.swift
2. ContentView.swift
3. LoginView.swift
4. OnboardingView.swift
5. OnboardingContainerView.swift
6. PersonalBestView.swift
7. TrainingDaysSetupView.swift
8. LanguageSettingsView.swift
9. TrainingPlanView.swift
10. UserProfileView.swift

**策略**: 使用 `@EnvironmentObject var authViewModel: AuthenticationViewModel`

**預計工作量**: 3-4 小時

---

### Phase 8D: 標記 AuthenticationService 為 Deprecated (優先級: Medium)

**目標**: 標記 AuthenticationService 為 @deprecated，並添加遷移指南

**檔案**: `Services/Authentication/AuthenticationService.swift`

**策略**:
```swift
@available(*, deprecated, message: "Use AuthenticationViewModel with AuthRepository/AuthSessionRepository instead")
class AuthenticationService: ObservableObject {
    // ...
}
```

**預計工作量**: 1 小時

---

## 預期成果

### Before Phase 8
```
Views → AuthenticationService.shared (Singleton)
Infrastructure → AuthenticationService.shared (Singleton)
UseCases → AuthenticationService.shared (Singleton)
```

### After Phase 8
```
Views → AuthenticationViewModel (@EnvironmentObject)
    ↓
AuthenticationViewModel → AuthRepository/AuthSessionRepository/OnboardingRepository
Infrastructure → AuthSessionRepository (DI)
UseCases → AuthRepository/OnboardingRepository (DI)

AuthenticationService → @deprecated
```

---

## 風險評估

| 風險項目 | 等級 | 緩解措施 |
|---------|------|---------|
| Views 破壞性變更 | High | 逐步遷移，保留 AuthenticationService 作為 deprecated bridge |
| 認證狀態同步問題 | Medium | AuthenticationViewModel 訂閱 Firebase Auth 狀態變化 |
| Build 失敗 | Low | 每個 Phase 後執行 build 驗證 |
| @Published 屬性遺失 | Medium | AuthenticationViewModel 提供相同的 @Published 屬性 |

---

## 總工作量估計

| Phase | 工作量 | 優先級 |
|-------|--------|--------|
| 8A: 創建 AuthenticationViewModel | 2-3 小時 | Critical |
| 8B: 遷移 Infrastructure Layer | 2-3 小時 | High |
| 8C: 遷移 Views | 3-4 小時 | High |
| 8D: 標記 Deprecated | 1 小時 | Medium |
| **總計** | **8-11 小時** | - |

---

**維護人**: Clean Architecture Migration Team
**最後更新**: 2026-01-07 14:45
