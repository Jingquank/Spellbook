import SwiftUI

struct LibrarySearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SpellbookDesign.Space.xSmall) {
            SpellbookIconView(icon: .search, size: .compact, colorRole: .secondary)
                .frame(width: 14, height: 14)

            TextField("Search skills", text: $text)
                .textFieldStyle(.plain)
                .font(SpellbookDesign.Typography.control)
                .focused($isFocused)
                .onExitCommand {
                    guard !text.isEmpty else { return }
                    text = ""
                }
                .accessibilityIdentifier("Search skills")

            SpellbookIconButton(
                icon: .clear,
                label: "Clear Search",
                size: .small,
                frame: .compact,
                colorRole: .secondary
            ) {
                text = ""
                isFocused = true
            }
            .opacity(text.isEmpty ? 0 : 1)
            .disabled(text.isEmpty)
            .accessibilityIdentifier("Clear Search")
        }
        .padding(.horizontal, SpellbookDesign.Space.small)
        .frame(height: SpellbookDesign.Sidebar.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: SpellbookDesign.Radius.small)
                .fill(fieldFill)
        )
        .spellbookFocusSurface(role: .field, isFocused: isFocused)
        .onHover { isHovering = $0 }
        .animation(SpellbookMotion.sidebarHover(reduceMotion: reduceMotion), value: isHovering)
        .accessibilityElement(children: .contain)
    }

    private var fieldFill: Color {
        if isHovering {
            SpellbookDesign.Palette.hover
        } else {
            SpellbookDesign.Palette.grouped
        }
    }
}
