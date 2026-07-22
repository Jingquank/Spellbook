import SwiftUI

struct SidebarSelectionButton<Label: View>: View {
    @Environment(\.interfaceDensity) private var interfaceDensity

    let isSelected: Bool
    let action: () -> Void
    let label: Label

    init(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.isSelected = isSelected
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .padding(.horizontal, SpellbookMetrics.sidebarHorizontalInset)
                .frame(minHeight: interfaceDensity.libraryRowHeight)
        }
        .buttonStyle(.plain)
        .sidebarSelectionBackground(isSelected: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
