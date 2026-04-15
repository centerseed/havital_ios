# 09. Paceriz Flutter 遷移檢查清單

## 📋 總覽

本檢查清單記錄 Paceriz 從 Swift/SwiftUI 遷移到 Flutter 的 **16 週完整任務分解**。

**遷移策略**：一次性完整遷移（非分階段）
**預計週期**：16 週（約 4 個月）
**Bundle ID**：保留現有 `com.havital.paceriz`

---

## 🎯 四大階段總覽

| 階段 | 時間 | 關鍵目標 | 交付物 |
|------|------|---------|--------|
| **Phase 1** | Week 1-4 | 基礎架構搭建 | Flutter 空殼 + 架構文檔 |
| **Phase 2** | Week 5-10 | 核心功能遷移 | Beta 版（運動資料 + 訓練計畫 + IAP） |
| **Phase 3** | Week 11-14 | 進階功能 | 多運動類型 + Apple Watch |
| **Phase 4** | Week 15-16 | 測試和發佈 | 1.0 正式版上線 |

---

## Phase 1: 基礎架構搭建（Week 1-4）

### Week 1: 專案初始化和環境設定

**目標**：建立可運行的 Flutter 專案骨架

#### 專案建立
- [ ] 使用 Flutter CLI 建立新專案
- [ ] 設定專案名稱和組織識別碼
- [ ] 配置 iOS 最低版本要求（iOS 14+）
- [ ] 配置 Android 最低版本要求（API 21+）
- [ ] 建立 Dev 和 Prod 兩種建置環境

#### 開發環境配置
- [ ] 安裝 Flutter SDK（穩定版本 3.16+）
- [ ] 配置 VS Code / Android Studio 開發環境
- [ ] 安裝 Dart 和 Flutter 擴充功能
- [ ] 設定 Git 版本控制（.gitignore 配置）
- [ ] 建立團隊開發規範文檔

#### Firebase 基礎設定
- [ ] 建立 Firebase Dev 專案
- [ ] 建立 Firebase Prod 專案
- [ ] 下載 iOS 和 Android 配置檔案
- [ ] 整合 Firebase Core SDK
- [ ] 配置 FlutterFire CLI

#### iOS 原生設定
- [ ] 配置 Info.plist（權限描述）
- [ ] 設定 Bundle ID：com.havital.paceriz
- [ ] 配置 HealthKit 權限請求
- [ ] 設定背景模式（Background Modes）
- [ ] 配置深度連結（Deep Links）

#### 驗收標準
- [ ] 專案可在 iOS 模擬器成功運行
- [ ] 專案可在 Android 模擬器成功運行
- [ ] Firebase 連線測試通過（Dev 和 Prod）
- [ ] 開發環境文檔完成

---

### Week 2: Clean Architecture 骨架建立

**目標**：建立四層架構的目錄結構和核心介面

#### 目錄結構建立
- [ ] 建立 lib/core/ 目錄（核心基礎建設）
- [ ] 建立 lib/data/ 目錄（資料層）
- [ ] 建立 lib/domain/ 目錄（領域層）
- [ ] 建立 lib/presentation/ 目錄（展示層）
- [ ] 建立 test/ 目錄結構（對應原始碼結構）

#### Core Layer 基礎建設
- [ ] 定義錯誤類型（NetworkError、CacheError、BusinessError）
- [ ] 建立網路設定（Dio 初始化）
- [ ] 建立快取策略協定（CacheStrategy 介面）
- [ ] 設定日誌系統（Logger 配置）
- [ ] 建立常數定義檔案（API endpoints、時間常數）

#### 依賴注入設定
- [ ] 安裝 get_it 和 injectable 套件
- [ ] 建立 injection.dart 設定檔
- [ ] 配置自動註冊掃描路徑
- [ ] 定義 Singleton、LazySingleton、Factory 策略
- [ ] 執行程式碼生成（build_runner）

#### 驗收標準
- [ ] 目錄結構符合 Clean Architecture 規範
- [ ] 依賴注入容器可成功初始化
- [ ] 錯誤類型定義完整且可擴充
- [ ] 單元測試目錄結構建立完成

---

### Week 3: 統一快取策略實作

**目標**：實作雙軌快取系統和版本控制

#### CacheStrategy 協定實作
- [ ] 定義快取協定介面（save、load、isExpired）
- [ ] 定義 TTL（Time To Live）配置
- [ ] 定義快取識別碼（identifier）規則
- [ ] 建立快取元資料結構（CacheMetadata）
- [ ] 實作版本控制機制

#### Hive 資料庫整合
- [ ] 安裝 Hive 和 Hive Flutter 套件
- [ ] 初始化 Hive 資料庫
- [ ] 建立型別轉接器（TypeAdapter）基礎類別
- [ ] 實作加密支援（選用）
- [ ] 建立快取清理策略

#### 雙軌快取實作
- [ ] 實作 Track A：立即顯示快取（同步）
- [ ] 實作 Track B：背景重新整理（非同步）
- [ ] 建立快取結果類型（CacheResult）
- [ ] 實作快取更新通知機制
- [ ] 處理快取失效和降級邏輯

#### 單元測試
- [ ] CacheStrategy 介面測試
- [ ] Hive 儲存和讀取測試
- [ ] 雙軌快取流程測試
- [ ] 快取過期邏輯測試
- [ ] 版本遷移測試

#### 驗收標準
- [ ] 快取策略單元測試覆蓋率 > 80%
- [ ] 雙軌快取流程驗證通過
- [ ] 快取元資料版本控制可運作
- [ ] 技術文檔：02_CACHE_STRATEGY.md 完成

---

### Week 4: API 去重機制實作

**目標**：實作全域 API 去重管理器

#### APIDeduplicationManager 實作
- [ ] 建立全域單例管理器
- [ ] 實作請求 Key 生成演算法
- [ ] 實作請求狀態追蹤（active requests map）
- [ ] 實作請求完成後自動清理
- [ ] 實作請求超時處理

#### Dio HTTP 客戶端設定
- [ ] 配置 Dio 基礎設定（baseUrl、timeout）
- [ ] 實作認證攔截器（Auth Token）
- [ ] 實作錯誤處理攔截器
- [ ] 實作日誌攔截器（開發環境）
- [ ] 實作重試機制（RetryInterceptor）

#### 整合測試
- [ ] 多個重複請求去重測試
- [ ] 請求完成後清理驗證
- [ ] 請求超時處理測試
- [ ] 認證失效處理測試
- [ ] 網路錯誤重試測試

#### CI/CD 初始化
- [ ] 建立 GitHub Actions 工作流程
- [ ] 配置自動化測試（單元測試）
- [ ] 配置程式碼覆蓋率報告
- [ ] 配置 Lint 檢查（flutter analyze）
- [ ] 配置建置驗證（iOS 和 Android）

#### 驗收標準
- [ ] API 去重機制單元測試覆蓋率 > 80%
- [ ] CI/CD 管道可成功運行
- [ ] 程式碼覆蓋率報告可生成
- [ ] 技術文檔：03_API_DEDUPLICATION.md 完成

---

## Phase 2: 核心功能遷移（Week 5-10）

### Week 5: 運動資料模型遷移

**目標**：遷移 WorkoutV2 資料模型和基礎 API

#### DTO 資料模型建立
- [ ] 遷移 WorkoutV2Models.swift 到 Flutter
- [ ] 建立 WorkoutV2DTO 類別（Freezed）
- [ ] 建立 WorkoutSummaryDTO 類別
- [ ] 建立 WorkoutSegmentDTO 類別
- [ ] 建立 HeartRateZoneDTO 類別

#### JSON 序列化設定
- [ ] 安裝 freezed 和 json_serializable 套件
- [ ] 定義 JSON 欄位映射
- [ ] 執行程式碼生成（build_runner）
- [ ] 驗證序列化和反序列化
- [ ] 處理空值和預設值

#### Domain Entity 建立
- [ ] 建立 Workout 領域實體
- [ ] 建立 WorkoutSummary 實體
- [ ] 建立 WorkoutSegment 實體
- [ ] 定義 DTO → Entity 轉換邏輯
- [ ] 定義業務驗證規則

#### 驗收標準
- [ ] 所有 DTO 類別成功生成
- [ ] JSON 解析測試通過（使用真實後端資料）
- [ ] DTO → Entity 轉換測試通過
- [ ] 技術文檔：05_DATA_MODELS.md 更新

---

### Week 6: 運動資料 Repository 實作

**目標**：實作運動資料的完整資料流

#### Repository 介面定義（Domain Layer）
- [ ] 定義 WorkoutRepository 抽象介面
- [ ] 定義 getWorkouts 方法簽章
- [ ] 定義 refreshWorkouts 方法簽章
- [ ] 定義 getWorkoutById 方法簽章
- [ ] 定義快取策略參數

#### Remote DataSource 實作
- [ ] 建立 WorkoutRemoteDataSource
- [ ] 實作 fetchWorkouts API 呼叫
- [ ] 實作分頁載入（limit、offset）
- [ ] 實作篩選參數（日期範圍、運動類型）
- [ ] 處理 API 錯誤回應

#### Local DataSource 實作
- [ ] 建立 WorkoutLocalDataSource
- [ ] 實作 Hive 儲存邏輯
- [ ] 實作 7 天 TTL 快取策略
- [ ] 實作快取查詢（依日期、類型）
- [ ] 實作快取清理（過期資料）

#### Repository 實作（Data Layer）
- [ ] 建立 WorkoutRepositoryImpl
- [ ] 實作雙軌快取邏輯
- [ ] 整合 API 去重機制
- [ ] 實作錯誤處理和降級策略
- [ ] 實作重新整理邏輯（forceRefresh）

#### 單元測試
- [ ] Repository 雙軌快取測試
- [ ] Remote DataSource API 呼叫測試（Mock）
- [ ] Local DataSource 儲存和讀取測試
- [ ] 錯誤處理測試
- [ ] 快取過期測試

#### 驗收標準
- [ ] Repository 單元測試覆蓋率 > 80%
- [ ] 雙軌快取流程驗證通過
- [ ] API 去重整合測試通過
- [ ] 整合測試：完整資料流測試

---

### Week 7: 運動列表 UI 實作

**目標**：實作運動列表頁面和狀態管理

#### BLoC 狀態管理建立
- [ ] 建立 WorkoutBloc
- [ ] 定義 WorkoutEvent（LoadWorkouts、RefreshWorkouts）
- [ ] 定義 WorkoutState（Loading、Loaded、Error）
- [ ] 實作事件處理邏輯（event → state）
- [ ] 整合 WorkoutRepository

#### UI 頁面實作
- [ ] 建立 WorkoutListPage
- [ ] 實作下拉重新整理（RefreshIndicator）
- [ ] 實作分頁載入（Infinite Scroll）
- [ ] 實作載入骨架（Shimmer 效果）
- [ ] 實作錯誤狀態 UI（ErrorView）

#### 可重複使用元件
- [ ] 建立 WorkoutCard 元件
- [ ] 建立 WorkoutSummaryWidget
- [ ] 建立 HeartRateZoneBadge 元件
- [ ] 建立 LoadingSkeleton 元件
- [ ] 建立 EmptyStateView 元件

#### BLoC 測試
- [ ] WorkoutBloc 事件處理測試
- [ ] 狀態轉換順序測試
- [ ] 錯誤狀態測試
- [ ] 快取更新通知測試

#### 驗收標準
- [ ] 運動列表頁面可正常顯示
- [ ] 下拉重新整理功能可運作
- [ ] 分頁載入流暢（無明顯卡頓）
- [ ] BLoC 測試覆蓋率 > 80%

---

### Week 8: 訓練計畫模型和 Repository

**目標**：遷移訓練計畫資料模型和資料流

#### DTO 資料模型建立
- [ ] 建立 TrainingPlanDTO 類別
- [ ] 建立 WeeklyPlanDTO 類別
- [ ] 建立 DailyWorkoutDTO 類別
- [ ] 建立 TrainingZoneDTO 類別
- [ ] 建立 PlanOverviewDTO 類別

#### Domain Entity 建立
- [ ] 建立 TrainingPlan 領域實體
- [ ] 建立 WeeklyPlan 實體
- [ ] 建立 DailyWorkout 實體
- [ ] 定義計畫狀態（未開始、進行中、已完成）
- [ ] 定義業務驗證規則

#### Repository 實作
- [ ] 定義 TrainingPlanRepository 介面
- [ ] 建立 TrainingPlanRemoteDataSource
- [ ] 建立 TrainingPlanLocalDataSource
- [ ] 實作 30 分鐘 TTL 快取策略
- [ ] 實作 TrainingPlanRepositoryImpl

#### 單元測試
- [ ] Repository 測試
- [ ] DataSource 測試
- [ ] DTO → Entity 轉換測試
- [ ] 快取策略測試

#### 驗收標準
- [ ] 訓練計畫資料模型完整
- [ ] Repository 單元測試覆蓋率 > 80%
- [ ] 快取策略驗證通過

---

### Week 9: 訓練計畫 UI 實作

**目標**：實作訓練計畫概覽和周計畫頁面

#### BLoC 狀態管理建立
- [ ] 建立 TrainingPlanBloc
- [ ] 定義 TrainingPlanEvent
- [ ] 定義 TrainingPlanState（NoPlan、Loading、Ready、Completed、Error）
- [ ] 實作事件處理邏輯
- [ ] 整合 TrainingPlanRepository

#### 訓練計畫概覽頁面
- [ ] 建立 TrainingPlanOverviewPage
- [ ] 實作計畫進度顯示（週數、完成度）
- [ ] 實作生成新計畫按鈕
- [ ] 實作週次切換功能
- [ ] 實作 NoPlan 狀態 UI

#### 周計畫詳情頁面
- [ ] 建立 WeeklyPlanPage
- [ ] 實作每日運動卡片
- [ ] 實作訓練強度區間顯示
- [ ] 實作目標距離和配速顯示
- [ ] 實作完成狀態標記

#### 可重複使用元件
- [ ] 建立 DailyWorkoutCard 元件
- [ ] 建立 TrainingZoneBadge 元件
- [ ] 建立 PlanProgressBar 元件
- [ ] 建立 GeneratePlanButton 元件

#### 驗收標準
- [ ] 訓練計畫概覽頁面可正常顯示
- [ ] 周計畫詳情頁面可正常顯示
- [ ] NoPlan 狀態提示正確
- [ ] BLoC 測試覆蓋率 > 80%

---

### Week 10: IAP 訂閱系統實作

**目標**：整合 IAP 並實作功能門控

#### Subscription 資料模型
- [ ] 建立 SubscriptionDTO 類別
- [ ] 建立 Subscription 領域實體
- [ ] 定義訂閱狀態（free、premium、expired）
- [ ] 定義訂閱類型（monthly、yearly）
- [ ] 建立收據驗證模型

#### SubscriptionRepository 實作
- [ ] 定義 SubscriptionRepository 介面
- [ ] 建立 Firestore DataSource
- [ ] 實作訂閱狀態查詢
- [ ] 實作 7 天 TTL 快取策略
- [ ] 整合收據驗證 API

#### in_app_purchase 整合
- [ ] 安裝 in_app_purchase 套件
- [ ] 配置 iOS IAP 產品 ID
- [ ] 配置 Android IAP 產品 ID
- [ ] 實作購買流程
- [ ] 實作購買恢復功能

#### Feature Gate 系統
- [ ] 建立 FeatureGate 存取控制器
- [ ] 定義 PremiumFeature 列舉
- [ ] 實作 canAccess 檢查邏輯
- [ ] 實作 requirePremium 強制檢查
- [ ] 建立 FeatureLockedError 錯誤類型

#### 訂閱頁面 UI
- [ ] 建立 SubscriptionPage
- [ ] 實作訂閱方案卡片
- [ ] 實作購買按鈕
- [ ] 實作購買成功提示
- [ ] 實作購買失敗處理

#### 功能鎖定 UI
- [ ] 建立 PremiumUpgradeDialog
- [ ] 實作功能鎖定提示
- [ ] 實作升級按鈕
- [ ] 實作導航到訂閱頁面

#### 驗收標準
- [ ] IAP 購買流程可正常運作（沙盒環境）
- [ ] 功能門控邏輯正確（免費 vs 付費）
- [ ] 收據驗證整合測試通過
- [ ] 技術文檔：04_FEATURE_GATE_IAP.md 完成

---

## Phase 3: 進階功能（Week 11-14）

### Week 11: Training V2 多運動類型支援

**目標**：擴充訓練計畫支援多運動類型

#### ActivityType 列舉擴充
- [ ] 建立 ActivityType 列舉（跑步、騎行、游泳）
- [ ] 定義運動類型圖示
- [ ] 定義運動類型顏色主題
- [ ] 定義運動類型單位（公里、英里、碼）
- [ ] 建立運動類型篩選器

#### TrainingPlan 繼承架構
- [ ] 建立 TrainingPlan 抽象基底類別
- [ ] 建立 RunningTrainingPlan 子類別
- [ ] 建立 CyclingTrainingPlan 子類別
- [ ] 建立 SwimmingTrainingPlan 子類別
- [ ] 定義各類別專屬屬性

#### 騎行特定功能
- [ ] 建立 PowerZone 資料模型
- [ ] 實作 FTP（Functional Threshold Power）計算
- [ ] 實作功率區間顯示
- [ ] 整合騎行訓練計畫 API
- [ ] 實作騎行專屬 UI 元件

#### 游泳特定功能
- [ ] 建立 SwimStroke 資料模型（自由式、蛙式等）
- [ ] 實作配速計算（每 100 公尺）
- [ ] 實作泳池長度設定
- [ ] 整合游泳訓練計畫 API
- [ ] 實作游泳專屬 UI 元件

#### UI 適配
- [ ] 訓練計畫頁面支援運動類型切換
- [ ] 運動卡片依類型顯示不同圖示
- [ ] 訓練強度區間依類型調整
- [ ] 統計圖表支援多運動類型
- [ ] 篩選器支援運動類型選擇

#### 驗收標準
- [ ] 跑步、騎行、游泳三種類型完整支援
- [ ] 訓練計畫 UI 正確適配不同運動類型
- [ ] 多運動類型整合測試通過
- [ ] 技術文檔：06_TRAINING_V2_DESIGN.md 完成

---

### Week 12: AI 生成訓練計畫整合

**目標**：整合 AI 生成訓練計畫 API

#### PlanGenerator 介面定義
- [ ] 建立 PlanGenerator 抽象介面
- [ ] 定義 generatePlan 方法簽章
- [ ] 定義輸入參數（目標、當前能力、時間限制）
- [ ] 定義輸出格式（WeeklyPlan 列表）
- [ ] 定義生成選項（強度、頻率）

#### AI 生成 API 整合
- [ ] 整合後端 AI 生成端點
- [ ] 實作生成請求參數組裝
- [ ] 實作生成進度追蹤
- [ ] 實作生成結果驗證
- [ ] 處理生成失敗情況

#### 生成流程 UI
- [ ] 建立訓練計畫生成精靈（Wizard）
- [ ] 實作步驟 1：選擇運動類型
- [ ] 實作步驟 2：設定目標（距離、時間）
- [ ] 實作步驟 3：填寫當前能力
- [ ] 實作步驟 4：調整訓練偏好
- [ ] 實作生成中載入動畫
- [ ] 實作生成完成預覽

#### 計畫調整功能
- [ ] 實作單日訓練調整（距離、強度）
- [ ] 實作週次調整（跳過、重複）
- [ ] 實作計畫重新生成
- [ ] 實作調整歷史記錄
- [ ] 實作調整同步到後端

#### 驗收標準
- [ ] AI 生成流程完整且流暢
- [ ] 生成的計畫符合使用者設定
- [ ] 計畫調整功能可正常運作
- [ ] 整合測試：完整生成流程測試

---

### Week 13: Apple Watch 資料同步基礎

**目標**：建立 Apple Watch 資料同步橋接

#### iOS Native Module 建立
- [ ] 建立 WatchDataBridge.swift
- [ ] 實作 MethodChannel 通訊協定
- [ ] 實作 HealthKit 授權請求
- [ ] 實作運動資料查詢
- [ ] 實作 HRV 資料查詢

#### Flutter 側 DataSource
- [ ] 建立 WatchLocalDataSource
- [ ] 實作 MethodChannel 呼叫包裝
- [ ] 實作權限狀態查詢
- [ ] 實作資料同步請求
- [ ] 處理 Native 錯誤回應

#### HealthKit 資料模型
- [ ] 建立 HealthKitWorkoutDTO
- [ ] 建立 HRVSampleDTO
- [ ] 建立 HeartRateSampleDTO
- [ ] 定義 DTO → WorkoutV2 轉換邏輯
- [ ] 處理資料去重

#### 同步邏輯實作
- [ ] 實作增量同步（依時間範圍）
- [ ] 實作全量同步（初次使用）
- [ ] 實作同步衝突解決
- [ ] 實作同步狀態追蹤
- [ ] 實作同步錯誤處理

#### 驗收標準
- [ ] iOS Native Module 可成功呼叫
- [ ] HealthKit 權限請求正常
- [ ] 運動資料可成功同步
- [ ] 技術文檔：07_APPLE_WATCH_SYNC.md 完成

---

### Week 14: Apple Watch 背景同步和上傳

**目標**：實作背景同步和資料上傳

#### 背景任務調度
- [ ] 配置 BGTaskScheduler（iOS）
- [ ] 實作背景同步任務（workout-sync）
- [ ] 實作 HRV 重試任務（hrv-retry-sync）
- [ ] 實作任務冷卻期邏輯
- [ ] 實作任務取消處理

#### 資料上傳 API
- [ ] 整合 /sync_watch_workouts 端點
- [ ] 實作批次上傳邏輯
- [ ] 實作上傳重試機制
- [ ] 實作上傳進度追蹤
- [ ] 處理上傳衝突

#### 同步狀態 UI
- [ ] 建立同步狀態指示器
- [ ] 實作同步進度顯示
- [ ] 實作同步錯誤提示
- [ ] 實作手動同步按鈕
- [ ] 實作同步歷史記錄

#### 效能最佳化
- [ ] 實作資料壓縮（大量資料）
- [ ] 實作批次大小控制
- [ ] 實作網路狀態檢測（Wi-Fi 優先）
- [ ] 實作電池電量檢測（低電量暫停）
- [ ] 實作同步頻率限制

#### 整合測試
- [ ] 初次同步測試（大量資料）
- [ ] 增量同步測試（少量更新）
- [ ] 背景任務測試（應用程式關閉）
- [ ] 網路異常測試（斷線、超時）
- [ ] 電池電量測試（低電量場景）

#### 驗收標準
- [ ] 背景同步可正常運作
- [ ] 資料上傳成功率 > 95%
- [ ] 同步效能可接受（< 30 秒完成）
- [ ] 整合測試全部通過

---

## Phase 4: 測試和發佈（Week 15-16）

### Week 15: 端到端測試和效能最佳化

**目標**：完成 E2E 測試並最佳化效能

#### E2E 測試實作
- [ ] 建立使用者認證流程測試
- [ ] 建立運動資料載入流程測試
- [ ] 建立訓練計畫生成流程測試
- [ ] 建立 IAP 購買流程測試（沙盒）
- [ ] 建立 Apple Watch 同步流程測試

#### 效能測試和最佳化
- [ ] 使用 Flutter DevTools 分析效能瓶頸
- [ ] 最佳化列表滾動效能（虛擬化）
- [ ] 最佳化圖片載入（快取、壓縮）
- [ ] 最佳化網路請求（減少請求數）
- [ ] 最佳化應用程式啟動時間

#### 記憶體和電池最佳化
- [ ] 檢測記憶體洩漏（Memory Profiler）
- [ ] 最佳化記憶體佔用（< 150MB）
- [ ] 最佳化背景任務電池消耗
- [ ] 最佳化網路請求電池消耗
- [ ] 最佳化 UI 渲染電池消耗

#### 使用者驗收測試（UAT）
- [ ] 招募 Beta 測試使用者（10-20 人）
- [ ] 建立 TestFlight 測試版本
- [ ] 收集使用者回饋
- [ ] 修復關鍵 Bug
- [ ] 驗證核心功能可用性

#### Bug 修復優先級
- [ ] P0（阻塞性）：立即修復
- [ ] P1（嚴重）：本週內修復
- [ ] P2（一般）：下版本修復
- [ ] P3（輕微）：記錄追蹤

#### 驗收標準
- [ ] E2E 測試全部通過
- [ ] 啟動時間 < 2 秒
- [ ] 記憶體佔用 < 150MB
- [ ] Crash 率 < 0.1%（Beta 測試）
- [ ] 技術文檔：10_TESTING_PLAN.md 完成

---

### Week 16: 發佈準備和正式上線

**目標**：完成 App Store 提交並正式發佈

#### App Store 提交材料
- [ ] 準備應用程式圖示（1024x1024）
- [ ] 準備螢幕截圖（6.7 吋、6.5 吋、5.5 吋）
- [ ] 撰寫應用程式描述（繁體中文、英文、日文）
- [ ] 撰寫更新說明（What's New）
- [ ] 設定分級和類別

#### 隱私和合規
- [ ] 填寫隱私權政策 URL
- [ ] 聲明資料使用方式
- [ ] 聲明第三方 SDK（Firebase、Sentry）
- [ ] 設定 App Tracking Transparency（ATT）
- [ ] 完成出口合規聲明

#### 建置和簽章
- [ ] 建立 Prod 環境建置配置
- [ ] 設定 Code Signing（Provisioning Profile）
- [ ] 建置 Release 版本（iOS）
- [ ] 驗證建置產物（IPA 檔案）
- [ ] 上傳到 App Store Connect

#### 灰度發佈策略
- [ ] 階段 1：10% 使用者（觀察 3 天）
- [ ] 監控 Crash 率和錯誤日誌
- [ ] 階段 2：50% 使用者（觀察 3 天）
- [ ] 驗證效能指標和業務指標
- [ ] 階段 3：100% 使用者（全量發佈）

#### 監控和日誌配置
- [ ] 配置 Sentry Crash 上報
- [ ] 配置 Firebase Analytics 事件追蹤
- [ ] 配置效能監控（Firebase Performance）
- [ ] 建立關鍵指標儀表板
- [ ] 設定異常告警閾值

#### 回滾預案
- [ ] 準備緊急回滾版本（Swift 原版）
- [ ] 建立回滾操作手冊
- [ ] 定義回滾觸發條件（Crash 率 > 1%）
- [ ] 準備使用者溝通文案
- [ ] 設定緊急聯絡機制

#### 文檔完成
- [ ] 技術文檔：11_DEPLOYMENT.md 完成
- [ ] 技術文檔：12_MONITORING.md 完成
- [ ] 使用者遷移指南完成
- [ ] 運維手冊完成
- [ ] API 文檔更新

#### 驗收標準
- [ ] App Store 審核通過
- [ ] 灰度發佈無重大問題
- [ ] 監控系統正常運作
- [ ] 使用者遷移率 > 95%
- [ ] App Store 評分維持 4.5+

---

## 📊 成功指標檢查清單

### 技術指標
- [ ] 程式碼量相比 Swift 版本減少 30%
- [ ] API 呼叫減少 50%（智慧去重 + 快取）
- [ ] 單元測試覆蓋率 > 80%
- [ ] 啟動時間 < 2 秒（冷啟動）
- [ ] 記憶體佔用 < 150MB（iOS）
- [ ] Crash 率 < 0.1%

### 業務指標
- [ ] 使用者遷移率 > 95%
- [ ] 7 日留存率 > 70%
- [ ] IAP 轉換率 > 5%
- [ ] App Store 評分維持 4.5+

### 架構指標
- [ ] 新功能開發效率：從 2 週縮短到 1 週
- [ ] Bug 修復速度：平均 < 24 小時
- [ ] 程式碼審查時間：平均 < 2 小時
- [ ] 部署頻率：每週至少 1 次

---

## 🚧 風險緩解檢查清單

### 技術風險
- [ ] Apple Watch 同步失敗 → 降級到僅支援 iPhone HealthKit
- [ ] IAP 收據驗證延遲 → 本機快取訂閱狀態（7 天 TTL）
- [ ] 資料遷移遺失 → 雲端備份（Firestore）
- [ ] 效能下降 → 使用 Hive + 虛擬化清單

### 業務風險
- [ ] 使用者流失 → 灰度發佈 + 無縫遷移體驗
- [ ] IAP 訂閱中斷 → 提前 2 週郵件通知 + 訂閱延長補償
- [ ] 功能降級 → 確保核心功能 100% 遷移

### 時間風險
- [ ] 輕微延期（1-2 週） → 壓縮 Phase 3 進階功能
- [ ] 嚴重延期（> 1 個月） → 拆分發佈（核心功能先上線）
- [ ] 阻塞風險 → Apple Watch 整合可獨立為 1.1 版本

---

## 📝 每週會議檢查點

### 週會必檢項目
- [ ] 上週任務完成度檢查
- [ ] 本週任務優先級排序
- [ ] 阻塞問題識別和解決方案
- [ ] 程式碼審查進度確認
- [ ] 測試覆蓋率報告
- [ ] 技術文檔更新狀態

### 階段里程碑會議
- [ ] Phase 1 完成：基礎架構評審
- [ ] Phase 2 完成：核心功能 Demo
- [ ] Phase 3 完成：進階功能驗收
- [ ] Phase 4 完成：發佈前最終檢查

---

**文檔版本**：v1.0
**建立日期**：2025-12-29
**預計完成**：2026-04-29（16 週後）
**負責人**：開發團隊

---

**使用說明**：
1. 每完成一個任務，請在對應的 checkbox 中打勾 ✅
2. 每週結束時，更新本檔案並提交到版本控制
3. 遇到阻塞問題，立即在週會中提出
4. 所有交付物必須經過程式碼審查才能標記為完成
