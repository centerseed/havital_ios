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

    /// 整期總結要不要走故事版 fixture。**production 恆為 false** —— 敘事端點未落地，
    /// `App2PlanEndStoryFixture` 是唯一的 producer，而它整段在 `#if DEBUG` 裡。
    ///
    /// 存的是**開關**而不是組好的 `App2PeriodStory`：fixture 的週數要跟真實
    /// `total_weeks` 走（2026-08-27 補修），而那個值只有消費端
    /// （`App2PeriodSummaryViewModel.weeks`）知道 —— 在開關這裡就把故事組好，
    /// hero 句的 N 只能寫死，於是同屏的章節標籤與它對不上。
    @Published var planEndStoryPreview = false
}

// MARK: - App2WeeklyReviewDevView
/// 週回顧開發者工具（2.0 設定頁 →「週回顧開發工具」，**只在 DEBUG build 出現**）。
///
/// 為什麼不加進 1.4 的 `UserProfileView.developerSection`：那一段是 1.4 設定頁的
/// 開發者區，2.0 走的是 `App2SettingsView`，兩頁在 2.0 期間並存但入口不同。
/// 落點沿用 repo 既有的 `Features/<Feature>/Debug/` 慣例
/// （`Features/Subscription/Debug/IAPTestHarness.swift`），不另建第二種開發面板機制。
///
/// 三件事：
/// 1. **CTA 狀態走查** —— 強制首頁時機卡顯示 §A.5 的任一格。
/// 2. **直接開週回顧頁** —— 指定 `week_of_plan` 與 `isCurrentWeek`（見 `openReviewSection`）。
/// 3. **指定週次直接呼叫端點** —— `POST /v2/summary/weekly` 等。
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
    /// 走查用：直接開週回顧頁（見 `openReviewSection`）。
    @State private var reviewTarget: App2WeeklyReviewTarget?

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
                openReviewSection
                generateSection
                if !log.isEmpty { logSection }
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .fullScreenCover(item: $reviewTarget) { target in
            App2WeeklyReviewView(
                weekOfPlan: target.weekOfPlan,
                isCurrentWeek: target.isCurrentWeek,
                onClose: { reviewTarget = nil }
            )
        }
    }

    // MARK: - 直接開週回顧頁（走查週日流程用）
    //
    // 週日流程（`isCurrentWeek == true`）的**產生鈕**在平日的真實資料上是碰不到的：
    // 首頁的 `generateCurrentWeek` override 開出來的是 `weekOfPlan == current_week`，
    // 而後端平日只准產 `current_week − 1`（`plan_generation_window.py:37`），所以那一頁
    // 落在「產生視窗未開」的空態，鈕根本不畫（T-0362）。於是 T-0409 的確認框——只在
    // `isCurrentWeek == true` 才跳的那一個——一年只有星期天走查得到。
    //
    // 這兩顆鈕**不繞過任何判準**：視窗判斷、確認框判斷、產生請求都還是各自那條真路徑。
    // 它們做的只有一件事——把頁面用「今天視窗開著的那一週」開起來（週次現查
    // `/v2/plan/status`，不靠走查者去猜、也不靠 stepper 撥對），`isCurrentWeek` 則由
    // 按的是哪一顆決定。於是產生鈕在、確認框的兩種形狀都走得到。
    //
    // **按確認會真的產生一份回顧**（那是真路徑）。只要驗確認框本身，按取消就好。

    private var openReviewSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: "Open weekly review page")
                .padding(.top, 20)
            App2Card(padding: 15, spacing: 12) {
                devButton(
                    "Open review — Sunday shape (isCurrentWeek = true)",
                    id: "App2_DevOpenReviewSunday"
                ) {
                    await openAllowedWeekReview(isCurrentWeek: true)
                }
                devButton(
                    "Open review — weekday shape (isCurrentWeek = false)",
                    id: "App2_DevOpenReviewWeekday"
                ) {
                    await openAllowedWeekReview(isCurrentWeek: false)
                }
                Text("Opens the week today's generation window actually allows (read live from "
                     + "/v2/plan/status). Nothing is bypassed — confirming the dialog really "
                     + "generates a review.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 開「今天產得出來的那一週」的回顧頁。週次現查後端，不從畫面上的 stepper 拿——
    /// 走查者撥錯一格就會落回「視窗未開」的空態，然後把那當成缺陷。
    private func openAllowedWeekReview(isCurrentWeek: Bool) async {
        isBusy = true
        do {
            let status = try await repository.getPlanStatus()
            let isSunday = App2HomeViewModel.isSundayInUserTimezone(status)
            let allowed = isSunday ? status.currentWeek : status.currentWeek - 1
            guard allowed >= 1 else {
                log = "open review\n❌ 今天沒有可產生的週次（current_week=\(status.currentWeek)）"
                isBusy = false
                return
            }
            log = "open review\n✅ week_of_plan=\(allowed) isCurrentWeek=\(isCurrentWeek) "
                + "(current_week=\(status.currentWeek), sunday=\(isSunday))"
            reviewTarget = App2WeeklyReviewTarget(
                weekOfPlan: allowed, isCurrentWeek: isCurrentWeek
            )
        } catch {
            log = "open review\n❌ \(error.toDomainError().localizedDescription)"
        }
        isBusy = false
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
                // 把那一週的回顧刪掉，好把頁面推回「還沒產生」的空態——走查產生鈕
                // （以及 T-0409 的確認框）需要那個態，而它在真實資料上通常已經被填掉了。
                // 讀取用 `fetchWeeklySummary`：`getWeeklySummary` 404 時會 fallback 成 POST，
                // 那會在「要刪掉它」的路徑上先生成一份出來。
                devButton("DELETE /v2/summary/weekly", id: "App2_DevDelete") {
                    await run("DELETE /v2/summary/weekly week_of_plan=\(week)") {
                        guard let summary = try await repository.fetchWeeklySummary(
                            weekOfPlan: week
                        ) else {
                            return "nothing to delete (week \(week) has no summary)"
                        }
                        try await repository.deleteWeeklySummary(summaryId: summary.id)
                        // 本機還留著一份（`getWeeklySummary` 先讀 cache），不清掉的話
                        // 下一次開那一頁還是會看到剛剛刪掉的那份回顧。
                        await repository.clearWeeklySummaryCache(weekOfPlan: week)
                        return "deleted id=\(summary.id) week=\(summary.weekOfTraining) (+cache cleared)"
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
