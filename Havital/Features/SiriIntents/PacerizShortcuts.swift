import AppIntents

struct PacerizShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodaysSessionIntent(),
            phrases: [
                "在 \(.applicationName) 今天要練什麼",
                "問 \(.applicationName) 今天的課表",
                "\(.applicationName) 今天練什麼"
            ],
            shortTitle: "今天要練什麼",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: ReadinessIntent(),
            phrases: [
                "在 \(.applicationName) 我今天能練嗎",
                "問 \(.applicationName) 我的訓練準備度"
            ],
            shortTitle: "今天能不能練",
            systemImageName: "heart.text.square"
        )
        AppShortcut(
            intent: NextRaceIntent(),
            phrases: [
                "在 \(.applicationName) 離比賽還有幾天",
                "問 \(.applicationName) 我的下一場比賽"
            ],
            shortTitle: "離比賽還有幾天",
            systemImageName: "flag.checkered"
        )
        AppShortcut(
            intent: WeeklyMileageIntent(),
            phrases: [
                "在 \(.applicationName) 我這週跑多少",
                "問 \(.applicationName) 我這週的跑量"
            ],
            shortTitle: "我這週跑多少",
            systemImageName: "chart.bar"
        )
    }
}
