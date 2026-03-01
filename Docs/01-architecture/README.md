# Paceriz iOS App - Clean Architecture 架構文檔

**版本**: 1.1
**最後更新**: 2026-01-03
**狀態**: ✅ TrainingPlan Feature 已實現 Clean Architecture

---

## 文檔目錄

本目錄包含 Paceriz iOS App 向 Clean Architecture 遷移的完整規劃文檔，基於 Flutter 版本的架構設計原則和 iOS/Swift 最佳實踐。

### 核心架構文檔

1. **[ARCH-001: 現狀分析](./ARCH-001-Current-State-Analysis.md)**
   - 當前架構層級結構
   - 與 Clean Architecture 的對比
   - 優勢與問題識別
   - 符合度評估 (56%)

2. **[ARCH-002: Clean Architecture 設計](./ARCH-002-Clean-Architecture-Design.md)**
   - 目標架構分層 (Presentation → Domain → Data → Core)
   - Repository Pattern 實作
   - Dependency Injection 策略
   - 統一狀態管理系統

3. **[ARCH-003: 遷移路線圖](./ARCH-003-Migration-Roadmap.md)**
   - Week 3: Repository Pattern 實作
   - Week 4: 統一狀態管理
   - Week 5: 錯誤處理標準化
   - Week 6: UseCase Layer (可選)

4. **[ARCH-004: 資料流設計](./ARCH-004-Data-Flow.md)**
   - 完整數據流 (App 啟動 → 課表載入)
   - 雙軌緩存系統實作細節
   - API 調用追蹤機制
   - 時序圖與流程圖

5. **[ARCH-005: TrainingPlan 參考實現](./ARCH-005-TrainingPlan-Reference-Implementation.md)** ✅ NEW
   - Clean Architecture 完整實現範例
   - Repository Pattern + Use Case 模式
   - 依賴注入最佳實踐
   - 其他 Feature 重構檢查清單

---

## 架構設計原則

### Clean Architecture 核心概念

```
┌─────────────────────────────────────────────────────────┐
│                   Presentation Layer                     │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐                │
│  │  Views  │  │ViewModels│ │ ViewState│                │
│  └────┬────┘  └────┬─────┘  └──────────┘                │
│       │            │                                      │
│       └────────────┼──────────────────────────────────────┤
│                    ▼                                      │
│                 Domain Layer                              │
│  ┌─────────┐  ┌──────────┐  ┌────────────────┐          │
│  │ Entities│  │ UseCases │  │ Repository     │          │
│  │         │  │          │  │ (Protocol)     │          │
│  └─────────┘  └─────┬────┘  └───────┬────────┘          │
│                     │                │                    │
├─────────────────────┼────────────────┼────────────────────┤
│                     ▼                ▼                    │
│                  Data Layer                               │
│  ┌─────────────┐  ┌──────────────────────┐               │
│  │    DTOs     │  │ Repository (Impl)    │               │
│  │             │  │  ├── Remote Source   │               │
│  └─────────────┘  │  └── Local Source    │               │
│                   └──────────────────────┘               │
├──────────────────────────────────────────────────────────┤
│                   Core Layer                              │
│  ┌─────────┐  ┌─────────┐  ┌──────┐  ┌────────┐         │
│  │ Network │  │  Cache  │  │  DI  │  │ Utils  │         │
│  └─────────┘  └─────────┘  └──────┘  └────────┘         │
└──────────────────────────────────────────────────────────┘
```

**依賴方向**: 外層依賴內層，內層不知道外層的存在
- Presentation → Domain → Data → Core
- Domain 層通過 Protocol 反轉依賴（Repository Protocol）

### 與 Flutter 版本的對應關係

| Flutter 層級 | iOS 層級 | 對應元件 |
|-------------|---------|---------|
| **Presentation** | Presentation | SwiftUI Views, ViewModels |
| **Domain** | Domain | Entities, UseCases, Repository Protocols |
| **Data** | Data | DTOs, Repository Implementations, DataSources |
| **Core** | Core | HTTPClient, UnifiedCacheManager, DI |

---

## 當前架構優勢

### 1. 雙軌緩存系統 (90% 符合 Clean Architecture)
- **Track A**: 立即顯示緩存內容
- **Track B**: 背景刷新最新數據
- 已在 UserPreferencesManager, TrainingPlanStorage 等組件中實作

### 2. UnifiedCacheManager (100% 符合)
- 泛型設計支援任意 Codable 類型
- TTL 策略完整 (.realtime, .shortTerm, .mediumTerm, .longTerm, .weekly, .permanent)
- MultiKeyCacheManager 支援帶後綴的多鍵緩存

### 3. API 調用追蹤系統
- `.tracked(from: "ViewName: functionName")` 語法
- 完整的調用鏈追蹤與日誌記錄

---

## 主要改進方向

### 🔥 高優先級

#### 1. 引入 Repository Pattern + Dependency Inversion
**問題**: ViewModels 直接依賴具體的 Service 實作
```swift
// ❌ 當前寫法
class TrainingPlanViewModel {
    private let service = TrainingPlanService.shared  // 具體依賴
}
```

**目標**: 依賴 Repository Protocol
```swift
// ✅ 目標寫法
class TrainingPlanViewModel {
    private let repository: TrainingPlanRepository  // Protocol 依賴
}
```

#### 2. 統一狀態管理
**問題**: 多個 @Published 屬性，狀態分散
```swift
// ❌ 當前寫法
@Published var isLoading = false
@Published var weeklyPlan: WeeklyPlan?
@Published var error: Error?
```

**目標**: 單一狀態枚舉
```swift
// ✅ 目標寫法
@Published var state: ViewState<WeeklyPlan> = .loading

enum ViewState<T> {
    case loading
    case loaded(T)
    case error(Error)
}
```

### ⚠️ 中優先級

#### 3. 錯誤處理標準化
**目標**: 使用 Result 或自定義 Either 類型明確處理錯誤
```swift
// ✅ 目標寫法
func getWeeklyPlan() async -> Result<WeeklyPlan, DomainError>
```

### ℹ️ 低優先級 (可選)

#### 4. UseCase Layer
將複雜業務邏輯封裝為可組合的 UseCase

---

## 遷移時間表

| 週次 | 任務 | 優先級 | 預估工作量 |
|-----|------|--------|-----------|
| Week 3 | Repository Pattern 實作 | 🔥 High | 3-5 天 |
| Week 4 | 統一狀態管理 | 🔥 High | 2-3 天 |
| Week 5 | 錯誤處理標準化 | ⚠️ Medium | 2-3 天 |
| Week 6 | UseCase Layer (可選) | ℹ️ Low | 1-2 天 |

---

## 設計原則

### 1. 保留優勢，漸進改進
- **保留**: 雙軌緩存系統、UnifiedCacheManager、API 追蹤
- **改進**: 引入 Domain 層、Repository Pattern、統一狀態管理

### 2. 依賴反轉原則 (DIP)
- Domain 層定義 Repository Protocol
- Data 層實作 Repository Protocol
- Presentation 層依賴 Repository Protocol

### 3. 單一職責原則 (SRP)
- **ViewModel**: 僅處理 UI 狀態轉換
- **Repository**: 僅協調資料來源
- **DataSource**: 僅負責資料獲取 (API 或本地)
- **UseCase**: 僅封裝單一業務流程

### 4. 開放封閉原則 (OCP)
- 新增資料來源不修改 Repository Protocol
- 新增狀態類型不修改基礎架構
- 新增緩存策略不修改 Data Layer

---

## 測試策略

### 單元測試
- **Domain Layer**: UseCase 業務邏輯測試 (覆蓋率 > 90%)
- **Data Layer**: Repository 和 DataSource 測試 (覆蓋率 > 80%)
- **Presentation Layer**: ViewModel 狀態轉換測試 (覆蓋率 > 80%)

### 整合測試
- 完整使用者流程測試
- Mock API 整合測試

---

## 下一步

1. ✅ 完成架構現狀分析 (ARCH-001)
2. ✅ 設計 Clean Architecture 目標架構 (ARCH-002)
3. ✅ 制定遷移路線圖 (ARCH-003)
4. ✅ **TrainingPlan Feature 完整實現** (ARCH-005)
   - Repository Pattern
   - Use Case 模式
   - 依賴注入
5. 🔄 其他 Feature 重構（參考 ARCH-005）
   - UserProfile Feature
   - Workout Feature
   - Settings Feature

---

**文檔版本**: 1.1
**撰寫日期**: 2026-01-03
**基於**: Flutter Clean Architecture + iOS 最佳實踐
