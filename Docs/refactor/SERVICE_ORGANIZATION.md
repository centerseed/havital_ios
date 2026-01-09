# Services 目錄結構說明

## 目錄組織

```
Services/
├── Core/                    # 核心基礎設施
│   ├── HTTPClient.swift
│   ├── APIParser.swift
│   ├── DeduplicatedAPIService.swift
│   ├── SafeNumber.swift
│   └── UnifiedAPIResponse.swift
│
├── Integrations/            # 第三方整合服務
│   ├── Garmin/
│   │   ├── GarminService.swift
│   │   ├── GarminConnectionStatusService.swift
│   │   └── GarminDisconnectService.swift
│   ├── Strava/
│   │   ├── StravaService.swift
│   │   ├── StravaConnectionStatusService.swift
│   │   ├── StravaDisconnectService.swift
│   │   └── StravaPKCEStorageService.swift
│   └── AppleHealth/
│       ├── AppleHealthWorkoutUploadService.swift
│       └── HealthDataService.swift
│
├── Authentication/          # 認證相關服務
│   ├── AuthenticationService.swift
│   └── EmailAuthService.swift
│
├── Utilities/               # 工具服務
│   ├── BackfillService.swift
│   ├── FeedbackService.swift
│   ├── FirebaseLoggingService.swift
│   ├── PhotoAnalyzer.swift
│   ├── TrainingLoadDataManager.swift
│   ├── TrainingReadinessService.swift
│   ├── UserPreferencesService.swift
│   ├── VDOTService.swift
│   ├── WeekDateService.swift
│   ├── WeeklySummaryService.swift
│   └── WorkoutBackgroundUploader.swift
│
├── Deprecated/              # ⚠️ 已棄用的服務
│   ├── UserService.swift (部分 deprecated)
│   └── WorkoutV2Service.swift (部分 deprecated)
│
└── (根目錄 - 配置文件)
    ├── APIClient.swift      # Legacy wrapper
    ├── APIConfig.swift
    └── Schemas.swift
```

---

## 使用指南

### Core/
**核心網路和解析基礎設施，所有 API 服務的基礎**

- `HTTPClient.swift` - HTTP 請求客戶端
- `APIParser.swift` - JSON 解析器
- `UnifiedAPIResponse.swift` - 統一 API 響應格式

**✅ 保留使用**: 這些是基礎設施，所有 RemoteDataSource 都應該使用

---

### Integrations/
**第三方平台整合服務**

#### Garmin/
- Garmin Connect OAuth 認證和連接
- 數據同步狀態檢查
- 帳號解綁功能

#### Strava/
- Strava OAuth 2.0 with PKCE 認證
- 數據同步狀態檢查
- 帳號解綁功能
- PKCE 參數存儲

#### AppleHealth/
- Apple Health 數據上傳
- HealthKit 數據讀取和同步

**✅ 使用場景**: 需要與第三方平台整合時使用

---

### Authentication/
**用戶認證服務**

- `AuthenticationService.swift` - Firebase 認證、Google 登入、用戶狀態管理
- `EmailAuthService.swift` - Email/密碼認證

**✅ 使用場景**: 登入、登出、認證狀態檢查

---

### Utilities/
**各種工具和輔助服務**

| 服務 | 用途 |
|------|------|
| BackfillService | 歷史數據回填 |
| FeedbackService | 用戶反饋提交 |
| FirebaseLoggingService | Firebase 日誌記錄 |
| PhotoAnalyzer | 照片分析工具 |
| TrainingLoadDataManager | 訓練負荷數據管理 |
| TrainingReadinessService | 訓練準備度評估 |
| UserPreferencesService | 用戶偏好設定 |
| VDOTService | VDOT 計算服務 |
| WeekDateService | 週次日期計算 |
| WeeklySummaryService | 週次總結服務 |
| WorkoutBackgroundUploader | 背景訓練上傳 |

**⚠️ 未來計劃**: 這些服務將逐步遷移到對應的 Feature Module

---

### Deprecated/
**⚠️ 已標記為棄用的服務**

| 服務 | 狀態 | 遷移路徑 |
|------|------|---------|
| UserService.swift | 部分 deprecated | → UserProfileRepository |
| WorkoutV2Service.swift | 部分 deprecated | → WorkoutRepository |

**❌ 請勿使用**: 這些服務的主要功能已遷移到 Clean Architecture
**📝 遷移指南**: 查看文件頂部的註解獲取遷移說明

---

## Clean Architecture 遷移狀態

### 已遷移 ✅
- Target 管理 → `Features/Target/`
- TrainingPlan 管理 → `Features/TrainingPlan/`
- Workout 核心功能 → `Features/Workout/`
- UserProfile 核心功能 → `Features/UserProfile/`

### 進行中 ⚠️
- Authentication → 考慮移至 `Features/Authentication/`
- Utilities → 逐步移至對應 Feature Module

### 計劃中 📌
- 最終目標: Services/ 只保留 Core/ 基礎設施
- 所有業務邏輯服務移至 Features/

---

## 開發規範

### 新增服務時
1. **優先使用 Repository Pattern** - 不要直接創建 Service
2. **遵循 Clean Architecture** - Service 只應處理基礎設施層
3. **放置位置原則**:
   - 網路/解析基礎設施 → `Services/Core/`
   - 第三方整合 → `Services/Integrations/[Platform]/`
   - 業務邏輯 → `Features/[Module]/Infrastructure/` (不是 Services/)

### 使用現有服務時
1. 檢查是否已標記 `@available(*, deprecated)`
2. 查看文件頂部註解的遷移指南
3. 優先使用 Repository 而非直接調用 Service

---

**最後更新**: 2026-01-07
**重組版本**: Phase 1 - 漸進式重組
**下一步**: Phase 2 - 完全遷移至 Clean Architecture
