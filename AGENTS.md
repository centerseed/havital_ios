# iOS — Havital shared rules

This file is the canonical repo-local entrypoint for Codex and Claude Code.
`CLAUDE.md` imports it and may add Claude-only behavior; it is not a shared
policy source. Also read `/Users/wubaizong/havital/AGENTS.md` and the shared
protocol in `/Users/wubaizong/havital/docs/development/LOCAL-DEVELOPMENT-HARNESS.md`.

## 成規

- 持久化訓練真相走 **backend**。HealthKit 權限／純裝置展示可 local；禁 UI 第二份 persisted 真相。
- 穿戴：`HealthKit → backend → UI`，禁 `HealthKit → UI`。
- 用戶字串：`Localizable.strings`（zh-Hant／en／ja），三語齊。
- 有 repository protocol → ViewModel 依 protocol。Repository **被動**，不 publish `CacheEventBus`。
- API DTO 在 data；domain 不綁 wire format（既有契約例外除外）。
- App UI：app 設計語言。行銷深板岩藍面板只限 `marketing/`。
- 跨邊界契約先查兩邊；只在需求與證據要求時改兩邊。
- Bug 先真實 path repro。自己引入的紅必須清。
- **查出 backend 問題 → 開票給 backend**，不在 app 硬繞。

## 陷阱

1. 算出來的 `Date` 當 Dictionary key 可能 miss → 當 key 先正規化（日起點／`TimeInterval`）。
2. UI error 前濾 `NSURLErrorCancelled`。
3. 初始化順序：`Launch → Auth → User Data → Training Overview → Weekly Plan → UI Ready`。
4. API 呼叫串 `.tracked(from: "ViewName: functionName")`。
5. 可取消 async：lifecycle 邊界 cancel；取消後不更新 UI。既有 `TaskManageable` 沿用。

## 指令

```bash
# 優先 booted simulator；UDID 別寫死
xcodebuild build -project Havital.xcodeproj -scheme Havital \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
maestro test .maestro/flows/<flow>.yaml    # 禁 --no-window
```

發版前遵守 `fastlane/RELEASE.md`，確認三語 notes 並取得使用者批准。Merge 前先完成 shared
external verdict contract，再從該 repo checkout 執行 shared merge gate。

## 需要時再讀

`fastlane/RELEASE.md` · `.Codex/rules/architecture.md`（若存在）· root `docs/` 的相關 spec/decision。
