# Service 目錄重組計劃

## 當前狀況分析

### Services/ 目錄內容分類

**Core Infrastructure (✅ 位置正確)**
```
Services/Core/
├── HTTPClient.swift
├── APIParser.swift
├── DeduplicatedAPIService.swift
├── SafeNumber.swift
└── UnifiedAPIResponse.swift
```

**API Configuration (✅ 保留)**
```
Services/
├── APIClient.swift (legacy wrapper)
├── APIConfig.swift
└── Schemas.swift
```

**已標記 Deprecated (⚠️ 部分功能已遷移)**
```
Services/
├── UserService.swift (部分 deprecated)
└── WorkoutV2Service.swift (部分 deprecated)
```

**第三方整合服務 (📦 建議分類)**
```
Services/
├── Garmin/
│   ├── GarminService.swift
│   ├── GarminConnectionStatusService.swift
│   └── GarminDisconnectService.swift
├── Strava/
│   ├── StravaService.swift
│   ├── StravaConnectionStatusService.swift
│   ├── StravaDisconnectService.swift
│   └── StravaPKCEStorageService.swift
└── AppleHealth/
    ├── AppleHealthWorkoutUploadService.swift
    └── HealthDataService.swift
```

**認證服務 (🔐 獨立分類)**
```
Services/Authentication/
├── AuthenticationService.swift
└── EmailAuthService.swift
```

**工具服務 (🔧 按功能分類)**
```
Services/Utilities/
├── BackfillService.swift
├── FeedbackService.swift
├── FirebaseLoggingService.swift
├── PhotoAnalyzer.swift
├── TrainingLoadDataManager.swift
├── TrainingReadinessService.swift
├── UserPreferencesService.swift
├── VDOTService.swift
├── WeekDateService.swift
├── WeeklySummaryService.swift
└── WorkoutBackgroundUploader.swift
```

---

## 重組方案：漸進式重組 (Phase 1)

### 目標
1. 改善目錄組織，清晰分類
2. 最小化 import 語句修改
3. 保持 Build 穩定

### 執行步驟

#### Step 1: 創建子目錄分類 (保持在 Services/ 下)

```
Services/
├── Core/ (保持)
├── Integrations/
│   ├── Garmin/
│   ├── Strava/
│   └── AppleHealth/
├── Authentication/
├── Utilities/
├── Deprecated/
│   ├── UserService.swift
│   └── WorkoutV2Service.swift
└── (配置文件保持根目錄)
```

#### Step 2: 移動文件到子目錄

**Integrations/**
- Move: Garmin*, Strava*, AppleHealth*, HealthData*

**Authentication/**
- Move: AuthenticationService, EmailAuthService

**Utilities/**
- Move: Backfill, Feedback, Firebase, Photo, Training*, User Preferences, VDOT, Week*, Workout Background

**Deprecated/**
- Move: UserService, WorkoutV2Service (標記為 deprecated)

#### Step 3: 添加 README 文檔

為每個子目錄添加 README.md 說明用途和遷移指引。

---

## 未來計劃 (Phase 2 - 長期)

### 最終目標架構

```
Havital/
├── Core/
│   └── Infrastructure/
│       ├── Network/ (from Services/Core/)
│       ├── Integrations/ (from Services/Integrations/)
│       └── Authentication/ (from Services/Authentication/)
├── Features/
│   ├── Workout/
│   │   └── Infrastructure/
│   │       └── (Workout-related services)
│   ├── TrainingPlan/
│   │   └── Infrastructure/
│   │       └── (Training-related services)
│   └── UserProfile/
│       └── Infrastructure/
│           └── (User-related services)
└── Services/ (最終只保留 Core/)
```

---

## 預期成果

### Phase 1 (本次執行)
- ✅ Services 目錄內部組織清晰
- ✅ 相關服務集中管理
- ✅ Deprecated 服務明確標記
- ✅ 保持 Build 穩定
- ⚠️ Import 語句需小幅修改

### Phase 2 (未來)
- 📌 完全遵循 Clean Architecture
- 📌 服務移至對應 Feature Module
- 📌 移除 Services/ 目錄（只保留 Core/）

---

## 執行檢查清單

- [ ] 創建子目錄結構
- [ ] 移動 Integration 相關文件
- [ ] 移動 Authentication 相關文件
- [ ] 移動 Utility 相關文件
- [ ] 移動 Deprecated 文件
- [ ] 更新 import 語句
- [ ] 添加 README 文檔
- [ ] 驗證 Build 成功
- [ ] 更新文檔

---

**優先級**: Medium
**風險級別**: Low (只是目錄重組，不改變代碼邏輯)
**預計時間**: 1-2 小時
