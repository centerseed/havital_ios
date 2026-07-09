import CoreGraphics

enum ShareCardEditorLogic {
    static func setVisible(
        _ visible: Bool,
        kind: ShareCardOverlayKind,
        state: inout ShareCardEditorState
    ) {
        var layout = layout(kind: kind, in: state)
        layout.isVisible = visible
        if visible {
            let defaultPos = ShareCardLayoutMath.defaultPosition(for: kind)
            layout.centerX = defaultPos.x
            layout.centerY = defaultPos.y
        }
        assignLayout(layout, kind: kind, state: &state)
    }

    static func dragOverlay(
        kind: ShareCardOverlayKind,
        translation: CGSize,
        cardSize: CGSize,
        state: inout ShareCardEditorState
    ) {
        guard cardSize.width > 0, cardSize.height > 0 else { return }

        var layout = layout(kind: kind, in: state)
        layout.centerX = ShareCardLayoutMath.clampNormalized(
            layout.centerX + translation.width / cardSize.width
        )
        layout.centerY = ShareCardLayoutMath.clampNormalized(
            layout.centerY + translation.height / cardSize.height
        )
        assignLayout(layout, kind: kind, state: &state)
    }

    static func setRouteColor(_ color: ShareCardRouteColor, state: inout ShareCardEditorState) {
        state.routeColor = color
    }

    static func adjustRouteScale(delta: CGFloat, state: inout ShareCardEditorState) {
        state.routeScale = ShareCardLayoutMath.clampRouteScale(state.routeScale + delta)
    }

    static func layout(kind: ShareCardOverlayKind, in state: ShareCardEditorState) -> ShareCardElementLayout {
        switch kind {
        case .title: return state.titleLayout
        case .paceChart: return state.paceChartLayout
        case .routeGlyph: return state.routeLayout
        }
    }

    private static func assignLayout(
        _ layout: ShareCardElementLayout,
        kind: ShareCardOverlayKind,
        state: inout ShareCardEditorState
    ) {
        switch kind {
        case .title: state.titleLayout = layout
        case .paceChart: state.paceChartLayout = layout
        case .routeGlyph: state.routeLayout = layout
        }
    }
}
