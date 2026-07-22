import SwiftUI

struct MetadataRowView: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.primary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
