# Target Module - Clean Architecture 重構狀態

## 完成狀態：✅ 遷移完成，TargetManager 已廢棄

---

## 架構概覽

```
Features/Target/
├── Domain/
│   ├── Errors/
│   │   └── TargetError.swift           # 領域錯誤
│   └── Repositories/
│       └── TargetRepository.swift      # Protocol 定義
├── Data/
│   ├── DataSources/
│   │   ├── TargetLocalDataSource.swift
│   │   └── TargetRemoteDataSource.swift
│   └── Repositories/
│       └── TargetRepositoryImpl.swift  # 含 DI 註冊擴展
└── Presentation/
    └── ViewModels/
        └── TargetFeatureViewModel.swift
```

---

## 依賴注入整合

### DependencyContainer 註冊

```swift
// Havital/Core/DI/DependencyContainer.swift
func registerTargetDependencies() {
    registerTargetModule()  // 調用 TargetRepositoryImpl 中的擴展方法
    Logger.debug("[DI] Target module dependencies registered")
}
```

### 註冊調用位置

```swift
// HavitalApp.swift init()
DependencyContainer.shared.registerTargetDependencies()
print("📦 Target 模組依賴已註冊")
```

### ViewModel 使用方式

由於 `@MainActor` 隔離限制，ViewModel 不通過 DI Container 工廠註冊。
Views 應直接使用 convenience init：

```swift
// 在 View 中
@StateObject private var viewModel = TargetFeatureViewModel()

// TargetFeatureViewModel 的 convenience init 會自動從 DI 解析依賴
convenience init() {
    self.init(repository: DependencyContainer.shared.resolve())
}
```

---

## 遷移狀態

### 已完成

- [x] Domain Layer 定義完成
- [x] Data Layer 實作完成
- [x] Repository Pattern 實現
- [x] DependencyContainer 整合
- [x] ViewModel 實作（TargetFeatureViewModel）
- [x] 雙軌緩存策略實現

### 待完成

- [x] ~~遷移 `TrainingPlanOverviewDetailView.swift` 中的 TargetManager 使用~~ ✅ 已完成
- [ ] 移除已棄用的 `TargetManager.swift`（下次清理）

---

## 遷移策略

### TargetManager 使用點遷移狀態

| 檔案 | 用途 | 狀態 | 遷移方案 |
|-----|------|------|---------|
| `TrainingPlanOverviewDetailView.swift` | 賽事顯示與編輯 | ✅ 已完成 | → `TargetFeatureViewModel` |
| `TargetManager.swift` | 原始管理器 | ⚠️ 已廢棄 | 可刪除 |

### 遷移模式

#### 1. 載入賽事資料
```swift
// Before
@StateObject private var targetManager = TargetManager.shared
await targetManager.loadTargets()

// After
@StateObject private var targetViewModel = TargetFeatureViewModel()
await targetViewModel.loadTargets()
```

#### 2. 強制刷新
```swift
// Before
await targetManager.forceRefresh()

// After
await targetViewModel.forceRefresh()
```

#### 3. 讀取主賽事
```swift
// Before
if let target = targetManager.mainTarget { ... }

// After
if let target = targetViewModel.mainTarget { ... }
```

#### 4. 讀取支援賽事
```swift
// Before
targetManager.supportingTargets

// After
targetViewModel.supportingTargets
```

---

## 注意事項

### 雙軌緩存策略

Repository 實現雙軌緩存：
- Track A: 立即返回本地緩存（快速顯示）
- Track B: 背景刷新 API 數據（保持新鮮）

### @MainActor 隔離

ViewModel 必須標記為 `@MainActor`，這導致：
- 無法在 DependencyContainer 中使用同步工廠
- Views 應使用 `@StateObject private var viewModel = ViewModel()`
- convenience init 會自動解析依賴

### 向後兼容

Repository 在更新時仍然發送 `NotificationCenter` 通知：
- `.targetUpdated`
- `.supportingTargetUpdated`

這確保其他尚未遷移的組件仍能正常運作。

---

## 相關文檔

- [Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [UserProfile 模組重構](./07-USERPROFILE-MODULE-REFACTORING.md)
