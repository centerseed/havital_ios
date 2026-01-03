# 01. Flutter 架構設計

## 📐 Clean Architecture 分層設計

Paceriz Flutter 應用程式採用 **Clean Architecture（簡潔架構）** 四層設計，確保職責清晰、易於測試和維護。

```
┌──────────────────────────────────────────────────────────────┐
│                   Presentation Layer                          │
│  (UI/狀態管理 - BLoC)                                          │
│  ┌──────────────┬──────────────┬──────────────┐              │
│  │    Pages     │    BLoCs     │   Widgets    │              │
│  │  (UI 頁面)    │  (狀態管理)   │  (UI 元件)    │              │
│  └──────────────┴──────────────┴──────────────┘              │
├──────────────────────────────────────────────────────────────┤
│                    Domain Layer                               │
│  (業務邏輯/用例/實體)                                           │
│  ┌──────────────┬──────────────┬──────────────┐              │
│  │  Entities    │  Use Cases   │ Repositories │              │
│  │  (領域實體)   │  (業務邏輯)   │  (抽象介面)   │              │
│  └──────────────┴──────────────┴──────────────┘              │
├──────────────────────────────────────────────────────────────┤
│                     Data Layer                                │
│  ┌────────────────┬─────────────────┬────────────────┐       │
│  │  Repositories  │  Remote Sources │ Local Sources  │       │
│  │  (實作層)       │  (API 呼叫)      │ (快取管理)      │       │
│  └────────────────┴─────────────────┴────────────────┘       │
├──────────────────────────────────────────────────────────────┤
│                    Core Layer                                 │
│  (工具/常數/擴充功能/依賴注入)                                   │
│  ┌──────────────┬──────────────┬──────────────┐              │
│  │  DI (get_it) │  Cache       │  Network     │              │
│  │  (依賴注入)   │  (快取策略)   │  (API 去重)   │              │
│  └──────────────┴──────────────┴──────────────┘              │
└──────────────────────────────────────────────────────────────┘
```

---

## 🗂️ 專案目錄結構

### 完整目錄樹

```
paceriz/
├── lib/
│   ├── core/                                  # 核心基礎建設
│   │   ├── di/                                # 依賴注入設定
│   │   ├── error/                             # 錯誤類型定義
│   │   ├── network/                           # 網路設定（Dio、API 去重）
│   │   ├── cache/                             # 快取策略協定
│   │   └── feature_gate/                      # 功能門控（IAP）
│   │
│   ├── data/                                   # 資料層
│   │   ├── models/                            # DTO（資料傳輸物件）
│   │   ├── datasources/                       # 資料來源
│   │   │   ├── remote/                        # 遠端資料來源（API）
│   │   │   └── local/                         # 本機資料來源（快取）
│   │   ├── repositories/                      # Repository 實作層
│   │   └── cache/                             # 快取管理器
│   │
│   ├── domain/                                 # 領域層
│   │   ├── entities/                          # 領域實體
│   │   ├── repositories/                      # Repository 抽象介面
│   │   └── usecases/                          # 用例（業務邏輯封裝）
│   │
│   └── presentation/                           # 展示層
│       ├── bloc/                              # 狀態管理（BLoC）
│       ├── pages/                             # 頁面
│       └── widgets/                           # 可重複使用元件
│
├── ios/                                        # iOS Native 程式碼
│   └── Runner/
│       ├── WatchDataBridge.swift              # Apple Watch 橋接
│       └── AppDelegate.swift
│
├── test/                                       # 測試目錄
│   ├── unit/                                  # 單元測試
│   └── integration/                           # 整合測試
│
├── pubspec.yaml                                # 依賴設定
└── README.md                                   # 專案說明
```

---

## 📚 層級職責詳解

### 1. Presentation Layer（展示層）

**職責**：
- UI 渲染（僅包含展示邏輯）
- 狀態訂閱（透過 BLoC）
- 使用者互動事件分發

**不負責**：
- ❌ 直接呼叫 API
- ❌ 處理業務邏輯
- ❌ 管理快取

**核心元件**：
- **Pages**：完整頁面（如運動列表頁、訓練計畫頁）
- **BLoCs**：狀態管理器，處理事件和狀態轉換
- **Widgets**：可重複使用的 UI 元件（如運動卡片、載入骨架）

**範例流程**：
1. 使用者下拉重新整理
2. 頁面觸發 BLoC 事件：`RefreshWorkouts`
3. BLoC 呼叫 UseCase
4. BLoC 接收結果，更新狀態
5. 頁面監聽狀態變化，重新渲染 UI

---

### 2. Domain Layer（領域層）

**職責**：
- 定義業務規則（與框架無關）
- 協調 Repository 呼叫
- 資料轉換（DTO → Entity）

**不負責**：
- ❌ 知道資料從何處來（API 或快取）
- ❌ 知道 UI 如何展示
- ❌ 依賴具體實作（只依賴抽象介面）

**核心元件**：
- **Entities**：領域實體（如 Workout、TrainingPlan、Subscription）
- **Use Cases**：業務邏輯封裝（如 GetWorkouts、GenerateWeeklyPlan）
- **Repositories（抽象）**：定義資料存取介面

**設計原則**：
- 領域層是整個架構的核心
- 完全獨立於框架和外部依賴
- 高度可測試（透過 Mock Repository）

---

### 3. Data Layer（資料層）

**職責**：
- 資料獲取（API/本機快取）
- 雙軌快取協調（立即顯示快取 + 背景重新整理）
- 錯誤處理和重試邏輯

**不負責**：
- ❌ 業務邏輯判斷
- ❌ UI 狀態管理

**核心元件**：
- **Models（DTO）**：資料傳輸物件，與後端 API 一致
- **Remote DataSource**：API 呼叫封裝
- **Local DataSource**：本機快取存取
- **Repository（實作）**：實作 Domain 層定義的介面

**雙軌快取策略**：
- **Track A**：立即回傳本機快取（同步）
- **Track B**：背景重新整理 API（非同步）

---

### 4. Core Layer（核心層）

**職責**：
- 依賴注入設定
- 統一快取策略
- API 去重機制
- 網路設定（Dio）

**不負責**：
- ❌ 業務邏輯
- ❌ UI 展示

**核心元件**：
- **依賴注入（get_it）**：管理所有物件的生命週期
- **快取策略**：統一的快取協定和實作
- **API 去重**：自動去除重複的 API 請求
- **網路設定**：Dio 攔截器、重試邏輯

---

## 🔄 資料流範例

### 範例 1：使用者下拉重新整理運動列表

```
使用者操作: 下拉螢幕
    ↓
Presentation Layer: WorkoutListPage
    ↓ 使用者互動
BLoC 接收事件: RefreshWorkouts
    ↓ 呼叫 UseCase
Domain Layer: GetWorkouts.execute(forceRefresh: true)
    ↓ 呼叫 Repository
WorkoutRepository.getWorkouts(forceRefresh: true)
    ↓
Data Layer: WorkoutRepositoryImpl
    ├─ Track A: 立即回傳快取（如果存在）
    │   ↓ 從 LocalDataSource 載入
    │   ↓ BLoC 更新狀態: WorkoutLoaded(cachedWorkouts)
    │   ↓ UI 渲染快取資料
    │
    └─ Track B: 背景重新整理 API
        ↓ API 去重檢查（避免重複請求）
        ↓ RemoteDataSource 發起 API 請求
        ↓ Dio 呼叫後端：GET /v2/workouts?limit=50
        ↓ 後端回傳 JSON
        ↓ 解析為 WorkoutDTO
        ↓ LocalDataSource 儲存到快取
        ↓ 轉換為 Workout Entity
        ↓ BLoC 更新狀態: WorkoutLoaded(freshWorkouts)
        ↓ UI 渲染最新資料
```

---

### 範例 2：功能門控檢查（HRV 趨勢）

```
使用者操作: 點擊 HRV 趨勢按鈕
    ↓
Presentation Layer: HRVTrendsPage
    ↓ 呼叫功能門控
Core Layer: FeatureGate.requirePremium(feature: HRVTrends)
    ↓ 呼叫 Repository
SubscriptionRepository.getStatus()
    ↓
Data Layer: SubscriptionRepositoryImpl
    ├─ 檢查本機快取（7天 TTL）
    │   ↓ LocalDataSource 載入訂閱狀態
    │   ↓ 有快取: 回傳 SubscriptionStatus
    │
    └─ 無快取: 呼叫 Firestore API
        ↓ Firestore.collection('subscriptions').doc(userId).get()
        ↓ 解析為 SubscriptionDTO
        ↓ LocalDataSource 儲存到快取
        ↓ 回傳 SubscriptionStatus
    ↓
FeatureGate: 判斷 status.isPremium?
    ├─ YES: 通過檢查，進入功能頁面
    └─ NO: 拋出 FeatureLockedError
        ↓ 捕捉錯誤
        ↓ 顯示 PremiumUpgradeDialog
        ↓ 使用者點擊 "升級"
        ↓ 導航到訂閱頁面
```

---

## 🔗 依賴注入策略

### 使用 get_it + injectable

**核心概念**：
- **Service Locator 模式**：全域單例容器
- **自動註冊**：透過 injectable 套件自動生成註冊程式碼
- **生命週期管理**：Singleton、LazySingleton、Factory

**註冊類型**：

1. **Singleton**：整個應用程式生命週期只有一個實例
   - 範例：Dio、APIDeduplicationManager、FeatureGate

2. **LazySingleton**：第一次使用時建立，之後重複使用
   - 範例：WorkoutRepository、TrainingPlanRepository

3. **Factory**：每次使用都建立新實例
   - 範例：UseCase（GetWorkouts、RefreshWorkouts）

**依賴注入流程**：
1. 定義介面和實作
2. 使用 @injectable 標記需要註冊的類別
3. 執行程式碼生成：`flutter pub run build_runner build`
4. 在應用程式啟動時初始化容器
5. 在需要時從容器取得實例

---

## 📋 檔案結構和職責對照表

### Flutter ↔ Swift 檔案對照

| Flutter 檔案 | Swift 參考檔案 | 職責 |
|-------------|---------------|------|
| `lib/core/cache/cache_strategy.dart` | `Utils/BaseCacheManagerTemplate.swift` | 統一快取協定 |
| `lib/core/network/api_deduplication.dart` | `Services/Protocols/DeduplicatedAPIService.swift` | API 去重模式 |
| `lib/data/models/workout_v2_dto.dart` | `Models/WorkoutV2Models.swift` | 資料模型結構 |
| `lib/data/repositories/workout_repository_impl.dart` | `Managers/UnifiedWorkoutManager.swift` | 雙軌快取參考 |
| `lib/domain/usecases/get_workouts.dart` | `ViewModels/TrainingRecordViewModel.swift` | 業務邏輯 |
| `lib/presentation/bloc/workout/workout_bloc.dart` | `ViewModels/TrainingRecordViewModel.swift` | 狀態管理 |
| `lib/core/feature_gate/feature_gate.dart` | `Managers/FeatureFlagManager.swift` | 功能門控擴充 |
| `ios/Runner/WatchDataBridge.swift` | `Managers/HealthKitManager.swift` | HealthKit 橋接 |

---

## 🧪 測試策略

### 單元測試

**測試範圍**：
- Domain Layer：Use Cases 業務邏輯
- Data Layer：Repository 實作、資料來源
- Core Layer：工具函式、快取策略

**測試重點**：
- 業務邏輯正確性
- 錯誤處理
- 邊界條件

### BLoC 測試

**測試範圍**：
- 事件處理邏輯
- 狀態轉換順序
- 錯誤狀態處理

**測試工具**：
- `bloc_test` 套件
- `mockito` for Mock

### 整合測試

**測試範圍**：
- 完整使用者流程
- 多層協作
- API 呼叫整合

---

## 🔑 關鍵架構原則

### 1. 依賴倒置原則（DIP）

**核心概念**：高層模組不依賴低層模組，兩者都依賴抽象。

**實踐方式**：
- Domain Layer 只依賴抽象介面（Repository）
- Data Layer 實作這些介面
- 透過依賴注入容器連接

**優勢**：
- 易於測試（可以 Mock Repository）
- 易於替換實作（如切換資料來源）

---

### 2. 單一職責原則（SRP）

**核心概念**：每個類別只負責一件事。

**實踐方式**：
- Remote DataSource 只負責 API 呼叫
- Local DataSource 只負責本機儲存
- Repository 負責協調兩者
- UseCase 負責業務邏輯

**優勢**：
- 程式碼易讀
- 易於維護
- 降低耦合度

---

### 3. 開閉原則（OCP）

**核心概念**：對擴充開放，對修改封閉。

**實踐方式**：
- 使用抽象基底類別（如 TrainingPlan）
- 透過繼承擴充新功能（如 CyclingTrainingPlan）
- 不修改現有程式碼

**優勢**：
- 新增功能不影響現有功能
- 降低迴歸風險

---

## 📚 參考資料

- [Clean Architecture (Robert C. Martin)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter BLoC Documentation](https://bloclibrary.dev/)
- [Reso Coder Flutter Clean Architecture](https://resocoder.com/flutter-clean-architecture-tdd/)
- [Very Good Ventures 架構指南](https://verygood.ventures/blog/very-good-flutter-architecture)

---

**文檔版本**：v1.0
**建立日期**：2025-12-29
**負責人**：開發團隊
