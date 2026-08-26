#if DEBUG
import SwiftUI

// MARK: - App2DevWeekReviewOverride
/// 首頁週回顧時機卡的**開發用強制狀態**。
///
/// `DESIGN-app2-weekly-review-and-plan-end-inventory` §A.5 的四個顯示狀態各自只在
/// 特定的日子 ＋ 資料組合下出現（平日 vs **使用者時區**的週日、上週回顧生成與否），
/// 而後端不接受用戶端指定「今天是週幾」—— 所以在真實資料上走查這四格是等不到的。
/// 這個 override 只換**首頁那張卡呈現的那一格**，`weekReviewState` 的判斷本身不動。
enum App2DevWeekReviewOverride: String, CaseIterable, Identifiable {
    /// 不覆寫，照真實 plan status。
    case off
    /// 整卡隱藏（§A.5 第 1 列與計畫結束態）。
    case hidden
    /// 平日：「產生上週回顧」。
    case generatePreviousWeek
    /// 週日：「產生本週回顧」。
    case generateCurrentWeek
    /// 已生成：「查看回顧」。
    case viewReview

    var id: String { rawValue }

    /// 走查用的標籤。**刻意不進 `Localizable.strings`** —— DEBUG-only 開發工具不是
    /// 面向用戶的字串，翻三語只會讓 i18n 檔多出沒有人會看到的 key。
    var label: String {
        switch self {
        case .off:                  return "Off (real status)"
        case .hidden:               return "Hidden"
        case .generatePreviousWeek: return "Generate previous week (weekday)"
        case .generateCurrentWeek:  return "Generate current week (Sunday)"
        case .viewReview:           return "View review"
        }
    }

    /// 把 override 換成實際狀態。
    ///
    /// 回傳的是**雙層 optional**：外層 nil ＝「沒有覆寫，用真實值」，
    /// 內層 nil ＝「覆寫成整卡隱藏」。兩者是不同的意思，壓成一層就分不出來。
    ///
    /// 目標週仍然從 plan status 取 —— 週次不是走查的對象，點下去要能真的開到那一週。
    func resolve(planStatus: PlanStatusV2Response) -> App2WeekReviewState?? {
        switch self {
        case .off:
            return nil
        case .hidden:
            return .some(nil)
        case .generatePreviousWeek:
            return .some(.notGenerated(
                isCurrentWeek: false, targetWeek: max(planStatus.currentWeek - 1, 1)
            ))
        case .generateCurrentWeek:
            return .some(.notGenerated(isCurrentWeek: true, targetWeek: planStatus.currentWeek))
        case .viewReview:
            return .some(.available(
                summaryId: planStatus.previousWeekSummaryId ?? "dev-forced",
                isCurrentWeek: false,
                targetWeek: max(planStatus.currentWeek - 1, 1)
            ))
        }
    }
}

// MARK: - App2DevSettings
/// 2.0 的 DEBUG-only 開發旗標。
///
/// **不落地**（不寫 UserDefaults）——重啟就回到真實狀態，免得走查完忘記關掉、
/// 下一次拿假狀態當現況判讀。
@MainActor
final class App2DevSettings: ObservableObject {
    static let shared = App2DevSettings()
    private init() {}

    @Published var weekReviewOverride: App2DevWeekReviewOverride = .off

    /// 計畫結束態走查（`Features/App2/Debug/App2PlanEndDevView.swift`）。
    ///
    /// 與 `weekReviewOverride` 同一個物件而不是第二個 dev flag store —— 兩個走查
    /// 開關互斥（結束態一開，週回顧時機卡就該收掉），放在一起才看得出這件事。
    @Published var planEndOverride: App2DevPlanEndOverride = .off

    /// 整期總結故事版的 fixture。**production 恆為 nil** —— 敘事端點未落地，
    /// 這裡是唯一的 producer，而它整段在 `#if DEBUG` 裡。
    @Published var planEndStory: App2PeriodStory?
}

// MARK: - App2WeeklyReviewDevView
/// 週回顧開發者工具（2.0 設定頁 →「週回顧開發工具」，**只在 DEBUG build 出現**）。
///
/// 為什麼不加進 1.4 的 `UserProfileView.developerSection`：那一段是 1.4 設定頁的
/// 開發者區，2.0 走的是 `App2SettingsView`，兩頁在 2.0 期間並存但入口不同。
/// 落點沿用 repo 既有的 `Features/<Feature>/Debug/` 慣例
/// （`Features/Subscription/Debug/IAPTestHarness.swift`），不另建第二種開發面板機制。
///
/// 兩件事：
/// 1. **CTA 狀態走查** —— 強制首頁時機卡顯示 §A.5 的任一格。
/// 2. **指定週次直接呼叫端點** —— `POST /v2/summary/weekly` 等。
///
/// 第 2 項的實查結果（2026-08-26，dev 後端，創辦人 dev 帳號）：
/// **平日生成是 server 端擋的，client 繞不過**。
/// `core/training_rules/plan_generation_window.py:37-55` 的 `allowed_week_for_kind`
/// 在使用者時區的週一～六只允許 `current_week - 1`（`current_week <= 1` 時是 0，
/// 也就是無週可產），週日才允許 `current_week`。擋下來時回 400
/// `weekly_summary_generation_window_denied`，body 帶 `allowed_week` 與 `weekday`。
/// 所以這顆鈕的用途是把後端的裁決原樣攤出來看，不是繞過視窗。
struct App2WeeklyReviewDevView: View {

    let onClose: () -> Void

    @ObservedObject private var dev = App2DevSettings.shared
    @State private var week: Int = 1
    @State private var log: String = ""
    @State private var isBusy = false

    private let repository: TrainingPlanV2Repository

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let container = DependencyContainer.shared
        if !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        self.repository = container.resolve()
    }

    var body: some View {
        App2SettingsPageScaffold(
            title: "Weekly Review Dev Tools",
            onBack: onClose,
            backIdentifier: "App2_WeeklyReviewDevBack",
            titleIdentifier: "App2_WeeklyReviewDevView"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ctaSection
                generateSection
                if !log.isEmpty { logSection }
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
    }

    // MARK: - CTA 狀態走查

    private var ctaSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: "Home CTA forced state")
            App2Card(padding: 15, spacing: 12) {
                ForEach(App2DevWeekReviewOverride.allCases) { option in
                    HStack(spacing: 10) {
                        Image(systemName: dev.weekReviewOverride == option
                              ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(dev.weekReviewOverride == option
                                             ? App2Theme.accentBlue : App2Theme.chevron)
                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(App2Theme.inkSecondary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { dev.weekReviewOverride = option }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_DevWeekReviewOverride_\(option.rawValue)")
                }
                Text("Override only changes what the home card renders; tapping it still opens real data. Applies immediately. Cleared on relaunch.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 指定週次呼叫端點

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: "Call endpoints directly")
                .padding(.top, 20)
            App2Card(padding: 15, spacing: 12) {
                HStack(spacing: 10) {
                    Text("week_of_plan")
                        .font(.app2Mono(13))
                        .foregroundStyle(App2Theme.inkSecondary)
                    Text("\(week)")
                        .font(.app2Mono(18))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 0)
                    Stepper("", value: $week, in: 0...52)
                        .labelsHidden()
                        .accessibilityIdentifier("App2_DevWeekStepper")
                }
                devButton("POST /v2/summary/weekly", id: "App2_DevGenerate") {
                    await run("POST /v2/summary/weekly week_of_plan=\(week)") {
                        let summary = try await repository.generateWeeklySummary(
                            weekOfPlan: week, forceUpdate: nil
                        )
                        return "generated id=\(summary.id) week=\(summary.weekOfTraining)"
                    }
                }
                devButton("GET /v2/summary/weekly", id: "App2_DevFetch") {
                    await run("GET /v2/summary/weekly?week_of_plan=\(week)") {
                        let summary = try await repository.getWeeklySummary(weekOfPlan: week)
                        return "exists id=\(summary.id) suggestions="
                            + "\(summary.nextWeekAdjustments.items.count)"
                    }
                }
                devButton("GET /v2/plan/status", id: "App2_DevStatus") {
                    await run("GET /v2/plan/status") {
                        let status = try await repository.getPlanStatus()
                        return """
                        current_week=\(status.currentWeek)/\(status.totalWeeks)
                        next_action=\(status.nextAction)
                        can_generate_next_week=\(status.canGenerateNextWeek)
                        previous_week_summary_id=\(status.previousWeekSummaryId ?? "null")
                        requires_current_week_summary=\
                        \(status.nextWeekInfo?.requiresCurrentWeekSummary.map(String.init) ?? "null")
                        user_timezone=\(status.metadata?.userTimezone ?? "null")
                        server_time=\(status.metadata?.serverTime ?? "null")
                        → 使用者時區是週日？ \
                        \(App2HomeViewModel.isSundayInUserTimezone(status))
                        """
                    }
                }
                Text("Weekday generation is denied server-side (400 weekly_summary_generation_window_denied, "
                     + "body carries allowed_week / weekday). This screen only surfaces that verdict verbatim.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: "Output")
                .padding(.top, 20)
            App2Card(padding: 15, spacing: 6) {
                Text(log)
                    .font(.app2Mono(12))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("App2_DevLog")
            }
        }
    }

    // MARK: - Helpers

    private func devButton(_ title: String, id: String, action: @escaping () async -> Void) -> some View {
        HStack(spacing: 8) {
            if isBusy { ProgressView().tint(.white) }
            Text(title)
                .font(.app2Mono(13))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.accentBlue.opacity(isBusy ? 0.5 : 1))
        )
        .contentShape(Rectangle())
        .onTapGesture { if !isBusy { Task { await action() } } }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(id)
    }

    /// 成功與失敗都印。**失敗的 body 正是這一頁要看的東西**（`allowed_week`／`weekday`），
    /// 所以這裡刻意不套用產品路徑那條「不把 server body 印到畫面上」的規則 ——
    /// 它是 DEBUG-only 工具，讀者是我們自己，而且 Release build 不存在。
    private func run(_ label: String, _ work: @escaping () async throws -> String) async {
        isBusy = true
        do {
            log = "\(label)\n✅ \(try await work())"
        } catch {
            log = "\(label)\n❌ \(error.toDomainError().localizedDescription)"
        }
        isBusy = false
    }
}
#endif
