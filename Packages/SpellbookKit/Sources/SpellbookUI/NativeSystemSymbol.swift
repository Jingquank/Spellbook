import SwiftUI

/// SF Symbols are allowed only when macOS owns the presentation, such as a
/// native menu, empty state, or window-chrome control.
enum NativeSystemSymbol: String, Sendable {
    case checkmark
    case folder
    case link
    case disconnect = "link.badge.minus"
    case packageBox = "shippingbox"
    case image = "photo"
    case publishing = "arrow.up.doc"
    case tools = "wrench.and.screwdriver"
    case split = "rectangle.split.2x1"
    case combine = "rectangle.on.rectangle"
    case trash
    case badgeCheck = "checkmark.seal"
    case book = "book.closed"
    case warning = "exclamationmark.triangle"
    case bookStack = "books.vertical"
    case refresh = "arrow.clockwise"

    var name: String { rawValue }
}
