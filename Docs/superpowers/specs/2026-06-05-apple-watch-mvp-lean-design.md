---
doc_id: DESIGN-apple-watch-mvp-lean
title: Apple Watch 跑課表同步 — 精簡核心版設計
type: DESIGN
ontology_entity: apple-watch-app
status: draft
version: "1.0"
date: 2026-06-05
amends: SPEC-apple-watch-app-mvp (v0.5)
amends_td: TD-apple-watch-app-mvp (v0.3)
---

# Apple Watch 跑課表同步 — 精簡核心版設計

> 本文件是 2026-06-05 brainstorm 的產出，**修訂**既有 `SPEC-apple-watch-app-mvp.md` v0.5 與
> `TD-apple-watch-app-mvp.md` v0.3 的部分決策（同步模式、暖身/緩和機制、RPE、MVP 範圍）。
> 既有 SPEC/TD 仍是 dedup pipeline、HKWorkout parity、complication 等細節的依據；
> 本文件只覆寫下方「§7 與既有 SPEC 的差異」列出的條目。

## 目標一句話

使用者在 iPhone 上把「今天的課表」按一個按鈕傳到 Apple Watch；在錶上一鍵啟動，
暖身/間歇/組合/緩和由錶自動帶跑（間歇分段自動切換、切換前 5 秒提示），跑完選 RPE；
workout 以「與 Apple 內建跑步 App 一致的格式」寫入 Apple Health，
既有 iOS 同步管線用同一套邏輯解析後回傳 Paceriz 後端。**不做任何繞過 HealthKit 的額外資料傳輸。**

## 定位

- 這是既有 10–11 週完整 MVP 的**精簡核心版**（約 8–9 週）。
- 砍掉的是「與內建 App 完整對齊」的硬功夫與 P1/P2 提示；保留核心閉環 + HKWorkout parity + complication + 全跑步 run_type + 暫停。
- 既有 SPEC 為 backlog（觸發條件：Android 主線上線穩定後）。本文件不改變該 backlog 定位，除非使用者另行指示啟動。

---

## §1 範圍與課表分流

### 1.1 精簡版「砍掉」（相對既有 SPEC v0.5）

- Auto-pause（`.motionPaused` / `.motionResumed`，AC-WATCH-26）→ 移出 MVP
- 心率區間顏色提示 / 每公里語音 / AirPods 播報（P1/P2）
- 每公里自動 `.lap` event（純對齊內建的細節）
- HKWorkout 完整 by-field parity harness + iOS parser hardening 全套（改為「驗證既有 parser 能解 `.segment` / `.pause`，必要時小修」）

### 1.2 精簡版「必須保留」（砍了閉環就壞）

- workout 寫 `com.paceriz.workout_uuid` metadata + 後端 uuid 去重（否則一筆變兩筆，AC-WATCH-23）
- 課表 snapshot 本地快取（離線可跑，AC-WATCH-17）
- 權限請求 gate（HealthKit / Location / Motion）
- iPhone 登入狀態同步到 Watch（不在錶上登入）
- HKWorkout schema parity（寫入格式對齊內建，讓後台同一套邏輯解 — 見 §3.3）
- Complication（corner / circular family）

### 1.3 課表分流規則

> 核心規則：**所有非輕鬆跑都要暖身/緩和；課表如果沒給 warmup/cooldown segment，Watch app 自己補上 open-ended 暖身/緩和。**

| 流程 | run_type（`DayType`） | 暖身/緩和 | 主段 |
|---|---|---|---|
| **A. 直接開始**（連續單段） | `easy_run`/`easy`、`long_run`/`lsd`、`recovery_run` | **無** | 單一連續段 |
| **B. 暖身→主段→緩和** | `interval`、`combination`、`tempo`、`threshold`、`progression`、`benchmark`、`race` | **一律有**（open；課表沒給就補） | 依課表 segments 自動切換 |
| **禁啟動** | `rest` | — | 顯示「今日休息」，不給啟動鈕 |
| **不支援**（引導回 iPhone） | 非跑步類：`strength`/`yoga`/`cycling`/`hiking`/`cross_training` | — | 顯示「此類型請於對應裝置進行」 |

- 暖身/緩和**一律 open-ended**：Watch **忽略課表裡 warmup/cooldown segment 的目標距離**，只取課表的「真正主段」（間歇的跑/休段、progression 的遞增段、benchmark/race 的全力單段）做自動切換。暖身緩和跑多少由跑者按鈕決定。
- `DayType` 解碼沿用 iOS 既有「寬鬆解碼」契約：未知 run_type → 視為 `rest`（不啟動）。

---

## §2 訓練狀態機

### 2.1 流程 A（輕鬆類）

```
今日課表卡「Easy 8K」→ 按「開始訓練」→ 權限 gate（首次）
  → [進行中・單段]  時間(主) / 配速 / 距離 / 心率，每秒更新
  → 控制頁「結束」
  → [RPE・轉錶冠 1-10・可跳過]
  → [摘要・距離/時間/均速/均心率]
  → 寫 HealthKit（uuid + rpe metadata）
```

### 2.2 流程 B（間歇/組合/漸速/節奏/全力測/比賽）

```
今日課表卡「800m×5」→ 按「開始訓練」→ 權限 gate
  → [暖身・open]   已暖身時間(主) / 配速 / 距離 / 心率     ← 課表沒給也補這段
  → 按「開始課表」
  → [主段・依課表 segments 自動切換]
        interval：跑段 ↔ 休息段交替（距離型或時間型）
        progression：多段配速遞增
        benchmark / race：單段距離全力
        每段切換前 5 秒：震動 + 嗶
  → 最後一段自動結束
  → [緩和・open]   已緩和時間(主) / 配速 / 距離 / 心率     ← 課表沒給也補這段
  → 按「結束」
  → [RPE・轉錶冠 1-10・可跳過]
  → [摘要] → 寫 HealthKit（uuid + rpe metadata）
```

### 2.3 全程通用規則

- **暫停/繼續**：任何進行中狀態皆可。暫停期間不累計距離/時間、不觸發分段切換，且每次暫停/繼續對應寫一組 `.pause` / `.resume` event。
- **snapshot freeze**：啟動瞬間凍結課表內容；訓練中 iPhone 改課表不影響本次。
- **5 秒切換提示**：時間型直接倒數秒；距離型用最近 30 秒滾動均速推估（±2 秒容忍，同段 latch 不重複觸發）。
- **分段切換門檻**：嚴格距離（累計 ≥ 目標距離才切；不放水 5%）。
- **中斷恢復**：fail-fast（當機/沒電不嘗試恢復 snapshot；HealthKit 仍保留到當機點的軌跡）。

---

## §3 資料流

### 3.1 課表下行 — 手動「傳送到 Apple Watch」（**改自既有 SPEC 的自動整週同步**）

```
[iPhone] 今日課表 detail（PlannedSessionDetailView）
    │  使用者按「傳送到 Apple Watch」（單日・手動・單向）
    ▼  WCSession.transferUserInfo（背景可達、queued）
[Watch] 收到單日 WatchPlanSnapshotDTO → 存本地快取（LocalSnapshotCache）
```

- **不做**整週同步、不做自動背景 push、不做 snapshot 版本比對。
- 一次只送**一筆單日課表 snapshot**；Watch 端覆寫本地快取。
- 登入狀態（auth.state）仍由 iPhone 端在登入/登出時 push（沿用既有 paired session 機制）。

### 3.2 workout 上行 — 透過 HealthKit（**不繞過，沿用既有同步管線**）

```
[Watch] 跑完 → HKLiveWorkoutBuilder.finishWorkout 寫入 Apple Health
    ▼  系統自動 sync（iPhone 回到藍牙範圍）
[iPhone] 既有 AppleHealthWorkoutUploadService
    用「跟解內建 App 一樣的邏輯」解析 → 上傳（既有 fingerprint 去重）
    → 拿到 workoutId 後讀 metadata rpe → 呼叫既有 setRPE API
    ▼  既有 upload pipeline（無新管線）
[Backend] 既有 ingest + 既有 setRPE endpoint（皆不改）
```

### 3.3 HKWorkout 寫入格式（parity — 讓後台同一套邏輯解）

寫入 `HKWorkout` 時必須帶齊、且結構對齊 watchOS 內建跑步 App：

| 欄位 / 事件 | 說明 |
|---|---|
| `HKWorkoutActivityType.running` | 固定 |
| `totalDistance` / `duration` / `totalEnergyBurned` | HKQuantity，單位正確 |
| `HKWorkoutRoute` | GPS 軌跡，至少 1 筆 `CLLocation` |
| 心率 samples | `heartRate`，全程每秒至少一筆 |
| `.pause` / `.resume` events | 對應每次手動暫停/繼續 |
| `.segment` events | 對應課表分區：暖身 / 間歇跑段 / 休息段 / 緩和（每段一個 segment） |
| metadata `HKMetadataKeyIndoorWorkout` | 室內/戶外標記 |
| metadata `com.paceriz.workout_uuid` | UUID v4，dedup 主 key（見 §3.4） |
| metadata `com.paceriz.rpe` | RPE 1-10（可缺，見 §5.8） |

> **首版不做**：每公里 `.lap` event、`runningPower` / cadence samples、auto-pause 的 `.motionPaused` / `.motionResumed`。
> **風險**：「後台同一套邏輯解」要成立，前提是既有 iOS parser 確實解出 `.segment` / `.pause`。
> TD 提過既有 parser 可能略過這些 event → **實作前需驗證，必要時小修**（非整套 parser hardening）。

### 3.4 Dedup

- **MVP**：沿用既有 `(uid, start_time, distance, source)` fingerprint 去重。Watch workout 格式與內建一致、source = `com.paceriz.watch`，既有上傳管線即可處理。
- Watch 端仍寫 `com.paceriz.workout_uuid`（v4，寫入前 fail-fast 驗證 regex `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`）作為**未來加強用的保險 token**，但 MVP 後端不依賴它。
- **Contingency**：實機若發現 fingerprint 對 Watch workout 去重不穩 → 才啟用後端 `paceriz_workout_uuid` 唯一 key（見 §4.3）。

---

## §4 元件與要動的程式

### 4.1 新建 watchOS target `HavitalWatch`（watchOS 10.0+）

```
Presentation
  - TodayWorkoutView / WelcomeView（未配對引導）
  - EasyRunMetricsView（A 流程）/ IntervalMetricsView（B 主段）
  - WarmupCooldownView（open 暖身緩和）
  - WorkoutControlView（暫停/結束）
  - RPEView（轉錶冠）/ WorkoutSummaryView
  - PermissionView
Domain
  - ActiveWorkoutSession（啟動即 freeze 課表）
  - SegmentTransitionEngine（主段自動切換 + 5 秒倒數）
  - WorkoutLauncher（啟動前置檢查）
  - PermissionGate / WorkoutSnapshotStore
Data / Infra
  - HKLiveWorkoutBuilderWrapper（寫 route/HR/.segment/.pause + uuid/rpe metadata）
  - WCSessionClient（收單日 snapshot）
  - LocalSnapshotCache（UserDefaults / file）
  - HapticPlayer
Complication
  - WidgetKit provider（corner / circular family）
```

### 4.2 iPhone 既有 app 改動

- **新增** `WatchCompanionService`（`WCSessionDelegate`）：送 auth state + 「傳送到 Apple Watch」單日 snapshot。
- **改** `PlannedSessionDetailView`：加「傳送到 Apple Watch」按鈕，依 `WCSession.isPaired` / `isWatchAppInstalled` 三態渲染（無配對 watch → 隱藏；有 watch 沒裝 app → 引導安裝；就緒 → 傳送）。
- **改** `AppleHealthWorkoutUploadService`：讀 `com.paceriz.workout_uuid` 去重 + 讀 `com.paceriz.rpe`；驗證（必要時小修）既有 parser 對 `.segment` / `.pause` 的處理。
- 上傳時把 `paceriz_workout_uuid` + `rpe` 帶給後端。

### 4.3 後端 — MVP 預設「不改」

Paceriz 架構是 `HealthKit → 既有上傳管線 → 後端 → app 從後端拿`（device→backend→UI 硬規則）。
Watch workout 走的是**既有那條上傳管線**（與內建 App / Garmin 同步進來的 workout 同一條），
因此本功能**不需要為後端新增邏輯**：

- **RPE**：iOS upload 拿到 workoutId 後讀 metadata `com.paceriz.rpe`，呼叫**既有 setRPE 路徑**
  （`WorkoutReflectionView.onSaveRPE` 已在用；後端 `workout_v2.py` `rpe: Optional[int]`（ge=1, le=10）早已存在）→ 後端不改。
  - ⚠️ 待實作確認：該 setRPE 的 repository method 是否可在 upload 流程獨立呼叫（只給 workoutId + rpe）。
- **Dedup**：沿用既有 `(uid, start_time, distance, source)` fingerprint。

**Contingency（非 MVP）**：若實機 spike 發現既有 fingerprint 對 Watch workout 去重不穩，
才加後端 `paceriz_workout_uuid` 唯一 key 欄位。屆時 Watch 端 uuid metadata 已備好，只需後端補欄位。

---

## §5 訓練畫面規格（Garmin 邏輯 × Apple Watch 風格）

**視覺風格基準（Apple Watch 原生 Workout App）**：黑底、大號圓體數字、每指標一個彩色全大寫 label、
主指標通常綠色、每頁 ≤ 5 指標、可上下滑/Digital Crown 切頁。

**① 今日課表主頁（啟動前）**
```
┌────────────────┐
│ 今日 · 間歇      │
│ 800m × 5        │
│ 暖身→主段→緩和   │
│ [   開始訓練   ] │   ← 綠色主按鈕
└────────────────┘
```

**② 暖身中（B 流程・open）** — Garmin「Until Lap Press」
```
┌────────────────┐
│ 暖身            │   ← 段名(橘)
│ 0:48           │   ← 已暖身時間(綠・主)
│ 6:32 配速       │   ← 段均配速(青)
│ 0.16 km        │
│ ♥ 132          │   ← 心率(紅)
│ [  開始課表  ]  │   ← = Garmin 按 Lap 進主段
└────────────────┘
```

**③ 間歇・跑段**
```
┌────────────────┐
│ 間歇  3/5       │   ← 步驟 + 第幾組(藍)
│ 0.42 km        │   ← 該段剩餘距離倒數(綠・主)
│ 目標 4:30–4:50  │   ← 目標配速範圍
│ 4:38 配速       │   ← 段均配速；範圍內=綠/太快=橘/太慢=紅
│ ♥ 168          │
└────────────────┘
   切換前 5 秒：震動 + 嗶
```

**④ 休息段**
```
┌────────────────┐
│ 休息  3/5       │
│ 1:28           │   ← 剩餘休息時間倒數(綠・主)
│ 下一段 800m     │   ← 預告
│ 6:10 配速       │
│ ♥ 150          │
└────────────────┘
   切換前 5 秒：震動 + 嗶
```

**⑤ 緩和中（open）** — 同 ②，主指標換「已緩和時間」，底部鈕為 `[ 結束 ]`。

**⑥ 直接開始（A 流程・輕鬆跑）**
```
┌────────────────┐
│ 輕鬆跑 8K       │
│ 32:18          │   ← 時間(綠・主)
│ 5:42 配速       │
│ 6.34 km        │
│ ♥ 148          │
└────────────────┘   結束鈕在控制頁
```

**⑦ 暫停/結束控制頁** — 比照 Apple 原生「向右滑出控制」
```
┌────────────────┐
│  ⏸ 暫停         │   ← 暫停期間不累計、不切段
│  ⏹ 結束         │   → 進 RPE
└────────────────┘
```

**⑧ RPE（轉錶冠 1-10・可跳過）**
```
┌────────────────┐
│  今天的體感      │
│      7         │   ← Digital Crown 轉 1↔10
│     /10        │
│   紮實的一次     │   ← 體感文字隨值即時換(見 §5.8)
│  [   完成   ]   │
│   稍後再說 >     │   ← 可跳過
└────────────────┘
```

**⑨ 摘要**
```
┌────────────────┐
│ 總距離  6.40 km │
│ 總時間  34:12   │
│ 均速   5:20/km  │
│ 均心率  158     │
└────────────────┘
```

### 5.x 共通 Garmin 邏輯對齊點（規格要求）

1. 暖身/緩和 = open，只能手動按鈕進/出（不自動切）。
2. 主段配速欄一律顯示**段均配速**（滾動均速），非即時 GPS 配速。
3. 主段主指標 = **該段剩餘倒數**（距離型顯示剩餘距離、時間型顯示剩餘時間）。
4. 每段標**第幾組（N/總數）**。
5. 配速是否達標用**顏色**（綠/橘/紅）表示，取代 Garmin 的 bar slider（Apple 化的點）。

### 5.8 RPE 規格

- 量表 **1-10 整數**，對齊既有後端 `workout_v2.py` `rpe: Optional[int]`（ge=1, le=10）與 iOS recap。
- 互動：**Digital Crown 轉 1↔10**，大數字置中。
- 體感文字四級（沿用 iOS recap）：≤3「輕巧地完成」、4-5「節奏掌握得不錯」、6-7「紮實的一次」、8+「硬仗打完了」。
- **可跳過**（「稍後再說」）：漏選不阻塞 — 既有 iPhone `WorkoutReflectionGate` 會在使用者回 iPhone 看該筆訓練時自動補問。
- 回傳路徑：Watch 寫 metadata `com.paceriz.rpe` → sync 回 iPhone → iOS upload 讀出後呼叫**既有 setRPE API**（後端不改）。不做額外傳輸。

---

## §6 i18n

- Watch 字串與 iOS 共用/同步維護，支援 zh-TW、ja-JP、en-US；zh-HK fallback 至 zh-TW。
- 不得出現未翻譯 placeholder 或英文預設字串。

---

## §7 與既有 SPEC v0.5 的差異（本文件覆寫的條目）

| 主題 | 既有 SPEC v0.5 | 本文件（精簡核心版） |
|---|---|---|
| 課表同步 | 自動 push 整週 + 啟動 pull（AC-WATCH-01/03） | **手動按鈕、單日、單向「傳送到 Apple Watch」** |
| 暖身/緩和 | 當成課表 segment，由系統自動切換 | **純 open、手動按鈕切換；非輕鬆跑一律有，課表沒給就補** |
| RPE | 無 | **新增：轉錶冠 1-10、可跳過、寫 `com.paceriz.rpe` metadata** |
| auto-pause（AC-WATCH-26） | P0 | **移出 MVP** |
| 每公里 `.lap` / parity harness 全套 | P0（AC-WATCH-25） | **首版改為「驗證既有 parser 能解 segment/pause，必要時小修」** |
| 心率區間提示 / AirPods / 每公里語音 | P0/P1/P2 | **首版不做** |
| Complication | P0（AC-WATCH-24） | **保留** |
| 全跑步 run_type（含 race/benchmark/progression） | 含 | **保留** |

未列入上表的既有 AC（dedup 三防線、權限 gate、離線快取、摘要四指標、snapshot freeze、watchOS 10.0+ 等）**沿用既有 SPEC/TD**。

---

## §8 工時與風險

- **工時粗估**：約 8–9 週單人全職（完整版 10–11 週）。砍掉約 9 工程日的 parity/auto-pause 工作，加回 RPE 流程 + 暖身/緩和手動狀態機約 4 天。
- **跨 2 subsystem**：watchOS app（新建）、iOS companion 改動 → 建議拆 2 份 plan。後端 MVP 不改（見 §4.3），僅 contingency 才動。

### 風險

| 風險 | 衝擊 | 對策 |
|---|---|---|
| 既有 iOS parser 略過 `.segment` / `.pause` event | parity 失效，後台解不出分段 | 實作前 spike 驗證既有 parser；必要時小修（不擴大成全套 hardening） |
| HealthKit metadata sync 到 iPhone 的延遲 | 跑完 > 2 分鐘 Paceriz 才看到 | 沿用既有 AC-WATCH-23 的 2 分鐘邊界；spike 量測 p50/p95 |
| `HKLiveWorkoutBuilder` 暫停期間累計細節跨版本不一 | 距離/時間誤差 | 啟動前實機 spike 驗證；以 `ActiveWorkoutSession.isPaused` gate 上層累計 |
| 距離型分段 GPS 訊號差卡住 | 分段切不過去 | 由暫停 + 手動結束接住（fail-fast，MVP 不做 timeout fallback） |

---

## §9 開放問題（實作前需 spike / 確認）

1. watchOS 最低版本市佔重評（建議仍 10.0+）。
2. `HKLiveWorkoutBuilder` 暫停行為實機驗證。
3. 既有 iOS parser 對 `.segment` / `.pause` 的處理（決定是否要小修）。
4. Complication timeline reload budget（避免顯示昨日課表）。
5. 「傳送到 Apple Watch」按鈕的精確位置與多日課表情境（是否只允許傳今日，或可傳任一天）。

---

## Changelog

- **v1.0 (2026-06-05)** — brainstorm 產出。確立精簡核心版範圍、課表分流規則、訓練狀態機（暖身/緩和純 open 手動切換）、手動單日傳送同步模式、RPE（轉錶冠 1-10 可跳過 + metadata）、HKWorkout parity 寫入格式、§5 訓練畫面規格（Garmin 邏輯 × Apple Watch 風格）。覆寫既有 SPEC v0.5 的同步/暖身緩和/auto-pause/parity 範圍等條目。
</content>
</invoke>
