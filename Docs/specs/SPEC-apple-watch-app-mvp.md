---
doc_id: SPEC-apple-watch-app-mvp
title: Apple Watch App 主線（MVP）
type: SPEC
ontology_entity: apple-watch-app
status: draft
version: "0.5"
date: 2026-05-07
supersedes: null
backlog: true
backlog_reason: "短期主推 Android（Marketing 2026-05-07 分析）；本規格作為 KOL GTM 後手，Android 上線後啟動。"
---

# Feature Spec: Paceriz Apple Watch App 主線（MVP）

## 背景與動機

目前 95 位 MAU（佔 23.2%）使用 Apple Watch，但 Paceriz 沒有獨立 Watch App——Watch 數據透過 HealthKit 被動同步進 iOS App，跑者在跑步當下若要查看課表、目標配速、心率區間，必須掏出手機。這在戶外路跑場景嚴重影響體驗，也讓 Paceriz 在 Apple 生態系跑者社群相對於 Garmin Connect 顯得功能不完整。

本規格定義一個獨立的 Apple Watch App，核心訊息：

> **「課表在手機，配速在手腕——再也不用邊跑邊掏手機看配速區間」**

跑者在 Watch 上可以：
- 看到今日課表（含間歇 / 組合 / 漸速跑的分段細節）
- 一鍵啟動訓練，自動帶入 lap 結構（不用手動設間歇分圈）
- 跑步中即時看到當下配速、課表目標配速、剩餘距離/時間
- 跑完直接在手腕看摘要

## 規劃定位（重要）

本規格為 **backlog 規劃**，不是立即開發項目。

- **觸發條件**：Android 版上線並穩定後啟動（避免 iOS / Android 雙線開發）
- **GTM 定位**：作為現有 iOS 用戶留存 + Apple 生態系跑者社群差異化定位
- **規劃理由**：先行寫好 spec 讓 Architect 在 Android 工期評估同時做 Watch App 的工時 / 風險預估；待 Android 站穩後 1-2 週內可立即啟動，不需從零開始討論

## 目標用戶

**主要族群**：擁有 Apple Watch 的台港中文跑者（zh-TW + zh-HK 佔現有 Apple Watch MAU 79%）

**典型場景**：
1. 河濱 / 操場長跑訓練：手機放包包，Watch 即時看配速 / 心率
2. 間歇訓練：避免每組手動切換分圈，由 Watch 依課表自動執行
3. 訓練結束：直接在手腕看是否達標，不必等回家開手機

**明確排除**（本期 MVP 不服務）：
- 完全不帶 iPhone 的 LTE Watch 獨立場景（見「明確不包含」）
- 騎車、游泳、其他非跑步訓練類型

## Spec 相容性

已比對的既有 Spec：

| Spec | 關係 | 衝突 |
|------|------|------|
| `SPEC-training-hub-and-weekly-plan-lifecycle` | 取用其 weekly plan 資料模型 | 無 |
| `SPEC-training-record-and-workout-detail` | 訓練完成後紀錄寫回，Watch 摘要為其子集 | 無 |
| `SPEC-heart-rate-and-training-readiness-surfaces` | 取用其心率區間設定 | 無 |
| `SPEC-workout-upload-error-noise-filtering` | Watch 透過 HealthKit 同步，沿用其錯誤分類規則 | 無 |
| `SPEC-app-shell-routing-and-global-guardrails` | iOS 端跨 App routing 不影響 Watch | 無 |

結論：無需求矛盾、介面衝突、範圍重疊或假設衝突。

## 需求

### P0（必須有 — MVP 上線基線）

#### 帳號 / 認證

##### AC-WATCH-01: iPhone 已登入帳號必須自動同步到 Watch
Given 使用者已在配對的 iPhone 上完成 Paceriz 登入，  
When 第一次在 Watch 上開啟 Paceriz App，  
Then Watch App 必須透過 watchOS paired session 自動取得登入狀態，**不得**要求使用者在 Watch 上輸入密碼、掃 QR Code 或進行其他認證步驟。

##### AC-WATCH-02: Watch 未配對 iPhone 或 iPhone 未登入時必須顯示明確引導
Given 使用者打開 Watch App 但 iPhone 未配對、未登入、或未安裝 Paceriz，  
When Watch App 啟動完成，  
Then Watch 必須顯示一張引導卡片，告知「請先在配對的 iPhone 上登入 Paceriz」，**不得**顯示任何訓練功能。

#### 課表瀏覽

##### AC-WATCH-03: Watch 必須顯示今日課表
Given 使用者已登入且本週課表已產生，  
When 使用者打開 Watch App 主頁，  
Then 系統必須顯示「今日課表」資訊，包含：
- 訓練類型（輕鬆跑 / 間歇 / 組合跑 / 漸速跑 / 休息日 / 其他）
- 總距離或總時間
- 對於非休息日：分段結構摘要（例如「暖身 1km → 800m × 5（間歇 2 分鐘） → 收操 1km」）

##### AC-WATCH-04: 今日為休息日時 Watch 必須明確顯示且禁用啟動訓練
Given 今日課表為休息日（rest day），  
When 使用者打開 Watch App 主頁，  
Then 系統必須顯示「今日休息」訊息，且**不得**提供「開始訓練」按鈕。

##### AC-WATCH-05: 無本週課表時 Watch 必須引導使用者去 iPhone 產生
Given 使用者尚未產生本週課表，  
When 使用者打開 Watch App 主頁，  
Then 系統必須顯示「請先在 iPhone 上產生本週課表」引導，**不得**在 Watch 上提供產生課表的入口。

#### 訓練啟動

##### AC-WATCH-06: 使用者必須能在 Watch 上直接啟動今日課表
Given 今日為非休息日、本週課表已產生、Watch 已取得有效今日課表 snapshot（透過配對 iPhone 同步或先前已快取），且必要權限均已授權（依 AC-WATCH-21），  
When 使用者在 Watch 主頁點擊「開始訓練」，  
Then Watch 必須直接啟動訓練，**不得**要求使用者先在 iPhone 上做任何額外設定或確認。

> 註：若課表 snapshot 尚未取得，啟動行為由 AC-WATCH-18 處理（顯示靠近 iPhone 引導）。若權限未授權，由 AC-WATCH-22 處理。

##### AC-WATCH-07: 訓練啟動時 Watch 必須 snapshot 當下課表內容
Given 使用者在 Watch 上啟動訓練，  
When 訓練開始，  
Then 系統必須將當下今日課表的完整內容（所有分段、目標配速、目標距離 / 時間）snapshot 為本次訓練的執行依據；訓練進行中**不得**因 iPhone 端課表被改而動態變更已啟動的訓練內容。

##### AC-WATCH-08: 訓練啟動後必須使用 Watch 內建 GPS 與心率感應器
Given Watch 上的訓練已啟動，  
When 訓練進行中，  
Then 系統必須使用 watchOS workout session（HealthKit）取得 GPS 軌跡與心率資料，**不得**依賴 iPhone GPS。

#### 訓練中顯示（依課表類型分流）

##### AC-WATCH-09: 輕鬆跑訓練中必須顯示基本即時資訊
Given 訓練類型為輕鬆跑，  
When 訓練進行中，  
Then Watch 主畫面必須同時顯示：當下配速、當下心率、累計距離、累計時間，且每秒至少更新一次。

##### AC-WATCH-10: 間歇 / 組合 / 漸速跑必須顯示當前分段資訊
Given 訓練類型為間歇跑、組合跑或漸速跑，  
When 訓練進行中，  
Then Watch 主畫面必須顯示：
- 當下配速
- 當前分段的目標配速範圍（例如「目標 4:30~4:50」）
- 當前分段剩餘距離或剩餘時間（依分段類型而定）
- 當下心率

##### AC-WATCH-11: 距離型分段必須由系統依累計距離自動切換
Given 訓練類型為間歇 / 組合 / 漸速跑，目前分段為距離型分段（如 800m），且訓練未處於暫停狀態，  
When 系統偵測到該分段累計 GPS 距離達到目標距離，  
Then 系統必須自動切換到下一分段，並更新主畫面所有目標數值（配速範圍、剩餘距離 / 時間）。暫停期間不累計距離（依 AC-WATCH-13）。

##### AC-WATCH-12: 分段結束前 5 秒必須提示
Given 訓練類型為間歇 / 組合 / 漸速跑，當前分段剩餘距離預估 ≤ 5 秒（依當下配速估算）或剩餘時間 ≤ 5 秒，  
When 進入結束前 5 秒，  
Then Watch 必須觸發一次震動 + 一次提示音，且**不得**重複觸發（每分段切換前最多一次提示）。

#### 訓練控制

##### AC-WATCH-13: 訓練中必須可在 Watch 上暫停 / 繼續
Given Watch 上的訓練正在進行，  
When 使用者點擊 Watch App UI 上的暫停按鈕，  
Then 系統必須暫停 GPS、時間、距離累計與分段切換判定；繼續後從暫停點接續，**不得**遺失先前已累計的距離與時間。

> 註：硬體按鈕（Side Button、Action Button、Digital Crown）作為暫停 / 結束的快速入口屬技術設計可選項，由 Architect 評估 watchOS 平台限制後決定，不列為 P0 阻塞 AC。

##### AC-WATCH-14: 訓練中必須可在 Watch 上手動結束
Given Watch 上的訓練正在進行或已暫停，  
When 使用者執行結束動作，  
Then 系統必須結束本次 workout session，將資料寫入 HealthKit，並導向 AC-WATCH-15 的摘要畫面。

#### 訓練結束 / 資料寫入

##### AC-WATCH-15: 訓練結束時 Watch 必須顯示摘要畫面
Given 訓練在 Watch 上結束，  
When 進入摘要畫面，  
Then Watch 必須顯示四個核心指標：總距離、總時間、平均配速、平均心率，且**不得**強制使用者立即看完整版報告（完整版仍在 iPhone App）。

##### AC-WATCH-16: 訓練資料必須寫入 Apple Health（含 dedup token）
Given 訓練在 Watch 上完成，  
When 結束流程執行，  
Then 系統必須將 workout（含 GPS 軌跡、心率、距離、時間）寫入 Apple Health，使現有 iOS App 的 HealthKit 同步機制可在後續同步該筆紀錄到 Paceriz 後端，**不得**繞過 HealthKit 直接 call Paceriz API（避免雙寫造成 dedup 複雜度）。

寫入時必須附帶 dedup token metadata（Watch 端 → HealthKit → iPhone 端 dedup pipeline 的唯一識別來源）：

- Metadata key：`com.paceriz.workout_uuid`
- 值必須為**有效的 UUID v4 字串**（非空、符合 RFC 4122 v4 regex `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`）
- 同一筆 workout 在整個生命週期內 uuid 不變（產生於訓練啟動時，寫入時帶入）
- Watch 端寫入前必須驗證 uuid 有效性，**不符 → fail-fast 不寫入 HealthKit + log error**，不得寫入無 uuid 或 uuid 格式錯誤的 workout

> **驗收條件**：
> - workout 已寫入 Apple Health 但 metadata 缺 `com.paceriz.workout_uuid` → FAIL
> - uuid 值不符 v4 regex → FAIL
> - uuid 驗證失敗時，workout 仍被寫入 HealthKit → FAIL（必須 fail-fast）

##### AC-WATCH-23: Watch 訓練必須端到端出現在 Paceriz 紀錄且僅一筆
Given Watch 上完成的 workout 已依 AC-WATCH-16 寫入 Apple Health，且 iPhone 重新進入藍牙範圍並執行一次完整 HealthKit sync，  
When 使用者打開 iOS App 的訓練紀錄頁（依 SPEC-training-record-and-workout-detail），  
Then 該筆 workout **必須出現一次且僅一次**，且必須完整保留以下核心資料：
- 總距離（與 Watch 端摘要一致，誤差 ≤ 1 公尺）
- 總時間（不含暫停的有效訓練時長）
- 心率序列（每秒至少一個取樣，可被 workout detail 顯示為心率區間分布）
- GPS 路線軌跡（可被 workout detail 顯示為地圖）

> **驗收條件**：  
> - 重複建立同一筆 workout（dedup 失敗）→ FAIL  
> - 後端有紀錄但缺心率或路線資料 → FAIL  
> - 數值與 Watch 摘要不一致（超過誤差容忍） → FAIL  
> - HealthKit 已 sync 但 2 分鐘內 Paceriz 紀錄頁仍看不到該筆 → FAIL（同步管線斷了）

> **時間邊界說明**：原 v0.3 為 30 秒；v0.4 放寬至 2 分鐘，反映 HealthKit 後台同步排程實際延遲（iPhone 重新進入藍牙範圍 + HealthKit 後台 sync + iOS upload pipeline batch interval 三段累計），30 秒過嚴會造成 false negative。

#### 離線 / 連線

##### AC-WATCH-17: iPhone 不在身邊時 Watch 必須能完成訓練
Given 訓練啟動前已從 iPhone 同步過今日課表，且訓練進行中 iPhone 離開藍牙範圍，  
When 訓練進行中至結束，  
Then Watch 必須能依 snapshot 課表完整執行訓練（GPS、心率、分段切換、摘要），訓練資料先寫入 Apple Health 待之後與 iPhone 重新連線時同步。

##### AC-WATCH-18: iPhone 不在身邊且尚未同步今日課表時必須阻擋啟動
Given 使用者開啟 Watch App 時 iPhone 不在藍牙範圍，且 Watch 本地沒有快取今日課表（首次使用或快取失效），  
When 使用者嘗試啟動訓練，  
Then 系統必須顯示「需先靠近 iPhone 同步課表」訊息，**不得**啟動訓練。

#### 分段切換補充

##### AC-WATCH-20: 時間型分段必須由系統依累計時間自動切換
Given 訓練類型為間歇 / 組合 / 漸速跑，目前分段為時間型分段（如 5 分鐘），且訓練未處於暫停狀態，  
When 系統偵測到該分段累計訓練時間達到目標秒數，  
Then 系統必須自動切換到下一分段，並更新主畫面所有目標數值（配速範圍、剩餘距離 / 時間）。暫停期間不累計時間（依 AC-WATCH-13）。

#### 權限

##### AC-WATCH-21: 首次使用必須請求所有必要權限
Given 使用者在 Watch 上第一次嘗試啟動訓練，且尚未授權 HealthKit、Location（While In Use 含 background）、Motion & Fitness 任一權限，  
When 使用者點擊「開始訓練」，  
Then 系統必須在啟動 workout session 前依序請求所有缺漏的必要權限；只有全部授權後才得啟動訓練。

##### AC-WATCH-22: 權限被拒絕時必須阻擋啟動並提供恢復路徑
Given 使用者拒絕了 HealthKit、Location 或 Motion & Fitness 任一必要權限，  
When 使用者再次嘗試啟動訓練，  
Then 系統必須顯示權限缺漏訊息，明確指示「需在 iPhone 的 Watch App → Paceriz 或 Watch 設定中開啟對應權限」，且**不得**啟動訓練；不得反覆彈出系統權限視窗（已被拒絕的權限 iOS 系統不會再彈）。

#### Complication（watch face 抬腕可見）

##### AC-WATCH-24: Complication 必須在 watch face 上顯示今日課表簡述
Given 使用者已將 Paceriz complication 加入 watch face（corner family 或 circular family），且本週課表已產生，  
When 使用者抬腕看 watch face，  
Then complication 必須顯示：
- Paceriz logo（視覺辨識）
- 今日課表簡述（例如：「8K Easy」、「800m × 5」、「休息日」、「無課表」）

且點擊 complication 必須直接進入 Paceriz Watch App 主頁。

> **範圍**：本 AC 僅涵蓋 corner family 與 circular family 兩種最常見 complication family；其他 family（modular、graphic、inline 等）留 P1。
>
> **驗收條件**：
> - corner / circular complication 任一 family 在 watch face 上看不到 Paceriz logo → FAIL
> - 課表已產生但 complication 顯示「無課表」 → FAIL
> - 休息日課表 complication 未顯示「休息日」 → FAIL
> - 點擊 complication 未開啟 Paceriz Watch App → FAIL

#### HKWorkout Schema Parity（與內建跑步 App 對齊）

##### AC-WATCH-25: HKWorkout schema 與內建跑步 App parity
Given Paceriz Watch App 完成一場跑步訓練並寫入 HealthKit，  
When 寫入 `HKWorkout` 完成，  
Then 該 workout 必須包含以下欄位 / 事件，且結構與 watchOS 內建跑步 App 寫入的 workout 一致：

1. `HKWorkoutActivityType.running`
2. `totalDistance`、`totalEnergyBurned`、`duration`（皆為 `HKQuantity`，單位正確）
3. `HKWorkoutRoute`（GPS route），且至少包含 1 筆 `CLLocation` sample
4. 每次手動暫停 / 繼續必須對應寫入一組 `HKWorkoutEvent.pause` / `.resume`
5. **每完成 1 公里自動寫入 `HKWorkoutEvent.lap`**（對齊內建跑步 App 行為；`HKLiveWorkoutBuilder` 不會自動發出，須由 App 監聽距離累計手動 emit）
6. 心率 sample（`HKQuantityTypeIdentifier.heartRate`），訓練全程每秒至少一筆
7. 配速（`HKQuantityTypeIdentifier.runningSpeed` 或 derived pace）、步頻（`HKQuantityTypeIdentifier.runningStrideLength` / cadence）、跑步功率（watchOS 10+ `HKQuantityTypeIdentifier.runningPower`）samples
8. metadata 必須包含 `HKMetadataKeyIndoorWorkout`（Bool）以標記室內 / 戶外

> **驗收方式**：以同一支 iPhone + Watch，分別用「內建跑步 App」與「Paceriz Watch App」各跑一次相同距離 + 相同操作（含暫停 / 繼續）；iOS App parser 解出兩筆 workout 的所有上述欄位後做 by-field diff，**差異只能存在於 source name**（一個是 `com.apple.workout`、一個是 `com.paceriz.watch`）。其餘欄位 / 事件序列必須一致。

> **驗收條件**：
> - 上述 8 點任一項缺漏 → FAIL
> - 每完成 1km 沒有對應 `HKWorkoutEvent.lap` → FAIL
> - 暫停 / 繼續未對應寫入 `.pause` / `.resume` event → FAIL
> - 與內建 App 對照 diff 出現非 source name 的差異 → FAIL

##### AC-WATCH-26: 自動暫停（Auto-pause）行為與內建一致
Given 使用者在 iOS Settings → 健身（Fitness）開啟「自動暫停跑步」（Auto-Pause Running），  
When Paceriz Watch App 訓練進行中偵測到使用者停止移動，  
Then 系統必須寫入 `HKWorkoutEvent.motionPaused`；恢復移動後寫入 `HKWorkoutEvent.motionResumed`，與內建跑步 App 行為一致。

> **驗收條件**：
> - Auto-pause 開啟但停止移動時未寫入 `.motionPaused` → FAIL
> - 恢復移動時未寫入 `.motionResumed` → FAIL
> - Auto-pause 關閉時仍寫入 `.motionPaused` / `.motionResumed`（誤觸發） → FAIL

#### 國際化

##### AC-WATCH-19: Watch App 必須支援與 iOS App 一致的語系
Given Watch App 對應的 iPhone Paceriz App 已支援的語系（zh-TW、ja-JP、en-US；zh-HK 系統 fallback 至 zh-TW），  
When Watch App 顯示任何使用者面字串，  
Then 系統必須依使用者 Apple Watch 的系統語系顯示對應翻譯，**不得**出現未翻譯的 placeholder 或英文預設字串。

---

### P1（應該有）

#### AC-WATCH-P1-01: 心率區間提示
Given 訓練進行中且使用者已設定心率區間（依 SPEC-heart-rate-and-training-readiness-surfaces），  
When 當下心率超出 / 低於課表目標區間達 10 秒以上，  
Then Watch 必須以顏色變化（綠 / 橘 / 紅）或一次震動提示，但**不得**頻繁震動干擾跑者。

#### AC-WATCH-P1-02: 每公里 lap 提示
Given 訓練進行中，  
When 累計 GPS 距離每經過 1 公里整數倍（1km、2km、3km...），  
Then Watch 必須觸發一次震動，並在主畫面短暫顯示「第 N km — 配速 X:YY」。

#### AC-WATCH-P1-03: 其他 complication family（非 corner / circular）
Given 使用者已將 Paceriz complication 加入 watch face 的非 corner / circular family（如 modular、graphic、inline 等），  
When 使用者抬起手腕看 watch face，  
Then complication 應顯示「今日課表類型 + 主要數字（距離或時間）」，點擊可直接進入 Paceriz Watch App 主頁。

> 註：corner / circular family 已在 AC-WATCH-24 升 P0；本 AC 僅涵蓋 P0 範圍以外的 family。

---

### P2（可以有）

#### AC-WATCH-P2-01: AirPods 語音提示
Given 使用者已連接 AirPods 且訓練進行中，  
When 分段切換、心率區間異常、每公里 lap 等事件發生，  
Then 系統可透過 AirPods 用語音播報關鍵資訊（例如「第 2 公里完成，配速 5:20」）。

#### AC-WATCH-P2-02: 完整訓練詳情在 Watch 上呈現
Given 訓練在 Watch 上結束，  
When 使用者在摘要畫面向下捲動，  
Then Watch 可呈現每公里配速表 + 心率區間分布，**但**主流仍引導至 iPhone App 看完整版。

#### AC-WATCH-P2-03: Standalone LTE 模式
Given 使用者擁有 LTE 版 Apple Watch 且 iPhone 不在身邊，  
When 使用者打開 Watch App，  
Then Watch 可直接連 Paceriz 後端 API 同步今日課表並上傳訓練紀錄（繞過 iPhone 配對）。

> **⚠️ Hard Requirement**：本 AC 與 MVP 核心邊界（AC-WATCH-16「不繞過 HealthKit 直接 call Paceriz API」）衝突。若未來啟動 P2 LTE 模式，**必須另開獨立 SPEC** 重新定義以下 contracts，不得在本 SPEC 範圍內偷帶實作：
> - **同步契約**：Watch ↔ Paceriz API 的 endpoints、payload schema、retry 策略
> - **Dedup 契約**：Watch 直接上傳的 workout 與 HealthKit 同步進來的 workout 如何避免重複建立
> - **Auth 契約**：Watch 端如何取得並更新 access token（無 iPhone 配對情境）
> - **Offline-first 契約**：LTE 訊號斷線時的 local queue 行為

---

## 明確不包含

- **Watch 端獨立登入 / 註冊流程**：認證一律透過已配對 iPhone（AC-WATCH-01）
- **Watch 端產生 / 編輯週課表**：產生與編輯仍在 iPhone App，Watch 唯讀
- **訓練中途課表動態變更**：訓練啟動瞬間 snapshot，期間不重新同步（AC-WATCH-07）
- **騎車、游泳、力量訓練**：本期 MVP 僅支援跑步
- **訓練中即時上傳 Paceriz API**：所有資料透過 HealthKit 寫入後由 iOS App 同步上傳（AC-WATCH-16）
- **Android Wear / Wear OS 對應**：本 spec 僅涵蓋 watchOS / Apple Watch
- **Standalone LTE 完全脫離 iPhone 模式**：列為 P2，本期不做（AC-WATCH-P2-03）。若未來啟動，必須另開獨立 SPEC 重新定義同步 / dedup / auth 契約，**不得在本 SPEC 範圍內偷帶實作**

---

## 技術約束（給 Architect 參考）

1. **資料同步邊界**：Watch 是 companion mode，不直接 call Paceriz API；訓練資料一律透過 HealthKit → 既有 iOS App 同步管線（沿用 SPEC-workout-upload-error-noise-filtering 的錯誤分類規則）
2. **課表快取**：Watch 本地需快取「今日課表 snapshot」以支援離線訓練（AC-WATCH-17）；過期時間建議跟隨「今日」邊界
3. **GPS / 心率資料來源**：使用 watchOS HealthKit `HKWorkoutSession`，由 Architect 決定是否直接以 HKWorkoutBuilder 處理或自建累計層
4. **語系資源**：Watch App 的字串資源需與 iOS App 共用或同步維護（避免兩端翻譯不一致）
5. **訓練資料的 dedup**：iOS App 端的 HealthKit 同步機制必須能正確處理 Watch 寫入的 workout，避免重複建立 Paceriz 後端 workout record。**dedup 的最終結果由 AC-WATCH-23 驗收**（一次且僅一次出現在 Paceriz 訓練紀錄）；具體實作策略（HealthKit metadata 標記、source bundle 比對、時間戳 fingerprint 等）由 Architect 設計
6. **耗電 / 效能**：Apple Watch 訓練電池消耗高，跑步 1.5 小時應有足夠電量；GPS、心率取樣率由 Architect 評估
7. **watchOS 最低支援版本**：建議跟隨 iOS App 同步策略（由 Architect 決定）

---

## 開放問題

以下問題需 Architect 在技術設計階段釐清，PM 不做技術決策：

1. **HealthKit dedup 策略** — **已解決：見 TD-apple-watch-app-mvp.md（Q1）**。決議採簡單版：Watch 寫入 `com.paceriz.workout_uuid` (UUID v4) metadata 為單一 dedup key；TD 列出 uuid 有效性三條防線（Watch 寫入 fail-fast / iOS upload skip dedup fallback 既有 source filter / Firestore 衝突 reject）。
2. **暫停期間 GPS / 時間累計**：暫停時 GPS 是否完全停止取樣，還是繼續取樣但不計入距離？影響電池與資料準確度的取捨。
3. **分段切換的 GPS 誤差容忍**：800m 間歇實際 GPS 量測可能 780m 或 820m，自動切換的判定門檻是嚴格距離還是 ±5% 容差？
4. **訓練中斷恢復**：跑步中 Watch 突然當機 / 沒電，重啟後是否恢復先前訓練？建議 MVP 不做（按 fail-fast 處理），但需 Architect 確認此假設無法接受時的成本。
5. **複雜分段的呈現**：組合跑可能含多種子分段（例如「3km 輕鬆 + 2km 漸速 + 1km 全力」），Watch 小螢幕如何呈現？需 Designer 介入。
6. **第 5 秒倒數提示在「時間型分段」與「距離型分段」上的計算方式** — **已解決：見 TD-apple-watch-app-mvp.md（Q6）**。決議：時間型直接倒數秒；距離型用最近 30 秒滾動平均配速推估，誤差容忍 ±2 秒，同分段 latch 不重複觸發。
7. **Watch App MVP 是否支援 watchOS complication 作為 KOL demo 必備功能** — **已解決：見 TD-apple-watch-app-mvp.md（Q7）**。決議：升 P0，僅 corner / circular family（其他 family 留 P1）；對應新增 AC-WATCH-24。
8. **語系 fallback 規則**：zh-HK 是否真的 fallback 至 zh-TW，還是透過 iOS App 共用 zh-Hant 一份？需 Architect / Designer 確認。

---

## 後續流程建議

1. **本 spec 進入 `Under Review`** → 用戶 review → `Approved`
2. **Architect 拉技術設計**（含開放問題的決策、工時評估、risk assessment）
3. **暫不開 task / Plan entity**：等 Android 主線達標後再啟動 Watch 主線（觸發條件見「規劃定位」段）
4. **保留可調動性**：若 KOL GTM 需要 Watch demo 提早，可從本 spec 抽 P0 子集做「展示版」

---
