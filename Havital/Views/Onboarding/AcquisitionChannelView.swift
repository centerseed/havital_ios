// Havital/Views/Onboarding/AcquisitionChannelView.swift
//
// Onboarding 自報行銷渠道（T-0094）：「你從哪裡知道 Paceriz？」
// 單選 + 可跳過。送出走 PUT /user 的 acquisition_channel（後端 set-if-absent，首答為準）。
// 自報失敗不擋 onboarding —— 記 log 後照常前進。

import SwiftUI

/// 渠道字彙表：rawValue 必須與後端 `domains/user/acquisition_source.py` 的
/// VALID_CHANNELS 完全一致，不得自創字串。
enum AcquisitionChannelOption: String, CaseIterable {
    case threads
    case instagram
    case friend
    case appStoreSearch = "app_store_search"
    case ad
    case other

    var icon: String {
        switch self {
        case .threads: return "at.circle"
        case .instagram: return "camera"
        case .friend: return "person.2"
        case .appStoreSearch: return "magnifyingglass"
        case .ad: return "megaphone"
        case .other: return "ellipsis.circle"
        }
    }

    var title: String {
        switch self {
        case .threads: return "Threads"
        case .instagram: return "Instagram"
        case .friend: return NSLocalizedString("onboarding.channel_friend", comment: "朋友推薦")
        case .appStoreSearch: return NSLocalizedString("onboarding.channel_app_store_search", comment: "App Store 搜尋")
        case .ad: return NSLocalizedString("onboarding.channel_ad", comment: "廣告")
        case .other: return NSLocalizedString("onboarding.channel_other", comment: "其他")
        }
    }
}

struct AcquisitionChannelView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel

    @State private var selectedChannel: AcquisitionChannelOption?

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: L10n.Onboarding.continueStep.localized,
            ctaEnabled: selectedChannel != nil,
            isLoading: false,
            skipTitle: L10n.Onboarding.skipForNow.localized,
            ctaAccessibilityId: "OnboardingContinueButton",
            ctaAction: {
                handleContinue()
            },
            skipAction: {
                // 跳過 = 不送任何欄位
                coordinator.navigate(to: .dataSource)
            }
        ) {
            VStack(spacing: OnboardingLayout.sectionSpacing) {
                VStack(spacing: 16) {
                    Image(systemName: "hand.wave")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.accentColor)

                    Text(NSLocalizedString("onboarding.acquisition_channel_title", comment: "你從哪裡知道 Paceriz？"))
                        .font(AppFont.title2())
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("onboarding.acquisition_channel_subtitle", comment: "幫助我們把 Paceriz 帶給更多跑者"))
                        .font(AppFont.body())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    ForEach(AcquisitionChannelOption.allCases, id: \.rawValue) { option in
                        channelRow(option)
                    }
                }
            }
        }
        .accessibilityIdentifier("AcquisitionChannel_Screen")
        .navigationTitle(NSLocalizedString("onboarding.acquisition_channel_nav_title", comment: "認識 Paceriz"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func channelRow(_ option: AcquisitionChannelOption) -> some View {
        Button(action: {
            selectedChannel = option
        }) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(AppFont.title3())
                    .foregroundColor(selectedChannel == option ? .accentColor : .secondary)
                    .frame(width: 28)

                Text(option.title)
                    .font(AppFont.headline())
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: selectedChannel == option ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedChannel == option ? .accentColor : .secondary)
                    .font(AppFont.title3())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedChannel == option ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedChannel == option ? Color.accentColor : Color(.systemGray3),
                            lineWidth: selectedChannel == option ? 2 : 1)
            )
        }
        .accessibilityIdentifier("AcquisitionChannelOption_\(option.rawValue)")
        .buttonStyle(PlainButtonStyle())
    }

    private func handleContinue() {
        guard let channel = selectedChannel else { return }
        // 自報是 best-effort：背景送出、立即前進，失敗（VM 內已記 log）不擋主流程
        Task { [viewModel] in
            await viewModel.saveAcquisitionChannel(channel.rawValue)
        }
        coordinator.navigate(to: .dataSource)
    }
}

struct AcquisitionChannelView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AcquisitionChannelView()
                .environmentObject(DependencyContainer.shared.makeOnboardingFeatureViewModel())
        }
    }
}
