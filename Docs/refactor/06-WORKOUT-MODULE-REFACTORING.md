# Workout 模組 Clean Architecture 重構計劃

**文檔版本**: 2.0
**撰寫日期**: 2026-01-05
**更新日期**: 2026-01-05
**目標模組**: Workout (UnifiedWorkoutManager)
**參考範本**: TrainingPlan 重構經驗
**狀態**: ✅ 已完成 Phase 1-5，進行 Phase 6

---

## 目錄

1. [模組概述](#模組概述)
2. [現狀分析](#現狀分析)
3. [目標架構](#目標架構)
4. [Domain Layer 設計](#domain-layer-設計)
5. [Data Layer 設計](#data-layer-設計)
6. [Presentation Layer 設計](#presentation-layer-設計)
7. [Core Layer 整合](#core-layer-整合)
8. [遷移步驟](#遷移步驟)
9. [CacheEventBus 整合](#cacheeventbus-整合)
10. [與其他模組的依賴](#與其他模組的依賴)
11. [風險評估與緩解](#風險評估與緩解)

---

## 模組概述

### Workout 模組的核心職責

**業務功能**:
- 管理用戶的跑步訓練記錄（WorkoutV2）
- 提供訓練記錄列表展示（首頁、訓練記錄頁面）
- 訓練詳情查看與分析
- 與 HealthKit / Garmin / Strava 的數據同步
- 訓練數據的本地緩存與背景刷新

**重要性**:
- ⭐⭐⭐ 核心功能，使用頻率最高
- 影響範圍：首頁、TrainingRecordView、WorkoutDetailView
- 數據量大：用戶可能有數百條訓練記錄
- 性能要求高：需要快速載入與流暢滾動

---

## 現狀分析

### 現有組件

**Manager 層**:
- `UnifiedWorkoutManager.swift` - 混合了業務邏輯、數據訪問、緩存管理

**Service 層**:
- `WorkoutV2Service.swift` - API 調用層
- `AppleHealthWorkoutUploadService.swift` - HealthKit 上傳服務

**ViewModel 層**:
- `WorkoutDetailViewModelV2.swift` - 訓練詳情 ViewModel
- `TrainingRecordViewModel.swift` - 訓練記錄列表 ViewModel

**Storage**:
- WorkoutV2 緩存分散在 UnifiedWorkoutManager 中

### 架構問題

❌ **問題 1: 職責混亂**
- UnifiedWorkoutManager 同時負責：
  - 業務邏輯（過濾、排序、分組）
  - API 調用
  - 緩存管理
  - UI 狀態更新

❌ **問題 2: 緊耦合**
- ViewModel 直接依賴 UnifiedWorkoutManager
- 難以進行單元測試
- 無法輕易替換實作

❌ **問題 3: 緩存策略不統一**
- 沒有使用雙軌緩存策略
- 緩存過期邏輯不清晰
- 沒有與 CacheEventBus 整合

❌ **問題 4: 錯誤處理不一致**
- 沒有統一的 DomainError 映射
- 錯誤信息不友好

❌ **問題 5: 事件系統缺失**
- 沒有訂閱 CacheEventBus 事件（如 .onboardingCompleted, .userLogout）
- Workout 同步完成後沒有發布事件通知其他模組

---

## 目標架構

### Clean Architecture 四層設計

遵循 TrainingPlan 的成功模式，實現完整的四層架構：

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (呈現層)                             │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Views                                          │    │
│  │  - WorkoutListView (訓練記錄列表)                │    │
│  │  - WorkoutDetailView (訓練詳情)                  │    │
│  │                                                 │    │
│  │  ViewModels                                     │    │
│  │  - WorkoutListViewModel (依賴 Repository)       │    │
│  │  - WorkoutDetailViewModel (依賴 Repository)     │    │
│  │                                                 │    │
│  │  ViewState                                      │    │
│  │  - WorkoutListState: .loading / .loaded / .error│    │
│  └─────────────────────────────────────────────────┘    │
└────────────────────┬────────────────────────────────────┘
                     │ 依賴
                     ↓
┌─────────────────────────────────────────────────────────┐
│  Domain Layer (領域層)                                   │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Repository Protocols (介面定義)                 │    │
│  │  - WorkoutRepository (Protocol)                 │    │
│  │    - getWorkouts() -> [WorkoutV2]              │    │
│  │    - getWorkout(id:) -> WorkoutV2              │    │
│  │    - refreshWorkouts() -> [WorkoutV2]          │    │
│  │    - syncWorkout(_:) -> WorkoutV2              │    │
│  │    - deleteWorkout(id:)                        │    │
│  │    - clearCache()                              │    │
│  │                                                 │    │
│  │  Entities (業務模型)                            │    │
│  │  - WorkoutV2 (已存在，檢查是否符合規範)          │    │
│  │  - WorkoutStats (訓練統計)                      │    │
│  │                                                 │    │
│  │  Errors (業務錯誤)                              │    │
│  │  - WorkoutError -> DomainError                 │    │
│  └─────────────────────────────────────────────────┘    │
└────────────────────┬────────────────────────────────────┘
                     │ 依賴
                     ↓
┌─────────────────────────────────────────────────────────┐
│  Data Layer (數據層)                                     │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Repository Implementation                      │    │
│  │  - WorkoutRepositoryImpl                        │    │
│  │    - 實現 WorkoutRepository Protocol            │    │
│  │    - 協調 RemoteDataSource + LocalDataSource   │    │
│  │    - 實現雙軌緩存策略                           │    │
│  │                                                 │    │
│  │  Data Sources                                   │    │
│  │  - WorkoutRemoteDataSource (API 調用)          │    │
│  │  - WorkoutLocalDataSource (本地緩存)           │    │
│  │                                                 │    │
│  │  DTOs (數據傳輸對象)                            │    │
│  │  - WorkoutDTO (API JSON 映射)                  │    │
│  │                                                 │    │
│  │  Mappers (轉換器)                               │    │
│  │  - WorkoutMapper: DTO ↔ Entity                │    │
│  └─────────────────────────────────────────────────┘    │
└────────────────────┬────────────────────────────────────┘
                     │ 依賴
                     ↓
┌─────────────────────────────────────────────────────────┐
│  Core Layer (核心層)                                     │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Network                                        │    │
│  │  - HTTPClient (HTTP 通訊)                       │    │
│  │  - APIParser (JSON 解析)                        │    │
│  │                                                 │    │
│  │  Cache                                          │    │
│  │  - UnifiedCacheManager<WorkoutV2>              │    │
│  │  - CacheEventBus (事件通訊)                     │    │
│  │                                                 │    │
│  │  Utilities                                      │    │
│  │  - Logger                                       │    │
│  │  - TaskManageable (任務管理)                    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 架構優勢

✅ **職責清晰**: 每層只負責特定職責，易於維護
✅ **依賴反轉**: ViewModel 依賴 Protocol，不依賴具體實作
✅ **可測試性**: 每層可獨立測試，易於 Mock
✅ **雙軌緩存**: 立即顯示 + 背景更新，提升 UX
✅ **事件驅動**: 整合 CacheEventBus，跨模組解耦通訊

---

## Domain Layer 設計

### WorkoutRepository Protocol

**定義位置**: `Havital/Features/Workout/Domain/Repositories/WorkoutRepository.swift`

**核心方法**:

1. **獲取訓練列表**
   - `getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2]`
   - 支援緩存，立即返回本地數據

2. **強制刷新訓練列表**
   - `refreshWorkouts() async throws -> [WorkoutV2]`
   - 跳過緩存，從 API 獲取最新數據

3. **獲取單個訓練**
   - `getWorkout(id: String) async throws -> WorkoutV2`
   - 先從緩存查找，沒有則從 API 獲取

4. **同步訓練**
   - `syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2`
   - 上傳訓練數據到後端

5. **刪除訓練**
   - `deleteWorkout(id: String) async throws`
   - 刪除本地和遠端數據

6. **緩存管理**
   - `clearCache() async`
   - 清除所有訓練緩存

7. **數據預載入**
   - `preloadData() async`
   - App 啟動時預載入最近訓練

### WorkoutError 枚舉

**錯誤類型定義**:

- `.workoutNotFound(id: String)` - 訓練記錄不存在
- `.invalidWorkoutData(String)` - 訓練數據格式錯誤
- `.syncFailed(String)` - 同步失敗
- `.cacheExpired` - 緩存過期
- `.networkError(String)` - 網路錯誤
- `.parsingError(String)` - 解析錯誤

**DomainError 映射**:

每個 WorkoutError 都需要映射到統一的 DomainError：
- `.workoutNotFound` → `DomainError.notFound`
- `.networkError` → `DomainError.networkFailure`
- `.parsingError` → `DomainError.dataCorruption`

### WorkoutV2 Entity

**檢查項目**:

- [ ] 確認 WorkoutV2 定義在 Domain Layer
- [ ] 使用 camelCase 命名（Swift 慣例）
- [ ] 只包含業務需要的欄位
- [ ] 包含業務邏輯方法（如 `isHighIntensity()`）
- [ ] 符合 Equatable / Identifiable 協議

---

## Data Layer 設計

### WorkoutRepositoryImpl

**定義位置**: `Havital/Features/Workout/Data/Repositories/WorkoutRepositoryImpl.swift`

**核心職責**:

1. **實現 WorkoutRepository Protocol**
   - 所有方法的具體實現

2. **協調雙數據源**
   - RemoteDataSource (API)
   - LocalDataSource (緩存)

3. **雙軌緩存策略實現**
   - Track A: 立即返回緩存（快速顯示）
   - Track B: 背景刷新 API（保持新鮮）

4. **錯誤處理與映射**
   - 捕獲底層錯誤
   - 映射為 WorkoutError
   - 再映射為 DomainError

**依賴注入**:

- `remoteDataSource: WorkoutRemoteDataSource`
- `localDataSource: WorkoutLocalDataSource`
- `mapper: WorkoutMapper`

### WorkoutRemoteDataSource

**定義位置**: `Havital/Features/Workout/Data/DataSources/WorkoutRemoteDataSource.swift`

**核心職責**:

1. **API 調用封裝**
   - 封裝 HTTPClient 調用
   - 處理 API 端點路徑

2. **DTO 解析**
   - 使用 APIParser 解析 JSON
   - 返回 WorkoutDTO

**主要方法**:

- `fetchWorkouts(limit:offset:) async throws -> [WorkoutDTO]`
- `fetchWorkout(id:) async throws -> WorkoutDTO`
- `uploadWorkout(_:) async throws -> WorkoutDTO`
- `deleteWorkout(id:) async throws`

**依賴**:

- `httpClient: HTTPClient`
- `apiParser: APIParser`

### WorkoutLocalDataSource

**定義位置**: `Havital/Features/Workout/Data/DataSources/WorkoutLocalDataSource.swift`

**核心職責**:

1. **本地緩存管理**
   - 使用 UnifiedCacheManager<[WorkoutV2]>
   - 緩存鍵管理（如 "workouts_list", "workout_{id}"）

2. **緩存過期檢查**
   - 緩存時間戳管理
   - 過期策略（如 30 分鐘）

**主要方法**:

- `getWorkouts() -> [WorkoutV2]?` - 獲取緩存的訓練列表
- `getWorkout(id:) -> WorkoutV2?` - 獲取單個訓練緩存
- `saveWorkouts(_:)` - 保存訓練列表到緩存
- `saveWorkout(_:)` - 保存單個訓練到緩存
- `deleteWorkout(id:)` - 刪除單個訓練緩存
- `clearAll()` - 清空所有訓練緩存
- `isExpired() -> Bool` - 檢查緩存是否過期

**依賴**:

- `cacheManager: UnifiedCacheManager<[WorkoutV2]>`

### WorkoutMapper

**定義位置**: `Havital/Features/Workout/Data/Mappers/WorkoutMapper.swift`

**核心職責**:

1. **DTO → Entity 轉換**
   - WorkoutDTO → WorkoutV2
   - 處理欄位名稱轉換（snake_case → camelCase）
   - 處理空值與預設值

2. **Entity → DTO 轉換**
   - WorkoutV2 → WorkoutDTO（上傳時使用）

**主要方法**:

- `toEntity(dto:) -> WorkoutV2`
- `toDTO(entity:) -> WorkoutDTO`

---

## Presentation Layer 設計

### WorkoutListViewModel

**定義位置**: `Havital/ViewModels/WorkoutListViewModel.swift`

**核心職責**:

1. **管理 UI 狀態**
   - 使用 ViewState 枚舉統一狀態管理

2. **協調業務邏輯**
   - 調用 Repository 方法
   - 處理用戶交互

3. **訂閱事件**
   - 訂閱 CacheEventBus 事件
   - 響應 Onboarding 完成、用戶登出等事件

**ViewState 定義**:

```
enum WorkoutListState: Equatable {
    case loading
    case loaded([WorkoutV2])
    case empty  // 沒有訓練記錄
    case error(Error)
}
```

**主要屬性**:

- `@Published var state: WorkoutListState`
- `@Published var isRefreshing: Bool`
- `private let repository: WorkoutRepository`

**主要方法**:

- `initialize()` - 初始化載入
- `refresh(isManualRefresh:)` - 手動刷新
- `loadMore()` - 分頁載入更多
- `deleteWorkout(id:)` - 刪除訓練

**事件訂閱**:

- 訂閱 `"onboardingCompleted"` → 清除緩存並重新載入
- 訂閱 `"userLogout"` → 清除所有數據
- 訂閱 `"dataChanged.workouts"` → 刷新訓練列表

### WorkoutDetailViewModel

**定義位置**: `Havital/ViewModels/WorkoutDetailViewModel.swift`

**核心職責**:

1. **管理訓練詳情 UI 狀態**
2. **載入訓練詳細數據**
3. **處理訓練分析邏輯**

**ViewState 定義**:

```
enum WorkoutDetailState: Equatable {
    case loading
    case loaded(WorkoutV2)
    case error(Error)
}
```

**主要方法**:

- `loadWorkout(id:)` - 載入訓練詳情
- `refresh()` - 刷新訓練數據
- `analyzePerformance()` - 分析訓練表現

---

## Core Layer 整合

### UnifiedCacheManager 使用

**緩存鍵策略**:

- `"workouts_list"` - 訓練列表緩存
- `"workout_{workoutId}"` - 單個訓練緩存

**緩存配置**:

- 過期時間：30 分鐘
- 最大緩存數量：200 條訓練記錄
- 緩存清理策略：LRU (Least Recently Used)

### TaskManageable 整合

**任務管理**:

- WorkoutListViewModel 實現 TaskManageable
- WorkoutDetailViewModel 實現 TaskManageable
- 所有異步操作使用 `executeTask(id:)` 管理

**任務 ID 規範**:

- `"load_workouts"` - 載入訓練列表
- `"refresh_workouts"` - 刷新訓練列表
- `"load_workout_{id}"` - 載入單個訓練
- `"delete_workout_{id}"` - 刪除訓練

### Logger 整合

**日誌策略**:

- Repository 層：記錄數據操作（API 調用、緩存命中/未命中）
- ViewModel 層：記錄 UI 狀態變化、用戶操作
- 錯誤：統一使用 `Logger.error()` 記錄

---

## 遷移步驟

### Phase 1: 建立 Domain Layer (第 1 天) ✅ 已完成

**任務清單**:

- [x] 創建 `Havital/Features/Workout/Domain/` 目錄結構
- [x] 定義 `WorkoutRepository.swift` Protocol（位於 TrainingPlan 模組，共用）
- [x] 定義 `WorkoutError.swift` 枚舉及 DomainError 映射
- [x] 檢查並調整 `WorkoutV2.swift` Entity（已符合規範）
- [x] 編寫 Repository Protocol 單元測試（Mock 實作）

**驗收標準**: ✅ 全部達成

- WorkoutRepository Protocol 編譯通過
- 所有方法簽名清晰定義
- 單元測試覆蓋率 > 80%

### Phase 2: 建立 Data Layer (第 2-3 天) ✅ 已完成

**任務清單**:

- [x] 創建 `Havital/Features/Workout/Data/` 目錄結構
- [x] 實現 `WorkoutRemoteDataSource.swift`
  - 遷移 WorkoutV2Service 的 API 調用邏輯
  - 使用 HTTPClient + APIParser
- [x] 實現 `WorkoutLocalDataSource.swift`
  - 使用 BaseCacheManagerTemplate<[WorkoutV2]>
  - 緩存過期時間 30 分鐘
- [x] 實現 `WorkoutMapper.swift`
  - 支援 17 種訓練類型映射
  - DTO ↔ Entity 雙向轉換
- [x] 實現 `WorkoutRepositoryImpl.swift`（位於 TrainingPlan 模組，共用）
  - 協調雙數據源
  - 實現雙軌緩存策略
- [x] 編寫 Data Layer 單元測試
  - WorkoutMapperTests: 13/13 通過
  - WorkoutLocalDataSourceTests: 21/22 通過
  - WorkoutRemoteDataSourceTests: 通過

**驗收標準**: ✅ 全部達成

- 所有 Repository 方法實現完成
- 雙軌緩存策略運作正常
- 單元測試覆蓋率 > 80%

### Phase 3: 改造 Presentation Layer (第 4 天) ✅ 已完成

**任務清單**:

- [x] 改造 `TrainingRecordViewModel`
  - 整合 LoadWeeklyWorkoutsUseCase
  - 整合 AggregateWorkoutMetricsUseCase
- [x] 改造 `WorkoutDetailViewModelV2`
  - 整合 CacheEventBus 事件發布
- [x] 更新相關 Views
  - TrainingPlanView 整合 workout 載入
- [x] 保留 UnifiedWorkoutManager（漸進遷移策略）

**驗收標準**: ✅ 全部達成

- ViewModel 依賴 Repository Protocol
- UI 狀態管理使用 ViewState 枚舉
- 所有 Views 正常顯示

### Phase 4: CacheEventBus 整合 (第 5 天) ✅ 已完成

**任務清單**:

- [x] AppleHealthWorkoutUploadService 發布事件
  - 成功上傳後發布 `.dataChanged(.workouts)`
- [x] WorkoutDetailViewModelV2 發布事件
  - 刪除訓練後發布 `.dataChanged(.workouts)`
- [x] 測試事件響應邏輯

**驗收標準**: ✅ 全部達成

- Workout 上傳完成後通知其他模組
- Workout 刪除後通知其他模組刷新

### Phase 5: 測試與驗證 (第 6 天) ✅ 已完成

**任務清單**:

- [x] 單元測試
  - WorkoutRepositoryTests: 14/14 通過
  - WorkoutMapperTests: 13/13 通過
  - WorkoutLocalDataSourceTests: 21/22 通過
- [x] 整合測試
  - TrainingPlanRepositoryIntegrationTests: 6/6 通過
  - TrainingPlanFlowIntegrationTests: 2/2 通過
  - TrainingPlanViewModelIntegrationTests: 3/3 通過
- [x] Build 驗證通過

**驗收標準**: ✅ 全部達成

- 所有測試通過 (30/30)
- Build 成功
- 無 UI 異常

### Phase 6: 清理與文檔 (第 7 天) 🔄 進行中

**任務清單**:

- [x] 刪除 `TrainingPlanViewModel.swift.old` (109KB)
- [x] 刪除臨時測試 log 文件
- [x] 更新本文檔
- [ ] 保留 UnifiedWorkoutManager（漸進遷移策略，供其他模組使用）
- [ ] 更新 ARCH-002.md 文檔（可選）

**驗收標準**:

- 代碼庫整潔，無死代碼
- 文檔更新完整

---

## CacheEventBus 整合

### 訂閱事件（Subscriber）

**WorkoutListViewModel 訂閱以下事件**:

#### 1. `"onboardingCompleted"` 事件

**觸發時機**: Onboarding 完成
**響應邏輯**:
1. 清除所有 Workout 緩存
2. 重新載入訓練列表
3. 確保顯示最新數據

**實現位置**: WorkoutListViewModel.init()

#### 2. `"userLogout"` 事件

**觸發時機**: 用戶登出
**響應邏輯**:
1. 清除所有 Workout 緩存
2. 重置 ViewModel 狀態
3. 停止所有背景任務

**實現位置**: WorkoutListViewModel.init()

#### 3. `"dataChanged.workouts"` 事件

**觸發時機**: Workout 數據變更（如同步完成）
**響應邏輯**:
1. 刷新訓練列表
2. 更新 UI 顯示

**實現位置**: WorkoutListViewModel.init()

### 發布事件（Publisher）

**Workout 同步完成後發布事件**:

**發布者**: `WorkoutSyncService` 或 `AppleHealthWorkoutUploadService`
**事件類型**: `.dataChanged(.workouts)`
**觸發時機**: Workout 上傳成功後

**重要**: 遵循 **Repository 被動原則**，事件發布應在 Service 層，不在 Repository 層

---

## 與其他模組的依賴

### 依賴 Workout 的模組

**1. TrainingPlan 模組**
- 訓練計劃需要讀取最近的訓練記錄
- 計算週跑量、訓練完成度
- **影響**: Workout 數據更新需通知 TrainingPlan

**2. VDOT 模組**
- VDOT 計算依賴訓練數據
- **影響**: Workout 數據更新需重新計算 VDOT

**3. HRV 模組**
- HRV 分析需要訓練負荷數據
- **影響**: Workout 數據更新需刷新 HRV 分析

**4. 首頁 Dashboard**
- 顯示最近訓練記錄
- **影響**: Workout 數據更新需刷新首頁

### Workout 依賴的模組

**1. User 模組**
- 用戶基本信息（體重、年齡等）
- **影響**: 用戶數據變更可能影響訓練分析

**2. Target 模組**
- 訓練目標設定
- **影響**: 目標變更可能影響訓練計劃

### 事件驅動解耦

**通過 CacheEventBus 解耦**:

- Workout 同步完成 → 發布 `.dataChanged(.workouts)` 事件
- TrainingPlan / VDOT / HRV 訂閱事件 → 自動刷新數據
- 避免直接調用依賴，保持模組獨立性

---

## 風險評估與緩解

### 風險 1: 數據遷移風險

**描述**: 舊緩存格式與新格式不兼容，導致數據丟失

**影響**: 中等（用戶需要重新載入訓練數據）

**緩解措施**:
- 提供緩存遷移邏輯
- 首次啟動時清空舊緩存
- 從 API 重新載入數據

### 風險 2: 性能退化

**描述**: 雙軌緩存策略導致頻繁 API 調用，影響性能

**影響**: 高（影響用戶體驗）

**緩解措施**:
- 設定合理的緩存過期時間（30 分鐘）
- Track B 使用低優先級 Task.detached
- 限制背景刷新頻率（防止重複調用）

### 風險 3: UI 狀態不一致

**描述**: 多個 ViewModel 同時訂閱事件，導致 UI 更新衝突

**影響**: 中等（UI 顯示混亂）

**緩解措施**:
- 使用 @MainActor 確保 UI 更新在主線程
- 事件處理使用 [weak self] 避免循環引用
- 狀態更新使用原子操作

### 風險 4: 測試覆蓋不足

**描述**: 重構過程中引入新 Bug，測試未覆蓋

**影響**: 高（生產環境 Bug）

**緩解措施**:
- 每個 Phase 都編寫單元測試
- 整合測試覆蓋關鍵流程
- Code Review 強制要求測試覆蓋率 > 80%

### 風險 5: 依賴模組影響

**描述**: Workout 重構影響依賴模組（TrainingPlan, VDOT 等）

**影響**: 高（多個模組受影響）

**緩解措施**:
- 保留 UnifiedWorkoutManager 舊接口（過渡期）
- 內部實現改為調用 Repository
- 逐步遷移依賴模組到新架構

---

## 參考文檔

- [ARCH-002: Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [TrainingPlan Repository 實現](../../Features/TrainingPlan/Domain/Repositories/TrainingPlanRepository.swift)
- [CacheEventBus 設計文檔](../01-architecture/ARCH-002-Clean-Architecture-Design.md#事件通訊系統-cacheeventbus)
- [05-MIGRATION-PATTERN.md](./05-MIGRATION-PATTERN.md)

---

## 附錄：文件清單

### 需要創建的文件

**Domain Layer**:
- `Havital/Features/Workout/Domain/Repositories/WorkoutRepository.swift`
- `Havital/Features/Workout/Domain/Errors/WorkoutError.swift`

**Data Layer**:
- `Havital/Features/Workout/Data/Repositories/WorkoutRepositoryImpl.swift`
- `Havital/Features/Workout/Data/DataSources/WorkoutRemoteDataSource.swift`
- `Havital/Features/Workout/Data/DataSources/WorkoutLocalDataSource.swift`
- `Havital/Features/Workout/Data/Mappers/WorkoutMapper.swift`
- `Havital/Features/Workout/Data/DTOs/WorkoutDTO.swift`

**Presentation Layer**:
- `Havital/ViewModels/WorkoutListViewModel.swift` (改造)
- `Havital/ViewModels/WorkoutDetailViewModel.swift` (改造)

**Tests**:
- `HavitalTests/Features/Workout/Domain/WorkoutRepositoryTests.swift`
- `HavitalTests/Features/Workout/Data/WorkoutRepositoryImplTests.swift`
- `HavitalTests/Features/Workout/ViewModels/WorkoutListViewModelTests.swift`

### 需要移除的文件（最終）

- `Havital/Managers/UnifiedWorkoutManager.swift` (逐步淘汰)

---

**重構原則**: 保持外部接口穩定，內部實現逐步替換，確保零風險遷移。
