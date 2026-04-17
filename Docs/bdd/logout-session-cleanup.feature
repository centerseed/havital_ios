# Feature: logout-session-cleanup
# Version: 1.0 — 2026-04-16
# Dev brief: .claude/specs/logout-session-cleanup/spec.md

Feature: 登出時清除所有使用者本地資料
  In order to 確保不同使用者之間的資料完全隔離
  As a 切換帳號的使用者
  I want to 登出後所有前一位使用者的本地快取被徹底清除

  Background:
    Given 使用者 A 已登入且完成過 onboarding
    And 使用者 A 在 app 中產生了訓練計畫、個人紀錄、偏好設定等本地快取

  # ── 核心：Session 邊界 ──

  @ac1
  Scenario: 登出後所有 user-scoped UserDefaults 被核彈式清除
    When 使用者 A 登出
    Then 該 app bundle 的整個 UserDefaults domain 被移除
    And 僅保留 iOS 系統層級的設定

  @ac2
  Scenario: 登出後所有已註冊的快取被自動清除
    Given 所有持有 user-scoped 資料的 LocalDataSource 均已向快取事件總線註冊
    When 使用者 A 登出
    And 快取事件總線發布登出事件
    Then 所有已註冊的快取清除方法被呼叫
    And UserProfile、TrainingPlanV2、Target、Subscription 的本地快取全部為空

  @ac3
  Scenario: 登出後 Keychain 中的認證憑證被清除
    Given 使用者 A 透過 Apple 或 Google 登入，OAuth token 存於 Keychain
    When 使用者 A 登出
    Then Keychain 中所有密碼、憑證、金鑰類別的項目被刪除

  @ac4
  Scenario: 登出後所有持有 user-scoped 狀態的 Singleton 自動重置
    Given 以下 Singleton 訂閱了登出事件
      | Singleton                      | 重置行為               |
      | OnboardingCoordinator          | 清除導航與選擇狀態     |
      | OnboardingBackfillCoordinator  | 清除回填狀態           |
      | GarminManager                  | 重置連線檢查旗標       |
      | StravaManager                  | 重置連線檢查旗標       |
      | SyncNotificationManager        | 重置同步狀態           |
      | WorkoutUploadTracker           | 清除已上傳紀錄         |
      | SubscriptionStateManager       | 訂閱狀態設為無         |
    When 使用者 A 登出
    Then 上述每個 Singleton 收到登出事件後執行各自的重置行為

  @ac5
  Scenario: 登出後 RevenueCat 身份重置為匿名
    When 使用者 A 登出
    Then RevenueCat SDK 執行 logOut 回到匿名身份
    And 本地追蹤的 RevenueCat 使用者 ID 設為空

  @ac5 @edge-case
  Scenario: 離線時 RevenueCat logOut 失敗不阻擋登出流程
    Given 裝置處於離線狀態
    When 使用者 A 登出
    Then 本地快取全部清除
    And RevenueCat logOut 失敗被記錄但不影響登出結果
    And 使用者看到登入畫面

  # ── 背景刷新 Race Condition ──

  @ac6
  Scenario: 登出期間進行中的背景刷新不得回寫舊資料
    Given 使用者剛觸發了一次資料讀取，Repository 返回快取並啟動了背景刷新任務
    When 使用者在背景刷新完成前登出
    And 本地快取已被清除
    Then 背景刷新任務完成後不將結果寫入本地快取
    And 本地快取在登出後保持為空

  @ac6 @edge-case
  Scenario: 登出期間多個 Repository 的背景刷新同時進行
    Given UserProfile 和 UserPreferences 的背景刷新任務都在執行中
    When 使用者登出
    Then 兩個背景刷新任務完成後都不回寫結果
    And 對應的本地快取保持為空

  # ── 跨使用者隔離驗證 ──

  @ac7
  Scenario: 新使用者登入後 Onboarding 不包含前一位使用者的資料
    Given 使用者 A 已登出
    When 使用者 B 以新帳號登入
    And 使用者 B 進入 Onboarding 流程
    Then Personal Best 頁面不顯示使用者 A 的最佳成績
    And Weekly Distance 頁面不顯示使用者 A 的週跑量
    And Goal Type 頁面的預設選擇不受使用者 A 影響
    And Training Days 頁面不顯示使用者 A 的偏好天數
    And 目標距離為系統預設值

  @ac7
  Scenario: 新使用者登入後主畫面不包含前一位使用者的資料
    Given 使用者 A 已登出
    When 使用者 B 以已完成 onboarding 的帳號登入
    And 使用者 B 進入主畫面
    Then 訓練計畫顯示使用者 B 自己的資料
    And 週課表顯示使用者 B 自己的資料
    And 心率區間顯示使用者 B 自己的數值
    And 所有資料均從 API 新鮮載入

  @ac7 @edge-case
  Scenario: 使用者登出後立即以同一帳號重新登入
    Given 使用者 A 已登出
    When 使用者 A 以同一帳號重新登入
    Then 所有資料從 API 新鮮載入
    And 不使用登出前的本地快取

  # ── 登出路徑統一 ──

  @ac8
  Scenario: App 中僅存在單一登出路徑
    Given 使用者在設定頁點擊登出
    When 登出流程執行
    Then 登出邏輯由統一的 Clean Architecture 路徑處理
    And 不存在已棄用的 Legacy 登出呼叫

  @ac8
  Scenario: 刪除帳號時走相同的清理邏輯
    Given 使用者在設定頁點擊刪除帳號
    When 帳號刪除完成後執行登出
    Then 本地清理邏輯與一般登出完全相同

  # ── 防禦性邊界 ──

  @ac9
  Scenario: 連續快速點擊登出按鈕只執行一次
    Given 使用者在設定頁面
    When 使用者在 1 秒內點擊登出按鈕兩次
    Then 登出僅被執行一次
    And 不會發生並發的登出操作

  @ac9 @edge-case
  Scenario: 登出過程中 Firebase signOut 失敗
    Given Firebase signOut 拋出錯誤
    When 使用者嘗試登出
    Then 使用者看到錯誤訊息
    And 本地狀態不做部分清除
    And 使用者仍停留在已登入畫面

  # ── 架構保證 ──

  @ac10
  Scenario: 新增的快取模組自動被登出清除而無需修改登出程式碼
    Given 開發者新增了一個新的 LocalDataSource 並實作快取協議
    And 該 LocalDataSource 在初始化時向快取事件總線註冊
    When 使用者登出
    Then 新 LocalDataSource 的清除方法被自動呼叫
    And 登出函式本身無需任何修改
