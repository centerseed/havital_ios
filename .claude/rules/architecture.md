# Architecture Rules — Paceriz iOS

## 四層依賴方向（NEVER violate）
```
Presentation → Domain → Data → Core
```
依賴永遠向內，內層不知道外層存在。

## 每層的禁止事項

| Layer | FORBIDDEN |
|-------|-----------|
| Presentation (Views, ViewModels) | 業務邏輯、直接 API 調用、直接 DB 存取 |
| Domain (Entities, Protocols) | 依賴外層、依賴具體實作 |
| Data (RepositoryImpl, DTOs, Mappers) | 業務邏輯、UI 狀態管理 |
| Core (HTTPClient, Cache, Logger) | 業務邏輯、UI 相關程式碼 |

## 關鍵約束

### Repository Pattern
- ViewModel 依賴 **Protocol**（Domain Layer），NEVER 依賴具體 RepositoryImpl
- **Repository 是被動的**: NEVER 發布或訂閱 CacheEventBus 事件

### DTO vs Entity
- DTO 在 Data Layer，對應 API JSON（snake_case + CodingKeys）
- Entity 在 Domain Layer，純業務模型（camelCase）
- 用 Mapper 轉換，NEVER 讓 Entity 出現 Codable

### CacheEventBus
- 取代 `NotificationCenter.default`（違反依賴反轉）
- 發布者: ViewModels、Managers/Services
- 訂閱者: ViewModels、Managers/Services
- FORBIDDEN: Repository/DataSource 參與事件流

### Dual-Track Caching（RepositoryImpl 負責）
- Track A: 立即返回本地快取
- Track B: 背景 API 重新整理
- 特殊場景（logout/onboarding）: 清快取 → 強制 API 重載

### 數據流方向
```
CORRECT:  HealthKit → Backend API → WorkoutV2 Models → UI
FORBIDDEN: HealthKit → UI（繞過後端）
```

### DI 生命週期
- Singleton: HTTPClient, Logger, DataSource, Mapper, RepositoryImpl
- Factory（每次新建）: ViewModel
