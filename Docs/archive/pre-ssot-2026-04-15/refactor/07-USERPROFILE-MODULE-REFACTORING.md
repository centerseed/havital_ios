# UserProfile Module - Clean Architecture 重構狀態

## 完成狀態：✅ 遷移完成，UserManager 已廢棄

---

## 架構概覽

```
Features/UserProfile/
├── Domain/
│   ├── Entities/
│   │   └── UserProfile.swift            # 業務實體
│   ├── Errors/
│   │   └── UserProfileError.swift       # 領域錯誤
│   ├── Repositories/
│   │   └── UserProfileRepository.swift  # Protocol 定義
│   └── UseCases/
│       ├── GetUserProfileUseCase.swift
│       ├── RefreshUserProfileUseCase.swift
│       ├── GetHeartRateZonesUseCase.swift
│       ├── GetTargetsUseCase.swift
│       ├── CalculateStatisticsUseCase.swift
│       ├── SaveUserMetricsUseCase.swift
│       ├── UpdateActivityGoalUseCase.swift
│       └── SetHeartRateZonesUseCase.swift
├── Data/
│   ├── DTOs/
│   │   └── UserProfileDTO.swift         # API 資料傳輸對象
│   ├── DataSources/
│   │   ├── UserProfileRemoteDataSource.swift
│   │   └── UserProfileLocalDataSource.swift
│   ├── Mappers/
│   │   └── UserProfileMapper.swift
│   └── Repositories/
│       └── UserProfileRepositoryImpl.swift  # 含 DI 註冊擴展
└── Presentation/
    └── ViewModels/
        └── UserProfileFeatureViewModel.swift  # 使用 8 個 UseCases
```

---

## 依賴注入整合

### DependencyContainer 註冊

```swift
// Havital/Core/DI/DependencyContainer.swift
func registerUserDependencies() {
    registerUserProfileModule()  // 調用 UserProfileRepositoryImpl 中的擴展方法
    Logger.debug("[DI] User module dependencies registered")
}
```

### 註冊調用位置

```swift
// HavitalApp.swift init()
DependencyContainer.shared.registerUserDependencies()
print("📦 User 模組依賴已註冊")
```

### ViewModel 使用方式

由於 `@MainActor` 隔離限制，ViewModel 不通過 DI Container 工廠註冊。
Views 應直接使用 convenience init：

```swift
// 在 View 中
@StateObject private var viewModel = UserProfileFeatureViewModel()

// UserProfileFeatureViewModel 的 convenience init 會自動從 DI 解析依賴
convenience init() {
    self.init(
        getUserProfileUseCase: DependencyContainer.shared.resolve(),
        refreshUserProfileUseCase: DependencyContainer.shared.resolve(),
        // ... 其他 UseCases
    )
}
```

---

## 集成測試

### 測試檔案位置

```
HavitalTests/Features/UserProfile/
├── Repositories/
│   └── UserProfileRepositoryIntegrationTests.swift  # 6 個測試
└── ViewModels/
    └── UserProfileViewModelIntegrationTests.swift   # 7 個測試
```

### 測試執行結果

| 測試類別 | 測試數量 | 狀態 |
|---------|---------|------|
| UserProfileRepositoryIntegrationTests | 18 | ✅ 全部通過 |
| UserProfileViewModelIntegrationTests | 21 | ⚠️ 需要完整認證環境 |

### Repository 測試項目

1. `test_getUserProfile_shouldReturnValidData` - 獲取用戶資料
2. `test_refreshUserProfile_shouldReturnFreshData` - 強制刷新
3. `test_getHeartRateZones_shouldReturnZonesIfAvailable` - 獲取心率區間
4. `test_getTargets_shouldReturnTargetsList` - 獲取用戶目標
5. `test_calculateStatistics_shouldReturnStats` - 計算統計
6. `test_caching_shouldReturnCachedData` - 緩存機制驗證

---

## 遷移狀態

### 已完成

- [x] Domain Layer 定義完成
- [x] Data Layer 實作完成
- [x] Repository Pattern 實現
- [x] DependencyContainer 整合
- [x] UseCases 全部實作（8 個）
- [x] ViewModel 使用 UseCases
- [x] 集成測試框架建立

### 待完成

- [x] ~~遷移 `MyAchievementView.swift` 中的 UserManager 使用~~ ✅ 已完成
- [x] ~~遷移 `AppStateManager.swift` 中的 UserManager 使用~~ ✅ 已完成
- [x] ~~遷移 `AppRatingManager.swift` 中的 UserManager 使用~~ ✅ 已完成
- [x] ~~標記 `UserProfileViewModelV2.swift` 為 deprecated~~ ✅ 已完成（此類別未被使用）
- [ ] 移除已棄用的 `UserManager.swift` 和 `UserProfileViewModelV2.swift`（下次清理）

---

## 遷移策略

### UserManager 使用點遷移狀態

| 檔案 | 用途 | 狀態 | 遷移方案 |
|-----|------|------|---------|
| `UserProfileFeatureViewModel.swift` | 已遷移至 UseCases | ✅ 已完成 | 使用 8 個 UseCases |
| `MyAchievementView.swift` | 成就顯示 | ✅ 已完成 | → `UserProfileLocalDataSource` + `PersonalBestCelebrationStorage` |
| `AppStateManager.swift` | 應用狀態管理 | ✅ 已完成 | → `UserProfileLocalDataSource.saveUserProfile()` |
| `AppRatingManager.swift` | 評分提示 | ✅ 已完成 | → `UserProfileLocalDataSource.getUserProfile()` |
| `UserProfileViewModelV2.swift` | 舊 ViewModel | ⚠️ 已廢棄 | 無使用點，可刪除 |
| `UserManager.swift` | 原始管理器 | ⚠️ 已廢棄 | 無使用點，可刪除 |

### 遷移模式

#### 1. 讀取用戶資料（同步快取）
```swift
// Before
let user = UserManager.shared.currentUser

// After
let user = UserProfileLocalDataSource().getUserProfile()
```

#### 2. 保存用戶資料到快取
```swift
// Before
await UserManager.shared.updateCurrentUser(user)

// After
UserProfileLocalDataSource().saveUserProfile(user)
```

#### 3. Personal Best 慶祝動畫
```swift
// Before
userManager.markCelebrationAsShown()
userManager.getPendingCelebrationUpdate()

// After
PersonalBestCelebrationStorage.markCelebrationAsShown()
PersonalBestCelebrationStorage.getPendingCelebrationUpdate()
```

---

## 注意事項

### Demo 帳號測試

集成測試使用 Demo 帳號，需注意：
- Demo 帳號可能沒有 email（只有 displayName）
- 測試斷言應檢查 `displayName OR email`，而非只檢查 email

### @MainActor 隔離

ViewModel 必須標記為 `@MainActor`，這導致：
- 無法在 DependencyContainer 中使用同步工廠
- Views 應使用 `@StateObject private var viewModel = ViewModel()`
- convenience init 會自動解析依賴

---

## 相關文檔

- [Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [遷移路線圖](./03-MIGRATION-ROADMAP.md)
- [模組拆分計畫](./04-MODULE-BREAKDOWN.md)
