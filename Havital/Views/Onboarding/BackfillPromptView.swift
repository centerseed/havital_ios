import SwiftUI

/// Onboarding Backfill 提示畫面
///
/// 詢問用戶是否要同步近 14 天的訓練資料
///
/// 功能：
/// - 顯示資料來源（Garmin/Strava）
/// - 解釋 backfill 的好處
/// - 提供「同意」和「跳過」兩個選項
struct BackfillPromptView: View {
    let dataSource: DataSourceType
    let targetDistance: Double

    var body: some View {
        NavigationView {
            BackfillPromptContentView(dataSource: dataSource, targetDistance: targetDistance)
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

/// Onboarding Backfill 提示畫面的內容視圖
struct BackfillPromptContentView: View {
    @StateObject private var viewModel: BackfillPromptViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    // MARK: - Initialization

    init(dataSource: DataSourceType, targetDistance: Double) {
        _viewModel = StateObject(wrappedValue: BackfillPromptViewModel(
            dataSource: dataSource,
            targetDistance: targetDistance
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 32) {
                    // 頂部圖示和標題
                    headerSection

                    // 說明區塊
                    descriptionSection

                    // 好處列表
                    benefitsSection

                    Spacer(minLength: 40)

                    // 底部按鈕
                    actionButtons
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 30)
            }

            Spacer()
        }
        .onChange(of: viewModel.isNavigatingToSync) { oldValue, newValue in
            if newValue {
                coordinator.navigate(to: .dataSync)
            }
        }
        .onChange(of: viewModel.isNavigatingToPersonalBest) { oldValue, newValue in
            if newValue {
                coordinator.navigate(to: .personalBest)
            }
        }
    }

    // MARK: - View Components

    /// 頂部圖示和標題區塊
    private var headerSection: some View {
        VStack(spacing: 20) {
            // 資料來源圖示
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: viewModel.dataSourceIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding.backfill_prompt.title", comment: "Sync recent training data?"))
                    .font(AppFont.title2())
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(String(format: NSLocalizedString("onboarding.backfill_prompt.subtitle", comment: "Get your last 14 days from %@"), viewModel.dataSourceDisplayName))
                    .font(AppFont.body())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 說明區塊
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.accentColor)
                    .font(AppFont.title3())

                Text(NSLocalizedString("onboarding.backfill_prompt.what_is_backfill", comment: "What is data sync?"))
                    .font(AppFont.headline())
            }

            Text(NSLocalizedString("onboarding.backfill_prompt.backfill_description", comment: "We'll sync your last 14 days of running records"))
                .font(AppFont.body())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    /// 好處列表區塊
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("onboarding.backfill_prompt.why_it_helps", comment: "Why it helps?"))
                .font(AppFont.headline())

            VStack(alignment: .leading, spacing: 14) {
                benefitItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: NSLocalizedString("onboarding.backfill_prompt.benefit1_title", comment: "Better training suggestions"),
                    description: NSLocalizedString("onboarding.backfill_prompt.benefit1_description", comment: "Personalized plan based on your history")
                )

                benefitItem(
                    icon: "target",
                    title: NSLocalizedString("onboarding.backfill_prompt.benefit2_title", comment: "Complete progress tracking"),
                    description: NSLocalizedString("onboarding.backfill_prompt.benefit2_description", comment: "View your full training journey")
                )

                benefitItem(
                    icon: "figure.run",
                    title: NSLocalizedString("onboarding.backfill_prompt.benefit3_title", comment: "Accurate fitness assessment"),
                    description: NSLocalizedString("onboarding.backfill_prompt.benefit3_description", comment: "Analyze your running status")
                )
            }
        }
    }

    /// 單個好處項目
    private func benefitItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(AppFont.title3())
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)

                Text(description)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 底部按鈕區塊
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 主要按鈕：同意同步
            Button(action: {
                viewModel.confirmBackfill()
            }) {
                Text(NSLocalizedString("onboarding.backfill_prompt.confirm_button", comment: "Yes, Get My Data"))
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }

            // 次要按鈕：跳過
            Button(action: {
                viewModel.skipBackfill()
            }) {
                Text(NSLocalizedString("onboarding.backfill_prompt.skip_button", comment: "Skip for Now"))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Preview

struct BackfillPromptView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Garmin 預覽
            BackfillPromptView(dataSource: .garmin, targetDistance: 21.0975)
                .previewDisplayName("Garmin")

            // Strava 預覽
            BackfillPromptView(dataSource: .strava, targetDistance: 42.195)
                .previewDisplayName("Strava")

            // 深色模式
            BackfillPromptView(dataSource: .garmin, targetDistance: 5.0)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
