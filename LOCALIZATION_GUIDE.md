# Havital iOS App 多國語言實作指南

## 🎯 已完成項目

### ✅ Phase 1-5: 基礎架構與核心功能
1. **本地化檔案結構** - 已建立 zh-Hant, en, ja 三種語言的 Localizable.strings
2. **Type-safe Keys** - LocalizationKeys.swift 提供類型安全的字串鍵值
3. **語言管理器** - LanguageManager.swift 處理語言切換與同步
4. **設定介面** - LanguageSettingsView.swift 提供語言選擇 UI
5. **主導航本地化** - ContentView 的 TabView 已使用本地化字串

## 📝 使用方法

### 1. 替換硬編碼字串的標準流程

#### Before (硬編碼):
```swift
Text("訓練計劃")
Button("儲存") { }
.navigationTitle("個人資料")
```

#### After (本地化):
```swift
Text(L10n.Tab.trainingPlan.localized)
Button(L10n.Common.save.localized) { }
.navigationTitle(L10n.Profile.title.localized)
```

### 2. 動態字串本地化

#### 格式化字串:
```swift
// 在 Localizable.strings 中定義:
"training.week" = "Week %d";  // 英文
"training.week" = "第 %d 週";  // 中文

// 在程式碼中使用:
Text(L10n.Training.week.localized(with: weekNumber))
```

### 3. 日期時間格式化

使用 LanguageManager 的格式化方法:
```swift
// 日期格式化
let dateString = LanguageManager.shared.formatDate(workout.date)

// 時間格式化
let timeString = LanguageManager.shared.formatTime(workout.startTime)
```

### 4. 單位格式化 (目前僅支援公制)

⚠️ **注意**: 後端系統目前僅支援公制單位 (km, min/km)，英制支援將在未來版本加入。

```swift
// 距離格式化 (僅公制)
let distance = LanguageManager.shared.formatDistance(workout.distance)

// 配速格式化 (僅公制)  
let pace = LanguageManager.shared.formatPace(workout.averagePace)
```

## 🔄 剩餘工作指引

### Phase 6: 訓練視圖本地化
檔案位置: `Havital/Views/Training/`

重點替換項目:
- TrainingPlanView.swift: "每日訓練", "週跑量", "訓練回顧"
- TrainingRecordView.swift: "訓練紀錄", 日期篩選選項
- WeeklyPlanView.swift: 訓練類型名稱

範例:
```swift
// 替換前
Text("輕鬆跑")

// 替換後
Text(L10n.Training.TrainingType.easy.localized)
```

### Phase 7: 個人資料與設定視圖
檔案位置: `Havital/Views/`

重點替換項目:
- UserProfileView.swift: 所有區段標題與按鈕文字
- 心率區間相關文字
- 數據來源狀態文字

已部分完成的範例:
```swift
// UserProfileView 中已加入語言設定按鈕:
Button(action: { showLanguageSettings = true }) {
    HStack {
        Image(systemName: "globe")
        Text("語言設定")  // 需替換為 L10n.Settings.language.localized
    }
}
```

### Phase 8: 認證與引導流程
檔案位置: `Havital/Views/Onboarding/`, `Havital/Views/Auth/`

重點替換項目:
- LoginView: 登入表單所有文字
- OnboardingView: 每個步驟的說明文字
- 錯誤訊息與提示

### Phase 9: 錯誤訊息本地化
全域搜尋並替換:
- Alert 標題與內容
- 錯誤提示訊息
- 載入狀態文字

範例:
```swift
// 替換前
.alert("網路連線錯誤", isPresented: $showError)

// 替換後
.alert(L10n.Error.network.localized, isPresented: $showError)
```

### Phase 10: 進階格式化
實作地區特定的格式:
- 數字格式（千分位符號）
- 百分比顯示  
- 日期時間本地化格式

⚠️ **單位系統說明**:
- 目前僅支援公制單位 (km, min/km)
- 英制支援需等待後端系統升級
- 所有距離、配速計算都使用公制

## 🧪 測試方法

### 1. 語言切換測試
```swift
// 在模擬器中測試:
1. 進入 設定 > 語言設定
2. 選擇不同語言
3. 儲存並確認 App 重啟
4. 驗證所有文字都已更新
```

### 2. 單元測試範例
```swift
func testLocalizationKeys() {
    // 測試所有語言都有對應的字串
    let languages = ["zh-Hant", "en", "ja"]
    
    for lang in languages {
        let bundle = Bundle(path: Bundle.main.path(forResource: lang, ofType: "lproj")!)!
        let localizedString = NSLocalizedString("tab.training_plan", bundle: bundle, comment: "")
        XCTAssertNotEqual(localizedString, "tab.training_plan")
    }
}
```

## 🚀 後續優化建議

1. **右到左語言支援** (RTL)
   - 未來若要支援阿拉伯文或希伯來文
   - 需要調整 UI 佈局方向

2. **動態字型大小**
   - 支援系統的動態字型設定
   - 確保文字在不同大小下都能正確顯示

3. **圖片本地化**
   - 某些包含文字的圖片可能需要不同語言版本

4. **App Store 本地化**
   - App 名稱、描述、截圖的多語言版本

## 📌 注意事項

1. **⚠️ 單位系統限制**
   - **僅使用公制**: 後端只支援公制 (km, min/km)
   - **避免英制轉換**: 不要在前端進行英制轉換，會造成數據不一致
   - **保持一致**: 所有距離顯示都使用 km，配速使用 min/km

2. **避免字串拼接**
   ```swift
   // ❌ 錯誤
   Text("共 " + "\(count)" + " 項")
   
   // ✅ 正確
   Text(L10n.Common.itemCount.localized(with: count))
   ```

3. **保持一致性**
   - 同一概念在不同地方使用相同的翻譯
   - 建立術語表確保翻譯一致

4. **測試邊界情況**
   - 長文字是否會截斷
   - 短文字是否會造成佈局問題

## 🔗 相關檔案

- `/Havital/Resources/*/Localizable.strings` - 所有本地化字串
- `/Havital/Utils/LocalizationKeys.swift` - 類型安全的鍵值定義
- `/Havital/Managers/LanguageManager.swift` - 語言管理邏輯
- `/Havital/Views/Settings/LanguageSettingsView.swift` - 語言設定 UI

## 📱 API 整合

後端 API 端點已支援:
- `GET /user/preferences` - 取得語言偏好
- `PUT /user/preferences` - 更新語言偏好

支援的語言代碼:
- `zh-TW` - 繁體中文
- `en-US` - 英文
- `ja-JP` - 日文

---

這份指南提供了完整的本地化實作方法，您可以按照 Phase 6-10 的指引繼續完成剩餘的本地化工作。