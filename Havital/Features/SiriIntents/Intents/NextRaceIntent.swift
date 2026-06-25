import AppIntents

struct NextRaceIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("voice.intent.next_race.title", defaultValue: "離比賽還有幾天")
    static var description = IntentDescription(LocalizedStringResource("voice.intent.next_race.desc", defaultValue: "念出距離下一場比賽的天數"))
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRuntime.ensureBootstrapped()
        let repo: TargetRepository = DependencyContainer.shared.resolve()
        let target = await repo.getMainTarget()
        return .result(dialog: IntentDialog(stringLiteral: NextRaceDialogBuilder.build(from: target, today: Date())))
    }
}
