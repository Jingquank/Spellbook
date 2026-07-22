import SpellbookCore
import SwiftUI

struct StatusIndicatorView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let status: ActionableStatus
    let action: () -> Void

    var body: some View {
        Button(status.label, systemImage: symbolName, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(tint)
            .symbolVariant(differentiateWithoutColor ? .fill : .none)
            .help(status.label)
    }

    private var symbolName: String {
        switch status {
        case .conflict: "exclamationmark.triangle"
        case .actionRequired: "exclamationmark.circle"
        case .modified: "pencil.circle"
        case .updateAvailable: "arrow.down.circle"
        }
    }

    private var tint: Color {
        switch status {
        case .conflict: .red
        case .actionRequired: .orange
        case .modified: .orange
        case .updateAvailable: .green
        }
    }
}
