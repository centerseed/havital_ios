---
type: TD
id: TD-apple-watch-app-mvp
spec: SPEC-apple-watch-app-mvp
status: Draft
l2_entity: apple-watch-app
created: 2026-05-07
updated: 2026-05-07
version: "0.3"
backlog: true
backlog_reason: "Spec 為 backlog 規劃；本 TD 為工時/風險評估文件，不可被當作 ready-to-build 設計直接派任務"
---

# 技術設計：Paceriz Apple Watch App 主線（MVP）

> ⚠️ **規劃文件聲明**：本 TD 對應的 SPEC 為 backlog，觸發條件為「Android 主線上線並穩定後啟動」。本文件目的是讓 Architect 在 Android 工期評估同時把 Watch App 的工時 / 風險預估完，**非** ready-to-build 設計。所有 [TBD-IMPL] 標記的細節都需在啟動前重新驗證（watchOS API 可能改版、HealthKit dedup 行為可能變化）。

---

## 調查報告

### 已讀文件 / Codebase 路徑

- `docs/specs/SPEC-apple-watch-app-mvp.md` v0.5 — 26 條 P0 AC，含 AC-WATCH-23（端到端 dedup 驗收）+ AC-WATCH-24（complication MVP，corner / circular family）+ AC-WATCH-25 / 26（HKWorkout schema parity 與 auto-pause）。
- `docs/specs/SPEC-training-record-and-workout-detail.md` — Watch 摘要為其子集；AC-WATCH-23 直接掛此 spec 的紀錄頁驗收。
- `docs/specs/SPEC-workout-upload-error-noise-filtering.md` + `docs/designs/TD-workout-upload-error-noise-filtering.md` — 沿用 cancellation / protected data 過濾規則；Watch 透過 HealthKit 同步進來的紀錄會走同一條上傳鏈。
- `docs/specs/SPEC-heart-rate-and-training-readiness-surfaces.md` — Watch 取用其心率區間設定，**唯讀**。
- `Havital/Services/Integrations/AppleHealth/AppleHealthWorkoutUploadService.swift` — 既有 HealthKit upload 路徑：
  - L632/703/1120/1475/1517：已抓 `workout.sourceRevision.source.bundleIdentifier` + `name`，但目前**沒有針對自家 Watch App bundle id 做 prefer 規則**。
  - L1322-1325 / L1528：Apple Health / Fitness 來源已被當作 fallback 過濾（避免把空殼 workout 當有效資料）。
  - L862/895：metadata 已會讀 `HKMetadataKeyDeviceManufacturerName` / `HKMetadataKeyDeviceName`。**沒有讀任何 Paceriz-specific metadata key**——這是 Watch 寫入時可放 dedup token 的乾淨入口。
- `Havital/Core/Infrastructure/HealthKitManager.swift` + `Havital/Features/Workout/Infrastructure/WorkoutBackgroundUploader.swift` — 既有背景同步管線；Watch 寫入後的 workout 會自動被吃進來，**不需要新管線**。
- `Havital/Features/TrainingPlanV2/Domain/Entities/WeeklyPlanV2.swift` — Domain entity；可作為 Watch snapshot 的來源型別（需設計 Watch-side 縮減版 DTO，去掉 backend-only 欄位以省 WCSession payload）。
- `Havital/Info.plist` / `Havital.xcodeproj/project.pbxproj` — `IPHONEOS_DEPLOYMENT_TARGET = 18.0`。**目前沒有 watchOS target / scheme**——啟動時要新建 `HavitalWatch` target（WatchKit App + WatchKit Extension 已合併為單一 watchOS App target，watchOS 9+ 起的標準）。
- `Havital/Resources/Localizable.xcstrings`（推測，依 i18n 規則）— Watch 必須與 iOS 共用同一份字串資源；watchOS 從 iOS app bundle 拷貝資源是標配做法。

### 搜尋但未找到

- 任何 `WCSession` / `WatchConnectivity` 相關程式 — 確認目前 codebase **完全沒有 Watch companion 邏輯**，要從零開始建立。
- 任何 `HKWorkoutSession` builder 程式 — iOS 端無此使用（iOS 端只讀 HealthKit，不寫 workout）；watchOS 端要全新實作。
- 既有 watchOS target / scheme — 無。

### 我不確定的事 [TBD-IMPL]

- [TBD-IMPL] watchOS deployment target：建議 watchOS 10.0+（iPhone 端已 iOS 18，對應 Watch Series 4+ 仍可跑 watchOS 10），但啟動實作前要重查當下市佔。
- [TBD-IMPL] `HKWorkoutBuilder` 的 metadata 欄位是否在所有 watchOS 版本都會經 HealthKit sync 正確帶到 iPhone 端 `HKWorkout.metadata`——文件層級確認可，但 backlog 啟動前應先在實機跑 spike 驗證。
- [TBD-IMPL] watchOS 上 `HKLiveWorkoutBuilder` 的暫停 / 繼續 API 行為對 distance / time 累計的細節（是否要自建累計層）。

### 結論

**可以開始技術設計（規劃文件）**。但 [TBD-IMPL] 標記的細節必須在 backlog 觸發、啟動實作前以 spike 驗證，不可直接照本 TD 開工。

---

## Spec 衝突檢查

| 對照 Spec | 衝突類型 | 結論 |
|---|---|---|
| SPEC-training-record-and-workout-detail | 範圍重疊（紀錄頁顯示） | **無衝突**：Watch 摘要為子集，紀錄頁仍是 SSOT |
| SPEC-workout-upload-error-noise-filtering | 介面不一致（HealthKit 同步錯誤分類） | **無衝突**：Watch 寫入的 workout 走同一條 upload 鏈，沿用既有錯誤分類 |
| SPEC-heart-rate-and-training-readiness-surfaces | 需求矛盾（區間設定來源） | **無衝突**：Watch 唯讀，由 iPhone 設定後同步過來 |
| SPEC-app-shell-routing-and-global-guardrails | 範圍重疊（全域 routing） | **無衝突**：Watch 為獨立 App，不參與 iPhone routing |
| SPEC-training-hub-and-weekly-plan-lifecycle | 介面合約（weekly plan schema） | **無衝突**：Watch snapshot 為唯讀子集 |
| AC-WATCH-P2-03（standalone LTE） vs AC-WATCH-16（不繞過 HealthKit） | 同 SPEC 內衝突 | **已在 SPEC 內處理**：明標「Hard Requirement，啟動需另開 SPEC」，本 TD 不涉及 |

**結論：無衝突。**

---

## 開放問題決議

> 以下決議**取代** SPEC 結尾「開放問題」段。SPEC 為 PM 文件，不改；決議落在本 TD。

### Q1：HealthKit dedup 策略（呼應 AC-WATCH-16 / AC-WATCH-23）

> **v0.2 用戶拍板：採簡單版（純 metadata uuid 單一防線）**，不採用 v0.1 建議的 A+B 雙保險。理由：dedup 邏輯越複雜越難 debug；用 uuid 為唯一 key + 三條有效性防線即可，其他 source 的 workout 沿用既有 source bundle 過濾路徑（不在 Watch dedup 範圍內）。

#### 決議：單一 dedup key = `com.paceriz.workout_uuid`

- Watch 端 `HKWorkoutBuilder.addMetadata` 只寫 `com.paceriz.workout_uuid` (String, UUID v4) 一個 key 作為 dedup token。
- iOS 端 upload service：以此 uuid 作為 Watch 來源 workout 的唯一識別。
- 後端 ingest endpoint：新增 optional `paceriz_workout_uuid` 欄位，存入 Firestore 作為 dedup fingerprint 的主 key（若存在）。

#### uuid 有效性三條防線（用戶特別交代的核心）

> 用戶要求明確記錄 uuid 在整個 pipeline 的有效性保證，避免任何一層無聲失敗導致 dedup 崩盤。**任何一條防線觸發都必須 log，QA 與 production monitoring 才能在 metadata 異常時抓得到。**

| # | 位置 | 條件 | 行為 |
|---|---|---|---|
| **防線 1** | Watch 端 `HKWorkoutBuilder.addMetadata` 呼叫前 | uuid 必須非空 + 必須符合 UUID v4 regex `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` | **不符 → fail-fast 不寫入 HealthKit + log error**（不得寫入無 uuid 或格式錯誤的 workout）|
| **防線 2** | iOS `AppleHealthWorkoutUploadService` 讀到 workout 時 | `workout.metadata?["com.paceriz.workout_uuid"]` 為 nil 或非 String | **log warning + skip uuid-based dedup**，該 workout fallback 走既有 source bundle 過濾路徑（不是直接放行；若既有過濾判定為非 Paceriz 來源仍會被過濾掉）|
| **防線 3** | iOS upload service 上傳前（query Firestore） | 同 uuid 已存在於 Firestore `workouts` collection | **reject 第二筆 + log error**（不默默覆蓋既有紀錄；同 uuid 第二筆視為同步異常或惡意重送）|

**實作位置：**
- 防線 1：watchOS `WorkoutBuilderWriter.swift`（新增）。validation function 在 add metadata 之前 call，失敗則 throw + 不執行 `endCollection / finishWorkout`。
- 防線 2：`AppleHealthWorkoutUploadService.swift`（修改）。讀 metadata 時若無 uuid → fallback to existing source filter pass，不在新 pass 內處理。
- 防線 3：iOS upload pre-flight check 或 backend ingest endpoint 任一處實作。**建議放 backend** —— iOS 端只負責送上去，dedup 衝突判定在後端 SSOT，避免裝置端 cache 不一致。

#### 後端 dedup 規則

- 新增 optional `paceriz_workout_uuid` 欄位（保留向後相容）。
- 若請求帶 uuid：以 `(uid, paceriz_workout_uuid)` 為主 key，同組合已存在 → 防線 3 reject。
- 若請求未帶 uuid（既有 iOS 健康同步路徑、其他 source）：fallback 既有 `(uid, start_time, distance, source)` fingerprint。
- 舊資料不受影響（uuid 欄位為 optional）。

**影響 AC：** AC-WATCH-16（uuid 有效性 + Watch 端 fail-fast 已寫入 SPEC v0.4）、AC-WATCH-23（端到端紀錄一次且僅一次）。

**Risk：** 防線 2 fallback 到既有 source bundle 過濾後，若使用者裝了其他 watchOS 第三方 app 在同時段也跑 workout，可能與 Paceriz 既有過濾規則重疊。MVP 不額外處理；backlog 啟動 spike 時驗證實機行為。

---

### Q2：GPS 誤差容忍度（分段切換，呼應 AC-WATCH-11 / AC-WATCH-12 / AC-WATCH-20）

**選項：**
- **A. 嚴格距離**：累計 ≥ 目標 → 切換。
- **B. ±5% 容差**：≥ 目標 × 0.95 即視為達標。
- **C. 嚴格距離 + 強制 timeout**：嚴格距離為主，但若該分段預估剩餘時間 < 0（GPS 漂移導致累計卡住）則 fallback。

**建議：採 A（嚴格距離）+ Q6 的 5 秒倒數補償**。

理由：跑者對「800m 間歇」的心理期待是「跑完 800m」，不是「跑到 760m」。GPS 誤差靠 5 秒倒數提示（Q6）讓跑者主動感知即可，系統不應靜默放水 5%——間歇訓練的精度是 Paceriz 對 Garmin 的差異化價值。

**影響 AC：** AC-WATCH-11, AC-WATCH-20。
**Risk：** GPS 訊號極差（隧道、室內跑步機）會卡住分段——MVP 不處理，由 Q4 訓練中斷恢復策略接住（手動結束 + 紀錄已跑部分）。

---

### Q3：watchOS 最低版本

**選項：**
- **A. watchOS 10.0+**：覆蓋 Apple Watch Series 4+，對齊 iPhone 端 iOS 18 最小依賴。
- **B. watchOS 11.0+**：可用最新 `WorkoutKit` API（提供 prebuilt workout structure），covered set 較少。
- **C. watchOS 9.0+**：覆蓋 Series 3，但 Series 3 已不能升 watchOS 9，等於沒覆蓋更多。

**建議：採 A（watchOS 10.0+）。**

理由：
- 與 iOS 18 對應的 Watch 矩陣最大公約數。
- watchOS 10 的 `HKLiveWorkoutBuilder` API 已穩定 4 年，有充足社群資料。
- WorkoutKit（watchOS 11）雖好但會把 covered set 砍到 Series 6+，95 個 MAU 不能再縮小。

**影響 AC：** 全體（部署最低版本）。
**Risk：** 若 backlog 啟動時 Apple 已釋出 watchOS 12，建議重新評估是否提到 watchOS 11 取得 WorkoutKit 紅利。

---

### Q4：訓練中斷恢復行為

**選項：**
- **A. Fail-fast**：當機 / 沒電後重啟，原 workout session 結束，已跑部分依 watchOS 系統行為（HealthKit 通常會保留到當機點的資料），不嘗試恢復課表 snapshot。
- **B. 持久化 snapshot**：Watch 本地把訓練狀態（當前分段、累計距離）每 30 秒寫一次到 `UserDefaults` / file，重啟後彈出「是否恢復未完成訓練？」。

**建議：採 A（Fail-fast，跟 SPEC 預設一致）。**

理由：
- Watch 訓練中當機極罕見（Apple Watch Series 4+ 在訓練模式硬體穩定度高）。
- 持久化路徑會引入「分段切換時刻 vs 寫盤時刻」的競態（萬一在切換瞬間當機，恢復後分段狀態不一致）。
- MVP 階段不值得這個複雜度。
- HealthKit 仍會保留到當機點的軌跡，使用者透過既有 iOS App workout sync 路徑仍能拿到「半條 workout」紀錄。

**影響 AC：** 無新增 AC（這是 SPEC 已預留的 Architect 確認項）。
**Risk：** 若 KOL 反映「我跑 30 分鐘 Watch 當機資料全沒了」會被質疑體驗差——但對應應該由「為什麼會當機」debug，不是用恢復邏輯遮掩。

---

### Q5：複雜分段（間歇 / 組合）的 Watch UI 呈現

**選項：**
- **A. 單頁主畫面（依 SPEC AC-WATCH-10）**：當下配速 + 當前分段目標 + 剩餘 + 心率，一頁四指標。
- **B. 主畫面 + 可滑動下一頁顯示「整體分段進度」**：第一頁同 A，滑下一頁顯示「3/8 組」進度條。
- **C. Designer 進駐後決定**：MVP 只承諾 A，B 留給 P1。

**建議：採 C（MVP 只做 A），但 TD 預留 B 的擴展點。**

理由：
- AC-WATCH-10 只規範「當前分段」資訊，沒要求「整體進度」。
- watchOS 雙頁 UI 在跑步中切換成本（手動滑動）反而干擾，不見得是好 UX。
- Designer 進駐前不下死規格，避免做了又改。

**影響 AC：** AC-WATCH-09, AC-WATCH-10。
**Risk：** Designer 看了實機後可能要求加第二頁（「跑者想知道我跑到第幾組」），TD 預留 page-based UI 容器即可，不增加重做成本。

---

### Q6：AC-WATCH-08 5 秒倒數的計算基準（時間 vs 距離分段）

> 註：AC-WATCH-08 是「使用 watchOS GPS / 心率」，5 秒倒數實為 **AC-WATCH-12**。SPEC 開放問題第 6 條原文編號有誤，本 TD 以 AC-WATCH-12 處理。

**選項：**
- **時間型分段**：直接倒數秒（`segment.targetSeconds - elapsedSeconds <= 5` → 觸發）。
- **距離型分段**：依當下配速推估（`(targetDistance - distance) / currentPace_m_per_s <= 5` → 觸發）。

**建議：**
1. 時間型 → 直接秒數倒數（trivial）。
2. 距離型 → 用「最近 30 秒滾動平均配速」推估，誤差容忍 ±2 秒（不重複觸發即可）。
3. 抑制重複觸發：同分段一旦觸發過就 latch，直到分段切換才解鎖。

**配速來源細節：** 不用 instantaneous pace（GPS 抖動大），改用 `HKLiveWorkoutBuilder` 的 statistics 取最近窗口平均。

**影響 AC：** AC-WATCH-12。
**Risk：** 若使用者突然加速 / 減速，推估誤差會放大；±2 秒容忍是合理 trade-off。

---

### Q7：Complication 升 P0（v0.2 已拍板）

> **v0.2 用戶拍板：升 P0**。SPEC v0.4 已新增 AC-WATCH-24，範圍為 corner family + circular family；其他 family 留 AC-WATCH-P1-03。

**決議內容：**
- corner / circular complication 必做（MVP 範圍）
- 顯示內容：Paceriz logo + 今日課表簡述（「8K Easy」「800m × 5」「休息日」「無課表」）
- 點擊 → 進入 Paceriz Watch App 主頁
- 其他 family（modular / graphic / inline 等）留 P1（AC-WATCH-P1-03 已對應改寫）

**實作要點：**
- 用 watchOS 10+ `WidgetKit` 統一 API（ComplicationKit 已棄用）
- Timeline provider 從 `WorkoutSnapshotStore` 取今日課表，每日 00:00 + 課表變更時 reload timeline
- watchOS 系統對 widget refresh budget 有限制（每分鐘 ~1 次），不可期待即時更新；課表變更時主動 call `WidgetCenter.shared.reloadAllTimelines()` 推一次
- Complication tap → 透過 `widgetURL` deep link 進 Watch App 主頁

**影響 AC：** 新增 AC-WATCH-24（P0）；AC-WATCH-P1-03 改為「其他 complication family」（P1）。
**工時：** +3 天（已併入下方總計 effort estimate）。
**Risk：** 實機若 watchOS 更新延遲導致 complication 顯示昨日課表（GTM 素材尷尬），需依 widget refresh budget 設計 timeline reload 策略——backlog 啟動時 spike 驗證。

---

### Q8：zh-HK 語系 fallback 規則

**選項：**
- **A. zh-HK → zh-TW（SPEC 預設）**：Watch 端把 zh-HK 系統語言映射到 zh-TW 翻譯檔。
- **B. 共用 zh-Hant 一份**：iOS App 與 Watch App 都改用 `zh-Hant`（涵蓋 zh-TW + zh-HK + zh-Hant），iOS 端也要跟著改。
- **C. zh-HK 維持系統 fallback（Apple 預設）**：什麼都不做，依 iOS App 既有行為。

**建議：採 A（zh-HK → zh-TW），不動 iOS App。**

理由：
- 改 iOS App 的 locale code（B 選項）= 大改動 + 風險全 zh-TW 用戶被影響，CP 值低。
- iOS App 既有行為（推測為 C）若已在 zh-HK 使用者上沒出問題，Watch 沿用同樣行為即可——但 SPEC 寫死要 fallback to zh-TW，所以 Watch 端在 `Localizable.xcstrings` 裡明寫 zh-HK fallback chain to zh-TW。
- 風險低：zh-HK 與 zh-TW 90% 字串一致。

**影響 AC：** AC-WATCH-19。
**Risk：** 香港使用者偶爾會看到台灣用語（「裡面」vs「裏面」、「公里」vs「公里」），但這已是 iOS App 既有狀態，不增加新問題。

---

## AC Compliance Matrix（P0 全部 26 條）

> Test stub path 標 [TBD] 表示 backlog 階段不建立 stub 檔案；啟動實作時由 Developer 建立。

| AC ID | 概要 | 實作位置（規劃） | Test stub | 備註 |
|---|---|---|---|---|
| AC-WATCH-01 | iPhone 登入自動同步 Watch | Watch `AuthBridge` + iOS `WCSessionDelegate` 端 | [TBD] `HavitalWatch/AuthBridgeTests.swift` | watchOS 透過 paired session 自動拿；Apple 標配 |
| AC-WATCH-02 | 未配對 / iPhone 未登入引導卡片 | Watch `WelcomeView` | [TBD] | 純 UI，不會啟動訓練 |
| AC-WATCH-03 | 顯示今日課表（類型 / 距離 / 分段摘要） | Watch `TodayWorkoutView` ← `WorkoutSnapshotStore` | [TBD] | 來源由 WCSession sync from iPhone |
| AC-WATCH-04 | 休息日明確顯示且禁啟動 | Watch `TodayWorkoutView` | [TBD] | UI rule，不渲染「開始訓練」按鈕 |
| AC-WATCH-05 | 無本週課表 → 引導去 iPhone 產生 | Watch `TodayWorkoutView` empty state | [TBD] | |
| AC-WATCH-06 | Watch 直接啟動今日課表 | Watch `WorkoutLauncher` | [TBD] | 前提：snapshot ready + 權限 OK |
| AC-WATCH-07 | 啟動時 snapshot 課表（訓練中不變） | Watch `ActiveWorkoutSession` (immutable plan binding) | [TBD] | 寫入 session 起即 freeze |
| AC-WATCH-08 | 使用 watchOS GPS / 心率 | Watch `HKLiveWorkoutBuilder` (no iPhone GPS) | [TBD] | 不引用 CoreLocation from iPhone |
| AC-WATCH-09 | 輕鬆跑：配速 / 心率 / 距離 / 時間 | Watch `EasyRunMetricsView` | [TBD] | 1Hz 更新 |
| AC-WATCH-10 | 間歇 / 組合 / 漸速：含目標配速範圍 / 剩餘 | Watch `IntervalMetricsView` | [TBD] | |
| AC-WATCH-11 | 距離型分段自動切換 | Watch `SegmentTransitionEngine` | [TBD] | 嚴格距離（Q2 決議）|
| AC-WATCH-12 | 分段結束前 5 秒提示 | Watch `SegmentTransitionEngine` + `HapticPlayer` | [TBD] | 計算規則見 Q6 |
| AC-WATCH-13 | 暫停 / 繼續 | Watch `ActiveWorkoutSession.pauseResume` | [TBD] | 暫停期間 GPS 取樣由 watchOS workout session 自動管 |
| AC-WATCH-14 | 手動結束 → 摘要 | Watch `ActiveWorkoutSession.finish` | [TBD] | |
| AC-WATCH-15 | 摘要四指標 | Watch `WorkoutSummaryView` | [TBD] | |
| AC-WATCH-16 | 寫入 Apple Health（含 uuid metadata + fail-fast 防線 1） | Watch `WorkoutBuilderWriter` + `HKWorkoutBuilder.finishWorkout` | [TBD] | uuid v4 regex 驗證；不符不寫入 + log（Q1 防線 1） |
| AC-WATCH-17 | iPhone 不在身邊也能完成訓練 | Watch local snapshot cache | [TBD] | snapshot freshness 邊界 = 今日 |
| AC-WATCH-18 | iPhone 不在身邊且無 snapshot 阻擋 | Watch `WorkoutLauncher` precondition | [TBD] | |
| AC-WATCH-19 | i18n 一致（zh-TW / ja-JP / en-US，zh-HK fallback zh-TW） | Watch `Localizable.xcstrings`（與 iOS 共用） | [TBD] | Q8 決議 |
| AC-WATCH-20 | 時間型分段自動切換 | Watch `SegmentTransitionEngine` | [TBD] | 同 AC-WATCH-11 引擎 |
| AC-WATCH-21 | 首次使用請求所有必要權限 | Watch `PermissionGate` (HealthKit / Location / Motion) | [TBD] | 啟動 workout 前序列請求 |
| AC-WATCH-22 | 權限被拒阻擋啟動 + 引導 | Watch `PermissionDeniedView` | [TBD] | iOS 系統不會再彈，引導去設定 |
| **AC-WATCH-23** | **端到端 Paceriz 紀錄頁出現一次且僅一次（2 分鐘內）** | iOS `AppleHealthWorkoutUploadService`（uuid dedup + 防線 2 fallback） + 後端 ingest（`paceriz_workout_uuid` 欄位 + 防線 3 衝突 reject） | [TBD] **整合測試 + 實機測試** | 核心驗收；v0.4 時間邊界 30s → 2min；Q1 三條防線 |
| **AC-WATCH-24** | **Complication（corner / circular family）顯示 logo + 今日課表 + 點擊進主頁** | Watch `WidgetKit` complication provider + timeline reload on plan change | [TBD] | v0.4 升 P0（Q7）；其他 family 留 AC-WATCH-P1-03 |
| **AC-WATCH-25** | **HKWorkout schema 與內建跑步 App parity（含 lap event 自動每 km 寫入）** | Watch `HKLiveWorkoutBuilder` wrapper + `LapEventEmitter`（每 km 邊界）+ 多 quantity sample collectors（HR / pace / cadence / power） | [TBD] **整合測試（內建 App vs Paceriz workout by-field diff harness）** | v0.5 新增；`HKLiveWorkoutBuilder` 不會自動 emit lap，須手動實作 |
| **AC-WATCH-26** | **Auto-pause 行為與內建一致（`.motionPaused` / `.motionResumed`）** | Watch `HKLiveWorkoutBuilder` wrapper + 監聽 system auto-pause event | [TBD] | v0.5 新增；尊重使用者 iOS Settings → 健身 開關 |

### P1 / P2 補充
- AC-WATCH-P1-01（心率區間提示）— 規劃位置 Watch `HeartRateZoneIndicator`
- AC-WATCH-P1-02（每公里 lap）— 規劃位置 Watch `LapNotifier`
- AC-WATCH-P1-03（complication 其他 family）— v0.4 已縮小範圍至非 corner / circular family；core complication 已升 AC-WATCH-24
- AC-WATCH-P2-01 / P2-02 / P2-03 — 不在 MVP 範圍

---

## 元件架構

### 整體拓撲

```
┌────────────────────────────────────────────────────────────┐
│ Apple Watch (HavitalWatch target — watchOS 10.0+)          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Presentation                                          │  │
│  │  - TodayWorkoutView / WorkoutSummaryView /            │  │
│  │    IntervalMetricsView / EasyRunMetricsView /         │  │
│  │    PermissionDeniedView / WelcomeView                 │  │
│  └────────────────────┬─────────────────────────────────┘  │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │ Domain                                                │  │
│  │  - ActiveWorkoutSession (immutable plan binding)      │  │
│  │  - SegmentTransitionEngine                            │  │
│  │  - WorkoutLauncher (precondition gate)                │  │
│  │  - PermissionGate                                     │  │
│  │  - WorkoutSnapshotStore                               │  │
│  └────────────────────┬─────────────────────────────────┘  │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │ Data / Infra                                          │  │
│  │  - HKLiveWorkoutBuilder wrapper                       │  │
│  │  - WCSessionClient（Watch 側）                         │  │
│  │  - LocalSnapshotCache (UserDefaults / file)           │  │
│  │  - HapticPlayer                                       │  │
│  └────────────────────┬─────────────────────────────────┘  │
│           HealthKit write ↓        ↑ WCSession             │
└───────────┼─────────────────────────┼──────────────────────┘
            │                         │
            ▼                         ▼
┌─────────────────────────────────────────────────────────────┐
│ iPhone (existing Havital app)                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ NEW: WatchCompanionService                          │    │
│  │  - WCSessionDelegate                                │    │
│  │  - 推送：auth state / today plan snapshot / HR zones│    │
│  │  - 接收：Watch app 啟動 ping（diagnostics）         │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ MODIFIED: AppleHealthWorkoutUploadService           │    │
│  │  - Pass 1: 按 com.paceriz.workout_uuid dedup        │    │
│  │  - Pass 2: 既有 source-bundle 過濾                  │    │
│  │  - 上傳時帶上 paceriz_workout_uuid 給後端           │    │
│  └─────────────────────────────────────────────────────┘    │
│  HealthKit ←───── 系統同步 ─────── (Watch 寫入)             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ 既有 upload pipeline（無新管線）
┌─────────────────────────────────────────────────────────────┐
│ Backend (Cloud Run, paceriz-prod / havital-dev)             │
│  - workout ingestion endpoint                                │
│  - MODIFIED: dedup 加 paceriz_workout_uuid 欄位             │
│  - 其他無變更                                                │
└─────────────────────────────────────────────────────────────┘
```

### 分工

| 層 | Owner | 工時粗估 |
|---|---|---|
| Watch app target 建立 + scheme + signing | iOS Developer | 2 天 |
| Watch Presentation（所有 View） | iOS Developer + Designer | 5 天 |
| Watch Domain（session / segment / launcher） | iOS Developer | 7 天 |
| Watch Data（HKLiveWorkoutBuilder + WCSession + cache） | iOS Developer | 5 天 |
| iOS WatchCompanionService（新增） | iOS Developer | 3 天 |
| iOS AppleHealthWorkoutUploadService 改 dedup | iOS Developer | 2 天 |
| Backend dedup 欄位增補 + 防線 3 衝突 reject | Backend Developer | 1 天 |
| i18n 字串補齊 | iOS Developer | 1 天 |
| 實機測試（含 dedup 三條防線驗證 + complication 實機） | QA + Architect | 5 天 |
| Complication（corner / circular family，v0.4 P0） | iOS Developer + Designer | 3 天 |
| Lap event 自動偵測（每 km 邊界 emit `.lap`，AC-WATCH-25） | iOS Developer | 2 天 |
| Auto-pause 整合（`.motionPaused` / `.motionResumed`，AC-WATCH-26） | iOS Developer | 2 天 |
| HKWorkout parity test harness（內建 App vs Paceriz by-field diff script） | iOS Developer + QA | 2 天 |
| iOS App parser hardening（解析 lap / pause events / 多 quantity samples，與內建一致） | iOS Developer | 3 天 |
| **總計** | | **~42–44 工程日（單人全職，約 8–9 週）**；加 App Store 審核 buffer 總計 **10–11 週**（含 v0.5 新增 9 天工作量；不含 backlog 啟動前 spike）|

---

## 介面合約清單

### 1. iPhone → Watch（WCSession message types）

| Message | Direction | Payload (簡化) | 觸發時機 |
|---|---|---|---|
| `auth.state` | iPhone → Watch | `{ logged_in: Bool, user_id: String? }` | iPhone 登入 / 登出時 push |
| `today_plan.snapshot` | iPhone → Watch | `{ date: "yyyy-MM-dd", plan: WatchPlanSnapshotDTO? }` | iPhone 產生 / 編輯週課表後 push；Watch 啟動時 pull |
| `hr_zones` | iPhone → Watch | `{ zones: [HRZoneDTO] }` | iPhone 修改心率設定後 push |

### 2. Watch → HealthKit（write，含防線 1 fail-fast）

```swift
// 簡單版 dedup：單一 metadata key
private static let uuidV4Regex = try! NSRegularExpression(
    pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
)

func writeWorkout(builder: HKWorkoutBuilder, uuid: String) throws {
    // 防線 1：uuid 有效性檢查；不符 fail-fast 不寫入
    let range = NSRange(uuid.startIndex..., in: uuid)
    guard !uuid.isEmpty,
          Self.uuidV4Regex.firstMatch(in: uuid, range: range) != nil else {
        logger.error("[Watch] invalid workout_uuid: \(uuid) — abort write")
        throw WatchWorkoutError.invalidUUID
    }

    let metadata: [String: Any] = [
        "com.paceriz.workout_uuid": uuid   // 唯一 dedup key
    ]
    builder.addMetadata(metadata) { _, _ in }
    builder.endCollection(withEnd: Date()) { _, _ in
        builder.finishWorkout { _, _ in }
    }
}
```

> 簡單版設計刻意只寫 `workout_uuid` 一個 key。若未來需要 `plan_id` / `segment_count` 等診斷欄位，再評估擴充——MVP 先確保 uuid pipeline 穩定。

### 3. iPhone HealthKit Read（簡單版 dedup + 防線 2）

修改 `AppleHealthWorkoutUploadService`：
```swift
// 防線 2：讀 metadata；無 uuid → log warning + skip uuid dedup（fallback 既有 source filter）
func splitByParcerizUUID(_ workouts: [HKWorkout]) -> (withUUID: [HKWorkout], fallback: [HKWorkout]) {
    var withUUID: [HKWorkout] = []
    var fallback: [HKWorkout] = []
    for workout in workouts {
        if let uuid = workout.metadata?["com.paceriz.workout_uuid"] as? String,
           !uuid.isEmpty {
            withUUID.append(workout)
        } else {
            // 防線 2：log warning，走既有 source bundle 過濾路徑
            logger.warning("[Upload] workout missing paceriz_workout_uuid: \(workout.uuid) — fallback to source filter")
            fallback.append(workout)
        }
    }
    return (withUUID, fallback)
}
```

- `withUUID` workouts：上傳時帶 `paceriz_workout_uuid` 給後端，由後端防線 3 衝突檢查。
- `fallback` workouts：走既有 Apple Health / Fitness source bundle 過濾路徑（既有邏輯 L1322-1325 / L1528），不在新 dedup pass 內處理。

### 4. Backend ingest endpoint（含防線 3）

新增 optional 欄位：
```json
{
  "workout": {
    "source": "apple_health",
    "paceriz_workout_uuid": "<uuid v4>",  // NEW, optional
    "start_time": "...",
    ...
  }
}
```

後端 dedup 規則：
1. 若請求帶 `paceriz_workout_uuid`：query Firestore `workouts` collection where `(uid, paceriz_workout_uuid)` 已存在
   - **防線 3：已存在 → reject 第二筆 + log error**（不默默覆蓋；同 uuid 第二筆視為同步異常或重送）
   - 不存在 → 寫入新紀錄
2. 若請求未帶 uuid → fallback 既有 `(uid, start_time, distance, source)` fingerprint。

### 5. WatchPlanSnapshotDTO（Watch ↔ iPhone）

```swift
struct WatchPlanSnapshotDTO: Codable {
    let date: String                    // yyyy-MM-dd（local）
    let workoutType: String             // "easy_run" / "interval" / ...
    let totalDistanceMeters: Double?
    let totalSeconds: Int?
    let segments: [WatchSegmentDTO]
    let planId: String                  // 對應 WeeklyPlanV2 planId
    let snapshotVersion: Int            // 漲數字便於 Watch 端做版本比對
}

struct WatchSegmentDTO: Codable {
    let kind: String                    // "warmup" / "interval" / "rest" / "cooldown"
    let measure: String                 // "distance" / "time"
    let targetMeters: Double?
    let targetSeconds: Int?
    let targetPaceLowSecPerKm: Int?
    let targetPaceHighSecPerKm: Int?
    let label: String                   // i18n 過的顯示名（"800m × 5"）
}
```

**設計原則：** Watch DTO 不直接重用 iOS Domain `WeeklyPlanV2` —— 太重，含 backend-only 欄位。Watch 端用最小化 DTO，iPhone companion service 負責從 `WeeklyPlanV2` 投影出 `WatchPlanSnapshotDTO`。

---

## HKWorkout Parity Test Plan（對應 AC-WATCH-25 / 26）

### Parity 比對欄位 checklist

| # | 欄位 / 事件 | 比對方式 | 容忍 |
|---|---|---|---|
| 1 | `workoutActivityType` | enum equality | 必須 == `.running` |
| 2 | `totalDistance` (HKQuantity) | 數值 + unit | ≤ 1m 差異（GPS 量測誤差） |
| 3 | `totalEnergyBurned` (HKQuantity) | 數值 + unit | ≤ 5 kcal（兩 App 算法差異容許範圍） |
| 4 | `duration` | 秒數 | ≤ 1s |
| 5 | `HKWorkoutRoute` 是否存在 + location count > 0 | route query | route 必須存在；location count > 0 |
| 6 | `HKWorkoutEvent.pause` / `.resume` 序列 | event sequence equality | 操作一致時序列必須完全一致 |
| 7 | `HKWorkoutEvent.lap` 數量 | lap count == ⌊totalDistance / 1000⌋ | 必須相等 |
| 8 | `HKWorkoutEvent.motionPaused` / `.motionResumed`（AC-WATCH-26） | 序列 | Auto-pause 開啟且實際停止 → 必須有；關閉 → 必須無 |
| 9 | 心率 sample 數 / 取樣率 | sample count，期望 ≥ duration（每秒至少一筆） | 兩 App 取樣率須一致 |
| 10 | 配速 / 步頻 / 跑步功率 sample 是否存在 | quantity sample query | 必須存在（watchOS 10+ runningPower）|
| 11 | metadata `HKMetadataKeyIndoorWorkout` | bool equality | 必須一致 |
| 12 | source name | NOT compared | 唯一允許差異欄位 |

### Test harness 建議

寫一支 debug script（建議放 `Havital/Scripts/HealthKitParityCheck/`），從 HealthKit 撈最近兩筆 running workout（一筆 `com.apple.workout` 內建 + 一筆 `com.paceriz.watch`）做欄位 diff，輸出 PASS / FAIL 報告。

- 形式：iOS App 內建 debug menu 或 standalone `swift` script（透過 HealthKit 授權）
- 輸出：每欄位 expected / actual / pass，整體 verdict
- 列入 backlog 啟動後的 **回歸測試 + 上架前必跑**

### 上架前必跑場景

1. **Easy run 5 km，無暫停**：lap event = 5、無 pause event
2. **Easy run 5 km，手動暫停 1 次**：lap event = 5、pause event = 1、resume event = 1
3. **Interval 800m × 5（總約 6 km）**：lap event = 6（每 km 邊界，與分段切換獨立）；分段切換用 `.segment` event，不混用 `.lap`
4. **Auto-pause 開啟，跑步中於紅綠燈停 30s**：必須有 `.motionPaused` + `.motionResumed`
5. **Auto-pause 關閉，跑步中停 30s**：必須無 `.motionPaused`

每個場景 with 內建 App + Paceriz Watch 各跑一次，跑 parity diff harness。任一場景 fail → 阻擋上架。

---

## iOS App Parser Hardening（AC-WATCH-25 連動 iOS 工作）

> 這是 iOS 端工作，不是 Watch 端。AC-WATCH-25 要求「parser 解出來的欄位必須與內建跑步 App parity」，但 Paceriz iOS 既有 parser 可能在某些 events 上行為不一致。

### 範圍

- `AppleHealthWorkoutUploadService` 解析 workout 時，必須完整讀取：
  - `HKWorkoutEvent.lap`（用於課表完成度核對；目前 iOS 端可能略過 lap event）
  - `HKWorkoutEvent.pause` / `.resume`（用於計算「不含暫停的有效訓練時長」，AC-WATCH-23 要求）
  - `HKWorkoutEvent.motionPaused` / `.motionResumed`（用於與「跑步中停紅綠燈」場景時長一致）
  - `HKQuantityTypeIdentifier.runningPower`（watchOS 10+ 才有；舊 parser 可能略過 unknown identifier）
- 對 Paceriz Watch 寫入的 workout 行為必須與內建一致——**parser 不可因 source name 不同而走不同分支**（除了既有 source bundle dedup pass 外）

### 工時 / Risk

- +3 天（已併入下方 Effort estimate）
- Risk：parser 改動會影響「既有 iOS 用戶從內建跑步 App 同步進來的紀錄」——必須做回歸測試（拿一筆既有用戶的內建 workout，改動前後 parser 輸出做 diff，確認無 regression）

---

## HKLiveWorkoutBuilder Lap Emission 實作要點

> 重要實作 trap：watchOS 內建跑步 App 會自動每 km emit `HKWorkoutEvent.lap`，但 **`HKLiveWorkoutBuilder` 並不會自動寫**。Paceriz 必須自己監聽距離累計，每跨 1 km 邊界手動 `addWorkoutEvents([.lap])`。

### 實作骨架

```swift
final class LapEventEmitter {
    private var lastLapKm: Int = 0  // 已 emit 的最高 km 邊界

    func onDistanceUpdate(meters: Double, builder: HKLiveWorkoutBuilder) {
        let currentKm = Int(meters / 1000.0)
        guard currentKm > lastLapKm else { return }

        // 每跨一個 km 邊界 emit 一次 .lap event
        for km in (lastLapKm + 1)...currentKm {
            let timestamp = Date()  // 實作上應改為精準的 km 邊界時刻
            let event = HKWorkoutEvent(
                type: .lap,
                dateInterval: DateInterval(start: timestamp, duration: 0),
                metadata: nil
            )
            builder.addWorkoutEvents([event]) { _, _ in }
        }
        lastLapKm = currentKm
    }
}
```

### `.lap` vs `.segment` 不要混用

- **`.lap`**：每 km 邊界（AC-WATCH-25），系統觸發
- **`.segment`**：課表分段（warmup / interval / rest / cooldown），由 `SegmentTransitionEngine` 在分段切換時 emit

兩者**獨立並存**：interval 800m × 5 訓練在 6 km 完成時，會有 5 個 `.segment` event（分段切換）+ 6 個 `.lap` event（km 邊界）。混用會讓 iOS parser 算錯課表完成度。

### 暫停期間不累計距離

`onDistanceUpdate` 必須只在訓練未暫停時 call；暫停期間 `HKLiveWorkoutBuilder` 的 `statistics` 凍結，但要確保上層 `LapEventEmitter` 不會誤觸發（用 `ActiveWorkoutSession.isPaused` flag gate）。

### 邊界精準度

`Int(meters / 1000.0)` 在 GPS 樣本跳動時可能在 999.9 / 1000.1 來回——`lastLapKm` 只增不減的 latch 設計避免重複 emit；但首次跨越的 timestamp 可能晚 1–2 秒，與內建 App 的精準度差距列入 parity test 的容忍範圍。

---

## Risk Assessment

### (1) 不確定的技術點

- **HealthKit metadata 經 sync 到 iPhone 端的可靠度**：watchOS 文件層級保證 metadata 會跟 workout 一起 sync 到 iPhone HealthKit，但「同步即時性」會受 iPhone 是否在範圍內、HealthKit 後台同步排程影響。AC-WATCH-23 寫「30 秒內看得到」是樂觀邊界，需在 backlog 啟動 spike 中量測 p50 / p95 延遲，必要時調整 SPEC。
- **`HKLiveWorkoutBuilder` 暫停期間的 distance / time 累計細節**：watchOS 預設行為是暫停時 `statistics` 凍結，但具體實機行為（GPS 仍取樣 vs 完全停）需 spike 確認，影響電池與資料準確度。
- **Watch app bundle id 的 sourceRevision 比對**：跨 watchOS 版本是否穩定（曾有 Apple Watch 重置後 bundle id 帶 suffix 的個案），dedup 不能單靠 bundle id（已用 metadata uuid 做主 key 規避）。
- **Lap event 邊界 timestamp 精準度**（v0.5 新增）：`HKLiveWorkoutBuilder` distance 樣本跳動時，跨 km 邊界的 emit timestamp 與內建 App 可能差 1–2 秒，parity test 須設容忍範圍；若實機差距 > 5 秒則需重設計（用 `HKStatistics` 回溯精準時刻）。
- **Auto-pause 系統 event 是否能由 `HKLiveWorkoutBuilder` 自動寫**（v0.5 新增）：watchOS 對 auto-pause 的處理跨版本可能不一致，需 spike 驗證是否 builder 自動 emit `.motionPaused`，或須 App 監聽 system pause notification 後手動 add event。

### (2) 替代方案與選擇理由

| 議題 | 已選 | 替代 | 不選的理由 |
|---|---|---|---|
| Dedup 策略 | 簡單版單一 uuid + 三防線（v0.2 用戶拍板） | A+B 雙保險 / 純 source bundle | dedup 越複雜越難 debug；單 key + 三防線足夠 |
| GPS 容忍 | 嚴格距離（Q2 A） | ±5% 容差 | 損及間歇精度，差異化價值折損 |
| watchOS 最低 | 10.0+（Q3 A） | 11.0+ | covered set 太小（只剩 Series 6+），95 MAU 不能再砍 |
| 中斷恢復 | Fail-fast（Q4 A） | 持久化 snapshot | 競態風險 > 收益，HealthKit 已保半條軌跡 |
| 複雜分段 UI | 單頁（Q5 C） | 多頁進度條 | Designer 進駐前不下死規格 |
| Complication | 升 P0 corner/circular（v0.2 用戶拍板） | 維持 P1 | KOL demo 視覺差異化必要 |
| AC-WATCH-23 時間邊界 | 2 分鐘（v0.2 用戶拍板） | 30 秒 | HealthKit 後台同步排程實際延遲，30 秒過嚴 |

### (3) 需要用戶確認的決策

> v0.2：以下三項用戶已拍板，列為已決議。

1. ~~Q7：complication 升 P0~~ → **已拍板：升 P0**（corner / circular family；其他 family 留 P1）；SPEC v0.4 已新增 AC-WATCH-24，工時 +3 天併入總計。
2. ~~Q1 dedup 策略~~ → **已拍板：採簡單版**（單一 `com.paceriz.workout_uuid` + 三條防線），不採 A+B 雙保險。
3. ~~AC-WATCH-23 時間邊界~~ → **已拍板：放寬到 2 分鐘**；SPEC v0.4 已更新。

### (4) 最壞情況與修正成本

| 風險 | 機率 | 衝擊 | 修正成本 |
|---|---|---|---|
| HealthKit dedup 在實機跑出重複紀錄 | 中 | 高（AC-WATCH-23 直接 fail） | 中：dedup pass 已寫，補強 metadata uuid pipe 通暢度 |
| watchOS API 在 backlog 啟動時已改版（10 → 12） | 高（時間延宕） | 中 | 中：spike 重評 Q3 即可 |
| 95 個 Watch MAU 中有人 zh-HK 看到台灣用語抱怨 | 低 | 低 | 低：補翻譯字串 |
| Complication 在實機被 watchOS 系統限制每分鐘只能更新 1 次 → 看到「昨日課表」 | 中 | 中（GTM 素材尷尬） | 中：用 timeline reload 機制，依 widget refresh budget 實作 |
| 啟動實作時發現 Watch target 與 iPhone target 共用 `Localizable.xcstrings` 設定不直觀 | 低 | 低 | 低：拷貝獨立檔案 |

---

## 後續行動（不在本 TD 範圍）

1. ~~用戶 review TD 三項拍板~~ → **v0.2 已完成**（complication 升 P0 / dedup 簡單版 / 時間邊界 2 分鐘）。
2. ~~PM 補 AC-WATCH-24~~ → **SPEC v0.4 已落地**。
3. **不建任何 task / Plan entity**——backlog 規劃為主，等 Android 主線達標。
4. backlog 觸發後，啟動實作前必做 spike：
   - HealthKit metadata sync 延遲量測（驗證 2 分鐘邊界是否合理）
   - `HKLiveWorkoutBuilder` 暫停行為實機驗證
   - watchOS 最低版本市佔重評
   - Complication timeline reload budget 實機驗證（避免顯示昨日課表）
5. 啟動實作時，由 Architect 依本 TD 拆 Developer / QA tasks，建 test stub 檔案。

---

## Changelog

- **v0.3 (2026-05-07)** — 補進 HKWorkout schema parity 相關需求：
  - 新增章節「HKWorkout Parity Test Plan」（對應 SPEC v0.5 的 AC-WATCH-25 / 26）：12 點欄位 diff checklist + parity test harness 規劃 + 5 個上架前必跑場景
  - 新增章節「iOS App Parser Hardening」：parser 須完整解析 lap / pause / motionPaused / runningPower events，與內建一致；+3 天併入 effort
  - 新增章節「HKLiveWorkoutBuilder Lap Emission 實作要點」：說明 `HKLiveWorkoutBuilder` 不會自動 emit `.lap`，須手動每 km 邊界 emit；`.lap` 與 `.segment` 不混用
  - AC Compliance Matrix 從 24 條更新至 26 條（新增 AC-WATCH-25 / 26）
  - Effort estimate 從 ~34 工程日修訂為 **42–44 工程日（單人全職，約 8–9 週）**，加 App Store 審核 buffer 總計 10–11 週
  - Risk Assessment (1) 新增 lap timestamp 精準度與 auto-pause 系統 event 不確定性
- **v0.2 (2026-05-07)** — 用戶拍板三項決議落地：
  - Q1 dedup 策略改簡單版：單一 `com.paceriz.workout_uuid` + 三條有效性防線（Watch fail-fast / iOS fallback to source filter / Firestore 衝突 reject）
  - Q7 complication 升 P0（corner / circular family，新增 AC-WATCH-24，工時 +3 天）
  - AC-WATCH-23 時間邊界 30 秒 → 2 分鐘
  - AC Compliance Matrix 從 23 條更新至 24 條
- **v0.1 (2026-05-07)** — 初版規劃文件。

---
