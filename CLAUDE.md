# Paceriz iOS App - AI 開發指引

## 專案概述
Paceriz 是一個健身追蹤應用，支援 Apple Health 和 Garmin Connect 整合。

**命名規則**: 產品名稱為 **Paceriz**，技術識別碼保持 `com.havital.*`（App Store 延續性）。目錄名稱保持 `Havital`，但所有使用者介面文字使用 **Paceriz**。

## Clean Architecture 核心原則（最高優先級）

### 四層架構依賴方向
```
Presentation Layer → Domain Layer → Data Layer → Core Layer
```
**核心規則**: 依賴永遠向內，內層不知道外層的存在。

### 各層職責

**Presentation Layer (呈現層)**
- 職責: UI 渲染、使用者互動、狀態綁定
- 組件: Views (SwiftUI)、ViewModels、ViewState enums
- 禁止: 業務邏輯、直接 API 調用、直接數據庫存取

**Domain Layer (領域層)**
- 職責: 業務實體定義、業務規則、數據存取介面定義
- 組件: Entities、Repository Protocols、UseCases（可選）
- 禁止: 依賴外層、依賴實作細節
- 原則: 定義「做什麼」，不定義「怎麼做」

**Data Layer (數據層)**
- 職責: Repository 實作、API 調用、快取管理、DTO ↔ Entity 轉換
- 組件: RepositoryImpl、RemoteDataSource、LocalDataSource、DTOs、Mappers
- 禁止: 業務邏輯、UI 狀態管理
- 原則: 實現雙軌快取策略，協調遠端與本地資料來源

**Core Layer (核心層)**
- 職責: 網路通訊、快取基礎設施、事件系統、依賴注入、工具函式
- 組件: HTTPClient、UnifiedCacheManager、CacheEventBus、DependencyContainer、Logger
- 禁止: 業務邏輯、UI 相關程式碼

### 關鍵設計模式

**1. Repository Pattern**
- Domain Layer 定義 Repository Protocol（介面）
- Data Layer 實作 RepositoryImpl（具體實現）
- ViewModel 依賴 Protocol，不依賴具體實作
- 符合依賴反轉原則

**2. ViewState Enum Pattern**
- 使用泛型 `ViewState<T>` 統一管理 UI 狀態
- 狀態類型: `.loading`、`.loaded(data)`、`.error(error)`、`.empty`
- 取代多個散亂的 `@Published` 屬性

**3. Dual-Track Caching Strategy**

**正常載入場景**:
- Track A: 立即返回本地快取（快速顯示）
- Track B: 背景重新整理 API 資料（保持新鮮）

**特殊重新整理場景**（如 Onboarding 完成、使用者登出）:
- 清除所有快取
- 強制從 API 重新載入

**實現位置**: Data Layer 的 RepositoryImpl 負責協調兩個 Track

**4. CacheEventBus（事件通訊系統）**

**核心價值**:
- 避免直接使用 `NotificationCenter.default`（違反依賴反轉原則）
- 各層依賴抽象事件協議，而非具體通知系統
- 支援雙軌快取的特殊場景處理

**事件類型範例**: `.userLogout`、`.trainingPlanUpdated`、`.onboardingCompleted`

**發布者與訂閱者規則**:
- 執行業務操作的層級負責發布相應事件
- 需要更新狀態的組件訂閱相關事件
- **Repository 是被動的**: Repository 層永遠不發布事件，也不訂閱事件
- 訂閱者: Presentation Layer (ViewModels)、Domain/Data Layer (Managers/Services)
- 發布者: Presentation Layer (Coordinators/ViewModels)、Domain/Data Layer (Services/Managers)
- 禁止: Repository/DataSource 參與事件流

**5. Dependency Injection**
- Core Layer: HTTPClient、Logger（Singleton）
- Data Layer: DataSource、Mapper、RepositoryImpl（Singleton）
- Presentation Layer: ViewModel（Factory，每次創建新實例）
- ViewModel 依賴 Repository Protocol，不依賴具體實作
- 所有依賴透過建構子注入

### 數據流向

**標準數據流**:
```
User Interaction → ViewModel → Repository Protocol → RepositoryImpl
  → LocalDataSource (Track A) + RemoteDataSource (Track B)
  → HTTPClient → API Response → DTO → Mapper → Entity
  → ViewModel.state = .loaded → View Re-render
```

**事件驅動流**:
```
Business Event → CacheEventBus.publish
  → ViewModel subscribes → clearCache() + forceRefresh()
  → Repository.clearAllCache() → Repository.forceRefreshFromAPI()
  → ViewModel.state = .loaded → View Re-render
```

### DTO vs Entity

**DTO (Data Transfer Object)**:
- 位置: Data Layer
- 與 API JSON 結構一一對應
- 使用 snake_case 命名（與後端一致）
- 包含 `CodingKeys` 進行鍵名轉換

**Entity (Domain Model)**:
- 位置: Domain Layer
- 純粹的業務模型
- 使用 camelCase 命名（Swift 慣例）
- 包含業務邏輯方法
- 只包含業務需要的欄位

**Mapper (轉換器)**:
- 位置: Data Layer
- 負責 DTO ↔ Entity 雙向轉換
- 處理數據類型轉換（如 Unix timestamp → Date）

### 錯誤處理策略

**Domain Layer 定義錯誤類型**:
- `DomainError` 枚舉定義所有業務級錯誤
- 提供使用者友好的錯誤訊息（LocalizedError）
- 明確的錯誤分類: `.networkFailure`、`.serverFailure`、`.cacheFailure`、`.authFailure`、`.validationFailure`

**Error 轉換流程**:
```
API Error → Data Layer catches → Convert to DomainError
  → Throw to ViewModel → ViewModel.state = .error
  → View displays ErrorView
```

## 開發原則

### 1. 驗證優先原則（CRITICAL）

**除錯 UI 顯示問題的系統化方法**:
1. 使用者回饋是真相 - 如果使用者說「你改錯 view」，立即停止並驗證
2. 使用工具找出所有可能性 - 不要假設哪個 view 負責
3. 證據優於直覺 - 如果日誌沒有出現，該 view 就不是問題所在

**必要步驟**:
- 使用 grep 找出所有顯示該資料的 views
- 檢查哪些 views 實際用於受影響的畫面
- 使用日誌或斷點驗證
- 只有在驗證之後才進行修改

**關鍵規則**: 當使用者質疑你的方法時，視為紅旗 - 停止、驗證所有假設、然後繼續。

### 2. 數據流架構

**正確的 API-First 模式**:
```
User Authentication → Backend API → Local Storage → UI Updates
```

**禁止**: HealthKit → UI（繞過後端）
**必須**: HealthKit → Backend API → WorkoutV2 Models → UI

### 3. 任務管理

**TaskManageable Protocol**:
- 所有 ViewModels 和 Managers 實作 TaskManageable
- 使用 TaskRegistry 管理 async tasks
- 在 deinit 中 cancelAllTasks

**取消錯誤處理**:
- 檢查 NSURLErrorCancelled 並忽略
- 不要為取消的任務更新 UI 狀態
- 只處理真實錯誤

**任務命名**:
- 使用唯一的 TaskID，包含參數（如 `TaskID("load_weekly_plan_\(week)")`）
- 背景任務明確標記（如 `TaskID("background_refresh_overview")`）

### 4. 初始化順序

**嚴格順序**:
```
App Launch → User Authentication → User Data Loading
  → Training Overview → Weekly Plan → UI Ready
```

**規則**:
- ViewModel 初始化前等待使用者認證完成
- 避免在資料準備好之前初始化

### 5. API 調用追蹤

**使用鏈式調用 `.tracked(from:)`**:
- 格式: `tracked(from: "ViewName: functionName")`
- 精確記錄 API 調用來源
- 適用場景: Button 點擊、.refreshable、私有函數中的 Task、Callback 閉包

**日誌會自動記錄**:
```
📱 [API Call] ViewName: functionName → GET /endpoint
✅ [API End] ViewName: functionName → GET /endpoint | 200 | 0.34s
```

### 6. Dictionary 安全性

**禁止**:
- Date 物件作為 Dictionary keys（會導致崩潰）
- 混合 key 類型

**必須**:
- 使用 TimeInterval 作為 keys
- 使用 TaskID 進行任務管理

## 技術實踐

### ViewState 管理
- 使用 `ViewState<T>` enum 統一管理 UI 狀態
- `.error` 狀態只用於可操作的錯誤
- 不要為取消的任務設定 `.error`

### 雙軌快取實現
- Track A: 立即顯示快取（同步）
- Track B: 背景更新（使用 `Task.detached`）
- 背景更新失敗不影響已顯示的快取

### 日誌策略
- 為 async 操作添加全面的日誌
- 追蹤錯誤上下文
- 使用 Logger.debug、Logger.error
- 記錄 API 調用、planId、成功/失敗狀態

### API 層職責
- **HTTPClient**: HTTP 通信、認證、網路錯誤
- **Service**: API 調用包裝、業務錯誤處理
- **Manager**: 快取策略、業務邏輯協調
- **Repository**: 數據存取協調（被動，不發布/訂閱事件）

## 開發檢查清單

### 新功能開發
- [ ] ViewModel 使用 `@MainActor` 標記（自動確保 UI 狀態更新在主線程）
- [ ] ViewModel 只依賴 Repository Protocol，不依賴具體實作
- [ ] View 不包含業務邏輯，只負責渲染和使用者輸入
- [ ] Repository Protocol 定義在 Domain Layer
- [ ] RepositoryImpl 實作在 Data Layer，實現雙軌快取
- [ ] DTO 定義在 Data Layer，Entity 定義在 Domain Layer
- [ ] 使用 Mapper 進行 DTO ↔ Entity 轉換
- [ ] 錯誤處理統一轉換為 DomainError
- [ ] ViewState enum 管理 UI 狀態
- [ ] 特殊事件使用 CacheEventBus 通知
- [ ] 所有依賴透過 DependencyContainer 注入
- [ ] 所有 async closures 使用 `[weak self]`

### 程式碼審查要點
- [ ] 沒有 Date 物件作為 Dictionary keys
- [ ] 所有 TaskManageable 類別處理取消錯誤
- [ ] 初始化等待使用者資料就緒
- [ ] ErrorView 只顯示可操作的錯誤
- [ ] 全面的日誌記錄用於除錯

### 測試指令
```bash
# Clean build
cd "/Users/wubaizong/havital/apps/ios/Havital"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 16'

# 搜尋崩潰模式
grep -r "Dictionary.*Date" Havital/ --include="*.swift"
grep -r "catch.*{" Havital/ --include="*.swift" | grep -v "cancelled"
```

### 執行時驗證
1. 測試初始化競爭條件: 多次終止並重啟 app
2. 驗證 ErrorView 觸發: 只應出現於網路/API 錯誤
3. 檢查任務取消: 監控日誌以確保正確處理取消
4. 驗證資料流: User auth → Training overview → Weekly plan 順序

## 常見反模式

### ⚠️ 多重初始化路徑
**症狀**: 多個初始化方法衝突
**解決方案**: 單一初始化路徑，正確排序

### ⚠️ 取消任務顯示 ErrorView
**症狀**: 成功載入資料後使用者看到錯誤畫面
**解決方案**: 在更新 UI 狀態之前過濾取消錯誤

### ⚠️ 資料載入競爭條件
**症狀**: 任務執行順序錯亂，導致狀態不一致
**解決方案**: 使用 TaskRegistry 防止重複執行 + 正確的依賴管理

## 架構成功指標
- **零 Dictionary 崩潰報告**: 沒有 `removeValue` 失敗
- **正確的錯誤顯示**: ErrorView 只用於可操作的錯誤
- **初始化可靠性**: 不論時間如何都能一致載入資料
- **任務管理效率**: 沒有未取消任務的記憶體洩漏

---

**核心原則**: 每個 async 操作都必須優雅地處理取消，並維持正確的 UI 狀態轉換。

**詳細設計文檔**: 參見 `Docs/01-architecture/ARCH-002-Clean-Architecture-Design.md`
