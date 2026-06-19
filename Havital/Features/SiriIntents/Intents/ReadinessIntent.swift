import AppIntents

struct ReadinessIntent: AppIntent {
    static var title: LocalizedStringResource = "今天能不能練"
    static var description = IntentDescription("念出今天的訓練準備度")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRuntime.ensureBootstrapped()
        let repo: ReadinessRepository = DependencyContainer.shared.resolve()
        let r = try await repo.getTodayReadiness()
        return .result(dialog: IntentDialog(stringLiteral: ReadinessDialogBuilder.build(from: r)))
    }
}
