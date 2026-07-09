import CoreGraphics
import SwiftUI

enum ShareCardRouteColor: CaseIterable, Equatable {
    case brand
    case white
    case green
    case gold
    case peach

    var strokeColor: Color {
        switch self {
        case .brand: return RecapPalette.brand
        case .white: return Color.white.opacity(0.9)
        case .green: return Color(red: 0.463, green: 0.784, blue: 0.576)
        case .gold: return RecapPalette.gold
        case .peach: return RecapPalette.peach
        }
    }

    var startMarkerColor: Color {
        switch self {
        case .brand: return RecapPalette.brand
        default: return strokeColor
        }
    }

    var endMarkerColor: Color {
        switch self {
        case .brand: return RecapPalette.brandDeep
        default: return strokeColor.opacity(0.75)
        }
    }
}

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
    var routeColor: ShareCardRouteColor
    var routeScale: CGFloat

    static let `default` = ShareCardEditorState(
        titleLayout: .hiddenDefault(kind: .title),
        paceChartLayout: .hiddenDefault(kind: .paceChart),
        routeLayout: .hiddenDefault(kind: .routeGlyph),
        routeColor: .brand,
        routeScale: 1.0
    )
}

enum ShareCardLayoutMath {
    static let minCenter: CGFloat = 0.05
    static let maxCenter: CGFloat = 0.95
    static let minRouteScale: CGFloat = 0.6
    static let maxRouteScale: CGFloat = 1.6
    static let routeScaleStep: CGFloat = 0.1

    static func clampNormalized(_ value: CGFloat) -> CGFloat {
        min(max(value, minCenter), maxCenter)
    }

    static func clampRouteScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minRouteScale), maxRouteScale)
    }

    static func defaultPosition(for kind: ShareCardOverlayKind) -> (x: CGFloat, y: CGFloat) {
        switch kind {
        case .title: return (0.50, 0.25)
        case .paceChart: return (0.50, 0.55)
        case .routeGlyph: return (0.25, 0.20)
        }
    }
}
