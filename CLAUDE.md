# CLAUDE.md — iOS App (Swift)

專案共通限制（證據優先、mock 邊界、不部署、i18n/時區、環境表、跨 repo 架構）在 `../../../CLAUDE.md`，會 stacking 自動載入。本檔只放 iOS 特有的。

## iOS 特有的坑

1. **`Date` 不能當 Dictionary key** — 用 `TimeInterval`。`Date` 的 `Hashable` 與時間相關，編譯不會擋，直接 runtime 靜默出錯。查回歸：`grep -r "Dictionary.*Date\|Date.*Dictionary" Havital/ --include="*.swift"`
2. **碰 UI state 前先濾掉 `NSURLErrorCancelled`** — 取消的 task 是使用者正常導航，對它顯示 `ErrorView` 是在騙人。
3. **Repository 不 publish 到 `CacheEventBus`** — Repository 是被動資料存取，事件流屬於 ViewModel/Service。正確寫法與回歸 grep 見 `.claude/rules/architecture.md`。
4. **HealthKit → Backend → UI**，不可 `HealthKit → UI`，否則 HealthKit 與 Firestore 兩份真相打架。
5. **初始化順序很敏感**，單元測試看不出來的 race 都在這裡：`App Launch → Auth → User Data → Training Overview → Weekly Plan → UI Ready`
6. **每個 API 呼叫串 `.tracked(from: "ViewName: functionName")`** — 沒串的話 production 事故追不到來源。
7. **每個 ViewModel/Manager 都實作 `TaskManageable`**（`TaskRegistry` + deinit 呼叫 `cancelAllTasks()`）。
8. **命名陷阱**：產品叫 Paceriz，但 bundle ID 是 `com.havital.*`、目錄是 `Havital`，不要改。

## 指令

```bash
# Build（固定用 iPhone 17 Pro；UDID 別寫死，現查：
#   xcrun simctl list devices | grep "iPhone 17 Pro" ）
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Maestro UI 測試（不要加 --no-window，用戶要看到畫面）
maestro test .maestro/flows/<flow>.yaml
```

Merge 進 main 前需 `/judge ios <branch>` 取得裁判 verdict（root `scripts/hooks/merge_gate.py` 硬擋）。

## 架構

`Presentation → Domain → Data → Core`，依賴只能向內。DTO 在 Data（snake_case + `CodingKeys`）、Entity 在 Domain（camelCase，不 Codable，避免 Domain 綁死序列化格式）。ViewModel 依賴 Repository protocol，不依賴 `RepositoryImpl`。單例：HTTPClient / Logger / DataSource / Mapper / RepositoryImpl；ViewModel 每次使用新建。

完整規則：`.claude/rules/architecture.md`

## 發版

fastlane 已串好並實測。完整步驟 → `fastlane/RELEASE.md`。
- 正式發版：`fastlane ios release`（自動 bump build 號 → archive+簽章含 Watch → 上傳 → 推 release notes → 送審，過審後手動 Release）
- 只 build 給手動上傳：`fastlane ios build`；查現行版本：`fastlane ios info`
- 唯一人工關：填 `fastlane/metadata/{zh-Hant,ja,en-US}/release_notes.txt` 三語文案
- 憑證：ASC 金鑰自動載入自 `fastlane/.env.default`（不進 git），`.p8` 在 `~/.appstoreconnect/`

## 需要時再讀（不預載）

- `.claude/rules/architecture.md` — 分層與 Repository 事件流的完整規則＋回歸 grep
- `.claude/rules/testing.md` — 模擬器環境限制、Maestro 前置條件與腳本品質規則（跑 UI 測試前讀）
- `.claude/rules/delivery.md` — build gate 與新功能檢查表（要宣稱完成前讀）
- `.claude/rules/debugging.md` — bug 分流：怎麼確認「畫面上真正被 render 的是哪個 view」、失敗分類（app bug / script bug / 環境問題）
