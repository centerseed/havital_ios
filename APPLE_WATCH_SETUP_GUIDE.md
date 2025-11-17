# Paceriz Apple Watch App - Xcode 設置指南

> 由於在命令行環境中無法直接操作 Xcode project，本文檔提供詳細的手動配置步驟。

---

## 📋 前提條件

- Xcode 15.0+
- watchOS 9.0+ SDK
- 有效的 Apple Developer 帳號
- 配對的 Apple Watch（用於測試）

---

## 🚀 Step 1: 創建 watchOS Target

### 1.1 在 Xcode 中添加 watchOS App Target

1. 打開 `Havital.xcodeproj`
2. 選擇 **File** → **New** → **Target...**
3. 選擇 **watchOS** → **App**
4. 配置 Target:
   - Product Name: `PacerizWatch`
   - Bundle Identifier: `com.havital.Paceriz.watchkitapp`
   - Language: **Swift**
   - User Interface: **SwiftUI**
   - 不勾選 "Include Notification Scene"

5. 點擊 **Finish**

### 1.2 配置 App Group

**iOS Target (Havital)**:
1. 選擇 Havital target
2. 進入 **Signing & Capabilities**
3. 點擊 **+ Capability** → **App Groups**
4. 添加 App Group: `group.com.havital.paceriz`

**watchOS Target (PacerizWatch)**:
1. 選擇 PacerizWatch target
2. 進入 **Signing & Capabilities**
3. 點擊 **+ Capability** → **App Groups**
4. 添加相同的 App Group: `group.com.havital.paceriz`

### 1.3 配置 HealthKit 權限

**watchOS Target (PacerizWatch)**:
1. 選擇 PacerizWatch target
2. 進入 **Signing & Capabilities**
3. 點擊 **+ Capability** → **HealthKit**
4. 勾選以下權限:
   - ✅ Clinical Health Records
   - ✅ Health Records

### 1.4 配置 Location 權限

**watchOS Target**:
1. 選擇 PacerizWatch target
2. 進入 **Info** tab
3. 添加以下 keys:
   - `NSLocationWhenInUseUsageDescription`: "Paceriz 需要 GPS 追蹤您的訓練路線"
   - `NSLocationAlwaysAndWhenInUseUsageDescription`: "Paceriz 需要 GPS 追蹤您的訓練路線"

---

## 📦 Step 2: 組織文件結構

### 2.1 刪除 Xcode 自動生成的文件

刪除以下自動生成的文件（已經有更完整的實現）:
- `PacerizWatchApp.swift` (Xcode 生成的，使用我們的版本)
- `ContentView.swift` (Xcode 生成的，不需要)

### 2.2 將源代碼文件添加到 Target

**共享文件**（同時添加到 iOS 和 watchOS target）:
1. 選擇 `Havital/Shared/` 下的所有文件
2. 在 **File Inspector** 中，勾選 **Target Membership**:
   - ✅ Havital (iOS)
   - ✅ PacerizWatch (watchOS)

**watchOS 專屬文件**（只添加到 watchOS target）:
1. 選擇 `PacerizWatch/PacerizWatch/` 下的所有文件
2. 確保只勾選 `PacerizWatch` target

**iOS 專屬文件**:
1. `Havital/Services/WatchConnectivityService.swift`
2. 確保只勾選 `Havital` target

---

## 🎨 Step 3: 添加 Assets

### 3.1 創建 watchOS App Icon

1. 打開 `PacerizWatch/PacerizWatch/Assets.xcassets`
2. 右鍵 → **New Image Set** → **watchOS App Icon**
3. 添加以下尺寸的 icon（使用 Paceriz app icon 的藍色跑鞋設計）:
   - 38mm: 80 × 80
   - 40mm: 88 × 88
   - 41mm: 92 × 92
   - 44mm: 100 × 100
   - 45mm: 108 × 108
   - 49mm: 110 × 110

### 3.2 配置 App Icon 設置

1. 選擇 PacerizWatch target
2. 進入 **General** → **App Icons and Launch Screen**
3. App Icon Source: `AppIcon`

---

## ⚙️ Step 4: 配置 Build Settings

### 4.1 設置 Deployment Target

**watchOS Target**:
- iOS Deployment Target: **9.0**
- Swift Language Version: **Swift 5**

### 4.2 配置 Frameworks

**watchOS Target 需要的框架**:
- SwiftUI (自動)
- HealthKit (已添加)
- CoreLocation (自動)
- WatchConnectivity (自動)
- WatchKit (自動)

---

## 🔗 Step 5: 配置 WatchConnectivity

### 5.1 在 iOS App 中啟用 WatchConnectivity

在 `HavitalApp.swift` 或適當的初始化位置添加:

```swift
import SwiftUI

@main
struct HavitalApp: App {
    // 添加 WatchConnectivity 服務
    @StateObject private var watchConnectivity = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchConnectivity)
        }
    }
}
```

### 5.2 在 TrainingPlanManager 中集成同步

在 `Havital/Managers/TrainingPlanManager.swift` 中，當課表更新時自動同步:

```swift
class TrainingPlanManager: ObservableObject {
    private let watchConnectivity = WatchConnectivityService.shared

    func generateWeeklyPlan() async {
        // ... 現有的課表生成邏輯 ...

        // 課表生成成功後，自動同步到 Watch
        if watchConnectivity.getSettings().syncOnPlanChange {
            await watchConnectivity.syncWeeklyPlan()
        }
    }
}
```

---

## 🏃 Step 6: 測試和調試

### 6.1 模擬器測試

1. 選擇 **Scheme**: `PacerizWatch`
2. 選擇目標設備: **Apple Watch Series 9 (45mm)** 或更新
3. 點擊 **Run** (⌘R)

**注意**: 模擬器中無法測試：
- HealthKit 數據採集
- GPS 追蹤
- 實際的心率監控

### 6.2 真機測試

1. 確保 Apple Watch 已配對並信任電腦
2. 選擇目標設備: 你的 Apple Watch
3. 點擊 **Run**

**首次運行檢查清單**:
- [ ] Watch app 成功安裝
- [ ] 可以看到課表列表
- [ ] 點擊課表可以看到詳情
- [ ] 點擊「開始訓練」可以進入訓練頁面
- [ ] HealthKit 權限提示正常顯示
- [ ] GPS 權限提示正常顯示

### 6.3 調試 WatchConnectivity

在 **Xcode Console** 中查看日誌:

```
✅ WatchConnectivity: 激活成功
✅ WatchDataManager: 數據同步成功
✅ WorkoutManager: 訓練已開始
⚠️ SegmentTracker: 5 秒倒數警告
```

---

## 🐛 常見問題排查

### 問題 1: "No such module 'WatchConnectivity'"

**解決方案**:
1. 確保 WatchConnectivity framework 已鏈接
2. Clean Build Folder (⇧⌘K)
3. 重新 Build

### 問題 2: 共享文件無法找到

**解決方案**:
1. 確保 `Havital/Shared/` 下的所有文件都勾選了 `PacerizWatch` target
2. 檢查 **Target Membership** 設置

### 問題 3: App Group 無法讀取數據

**解決方案**:
1. 確保 iOS 和 watchOS target 使用相同的 App Group ID
2. 確保 App Group 在 Developer Portal 中已啟用
3. 重新生成 Provisioning Profile

### 問題 4: HealthKit 權限被拒絕

**解決方案**:
1. 檢查 `Info.plist` 中的權限描述
2. 在 Settings → Privacy → Health 中手動授權
3. 重新安裝 app

### 問題 5: GPS 無法定位

**解決方案**:
1. 確保在戶外測試（室內 GPS 信號弱）
2. 檢查 Location 權限是否已授予
3. 等待 GPS 冷啟動（首次可能需要 30-60 秒）

---

## 📊 性能優化建議

### 6.1 電池優化

- ✅ 訓練結束後立即停止 GPS 更新
- ✅ 使用 `desiredAccuracy = kCLLocationAccuracyBest` 僅在訓練中
- ✅ 心率採樣頻率：每秒 1 次（已優化）

### 6.2 數據同步優化

- ✅ 使用 Application Context 進行背景同步
- ✅ 僅同步必要數據（當週課表 + 用戶配置）
- ✅ 實現本地緩存避免頻繁同步

### 6.3 UI 響應優化

- ✅ 使用 `@MainActor` 確保 UI 更新在主線程
- ✅ 避免在訓練中執行複雜計算
- ✅ 使用 `.monospacedDigit()` 避免數字跳動

---

## 🚀 發布準備

### 7.1 App Store Connect 配置

1. 創建新的 App（如果還沒有）
2. 添加 watchOS App 作為關聯 app
3. 配置 HealthKit 使用說明
4. 添加螢幕截圖（各種 Apple Watch 尺寸）

### 7.2 提交審核注意事項

**必須提供**:
1. HealthKit 使用說明（為什麼需要心率、GPS 數據）
2. 測試帳號和測試數據
3. 演示影片（展示訓練流程）

**潛在審核問題**:
- ⚠️ HealthKit 數據使用必須合理且透明
- ⚠️ GPS 使用必須在訓練中，不能背景持續追蹤
- ⚠️ 必須在 iPhone app 中也提供相同功能（不能 Watch 獨佔）

---

## 📝 後續改進建議

### Phase 2 功能

1. **語音播報**
   - 每公里播報配速/心率
   - 進入/離開區間提示

2. **複雜訓練支持**
   - 力量訓練追蹤
   - 瑜伽/騎行模式

3. **社交功能**
   - 訓練完成分享到社群
   - 成就系統

4. **離線增強**
   - watchOS 獨立網路請求
   - 無需 iPhone 也能運行

5. **數據分析**
   - 訓練後詳細分析
   - 心率變異性分析
   - 配速分布圖表

---

## ✅ 驗收測試清單

在提交代碼或發布前，確保以下功能正常:

### 基本功能
- [ ] 課表同步（iOS → watchOS）
- [ ] 課表列表顯示正確
- [ ] 課表詳情顯示完整
- [ ] 間歇訓練分段正確顯示
- [ ] 組合跑多階段正確顯示

### 訓練功能
- [ ] 開始訓練按鈕正常工作
- [ ] HealthKit 權限請求正常
- [ ] GPS 定位正常
- [ ] 心率實時更新
- [ ] 配速實時計算正確
- [ ] 距離累計正確

### 分段追蹤
- [ ] 間歇訓練組數追蹤正確
- [ ] 工作段/恢復段切換正常
- [ ] 5秒倒數提示音正常
- [ ] 段落完成提示音正常
- [ ] 組合跑階段切換正常

### UI 體驗
- [ ] 心率區間指示器正確延伸
- [ ] 配速區間指示器正確延伸（慢左快右）
- [ ] 超出區間時顯示警告
- [ ] 次要指標顯示正確
- [ ] 暫停/繼續按鈕正常
- [ ] 結束訓練確認對話框正常

### 數據保存
- [ ] 訓練數據保存到 HealthKit
- [ ] 包含心率時間序列
- [ ] 包含 GPS 軌跡
- [ ] iOS app 可以讀取訓練記錄

---

## 🆘 獲取幫助

如遇到問題:
1. 查看 Xcode Console 日誌
2. 檢查本文檔的「常見問題排查」章節
3. 參考設計文檔: `APPLE_WATCH_DESIGN_FINAL.md`
4. 提交 Issue 到 GitHub repository

---

**文檔版本**: 1.0
**最後更新**: 2025-11-17
**適用於**: watchOS 9.0+, iOS 16.0+
