import SpellbookCore
import SwiftUI

struct OperationHistorySectionView: View {
    let operations: [ManagedOperationRecord]
    let onRestore: (ManagedOperationRecord) -> Void

    var body: some View {
        Section("Recent changes") {
            if operations.isEmpty {
                Text("No Spellbook-managed changes yet")
                    .foregroundStyle(SpellbookDesign.Palette.textSecondary)
            } else {
                ForEach(operations) { operation in
                    OperationHistoryRowView(operation: operation, onRestore: onRestore)
                }
            }
        }
    }
}
