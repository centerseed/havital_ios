---
type: TD
id: TD-paywall-rewrite
status: Draft
related_specs: []
created: 2026-04-26
updated: 2026-04-26
---

# TD-paywall-rewrite — Paceriz Premium Paywall 重寫提案

## 目的

現有 paywall sheet（見背景）有三個結構性問題，導致轉換率低、訊息不清：

1. **價值不具體**：「升級以解鎖完整功能」「解鎖專屬訓練計畫，突破個人極限」是任何 fitness app 都能用的空話，沒有讓用戶感受到「Paceriz 給我什麼是我現在沒有的」。
2. **AI gating 不透明**：app 的核心 AI 功能（週課表 generation、Rizo 教練、賽事預測）在沒訂閱時會被擋下，但 paywall 沒清楚指出「這些功能是付費的」。用戶在被擋下的當下才第一次認識到這件事 → 體感差。
3. **Sheet title 三軌制**：`升級` / `Resubscribe` / `變更方案` 三個進場點分別顯示不同 navigation title，破壞品牌一致性。

App 尚未上 App Store，是改 paywall 訂閱策略的最後一個免責窗口。本文件提出：(1) 競品 paywall 觀察 → (2) Paceriz 的 trial 策略 → (3) 全新 sheet 結構與三語文案，可直接 dispatch 給 dev。

---

## 1. 競品研究

### 1.1 Runna — 直接競品（AI 跑步教練）

**來源**：
- [Runna Pricing](https://www.runna.com/pricing)
- [How to Use Runna for Free](https://support.runna.com/en/articles/11168168-how-to-use-runna-for-free)
- [Managing Your Runna Subscription](https://support.runna.com/en/articles/8112247-managing-your-runna-subscription)
- [ScreensDesign — Runna Paywall Showcase](https://screensdesign.com/showcase/runna-running-training-plans)
- [Mostly.media — Runna Premium Review](https://mostly.media/stravas-runna-app-worth-the-premium-review-breakdown/)

**Trial 機制**：
- 7 天免費試用（first-time users）
- **必須綁卡**：「You will need to confirm your payment details to access the trial, but you will not be charged for Runna Premium until after your free trial has ended.」
- 隱藏條款：「Your 1-week free trial will expire if you don't create a plan within 48 hours of downloading the Runna app.」
- 取消規則：「You will need to cancel your trial at least 24 hours prior to the expiry date if you do not wish to be charged.」
- 限新用戶（first-time only）

**Hero copy（pricing 頁）**：
- Title: 「Become a Runna」
- Subtitle: 「Unlock your potential with a personalized plan. Push for progress with elite coaching. Be part of something big.」

**Features list**（分成 4 個 group，這是 Runna 的關鍵設計）：

| Group | Bullets |
|---|---|
| **Personalized Plans** | Train for any distance / Custom plans for every race / Adapts to your performance / Holistic support before, during and after your plan |
| **Expert Coaching** | Plans built by elite coaches / Olympic-level experience provided with each plan / Expert advice on pacing, scheduling and more / Support from the Runna team when you need it |
| **Tech Integration** | Sync with your favorite devices / Apple Watch, Garmin, Fitbit, Coros & more / Connect with Strava / Workout insights & progress tracking |
| **Exclusive Perks** | Unlock discounts to carefully-selected brands / Free Couch to 5K / Access to new features at launch / Exclusive events & prize giveaways |

**CTA**：`Join Now`
**Disclosure**：「First week free. Cancel anytime.」
**Pricing**：年訂 $119.99（標 "That's $9.99/month – Save 50%"），月訂 $19.99

**In-app paywall 設計（從 ScreensDesign 拆解）**：
- Paywall 出現在 onboarding 結尾（影片 02:17 處），緊接在 personalization quiz 之後
- 進入 paywall **前**先顯示用戶選擇摘要（02:12），「reinforcing the personalized value they are about to unlock」— 這是 Runna 最關鍵的 UX：先給你看你即將失去什麼，再 ask for 訂閱
- 兩個 tier side-by-side，年訂視覺 emphasized
- 把年訂價格 break down 成週價（$2.30/week），降低數字感
- 帶 social proof：星等、testimonial
- 標籤「SAVE 50%」在年訂卡片

**對 Paceriz 的啟示**：
- ✅ Features 分組（不是一個 flat list）讓用戶能快速 scan 自己關心的項目
- ✅ Onboarding → personalization quiz → paywall 的順序是 Runna 轉換率高的關鍵
- ⚠️ Runna 的「48 小時內必須建 plan 不然 trial 失效」是個 dark pattern，Paceriz 不要學
- ⚠️ Runna trial 7 天偏短（為了讓 funnel 快速收斂）— 對 Paceriz 來說，跑步訓練計畫的 value 通常要 2-4 週才感受得到，7 天不夠

---

### 1.2 Strava Premium — 行業 reference

**來源**：
- [Strava Subscribe](https://www.strava.com/subscribe)
- [Strava Subscription Preview Support](https://support.strava.com/hc/en-us/articles/39188221577741-Strava-Subscription-Preview)
- [Engadget — Strava moving features behind subscription](https://www.engadget.com/strava-is-moving-some-free-features-behind-a-subscription-120156844.html)
- [Android Authority — Strava Membership cost](https://www.androidauthority.com/strava-membership-3231073/)
- [PaywallPro — Top Fitness App Paywalls](https://dev.to/paywallpro/top-fitness-app-paywalls-ux-patterns-pricing-insights-2868)

**Trial 機制（兩條）**：
1. **Subscription Preview（30 天，無需綁卡）**：「30 days of full subscription access with no credit card required」「The trial auto-expires with zero dark patterns」「Users see full value before paying」
2. **30-day free trial（要綁卡）**：透過綁卡進入的 paid trial path

兩者並存——Strava 用 Preview 作為 acquisition tool（降低嘗試門檻），用 paid trial 作為 conversion tool。

**Hero copy（subscribe 頁）**：
- Title: 「Strava Subscription」
- Subtitle: 「The best of Strava. Built for your goals.」
- 另一段強化文案: 「Upgrade your account for even more stats.」

**Features list**：
- Routes with offline maps
- Advanced training insights and progress tracking
- Live Segments and Segment Leaderboards
- Personal Heatmaps
- HR & Power Analysis
- Custom challenges and leaderboard competition
- Fitness Score monitoring
- Goal setting and tracking
- Beacon on devices
- Partner Perks

**CTA**：`Start free trial`
**Disclosure**：「30-day trial for ¥0 / ¥650/mo after 30 days. When billed annually. Excludes applicable taxes」+「Cancel at least 24 hours before」

**Pricing**（US）：年訂 $79.99（$6.67/月），月訂 $11.99，學生年訂 $39.99，家庭方案 $139.99

**Page 結構（從官網順序觀察）**：

```
1. Hero (title + subtitle)
2. Timeline visual（"Today / Day 28 / Day 30" 三步式）
3. Bundle offer（Strava + Runna $149.99/yr，up to 60% saving）
4. Plan options grid（Individual / Family / Student / Bundle）
5. Feature showcase（icons + description）
6. Comparison table（Free vs Subscription）
7. CTA repeat
```

**Strava 的 timeline 視覺設計（這是要學的關鍵）**：
- Day 1（今天）：「Start your free trial. Get instant access to everything.」
- Day 28：「We'll send a reminder before your trial ends.」
- Day 30：「Your subscription begins. Cancel anytime.」

這個三步 timeline 把「30 天後扣款」這件事轉化成可預期、有掌控感的旅程，而不是恐嚇式 disclosure。**Paceriz 的 default 選項應該採用此模式**。

**對 Paceriz 的啟示**：
- ✅ **Timeline visual** — 把 trial 機制 narrative 化，是降低訂閱焦慮的最有效設計
- ✅ Subscription Preview（無綁卡）+ paid trial（綁卡）並存的 dual-track 值得思考，但對只有 iOS Storekit 的小團隊來說太複雜，Paceriz 先做 paid trial 即可
- ⚠️ Strava 的 features list 太長（10+ 條）導致用戶 scan 不下去，Paceriz 控制在 4-6 條

---

### 1.3 Nike Run Club — 反例：完全免費

**來源**：
- [Nike Run Club App page](https://www.nike.com/nrc-app) (403, 用次要來源)
- [Mostly.media — NRC vs Runna](https://mostly.media/nike-run-club-vs-runna-which-running-app-delivers-real-value-in-2025/)
- [Tom's Guide — NRC Review](https://www.tomsguide.com/reviews/nike-run-club-review)
- [Gear Patrol — NRC App Review](https://www.gearpatrol.com/fitness/a43976920/nike-run-club-app-review/)

**Trial 機制**：N/A
**Pricing**：100% 免費，沒有 paywall

**價值取捨**：
- 「a set of fixed audio-guided runs and straightforward training plans」
- 「The audio coaching is pre-recorded and doesn't adapt to your pace or performance, making the experience simple and accessible, but lacking in nuance or flexibility」
- NRC 是 Nike 的 marketing 工具，目的是賣鞋，所以 app 本身不收訂閱

**對 Paceriz 的啟示**：
- ⚠️ Paceriz **不能跟 NRC 競爭「免費」**——NRC 背後有 Nike 鞋款補貼，而 Paceriz 無
- ✅ 但要承認：競品中存在「免費基線」，所以 Paceriz 的 free tier 必須夠好讓用戶嘗試（不是 trial 時才有東西用），同時 premium 的價值要清楚到「我願意每月付這個錢」
- ✅ Paywall 文案要避開「unlock training plans」這種跟 NRC 重疊的承諾，要強調「**adaptive / AI-driven / personalized**」這些 NRC 做不到的事

---

### 1.4 Garmin Connect+ — 從硬體用戶轉訂閱（2024 新推）

**來源**：
- [Tom's Guide — Garmin Connect+ launch](https://www.tomsguide.com/wellness/smartwatches/garmin-launches-a-paywall-here-are-all-the-premium-connect-features-that-will-cost-you-usd6-99-a-month) (內容無法 fetch，僅標題)
- [The 5K Runner — Connect+ review (2026-04)](https://the5krunner.com/2026/04/20/garmin-connect-plus-review/)
- [TechRadar — Garmin Connect Plus](https://www.techradar.com/health-fitness/garmin-connect-plus)
- [Garmin Q1 2025 earnings call coverage](https://www.gsmgotech.com/2026/02/garmins-connect-plus-subscription.html)

**Trial 機制**：
- 30 天免費試用（new users）
- 14 天 extension（returning trial users）
- 要綁卡

**Pricing**：
- US: $6.99/月 或 $69.99/年
- UK: £6.99/月 或 £69.99/年
- AU: AU$12/月 或 AU$120/年

**Features list（11 條，分 launch + 後續加入）**：

Launch features (7)：
1. Active Intelligence AI prompts
2. Performance Dashboard with customizable charts
3. Live Activity（real-time workout mirroring）
4. LiveTrack text alerts and profile customization
5. Expanded Garmin Coach content
6. Exclusive badges and challenges
7. Profile star icon

Added features (4)：
8. Trails+（curated trail routing）
9. 3D Maps（topographic rendering）
10. Connect Rundown（annual summary）
11. Nutrition tracking with AI image recognition

**Hero copy / CTA**：找不到具體截圖文案，**未找到**。

**Strategic outlook**（從 Garmin Q1 2025 earnings call）：
> 「new, advanced features, particularly AI-based insights, will be reserved exclusively for the premium subscription tier」

**用戶反彈**：
> 「For most Garmin owners, the subscription is not worth paying for on an annual basis」(The 5K Runner)
> 「Garmin sparks outrage with Connect+ subscription paywall」(Tom's Guide)

**對 Paceriz 的啟示**：
- ⚠️ Garmin 的反彈來自於「**已經買了硬體，為什麼還要付軟體錢**」的破壞性遷移，Paceriz 從第一天就是訂閱制，沒有這個負債
- ✅ 「**AI-based insights are premium**」這條訊息明確、用戶能接受。Paceriz 應該明白寫出「AI 功能是 premium」，不要曖昧
- ✅ Features 分為「launch + 後續加入」是 SaaS 心法——讓用戶感覺訂閱在持續變好。Paceriz 的 paywall 可以加一句「持續上新功能」

---

### 1.5 Whoop — 純訂閱制 / 多 tier / commitment-focused

**來源**：
- [WHOOP Membership page](https://www.whoop.com/us/en/membership/)
- [TechRadar — WHOOP 5.0 launch](https://www.techradar.com/health-fitness/smartwatches/whoop-unveils-two-brand-new-wearables-three-new-subscription-tiers)
- [NextPit — WHOOP buying guide](https://www.nextpit.com/how-tos/whoop-5-0-whoop-mg-buying-guide-subscription-plans-explained)
- [SanDiegoJay — Whoop Pricing Tiers](https://sandiegojay.com/blog/What-You-Get-With-Each-of-Whoop-s-Pricing-Tiers)

**Trial 機制**：
- 「Free trial available」（noted under PEAK tier only）
- 沒有公開的 standalone trial，傾向以 tier upgrade 試用
- Whoop 不靠 trial 拉新，靠**承諾感**（沒訂閱 = device 完全不能用）

**Hero copy**：
- Title: 「Memberships made for you」
- Subtitle: 「Each membership includes a device, a charger, and a unique set of features — choose the one that best fits your health and fitness goals.」

**Tier 結構**：

| Tier | Price | Tagline | Key features |
|---|---|---|---|
| **One** | $199/yr ($25/mo) | 「foundational health and fitness tracking」 | Sleep/Strain/Recovery, Cardio & Muscular Load, Personalized coaching, VO2 Max, HR zones, Women's Hormonal Insights |
| **Peak** | $239/yr ($30/mo) | 「optimize fitness... long-term health and resilience」 | Everything in One + Healthspan & Pace of Aging, Health Monitor with alerts, Real-time Stress Monitor |
| **Life** | $359/yr ($40/mo) | 「most in-depth health tracking, including medical-grade」 | Everything in Peak + Daily Blood Pressure Insights (beta), Heart Screener with ECG, Irregular Heart Rhythm Notifications |

**CTA**：`START WITH ONE` / `START WITH PEAK` / `START WITH LIFE`（注意 verb 是 "start"，不是 "buy"，框架成「開始一段旅程」）

**對 Paceriz 的啟示**：
- ✅ 「**START WITH X**」的 verb 比「升級」「訂閱」更有 forward momentum
- ✅ Tier-based 思路 Paceriz **暫時不適合**——Whoop 有硬體鎖訂閱才合理，Paceriz 是 software-only，多 tier 會稀釋訊息
- ⚠️ Whoop 的 「Free trial available」隱藏在某個 tier 下，標示太弱——Paceriz 的 trial 必須 hero level visible
- ✅ Hero subtitle「choose the one that best fits your goals」這種「以你為主」的語氣比「unlock potential」更有 grounding

---

### 1.6 競品 cross-table

| 維度 | Runna | Strava | NRC | Garmin Connect+ | Whoop |
|---|---|---|---|---|---|
| Trial 天數 | 7 天 | 30 天（preview 無卡）/ 30 天（paid） | N/A | 30 天 | （隱藏） |
| 要綁卡 | ✅ | Preview ❌ / Paid ✅ | N/A | ✅ | ✅ |
| 限新用戶 | ✅ | 視 Apple ID 而定 | N/A | ✅ | ✅ |
| Hero 訴求 | 個人化 + 教練 | 數據 + 目標 | (free) | AI insights | Membership identity |
| Features 分組 | 4 組 | 1 flat list | (free) | 1 list（launch + added） | 跨 tier 比較 |
| Timeline 視覺 | ❌ | ✅ 三步 | N/A | ❌ | ❌ |
| Pricing 框架 | 年訂 break to weekly | annual highlight | (free) | 年訂 ~ 月訂 ×10 | 純年訂 |
| CTA verb | "Join" | "Start free trial" | (free) | (未找到) | "Start with X" |

**核心觀察**：
1. **要做 trial 就要綁卡**（Runna/Garmin/Whoop 都是綁卡 trial），Strava Preview 的「無卡」是例外，且需要團隊有資源做 entitlement 切換邏輯。Paceriz 走 Apple Introductory Offer = 必綁卡。
2. **Trial 長度的中位數是 7-30 天**。30 天最常見（Strava + Garmin），7 天用於快速 funnel（Runna），14 天較少。
3. **Timeline 視覺只有 Strava 做**，這是 Paceriz 的差異化機會。
4. **Features 分組 vs flat list**：兩種都有人用，但 Paceriz 功能多元（plan + analysis + coach + race），分組更易 scan。

---

## 2. Paceriz Trial 策略建議

### 2.1 Trial 天數推薦：**14 天**

**理由**：
- **跑步訓練週期感**：跑步計畫的 value 不是看一天就能感受到，要看「課表如何適應我這週的恢復狀況」「賽事預測如何隨訓練調整」。7 天太短（Runna），用戶完成 1-2 次跑步剛要進入第 2 週的 plan adjustment 就被扣款。
- **30 天太長的 Apple 取消窗口**：Apple Introductory Offer 用戶會在 trial 第 1-2 天就決定「要不要繼續」（因為設定 calendar reminder），30 天的成本對 Paceriz（小團隊、剛上 App Store）太重。
- **競品依據**：Strava 的 30 天適合「已有 free 用戶 + 想升級」的場景；Runna 的 7 天適合「轉換明確、quiz-driven funnel」。Paceriz 介於兩者之間（沒有大規模 free 流量、但 funnel 不是 Runna 那麼 aggressive personalization），14 天是合理 middle ground。

如果要更保守 → **7 天**（跟 Runna 一致，funnel 快、燒 retention 快）。
如果要更 aggressive → **30 天**（學 Strava，但要算清楚扣款延遲對現金流的影響）。

**最終建議**：開站前 6 個月走 14 天，等 retention data 出來再 A/B 測 7 vs 30。

### 2.2 早鳥 + Free Trial 共存策略：**建議 (a) — default 有 30 天 trial，早鳥沒有 trial 但折扣**

**選項回顧**：
- (a) default 有 trial，早鳥沒有 trial 但有折扣 → 用戶二選一（**推薦**）
- (b) 兩個都有 trial → Apple 限制下用戶只能體驗一次
- (c) 早鳥退場，全走 default + trial

**為什麼選 (a)**：

1. **Apple Introductory Offer 一輩子一次的限制**（同一 subscription group）：如果兩個 offering 都有 trial，用戶選一個就用掉這輩子的 trial 機會。實際上 Apple 會自動 fallback，但用戶 perception 是「我為了試 7 天的早鳥，放棄了 14 天的 default trial」——這個對話極差。
2. **早鳥的核心 value 是「commitment 換折扣」**：早鳥用戶的人格設定 = 我願意現在就承諾、不需要試用。給他們 trial 反而稀釋這個訊息。
3. **Default trial 的核心 value 是「降低門檻」**：給沒信心的用戶一個「先體驗」的選項。
4. **二選一的 UX 很清楚**：paywall 裡兩張卡，一張寫「14 天免費試用 → 之後 NT$2,290/年」，另一張寫「立即訂閱享早鳥 X% off → NT$XXX/年」。用戶根據自己的 risk tolerance 選。

**早鳥 section 是否保留**：**保留，但重新定位**。
- 新定位：「**首批支持者方案 / Founder Pricing**」（不是「促銷」）
- 訊息調性：「we're new, you're early, trade trial for a deal」
- 視覺：放在 default 之後（not before），讓 default 是 primary path
- Section header 文案：「Founder Pricing — Skip the trial, lock in the launch price」（中文：「首批支持者方案 — 直接訂閱，鎖定上架價」）

### 2.3 Free tier 的 gating 策略：**軟提示 + 1 週體驗 + 硬牆**

**核心設計原則**：用戶不訂閱也要能用 app 一次以上，否則 cold-start 問題會爆炸。

**建議 gating layers**：

| Feature | Free tier | 訂閱（含 trial） |
|---|---|---|
| Onboarding + 個人資料 | ✅ | ✅ |
| 連結 HealthKit / Garmin / Strava | ✅ | ✅ |
| 看到 **Week 1** 的 AI 週課表（生成一次） | ✅ | ✅ |
| **重新生成課表 / 週調整** | ❌ paywall | ✅ |
| **Week 2+ 課表** | ❌ paywall | ✅ |
| 看訓練紀錄、配速、HR 基本分析 | ✅ | ✅ |
| **進階分析（負荷、recovery、trend）** | ❌ paywall | ✅ |
| **賽事預測（race prediction）** | ❌ paywall | ✅ |
| **Rizo 教練問答** | ⚠️ 5 則訊息上限 | ✅ 無限 |
| 賽事行事曆瀏覽 | ✅ | ✅ |
| 賽事行事曆建立目標賽事（觸發 plan generation） | ❌ paywall | ✅ |
| 訓練日記寫入 | ✅ | ✅ |
| 訓練日記 AI 摘要 | ❌ paywall | ✅ |

**設計理由**：
- **「Week 1 給看」** ← 學 Runna「Week 1 of any plan」，讓用戶感受 plan 的個人化品質再決定要不要付錢
- **「Rizo 5 則上限」** ← 軟性 limit 比硬牆好，用戶感受到 Rizo 能講話、然後在第 5 則時「想再多問」就觸發 paywall
- **「賽事預測整個鎖」** ← 這個功能成本高（需要 race data + LLM），且是強付費理由，硬牆合理

**用戶反饋#2「沒訂閱 = AI 功能不能用，這個要寫得很清楚」**的回應：
- Paywall 的 features list 必須**用 AI 詞彙明確標示**（見 §3.3 文案）
- 在被 gate 的 feature 上，使用 inline upsell card 說明「這是 Premium 功能」+「14 天免費試用」CTA，而不是直接 dump 用戶到 paywall sheet

### 2.4 Paywall 觸發點建議

| 觸發點 | 觸發類型 | 進入 paywall 的 source 識別 |
|---|---|---|
| App 第一次啟動完 onboarding | 不主動觸發（讓用戶先看 Week 1） | — |
| 用戶完成 Week 1，準備看 Week 2 | **主動 sheet pop** | `weekly_plan_week2` |
| 用戶嘗試 regenerate weekly plan | **主動 sheet pop** | `weekly_plan_regenerate` |
| 用戶建立第二個目標賽事（first 是免費 onboarding 帶入） | **主動 sheet pop** | `target_race_create` |
| 用戶點 race prediction tab | **主動 sheet pop** | `race_prediction_tab` |
| 用戶 Rizo 第 5 則訊息發出後 | **inline upsell card** | `rizo_message_limit` |
| 用戶從 Settings 主動點「升級」 | **主動 sheet pop** | `settings_upgrade` |
| 訂閱過期後再進 app | **主動 sheet pop**（resubscribe variant） | `resubscribe` |
| 切換方案 | **主動 sheet pop**（change variant） | `change_plan` |

**Source 識別的價值**：所有 paywall 觸發都帶 `source` parameter 進 analytics，dev 可以後續分析「哪個觸發點轉換最高」、「哪個觸發點被 dismissed 最多」。這個是 PM/Architect 後續需要決定的，但 Designer 這邊先標記 spec 的需求。

---

## 3. Sheet 結構與文案重寫

### 3.1 Sheet navigation title 統一

**現狀**：
- 升級流程：title = 「升級」
- 過期流程：title = 「Resubscribe」
- 切換方案流程：title = 「變更方案」

**改成**：**全部統一 = 「Paceriz Premium」**（zh-TW / en / ja 都用此 wording，「Paceriz」是品牌詞不翻譯，「Premium」三語通用）

**理由**：
- 品牌一致性：用戶在不同情境進來的都是同一張 sheet，title 應該是「目的地的名字」而不是「動作」
- Sheet 內容會根據 state 切換 hero copy（升級 / 重新訂閱 / 變更）— 這個 state-aware 切換在 hero copy 層處理，title 保持品牌定錨
- 跟 Apple's HIG 一致：Apple Music / Apple Fitness+ 的 sheet title 都是產品名

### 3.2 Sheet 結構提案

**現有 layout**：
```
[Hero: 圖示 + 標題 + 副標]
[Trial banner（如果在試用中）]
[Features list (3 條 with checkmark)]
[Early-bird section (orange cards) — only when isEarlyBird]
[Default section (Standard Plans)]
```

**新 layout**：

```
┌─────────────────────────────────────────────┐
│  Sheet Navigation                           │
│  [X]              Paceriz Premium       [Restore] │
├─────────────────────────────────────────────┤
│                                             │
│  ╭─ Hero ──────────────────────────────╮   │
│  │  [logo / icon]                      │   │
│  │  讓 AI 教練陪你練到下一場 PB           │   │
│  │  個人化課表、賽事預測、Rizo 隨時答疑    │   │
│  ╰────────────────────────────────────╯   │
│                                             │
│  ╭─ State Banner (conditional) ─────────╮  │
│  │  你正在試用中，剩 X 天                │  │
│  │  → 只在 trial state 顯示              │  │
│  ╰────────────────────────────────────╯   │
│                                             │
│  ╭─ Trial Timeline (default 卡關注時) ──╮  │
│  │  ●━━━━●━━━━●                         │  │
│  │  今天    第 12 天    第 14 天          │  │
│  │  立即解鎖  我們會提醒  訂閱開始         │  │
│  │  全部功能  即將扣款    可隨時取消       │  │
│  ╰────────────────────────────────────╯   │
│                                             │
│  ╭─ Features (4 groups) ────────────────╮ │
│  │  🎯 AI 個人化訓練                      │ │
│  │     ✓ 每週自動生成的智能課表            │ │
│  │     ✓ 根據體能狀態調整強度              │ │
│  │     ✓ 賽事週期化（從距離到 taper）       │ │
│  │                                      │ │
│  │  📊 進階分析                          │ │
│  │     ✓ 賽事完賽時間 AI 預測              │ │
│  │     ✓ 訓練負荷與恢復追蹤                │ │
│  │     ✓ 配速 / HR / Power 深度分析       │ │
│  │                                      │ │
│  │  💬 Rizo AI 教練                      │ │
│  │     ✓ 24/7 訓練問答無限制               │ │
│  │     ✓ 看你的數據給針對性建議             │ │
│  │                                      │ │
│  │  🔄 同步與整合                         │ │
│  │     ✓ Garmin / Strava / Apple Health │ │
│  │     ✓ 訓練日記 AI 摘要                  │ │
│  ╰────────────────────────────────────╯   │
│                                             │
│  ╭─ Pricing — Default ─────────────────╮   │
│  │  [年訂 RECOMMENDED 卡片]              │   │
│  │  NT$2,290/年（NT$190/月）              │   │
│  │  14 天免費試用 → 之後扣款              │   │
│  │  [月訂卡片] NT$XXX/月                 │   │
│  ╰────────────────────────────────────╯   │
│                                             │
│  ╭─ Founder Pricing (if eligible) ─────╮   │
│  │  首批支持者方案                        │   │
│  │  直接訂閱，鎖定上架前優惠價             │   │
│  │  [年訂卡片] NT$X,XXX/年（早鳥 XX% off） │   │
│  │  [月訂卡片] NT$XXX/月                 │   │
│  │  ⚠ 早鳥方案不含試用期                  │   │
│  ╰────────────────────────────────────╯   │
│                                             │
│  ╭─ Disclosure ────────────────────────╮   │
│  │  訂閱說明 + 條款連結                    │   │
│  ╰────────────────────────────────────╯   │
│                                             │
│  [恢復購買]  [使用條款]  [隱私權]            │
└─────────────────────────────────────────────┘
```

**結構決策說明**：

1. **Hero 換成 outcome-driven copy**：「讓 AI 教練陪你練到下一場 PB」是用戶可以視覺化的目標，比「升級以解鎖」具體。
2. **Trial Timeline 在 Features 之前**：學 Strava，把 trial 機制 narrative 化先講清楚，降低焦慮。**只在 default 卡片被 focus 或處於默認展開時顯示**——避免跟 Founder Pricing 的「不含試用」衝突。
3. **Features 分 4 組**：學 Runna 的分組策略，且每組第一個 bullet 都用 **AI / 智能 / 預測** 等詞彙明確標示這是 AI-powered。
4. **Pricing 兩個 section（Default → Founder）**：Default 在前，年訂 RECOMMENDED；Founder 在後，明確標示「不含試用期」。
5. **Disclosure 統一在底部**，用平實語氣寫扣款條款（不是 fine print）。

### 3.3 完整三語文案 draft

> 所有 i18n key 沿用現有 `paywall.*` prefix，新增條目用 `paywall.premium.*`。**不修改現有 key 的值**（避免 dev 改動 controller 邏輯），只新增。

#### 3.3.1 Sheet Navigation Title

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.nav_title` | Paceriz Premium | Paceriz Premium | Paceriz Premium |

#### 3.3.2 Hero（依 entry source 切換）

**Default entry（首次升級）**：

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.hero.default.title` | 讓 AI 教練陪你練到下一場 PB | Train smarter with your AI coach | AIコーチと次のPBへ |
| `paywall.premium.hero.default.subtitle` | 個人化課表、賽事預測、Rizo 隨時答疑 | Personalized plans, race time predictions, and Rizo on-demand | パーソナルプラン、レース予測、Rizoがいつでも対応 |

**Resubscribe entry（過期重訂）**：

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.hero.resubscribe.title` | 歡迎回來，繼續完成你的訓練 | Welcome back. Pick up where you left off. | おかえりなさい。トレーニングを続けましょう |
| `paywall.premium.hero.resubscribe.subtitle` | 重新訂閱以解鎖完整 AI 功能 | Resubscribe to unlock all AI features | 再登録してすべてのAI機能を利用 |

**Change plan entry（切換方案）**：

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.hero.change.title` | 變更你的訂閱方案 | Change your plan | プラン変更 |
| `paywall.premium.hero.change.subtitle` | 隨時切換月訂與年訂 | Switch between monthly and annual anytime | 月額・年額の切替はいつでも可能 |

#### 3.3.3 Trial Timeline（3 step）

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.timeline.step1.label` | 今天 | Today | 今日 |
| `paywall.premium.timeline.step1.desc` | 立即解鎖全部功能 | Unlock everything instantly | 全機能をすぐに利用 |
| `paywall.premium.timeline.step2.label` | 第 12 天 | Day 12 | 12日目 |
| `paywall.premium.timeline.step2.desc` | 我們會提前 2 天提醒你 | We'll remind you 2 days before billing | 課金2日前にお知らせ |
| `paywall.premium.timeline.step3.label` | 第 14 天 | Day 14 | 14日目 |
| `paywall.premium.timeline.step3.desc` | 訂閱開始，可隨時取消 | Subscription starts. Cancel anytime. | サブスク開始（いつでも解約可能） |

#### 3.3.4 Features（4 groups × 2-3 bullets）

**Group 1 — AI 個人化訓練 / AI Personalized Training / AIパーソナライズ**

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.features.plan.title` | AI 個人化訓練 | AI Personalized Training | AIパーソナライズ |
| `paywall.premium.features.plan.bullet1` | 每週自動生成的智能課表 | Smart weekly plans, generated for you | 毎週自動生成のスマートプラン |
| `paywall.premium.features.plan.bullet2` | 根據體能狀態自動調整強度 | Adapts intensity based on your readiness | 体力状態に応じて強度を自動調整 |
| `paywall.premium.features.plan.bullet3` | 賽事週期化（從距離訓練到 taper） | Race periodization, from base to taper | レース週期化（基礎期からテーパーまで） |

**Group 2 — 進階分析 / Advanced Analytics / 高度な分析**

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.features.analytics.title` | 進階分析 | Advanced Analytics | 高度な分析 |
| `paywall.premium.features.analytics.bullet1` | AI 賽事完賽時間預測 | AI race time predictions | AIによるレースタイム予測 |
| `paywall.premium.features.analytics.bullet2` | 訓練負荷與恢復追蹤 | Training load and recovery tracking | トレーニング負荷とリカバリーの追跡 |
| `paywall.premium.features.analytics.bullet3` | 配速 / 心率 / 功率深度分析 | Pace, HR, and power deep dives | ペース・心拍・パワーの詳細分析 |

**Group 3 — Rizo AI 教練 / Rizo AI Coach / Rizo AIコーチ**

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.features.rizo.title` | Rizo AI 教練 | Rizo AI Coach | Rizo AIコーチ |
| `paywall.premium.features.rizo.bullet1` | 24/7 訓練問答，無次數限制 | 24/7 training Q&A, unlimited messages | 24時間トレーニングQ&A、無制限 |
| `paywall.premium.features.rizo.bullet2` | 看你的數據給針對性建議 | Personalized advice based on your data | あなたのデータに基づくアドバイス |

**Group 4 — 同步與整合 / Sync & Integration / 連携機能**

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.features.sync.title` | 同步與整合 | Sync & Integration | 連携機能 |
| `paywall.premium.features.sync.bullet1` | Garmin / Strava / Apple Health 全整合 | Full Garmin / Strava / Apple Health sync | Garmin・Strava・Apple Health完全連携 |
| `paywall.premium.features.sync.bullet2` | 訓練日記 AI 摘要 | AI summary for your training log | トレーニング日記のAI要約 |

#### 3.3.5 Pricing section labels

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.section.default.title` | 標準方案 | Standard Plans | スタンダードプラン |
| `paywall.premium.section.default.subtitle` | 14 天免費試用，隨時取消 | 14-day free trial. Cancel anytime. | 14日間無料体験。いつでも解約可能 |
| `paywall.premium.section.founder.title` | 首批支持者方案 | Founder Pricing | ファウンダー価格 |
| `paywall.premium.section.founder.subtitle` | 直接訂閱，鎖定上架前優惠價 | Skip the trial, lock in launch pricing | トライアルなしで上場前価格を確定 |
| `paywall.premium.section.founder.notice` | 此方案不含免費試用期 | This plan does not include a free trial | 本プランは無料体験を含みません |

#### 3.3.6 Plan card labels（年訂 / 月訂）

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.plan.annual.label` | 年訂 | Annual | 年額 |
| `paywall.premium.plan.annual.badge_recommended` | 推薦 | RECOMMENDED | おすすめ |
| `paywall.premium.plan.annual.savings_format` | 年訂省 %@%% | Save %@%% with annual | 年額で%@%%お得 |
| `paywall.premium.plan.monthly.label` | 月訂 | Monthly | 月額 |
| `paywall.premium.plan.trial_format` | %@ 天免費試用後扣款 | %@ days free, then charged | %@日間無料、その後課金 |
| `paywall.premium.plan.no_trial_format` | 立即扣款，無試用期 | Charged immediately, no trial | 即時課金、トライアルなし |

#### 3.3.7 CTA Button

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.cta.start_trial` | 開始 14 天免費試用 | Start 14-day free trial | 14日間の無料体験を開始 |
| `paywall.premium.cta.subscribe_now` | 立即訂閱 | Subscribe now | 今すぐ登録 |
| `paywall.premium.cta.resubscribe` | 重新訂閱 | Resubscribe | 再登録 |
| `paywall.premium.cta.change_plan` | 變更為此方案 | Switch to this plan | このプランに変更 |

#### 3.3.8 Trial-state Banner（用戶已在試用中時 sheet 顯示）

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.premium.trial_banner.format` | 你正在試用中，還剩 %@ 天 | You're on trial — %@ days left | トライアル中 — 残り%@日 |
| `paywall.premium.trial_banner.subtitle` | 試用結束後將自動扣款，可隨時取消 | Auto-renews after trial. Cancel anytime. | トライアル後自動更新。いつでも解約可能 |

#### 3.3.9 Disclosure（trial 版 + 標準版）

**Trial 版（CTA 是 "Start trial"）**：

| Key | zh-TW |
|---|---|
| `paywall.premium.disclosure.trial` | 點擊「開始 14 天免費試用」即代表你同意：免費試用期為 14 天，到期後將以 NT$2,290/年（或所選方案價格）自動續訂並從你的 Apple ID 扣款。試用期結束 24 小時前可在 Apple ID 設定中取消，避免扣款。訂閱會在每個週期結束前 24 小時自動續訂，除非你取消。詳情請參閱 [使用條款] 與 [隱私權政策]。 |

**Trial 版 / EN**：
> By tapping "Start 14-day free trial" you agree: your free trial lasts 14 days, after which your selected plan will auto-renew at the listed price billed to your Apple ID. Cancel at least 24 hours before the trial ends in your Apple ID settings to avoid charges. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. See [Terms of Use] and [Privacy Policy].

**Trial 版 / JA**：
> 「14日間の無料体験を開始」をタップすることで、以下に同意したものとみなされます：無料体験期間は14日間です。期間終了後、選択したプランは自動的に更新され、Apple IDに記載の価格で課金されます。課金を回避するには、トライアル終了の24時間前までにApple IDの設定からキャンセルしてください。各更新期間終了の24時間前までに解約しない限り、サブスクリプションは自動更新されます。詳細は[利用規約]と[プライバシーポリシー]をご覧ください。

**標準版（早鳥訂閱、無 trial）**：

| Key | zh-TW |
|---|---|
| `paywall.premium.disclosure.standard` | 點擊「立即訂閱」即代表你同意：將立即從你的 Apple ID 扣款並訂閱所選方案。訂閱會在每個週期結束前 24 小時自動續訂，除非你在當前週期結束 24 小時前於 Apple ID 設定中取消。詳情請參閱 [使用條款] 與 [隱私權政策]。 |

**標準版 / EN**：
> By tapping "Subscribe now" you agree: your selected plan will be billed immediately to your Apple ID. Subscriptions auto-renew at the same price unless cancelled at least 24 hours before the end of the current period in your Apple ID settings. See [Terms of Use] and [Privacy Policy].

**標準版 / JA**：
> 「今すぐ登録」をタップすることで、以下に同意したものとみなされます：選択したプランはApple IDから即時に課金されます。各更新期間終了の24時間前までにApple IDの設定で解約しない限り、サブスクリプションは同じ価格で自動更新されます。詳細は[利用規約]と[プライバシーポリシー]をご覧ください。

---

## 4. Inline upsell card 設計（被 gate 的功能）

當用戶在 app 內遇到 gated feature（如點 race prediction tab），不要直接彈 paywall sheet，先顯示 inline upsell card。這降低中斷感、提高轉換率（用戶看到「就差這個」的 framing）。

**範例 — Race Prediction tab 被 gate 時**：

```
┌──────────────────────────────────────────┐
│  🔒  AI 賽事預測是 Premium 功能              │
│                                          │
│  根據你的訓練數據，預測 5K / 10K / 半馬 /     │
│  全馬的完賽時間，並隨訓練進度更新。          │
│                                          │
│  [開始 14 天免費試用 →]                    │
│                                          │
│  已訂閱？[恢復購買]                        │
└──────────────────────────────────────────┘
```

**Inline upsell i18n keys**：

| Key | zh-TW | en | ja |
|---|---|---|---|
| `paywall.inline.race_prediction.title` | AI 賽事預測是 Premium 功能 | Race Prediction is a Premium feature | レース予測はPremium機能 |
| `paywall.inline.race_prediction.body` | 根據你的訓練數據，預測 5K / 10K / 半馬 / 全馬的完賽時間，並隨訓練進度更新 | Predict your finish times for 5K / 10K / half / full marathon, updated as you train | トレーニングデータから5K/10K/ハーフ/フルの完走タイムを予測 |
| `paywall.inline.weekly_plan.title` | 解鎖完整週課表 | Unlock your full weekly plan | 週間プランを全て解放 |
| `paywall.inline.weekly_plan.body` | Week 1 是免費的。訂閱後可生成第 2 週起的個人化課表，並可隨時重新調整 | Week 1 is free. Subscribe to generate Week 2+ and re-adjust anytime | 第1週は無料。サブスク登録で第2週以降の生成と再調整が可能 |
| `paywall.inline.rizo_limit.title` | 你已用完免費對話額度 | You've used your free Rizo messages | Rizoの無料メッセージを使い切りました |
| `paywall.inline.rizo_limit.body` | Premium 訂閱享 Rizo 無限對話 | Premium subscribers get unlimited Rizo conversations | Premium会員はRizoが無制限 |
| `paywall.inline.cta.start_trial` | 開始 14 天免費試用 | Start 14-day free trial | 14日間の無料体験を開始 |
| `paywall.inline.cta.restore` | 已訂閱？恢復購買 | Already subscribed? Restore | 登録済み？復元する |

---

## 5. 開放討論（Designer 的判斷）

### 5.1 Gate 設計建議：軟 gating + 1 處硬 gating

採 §2.3 的混合策略：
- **Week 1 給看**（軟）：強投資感
- **Rizo 5 則限制**（軟 limit）：讓用戶感受 Rizo
- **Race Prediction / Advanced Analytics**（硬牆）：強付費理由

**不建議**完全硬 gate 所有 AI 功能（用戶連 Week 1 都看不到）— 這會讓 onboarding 完成率掉一半，cold-start 災難。

### 5.2 競品做得好但 Paceriz 還沒做的（建議列入後續 spec）

| 觀察自 | 機會 |
|---|---|
| Strava | 跟其他 app 的 bundle 訂閱（Paceriz + 跑鞋商 / 賽事報名平台） |
| Runna | Onboarding quiz 後直接 preview 用戶的「個人化計畫摘要」再開 paywall |
| Garmin | Annual recap / 年度回顧（Connect Rundown）— 對 Paceriz 來說可以做「年度跑量總結」當成 retention hook |
| Whoop | 「Start with X」的 verb framing — 已採用至 CTA |
| 全部 | 訂閱後**立即**展示「你已解鎖的功能」摘要頁，避免 dead zone |

### 5.3 Founder Pricing section 的視覺處理

不要用「橘色 cards」這種促銷 UI 風格。改用：
- 跟 default section 同款卡片骨架，但加一個小型 badge「FOUNDER」（深色 + 金色字）
- Section header 用 caption 字級寫副標
- **避免「限時優惠 / 倒數計時」這種 dark pattern**——iOS 用戶反感，Apple 評審也可能擋

---

## 6. 給 Dev 的 hand-off 摘要

| 項目 | 動作 | 責任 |
|---|---|---|
| Sheet navigation title 統一改 `Paceriz Premium` | 改 3 個 entry point 的 NavigationStack title | iOS Dev |
| Trial timeline 元件 | 新增 `PaywallTrialTimelineView`（3 step horizontal） | iOS Dev |
| Features 4 group 改寫 | 取代現有 3-bullet flat list，改 grouped 結構 | iOS Dev |
| Hero copy state-aware（default / resubscribe / change） | 根據 entry source 切換 hero | iOS Dev |
| Pricing section 標題改名（早鳥 → Founder Pricing） | 純文案 + i18n key 改名 | iOS Dev |
| Founder section 加「不含試用期」notice | 新增 caption row | iOS Dev |
| Inline upsell card（race prediction / weekly plan / rizo limit） | 3 個新元件 | iOS Dev |
| Trial banner（trial state 中顯示） | 新增 `PaywallTrialBanner` | iOS Dev |
| Disclosure 改 trial 版 + 標準版兩套 | 根據選中卡片切換 | iOS Dev |
| Apple Introductory Offer 設定 | 在 App Store Connect 把 default offering 設成 14 天 free trial | PM |
| Paywall source tracking | 所有 paywall entry 帶 `source` 進 analytics | iOS Dev |

**i18n 文件需新增 keys**：所有以 `paywall.premium.*` 和 `paywall.inline.*` 開頭的 key（zh-TW / en-US / ja-JP）。

**現有 keys 不刪、不改**，舊的 `paywall.upgrade.title`、`paywall.subscribe.title` 等如果之後沒地方引用，由 dev 在 `/simplify` 時清掉。

---

## 7. 變更日誌

| 日期 | 內容 |
|---|---|
| 2026-04-26 | Initial draft — 5 個競品研究、trial 策略、sheet 結構、三語文案 |
