# CLAUDE.md — iOS App (Swift)

共通限制在 `../../../CLAUDE.md`（stacking 自動載入）。本檔只放 iOS 特有的陷阱。

## 陷阱

1. **用「算出來的 `Date`」當 Dictionary key 會查不到** — `Date` 本身是合法的 Hashable key，但兩個邏輯上同一天、由不同運算得出的 `Date` 浮點值可能差一點點，查表就 miss。要當 key 就先正規化（例如取 `TimeInterval` 或當日起點），別直接拿計算結果。
2. **碰 UI state 前先濾掉 `NSURLErrorCancelled`** — 取消的 task 是使用者正常導航，對它顯示 `ErrorView` 是在騙人。
3. **Repository 不 publish 到 `CacheEventBus`** — Repository 被動，事件流屬於 ViewModel/Service。寫法與回歸 grep 見 `.claude/rules/architecture.md`。
4. **HealthKit → Backend → UI**，不可 `HealthKit → UI`，否則 HealthKit 與 Firestore 兩份真相打架。
5. **初始化順序敏感**，單元測試看不出來的 race 都在這：`App Launch → Auth → User Data → Training Overview → Weekly Plan → UI Ready`。
6. **API 呼叫要串 `.tracked(from: "ViewName: functionName")`** — 沒串的話 production 事故追不到來源。
7. **命名**：產品叫 Paceriz，bundle ID 是 `com.havital.*`、目錄是 `Havital`，不要改。

## 指令

```bash
# UDID 別寫死（會隨 Xcode 版本失效）：xcrun simctl list devices | grep "iPhone 17 Pro"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

maestro test .maestro/flows/<flow>.yaml    # 別加 --no-window，用戶要看到畫面
```

Merge 進 main 前需 `/judge ios <branch>` 的裁判 verdict（root `merge_gate.py` 硬擋）。

發版：`fastlane ios release`（自動 bump build 號 → archive+簽章含 Watch → 上傳 → 送審，過審後手動 Release）；只 build 用 `fastlane ios build`。唯一人工關是 `fastlane/metadata/{zh-Hant,ja,en-US}/release_notes.txt` 三語文案。憑證從 `fastlane/.env.default` 自動載入，`.p8` 在 `~/.appstoreconnect/`。完整步驟 `fastlane/RELEASE.md`。

## 需要時再讀（不預載）

- `.claude/rules/architecture.md` — 分層與 Repository 事件流的完整規則＋回歸 grep
- `.claude/rules/testing.md` — 模擬器限制、Maestro 前置條件與腳本品質（跑 UI 測試前）
- `.claude/rules/delivery.md` — build gate 與新功能檢查表
- `.claude/rules/debugging.md` — 怎麼確認畫面上真正 render 的是哪個 view
