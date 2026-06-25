import AppIntents

struct PacerizShortcuts: AppShortcutsProvider {
    // T-0048 i18n: shortTitle 已用 LocalizedStringResource 顯式 key 在地化。
    // phrases 含 \(.applicationName) token,需 App Intents String Catalog(Localizable.xcstrings)
    // + Xcode 萃取 + 裝置 Siri 測試才能可靠在地化;暫保留 zh-TW（en/ja Siri rollout 前補）。
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodaysSessionIntent(),
            phrases: [
                "在 \(.applicationName) 今天要練什麼",
                "問 \(.applicationName) 今天的課表",
                "\(.applicationName) 今天練什麼"
            ],
            shortTitle: LocalizedStringResource("voice.intent.todays_session.title", defaultValue: "今天要練什麼"),
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: ReadinessIntent(),
            phrases: [
                "在 \(.applicationName) 我今天能練嗎",
                "問 \(.applicationName) 我的訓練準備度"
            ],
            shortTitle: LocalizedStringResource("voice.intent.readiness.title", defaultValue: "今天能不能練"),
            systemImageName: "heart.text.square"
        )
        AppShortcut(
            intent: NextRaceIntent(),
            phrases: [
                "在 \(.applicationName) 離比賽還有幾天",
                "問 \(.applicationName) 我的下一場比賽"
            ],
            shortTitle: LocalizedStringResource("voice.intent.next_race.title", defaultValue: "離比賽還有幾天"),
            systemImageName: "flag.checkered"
        )
        AppShortcut(
            intent: WeeklyMileageIntent(),
            phrases: [
                "在 \(.applicationName) 我這週跑多少",
                "問 \(.applicationName) 我這週的跑量"
            ],
            shortTitle: LocalizedStringResource("voice.intent.weekly_mileage.title", defaultValue: "我這週跑多少"),
            systemImageName: "chart.bar"
        )
    }
}
