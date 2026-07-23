import SwiftUI

struct SpellbookIconMenu<MenuContent: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    let icon: SpellbookIcon
    let label: String
    var size: SpellbookIconSize = .standard
    var frame: SpellbookIconButtonFrame = .standard
    var colorRole: SpellbookIconColorRole = .interactive
    private let menuContent: MenuContent

    init(
        icon: SpellbookIcon,
        label: String,
        size: SpellbookIconSize = .standard,
        frame: SpellbookIconButtonFrame = .standard,
        colorRole: SpellbookIconColorRole = .interactive,
        @ViewBuilder content: () -> MenuContent
    ) {
        self.icon = icon
        self.label = label
        self.size = size
        self.frame = frame
        self.colorRole = colorRole
        menuContent = content()
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            Label {
                Text(label)
            } icon: {
                SpellbookIconView(
                    icon: icon,
                    size: size,
                    colorRole: isEnabled ? colorRole : .disabled
                )
                .frame(width: frame.points, height: frame.points)
                .background {
                    RoundedRectangle(cornerRadius: SpellbookDesign.Radius.small)
                        .fill(isEnabled && isHovering ? SpellbookDesign.Palette.hover : .clear)
                }
                .contentShape(.rect)
            }
            .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .spellbookFocusSurface(role: .control)
        .onHover { isHovering = isEnabled && $0 }
        .animation(SpellbookMotion.sidebarHover(reduceMotion: reduceMotion), value: isHovering)
        .help(label)
        .accessibilityLabel(label)
    }
}
