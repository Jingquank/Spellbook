import SwiftUI

struct SidebarScrollMetrics: Equatable {
    var contentMinY = 0.0
    var contentHeight = 0.0
    var viewportHeight = 0.0
}

struct SidebarScrollEdgeVisibility: Equatable {
    let showsTop: Bool
    let showsBottom: Bool

    init(metrics: SidebarScrollMetrics, threshold: Double = 3) {
        let hasScrollableContent = metrics.contentHeight > metrics.viewportHeight + threshold
        showsTop = hasScrollableContent && metrics.contentMinY < -threshold
        showsBottom = hasScrollableContent
            && metrics.contentMinY + metrics.contentHeight > metrics.viewportHeight + threshold
    }
}

struct SidebarScrollMetricsKey: SwiftUI.PreferenceKey {
    static let defaultValue = SidebarScrollMetrics()

    static func reduce(value: inout SidebarScrollMetrics, nextValue: () -> SidebarScrollMetrics) {
        value = nextValue()
    }
}

struct SidebarScrollEdgeVeil: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Edge {
        case top
        case bottom

        var startPoint: UnitPoint {
            switch self {
            case .top: .top
            case .bottom: .bottom
            }
        }

        var endPoint: UnitPoint {
            switch self {
            case .top: .bottom
            case .bottom: .top
            }
        }
    }

    let edge: Edge
    let isVisible: Bool

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(veilGradient)
            .overlay(sidebarGradient)
            .frame(height: SpellbookDesign.Sidebar.scrollEdgeVeilHeight)
            .opacity(isVisible ? 1 : 0)
            .animation(SpellbookMotion.scrollEdge(reduceMotion: reduceMotion), value: isVisible)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var veilGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black.opacity(0.58), location: 0.48),
                .init(color: .clear, location: 1)
            ],
            startPoint: edge.startPoint,
            endPoint: edge.endPoint
        )
    }

    private var sidebarGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: SpellbookDesign.Palette.sidebar, location: 0),
                .init(color: SpellbookDesign.Palette.sidebar.opacity(0.58), location: 0.48),
                .init(color: .clear, location: 1)
            ],
            startPoint: edge.startPoint,
            endPoint: edge.endPoint
        )
    }
}
