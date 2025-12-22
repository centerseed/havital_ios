# 訂閱功能 UI 整合指南

## 📋 文件資訊

- **建立日期**：2025-11-04
- **版本**：v1.0
- **用途**：指導開發者在現有 App 中整合訂閱 UI 入口

---

## 🎯 整合目標

在 App 的關鍵位置添加訂閱功能入口，引導免費用戶升級到付費版。

### 設計原則
1. **非侵入性**：不干擾核心功能使用
2. **價值導向**：展示付費功能的實際價值
3. **適時出現**：在用戶需要時展示升級提示
4. **清晰明確**：讓用戶知道為什麼要升級

---

## 📍 訂閱入口位置

### 入口清單

| 編號 | 位置 | 優先級 | 觸發條件 | 實現難度 |
|------|------|--------|---------|---------|
| **1** | 主畫面頂部 Banner | ⭐⭐⭐⭐⭐ | 所有用戶 | 中 |
| **2** | 鎖定功能遮罩層 | ⭐⭐⭐⭐⭐ | 免費用戶點擊鎖定功能 | 低 |
| **3** | 用戶資料頁訂閱卡片 | ⭐⭐⭐⭐ | 所有用戶 | 低 |
| **4** | 試用期倒數提醒 | ⭐⭐⭐⭐ | 試用期用戶 | 中 |
| **5** | 週課表差異化提示 | ⭐⭐⭐ | 免費用戶查看課表 | 低 |

---

## 1. 主畫面頂部 Banner

### 實現位置
在以下三個主要 Tab 頁面的頂部添加 Banner：
- `TrainingPlanView`（訓練計劃）
- `TrainingRecordView`（訓練記錄）
- `MyAchievementView`（表現數據）

### UI 設計

#### 1.1 免費用戶 Banner

```swift
// 在 View body 最上方添加
if !subscriptionManager.isSubscribed {
    SubscriptionPromoBanner()
        .padding(.horizontal)
        .padding(.top, 8)
}
```

**顯示內容**：
```
┌─────────────────────────────────────────┐
│ 🚀 升級到 Premium 解鎖完整 AI 功能         │
│                                           │
│ ✅ AI 個性化課表                          │
│ ✅ 深度訓練分析                           │
│ ✅ 無限 AI 助手對話                       │
│                                           │
│     [開始 14 天免費試用] →                │
└─────────────────────────────────────────┘
```

**顏色**：漸層藍色背景，白色文字

#### 1.2 試用期用戶 Banner

```swift
if subscriptionManager.isInTrialPeriod {
    TrialCountdownBanner()
        .padding(.horizontal)
        .padding(.top, 8)
}
```

**顯示內容**：
```
┌─────────────────────────────────────────┐
│ ⏰ 試用期剩餘 7 天                         │
│                                           │
│ 您正在體驗完整付費功能                    │
│ 試用結束後將轉為免費版                    │
│                                           │
│     [立即升級享優惠] →                    │
└─────────────────────────────────────────┘
```

**顏色**：橙色背景，白色文字

#### 1.3 付費用戶 Banner

```swift
if subscriptionManager.isSubscribed {
    PremiumStatusBanner()
        .padding(.horizontal)
        .padding(.top, 8)
}
```

**顯示內容**：
```
┌─────────────────────────────────────────┐
│ ✨ 您是 Premium 會員                      │
│                                           │
│ 到期時間：2026-01-30                      │
│ 自動續訂：已開啟                          │
│                                           │
│ 👥 邀請好友，雙方各得 7 天獎勵 →          │
└─────────────────────────────────────────┘
```

**顏色**：金色漸層背景，深色文字

### 實現程式碼

建立 `Views/Subscription/Components/SubscriptionBanner.swift`：

```swift
// SubscriptionPromoBanner - 免費用戶
struct SubscriptionPromoBanner: View {
    @StateObject private var manager = SubscriptionManager.shared

    var body: some View {
        Button {
            // 導航到訂閱頁面
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("🚀 升級到 Premium 解鎖完整 AI 功能")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("AI 個性化課表", systemImage: "checkmark.circle.fill")
                    Label("深度訓練分析", systemImage: "checkmark.circle.fill")
                    Label("無限 AI 助手對話", systemImage: "checkmark.circle.fill")
                }
                .font(.subheadline)
                .foregroundColor(.white)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
    }
}
```

---

## 2. 鎖定功能遮罩層

### 實現位置
在以下功能頁面添加遮罩層：
- 週回顧的 AI 分析區塊
- Workout 詳情的 AI 文字分析
- Readiness Score 頁面（完全鎖定）
- AI 助手頁面（完全鎖定）
- 課表同步功能

### UI 設計

```
┌─────────────────────────────────────────┐
│                                           │
│            [模糊的內容]                    │
│                                           │
│  ┌─────────────────────────────────┐    │
│  │  🔒 此功能需要 Premium 訂閱      │    │
│  │                                  │    │
│  │  升級到付費版解鎖：               │    │
│  │  ✅ AI 深度分析                  │    │
│  │  ✅ 個性化訓練建議                │    │
│  │  ✅ 詳細數據洞察                 │    │
│  │                                  │    │
│  │    [開始 14 天免費試用]          │    │
│  │                                  │    │
│  │    [了解更多]                    │    │
│  └─────────────────────────────────┘    │
│                                           │
└─────────────────────────────────────────┘
```

### 實現程式碼

建立 `Views/Subscription/Components/FeatureLockOverlay.swift`：

```swift
struct FeatureLockOverlay: View {
    let featureName: String
    let benefits: [String]

    var body: some View {
        ZStack {
            // 背景模糊效果
            Color.black.opacity(0.5)
                .blur(radius: 2)

            // 鎖定卡片
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                Text("此功能需要 Premium 訂閱")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("升級到付費版解鎖：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(benefit)
                                .font(.subheadline)
                        }
                    }
                }

                NavigationLink(destination: SubscriptionView()) {
                    Text("開始 14 天免費試用")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button("了解更多") {
                    // 顯示功能介紹
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
    }
}
```

### 使用範例

在需要鎖定的功能區塊：

```swift
// 在 WeeklySummaryView 中
if !subscriptionManager.isSubscribed {
    // 顯示簡化版內容
    BasicWeeklySummary()

    // 顯示鎖定遮罩
    FeatureLockOverlay(
        featureName: "AI 週回顧分析",
        benefits: [
            "訓練完成度評估",
            "強度分布分析",
            "疲勞度和恢復建議"
        ]
    )
} else {
    // 顯示完整 AI 分析
    AIWeeklySummary()
}
```

---

## 3. 用戶資料頁訂閱卡片

### 實現位置
在 `UserProfileView.swift` 的 `profileSection` 之後添加訂閱狀態區塊

### UI 設計

#### 3.1 免費用戶卡片

```
┌─────────────────────────────────────────┐
│  訂閱與會員                                │
│  ─────────────────────────────────────   │
│                                           │
│  目前方案：免費版                          │
│                                           │
│  [升級到 Premium] →                       │
│  [開始 14 天免費試用]                      │
└─────────────────────────────────────────┘
```

#### 3.2 付費用戶卡片

```
┌─────────────────────────────────────────┐
│  訂閱與會員                                │
│  ─────────────────────────────────────   │
│                                           │
│  ⭐ Premium 會員                          │
│  到期時間：2026-01-30                      │
│  自動續訂：已開啟                          │
│                                           │
│  [管理訂閱] →                             │
│  [邀請好友得獎勵] →                        │
└─────────────────────────────────────────┘
```

### 實現程式碼

在 `UserProfileView.swift` 中添加：

```swift
// 在 profileSection 之後添加
var subscriptionSection: some View {
    Section(header: Text("訂閱與會員")) {
        if subscriptionManager.isSubscribed {
            // 付費用戶
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Premium 會員")
                        .font(.headline)
                }

                if let subscription = subscriptionManager.currentSubscription {
                    Text("到期時間：\(subscription.formattedExpiryDate ?? "無")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if subscription.autoRenewing {
                        Label("自動續訂已開啟", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.vertical, 8)

            NavigationLink("管理訂閱", destination: SubscriptionView())
            NavigationLink("邀請好友得獎勵", destination: InviteView())

        } else {
            // 免費用戶
            VStack(alignment: .leading, spacing: 12) {
                Text("目前方案：免費版")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    // 導航到訂閱頁面
                } label: {
                    HStack {
                        Text("升級到 Premium")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }

                Text("開始 14 天免費試用")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
        }
    }
}

// 在 body 中的 List 添加
var body: some View {
    List {
        profileSection
        subscriptionSection  // 新增
        weeklyDistanceSection
        // ... 其他 sections
    }
}
```

---

## 4. 試用期倒數提醒

### 實現邏輯

在 `SubscriptionManager.swift` 中添加試用期檢查：

```swift
extension SubscriptionManager {
    /// 檢查是否需要顯示試用期提醒
    func shouldShowTrialReminder() -> (show: Bool, daysRemaining: Int?) {
        guard let subscription = currentSubscription,
              subscription.status == .inTrial,
              let expiryDate = subscription.expiryDate,
              let expiry = ISO8601DateFormatter().date(from: expiryDate) else {
            return (false, nil)
        }

        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0

        // 在剩餘 7/3/1 天時顯示提醒
        if [7, 3, 1].contains(daysRemaining) {
            return (true, daysRemaining)
        }

        return (false, daysRemaining)
    }
}
```

### 試用期結束彈窗

建立 `Views/Subscription/TrialEndedSheet.swift`：

```swift
struct TrialEndedSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)

            Text("試用期已結束")
                .font(.title)
                .fontWeight(.bold)

            Text("感謝您體驗 Premium 功能！")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("升級到付費版繼續享受：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                FeatureBenefitRow(icon: "brain", text: "AI 個性化訓練計劃")
                FeatureBenefitRow(icon: "chart.line.uptrend.xyaxis", text: "深度訓練分析")
                FeatureBenefitRow(icon: "bubble.left.and.bubble.right", text: "無限 AI 助手對話")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            NavigationLink(destination: SubscriptionView()) {
                Text("立即升級")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Button("使用免費版") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
        .padding(32)
    }
}

struct FeatureBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
        }
    }
}
```

---

## 5. 週課表差異化提示

### 實現位置
在 `TrainingPlanView` 顯示週課表時

### UI 設計

免費用戶看到的週課表底部添加提示：

```
┌─────────────────────────────────────────┐
│  週一：輕鬆跑 5K                           │
│  週二：休息                                │
│  週三：節奏跑 8K                           │
│  ...                                      │
│  ─────────────────────────────────────   │
│  💡 升級到 Premium 解鎖：                  │
│  • 詳細配速區間（如 5:20-5:30/km）         │
│  • AI 動態調整課表                         │
│  • 訓練組合細節                            │
│                                           │
│  [查看 Premium 功能] →                    │
└─────────────────────────────────────────┘
```

---

## 🚀 實施優先級

### Phase 1（立即實作）
1. ✅ 主畫面 Banner（最重要）
2. ✅ 鎖定功能遮罩層
3. ✅ 用戶資料頁訂閱卡片

### Phase 2（後續優化）
4. ⏰ 試用期倒數提醒
5. 📊 週課表差異化提示

---

## 📊 追蹤指標

### 需要追蹤的事件

在各入口添加事件追蹤：

```swift
// 點擊升級按鈕
Logger.firebase(
    "Subscription: 點擊升級按鈕",
    level: .info,
    labels: ["source": "main_banner", "user_type": "free"]
)

// 查看訂閱頁面
Logger.firebase(
    "Subscription: 查看訂閱頁面",
    level: .info,
    labels: ["source": "profile_section"]
)

// 點擊鎖定功能
Logger.firebase(
    "Subscription: 嘗試訪問鎖定功能",
    level: .info,
    labels: ["feature": "weekly_summary_ai"]
)
```

### 轉換漏斗

```
查看訂閱頁面
    ↓ (60%)
點擊開始試用
    ↓ (80%)
完成註冊
    ↓ (15-20%)
付費轉換
```

---

## ✅ 實施檢查清單

### 開發階段
- [ ] 建立 `SubscriptionPromoBanner` 元件
- [ ] 建立 `FeatureLockOverlay` 元件
- [ ] 在 `TrainingPlanView` 添加 Banner
- [ ] 在 `TrainingRecordView` 添加 Banner
- [ ] 在 `MyAchievementView` 添加 Banner
- [ ] 在 `UserProfileView` 添加訂閱區塊
- [ ] 在週回顧添加鎖定遮罩
- [ ] 在 Workout 詳情添加鎖定遮罩

### 測試階段
- [ ] 測試免費用戶看到的所有入口
- [ ] 測試試用期用戶看到的提示
- [ ] 測試付費用戶看到的狀態
- [ ] 測試點擊流程（入口 → 訂閱頁 → 購買）
- [ ] 測試鎖定功能的顯示

### 上線前
- [ ] 確認所有入口的文案正確
- [ ] 確認追蹤事件正常記錄
- [ ] 確認 UI 在不同設備尺寸正常顯示
- [ ] 確認深色模式下顯示正常

---

**文件版本**：1.0
**最後更新**：2025-11-04
**維護者**：iOS Team
