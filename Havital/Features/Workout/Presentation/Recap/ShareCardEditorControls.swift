import SwiftUI

struct ShareCardEditorControls: View {
    let canvasData: ShareCardCanvasData
    @Binding var editorState: ShareCardEditorState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                overlayPill(
                    kind: .title,
                    labelKey: "workout.share.add.title",
                    isVisible: editorState.titleLayout.isVisible
                )

                if canvasData.hasPaceSeries {
                    overlayPill(
                        kind: .paceChart,
                        labelKey: "workout.share.add.pace_chart",
                        isVisible: editorState.paceChartLayout.isVisible
                    )
                }

                if canvasData.hasRoute {
                    overlayPill(
                        kind: .routeGlyph,
                        labelKey: "workout.share.add.route",
                        isVisible: editorState.routeLayout.isVisible
                    )
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 8)
    }

    private func overlayPill(
        kind: ShareCardOverlayKind,
        labelKey: String,
        isVisible: Bool
    ) -> some View {
        Button {
            ShareCardEditorLogic.setVisible(!isVisible, kind: kind, state: &editorState)
        } label: {
            HStack(spacing: 6) {
                if isVisible {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(NSLocalizedString(labelKey, comment: ""))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isVisible ? .white : RecapPalette.brand)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule(style: .continuous)
                    .fill(isVisible ? RecapPalette.brand : Color.clear)
            }
            .overlay {
                if !isVisible {
                    Capsule(style: .continuous)
                        .strokeBorder(RecapPalette.brand.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
