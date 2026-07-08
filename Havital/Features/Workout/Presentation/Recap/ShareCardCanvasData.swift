import CoreGraphics

struct ShareCardPaceSample: Equatable {
    let offsetSeconds: Int
    let paceSecondsPerKm: Double
}

struct ShareCardRoutePoint: Equatable {
    let latitude: Double
    let longitude: Double
}

struct ShareCardCanvasData: Equatable {
    let paceSamples: [ShareCardPaceSample]
    let routePoints: [ShareCardRoutePoint]

    var hasPaceSeries: Bool { paceSamples.count >= 2 }
    var hasRoute: Bool { routePoints.count >= 2 }

    static let empty = ShareCardCanvasData(paceSamples: [], routePoints: [])
}

enum ShareCardOverlayKind {
    case title, paceChart, routeGlyph
}

struct ShareCardElementLayout: Equatable {
    var isVisible: Bool
    var centerX: CGFloat
    var centerY: CGFloat

    static func hiddenDefault(kind: ShareCardOverlayKind) -> ShareCardElementLayout {
        let pos = ShareCardLayoutMath.defaultPosition(for: kind)
        return ShareCardElementLayout(isVisible: false, centerX: pos.x, centerY: pos.y)
    }
}

struct ShareCardEditorState: Equatable {
    var titleLayout: ShareCardElementLayout
    var paceChartLayout: ShareCardElementLayout
    var routeLayout: ShareCardElementLayout

    static let `default` = ShareCardEditorState(
        titleLayout: .hiddenDefault(kind: .title),
        paceChartLayout: .hiddenDefault(kind: .paceChart),
        routeLayout: .hiddenDefault(kind: .routeGlyph)
    )
}

enum ShareCardLayoutMath {
    static let minCenter: CGFloat = 0.05
    static let maxCenter: CGFloat = 0.95

    static func clampNormalized(_ value: CGFloat) -> CGFloat {
        min(max(value, minCenter), maxCenter)
    }

    static func defaultPosition(for kind: ShareCardOverlayKind) -> (x: CGFloat, y: CGFloat) {
        switch kind {
        case .title: return (0.50, 0.25)
        case .paceChart: return (0.50, 0.55)
        case .routeGlyph: return (0.25, 0.20)
        }
    }
}
