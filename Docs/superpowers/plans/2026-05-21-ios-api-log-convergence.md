# iOS 底層 API/Log 收斂 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除冷啟動/導航時的重複 API 呼叫與多餘 cloud-logging 流量，把 `/user` 收斂到單一有緩存的 Repository，並補齊 API 呼叫來源歸因。

**Architecture:** 以「單一資料來源 + 緩存層」為原則：所有 `/user` 存取走 `UserProfileRepository`（已有 dual-track cache）；其餘直打路徑（deprecated `UserService`、`AuthenticationService.makeAPICall`）退場。觀測面用既有 `APICallTracker` TaskLocal 補歸因；cloud-logging 移除高頻 routine info 的上傳標記。`monthly_stats` 重複已在本分支前置修復（短 TTL + in-flight 合併），本計畫不再處理。

**Tech Stack:** Swift / SwiftUI、Clean Architecture（Repository + DataSource + UseCase）、Combine（退場中）、Firebase Auth、自製 `Logger`/`FirebaseLoggingService`/`APICallTracker`。

**前置已知事實（研究確認）：**
- `Firebase ID token「×63」是假議題`：`FirebaseAuthDataSource.getIdToken()` 用 SDK `user.getIDToken()`（= `forcingRefresh:false`），SDK 本地已快取至約 1 小時到期，不會每次打網路。先前 63 次只是 *logging*，已降為 trace。→ 本計畫只修正誤導註解，不加 app 端 token 快取（YAGNI）。
- `cloud-logging` 無批次：每筆 `cloud_logging:true` 的 info 各打一次同步 `POST /internal/cloud-logging`。後端是否支援陣列 body 未確認，故本計畫採「前端移除高頻 routine info 的上傳標記」的低風險做法（不依賴後端）。
- `/user` 有 6 個 GET callsite，僅 `UserProfileRemoteDataSource.swift:41` 正當；其餘 5 個（UserService×2、AuthenticationService×3）繞過緩存。

---

## 驗證工具（Verification Harness）— 全計畫共用

成功指標是「API 呼叫次數 / log 量下降」，用模擬器 console 擷取量測。每個 Phase 完成後重跑此流程比對。

```bash
# 變數
UDID=E8E035CC-59AC-450F-A779-9633C3DB6E10
APP=~/Library/Developer/Xcode/DerivedData/Havital-afnohpqrotflnsarisvbcrxguabs/Build/Products/Debug-iphonesimulator/paceriz_dev.app
WT=/Users/wubaizong/havital/apps/ios/Havital/.claude/worktrees/ios-ui-refactor

# build + install
cd "$WT" && xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
xcrun simctl terminate "$UDID" com.havital.Havital.dev 2>/dev/null
xcrun simctl install "$UDID" "$APP"

# console 擷取（背景），冷啟動後做基本操作（切四個 tab 再回課表）
xcrun simctl launch --console-pty "$UDID" com.havital.Havital.dev > /tmp/applog.txt 2>&1 &
sleep 9   # 冷啟動
# （切 tab：用 ios-simulator MCP ui_tap 底部四個 tab，再回課表）
sleep 2

# 量測
echo "GET /user:        $(grep -c 'GET /user' /tmp/applog.txt)"
echo "cloud-logging POST: $(grep -c '/internal/cloud-logging' /tmp/applog.txt)"
echo "Unknown API caller: $(grep -c '📱 \[API\] Unknown' /tmp/applog.txt)"
echo "total log lines:   $(wc -l < /tmp/applog.txt)"
```

**Baseline（修復 monthly_stats + log 降噪後的現況）：** `GET /user` ≈ 8、`cloud-logging POST` ≈ 18、`Unknown API caller` 多筆、total ≈ 880。
**目標：** `GET /user` ≤ 2、`cloud-logging POST` ≤ 5、`Unknown` ≈ 0（被改到的路徑）。

---

## Task 0：基線擷取與分支備份

**Files:** 無（量測 + git）

- [ ] **Step 1: 建立備份分支**

```bash
cd /Users/wubaizong/havital/apps/ios/Havital/.claude/worktrees/ios-ui-refactor
git branch backup-$(date +%Y%m%d)-pre-convergence
```

- [ ] **Step 2: 跑驗證工具擷取 baseline，記下四個數字**

依「驗證工具」流程跑一次，把 `GET /user` / `cloud-logging POST` / `Unknown` / total 四個數字記到本檔最上方備查。

- [ ] **Step 3: Commit（僅計畫文件）**

```bash
git add docs/superpowers/plans/2026-05-21-ios-api-log-convergence.md
git commit -m "docs: add iOS API/log convergence plan (iOS Architect)"
```

---

## Phase 1 — 補 `.tracked(from:)` 歸因（低風險暖身）

目的：讓 log 裡 `Unknown` 的呼叫可追溯。機制：`APICallTracker.currentSource` 是 `@TaskLocal`，HTTPClient 讀 `getCurrentSource() ?? "Unknown"`。用全域 `tracked(_:_:)`（`APISourceTracking.swift:17`）包住呼叫即可。

### Task 1.1：monthly_stats 兩個 caller 加歸因

**Files:**
- Modify: `Havital/Views/Training/Components/TrainingCalendarView.swift:125,168`
- Modify: `Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingModeHeaderViewModelV2.swift:117`

- [ ] **Step 1: TrainingCalendarView 兩處 getMonthlyStats 包 tracked**

兩處皆為 `monthlyStats = try await monthlyStatsRepository.getMonthlyStats(year: year, month: monthNumber)`，改為：

```swift
monthlyStats = try await tracked("TrainingCalendarView: loadMonthlyStats") {
    try await monthlyStatsRepository.getMonthlyStats(year: year, month: monthNumber)
}
```

- [ ] **Step 2: TrainingModeHeaderViewModelV2:117 同樣包**

```swift
let stats = try await tracked("TrainingModeHeaderViewModelV2: loadMonthlyStats") {
    try await monthlyStatsRepository.getMonthlyStats(year: year, month: month)
}
```

- [ ] **Step 3: build**

Run: `xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: 跑驗證工具，確認 monthly_stats 的呼叫不再是 Unknown**

`grep "monthly_stats" /tmp/applog.txt | grep -c Unknown` 應為 0（或明顯下降）。

- [ ] **Step 5: Commit**

```bash
git add Havital/Views/Training/Components/TrainingCalendarView.swift Havital/Features/TrainingPlanV2/Presentation/ViewModels/TrainingModeHeaderViewModelV2.swift
git commit -m "chore(observability): attribute monthly_stats API calls via tracked() (iOS Developer)"
```

> 註：其餘 `Unknown` 來源（如 `UserProfileRemoteDataSource.swift:41` 的 GET /user）會在 Phase 2 收斂時一併歸口（呼叫端用 `tracked`/`TrackedTask` 包覆），不在此重複處理。

---

## Phase 2 — `/user` 多來源收斂（核心）

策略：所有 GET /user 走 `UserProfileRepository`（`getUserProfile()` cache-first / `refreshUserProfile()` 強制新鮮）；PUT /user 走 `updateUserProfile([...])`。`UserService` 僅保留兩塊**非 /user** 邏輯：`loginWithGoogle`（特殊認證）與 `syncUserPreferences`（本地偏好同步）。

> 風險：本 Phase 動到啟動/認證流程（CLAUDE.md 標記 init order 嚴格、易有 race）。每個 Task 後務必用模擬器跑通「冷啟動 → 課表載入 → 切 tab」並截圖確認無白屏/重登。
>
> **🔴 硬約束（載入順序，使用者明示）：V2 版本判斷與 IAP/訂閱狀態都依賴 user API。**
> - `TrainingVersionRouter.isV2User()` 讀 `user.trainingVersion`；冷啟動若 UserProfileRepository 尚未 bootstrap 會 default v1 → **V2 用戶被誤判 V1**。因此 `AppStateManager.loadUserData` 必須用 `refreshUserProfile()`（強制新鮮、寫入 repo cache），**嚴禁改成 cache-first `getUserProfile()`**。
> - 載入順序必須維持：**user 載入完成（trainingVersion 寫入 cache）→ 訓練版本路由 / 載入訂閱狀態（`loadSubscriptionStatus`）**。不可調換或並行化破壞此序。
> - 每個 Phase 2 Task 後額外驗證：(a) V2 demo 用戶冷啟動仍路由到 V2；(b) 訂閱/IAP 狀態正確（premium 不變免費）。
> - 動工前先確認 `TrainingVersionRouter` 讀 user 的來源與 `loadUserData` 寫入的 cache 是同一 store，確保 refreshUserProfile 寫入後 isV2User 讀得到。

### Task 2.1：AppRatingManager 改走 repository

**Files:**
- Modify: `Havital/Core/Infrastructure/AppRatingManager.swift:168-178`（`recordRatingPrompt` 呼叫處）

- [ ] **Step 1: 取得 repo 並改呼叫**

把 `try await self.userService.recordRatingPrompt(promptCount: newCount, lastPromptDate: dateString)` 改為：

```swift
let repo: UserProfileRepository = DependencyContainer.shared.resolve()
_ = try await repo.updateUserProfile([
    "rating_prompt_count": newCount,
    "last_rating_prompt_date": dateString
])
```

- [ ] **Step 2: 移除對 UserService 的依賴（若該檔僅用於此）**

確認 `AppRatingManager` 不再引用 `userService`；若有屬性宣告/注入，一併移除。

Run: `grep -n "userService\|UserService" Havital/Core/Infrastructure/AppRatingManager.swift`
Expected: 無殘留（或僅註解）

- [ ] **Step 3: build**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Havital/Core/Infrastructure/AppRatingManager.swift
git commit -m "refactor(user): route rating-prompt update through UserProfileRepository (iOS Developer)"
```

### Task 2.2：HeartRateZonesManager / HeartRateZonesBridge 改走 repository

**Files:**
- Modify: `Havital/Features/UserProfile/Domain/UseCases/HeartRateZonesManager.swift:144`
- Modify: `Havital/Features/UserProfile/Domain/UseCases/HeartRateZonesBridge.swift:36`

- [ ] **Step 1: 兩處 `UserService.shared.getUserProfile()`（Combine publisher）改為 async repo 呼叫**

把 publisher 取 user 的寫法改為（依各函式的 async/Combine 形態調整）：

```swift
let repo: UserProfileRepository = DependencyContainer.shared.resolve()
let user = try await repo.getUserProfile()
```

若原本是 Combine 鏈，改用 `Task { ... }` 包 async 呼叫，或將該函式改為 async（視 caller 而定；保留原本對 user 的後續處理邏輯不變）。

- [ ] **Step 2: build**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 模擬器確認心率區間功能正常**（進「表現/個人」頁，HR zones 有顯示）

- [ ] **Step 4: Commit**

```bash
git add Havital/Features/UserProfile/Domain/UseCases/HeartRateZonesManager.swift Havital/Features/UserProfile/Domain/UseCases/HeartRateZonesBridge.swift
git commit -m "refactor(user): heart-rate zones fetch user via repository, not UserService (iOS Developer)"
```

### Task 2.3：AppStateManager.loadUserData 改走 repository

**Files:**
- Modify: `Havital/Core/Infrastructure/AppStateManager.swift:235-256`

- [ ] **Step 1: 用 repo.refreshUserProfile 取代 UserService，移除手動 saveUserProfile**

Before（要點）：
```swift
userService = UserService.shared
let user = try await userService.getUserProfileAsync()        // line 247：直打 GET /user
userService.syncUserPreferences(with: user)                  // line 253：本地偏好同步（保留）
UserProfileLocalDataSource().saveUserProfile(user)           // line 256：手動寫 cache（刪除）
```

After：
```swift
let repo: UserProfileRepository = DependencyContainer.shared.resolve()
let user = try await tracked("AppStateManager: loadUserData") {
    try await repo.refreshUserProfile()                      // 冷啟動取新鮮資料，repo 自行寫 cache
}
UserService.shared.syncUserPreferences(with: user)           // 本地偏好同步保留
// 不再手動 saveUserProfile（repo 已寫 dual-track cache，避免雙寫不一致）
```

- [ ] **Step 2: build**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 模擬器冷啟動驗證**：登入狀態下冷啟動，課表/個人資料正常載入，dataSource 設定正確（無回到 unbound）。截圖確認。

- [ ] **Step 4: 跑驗證工具，確認 GET /user 下降**（預期少 1~2 發）

- [ ] **Step 5: Commit**

```bash
git add Havital/Core/Infrastructure/AppStateManager.swift
git commit -m "refactor(user): AppStateManager loads user via repository (cache-aware), drops manual cache write (iOS Developer)"
```

### Task 2.4：AuthenticationService 三處 /user 改走 repository

**Files:**
- Modify: `Havital/Services/Authentication/AuthenticationService.swift:403`（demo login 步驟3）
- Modify: `Havital/Services/Authentication/AuthenticationService.swift:533,547`（performUserSync）
- Modify: `Havital/Services/Authentication/AuthenticationService.swift:660`（fetchUserProfile，目前用 UserService publisher）

- [ ] **Step 1: performUserSync 的兩處 makeAPICall(User, "/user") 改 repo**

`var user = try await makeAPICall(User.self, path: "/user")`（line 533）→
```swift
let repo: UserProfileRepository = DependencyContainer.shared.resolve()
var user = try await repo.refreshUserProfile()
```
更新後重抓（line 547）`makeAPICall(User.self, path: "/user")` → `try await repo.refreshUserProfile()`（沿用同一個 `repo`）。
（line 537-545 已用 `userProfileRepository.updateUserProfile(updateData)`，不動。）

- [ ] **Step 2: demo login 步驟3（line 403）改 repo**

`let user = try await makeAPICall(User.self, path: "/user")` → `try await repo.refreshUserProfile()`（同檔取得 repo）。保留後續對 `appUser`/`hasCompletedOnboarding`/publish `dataChanged(.user)` 的邏輯。

- [ ] **Step 3: fetchUserProfile（line 644-768）改 async repo**

把 `APICallTracker.$currentSource.withValue("AuthenticationService: fetchUserProfile") { UserService.shared.getUserProfile() publisher ... }` 改為：
```swift
Task {
    do {
        let repo: UserProfileRepository = DependencyContainer.shared.resolve()
        let user = try await repo.getUserProfile()
        // ...沿用原本 onboarding 檢查 + syncUserPreferences + 連線檢查...
    } catch {
        // ...沿用原本 401/403 → Firebase signOut、DecodingError reset 邏輯（務必保留）...
    }
}.tracked(from: "AuthenticationService: fetchUserProfile")
```

- [ ] **Step 4: build**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: 模擬器驗證認證流程**：冷啟動（已登入）正常；登出→重登正常；無重複登入或白屏。截圖。

- [ ] **Step 6: Commit**

```bash
git add Havital/Services/Authentication/AuthenticationService.swift
git commit -m "refactor(user): AuthenticationService fetches /user via repository, drops direct makeAPICall (iOS Developer)"
```

### Task 2.5：syncUserPreferences 的 data_source PUT 走 repository

**Files:**
- Modify: `Havital/Services/Deprecated/UserService.swift:96-103,200-238`（`updateDataSource` / `syncUserPreferences`）

- [ ] **Step 1: syncUserPreferences 內部需 PUT data_source 時改走 repo**

`syncUserPreferences` 在無 dataSource 時呼叫 `updateDataSource()`（→ PUT /user）。把該內部呼叫改為：
```swift
let repo: UserProfileRepository = DependencyContainer.shared.resolve()
Task { try? await repo.updateDataSource(resolvedDataSource) }
```
（保留 syncUserPreferences 其餘純本地寫入 `UserPreferencesManager`/UserDefaults 的邏輯不變。）

- [ ] **Step 2: build + 模擬器確認 dataSource 綁定正常**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Havital/Services/Deprecated/UserService.swift
git commit -m "refactor(user): syncUserPreferences routes data_source PUT through repository (iOS Developer)"
```

### Task 2.6：移除 UserService 已死的 /user 方法

**Files:**
- Modify: `Havital/Services/Deprecated/UserService.swift`

- [ ] **Step 1: 確認以下方法已無 caller**

Run:
```bash
for m in getUserProfileAsync "getUserProfile(" updateUserData updatePersonalBestData recordRatingPrompt createTarget deleteUser; do
  echo "== $m =="; grep -rn "$m" Havital/ --include="*.swift" | grep -v "Services/Deprecated/UserService.swift"
done
```
Expected: 各項皆無外部命中（若有殘留 caller，回到對應 Task 補改）。

- [ ] **Step 2: 刪除這些方法本體**（保留 `loginWithGoogle`、`syncUserPreferences`、以及它們依賴的 `makeAPICall` 私有方法）

- [ ] **Step 3: build**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: 跑驗證工具，確認 `GET /user` ≤ 2**

- [ ] **Step 5: Commit**

```bash
git add Havital/Services/Deprecated/UserService.swift
git commit -m "refactor(user): remove dead /user methods from UserService, keep loginWithGoogle + syncUserPreferences (iOS Developer)"
```

---

## Phase 3 — cloud-logging 收斂（前端、不依賴後端）

`POST /internal/cloud-logging` 只在 `cloud_logging:true` 或 error/critical 時上傳（`FirebaseLoggingService.swift:136`）。冷啟動 ~18 發來自高頻 routine info 標了 `cloud_logging:true`。做法：把「啟動序列的 routine info」拿掉 `cloud_logging:true`（保留本地 log），只讓真正重要的事件 + error/critical 上雲。

### Task 3.1：移除高頻 routine info 的 cloud_logging 標記

**Files:**
- Modify: `Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift`（:140,155,175,188,212,224,301,320,336,348,395,408,894 等 setup/observer/check_upload routine）
- Modify: `Havital/Storage/TrainingPlanStorage.swift:47,79`、`WeeklySummaryStorage.swift:55,149`、`WorkoutV2CacheManager.swift:148,184`（cache 載入 routine）
- Modify: `Havital/HavitalApp.swift:530,641,656`（setup routine）

- [ ] **Step 1: 將 routine 的 `Logger.firebase(... level: .info, labels: ["cloud_logging": "true", ...] ...)` 改為本地 `Logger.debug(...)`**

逐處把「純啟動/setup/cache 載入的 info 上雲日誌」改為本地 debug。範例（WorkoutBackgroundManager setup observer）：

Before:
```swift
Logger.firebase("workout background observer 已設定", level: .info, labels: ["cloud_logging": "true", "module": "WorkoutBackgroundManager"])
```
After:
```swift
Logger.debug("[WorkoutBackgroundManager] workout background observer 已設定")
```

> 判準：保留上雲的＝跨裝置除錯需要的「結果/失敗/關鍵狀態」（例如背景上傳成功筆數、backfill 結果）；移除上雲的＝「我開始做某 setup」這類 routine 進度。error/critical 一律保留（本來就會上雲）。

- [ ] **Step 2: build**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 跑驗證工具，確認 `cloud-logging POST` ≤ 5**

- [ ] **Step 4: Commit**

```bash
git add Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift Havital/Storage/TrainingPlanStorage.swift Havital/Storage/WeeklySummaryStorage.swift Havital/Storage/WorkoutV2CacheManager.swift Havital/HavitalApp.swift
git commit -m "chore(logging): stop shipping routine setup/cache info logs to cloud-logging (iOS Developer)"
```

> 後續可選（需後端確認 `/internal/cloud-logging` 支援陣列 body）：在 `FirebaseLoggingService` actor 加 buffer + 定時/背景 flush 批次上傳。本計畫不含，列為 backlog。

---

## Phase 4 — Firebase token 註解修正（非功能）

研究確認 token 已由 Firebase SDK 本地快取，無重複網路請求。僅修正誤導註解，避免未來誤判。

### Task 4.1：修正 FirebaseAuthDataSource 註解

**Files:**
- Modify: `Havital/Features/Authentication/Data/DataSources/FirebaseAuthDataSource.swift:103-104,113`

- [ ] **Step 1: 改註解反映真實行為**

Before:
```swift
/// Get Firebase ID Token with automatic refresh
/// Token is fetched fresh every time for security
...
            // Force refresh to ensure token is valid
            let token = try await user.getIDToken()
```
After:
```swift
/// 取得 Firebase ID Token。
/// 註：user.getIDToken() = forcingRefresh:false，SDK 會回本地快取的 token 直到約 1 小時到期才自動換新，
/// 不會每次打網路。需強制刷新請用 refreshIdToken()。
...
            let token = try await user.getIDToken()  // SDK 本地快取，未到期不打網路
```

- [ ] **Step 2: build**

Run: `xcodebuild build ... | grep -E "BUILD (SUCCEEDED|FAILED)|error:"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Havital/Features/Authentication/Data/DataSources/FirebaseAuthDataSource.swift
git commit -m "docs(auth): correct misleading getIdToken comments — SDK caches token until expiry (iOS Developer)"
```

---

## Phase 5 — 整體回歸與量測

### Task 5.1：完整回歸驗證

**Files:** 無（量測 + 測試）

- [ ] **Step 1: 跑相關單元測試**

Run:
```bash
xcodebuild test -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:HavitalTests/MonthlyStatsCacheSettlementTests \
  -only-testing:HavitalTests/WorkoutRepositoryImplPublisherTests \
  -only-testing:HavitalTests/WorkoutListViewModelTests 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)|Executed"
```
Expected: TEST SUCCEEDED

- [ ] **Step 2: 跑驗證工具最終量測，對照 baseline**

確認：`GET /user` ≤ 2、`cloud-logging POST` ≤ 5、被改路徑的 `Unknown` ≈ 0、total log 進一步下降。

- [ ] **Step 3: 模擬器 E2E 手動驗證並截圖**

冷啟動（已登入）→ 課表/紀錄/表現/成就四 tab → 登出 → 重登。確認無白屏、無重複登入、資料正常。逐項截圖自驗。

- [ ] **Step 4: 最終 commit（若有零星修正）**

```bash
git add -A
git commit -m "chore: final convergence regression fixes (iOS Architect)"
```

---

## Self-Review 檢查

- **範圍涵蓋**：/user 收斂（Phase 2 全 callsite）、cloud-logging（Phase 3）、.tracked（Phase 1）、token（Phase 4 改為註解修正）。✅
- **型別一致**：`UserProfileRepository.getUserProfile()/refreshUserProfile()/updateUserProfile([String:Any])/updateDataSource(_:)` 全程一致；`tracked(_:_:)` / `.tracked(from:)` 簽名取自 `APISourceTracking.swift`。✅
- **YAGNI**：移除原「token 快取」任務（SDK 已快取），改為註解修正。✅
- **風險旗標**：Phase 2 動認證/啟動流程，每 Task 後要求模擬器跑通 + 截圖；備份分支於 Task 0。✅
- **跨 repo 依賴**：cloud-logging 真批次需後端支援，已排除於本計畫（列 backlog），改用前端移除標記的低風險做法。✅
