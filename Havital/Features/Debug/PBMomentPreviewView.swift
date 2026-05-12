#if DEBUG
import SwiftUI

struct PBMomentPreviewView: View {
    private enum Scenario: String, CaseIterable, Identifiable {
        case newPB
        case multiplePB
        case firstRecord

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newPB: return "New PB"
            case .multiplePB: return "Multiple PBs"
            case .firstRecord: return "First Record"
            }
        }
    }

    @State private var scenario: Scenario = .newPB
    @State private var showMoment = false
    @State private var showShareCard = false

    private var update: PersonalBestUpdate {
        switch scenario {
        case .newPB:
            return PersonalBestUpdate(
                distance: "5",
                oldTime: 1328,
                newTime: 1289,
                improvementSeconds: 39,
                workoutDate: "2026-05-11",
                workoutId: "debug_pb_5k",
                detectedAt: Date(),
                isFirstRecord: false,
                relatedUpdateCount: 0
            )
        case .multiplePB:
            return PersonalBestUpdate(
                distance: "10",
                oldTime: 2894,
                newTime: 2796,
                improvementSeconds: 98,
                workoutDate: "2026-05-11",
                workoutId: "debug_pb_multi",
                detectedAt: Date(),
                isFirstRecord: false,
                relatedUpdateCount: 2
            )
        case .firstRecord:
            return PersonalBestUpdate(
                distance: "21",
                oldTime: nil,
                newTime: 6432,
                improvementSeconds: 0,
                workoutDate: "2026-05-11",
                workoutId: "debug_pb_first_half",
                detectedAt: Date(),
                isFirstRecord: true,
                relatedUpdateCount: 0
            )
        }
    }

    var body: some View {
        ZStack {
            List {
                Section {
                    Picker("Scenario", selection: $scenario) {
                        ForEach(Scenario.allCases) { scenario in
                            Text(scenario.title).tag(scenario)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("DEBUG only. Uses fake PB data so you can review the moment and share card without running a real personal best.")
                }

                Section("Actions") {
                    Button {
                        showMoment = true
                    } label: {
                        Label("Show PB Moment", systemImage: "trophy.fill")
                    }

                    Button {
                        showShareCard = true
                    } label: {
                        Label("Open Share Card", systemImage: "photo.on.rectangle.angled")
                    }
                }

                Section("Inline Share Card Preview") {
                    PBMomentShareCardPreview(update: update)
                        .accessibilityIdentifier("PBMomentPreview_InlineShareCard")
                }
            }
            .navigationTitle("PB Moment Preview")
            .sheet(isPresented: $showShareCard) {
                PBMomentShareCardSheetView(
                    update: update,
                    onShare: {},
                    onSave: {}
                )
            }

            if showMoment {
                PersonalBestCelebrationView(
                    update: update,
                    onDismiss: { showMoment = false },
                    onShare: {
                        showMoment = false
                        showShareCard = true
                    }
                )
                .accessibilityIdentifier("PBMomentPreview_Celebration")
                .transition(.opacity)
            }
        }
    }
}
#endif
