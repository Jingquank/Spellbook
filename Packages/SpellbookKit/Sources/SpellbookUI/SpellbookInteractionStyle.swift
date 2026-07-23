import SwiftUI

enum SpellbookFocusRole {
    case row
    case field
    case control
    case link
}

private struct SpellbookFocusSurface: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.interactionModality) private var interactionModality

    let role: SpellbookFocusRole
    let isSelected: Bool
    let explicitFocus: Bool?

    private var showsKeyboardFocus: Bool {
        (explicitFocus ?? isFocused) && interactionModality == .keyboard
    }

    func body(content: Content) -> some View {
        content
            .focusEffectDisabled()
            .fontWeight(showsKeyboardFocus ? .semibold : nil)
            .background(focusBackground)
            .overlay(alignment: .bottom) {
                if showsKeyboardFocus, isSelected || role == .link {
                    Rectangle()
                        .fill(SpellbookDesign.Palette.focusKeyline)
                        .frame(height: role == .link ? 1 : 2)
                }
            }
    }

    @ViewBuilder
    private var focusBackground: some View {
        if showsKeyboardFocus, role != .link {
            RoundedRectangle(cornerRadius: radius)
                .fill(SpellbookDesign.Palette.focusWash)
        }
    }

    private var radius: Double {
        switch role {
        case .row:
            SpellbookDesign.Sidebar.rowRadius
        case .field, .control:
            SpellbookDesign.Radius.small
        case .link:
            0
        }
    }
}

private struct SidebarHoverSurface: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    let role: SpellbookFocusRole
    let isSelected: Bool
    let horizontalPadding: Double
    let verticalPadding: Double

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: SpellbookDesign.Sidebar.rowRadius)
                    .fill(isEnabled && isHovering ? SpellbookDesign.Palette.hover : .clear)
            )
            .spellbookFocusSurface(role: role, isSelected: isSelected)
            .onHover { isHovering = isEnabled && $0 }
            .animation(SpellbookMotion.sidebarHover(reduceMotion: reduceMotion), value: isHovering)
    }
}

extension View {
    func spellbookFocusSurface(
        role: SpellbookFocusRole,
        isSelected: Bool = false,
        isFocused: Bool? = nil
    ) -> some View {
        modifier(
            SpellbookFocusSurface(
                role: role,
                isSelected: isSelected,
                explicitFocus: isFocused
            )
        )
    }

    func sidebarHoverSurface(
        role: SpellbookFocusRole = .control,
        isSelected: Bool = false,
        horizontalPadding: Double = SpellbookDesign.Space.xSmall,
        verticalPadding: Double = SpellbookDesign.Space.xSmall
    ) -> some View {
        modifier(
            SidebarHoverSurface(
                role: role,
                isSelected: isSelected,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )
        )
    }
}
