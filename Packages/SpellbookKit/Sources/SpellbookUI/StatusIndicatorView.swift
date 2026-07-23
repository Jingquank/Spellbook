import SpellbookCore
import SwiftUI

struct StatusIndicatorView: View {
    let status: ActionableStatus
    let action: () -> Void

    var body: some View {
        SpellbookIconButton(
            icon: icon,
            label: status.label,
            size: .small,
            frame: .compact,
            colorRole: colorRole,
            action: action
        )
    }

    private var icon: SpellbookIcon {
        switch status {
        case .conflict: .warningTriangle
        case .actionRequired: .warningCircle
        case .modified: .edit
        case .updateAvailable: .downloadCircle
        }
    }

    private var colorRole: SpellbookIconColorRole {
        switch status {
        case .conflict: .error
        case .actionRequired, .modified: .warning
        case .updateAvailable: .update
        }
    }
}
