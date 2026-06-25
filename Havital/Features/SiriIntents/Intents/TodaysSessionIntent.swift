import AppIntents

struct TodaysSessionIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("voice.intent.todays_session.title", defaultValue: "今天要練什麼")
    static var description = IntentDescription(LocalizedStringResource("voice.intent.todays_session.desc", defaultValue: "念出今天的訓練內容"))
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRuntime.ensureBootstrapped()
        let repo: DailyStateRepository = DependencyContainer.shared.resolve()
        let card = try await repo.fetchTodayState()
        return .result(dialog: IntentDialog(stringLiteral: TodaysSessionDialogBuilder.build(from: card)))
    }
}
