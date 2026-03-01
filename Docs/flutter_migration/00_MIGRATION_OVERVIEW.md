# 00. Paceriz Flutter 遷移概覽

## 📋 執行摘要

**專案名稱**：Paceriz iOS 應用程式 Flutter 遷移 + 架構重構

**遷移策略**：一次性完整遷移（非分階段）

**預計週期**：16 週（約 4 個月）

**Bundle ID**：保留現有 `com.havital.paceriz`（不建立新應用程式）

**核心目標**：
1. 解決現有 Swift 架構的痛點
2. 實作簡潔、高擴充性的 Flutter 架構
3. 支援 Training V2（AI 生成 + 多運動類型）
4. 支援 IAP 付費功能門控
5. 支援 Apple Watch 資料同步

---

## 🎯 遷移目標和範圍

### 1.1 為什麼遷移到 Flutter？

**目前痛點**：
- ❌ **重複 API 呼叫**：`TrainingPlanManager.getTrainingPlanOverview()` 在多處被呼叫
- ❌ **快取策略不一致**：WorkoutV2CacheManager（7天TTL）vs TrainingPlanManager（30分鐘TTL）
- ❌ **任務管理複雜**：TaskID 碰撞風險、冷卻期靜默失敗
- ❌ **UserDefaults 擴充性差**：硬編碼 key、無版本控制
- ❌ **特性標記基礎建設弱**：僅支援 1 個 feature flag

**Flutter 優勢**：
- ✅ **跨平台**：單一程式碼庫支援 iOS + Android
- ✅ **統一架構**：Clean Architecture 強制職責分離
- ✅ **成熟生態系**：豐富的第三方套件（Hive、BLoC、Dio）
- ✅ **簡化快取**：Hive 比 UserDefaults 更強大
- ✅ **狀態管理**：BLoC 模式清晰、易測試

### 1.2 遷移範圍

#### ✅ 包含的功能
- 使用者認證（Firebase Auth + Google OAuth）
- 運動資料管理（Apple Health、Garmin、Strava 整合）
- 訓練計畫管理（現有計畫 + Training V2）
- IAP 付費功能（HRV 趨勢、VDOT 追蹤、訓練準備度等）
- Apple Watch 資料同步
- 推播通知（Firebase Messaging）
- 多語言支援（繁體中文、英文、日文）

#### ❌ 不包含的功能
- Andriod Watch 整合（僅 Apple Watch）
- 離線模式（保持與 Swift 版本一致）
- 社群功能（如排行榜、訓練群組 - 未來版本）

---

## 🔍 現有架構痛點分析

### 2.1 重複 API 呼叫問題

**現象**：
在 `TrainingPlanManager.swift` 中，`getTrainingPlanOverview()` 被呼叫 3 次：
- Line 214: `performLoadWeeklyPlan()`
- Line 252: `performRefreshWeeklyPlan()`
- Line 306: `fetchLatestWeeklyPlan()`

**影響**：
- 網路開銷增加 3 倍
- 電池消耗
- 潛在競態條件（3 個請求可能回傳不同版本的資料）

**Flutter 解決方案**：
全域 `APIDeduplicationManager` 自動去重，相同請求複用同一個 Future。

```dart
// Flutter 自動去重
final overview = await _dedup.deduplicatedCall(
  endpoint: '/plan/overview',
  params: {},
  apiCall: () => _api.getTrainingPlanOverview(),
);
```

---

### 2.2 快取策略不一致

**現象**：
- `WorkoutV2CacheManager`: 7天 TTL + 檔案系統 + Hybrid 儲存
- `TrainingPlanManager`: 30分鐘 TTL + UserDefaults + JSON 序列化

**影響**：
- 維護複雜（每個 Manager 都要實作自己的快取邏輯）
- 效能不可預測（不同 TTL 導致使用者體驗不一致）
- 難以擴充（新增快取類型需要複製貼上程式碼）

**Flutter 解決方案**：
統一 `CacheStrategy` 協定，所有快取管理器遵循相同介面。

```dart
// 統一快取協定
abstract class CacheStrategy<T> {
  Duration get ttl;
  Future<void> save(T data);
  Future<T?> load();
  Future<bool> isExpired();
}
```

---

### 2.3 任務管理複雜性

**現象**：
- TaskID 基於字串，存在碰撞風險（`sanitized.prefix(50)`）
- 冷卻期靜默失敗（僅列印日誌，無使用者提示）
- 多初始化路徑（`initialize()` vs `loadAllInitialData()`）

**影響**：
- 正式環境可能出現靜默錯誤
- 使用者操作無回應（冷卻期攔截）
- 難以除錯（任務執行順序不確定）

**Flutter 解決方案**：
BLoC 狀態管理 + 確定性任務 ID，錯誤狀態明確暴露給 UI。

```dart
// BLoC 明確錯誤狀態
sealed class WorkoutState {
  const WorkoutState();
}

class WorkoutError extends WorkoutState {
  final String message;
  const WorkoutError(this.message);
}
```

---

### 2.4 UserDefaults 擴充性差

**現象**：
- 硬編碼 key（`"workout_v2_list_cache"`, `"training_plan_cache"`）
- 無版本控制（資料結構變更需手動清理）
- 手動 JSON 序列化（`JSONEncoder().encode`）

**影響**：
- 資料遷移困難（無法檢測舊版本快取）
- 型別不安全（`as? [String]` 可能失敗）
- 擴充成本高（每個新快取需定義 key）

**Flutter 解決方案**：
Hive + 版本化 `CacheMetadata`，自動處理遷移。

```dart
// Hive 型別安全 + 版本控制
class CacheMetadata {
  final int version;  // 資料結構版本
  final DateTime cachedAt;

  // 自動遷移邏輯
  if (metadata.version != 2) {
    await clear();  // 清除舊版本快取
  }
}
```

---

### 2.5 特性標記基礎建設弱

**現象**：
`FeatureFlagManager` 僅支援 1 個功能開關（`isGarminEnabled`）

**影響**：
- 新增功能需要修改程式碼（新增 enum case）
- 無法動態設定（需要發佈新版本）
- 不支援 A/B 測試

**Flutter 解決方案**：
Feature Gate 系統 + Firebase Remote Config，動態設定。

```dart
// 動態功能門控
enum PremiumFeature {
  hrvTrends,
  vdotTracking,
  trainingReadiness,
}

await featureGate.requirePremium(feature: PremiumFeature.hrvTrends);
```

---

## 🏗️ Flutter 架構優勢

### 3.1 Clean Architecture 三層設計

```
┌─────────────────────────────────────────┐
│     Presentation Layer (UI/BLoC)        │  ← 狀態管理、UI 渲染
├─────────────────────────────────────────┤
│     Domain Layer (Business Logic)       │  ← 業務邏輯、用例
├─────────────────────────────────────────┤
│     Data Layer (API/Cache)              │  ← 資料獲取、快取
├─────────────────────────────────────────┤
│     Core Layer (Utils/DI/Network)       │  ← 基礎建設
└─────────────────────────────────────────┘
```

**優勢**：
- **職責清晰**：每層只負責特定任務
- **易於測試**：依賴注入 + Mock
- **可維護性高**：修改一層不影響其他層

### 3.2 雙軌快取策略

**Track A**：立即顯示快取（同步）
- 使用者下拉重新整理 → 立即顯示本機快取
- UI 不會出現長時間載入

**Track B**：背景重新整理（非同步）
- 同時發起 API 請求
- 更新快取 → 通知 UI 重新整理

**程式碼範例**：
```dart
Stream<CacheResult<T>> loadWithDualTrack() async* {
  // Track A: 優先回傳快取
  final cached = await cacheStrategy.load();
  if (cached != null) {
    yield CacheResult.fromCache(cached);

    // Track B: 背景重新整理
    _refreshInBackground();
  }
}
```

### 3.3 API 去重自動化

**現有問題**：
- 手動呼叫 `DeduplicatedAPIService.deduplicatedRequest()`
- 僅限單次請求去重（無全域快取）

**Flutter 改進**：
- 全域單例 `APIDeduplicationManager`
- 自動生成請求 Key（避免碰撞）
- 請求完成後自動清理

### 3.4 IAP 功能門控

**現有問題**：
- 無付費功能基礎建設
- 所有功能免費開放

**Flutter 實作**：
- `FeatureGate` 存取控制器
- `SubscriptionRepository` 訂閱狀態管理
- 功能鎖定 UI（`PremiumUpgradeDialog`）

### 3.5 Training V2 可擴充設計

**現有問題**：
- 僅支援跑步訓練計畫
- 硬編碼訓練演算法

**Flutter 實作**：
- `ActivityType` 列舉（跑步、騎行、游泳）
- `TrainingPlan` 基底類別（抽象介面）
- AI 生成演算法介面（`PlanGenerator`）

---

## 📅 16 週遷移時程表

| 階段 | 時間 | 關鍵任務 | 交付物 |
|------|------|---------|--------|
| **Phase 1** | Week 1-4 | 基礎架構搭建 | Flutter 空殼 + 架構文檔 |
| **Phase 2** | Week 5-10 | 核心功能遷移 | Beta 版（運動資料 + 訓練計畫 + IAP） |
| **Phase 3** | Week 11-14 | 進階功能 | 多運動類型 + Apple Watch |
| **Phase 4** | Week 15-16 | 測試和發佈 | 1.0 正式版上線 |

[詳細每週任務請參閱 09_MIGRATION_CHECKLIST.md]

---

## 🎯 關鍵決策記錄

### 決策 1：為什麼選擇 BLoC 而非 Riverpod？

**選擇**：`flutter_bloc`

**理由**：
1. **清晰的事件驅動模式**：更接近現有 Swift ViewModel
2. **強大的測試支援**：`bloc_test` 套件提供完整測試工具
3. **社群成熟度**：Flutter 官方推薦
4. **團隊學習曲線**：概念更直觀

### 決策 2：為什麼使用 Hive 而非 SQLite？

**選擇**：`hive`

**理由**：
1. **效能優勢**：純 Dart 實作，比 SQLite 快 5-10 倍
2. **簡化架構**：KV 儲存符合快取場景
3. **型別安全**：支援自訂型別轉接器
4. **加密支援**：內建 AES-256 加密

### 決策 3：為什麼 Apple Watch 需要 Native Module？

**選擇**：Swift Native Module 橋接

**理由**：
1. **Flutter 限制**：無法直接存取 WatchConnectivity
2. **HealthKit 依賴**：HealthKit 只能透過 iOS Native 呼叫
3. **效能考量**：Native 程式碼更適合背景同步

---

## 📊 成功指標

### 技術指標
- [ ] **程式碼量減少**：相比 Swift 版本減少 30%
- [ ] **API 呼叫減少**：智慧去重 + 快取減少 50% 網路請求
- [ ] **單元測試覆蓋率**：> 80%
- [ ] **啟動時間**：< 2 秒（冷啟動）
- [ ] **記憶體佔用**：< 150MB（iOS）
- [ ] **Crash 率**：< 0.1%

### 業務指標
- [ ] **使用者遷移率**：> 95%（老使用者成功遷移）
- [ ] **使用者留存率**：7 日留存 > 70%
- [ ] **IAP 轉換率**：免費到付費轉換 > 5%
- [ ] **App Store 評分**：維持 4.5+ 星

### 架構指標
- [ ] **新功能開發效率**：從 2 週縮短到 1 週
- [ ] **Bug 修復速度**：平均 < 24 小時
- [ ] **程式碼審查時間**：平均 < 2 小時
- [ ] **部署頻率**：每週至少 1 次

---

## 🚧 風險評估

| 風險項 | 嚴重性 | 機率 | 緩解方案 |
|--------|--------|------|----------|
| Apple Watch 同步失敗 | 高 | 中 | 降級到僅支援 iPhone HealthKit |
| IAP 收據驗證延遲 | 中 | 低 | 本機快取訂閱狀態（7天TTL） |
| 資料遷移遺失 | 高 | 低 | 雲端備份（Firestore） |
| 效能下降 | 中 | 中 | 使用 Hive + 虛擬化清單 |
| 使用者流失 | 高 | 中 | 灰度發佈 + 無縫遷移體驗 |
| 時間延期 | 中 | 高 | 拆分發佈（先上線核心功能） |

---

## 📚 參考資料

### 內部資源
- [CLAUDE.md](../../CLAUDE.md) - Swift 版本架構文檔
- [IAP_IMPLEMENTATION_PLAN.md](../IAP_IMPLEMENTATION_PLAN.md) - IAP 實作計畫

### 外部資源
- [Flutter 官方文檔](https://docs.flutter.dev/)
- [BLoC 模式文檔](https://bloclibrary.dev/)
- [Hive 資料庫](https://docs.hivedb.dev/)
- [Clean Architecture (Reso Coder)](https://resocoder.com/flutter-clean-architecture-tdd/)

---

**文檔版本**：v1.0
**建立日期**：2025-12-29
**預計完成**：2026-04-29（16 週後）
**負責人**：開發團隊
