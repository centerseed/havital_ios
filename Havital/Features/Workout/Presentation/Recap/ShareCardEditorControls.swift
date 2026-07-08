import SwiftUI

struct ShareCardEditorControls: View {
    let canvasData: ShareCardCanvasData
    @Binding var editorState: ShareCardEditorState

    var body: some View {
        VStack(spacing: 10) {
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

            if canvasData.hasRoute, editorState.routeLayout.isVisible {
                routeCustomizationRow
                    .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 8)
    }

    private var routeCustomizationRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(ShareCardRouteColor.allCases, id: \.self) { color in
                    Button {
                        ShareCardEditorLogic.setRouteColor(color, state: &editorState)
                    } label: {
                        Circle()
                            .fill(color.strokeColor)
                            .frame(width: 24, height: 24)
                            .overlay {
                                if editorState.routeColor == color {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(routeColorAccessibilityLabel(for: color))
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                routeScaleButton(
                    systemName: "minus.circle.fill",
                    labelKey: "workout.share.route.smaller",
                    enabled: editorState.routeScale > ShareCardLayoutMath.minRouteScale + 0.001
                ) {
                    ShareCardEditorLogic.adjustRouteScale(
                        delta: -ShareCardLayoutMath.routeScaleStep,
                        state: &editorState
                    )
                }

                routeScaleButton(
                    systemName: "plus.circle.fill",
                    labelKey: "workout.share.route.larger",
                    enabled: editorState.routeScale < ShareCardLayoutMath.maxRouteScale - 0.001
                ) {
                    ShareCardEditorLogic.adjustRouteScale(
                        delta: ShareCardLayoutMath.routeScaleStep,
                        state: &editorState
                    )
                }
            }
        }
    }

    private func routeScaleButton(
        systemName: String,
        labelKey: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(enabled ? RecapPalette.brand : Color.secondary.opacity(0.35))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(NSLocalizedString(labelKey, comment: ""))
    }

    private func routeColorAccessibilityLabel(for color: ShareCardRouteColor) -> String {
        let key: String
        switch color {
        case .brand: key = "workout.share.route.color.brand"
        case .white: key = "workout.share.route.color.white"
        case .green: key = "workout.share.route.color.green"
        case .gold: key = "workout.share.route.color.gold"
        case .peach: key = "workout.share.route.color.peach"
        }
        return NSLocalizedString(key, comment: "")
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
