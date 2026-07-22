import SwiftUI

struct SidebarSelectionBackground: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let isSelected: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: SpellbookMetrics.sidebarRowCornerRadius)
                    .fill(rowFill)
            )
            .onHover { isHovering = $0 }
    }

    private var rowFill: Color {
        if isSelected {
            return .primary.opacity(colorSchemeContrast == .increased ? 0.17 : 0.085)
        }
        if isHovering {
            return .primary.opacity(0.04)
        }
        return .clear
    }
}

extension View {
    func sidebarSelectionBackground(isSelected: Bool) -> some View {
        modifier(SidebarSelectionBackground(isSelected: isSelected))
    }
}
