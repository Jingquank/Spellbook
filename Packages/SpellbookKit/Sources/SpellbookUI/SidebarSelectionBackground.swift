import SwiftUI

struct SidebarSelectionBackground: ViewModifier {
    let isSelected: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: SpellbookDesign.Sidebar.rowRadius)
                    .fill(rowFill)
            )
            .onHover { isHovering = $0 }
    }

    private var rowFill: Color {
        if isSelected {
            return SpellbookDesign.Palette.selection
        }
        if isHovering {
            return SpellbookDesign.Palette.hover
        }
        return .clear
    }
}

extension View {
    func sidebarSelectionBackground(isSelected: Bool) -> some View {
        modifier(SidebarSelectionBackground(isSelected: isSelected))
    }
}
