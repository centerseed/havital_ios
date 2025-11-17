import SwiftUI

/// 心率设置提醒对话框
/// 用于在用户进入主画面时，提醒尚未设置心率数据的用户进行设置
struct HeartRateSetupAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userPreferenceManager = UserPreferenceManager.shared

    /// 当用户点击「立即设定」时的回调
    var onSetupNow: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 图标
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                    .padding(.top, 32)

                // 标题和描述
                VStack(spacing: 12) {
                    Text(NSLocalizedString("heart_rate.setup_prompt_title", comment: "Set Up Heart Rate"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("heart_rate.setup_prompt_message", comment: "Setting your max and resting heart rate helps us provide more accurate training recommendations and heart rate zone analysis."))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // 按钮组
                VStack(spacing: 12) {
                    // 去设置按钮
                    Button(action: {
                        dismiss()
                        // 延遲一小段時間讓 sheet dismiss 動畫完成，然後觸發滿版心率設置
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSetupNow()
                        }
                    }) {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                            Text(NSLocalizedString("heart_rate.go_to_setup", comment: "Set Up Now"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // 明天再提醒按钮
                    Button(action: {
                        remindMeTomorrow()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text(NSLocalizedString("heart_rate.remind_tomorrow", comment: "Remind Me Tomorrow"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    }

                    // 永不提醒按钮
                    Button(action: {
                        neverRemind()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text(NSLocalizedString("heart_rate.never_remind", comment: "Don't Remind Me"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Private Methods

    /// 明天再提醒我
    private func remindMeTomorrow() {
        // 记录当前时间戳，24小时后再提醒
        let tomorrow = Date().addingTimeInterval(24 * 60 * 60)
        userPreferenceManager.heartRatePromptNextRemindDate = tomorrow
        Logger.debug("Heart rate prompt: User chose 'Remind Me Tomorrow', next remind date: \(tomorrow)")
    }

    /// 永不提醒
    private func neverRemind() {
        userPreferenceManager.doNotShowHeartRatePrompt = true
        Logger.debug("Heart rate prompt: User chose 'Never Remind'")
    }
}

#Preview {
    HeartRateSetupAlertView {
        print("設定心率")
    }
}
