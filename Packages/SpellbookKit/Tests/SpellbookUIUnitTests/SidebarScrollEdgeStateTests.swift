import Testing
@testable import SpellbookUI

@Suite("Sidebar scroll edge visibility")
struct SidebarScrollEdgeStateTests {
    @Test("Non-scrollable content shows no veils")
    func nonScrollable() {
        let visibility = SidebarScrollEdgeVisibility(
            metrics: SidebarScrollMetrics(
                contentMinY: 0,
                contentHeight: 300,
                viewportHeight: 400
            )
        )

        #expect(!visibility.showsTop)
        #expect(!visibility.showsBottom)
    }

    @Test("Start shows only the bottom veil")
    func start() {
        let visibility = SidebarScrollEdgeVisibility(
            metrics: SidebarScrollMetrics(
                contentMinY: 0,
                contentHeight: 800,
                viewportHeight: 400
            )
        )

        #expect(!visibility.showsTop)
        #expect(visibility.showsBottom)
    }

    @Test("Middle shows both veils")
    func middle() {
        let visibility = SidebarScrollEdgeVisibility(
            metrics: SidebarScrollMetrics(
                contentMinY: -200,
                contentHeight: 800,
                viewportHeight: 400
            )
        )

        #expect(visibility.showsTop)
        #expect(visibility.showsBottom)
    }

    @Test("End shows only the top veil")
    func end() {
        let visibility = SidebarScrollEdgeVisibility(
            metrics: SidebarScrollMetrics(
                contentMinY: -400,
                contentHeight: 800,
                viewportHeight: 400
            )
        )

        #expect(visibility.showsTop)
        #expect(!visibility.showsBottom)
    }
}
