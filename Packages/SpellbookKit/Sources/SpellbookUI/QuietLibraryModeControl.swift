import SpellbookCore
import SwiftUI

struct QuietLibraryModeControl: View {
    @Binding var selection: LibraryViewMode
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @FocusState private var focusedMode: LibraryViewMode?

    var body: some View {
        HStack(spacing: 1) {
            ForEach(LibraryViewMode.allCases) { mode in
                Button {
                    selection = mode
                    focusedMode = mode
                } label: {
                    Text(mode.label)
                        .font(.callout.weight(selection == mode ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focused($focusedMode, equals: mode)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selection == mode ? selectedFill : Color.clear)
                )
                .overlay {
                    if increaseContrast, selection == mode {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.primary.opacity(0.42), lineWidth: 1)
                    }
                }
                .accessibilityLabel(mode.label)
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
        .padding(2)
        .background(.primary.opacity(increaseContrast ? 0.10 : 0.055), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Library organization")
        .onKeyPress(.leftArrow) { moveSelection(by: -1) }
        .onKeyPress(.rightArrow) { moveSelection(by: 1) }
    }

    private var selectedFill: Color {
        .primary.opacity(increaseContrast ? 0.18 : 0.09)
    }

    private var increaseContrast: Bool { colorSchemeContrast == .increased }

    private func moveSelection(by offset: Int) -> KeyPress.Result {
        let modes = LibraryViewMode.allCases
        guard let index = modes.firstIndex(of: selection) else { return .ignored }
        let next = min(max(index + offset, modes.startIndex), modes.index(before: modes.endIndex))
        selection = modes[next]
        focusedMode = selection
        return .handled
    }
}
