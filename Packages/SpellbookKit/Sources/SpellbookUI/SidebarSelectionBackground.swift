import SwiftUI

struct SidebarSelectionBackground: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.interactionModality) private var interactionModality
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isSelected: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .environment(\.sidebarRowFocusEmphasis, showsKeyboardFocus)
            .fontWeight(showsKeyboardFocus ? .semibold : nil)
            .background(
                RoundedRectangle(cornerRadius: SpellbookDesign.Sidebar.rowRadius)
                    .fill(rowFill)
            )
            .overlay(alignment: .bottom) {
                if showsKeyboardFocus, isSelected {
                    Rectangle()
                        .fill(SpellbookDesign.Palette.focusKeyline)
                        .frame(height: 2)
                }
            }
            .focusEffectDisabled()
            .onHover { isHovering = $0 }
            .animation(SpellbookMotion.sidebarHover(reduceMotion: reduceMotion), value: isHovering)
    }

    private var rowFill: Color {
        if isSelected {
            return SpellbookDesign.Palette.selection
        }
        if showsKeyboardFocus {
            return SpellbookDesign.Palette.focusWash
        }
        if isHovering {
            return SpellbookDesign.Palette.hover
        }
        return .clear
    }

    private var showsKeyboardFocus: Bool {
        isFocused && interactionModality == .keyboard
    }
}

private struct SidebarRowFocusEmphasisKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sidebarRowFocusEmphasis: Bool {
        get { self[SidebarRowFocusEmphasisKey.self] }
        set { self[SidebarRowFocusEmphasisKey.self] = newValue }
    }
}

extension View {
    func sidebarSelectionBackground(isSelected: Bool) -> some View {
        modifier(SidebarSelectionBackground(isSelected: isSelected))
    }
}
