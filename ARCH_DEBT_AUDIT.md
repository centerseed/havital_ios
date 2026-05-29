# Paceriz iOS 架構債盤點報告

> 產出日期：2026-05-29 · 方法：6 個 agent 平行掃描（layer-purity / migration / god-files / ios-correctness / duplication-deadcode / error-state）+ 彙整去重
> 規模：534 Swift 檔、~138K 行 · 44 筆 raw findings → 去重後 36 筆 · High 11 / Medium 18 / Low 7

## 執行摘要 (Executive Summary)

整體健康度判定為 **黃燈偏紅**：Clean Architecture 已大面積落地，但多個 feature 只搬了資料夾、沒搬紀律（DTO/Entity 邊界、錯誤轉換、API attribution 三項規範實際執行率偏低），且 V1/V2 訓練計畫雙軌與 4 個千行 god file 構成最大結構成本。最關鍵的是數條被文件明文宣告卻實際失效的護欄——`deinit cancelAllTasks()` 全域 no-op、`CacheEventBus` grep gate 已紅、`.tracked()` API attribution 在新架構 DataSource 為零——這些「規範存在但未生效」的問題優先於任何新增重構。

---

## 最優先處理 (Top Priorities)

依「嚴重度 × 修復成本」排序，高嚴重度／低成本者優先。

1. **`deinit cancelAllTasks()` 對所有 ViewModel/Manager 都是 no-op** — `High` / `M`
   證據：`Havital/Protocols/TaskManageable.swift:190-196`（約 36 個 conformer 受影響）。
   為何重要：detached Task 的 `weak self` 在 deinit 時已 nil，guard 提前 return，`taskRegistry.cancelAllTasks()` 永遠不執行——CLAUDE.md 承諾的 in-flight task 取消保證從未兌現，正是架構規則想防的 race。
   修法：在進 Task 前先 `let registry = taskRegistry`，`Task.detached { await registry.cancelAllTasks() }`，捕捉 registry 而非 self。

2. **TrainingPlanV2ViewModel 把 raw Error 直接丟到 UI（非 DomainError，破 i18n）** — `High` / `S`
   證據：`TrainingPlanV2ViewModel.swift:30,206,244,440`；`TrainingPlanV2View.swift:705`。
   為何重要：最常用畫面的網路錯誤顯示系統英文（如 "The Internet connection appears to be offline."）給 zh-TW/ja 使用者，違反 DomainError 邊界與 i18n 硬規範。
   修法：`networkError` 改 `DomainError?`，各 catch 與 coordinator callback 用 `error.toDomainError()` 轉換（SubscriptionRepositoryImpl.swift:336 已有同款 helper）。

3. **TrainingPlanV2 Domain entity 是 Codable 且當 cache 序列化格式（與既有 DTO+Mapper 並存）** — `High` / `L`
   證據：`PlanOverviewV2.swift:7`、`WeeklyPlanV2.swift:7`、`TrainingSessionModels.swift:116`、`TrainingPlanV2LocalDataSource.swift:146,187`。
   為何重要：團隊明知正解（DTO+Mapper 已存在於 remote 路徑），cache 卻繞過直接 decode entity，造成 Domain 綁 snake_case wire schema、cache/network 兩條序列化路徑可能 silent drift。
   修法：cache 改用（或復用）既有 DTO，經 Mapper 轉換；剝除 entity 的 Codable/CodingKeys/custom decoder。

4. **VDOT→建議配速有兩套發散實作，其一自承「簡化近似」** — `High` / `M`
   證據：`PaceCalculator.swift:43-102`（Daniels 公式）vs `PaceFormatterHelper.swift:44-102`（自注「簡化版／近似計算」，magic constants baseSecondsPerKm=330）；V1 ViewModel 仍接簡化版（`TrainingPlanViewModel.swift:148-149`、`EditScheduleViewModel.swift:134-136`）。
   為何重要：同一 trainingType+VDOT 在 V1/V2 畫面給出不同配速，直接損害訓練處方可信度。
   修法：以 PaceCalculator 為唯一真相，V1 ViewModel 改呼叫它，刪除 PaceFormatterHelper 的近似方法（保留純格式化）。

5. **V1/V2 兩套 default-training-details switch（~250 行）幾乎逐行重複** — `High` / `M`
   證據：`EditScheduleView.swift:536-840` vs `EditScheduleViewV2.swift:507-709`。
   為何重要：預設處方（距離、fallback 配速、segment）任何改動要改兩處，且已開始 drift（dayTarget 字串 542 vs 515 已不同）。
   修法：抽 `DefaultTrainingDetailsFactory.make(for:vdot:)` 共用，集中 fallback 常數與字串。

6. **Mandated `.tracked(from:)` API attribution 在所有新架構 RemoteDataSource 為零** — `Medium` / `M`
   證據：`APISourceTracking.swift` 只在 9 個 legacy 檔被用；`TrainingPlanV2RemoteDataSource.swift:66,129` 等 13 個 `*RemoteDataSource.swift` 全裸呼叫；`TrainingPlanRemoteDataSource`(16)、`WorkoutRemoteDataSource`(9)、`UserProfileRemoteDataSource`(6)、`BackendAuthDataSource`(9)。
   為何重要：訓練計畫／workout／profile／auth 等最高價值 endpoint 在 prod log 不可歸因，正是 attribution 規則要防的事故除錯缺口。
   修法：選定 RemoteDataSource 作為 attribution choke point 統一 chain `.tracked(from:)`，加 grep gate 防回歸。

7. **Workout Clean Arch feature 沒有 Domain Entity，repository 回傳 legacy Codable `Models.WorkoutV2`** — `High` / `L`
   證據：`WorkoutRepository.swift:32-126`、`Models/WorkoutV2Models.swift:10,433`。
   為何重要：Domain 直接綁後端 JSON schema，WorkoutMapper 映到同一 Codable 型別提供零隔離；最大單一 Entity/DTO 違規。
   修法：新增非 Codable entity + Data/DTOs（移出 Models/），Mapper 改 DTO→Entity，repository 回傳 entity，沿 repository 邊界漸進改。

8. **Legacy/UserPreferencesManager 標 @deprecated 但是唯一定義、且為新 feature + Core 的硬依賴** — `High` / `L`
   證據：`Legacy/UserPreferencesManager.swift:19-20,721`，被 ~30 檔引用含 UserProfile/Workout/Target/Onboarding 新 ViewModel 與 AppStateManager。
   為何重要：deprecation 註記是假的，對自家新 code 產生警告且誤導；信任註記而刪除會直接 break app。
   修法：(a) 完成遷移把偏好讀寫收進 UserProfileRepository 後刪類別；或 (b) 若保留，移除假 @deprecated 與 legacy typealias，搬到 Core/ 作官方 store。

9. **Apple Sign-In presentation anchor 用 fatalError** — `Medium` / `S`
   證據：`AuthenticationService.swift:1073`。
   為何重要：multi-scene／邊緣生命週期下 `connectedScenes.first` 合法為 nil 時，主要登入入口硬崩潰。
   修法：遍歷 connectedScenes 找 active foreground UIWindowScene；找不到回傳空 `UIWindow()` 或非致命錯誤到 loginError。

10. **LapAnalysisView render 路徑用 `try!` decode fallback** — `Medium` / `S`
    證據：`LapAnalysisView.swift:195`、`Models/WorkoutV2Models.swift:923`。
    為何重要：防呆 fallback 內藏潛在 crash；只要 LapData 任一欄改成 required 就崩，且正好崩在本該優雅處理 malformed data 的分支。
    修法：改 `try?` 並直接用既有 memberwise init `LapData(lapNumber:startTimeOffsetS:)`（WorkoutV2Models.swift:903）構造，免 JSON round-trip。

11. **VDOTCalculator.swift 整檔死碼（271 行）** — `Medium` / `S`
    證據：`Models/VDOTCalculator.swift:1-271`（唯一 `VDOTCalculator(` 出現在 261 行自身註解）。
    為何重要：誤導讀者以為 app 端算 VDOT，且攜帶與後端 `/v2/vdot/calculate` 發散的第二套公式，可能被誤接。
    修法：最終 grep 確認無 reflection 使用後刪除；確認 VDOTService 為唯一來源。低風險，可即刻清。

12. **V1/V2 訓練計畫兩套 stack 透過 runtime 版本路由全活** — `High` / `L`（最大結構成本，但需後端條件配合）
    證據：`ContentView.swift:399-442`、`Features/TrainingPlan`(25 檔)+`Views/Training`(41 檔) vs `Features/TrainingPlanV2`(64 檔)。
    為何重要：每個訓練計畫改動要做兩次、QA 兩次，~130 檔雙軌維護。**注意：這不是死碼**，v1 用戶仍在路由，刪除前需後端確認 v1 用戶趨近零。
    修法：定 V1 sunset 日期，確認 v1 流量歸零後強制 v2、刪 V1 presentation + Views/Training。

---

## 完整清單 (依維度)

### Layer-purity / 依賴方向違規

- `Medium` `SubscriptionLocalDataSource.swift:40` / `TargetLocalDataSource.swift:43` / `TrainingPlanV2LocalDataSource.swift:95` / `UserProfileLocalDataSource.swift:53` — 四個 Data 層 LocalDataSource 在 init 呼叫 `CacheEventBus.shared.register(self)`，違反 Data 不得碰 event bus 的 grep gate。
- `Medium` `SubscriptionStateManager.swift:17` / `VDOTManager.swift:141` — Domain 層 manager 直接 subscribe/register CacheEventBus，破 Domain 純淨。
- `High` `PlanOverviewV2.swift:7` / `WeeklyPlanV2.swift:7` / `TrainingSessionModels.swift:116` / `TrainingPlanV2LocalDataSource.swift:146,187` — TrainingPlanV2 Domain entity 為 Codable 且當 cache 序列化格式，與既有 DTO+Mapper 並存發散。（見 Top #3）
- `Medium` `AuthUser.swift:20` / `AchievementModels.swift:124` / `ClimateForecastModels.swift:9` / `HeartRateZone.swift:14` / `UserStatistics.swift:1` / `DailyStat.swift:1` / `WeeklySummaryV2.swift:1` / `WeeklyPreviewV2.swift:1` — 多個 Domain entity 為 Codable，部分（Climate/Achievement）甚至帶 snake_case CodingKeys（純 DTO 行為）。
- `High` `WorkoutBackgroundManager.swift:2,63,67` / `TrainingIntensityManager.swift:3,33` — Domain UseCase 直接 import 並 `HKHealthStore()` HealthKit，破 HealthKit→Backend→UI；兩者皆已標 @deprecated 但仍 live。
- `Medium` `EditScheduleV2ViewModel.swift:121,149,164,176` — Presentation ViewModel 直接組 Data 層 DTO（呼叫 `TrainingSessionMapper.toDTO`），反轉 Presentation→Data 依賴。

### 半成品遷移債（legacy Views/Models vs Features Clean Arch；V1/V2 共存）

- `High` `ContentView.swift:399-442` + `Features/TrainingPlan` / `Views/Training` / `Features/TrainingPlanV2` — V1/V2 雙 stack 全活，~130 檔並行維護。（見 Top #12）
- `High` `Legacy/UserPreferencesManager.swift:19-20,721` — 假 @deprecated 但唯一定義、新 code 硬依賴。（見 Top #8）
- `High` `WorkoutRepository.swift:32-126` / `WorkoutV2Models.swift:10,433` — Workout feature 無 Domain Entity，repository 回傳 legacy Codable。（見 Top #7）
- `Medium` `TargetRepository.swift:13-37` / `Models/Target.swift:19-33` — Target feature 有層資料夾卻無 DTO/Entity，端到端用同一 Codable model。
- `Medium` `Views/Onboarding/OnboardingContainerView.swift` + `Features/Onboarding/Presentation`（僅 3 檔、無 Views）— Onboarding 只搬 ViewModel/Coordinator，22 個 View 仍留 legacy 樹。
- `Medium` `MyAchievementView.swift:1431,1954,2352` / `ContentView.swift:248` — 無版本 gate 的 always-on tab 三次實例化 V1 `TrainingPlanViewModel`，導致 V2 用戶仍跑 V1 code，阻擋 V1 sunset。
- `Medium` `Services/Deprecated/WorkoutV2Service.swift:48`（無 @deprecated 標記）/ `UserService.swift:23` — 「Deprecated」資料夾實為新 code 與 app 啟動路徑（AppStateManager.swift:247）的 live 依賴。
- `Low` `Views/Settings/ClimateSettingsView.swift:164,227-257,244` — View 檔內 inline 自定義 Repository+VM 並 default 構造 Impl，與既有 Features/Climate 模組並行、繞過 DI。
- `Low` `TrainingRecordViewModel.swift:55` — init default `= WorkoutRepositoryImpl.shared`，硬耦合 concrete impl、繞過 DI（型別仍是 protocol，可覆寫）。

### God files / SRP 違規 / 缺層

- `High` `MyAchievementView.swift:98,563,611,699,759,1428,1951,2349` — 3009 行 god file，15+ type、自建 `HealthKitManager()`、cache/HealthKit/API 業務邏輯塞在 View 層。
- `High` `HealthKitManager.swift:18,986,1074,1321,1688` — 1966 行混 raw HK query 與 zone/weekly-analysis domain 計算（純 domain math 放 infra adapter）。
- `High` `UserProfileView.swift:21,658,1711,1726` — 1911 行，`switchDataSource(to:)` 把 Garmin/Strava/AppleHealth 綁定解綁業務邏輯 + 後端 API + `print()` 塞在 View。
- `Medium` `WeekTimelineViewV2.swift:731,788,1018,1026,1222` — 1875 行 component 檔含 ~20 view type + pace/VDOT/climate domain 計算 free function。
- `Medium` `HavitalApp.swift:22,515,671,772,884,1078,1455` — 1471 行 @main 混 permission/background/deeplink 編排與 production 內的 UI-test 鷹架（LocalUITest*）。
- `Medium` `TrainingDetailEditor.swift:6,154,402,411,1847` — 2277 行，30+ editor view + 400 行 edit-state model 內含 distance/pace 計算（與 PaceFormatterHelper 重複）。
- `Medium` `AppleHealthWorkoutUploadService.swift:10,480,622,833,951` — 1703 行混 upload 編排、HK 資料驗證/retry、device/error telemetry、summary caching；自建 HealthKitManager。
- `High` `UserProfileView.swift:29` / `MyAchievementView.swift:99` / `DataSyncView.swift:329` / `DataSourceSelectionView.swift:5` / `WorkoutDetailViewModelV2.swift:379` / `HealthDataUploadManagerV2.swift:106` — `HealthKitManager()` 被實例化 15+ 次，含 4 個 View 直接持有，破 HealthKit→UI 且無 singleton。

### Duplication 與死碼

- `Medium` `PaceCalculator.swift:75` / `PaceFormatterHelper.swift:44,109` / `PaceCalculationHelper.swift:20` / `WeekTimelineViewV2.swift:1018` / `TrainingPlanViewModel.swift:148` — pace/VDOT 邏輯三重 Utils + `getSuggestedPace` 共 6 份。
- `High` `PaceCalculator.swift:43-102` vs `PaceFormatterHelper.swift:44-102`（+ `TrainingPlanViewModel.swift:148-149`、`EditScheduleViewModel.swift:134-136`）— 兩套發散 VDOT→pace，其一自承近似。（見 Top #4）
- `High` `EditScheduleView.swift:536-840` vs `EditScheduleViewV2.swift:507-709` — V1/V2 default-details switch 逐行重複。（見 Top #5）
- `Medium` `EditScheduleView.swift:538` / `EditScheduleViewV2.swift:509` / `PaceFormatterHelper.swift:48-72` — ~45 處硬編碼 zh-TW dayTarget/description 字串繞過 LocalizationKeys，寫入計畫後 ja/en 用戶看到中文。
- `Medium` `Models/VDOTCalculator.swift:1-271` — 整檔死碼（grep 確認唯一引用在自身註解，低不確定性）。（見 Top #11）
- `Medium` `Legacy/TargetManager.swift:16` / `Legacy/TrainingPlanManager.swift:17` / `Legacy/WeeklySummaryManager.swift:5,34` — 三個 Legacy manager 已無 live 引用（僅出現在註解與 CacheEventBus.swift:208 字串字面量），~50KB 死碼。**注意：UserPreferencesManager 與 WeeklyVolumeManager 仍 live，勿刪。**
- `Medium` `WeeklyPlanV2Mapper.swift:88-118` / `PlanOverviewV2Mapper.swift:182-210` / `WeeklySummaryV2Mapper.swift:339-350` — ISO8601 `parseDate(from:)` 三 mapper 逐字複製，DateFormatterHelper 缺 fractional parser。
- `Medium` `PaceFormatterHelper.swift:109-126` / `WeekTimelineViewV2.swift:1018-1029` / `EditScheduleV2ViewModel.swift:499-506` — pace string↔seconds 至少三套；`%d:%02d` 格式化散見 31 檔（已有 TimeFormatting.formatTime）。
- `Low` `HealthDataUploadManagerV2.swift` / `RaceMapper.swift` / `BackfillService.swift` / `WorkoutUploadTracker.swift` / `TrainingReadinessModels.swift` 等 21 處 — inline `yyyy-MM-dd` DateFormatter，多數未設 locale/timezone（date-string 時區陷阱）。

### 錯誤處理 & 狀態管理一致性

- `High` `TrainingPlanV2ViewModel.swift:30,206,244,440` / `TrainingPlanV2View.swift:705` — raw Error 直送 UI 而非 DomainError。（見 Top #2）
- `Medium` `TrainingPlanV2ViewModel.swift:429` — Presentation 層手造 `NSError` 帶硬編碼中文 `"無週課表可刪除"`，繞過 DomainError + i18n。
- `Medium` 13 個 `*RemoteDataSource.swift`（`TrainingPlanV2RemoteDataSource.swift:66,129` 等）+ `APISourceTracking.swift` — mandated `.tracked(from:)` 在新架構 DataSource 為零。（見 Top #6）
- `Medium` `BaseDataViewModel.swift:11` / `TrainingPlanManager.swift:24,26` / `WeeklySummaryManager.swift:43` / `HRVManager.swift:46` / `ViewState.swift` — legacy manager 用 `isLoading + data? + syncError:String` triple-optional，與既有 `ViewState<T>` 兩套並存，error 存 String 丟失 DomainError 型別、可表達 loading+error 不可能態。
- `Low` `SubscriptionLocalDataSource.swift:40` / `TargetLocalDataSource.swift:43` / `TrainingPlanV2LocalDataSource.swift:95` / `UserProfileLocalDataSource.swift:53` / `VDOTManager.swift:140` — 文件公布的 `grep CacheEventBus` gate 目前為紅（register/subscribe 非 forbidden publish，但 gate 文字說完全不得引用）。
- `Low` `HealthKitManager.swift:32,152` / `AppleHealthWorkoutUploadService.swift`(106) / `AuthenticationService.swift`(88) / `HavitalApp.swift`(88) / `Logger.swift` — 已有 Logger（185 檔用）卻仍有 ~1184 處 runtime `print()`，無 leveling、無 #if DEBUG，release 也輸出。

### iOS 特定正確性陷阱（latent-bug）

- `High` `TaskManageable.swift:190-196`（+ WorkoutDetailViewModelV2/TargetFeatureViewModel/AppViewModel 等 ~36 conformer）— deinit `cancelAllTasks()` 全域 no-op。（見 Top #1）
- `Medium` `LapAnalysisView.swift:195` / `WorkoutV2Models.swift:923` — render 路徑 `try!` decode fallback。（見 Top #10）
- `Medium` `AuthenticationService.swift:1073` — Apple Sign-In anchor fatalError。（見 Top #9）
- `Low` `WeeklyPlanViewModel.swift:33` / `TrainingPlanViewModel.swift:373` — 宣告 `taskRegistry` 與 TaskManageable MARK 但類別未 conform、`executeTask` grep 計數 0；死狀態、誤導。
- `Low` `SafeNumber.swift:143` — `extension Numeric { static var zero { 0 as! Self } }` force-cast 並 shadow stdlib `AdditiveArithmetic.zero`；目前僅 stdlib numeric 流經故不會 trap，屬 fragile 共用碼。

---

## 建議的清理路線 (Roadmap)

### Wave 1 — Quick wins / 修復護欄（天）
目標：把「已紅或失效的規範」變綠，清掉零風險死碼。低成本、高槓桿、可即時驗證。
- 修 `deinit cancelAllTasks()` no-op（Top #1）— 捕捉 registry 而非 self。**最高優先，影響 ~36 conformer。**
- TrainingPlanV2ViewModel raw Error → DomainError（Top #2）+ 移除硬編碼 NSError 中文（#429）。
- Apple Sign-In fatalError 改優雅 fallback（Top #9）；LapAnalysisView `try!` 改 `try?`（Top #10）。
- 刪 VDOTCalculator.swift（Top #11）與三個 Legacy manager（TargetManager/TrainingPlanManager/WeeklySummaryManager），刪前各跑一次 grep 確認。
- 移除 WeeklyPlan/TrainingPlanViewModel 的死 `taskRegistry`；修 `Numeric.zero` force-cast。
- 釐清 CacheEventBus grep gate：將 gate 收斂為 `CacheEventBus.shared.publish` 或把 register 搬出 Data，二選一並更新 architecture.md 讓 gate 真綠。

### Wave 2 — 結構整併（週）
目標：收斂重複實作與錯誤層次，建立單一真相來源。
- pace/VDOT 收斂為 PaceCalculator 單一真相（Top #4、6 份 getSuggestedPace、pace↔seconds 三套）；刪 PaceCalculationHelper 與 free functions。
- 抽 `DefaultTrainingDetailsFactory`（Top #5），同時把 ~45 處硬編碼中文 dayTarget 移進 Localizable.strings。
- 統一 `.tracked(from:)` attribution 到 RemoteDataSource choke point（Top #6）+ 加 grep gate。
- DateFormatterHelper 新增 ISO8601 fractional parser 取代三 mapper 複製；21 處 inline `yyyy-MM-dd` 改走 helper（pin POSIX/timezone）。
- legacy manager `syncError:String` → `DomainError?` / `ViewState<T>`；刪無子類的 BaseDataViewModel。
- 把 Data 層 LocalDataSource register / Domain manager subscribe 移出，恢復 layer 純淨；EditScheduleV2ViewModel 的 DTO 組裝搬回 Data Mapper。
- 拆 god file：MyAchievementView / UserProfileView / HavitalApp（抽 ViewModel、子 view、Bootstrapper/PermissionCoordinator、把 UITest 鷹架移到 Debug/ build-config gate）。
- HealthKitManager 收斂為 thin query adapter + 單一 shared instance behind protocol（解 15+ 實例與 HealthKit→UI），HeartRateZoneCalculator/WeeklyHeartRateAnalyzer 抽到 Domain。
- print() → Logger，從 integration/auth manager 開始，加 grep lint。

### Wave 3 — 大型遷移（更長，需跨團隊/後端配合）
目標：消滅雙軌與 Domain 序列化耦合，需先決策與條件確認。
- **V1 sunset（Top #12）**：先由後端確認 v1 路由流量趨近零（前置條件，不可假設），再強制 getTrainingVersion()→v2、刪 Features/TrainingPlan presentation + Views/Training；前置須先解 MyAchievementView 對 V1 TrainingPlanViewModel 的 always-on 耦合。
- TrainingPlanV2 / Workout / Target Domain entity 去 Codable，導入 cache DTO + Mapper（Top #3、#7、Target），沿 repository 邊界漸進、blast radius 大。
- UserPreferencesManager 終局決策（Top #8）：完成遷入 UserProfileRepository 後刪，或正名移入 Core/ 並拔掉假 @deprecated。
- WorkoutBackgroundManager/TrainingIntensityManager 的 HealthKit 收到 Repository protocol 後（依賴 Wave 2 HealthKitManager 收斂）。
- Onboarding 22 個 View 由 legacy 樹搬入 Features/Onboarding/Presentation/Views；ClimateSettings inline repo/VM 併入 Features/Climate；WorkoutV2Service 移出 Services/Deprecated。

### 不確定性聲明
- 「死碼」類（VDOTCalculator、三個 Legacy manager、WeeklyPlan/TrainingPlanViewModel 的 taskRegistry）皆以 grep 判定，刪除前須各自再跑一次 grep 確認無 reflection/dynamic/字串建構引用——本報告未自行重跑驗證，沿用原 finding 標註的信心度。
- V1/V2 雙軌與 UserPreferencesManager **明確不是可直接刪的死碼**，刪除前提（v1 流量歸零、新 code 解依賴）必須先成立，否則會 break app。
