# 當前架構問題分析

## 概覽

**Clean Architecture 符合度：56%**

| 層級 | 當前 | 目標 | 差距 |
|------|------|------|------|
| Presentation | 80% | 95% | ViewState 統一 |
| Domain | 0% | 90% | 完全缺失 |
| Data | 60% | 90% | Repository 模式 |
| Core | 90% | 95% | DI Container |

---

## 1. God Objects (嚴重)

### UserManager (648 行, 7+ 職責)

**現有職責：**
- 用戶 Profile CRUD
- 認證狀態管理
- 心率區間載入
- Target 管理
- 統計計算
- Personal Best 追蹤
- 快取協調

**問題：**
- 違反單一職責原則
- 依賴 5+ 其他 Manager
- 難以測試

**應拆分為：**
- `UserRepository` - Profile CRUD
- `HeartRateZonesRepository` - 心率區間
- `UserTargetsRepository` - Target 管理
- `PersonalBestRepository` - PB 追蹤

---

### TrainingPlanViewModel (2500+ 行)

**現有職責：**
- 週計畫載入/產生
- 訓練概覽管理
- Workout 追蹤
- 強度計算
- EditSchedule 狀態
- 調整確認
- 週回顧顯示

**問題：**
- 巨型 ViewModel，難以維護
- 直接呼叫 Service (跳過 Manager)
- 多個獨立功能混在一起

**應拆分為：**
- `WeeklyPlanViewModel` (~200 行)
- `TrainingOverviewViewModel` (~150 行)
- `WorkoutTrackingViewModel` (~200 行)
- `IntensityViewModel` (~150 行)
- `EditScheduleViewModel` (~300 行)
- `WeeklySummaryViewModel` (~200 行)

---

### AuthenticationService (1125 行)

**現有職責：**
- Firebase Auth SDK 呼叫
- Google/Apple/Email 登入
- 後端 API 驗證
- 用戶 Profile 獲取
- Onboarding 狀態管理
- FCM Token 同步
- Analytics 追蹤
- 快取清除

**應拆分為：**
- `AuthRepository` (Protocol)
- `FirebaseAuthDataSource` - Firebase SDK 封裝
- `BackendAuthDataSource` - 後端 API
- `LoginViewModel` - UI 狀態

---

## 2. 層級違規

### Views 直接呼叫 Services (13+ 處)

**違規 View：**
- `PersonalBestView` → UserService
- `OnboardingView` → TargetService, UserService
- `TrainingOverviewView` → TrainingPlanService
- `WeeklyDistanceSetupView` → TargetService
- `UserProfileView` → AuthenticationService, GarminDisconnectService
- `MyAchievementView` → TrainingLoadDataManager

**問題：**
- 完全跳過 ViewModel 層
- 業務邏輯散落在 View 中
- 無法測試

---

### ViewModels 直接呼叫 Services (15+ 處)

**違規 ViewModel：**
- `TrainingPlanViewModel` → TrainingPlanService (15+ 處)
- `UserProfileViewModel` → UserService
- `EmailLoginViewModel` → EmailAuthService
- `AddSupportingTargetViewModel` → TargetService

**問題：**
- 跳過 Manager/Repository 層
- 快取邏輯重複
- 難以共用業務邏輯

---

## 3. ViewModels 嵌入 View (13 個)

**違規檔案：**
- `OnboardingView.swift` → OnboardingViewModel
- `PersonalBestView.swift` → PersonalBestViewModel
- `TrainingOverviewView.swift` → TrainingOverviewViewModel
- `WeeklyDistanceSetupView.swift` → WeeklyDistanceViewModel
- `TrainingDaysSetupView.swift` → TrainingDaysViewModel
- ...等 13 個

**問題：**
- 違反檔案組織原則
- 無法單獨測試 ViewModel
- 無法重複使用 ViewModel

---

## 4. 循環依賴

```
UserManager → HeartRateZonesManager → UserPreferencesManager
     ↓                                        ↑
UserPreferencesManager ←─────────────────────┘
```

```
UnifiedWorkoutManager → WorkoutBackgroundManager → HealthKitManager
          ↓                       ↑
    HealthKitManager ←────────────┘
```

**問題：**
- 初始化順序不確定
- 潛在 race conditions
- 難以單獨測試

---

## 5. Singleton 濫用

- **27/29 Managers** 使用 `static let shared`
- 程式碼中有 **108 處 `.shared` 引用**

**問題：**
- 隱藏依賴關係
- 全域可變狀態
- 無法注入 Mock 進行測試

---

## 6. 雙重 API Client

- 舊版：`APIClient` (仍在使用)
- 新版：`HTTPClient` + `APIParser` (部分遷移)

**問題：**
- 錯誤處理不一致
- 維護成本加倍
- 新開發者困惑

---

## 現有優點 (需保留)

1. **TaskManageable 協議** - Actor-based 任務管理，線程安全
2. **DataManageable 協議** - 標準化數據載入模式
3. **雙軌緩存策略** - 快速顯示緩存 + 背景更新
4. **API 追蹤系統** - `.tracked(from:)` 清晰追蹤來源
5. **HTTPClient 設計** - 分層清晰，401 自動重試
6. **BaseDataViewModel** - 良好的委派模式
