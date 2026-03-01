# 架構問題系統性檢查報告

**檢查日期**: 2026-01-08
**檢查範圍**: Clean Architecture 實現的潛在問題

---

## 🔴 嚴重問題（立即修復）

### 1. 事件鍵不匹配 - TrainingPlan 模組

**問題描述**:
- **發布者**: 使用 `.dataChanged(.trainingPlan)` → 轉換為 `"dataChanged.trainingPlan"`
- **訂閱者**: 監聽 `"trainingPlanModified"` → 完全不同的鍵
- **結果**: 訂閱者永遠收不到事件

**影響文件**:
- 發布: `TrainingPlanViewModel.swift:987`, `EditScheduleViewModel.swift:206`
- 訂閱: `TrainingPlanViewModel.swift:379`, `WeeklyPlanViewModel.swift:88`

**修復方案**:
```swift
// 選項A: 統一使用 CacheEventBus 枚舉（推薦）
CacheEventBus.shared.publish(.dataChanged(.trainingPlan))
CacheEventBus.shared.subscribe(for: "dataChanged.trainingPlan") { ... }

// 選項B: 添加自定義事件類型
enum CacheInvalidationReason {
    case trainingPlanModified
    // ...
}
```

**優先級**: 🔴 HIGH - 功能完全失效

---

## 🟡 中等問題（建議修復）

### 2. WorkoutRepository 數據源不一致

**問題描述**:
- `getWorkoutsInDateRange()` 讀取 `UnifiedWorkoutManager.workouts`
- `refreshWorkouts()` 更新 `LocalDataSource`
- 兩個數據源不同步

**影響文件**:
- `WorkoutRepositoryImpl.swift:36-41`

**已修復** (2026-01-09):
```swift
// ✅ 統一使用 WorkoutLocalDataSource
// 1. WorkoutRepositoryImpl 移除對 UnifiedWorkoutManager 的依賴
// 2. UnifiedWorkoutManager 改用 WorkoutLocalDataSource 替代 WorkoutV2CacheManager
// 3. 兩者現在共享同一緩存系統
```

**優先級**: ✅ FIXED

---

### 3. 初始化標記沒有重置

**問題描述**:
- `TrainingPlanViewModel.hasInitialized` 在登出時不會重置
- 登入後 `initialize()` 被跳過

**已修復**:
- ✅ 在 `dataChanged.user` 訂閱中重置 `hasInitialized = false`

**優先級**: ✅ FIXED

---

## 🟢 輕微問題（優化建議）

### 4. Legacy Managers 仍在使用

**發現**:
以下 Legacy Managers 仍在代碼中（標記為 deprecated 但未移除）:
- `UnifiedWorkoutManager` (✅ 已安全移除 - 2026-01-09)
- `WorkoutV2CacheManager` (因 `WorkoutDetailViewModelV2` 仍依賴其詳情緩存功能，暫時保留)
- `WeeklySummaryManager`
- `WeeklyVolumeManager`
- `TargetManager`
- `TrainingPlanManager`
- `UserPreferencesManager`

**建議**: 逐步遷移到 Repository Pattern (UnifiedWorkoutManager 遷移已完成)

**優先級**: 🟢 LOW - 不影響功能，但增加維護成本

---

## ✅ 架構檢查清單

### CacheEventBus 事件對稱性檢查

| 事件類型 | 發布者 | 訂閱者 | 狀態 |
|---------|-------|-------|------|
| `userLogout` | AuthenticationViewModel | TrainingPlanVM, UnifiedWorkoutManager, WorkoutListVM, WeeklySummaryVM, WeeklyPlanVM | ✅ 正常 |
| `onboardingCompleted` | OnboardingViewModel | TrainingPlanVM | ✅ 正常 |
| `dataChanged(.user)` | LoginViewModel | TrainingPlanVM, AuthenticationVM, WorkoutListVM | ✅ 正常 |
| `dataChanged(.workouts)` | WorkoutRepositoryImpl | ? | ⚠️ 未檢查 |
| `dataChanged(.trainingPlan)` | TrainingPlanVM, EditScheduleVM | ❌ 鍵不匹配 | 🔴 錯誤 |

### Repository 數據源一致性檢查

| Repository | 數據源數量 | 是否一致 | 狀態 |
|-----------|-----------|---------|------|
| WorkoutRepositoryImpl | 1 (LocalDataSource) | ✅ 一致 | ✅ 修復完成 |
| TrainingPlanRepositoryImpl | 2 (RemoteDataSource + LocalDataSource) | ✅ 一致 | ✅ 正常 |
| AuthRepositoryImpl | 3 (FirebaseAuth + BackendAuth + AuthCache) | ✅ 協調良好 | ✅ 正常 |

### ViewModel 初始化標記檢查

| ViewModel | hasInitialized | 登出時重置 | 登入時重置 | 狀態 |
|-----------|----------------|-----------|-----------|------|
| TrainingPlanViewModel | ✅ 有 | ✅ userLogout | ✅ dataChanged.user | ✅ 正常 |
| 其他 ViewModels | ❌ 無 | N/A | N/A | ✅ 不需要 |

---

## 📋 推薦修復順序

### 第一優先（立即修復）
1. ✅ **修復事件鍵不匹配**: `trainingPlanModified` → `dataChanged.trainingPlan`

### 第二優先（本週修復）
2. ✅ **統一 WorkoutRepository 數據源**: 現在都使用 LocalDataSource (2026-01-09 完成)

### 第三優先（逐步重構）
3. **移除 Legacy Managers**: 完全遷移到 Repository Pattern

---

## 💡 架構改進建議

### 1. 移除事件驅動，改為明確調用

**當前問題**: 隱式事件訂閱容易遺漏，難以追蹤

**改進方案**: ViewModel 主動調用 Repository，而不是被動等待事件

```swift
// ❌ 舊方式 - 被動訂閱
CacheEventBus.shared.subscribe(for: "dataChanged.user") {
    await self.loadData()
}

// ✅ 新方式 - 主動調用
func initialize() async {
    await UnifiedWorkoutManager.shared.forceRefreshFromAPI()
    await loadData()
}
```

### 2. Repository 職責單一化

**原則**: Repository 只負責數據存取，不參與事件發布

```swift
// ❌ 錯誤 - Repository 發布事件
class WorkoutRepositoryImpl {
    func refreshWorkouts() async {
        let data = try await fetch()
        CacheEventBus.shared.publish(.dataChanged(.workouts))  // ❌ 不應該
    }
}

// ✅ 正確 - ViewModel 發布事件
class WorkoutListViewModel {
    func refresh() async {
        let data = try await repository.refreshWorkouts()
        // ViewModel 決定是否需要通知其他模組
    }
}
```

### 3. 統一緩存策略

**推薦**: 所有 Repository 使用相同的雙軌緩存模式
- Track A: 立即返回本地緩存
- Track B: 背景刷新 API

---

## 🎯 總結

**總問題數**: 4
**嚴重問題**: 1 個（事件鍵不匹配）
**中等問題**: 1 個（數據源不一致）
**已修復**: 2 個

**整體評估**:
- ✅ Clean Architecture 結構清晰
- ✅ 依賴注入實現良好
- ⚠️ 事件系統需要規範化
- ⚠️ Legacy 代碼需要逐步清理
