import SwiftUI

// MARK: - App2RaceEditSheet
/// 新增／編輯賽事 —— 設計 **frame-13「新增賽事」**（編輯時只有標題與刪除鍵不同）。
///
/// 表單欄位與既有的 `AddSupportingTargetViewModel`／`EditTargetViewModel` 一一對應；
/// 「設為主要賽事」開關就是後端的 `is_main_race`，所以 2.0 不再有「主要賽事編輯」與
/// 「支援賽事編輯」兩條分開的畫面路徑。
struct App2RaceEditSheet: View {

    @State var form: App2RaceForm
    let isSaving: Bool
    let onSave: (App2RaceForm) -> Void
    let onDelete: (String) -> Void
    let onClose: () -> Void

    @State private var isShowingDatabase = false

    /// 設計 frame-13 的五顆類型 chip。前四顆是標準距離，「其他」＝距離自己填。
    private static let standardDistanceKeys = App2OnboardingFormat.raceDistanceKeys

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    databaseEntry
                    nameField
                    typeChips
                    distanceAndDate
                    targetTime
                    paceBlock
                    mainToggle
                    footerButtons
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.vertical, 14)
            }
            .background(App2Theme.pageGradient.ignoresSafeArea())
            .navigationTitle(form.targetId == nil
                             ? L10n.App2.Races.addTitle.localized
                             : L10n.App2.Races.editTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: ""), action: onClose)
                        .accessibilityIdentifier("App2_RaceFormCancel")
                }
            }
        }
        .accessibilityIdentifier("App2_RaceEditSheet")
        .fullScreenCover(isPresented: $isShowingDatabase) {
            App2RaceDatabaseView(
                onPick: { event, database in
                    form = App2RaceDatabaseViewModel.fill(form, with: event, distance: database)
                    isShowingDatabase = false
                },
                onClose: { isShowingDatabase = false }
            )
        }
    }

    // MARK: - 從賽事資料庫尋找（設計 frame-13 頂部的藍卡）

    private var databaseEntry: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(App2Theme.accentBlue)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.App2.Races.fromDatabase.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                Text(L10n.App2.Races.fromDatabaseSub.localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.accentBlueDeep.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.accentBlueDeep)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(App2Theme.accentCardGradient(strength: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(App2Theme.accentCardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { isShowingDatabase = true }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L10n.App2.Races.fromDatabase.localized)
        .accessibilityIdentifier("App2_RaceFormOpenDatabase")
        .padding(.bottom, 18)
    }

    // MARK: - 賽事名稱

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel(L10n.App2.Races.nameLabel.localized)
            TextField(L10n.App2.Races.namePlaceholder.localized, text: userEdited(\.name))
                .font(.system(size: 16, weight: .bold))
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .background(fieldSurface)
                .accessibilityIdentifier("App2_RaceFormName")
        }
        .padding(.bottom, 16)
    }

    // MARK: - 賽事類型

    private var typeChips: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel(L10n.App2.Races.typeLabel.localized)
            HStack(spacing: 8) {
                ForEach(Self.standardDistanceKeys, id: \.self) { key in
                    App2OnboardingChip(
                        title: App2OnboardingFormat.distanceLabel(km: Double(key) ?? 0),
                        isSelected: form.distanceKey == key,
                        fillsWidth: true,
                        cornerRadius: 999,
                        identifier: "App2_RaceFormDistance_\(key)"
                    ) {
                        form.distanceKey = key
                        form.clearRaceBinding()
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - 距離 ＋ 賽事日期

    private var distanceAndDate: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel(L10n.App2.Races.distanceLabel.localized)
                HStack(spacing: 4) {
                    TextField("0", text: userEdited(\.distanceKey))
                        .keyboardType(.decimalPad)
                        .font(.app2Mono(15, weight: .bold))
                        .accessibilityIdentifier("App2_RaceFormDistanceValue")
                    Text(verbatim: "km")
                        .font(.app2Mono(13, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
                .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
                .background(fieldSurface)
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel(L10n.App2.Races.dateLabel.localized)
                DatePicker("", selection: $form.date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    .background(fieldSurface)
                    .accessibilityIdentifier("App2_RaceFormDate")
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - 目標完賽時間

    private var targetTime: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(L10n.App2.Races.targetTimeLabel.localized)
            HStack(spacing: 10) {
                App2OnboardingTimeField(
                    unit: L10n.App2.Onboarding.raceHour.localized,
                    value: $form.hours,
                    range: 0...23,
                    identifier: "App2_RaceFormHours"
                )
                App2OnboardingTimeField(
                    unit: L10n.App2.Onboarding.raceMinute.localized,
                    value: $form.minutes,
                    range: 0...59,
                    identifier: "App2_RaceFormMinutes"
                )
                App2OnboardingTimeField(
                    unit: L10n.App2.Onboarding.raceSecond.localized,
                    value: $form.seconds,
                    range: 0...59,
                    identifier: "App2_RaceFormSeconds"
                )
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - 平均配速（填完才出現）

    @ViewBuilder
    private var paceBlock: some View {
        if let pace = form.paceLabel {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.App2.Races.paceLabel.localized)
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(App2Theme.inkMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(pace)
                            .font(.app2Mono(22))
                            .foregroundStyle(App2Theme.accentBlueDeep)
                        Text(verbatim: "/km")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(App2Theme.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 12, leading: 15, bottom: 12, trailing: 15))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(App2Theme.accentCardGradient(strength: 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(App2Theme.accentBlue.opacity(0.22), lineWidth: 1)
            )
            .padding(.bottom, 18)
            .accessibilityIdentifier("App2_RaceFormPace")
        } else {
            Text(L10n.App2.Races.paceHint.localized)
                .font(.system(size: 12, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(App2Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
                .padding(.bottom, 18)
        }
    }

    // MARK: - 設為主要賽事

    private var mainToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.App2.Races.makeMain.localized)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(L10n.App2.Races.makeMainSub.localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $form.makeMain)
                    .labelsHidden()
                    // 已經是主要賽事的那一筆不能在這裡取消 —— 取消之後就沒有主要賽事了，
                    // 而後端沒有「降級自己」的語意。要換就從另一場按「設為主要」。
                    .disabled(form.isCurrentMain)
                    .accessibilityIdentifier("App2_RaceFormMakeMain")
            }
            .padding(EdgeInsets(top: 13, leading: 15, bottom: 13, trailing: 15))
            .app2CardSurface(cornerRadius: 14)

            if form.isCurrentMain {
                noteText(L10n.App2.Races.mainLockNote.localized, color: App2Theme.inkMuted)
            } else if form.makeMain {
                noteText(L10n.App2.Races.makeMainNote.localized, color: App2Theme.accentBlueDeep)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - 刪除／儲存

    private var footerButtons: some View {
        HStack(spacing: 10) {
            if let id = form.targetId {
                Text(L10n.App2.Races.delete.localized)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(App2Theme.accentRed)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(App2Theme.accentRed.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(App2Theme.accentRed.opacity(0.25), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onDelete(id) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_RaceFormDelete")
            }

            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(L10n.App2.Races.save.localized)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(form.isValid ? App2Theme.accentBlue : App2Theme.accentBlue.opacity(0.35))
            )
            .contentShape(Rectangle())
            .onTapGesture { if form.isValid && !isSaving { onSave(form) } }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(L10n.App2.Races.save.localized)
            .accessibilityIdentifier("App2_RaceFormSave")
        }
    }

    // MARK: - 小元件

    /// 使用者**手動**改的欄位（名稱、距離）→ 斷開賽事庫綁定（同 1.x 的
    /// `BaseSupportingTargetViewModel.clearRaceSelection`）。
    ///
    /// 為什麼是自訂 Binding 而不是 `.onChange`：從賽事庫挑一場會整包換掉 `form`，
    /// 那不經過這個 setter，所以 `race_id` 保得住。用 `.onChange` 的話填完就會被
    /// 自己清掉，`race_id` 永遠送不出去。
    private func userEdited(_ keyPath: WritableKeyPath<App2RaceForm, String>) -> Binding<String> {
        Binding(
            get: { form[keyPath: keyPath] },
            set: { newValue in
                form[keyPath: keyPath] = newValue
                form.clearRaceBinding()
            }
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(App2Theme.inkMuted)
            .padding(.horizontal, 2)
    }

    private func noteText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .lineSpacing(3)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }

    private var fieldSurface: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(App2Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
            )
    }
}
